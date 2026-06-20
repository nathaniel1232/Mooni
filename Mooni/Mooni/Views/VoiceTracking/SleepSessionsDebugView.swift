import SwiftUI
import AVFoundation

/// Developer-only inspector for saved voice-tracking nights. Confirms the
/// capture pipeline is actually writing sessions, envelopes, and clips — and
/// lets you play back any captured sound. This is the rough stand-in for the
/// real "night replay" screen that ships in Phase 1.
struct SleepSessionsDebugView: View {
    @State private var sessions: [SleepSession] = []
    @State private var player: AVAudioPlayer?
    @State private var playingClip: String?

    var body: some View {
        ZStack {
            MooniGradient.night.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    if sessions.isEmpty {
                        Text("No nights captured yet.\nTap “I'm going to sleep” on Home.")
                            .font(MooniFont.body(14))
                            .foregroundColor(MooniColor.textMuted)
                            .multilineTextAlignment(.center)
                            .padding(.top, 60)
                    }
                    ForEach(sessions) { session in
                        sessionCard(session)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Captured nights")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { sessions = SleepSessionStore.allSessions() }
    }

    private func sessionCard(_ session: SleepSession) -> some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(MooniFont.title(15))
                            .foregroundColor(MooniColor.textPrimary)
                        Text("\(Self.duration(session.duration)) · \(session.events.count) sounds · \(Self.size(session.id))")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textSecondary)
                    }
                    Spacer()
                    Button {
                        SleepSessionStore.delete(session.id)
                        sessions = SleepSessionStore.allSessions()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(MooniColor.danger)
                    }
                    .buttonStyle(.plain)
                }

                if session.events.isEmpty {
                    Text("Envelope only — no sound events crossed the threshold.")
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.textMuted)
                } else {
                    ForEach(session.events) { event in
                        eventRow(session: session, event: event)
                    }
                }
            }
        }
    }

    private func eventRow(session: SleepSession, event: SoundEvent) -> some View {
        let isPlaying = playingClip == event.clipFilename
        return Button {
            play(sessionID: session.id, filename: event.clipFilename)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(MooniColor.accentSoft)
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.label ?? "Sound")
                        .font(MooniFont.caption(13))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("\(event.time.formatted(date: .omitted, time: .standard)) · \(Int(event.duration))s")
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.textMuted)
                }
                Spacer()
                levelDots(event.peakLevel)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func levelDots(_ level: Float) -> some View {
        let bars = 5
        let active = Int((level * Float(bars)).rounded())
        return HStack(spacing: 2) {
            ForEach(0..<bars, id: \.self) { i in
                Capsule()
                    .fill(i < active ? MooniColor.accent : Color.white.opacity(0.12))
                    .frame(width: 3, height: CGFloat(6 + i * 3))
            }
        }
    }

    private func play(sessionID: UUID, filename: String) {
        if playingClip == filename {
            player?.stop()
            playingClip = nil
            return
        }
        let url = SleepSessionStore.clipURL(sessionID: sessionID, filename: filename)
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        player = p
        p.play()
        playingClip = filename
    }

    private static func duration(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        if m < 60 { return "\(m)m" }
        return "\(m / 60)h \(m % 60)m"
    }

    private static func size(_ id: UUID) -> String {
        ByteCountFormatter.string(fromByteCount: SleepSessionStore.sizeOnDisk(id),
                                  countStyle: .file)
    }
}
