import Foundation

// MARK: - On-disk sleep-capture model
//
// A night of voice tracking is stored as a small folder under
// Application Support/SleepSessions/<id>/:
//
//   meta.json        — the SleepSession (times + event list + envelope info)
//   levels.f32       — the loudness envelope: one Float32 per sample, ~1 Hz.
//                      A whole 8h night is ~30 KB.
//   events/<file>    — short compressed AAC clips, one per detected sound
//                      event (snore / talk / noise). Only a handful of MB total.
//
// This layout is deliberately the foundation for the future "night replay"
// screen: the envelope draws the scrubbable waveform, and each SoundEvent is a
// tappable marker that plays its clip. Classification (snore vs talk vs …)
// fills in `SoundEvent.label` later — for now every event is unlabeled.

/// One detected sound during the night.
struct SoundEvent: Identifiable, Codable, Hashable {
    let id: UUID
    /// Wall-clock time the event started.
    let time: Date
    /// Length of the captured clip, seconds.
    let duration: TimeInterval
    /// Loudness peak, normalized 0–1 (relative to the night's noise floor).
    let peakLevel: Float
    /// File name of the clip inside the session's `events/` folder.
    let clipFilename: String
    /// Classifier label (snore / talk / cough / …). Nil until Phase 2.
    var label: String?

    init(id: UUID = UUID(), time: Date, duration: TimeInterval,
         peakLevel: Float, clipFilename: String, label: String? = nil) {
        self.id = id
        self.time = time
        self.duration = duration
        self.peakLevel = peakLevel
        self.clipFilename = clipFilename
        self.label = label
    }
}

/// One night of capture.
struct SleepSession: Identifiable, Codable, Hashable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date?
    var events: [SoundEvent]
    /// Envelope sample rate (samples per second) stored in `levels.f32`.
    var envelopeHz: Double
    /// Number of envelope samples written.
    var envelopeCount: Int

    init(id: UUID = UUID(), startedAt: Date, endedAt: Date? = nil,
         events: [SoundEvent] = [], envelopeHz: Double = 1.0, envelopeCount: Int = 0) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.events = events
        self.envelopeHz = envelopeHz
        self.envelopeCount = envelopeCount
    }

    var duration: TimeInterval {
        guard let endedAt else { return Date().timeIntervalSince(startedAt) }
        return endedAt.timeIntervalSince(startedAt)
    }
}

// MARK: - Store

/// Reads/writes sleep-capture sessions to Application Support. All file I/O is
/// synchronous and cheap (tiny JSON + a small binary envelope); the audio clips
/// are written by the capture engine directly into the session's `events/` dir.
enum SleepSessionStore {
    /// Keep full audio for the most recent N nights; older nights are pruned
    /// to free storage. (Envelopes are tiny, but clips add up.)
    static let keepFullSessions = 14

    static var baseURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                               in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("SleepSessions", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func sessionDir(_ id: UUID) -> URL {
        baseURL.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    static func eventsDir(_ id: UUID) -> URL {
        sessionDir(id).appendingPathComponent("events", isDirectory: true)
    }

    /// Creates the session + events folders. Call once at the start of a night.
    @discardableResult
    static func prepare(_ id: UUID) -> URL {
        let dir = sessionDir(id)
        try? FileManager.default.createDirectory(at: eventsDir(id),
                                                 withIntermediateDirectories: true)
        return dir
    }

    static func save(_ session: SleepSession) {
        let url = sessionDir(session.id).appendingPathComponent("meta.json")
        if let data = try? JSONEncoder().encode(session) {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: sessionDir(id))
    }

    /// All saved sessions, newest first.
    static func allSessions() -> [SleepSession] {
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(at: baseURL,
                                                     includingPropertiesForKeys: nil) else { return [] }
        let sessions = dirs.compactMap { dir -> SleepSession? in
            let meta = dir.appendingPathComponent("meta.json")
            guard let data = try? Data(contentsOf: meta),
                  let s = try? JSONDecoder().decode(SleepSession.self, from: data) else { return nil }
            return s
        }
        return sessions.sorted { $0.startedAt > $1.startedAt }
    }

    /// Deletes audio + envelopes for everything older than `keepFullSessions`.
    static func prune() {
        let all = allSessions()
        guard all.count > keepFullSessions else { return }
        for old in all.dropFirst(keepFullSessions) {
            delete(old.id)
        }
    }

    // MARK: Envelope (binary Float32)

    static func writeEnvelope(_ samples: [Float], for id: UUID) {
        let url = sessionDir(id).appendingPathComponent("levels.f32")
        samples.withUnsafeBytes { raw in
            try? Data(raw).write(to: url, options: .atomic)
        }
    }

    static func readEnvelope(_ id: UUID) -> [Float] {
        let url = sessionDir(id).appendingPathComponent("levels.f32")
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return [] }
        return data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    // MARK: Sizing (for the debug list)

    static func sizeOnDisk(_ id: UUID) -> Int64 {
        let fm = FileManager.default
        guard let en = fm.enumerator(at: sessionDir(id),
                                     includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in en {
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            total += Int64(size)
        }
        return total
    }

    static func clipURL(sessionID: UUID, filename: String) -> URL {
        eventsDir(sessionID).appendingPathComponent(filename)
    }
}
