import SwiftUI

/// The Home screen's coaching hero: the single thing to do *tonight*, produced
/// by `SleepCoach`. This is the visible promise of "SleepOwl fixes my sleep" —
/// one action, the reason, the payoff, and a button to act on it now.
struct TonightFixCard: View {
    let fix: SleepCoach.TonightFix
    var onAction: () -> Void

    var body: some View {
        MooniCard(padding: 18, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 12) {
                    Image(systemName: fix.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(fix.tint)
                        .frame(width: 44, height: 44)
                        .background(fix.tint.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("TONIGHT'S FIX")
                            .font(MooniFont.caption(10))
                            .tracking(1.5)
                            .foregroundColor(fix.tint)
                        Text(fix.title)
                            .font(MooniFont.title(17))
                            .foregroundColor(MooniColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                Text(fix.why)
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                    Text(fix.payoff)
                        .font(MooniFont.caption(12.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundColor(fix.tint)

                Button {
                    Haptics.tap()
                    onAction()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(fix.actionLabel)
                            .font(MooniFont.title(14))
                    }
                    .foregroundColor(MooniColor.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(fix.tint)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
