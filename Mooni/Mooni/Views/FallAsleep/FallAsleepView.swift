import SwiftUI
import Combine
import AVFoundation

/// Ambient-sound page that helps the user fall asleep faster.
/// Each tile loops a bundled audio file; if the file isn't bundled yet
/// the tile shows "Coming soon". A single tap starts/stops a sound,
/// and only one sound plays at a time so it doesn't turn into noise.
struct FallAsleepView: View {
    @StateObject private var player = AmbientSoundPlayer.shared
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var volume: Double = 0.7
    @State private var showPaywall = false

    /// Sound IDs that are free; everything else requires Pro.
    private static let freeSoundIDs: Set<String> = ["rain", "ocean"]
    // Default to 30 minutes so a user who falls asleep with the phone
    // doesn't have ambient sound playing all night. They can still extend
    // to 1h or disable from the timer card.
    @State private var timerSelection: TimerOption = .thirty

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                StarsBackground(count: 38)

                ScrollView {
                    VStack(spacing: 22) {
                        header

                        soundsGrid

                        if player.current != nil {
                            volumeCard
                            timerCard
                        }

                        Spacer(minLength: 80)
                    }
                    .padding(20)
                }
                // iPad: cap content column; background stays full-bleed.
                .responsiveContainer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onChange(of: volume) { _, newValue in
            player.setVolume(Float(newValue))
        }
        .onChange(of: timerSelection) { _, option in
            if let minutes = option.minutes, player.current != nil {
                player.scheduleStop(after: TimeInterval(minutes) * 60)
            } else {
                player.cancelScheduledStop()
            }
        }
        // Whenever a sound *starts*, kick off the auto-stop using the
        // currently selected timer. This is what protects the user from
        // ambient sound playing until morning if they fall asleep.
        .onChange(of: player.current?.id) { _, newId in
            if newId != nil, let minutes = timerSelection.minutes {
                player.scheduleStop(after: TimeInterval(minutes) * 60)
            } else if newId == nil {
                player.cancelScheduledStop()
            }
        }
        .onAppear { player.setVolume(Float(volume)) }
        .mooniPaywall(isPresented: $showPaywall)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sounds")
                .font(MooniFont.caption(13))
                .foregroundColor(MooniColor.accentSoft)
                .textCase(.uppercase)
            Text(player.current?.title ?? "Pick a sound")
                .font(MooniFont.display(28))
                .foregroundColor(MooniColor.textPrimary)
            Text(player.current == nil
                 ? "Tap a tile to start. Pull down on volume to fade out slowly."
                 : "Playing softly. Tap again to stop.")
                .font(MooniFont.body(14))
                .foregroundColor(MooniColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var soundsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(AmbientSound.catalog) { sound in
                let isFree = Self.freeSoundIDs.contains(sound.id)
                let locked = !isFree && !subscriptionManager.isPro
                SoundTile(
                    sound: sound,
                    isPlaying: player.current?.id == sound.id,
                    isAvailable: AmbientSoundPlayer.isBundled(sound),
                    isLocked: locked
                ) {
                    if locked {
                        showPaywall = true
                    } else {
                        player.toggle(sound)
                    }
                }
            }
        }
    }

    private var volumeCard: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(MooniColor.accentSoft)
                    Text("Volume")
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    Text("\(Int(volume * 100))%")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }
                Slider(value: $volume, in: 0...1)
                    .tint(MooniColor.accent)
            }
        }
    }

    private var timerCard: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(MooniColor.warning)
                    Text("Sleep timer")
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                }
                HStack(spacing: 8) {
                    ForEach(TimerOption.allCases) { option in
                        Button {
                            timerSelection = option
                        } label: {
                            Text(option.label)
                                .font(MooniFont.caption(13))
                                .foregroundColor(timerSelection == option ? MooniColor.background : MooniColor.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(timerSelection == option ? MooniColor.accentSoft : Color.white.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private enum TimerOption: String, CaseIterable, Identifiable {
    case off, fifteen, thirty, sixty
    var id: String { rawValue }
    var label: String {
        switch self {
        case .off:      return "Off"
        case .fifteen:  return "15m"
        case .thirty:   return "30m"
        case .sixty:    return "1h"
        }
    }
    var minutes: Int? {
        switch self {
        case .off:      return nil
        case .fifteen:  return 15
        case .thirty:   return 30
        case .sixty:    return 60
        }
    }
}

private struct SoundTile: View {
    let sound: AmbientSound
    let isPlaying: Bool
    let isAvailable: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: { if isAvailable || isLocked { action() } }) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(sound.tint.opacity(isPlaying ? 0.32 : 0.18))
                            .frame(width: 44, height: 44)
                        Image(systemName: isPlaying ? "pause.fill" : sound.icon)
                            .foregroundColor(sound.tint)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    Spacer()
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(MooniColor.warning)
                            .padding(7)
                            .background(MooniColor.warning.opacity(0.18))
                            .clipShape(Circle())
                    } else if !isAvailable {
                        Text("Soon")
                            .font(MooniFont.caption(10))
                            .foregroundColor(MooniColor.textMuted)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    } else if isPlaying {
                        Circle()
                            .fill(MooniColor.success)
                            .frame(width: 8, height: 8)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(sound.title)
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Text(sound.subtitle)
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(isPlaying ? 0.10 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isPlaying ? sound.tint.opacity(0.55) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .opacity(isAvailable ? (isLocked ? 0.75 : 1) : 0.55)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sound catalog

struct AmbientSound: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    /// Filename (without extension) of the looping audio asset to bundle.
    let resource: String

    static let catalog: [AmbientSound] = [
        .init(id: "rain",      title: "Rain & Thunder", subtitle: "Steady rainfall with distant thunder.",
              icon: "cloud.bolt.rain.fill", tint: Color(red: 0.65, green: 0.78, blue: 1.00), resource: "rain"),
        .init(id: "waterfall", title: "Waterfall", subtitle: "Steady mountain stream.",
              icon: "drop.fill",         tint: Color(red: 0.55, green: 0.85, blue: 0.78), resource: "waterfall"),
        .init(id: "amazon",    title: "Rainforest", subtitle: "Amazon at night — birds and rain.",
              icon: "leaf.fill",         tint: Color(red: 0.70, green: 0.90, blue: 0.65), resource: "amazon"),
        .init(id: "fire",      title: "Fireplace", subtitle: "Crackling logs in a quiet cabin.",
              icon: "flame.fill",        tint: Color(red: 1.00, green: 0.70, blue: 0.50), resource: "fire"),
        .init(id: "ocean",     title: "Ocean",     subtitle: "Slow waves on a calm beach.",
              icon: "water.waves",       tint: Color(red: 0.55, green: 0.75, blue: 1.00), resource: "ocean"),
        .init(id: "brown",     title: "Brown noise", subtitle: "Deep, even hum.",
              icon: "waveform",          tint: Color(red: 0.85, green: 0.78, blue: 1.00), resource: "brown")
    ]
}

// MARK: - Player

@MainActor
final class AmbientSoundPlayer: ObservableObject {
    static let shared = AmbientSoundPlayer()

    @Published private(set) var current: AmbientSound? = nil

    private var player: AVAudioPlayer?
    private var stopWorkItem: DispatchWorkItem?

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    static func isBundled(_ sound: AmbientSound) -> Bool {
        AmbientSoundPlayer.findURL(for: sound) != nil
    }

    func toggle(_ sound: AmbientSound) {
        if current?.id == sound.id {
            stop()
        } else {
            play(sound)
        }
    }

    func play(_ sound: AmbientSound) {
        guard let url = Self.findURL(for: sound) else { return }
        player?.stop()
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = player?.volume ?? 0.7
            p.prepareToPlay()
            p.play()
            self.player = p
            self.current = sound
        } catch {
            self.player = nil
            self.current = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
        current = nil
        cancelScheduledStop()
    }

    func setVolume(_ volume: Float) {
        player?.volume = max(0, min(1, volume))
    }

    func scheduleStop(after seconds: TimeInterval) {
        cancelScheduledStop()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.stop() }
        }
        stopWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    func cancelScheduledStop() {
        stopWorkItem?.cancel()
        stopWorkItem = nil
    }

    private static func findURL(for sound: AmbientSound) -> URL? {
        // Try the bundle root and the "Sounds" subfolder. With Xcode's
        // synchronized file groups, dropping a file into Mooni/Sounds/
        // preserves that folder when it's copied into the .app, so we
        // need to look in both places.
        let extensions = ["mp3", "m4a", "caf", "wav", "aac"]
        for ext in extensions {
            if let url = Bundle.main.url(forResource: sound.resource, withExtension: ext) {
                return url
            }
            if let url = Bundle.main.url(forResource: sound.resource, withExtension: ext, subdirectory: "Sounds") {
                return url
            }
        }
        return nil
    }
}

#Preview {
    FallAsleepView()
        .environmentObject(AppState.preview)
}
