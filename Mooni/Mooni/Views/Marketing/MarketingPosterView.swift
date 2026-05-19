import SwiftUI

/// Full-screen, screenshot-ready App Store / social promo poster.
///
/// Completely rebuilt: a real brand lockup (the actual `app_icon`), a bold
/// value headline, and a faux in-app "screen" card that shows the product
/// doing its one job — a sleep score, the night's stats and a hypnogram —
/// then a clean App Store call-to-action. Only a slow ambient glow moves, so
/// any frame grabbed from it looks deliberate and finished.
///
/// Surfaced from Profile → Dev Tools → "Marketing Poster".
struct MarketingPosterView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var glow = false
    @State private var showChrome = true
    @State private var chromeTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack {
            MooniGradient.night.ignoresSafeArea()
            StarsBackground(count: 80).ignoresSafeArea()

            // Ambient brand bloom, gently breathing.
            RadialGradient(
                colors: [MooniColor.accent.opacity(0.26), .clear],
                center: .center, startRadius: 8, endRadius: 360)
                .scaleEffect(glow ? 1.08 : 0.92)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 8)

                brandRow

                Spacer(minLength: 18)

                headline

                Spacer(minLength: 22)

                screenCard
                    .frame(maxHeight: 460)

                Spacer(minLength: 22)

                appStoreCTA

                Spacer(minLength: 10)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 14)

            chrome
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeIn(duration: 0.18)) { showChrome = true }
            scheduleChromeFade()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true)) {
                glow = true
            }
            scheduleChromeFade()
        }
        .onDisappear { chromeTask?.cancel() }
    }

    // MARK: - Brand row

    private var brandRow: some View {
        HStack(spacing: 13) {
            appIcon(side: 52, corner: 13)
            VStack(alignment: .leading, spacing: 1) {
                Text("SleepOwl")
                    .font(MooniFont.display(26))
                    .foregroundStyle(LinearGradient(
                        colors: [MooniColor.textPrimary, MooniColor.accentSoft],
                        startPoint: .leading, endPoint: .trailing))
                Text("Sleep tracking, automatic")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
                    .tracking(0.4)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Headline

    private var headline: some View {
        VStack(spacing: 10) {
            Text("Your sleep,\ndecoded.")
                .font(MooniFont.display(40))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .minimumScaleFactor(0.7)

            Text("It listens while you rest and turns the night\ninto a score you can actually act on.")
                .font(MooniFont.body(15))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: - In-app screen card

    private var screenCard: some View {
        VStack(spacing: 18) {
            HStack {
                Text("LAST NIGHT")
                    .font(MooniFont.caption(11))
                    .tracking(2.4)
                    .foregroundColor(MooniColor.textMuted)
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(MooniColor.success).frame(width: 6, height: 6)
                    Text("Tracked automatically")
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.textSecondary)
                }
            }

            HStack(spacing: 20) {
                SleepScoreRing(score: 82, size: 116, lineWidth: 12)
                VStack(alignment: .leading, spacing: 12) {
                    statRow("bed.double.fill", "7h 36m", "Time asleep", MooniColor.accent)
                    statRow("moon.zzz.fill", "1h 04m", "Deep sleep", MooniColor.accentSoft)
                    statRow("bolt.fill", "74%", "Energy", MooniColor.warning)
                }
            }

            hypnoStrip
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [MooniColor.surfaceElevated.opacity(0.9),
                                 MooniColor.surface.opacity(0.92)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.16), .clear,
                                         MooniColor.accent.opacity(0.20)],
                                startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1))
                .shadow(color: MooniColor.accent.opacity(0.28), radius: 34, y: 16)
                .shadow(color: Color.black.opacity(0.4), radius: 14, y: 8)
        )
    }

    private func statRow(_ icon: String, _ value: String,
                         _ label: String, _ tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(MooniFont.title(19))
                    .foregroundColor(MooniColor.textPrimary)
                    .monospacedDigit()
                Text(label)
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var hypnoStrip: some View {
        // (width fraction, color) — a believable night, deep-heavy early on.
        let segs: [(CGFloat, Color)] = [
            (0.07, MooniColor.danger),
            (0.30, MooniColor.accent),
            (0.18, MooniColor.accentSoft),
            (0.17, MooniColor.warning),
            (0.28, MooniColor.accent)
        ]
        return VStack(spacing: 9) {
            GeometryReader { geo in
                HStack(spacing: 3) {
                    ForEach(Array(segs.enumerated()), id: \.offset) { _, s in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(s.1)
                            .frame(width: max(2, geo.size.width * s.0 - 3))
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 16)
            HStack {
                Text("11:42 PM")
                Spacer()
                Text("Deep · REM · Light")
                Spacer()
                Text("7:18 AM")
            }
            .font(MooniFont.caption(10))
            .foregroundColor(MooniColor.textMuted)
        }
    }

    // MARK: - App Store CTA

    private var appStoreCTA: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Download on the")
                        .font(MooniFont.caption(11))
                        .foregroundColor(.white.opacity(0.85))
                    Text("App Store")
                        .font(MooniFont.display(21))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.28), lineWidth: 1))
            )

            Text("Search \u{201C}SleepOwl\u{201D} on the App Store")
                .font(MooniFont.title(14))
                .foregroundColor(MooniColor.textSecondary)
        }
    }

    // MARK: - Reusable app icon

    private func appIcon(side: CGFloat, corner: CGFloat) -> some View {
        Image("app_icon")
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 0.5))
            .shadow(color: MooniColor.accent.opacity(0.45), radius: 12, y: 4)
    }

    // MARK: - Chrome

    private var chrome: some View {
        VStack {
            HStack {
                Button {
                    chromeTask?.cancel()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.55))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                Spacer()
            }
            Spacer()
        }
        .padding(.top, 8)
        .padding(.leading, 14)
        .opacity(showChrome ? 1 : 0)
        .allowsHitTesting(showChrome)
        .animation(.easeOut(duration: 0.45), value: showChrome)
    }

    private func scheduleChromeFade() {
        chromeTask?.cancel()
        chromeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.5)) { showChrome = false }
        }
    }
}

#Preview {
    MarketingPosterView()
}
