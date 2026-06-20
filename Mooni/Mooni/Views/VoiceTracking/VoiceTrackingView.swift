import SwiftUI
import CoreMotion

/// Full-screen "we're listening" experience shown after the user taps
/// "I'm going to sleep" on Home. It starts the capture engine, shows live
/// proof that the mic is working (a reactive waveform), the passive signals
/// we're using, and a charge nudge. Tapping awake saves the night.
struct VoiceTrackingView: View {
    @ObservedObject private var capture = SleepCaptureManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var pulse = false
    /// Set once the user ends the night, to swap to the summary card.
    @State private var saved: SleepSession?

    private var motionAuthorized: Bool {
        CMMotionActivityManager.authorizationStatus() == .authorized
    }

    var body: some View {
        ZStack {
            NightUI.background.ignoresSafeArea()

            if let saved {
                summary(saved)
            } else if capture.micDenied {
                micDenied
            } else {
                listening
            }
        }
        .task {
            if capture.phase == .idle && saved == nil {
                await capture.beginListening()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    // MARK: Listening

    private var listening: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Image(systemName: "ear")
                Text("LISTENING")
                    .tracking(2)
            }
            .font(MooniFont.caption(12))
            .foregroundColor(MooniColor.accentSoft)

            ZStack {
                Circle()
                    .fill(MooniColor.accent.opacity(0.16))
                    .frame(width: 96, height: 96)
                    .scaleEffect(pulse ? 1.06 : 0.94)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 38))
                    .foregroundColor(MooniColor.accentSoft)
            }

            waveform

            VStack(spacing: 4) {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(Self.clock(capture.elapsed))
                        .font(MooniFont.display(34))
                        .foregroundColor(MooniColor.textPrimary)
                        .monospacedDigit()
                }
                Text("since you tapped · still settling in")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
            }

            statusChips

            Text("Place your phone face-down nearby.\nPlug in for a full night of insights.")
                .font(MooniFont.caption(12))
                .foregroundColor(MooniColor.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

            VStack(spacing: 12) {
                PrimaryButton(title: "I'm awake", icon: "sun.max.fill") {
                    Haptics.tap()
                    saved = capture.finishAndSave()
                }
                Button {
                    capture.cancel()
                    dismiss()
                } label: {
                    Text("I'm not actually going to bed")
                        .font(MooniFont.caption(13))
                        .foregroundColor(MooniColor.textMuted)
                        .underline()
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 320)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
    }

    private var waveform: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(capture.recentLevels.enumerated()), id: \.offset) { _, lvl in
                Capsule()
                    .fill(MooniColor.accent.opacity(0.85))
                    .frame(width: 4, height: max(4, lvl * 54))
            }
        }
        .frame(height: 60)
        .animation(.easeOut(duration: 0.08), value: capture.recentLevels)
    }

    private var statusChips: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            chip("microphone", "Microphone", ok: !capture.micDenied)
            chip("figure.walk", "Motion", ok: motionAuthorized)
            chip("iphone", "Screen", ok: true)
            chip("bolt.fill", capture.isCharging ? "Charging" : "Not charging", ok: capture.isCharging)
        }
    }

    private func chip(_ icon: String, _ label: String, ok: Bool) -> some View {
        let tint = ok ? MooniColor.success : MooniColor.warning
        return HStack(spacing: 7) {
            Image(systemName: icon)
            Text(label)
            Spacer(minLength: 0)
            Image(systemName: ok ? "checkmark" : "exclamationmark")
                .font(.system(size: 10, weight: .bold))
        }
        .font(MooniFont.caption(12))
        .foregroundColor(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(tint.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: Summary

    private func summary(_ session: SleepSession) -> some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 54))
                .foregroundColor(MooniColor.success)
            Text("Night saved")
                .font(MooniFont.display(28))
                .foregroundColor(MooniColor.textPrimary)
            Text("We listened for \(Self.duration(session.duration)).")
                .font(MooniFont.body(15))
                .foregroundColor(MooniColor.textSecondary)

            HStack(spacing: 12) {
                stat("\(session.events.count)", "sounds caught")
                stat(Self.size(session.id), "on disk")
            }

            Text("Sound replay with snore / talk markers is coming next — your clips are already being saved for it.")
                .font(MooniFont.caption(12))
                .foregroundColor(MooniColor.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Spacer()
            PrimaryButton(title: "Done", icon: "checkmark") {
                dismiss()
            }
            .frame(maxWidth: 320)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(MooniFont.title(20))
                .foregroundColor(MooniColor.textPrimary)
            Text(label)
                .font(MooniFont.caption(11))
                .foregroundColor(MooniColor.textMuted)
        }
        .frame(minWidth: 110)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Mic denied

    private var micDenied: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 48))
                .foregroundColor(MooniColor.warning)
            Text("Microphone is off")
                .font(MooniFont.display(26))
                .foregroundColor(MooniColor.textPrimary)
            Text("Sleep listening needs the microphone. Turn it on in Settings to track snoring, sleep talking and more.")
                .font(MooniFont.body(14))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
            PrimaryButton(title: "Open Settings", icon: "gearshape.fill") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .frame(maxWidth: 320)
            Button("Not now") { dismiss() }
                .font(MooniFont.caption(13))
                .foregroundColor(MooniColor.textMuted)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
    }

    // MARK: Formatting

    private static func clock(_ t: TimeInterval) -> String {
        let s = Int(max(0, t))
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    private static func duration(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        if m < 60 { return "\(m) min" }
        return "\(m / 60)h \(m % 60)m"
    }

    private static func size(_ id: UUID) -> String {
        ByteCountFormatter.string(fromByteCount: SleepSessionStore.sizeOnDisk(id),
                                  countStyle: .file)
    }
}

#Preview {
    VoiceTrackingView()
}
