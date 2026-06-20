import Foundation
import AVFoundation
import UIKit
import Combine

// MARK: - Draft handed back from the audio worker

/// A finished event clip, described in offsets from the session start (the
/// worker has no business knowing wall-clock dates). The manager turns this
/// into a `SoundEvent` with an absolute `time`.
struct SoundEventDraft: Sendable {
    let startOffset: TimeInterval
    let duration: TimeInterval
    let peakLevel: Float
    let filename: String
}

// MARK: - Audio worker (off the main actor)

/// Owns the audio engine + input tap. Runs entirely off the main actor on a
/// private serial queue. It does three cheap things, all night:
///
///   1. Meters loudness every buffer and builds a ~1 Hz dB envelope.
///   2. Streams a smoothed level back for the live waveform UI.
///   3. Records a short AAC clip ONLY when sound crosses a threshold above the
///      running noise floor (a snore, a word, a noise) — with a couple of
///      seconds of pre-roll so the clip doesn't start mid-snore.
///
/// This is what keeps a whole night at ~5–10 MB instead of gigabytes.
nonisolated final class AudioCaptureCore {

    // Tunables
    private let envelopeHz: Double = 1.0       // envelope samples / second
    private let levelUIInterval: Double = 0.08 // ~12 UI level callbacks / second
    private let triggerDB: Float = 12          // dB above floor to start a clip
    private let releaseDB: Float = 6           // fall back to floor+this to end
    private let preRoll: TimeInterval = 2.0    // seconds kept before a trigger
    private let hangover: TimeInterval = 1.5   // quiet time before a clip closes
    private let maxClip: TimeInterval = 25.0
    private let minClip: TimeInterval = 1.2

    // Callbacks (assigned by the manager; both are invoked off-main)
    var onLevel: (@Sendable (Float) -> Void)?
    var onEvent: (@Sendable (SoundEventDraft) -> Void)?

    private let engine = AVAudioEngine()
    private let queue = DispatchQueue(label: "mooni.sleepcapture.audio")
    private var tapInstalled = false

    // State — queue-isolated
    private var eventsDir: URL?
    private var format: AVAudioFormat?
    private var sessionStartUptime: Double = 0
    private var noiseFloorDB: Float = -50
    private var smoothedDB: Float = -60
    private var lastEnvelopeAt: Double = 0
    private var lastLevelAt: Double = 0
    private var envelope: [Float] = []

    // Pre-roll ring + active clip
    private var ring: [AVAudioPCMBuffer] = []
    private var ringFrames: AVAudioFrameCount = 0
    private var clipFile: AVAudioFile?
    private var clipStartUptime: Double = 0
    private var clipPeak: Float = 0
    private var clipFilename: String = ""
    private var belowSince: Double?

    var inputFormatDescription: String {
        guard let f = format else { return "—" }
        return "\(Int(f.sampleRate)) Hz · \(f.channelCount)ch"
    }

    func start(eventsDir: URL) throws {
        let input = engine.inputNode
        let fmt = input.inputFormat(forBus: 0)
        queue.sync {
            self.eventsDir = eventsDir
            self.format = fmt
            self.envelope.removeAll(keepingCapacity: true)
            self.ring.removeAll()
            self.ringFrames = 0
            self.noiseFloorDB = -50
            self.smoothedDB = -60
            self.sessionStartUptime = ProcessInfo.processInfo.systemUptime
            self.lastEnvelopeAt = self.sessionStartUptime
            self.lastLevelAt = self.sessionStartUptime
        }
        input.installTap(onBus: 0, bufferSize: 4096, format: fmt) { [weak self] buffer, _ in
            guard let self, let copy = self.copy(of: buffer) else { return }
            self.queue.async { self.handle(copy) }
        }
        tapInstalled = true
        engine.prepare()
        try engine.start()
    }

    /// Stops capture and returns the finished envelope + its sample rate.
    func stop() -> (envelope: [Float], hz: Double) {
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine.stop()
        return queue.sync {
            finalizeClipIfNeeded(now: ProcessInfo.processInfo.systemUptime)
            return (envelope, envelopeHz)
        }
    }

    // MARK: Processing (queue only)

    private func handle(_ buffer: AVAudioPCMBuffer) {
        let now = ProcessInfo.processInfo.systemUptime
        let db = Self.decibels(buffer)

        // Smooth the level, then track the noise floor: drop fast to a new
        // quiet baseline, drift up slowly so a long quiet stretch re-centres it.
        smoothedDB += 0.3 * (db - smoothedDB)
        if smoothedDB < noiseFloorDB {
            noiseFloorDB = smoothedDB
        } else if clipFile == nil {
            noiseFloorDB += 0.0008 * (smoothedDB - noiseFloorDB)
        }

        let norm = normalized(smoothedDB)

        // Live waveform — throttled.
        if now - lastLevelAt >= levelUIInterval {
            lastLevelAt = now
            onLevel?(norm)
        }

        // Envelope — ~1 Hz.
        if now - lastEnvelopeAt >= 1.0 / envelopeHz {
            lastEnvelopeAt = now
            envelope.append(norm)
        }

        // Maintain pre-roll ring while idle.
        if clipFile == nil {
            pushRing(buffer)
        }

        // Event state machine.
        if clipFile == nil {
            if smoothedDB > noiseFloorDB + triggerDB {
                startClip(now: now)
            }
        } else {
            writeClip(buffer)
            clipPeak = max(clipPeak, norm)
            let length = now - clipStartUptime
            if smoothedDB < noiseFloorDB + releaseDB {
                if belowSince == nil { belowSince = now }
            } else {
                belowSince = nil
            }
            let quietLongEnough = belowSince.map { now - $0 >= hangover } ?? false
            if quietLongEnough || length >= maxClip {
                finalizeClipIfNeeded(now: now)
            }
        }
    }

    private func startClip(now: Double) {
        guard let eventsDir, let format else { return }
        let name = "evt_\(Int(now * 1000)).m4a"
        let url = eventsDir.appendingPathComponent(name)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: Int(format.channelCount),
            AVEncoderBitRateKey: 48_000
        ]
        guard let file = try? AVAudioFile(forWriting: url, settings: settings) else { return }
        clipFile = file
        clipFilename = name
        clipStartUptime = now - preRoll
        clipPeak = normalized(smoothedDB)
        belowSince = nil
        // Flush the pre-roll so the clip includes the lead-in.
        for buf in ring { try? file.write(from: buf) }
        ring.removeAll(keepingCapacity: true)
        ringFrames = 0
    }

    private func writeClip(_ buffer: AVAudioPCMBuffer) {
        try? clipFile?.write(from: buffer)
    }

    private func finalizeClipIfNeeded(now: Double) {
        guard let file = clipFile else { return }
        let length = now - clipStartUptime
        let name = clipFilename
        let peak = clipPeak
        let startOffset = max(0, clipStartUptime - sessionStartUptime)
        clipFile = nil
        clipFilename = ""
        belowSince = nil

        if length >= minClip {
            onEvent?(SoundEventDraft(startOffset: startOffset,
                                     duration: length,
                                     peakLevel: peak,
                                     filename: name))
        } else {
            // Too short to be meaningful — drop the file.
            try? FileManager.default.removeItem(at: file.url)
        }
    }

    private func pushRing(_ buffer: AVAudioPCMBuffer) {
        guard let format else { return }
        ring.append(buffer)
        ringFrames += buffer.frameLength
        let maxFrames = AVAudioFrameCount(preRoll * format.sampleRate)
        while ringFrames > maxFrames, ring.count > 1 {
            ringFrames -= ring.removeFirst().frameLength
        }
    }

    // MARK: Helpers

    /// Maps a smoothed dB reading to 0–1 for the UI, relative to the floor so
    /// the waveform stays lively in a quiet room and saturates on loud sounds.
    private func normalized(_ db: Float) -> Float {
        let span: Float = 30
        return min(1, max(0.03, (db - noiseFloorDB) / span))
    }

    private static func decibels(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let ch = buffer.floatChannelData else { return -60 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return -60 }
        var sum: Float = 0
        let samples = ch[0]
        for i in 0..<frames { sum += samples[i] * samples[i] }
        let rms = (sum / Float(frames)).squareRoot()
        return 20 * log10(max(rms, 1e-7))
    }

    private func copy(of buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format,
                                          frameCapacity: buffer.frameLength) else { return nil }
        copy.frameLength = buffer.frameLength
        let channels = Int(buffer.format.channelCount)
        if let src = buffer.floatChannelData, let dst = copy.floatChannelData {
            for ch in 0..<channels {
                memcpy(dst[ch], src[ch], Int(buffer.frameLength) * MemoryLayout<Float>.size)
            }
        }
        return copy
    }
}

