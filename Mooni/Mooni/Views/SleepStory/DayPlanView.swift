import SwiftUI

// MARK: - Forecast from app state

extension SleepForecast {
    @MainActor
    static func make(appState: AppState, entry: SleepEntry) -> SleepForecast {
        let debt = SleepInsights.sleepDebt(entries: appState.entries,
                                           goalHours: appState.goalHours)
        return make(
            entry: entry,
            goalHours: appState.goalHours,
            targetBedtime: appState.targetBedtime,
            targetWakeTime: appState.targetWakeTime,
            debtHours: debt
        )
    }
}

private extension SleepForecast.ForecastTint {
    var color: Color {
        switch self {
        case .neutral: return MooniColor.accent
        case .good:    return MooniColor.success
        case .caution: return MooniColor.warning
        }
    }
}

// MARK: - Day plan

/// "Your day, predicted." Time-stamped guidance from last night's sleep.
/// Visual-first: a single-hue energy curve plus clean timed rows. Colour
/// is used only to flag the few moments that matter (a hard dip, a good
/// window, tonight's target).
struct DayPlanView: View {
    enum Style { case homeCompact, full }

    let forecast: SleepForecast
    var style: Style = .full

    var body: some View {
        switch style {
        case .homeCompact: compact
        case .full:        full
        }
    }

    // MARK: Home — three moments that matter most

    private var compact: some View {
        MooniCard(padding: 18, cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 14) {
                Text("TODAY, PREDICTED")
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textMuted)
                    .tracking(1.8)

                EnergyCurve(points: forecast.energy)
                    .frame(height: 56)

                VStack(spacing: 0) {
                    let keys = forecast.moments.filter {
                        $0.kind == .dip || $0.kind == .workout || $0.kind == .bedtime
                    }
                    ForEach(Array(keys.enumerated()), id: \.element.id) { idx, m in
                        momentRow(m, compact: true)
                        if idx < keys.count - 1 {
                            Divider().background(Color.white.opacity(0.06))
                        }
                    }
                }
            }
        }
    }

    // MARK: Sleep tab — full plan

    private var full: some View {
        VStack(spacing: 16) {
            MooniCard(padding: 18, cornerRadius: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("YOUR DAY")
                            .font(MooniFont.caption(11))
                            .foregroundColor(MooniColor.textMuted)
                            .tracking(1.8)
                        Spacer()
                        Text("from last night")
                            .font(MooniFont.caption(10))
                            .foregroundColor(MooniColor.textMuted)
                    }
                    EnergyCurve(points: forecast.energy)
                        .frame(height: 92)
                    HStack {
                        Text("Wake")
                        Spacer()
                        Text("Midday")
                        Spacer()
                        Text("Night")
                    }
                    .font(MooniFont.caption(9))
                    .foregroundColor(MooniColor.textMuted)
                }
            }

            MooniCard(padding: 8, cornerRadius: 24) {
                VStack(spacing: 0) {
                    ForEach(Array(forecast.moments.enumerated()), id: \.element.id) { idx, m in
                        momentRow(m, compact: false)
                            .padding(.horizontal, 10)
                        if idx < forecast.moments.count - 1 {
                            Divider()
                                .background(Color.white.opacity(0.055))
                                .padding(.leading, 92)
                        }
                    }
                }
                .padding(.vertical, 6)
            }

            MooniCard(padding: 18, cornerRadius: 24) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TONIGHT — ASLEEP BY")
                            .font(MooniFont.caption(10))
                            .foregroundColor(MooniColor.textMuted)
                            .tracking(1.5)
                        Text(forecast.bedtimeText)
                            .font(MooniFont.display(40))
                            .foregroundColor(MooniColor.success)
                        Text(forecast.tonightReason)
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    VStack(spacing: 2) {
                        Text(forecast.sleepNeedText)
                            .font(MooniFont.title(20))
                            .foregroundColor(MooniColor.textPrimary)
                        Text("TARGET")
                            .font(MooniFont.caption(9))
                            .foregroundColor(MooniColor.textMuted)
                            .tracking(1)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(MooniColor.success.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    // MARK: Row

    private func momentRow(_ m: SleepForecast.Moment, compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(m.time)
                .font(MooniFont.title(compact ? 14 : 15))
                .foregroundColor(m.tint.color)
                .frame(width: 88, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Image(systemName: m.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(m.tint.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(m.title)
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textPrimary)
                if !compact {
                    Text(m.detail)
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, compact ? 11 : 12)
    }
}

// MARK: - Energy curve (single hue, no axes)

/// A smooth, calm area+line of predicted energy across the day. One colour.
private struct EnergyCurve: View {
    let points: [Double]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                fillPath(size: geo.size)
                    .fill(MooniColor.accent.opacity(0.14))
                linePath(size: geo.size)
                    .stroke(MooniColor.accent,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                marker(size: geo.size)
            }
        }
    }

    private func point(_ i: Int, _ size: CGSize) -> CGPoint {
        let n = max(points.count - 1, 1)
        let step = size.width / CGFloat(n)
        let v = CGFloat(min(max(points[i], 0), 1))
        return CGPoint(x: CGFloat(i) * step, y: size.height - v * (size.height - 6) - 3)
    }

    private func linePath(size: CGSize) -> Path {
        var p = Path()
        guard !points.isEmpty else { return p }
        p.move(to: point(0, size))
        for i in 1..<points.count {
            let prev = point(i - 1, size), cur = point(i, size)
            let midX = (prev.x + cur.x) / 2
            p.addCurve(to: cur,
                       control1: CGPoint(x: midX, y: prev.y),
                       control2: CGPoint(x: midX, y: cur.y))
        }
        return p
    }

    private func fillPath(size: CGSize) -> Path {
        var p = linePath(size: size)
        guard !points.isEmpty else { return p }
        p.addLine(to: CGPoint(x: size.width, y: size.height))
        p.addLine(to: CGPoint(x: 0, y: size.height))
        p.closeSubpath()
        return p
    }

    @ViewBuilder
    private func marker(size: CGSize) -> some View {
        if let lowIdx = points.indices.min(by: { points[$0] < points[$1] }) {
            Circle()
                .fill(MooniColor.warning)
                .frame(width: 8, height: 8)
                .position(point(lowIdx, size))
        }
    }
}
