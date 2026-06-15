import SwiftUI

// Reusable building blocks for the full-screen morning check-in. Each screen
// is "one question, big tap targets" — these are the pieces every scene snaps
// together from so the flow container stays readable.

// MARK: - Step scaffold

/// The shared top of every question screen: a glowing dream-spirit, a display
/// title, and an optional subtitle. The caller supplies just its control.
struct StepScaffold<Content: View>: View {
    let pet: Pet
    var spiritSize: CGFloat = 90
    var glow: Color = MooniColor.accent
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 26) {
            CheckInSpirit(pet: pet, size: spiritSize, glow: glow)

            VStack(spacing: 6) {
                Text(title)
                    .font(MooniFont.display(26))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(MooniFont.body(15))
                        .foregroundColor(MooniColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content()
        }
    }
}

/// The glowing dream-spirit used across the check-in.
struct CheckInSpirit: View {
    let pet: Pet
    var size: CGFloat = 90
    var glow: Color = MooniColor.accent

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [glow.opacity(0.35), .clear],
                        center: .center, startRadius: 4, endRadius: size
                    )
                )
                .frame(width: size * 1.9, height: size * 1.9)
            DreamSpiritView(pet: pet, size: size)
        }
    }
}

// MARK: - Minutes (star slider) step

/// A "how many minutes" question: a big live number, a one-line caption, a
/// glowing star slider, and an "I'm not sure" escape that stores nil.
struct MinutesStarStep: View {
    @Binding var minutes: Double
    @Binding var unknown: Bool
    var maxMinutes: Double = 180
    var lowLabel: String = "instant"
    var highLabel: String = "3+ hours"
    let caption: (Int) -> String

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(display)
                    .font(MooniFont.display(44))
                    .foregroundColor(MooniColor.warning)
                    .contentTransition(.numericText())
                Text(caption(Int(minutes.rounded())))
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 38)
            }
            .opacity(unknown ? 0.30 : 1.0)
            .animation(.easeInOut(duration: 0.25), value: unknown)

            StarSlider(value: $minutes, maxValue: maxMinutes, disabled: unknown)
                .padding(.horizontal, 4)
                .padding(.top, 4)

            HStack {
                Text(lowLabel)
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textMuted)
                Spacer()
                Text(highLabel)
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textMuted)
            }
            .padding(.horizontal, 4)
            .opacity(unknown ? 0.4 : 1)

            Toggle(isOn: $unknown.animation(.easeInOut(duration: 0.2))) {
                Text("I'm not sure")
                    .font(MooniFont.body(13))
                    .foregroundColor(MooniColor.textSecondary)
            }
            .tint(MooniColor.warning)
            .padding(.horizontal, 40)
            .padding(.top, 8)
        }
    }

    private var display: String { Self.minutesString(Int(minutes.rounded())) }

    static func minutesString(_ m: Int) -> String {
        if m >= 60 {
            let h = m / 60
            let rem = m % 60
            return rem == 0 ? "\(h) hr" : "\(h)h \(rem)m"
        }
        return "\(m) min"
    }
}

/// Glowing star thumb on a gradient track — drag to choose a minute value.
struct StarSlider: View {
    @Binding var value: Double
    var maxValue: Double = 180
    var disabled: Bool = false

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let pct = CGFloat(min(1, max(0, value / maxValue)))
            let thumbX = pct * width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 8)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [MooniColor.accent, MooniColor.warning],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, thumbX), height: 8)
                Image(systemName: "star.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(MooniColor.warning)
                    .shadow(color: MooniColor.warning.opacity(0.6), radius: 12)
                    .offset(x: thumbX - 12)
            }
            .frame(height: 36)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard !disabled else { return }
                        let clamped = max(0, min(width, drag.location.x))
                        let raw = Double(clamped / max(1, width)) * maxValue
                        let rounded = raw.rounded()
                        if rounded != value { Haptics.tick() }
                        value = rounded
                    }
            )
        }
        .frame(height: 36)
        .opacity(disabled ? 0.35 : 1.0)
    }
}

// MARK: - Selectable chip

/// A selectable emoji + label card — the workhorse for discrete choices
/// (dreams, room temp, alcohol, movement).
struct CheckInChip: View {
    let emoji: String
    let label: String
    let selected: Bool
    var verticalPadding: CGFloat = 16
    var emojiSize: CGFloat = 28
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: emojiSize))
                    .scaleEffect(selected ? 1.15 : 1.0)
                Text(label)
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, verticalPadding)
            .background(selected ? Color.white.opacity(0.22) : Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? MooniColor.warning : .white.opacity(0.08),
                            lineWidth: selected ? 1.5 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: selected)
    }
}

// MARK: - Stepper that reveals a time picker

/// A count stepper that reveals a clock-time picker once the count is ≥ 1.
/// Used for "how much caffeine yesterday / when was the last one".
struct StepperWithTimeReveal: View {
    @Binding var count: Int
    @Binding var time: Date
    var maxCount: Int = 6
    var unit: String = "drink"
    var revealPrompt: String = "Last one at"
    var revealIcon: String = "cup.and.saucer.fill"

