import SwiftUI
import UIKit

/// Card surfaced in the wind-down sheet every few nights, walking the
/// user through a system-level wind-down setting (Night Shift, Color
/// Filters, Sleep Focus). iOS forbids us from toggling those for them,
/// but a clear walk-through is the next best thing.
struct WindDownSystemTaskCard: View {
    let task: WindDownSystemTask

    var body: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: task.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(MooniColor.warning)
                        .frame(width: 36, height: 36)
                        .background(MooniColor.warning.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tonight's tip")
                            .font(MooniFont.caption(11))
                            .foregroundColor(MooniColor.accentText)
                            .textCase(.uppercase)
                        Text(task.title)
                            .font(MooniFont.title(17))
                            .foregroundColor(MooniColor.textPrimary)
                    }
                    Spacer()
                }

                Text(task.body)
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(task.steps.enumerated()), id: \.offset) { idx, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(idx + 1)")
                                .font(MooniFont.caption(12))
                                .foregroundColor(MooniColor.background)
                                .frame(width: 22, height: 22)
                                .background(MooniColor.accentSoft)
                                .clipShape(Circle())
                            Text(step)
                                .font(MooniFont.body(13))
                                .foregroundColor(MooniColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                    }
                }

                if let url = task.settingsURL {
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        HStack(spacing: 6) {
                            Text("Open Settings")
                                .font(MooniFont.title(13))
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(MooniColor.accentText)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
