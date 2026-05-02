import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var step: Int = 0
    @State private var petName: String = "Lumi"
    @State private var goalHours: Double = 8.0
    @State private var bedtime: Date = Date.todayAt(hour: 22, minute: 30)
    @State private var wakeTime: Date = Date.todayAt(hour: 7, minute: 0)
    @State private var factsVisible = false

    private let totalSteps = 8

    var body: some View {
        ZStack {
            MooniGradient.night.ignoresSafeArea()
            StarsBackground(count: 90)

            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                TabView(selection: $step) {
                    welcomeStep.tag(0)
                    sleepPowerStep.tag(1)
                    sleepCycleStep.tag(2)
                    dreamEnergyStep.tag(3)
                    meetLumiStep.tag(4)
                    petNameStep.tag(5)
                    goalStep.tag(6)
                    scheduleStep.tag(7)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: step)

                footer
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
            }
        }
        .onChange(of: step) { _, _ in
            factsVisible = false
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                factsVisible = true
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
                factsVisible = true
            }
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: 28) {
            Spacer()
            DreamSpiritView(pet: previewPet, size: 180)
            VStack(spacing: 14) {
                Text("Welcome to Mooni")
                    .font(MooniFont.display(36))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Your personal dream companion.\nBetter sleep, every night.")
                    .font(MooniFont.body(17))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 28)
            Spacer()
        }
    }

    // MARK: - Step 2: Sleep is Your Superpower

    private var sleepPowerStep: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(MooniColor.accent.opacity(0.15))
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 62))
                    .foregroundStyle(
                        LinearGradient(colors: [MooniColor.accentSoft, MooniColor.accent],
                                       startPoint: .top, endPoint: .bottom)
                    )
            }

            VStack(spacing: 10) {
                Text("Sleep is Your\nSuperpower")
                    .font(MooniFont.display(32))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("You spend 1/3 of your life asleep.\nMake every night count.")
                    .font(MooniFont.body(16))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                sleepFactRow(icon: "brain.head.profile", color: MooniColor.accent,
                             title: "Memory & Learning",
                             detail: "Sleep consolidates everything you learn each day")
                sleepFactRow(icon: "heart.fill", color: MooniColor.danger,
                             title: "Heart & Immunity",
                             detail: "Quality sleep reduces heart disease risk by 34%")
                sleepFactRow(icon: "bolt.fill", color: MooniColor.warning,
                             title: "Energy & Mood",
                             detail: "One bad night can cut your focus in half")
            }
            .padding(.horizontal, 8)
            .opacity(factsVisible ? 1 : 0)
            .offset(y: factsVisible ? 0 : 14)

            Spacer()
        }
        .padding(.horizontal, 22)
    }

    // MARK: - Step 3: Sleep Cycle

    private var sleepCycleStep: some View {
        VStack(spacing: 26) {
            Spacer()

            ZStack {
                Circle()
                    .fill(MooniColor.success.opacity(0.12))
                    .frame(width: 110, height: 110)
                    .blur(radius: 18)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 58))
                    .foregroundStyle(
                        LinearGradient(colors: [MooniColor.success, MooniColor.accent],
                                       startPoint: .leading, endPoint: .trailing)
                    )
            }

            VStack(spacing: 10) {
                Text("Your Brain at Night")
                    .font(MooniFont.display(32))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Sleep isn't passive — your brain works hard\nto heal and prepare you for tomorrow.")
                    .font(MooniFont.body(16))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                sleepCycleRow(phase: "Light Sleep", icon: "moon", color: MooniColor.accentSoft,
                              detail: "Transition into sleep, muscles relax")
                sleepCycleRow(phase: "Deep Sleep", icon: "zzz", color: MooniColor.accent,
                              detail: "Body repairs tissue, strengthens immunity")
                sleepCycleRow(phase: "REM Sleep", icon: "sparkles", color: MooniColor.warning,
                              detail: "Brain processes emotions & locks in memories")
            }
            .padding(.horizontal, 8)
            .opacity(factsVisible ? 1 : 0)
            .offset(y: factsVisible ? 0 : 14)

            Text("Each cycle takes ~90 minutes. Aim for 5–6 complete cycles.")
                .font(MooniFont.caption(13))
                .foregroundColor(MooniColor.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .opacity(factsVisible ? 1 : 0)

            Spacer()
        }
        .padding(.horizontal, 22)
    }

    // MARK: - Step 4: Dream Energy

    private var dreamEnergyStep: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(MooniColor.warning.opacity(0.14))
                    .frame(width: 110, height: 110)
                    .blur(radius: 18)
                Image(systemName: "sparkles")
                    .font(.system(size: 58))
                    .foregroundStyle(
                        LinearGradient(colors: [Color.yellow, MooniColor.warning],
                                       startPoint: .top, endPoint: .bottom)
                    )
            }

            VStack(spacing: 10) {
                Text("Dream Energy")
                    .font(MooniFont.display(32))
                    .foregroundColor(MooniColor.textPrimary)
                Text("Every good night charges your spirit")
                    .font(MooniFont.body(16))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                energyExplainRow(icon: "moon.zzz.fill", color: MooniColor.accent,
                                 title: "Sleep well → earn Dream Energy",
                                 detail: "Scored on duration, quality & consistency")
                energyExplainRow(icon: "arrow.up.circle.fill", color: MooniColor.success,
                                 title: "Energy → level up your spirit",
                                 detail: "Each level unlocks new looks & items")
                energyExplainRow(icon: "checklist", color: MooniColor.warning,
                                 title: "Routines give bonus energy",
                                 detail: "Complete wind-down habits for extra points")
            }
            .padding(.horizontal, 8)
            .opacity(factsVisible ? 1 : 0)
            .offset(y: factsVisible ? 0 : 14)

            Spacer()
        }
        .padding(.horizontal, 22)
    }

    // MARK: - Step 5: Meet Lumi

    private var meetLumiStep: some View {
        VStack(spacing: 24) {
            Spacer()

            DreamSpiritView(pet: previewPet, size: 170)

            VStack(spacing: 12) {
                Text("Meet Your Dream Spirit")
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Your spirit reflects how you've been sleeping.\nCare for your sleep — and your spirit glows.")
                    .font(MooniFont.body(16))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            VStack(spacing: 8) {
                moodRow(mood: "Rested", icon: "sparkles", color: MooniColor.success,
                        desc: "Score 85+ — spirit shines & sparkles")
                moodRow(mood: "Calm", icon: "moon.fill", color: MooniColor.accent,
                        desc: "Score 70–84 — spirit glows softly")
                moodRow(mood: "Sleepy", icon: "zzz", color: MooniColor.warning,
                        desc: "Score 50–69 — spirit needs rest")
                moodRow(mood: "Low", icon: "moon.zzz.fill", color: MooniColor.textMuted,
                        desc: "Score <50 — spirit wraps in a blanket")
            }
            .padding(.horizontal, 8)
            .opacity(factsVisible ? 1 : 0)
            .offset(y: factsVisible ? 0 : 14)

            Spacer()
        }
        .padding(.horizontal, 22)
    }

    // MARK: - Step 6: Name

    private var petNameStep: some View {
        VStack(spacing: 26) {
            Spacer()
            DreamSpiritView(pet: previewPet, size: 148)
            VStack(spacing: 10) {
                Text("Name Your Spirit")
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
                Text("What will you call them?")
                    .font(MooniFont.body(16))
                    .foregroundColor(MooniColor.textSecondary)
            }
            TextField("", text: $petName, prompt: Text("Lumi").foregroundColor(MooniColor.textMuted))
                .font(MooniFont.title(22))
                .multilineTextAlignment(.center)
                .foregroundColor(MooniColor.textPrimary)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(MooniColor.accent.opacity(0.4), lineWidth: 1)
                )
                .padding(.horizontal, 40)
            Text("You can change this later.")
                .font(MooniFont.caption(13))
                .foregroundColor(MooniColor.textMuted)
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 7: Goal

    private var goalStep: some View {
        VStack(spacing: 26) {
            Spacer()

            ZStack {
                Circle()
                    .fill(MooniColor.accent.opacity(0.14))
                    .frame(width: 110, height: 110)
                    .blur(radius: 18)
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 58))
                    .foregroundStyle(
                        LinearGradient(colors: [MooniColor.accentSoft, MooniColor.accent],
                                       startPoint: .top, endPoint: .bottom)
                    )
            }

            VStack(spacing: 8) {
                Text("Your Sleep Goal")
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
                Text("Adults need 7–9 hours for optimal health.\nChoose your nightly target.")
                    .font(MooniFont.body(16))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Text("\(goalHours, specifier: "%.1f") hours")
                .font(MooniFont.display(44))
                .foregroundStyle(
                    LinearGradient(colors: [MooniColor.accentSoft, MooniColor.accent],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .padding(.top, 8)

            Slider(value: $goalHours, in: 5.0...10.0, step: 0.25)
                .tint(MooniColor.accent)
                .padding(.horizontal, 30)

            HStack {
                Text("5h")
                Spacer()
                Text("Recommended: 7–9h")
                    .foregroundColor(MooniColor.accent)
                Spacer()
                Text("10h")
            }
            .font(MooniFont.caption(12))
            .foregroundColor(MooniColor.textMuted)
            .padding(.horizontal, 30)

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Step 8: Schedule

    private var scheduleStep: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(MooniColor.success.opacity(0.12))
                    .frame(width: 110, height: 110)
                    .blur(radius: 18)
                Image(systemName: "clock.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(colors: [MooniColor.success, MooniColor.accentSoft],
                                       startPoint: .top, endPoint: .bottom)
                    )
            }

            VStack(spacing: 8) {
                Text("Set Your Schedule")
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
                Text("Consistency is key. A regular schedule\nresets your body clock within days.")
                    .font(MooniFont.body(16))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                timeRow(title: "Bedtime", icon: "moon.fill", color: MooniColor.accent, selection: $bedtime)
                timeRow(title: "Wake up", icon: "sun.max.fill", color: MooniColor.warning, selection: $wakeTime)
            }
            .padding(.top, 8)
            .padding(.horizontal, 4)

            let hours = Calendar.current.dateComponents([.hour, .minute], from: bedtime, to: wakeTime > bedtime ? wakeTime : wakeTime.addingTimeInterval(86400))
            let h = (hours.hour ?? 0) + (hours.minute ?? 0 >= 30 ? 1 : 0)
            Text("That's ~\(h) hours of sleep")
                .font(MooniFont.caption(13))
                .foregroundColor(h >= 7 && h <= 9 ? MooniColor.success : MooniColor.warning)
                .animation(.easeInOut, value: bedtime)
                .animation(.easeInOut, value: wakeTime)

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Reusable Row Builders

    private func sleepFactRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MooniFont.title(14))
                    .foregroundColor(MooniColor.textPrimary)
                Text(detail)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sleepCycleRow(phase: String, icon: String, color: Color, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.14))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(phase)
                    .font(MooniFont.title(14))
                    .foregroundColor(MooniColor.textPrimary)
                Text(detail)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func energyExplainRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MooniFont.title(14))
                    .foregroundColor(MooniColor.textPrimary)
                Text(detail)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func moodRow(mood: String, icon: String, color: Color, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(color)
                .frame(width: 28)
            Text(mood)
                .font(MooniFont.title(13))
                .foregroundColor(MooniColor.textPrimary)
                .frame(width: 60, alignment: .leading)
            Text(desc)
                .font(MooniFont.caption(12))
                .foregroundColor(MooniColor.textSecondary)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func timeRow(title: String, icon: String, color: Color, selection: Binding<Date>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 28)
            Text(title)
                .font(MooniFont.title(16))
                .foregroundColor(MooniColor.textPrimary)
            Spacer()
            DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .colorScheme(.dark)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if step > 0 {
                SecondaryButton(title: "Back") {
                    withAnimation { step -= 1 }
                }
                .frame(maxWidth: 100)
            }
            PrimaryButton(title: step == totalSteps - 1 ? "Begin Journey" : "Continue") {
                if step == totalSteps - 1 {
                    appState.completeOnboarding(
                        name: petName.trimmingCharacters(in: .whitespaces).isEmpty ? "Lumi" : petName,
                        goalHours: goalHours,
                        bedtime: bedtime,
                        wakeTime: wakeTime
                    )
                } else {
                    withAnimation { step += 1 }
                }
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(
                        LinearGradient(colors: [MooniColor.accentSoft, MooniColor.accent],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: geo.size.width * CGFloat(step + 1) / CGFloat(totalSteps))
                    .animation(.spring(response: 0.4), value: step)
            }
        }
        .frame(height: 4)
    }

    private var previewPet: Pet {
        var p = Pet()
        p.name = petName.isEmpty ? "Lumi" : petName
        p.mood = .rested
        p.equippedHat = "hat_nightcap"
        return p
    }
}

#Preview {
    OnboardingView().environmentObject(AppState())
}