    var body: some View {
        VStack(spacing: 22) {
            HStack(spacing: 22) {
                stepButton("minus") { if count > 0 { count -= 1; Haptics.tap() } }
                    .opacity(count > 0 ? 1 : 0.4)

                VStack(spacing: 2) {
                    Text(count >= maxCount ? "\(maxCount)+" : "\(count)")
                        .font(MooniFont.display(48))
                        .foregroundColor(MooniColor.warning)
                        .contentTransition(.numericText())
                    Text(count == 0 ? "none" : (count == 1 ? unit : "\(unit)s"))
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textMuted)
                }
                .frame(minWidth: 120)

                stepButton("plus") { if count < maxCount { count += 1; Haptics.tap() } }
                    .opacity(count < maxCount ? 1 : 0.4)
            }

            if count >= 1 {
                HStack(spacing: 10) {
                    Image(systemName: revealIcon)
                        .foregroundColor(MooniColor.warning)
                        .frame(width: 22)
                    Text(revealPrompt)
                        .font(MooniFont.body(15))
                        .foregroundColor(MooniColor.textSecondary)
                    Spacer()
                    DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .colorScheme(.dark)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.28), value: count >= 1)
    }

    private func stepButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(MooniColor.textPrimary)
                .frame(width: 52, height: 52)
                .background(Color.white.opacity(0.1))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Time wheel with optional toggle

/// A single clock-time question with an optional toggle below it.
/// Used for "when was your last meal" + "late & heavy?".
struct TimeWheelStep: View {
    @Binding var time: Date
    var icon: String = "fork.knife"
    var prompt: String
    var toggleLabel: String? = nil
    var toggleValue: Binding<Bool>? = nil

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(MooniColor.warning)
                    .frame(width: 24)
                Text(prompt)
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                Spacer()
                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .colorScheme(.dark)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if let toggleLabel, let toggleValue {
                Toggle(isOn: toggleValue) {
                    Text(toggleLabel)
                        .font(MooniFont.body(14))
                        .foregroundColor(MooniColor.textSecondary)
                }
                .tint(MooniColor.warning)
                .padding(.horizontal, 6)
                .padding(.top, 2)
            }
        }
    }
}

// MARK: - Yes/no that reveals a minutes slider

/// A yes / no choice that reveals a minutes slider when "yes". Used for naps.
struct ToggleRevealStep: View {
    @Binding var on: Bool
    @Binding var minutes: Double
    var maxMinutes: Double = 180
    var yesEmoji: String = "😴"
    var yesLabel: String = "Yes, I napped"
    var noEmoji: String = "🚫"
    var noLabel: String = "No nap"

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                CheckInChip(emoji: noEmoji, label: noLabel, selected: !on,
                            verticalPadding: 18) { on = false }
                CheckInChip(emoji: yesEmoji, label: yesLabel, selected: on,
                            verticalPadding: 18) { on = true }
            }

            if on {
                VStack(spacing: 8) {
                    Text(MinutesStarStep.minutesString(Int(minutes.rounded())))
                        .font(MooniFont.display(40))
                        .foregroundColor(MooniColor.warning)
                        .contentTransition(.numericText())
                    StarSlider(value: $minutes, maxValue: maxMinutes)
                        .padding(.horizontal, 4)
                    HStack {
                        Text("quick")
                            .font(MooniFont.caption(11))
                            .foregroundColor(MooniColor.textMuted)
                        Spacer()
                        Text("long")
                            .font(MooniFont.caption(11))
                            .foregroundColor(MooniColor.textMuted)
                    }
                    .padding(.horizontal, 4)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.28), value: on)
    }
}

// MARK: - Emoji scale slider

/// A horizontal slider that snaps between discrete emoji+label stops.
/// Almost nothing to read — you drag a thumb and the big emoji + one short
/// label update live. Used for the subjective scale questions.
struct EmojiScaleSlider: View {
    let stops: [(emoji: String, label: String)]
    @Binding var index: Int

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text(stops[safe: index]?.emoji ?? "🙂")
                    .font(.system(size: 66))
                    .contentTransition(.opacity)
                    .id(index)
                Text(stops[safe: index]?.label ?? "")
                    .font(MooniFont.title(20))
                    .foregroundColor(MooniColor.warning)
                    .contentTransition(.opacity)
            }

            GeometryReader { geo in
                let count = max(2, stops.count)
                let w = geo.size.width
                let stepW = w / CGFloat(count - 1)
                let clampedIndex = min(count - 1, max(0, index))
                let fillW = stepW * CGFloat(clampedIndex)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 6)
                    Capsule()
                        .fill(MooniColor.warning)
                        .frame(width: max(6, fillW), height: 6)

                    ForEach(0..<count, id: \.self) { i in
                        Circle()
                            .fill(i <= clampedIndex ? MooniColor.warning : Color.white.opacity(0.22))
                            .frame(width: 9, height: 9)
                            .offset(x: stepW * CGFloat(i) - 4.5)
                    }

                    Circle()
                        .fill(MooniColor.warning)
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 2))
                        .shadow(color: MooniColor.warning.opacity(0.6), radius: 8)
                        .offset(x: fillW - 15)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            let raw = max(0, min(w, v.location.x))
                            let i = Int((raw / stepW).rounded())
                            let clamped = min(count - 1, max(0, i))
                            if clamped != index {
                                Haptics.tap()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    index = clamped
                                }
                            }
                        }
                )
            }
            .frame(height: 44)

            HStack {
                Text(stops.first?.label ?? "")
                Spacer()
                Text(stops.last?.label ?? "")
            }
            .font(MooniFont.caption(11))
            .foregroundColor(MooniColor.textMuted)
        }
    }
}

private extension Array {
    subscript(safe i: Int) -> Element? {
        indices.contains(i) ? self[i] : nil
    }
}