// MARK: - Manager (main actor, observable)

/// The public face of voice tracking. Tapping "I'm going to sleep" calls
/// `beginListening()`; the device listens (and meters motion/screen passively
/// elsewhere) until the user taps awake, at which point `finishAndSave()`
/// persists the night. Nothing is logged as "sleep" here — this only captures;
/// the existing `SleepSessionEngine` still decides when sleep actually began.
@MainActor
final class SleepCaptureManager: ObservableObject {
    static let shared = SleepCaptureManager()

    enum Phase: Equatable { case idle, listening }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var level: CGFloat = 0.04
    /// Rolling window of recent levels for the bar waveform (oldest → newest).
    @Published private(set) var recentLevels: [CGFloat]
    @Published private(set) var startedAt: Date?
    @Published private(set) var eventCount: Int = 0
    @Published private(set) var isCharging: Bool = false
    /// Set after `finishAndSave()` so the UI can show a one-night summary.
    @Published var lastSaved: SleepSession?
    /// True if the mic permission was refused — the UI routes to Settings.
    @Published var micDenied = false

    private let core = AudioCaptureCore()
    private var session: SleepSession?
    private let waveformBars = 30

    private init() {
        recentLevels = Array(repeating: 0.04, count: 30)
        UIDevice.current.isBatteryMonitoringEnabled = true
        isCharging = Self.charging
        NotificationCenter.default.addObserver(
            self, selector: #selector(batteryChanged),
            name: UIDevice.batteryStateDidChangeNotification, object: nil)
    }

