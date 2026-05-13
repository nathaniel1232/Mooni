import Foundation
@preconcurrency import AVFoundation
import Combine

/// Plays short, non-looping audio samples — used to demo recognized sounds in
/// onboarding (snore, sleep-talk, breath). Distinct from `AmbientSoundPlayer`
/// which loops ambience for the wind-down flow.
///
/// Resolves files from the bundle root or the bundled "Sounds" subfolder so
/// drag-and-dropping a clip into Mooni/Sounds/ "just works" once it's added
/// to the Xcode target.
@MainActor
final class SamplePlayer: ObservableObject {
    static let shared = SamplePlayer()

    /// Resource currently playing, if any. Driven so views can highlight a
    /// pressed button while playback runs.
    @Published private(set) var currentlyPlaying: String? = nil

    private var player: AVAudioPlayer?
    private var delegate: PlayerDelegate?

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true, options: [])
    }

    /// True if a bundle resource exists for `name` in any supported format.
    static func isAvailable(_ name: String) -> Bool {
        Self.findURL(name: name) != nil
    }

    /// Toggles playback for the given resource name (without extension).
    /// Calling again with the same name stops it; calling with a different
    /// name swaps to the new clip.
    func toggle(_ name: String) {
        if currentlyPlaying == name {
            stop()
        } else {
            play(name)
        }
    }

    func play(_ name: String) {
        guard let url = Self.findURL(name: name) else {
            // Silently no-op if the audio asset is missing — better than a
            // crash during dev when sample clips haven't been dropped in yet.
            currentlyPlaying = nil
            return
        }
        player?.stop()
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            let del = PlayerDelegate { [weak self] in
                Task { @MainActor in self?.handleFinished(name: name) }
            }
            p.delegate = del
            p.numberOfLoops = 0
            p.volume = 0.85
            p.prepareToPlay()
            p.play()
            self.player = p
            self.delegate = del
            self.currentlyPlaying = name
        } catch {
            self.player = nil
            self.delegate = nil
            self.currentlyPlaying = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
        delegate = nil
        currentlyPlaying = nil
    }

    private func handleFinished(name: String) {
        if currentlyPlaying == name {
            player = nil
            delegate = nil
            currentlyPlaying = nil
        }
    }

    private static func findURL(name: String) -> URL? {
        let extensions = ["mp3", "m4a", "caf", "wav", "aac"]
        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Sounds") {
                return url
            }
        }
        return nil
    }
}

/// Tiny shim because AVAudioPlayer's delegate protocol predates Swift
/// concurrency — we just need a finished-playing callback.
private final class PlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let onFinish: () -> Void
    init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
}