    @objc private func batteryChanged() { isCharging = Self.charging }

    private static var charging: Bool {
        let s = UIDevice.current.batteryState
        return s == .charging || s == .full
    }

    var elapsed: TimeInterval { startedAt.map { Date().timeIntervalSince($0) } ?? 0 }

    var inputDescription: String { core.inputFormatDescription }

    // MARK: Lifecycle

    /// Requests mic access (if needed) and starts listening. Returns false if
    /// permission was refused or the engine couldn't start.
    @discardableResult
    func beginListening() async -> Bool {
        guard phase == .idle else { return true }

        let granted = await Self.requestMicPermission()
        guard granted else { micDenied = true; return false }
        micDenied = false

        let newSession = SleepSession(startedAt: Date())
        SleepSessionStore.prepare(newSession.id)
        self.session = newSession

        core.onLevel = { [weak self] lvl in
            Task { @MainActor in self?.ingestLevel(CGFloat(lvl)) }
        }
        core.onEvent = { [weak self] draft in
            Task { @MainActor in self?.ingestEvent(draft) }
        }

        do {
            let s = AVAudioSession.sharedInstance()
            // playAndRecord + mixWithOthers so the ambient-sound player can keep
            // playing while we record. Background `audio` mode (Info.plist) keeps
            // capture alive once the screen locks.
            try s.setCategory(.playAndRecord, mode: .default,
                              options: [.mixWithOthers, .allowBluetooth, .defaultToSpeaker])
            try s.setActive(true)
            try core.start(eventsDir: SleepSessionStore.eventsDir(newSession.id))
        } catch {
            SleepSessionStore.delete(newSession.id)
            self.session = nil
            return false
        }

        startedAt = newSession.startedAt
        eventCount = 0
        isCharging = Self.charging
        recentLevels = Array(repeating: 0.04, count: waveformBars)
        phase = .listening
        return true
    }

    /// Stops listening and writes the night to disk. Returns the saved session.
    @discardableResult
    func finishAndSave() -> SleepSession? {
        guard phase == .listening, var s = session else { return nil }
        let (envelope, hz) = core.stop()
        deactivateAudio()

        s.endedAt = Date()
        s.envelopeHz = hz
        s.envelopeCount = envelope.count
        SleepSessionStore.writeEnvelope(envelope, for: s.id)
        SleepSessionStore.save(s)
        SleepSessionStore.prune()

        lastSaved = s
        resetTransient()
        return s
    }

    /// Discards the in-progress night entirely (the "I'm not going to bed"
    /// escape). Nothing is saved.
    func cancel() {
        guard phase == .listening else { return }
        _ = core.stop()
        deactivateAudio()
        if let id = session?.id { SleepSessionStore.delete(id) }
        resetTransient()
    }

    // MARK: Internals

    private func ingestLevel(_ lvl: CGFloat) {
        level = lvl
        var bars = recentLevels
        bars.removeFirst()
        bars.append(lvl)
        recentLevels = bars
    }

    private func ingestEvent(_ draft: SoundEventDraft) {
        guard var s = session else { return }
        let event = SoundEvent(
            time: s.startedAt.addingTimeInterval(draft.startOffset),
            duration: draft.duration,
            peakLevel: draft.peakLevel,
            clipFilename: draft.filename
        )
        s.events.append(event)
        session = s
        eventCount = s.events.count
        // Persist incrementally so a crash / battery death keeps the night.
        SleepSessionStore.save(s)
    }

    private func deactivateAudio() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    private func resetTransient() {
        session = nil
        startedAt = nil
        phase = .idle
        level = 0.04
        recentLevels = Array(repeating: 0.04, count: waveformBars)
    }

    private static func requestMicPermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .denied:  return false
        default:
            return await withCheckedContinuation { cont in
                AVAudioApplication.requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }
    }
}
