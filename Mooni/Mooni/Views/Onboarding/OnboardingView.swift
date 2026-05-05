import SwiftUI

/// 14-screen onboarding flow.
/// The order matches the product spec: emotional hook → pet → name → demo →
/// goal → schedule → reflection → room → notification → health → preview →
/// loading → first quest → soft paywall.
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var health = HealthKitManager.shared
    @StateObject private var notifications = NotificationManager.shared

    // MARK: - Wizard state
    @State private var step: Int = 0

    // Pet
    @State private var species: PetSpecies = .fox
    @State private var petName: String = PetSpecies.fox.defaultName

    // Goal & schedule
    @State private var sleepGoal: SleepGoal? = nil
    @State private var bedtime: Date = Date.todayAt(hour: 22, minute: 45)
    @State private var wakeTime: Date = Date.todayAt(hour: 7, minute: 0)
    @State private var weekendWake: Date = Date.todayAt(hour: 8, minute: 30)
    @State private var separateWeekends: Bool = false

    // Room
    @State private var room: PetRoom = .moonBedroom

    // Demo (Screen 4) state
    @State private var demoStage: Int = 0   // 0 short / 1 long / 2 consistent

    // Loading screen (Screen 12)
    @State private var planMessageIndex: Int = 0
    @State private var planProgress: Double = 0

    // Paywall (Screen 14)
    @State private var paywallShown: Bool = false

    private let totalSteps = 14

    var body: some View {
        ZStack {
            backgroundForStep
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: step)

            StarsBackground(count: 80)
                .opacity(step == 7 ? 0.6 : 1.0)

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                footer
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Background
    @ViewBuilder
    private var backgroundForStep: some View {
        switch step {
        case 7:  room.gradient                         // Room preview
        case 8:  PetRoom.cozyForest.gradient           // Notification — warm
        case 11: MooniGradient.dawn                    // Loading screen
        default: MooniGradient.night
        }
    }

    // MARK: - Top progress bar
    private var topBar: some View {
        HStack(spacing: 12) {
            if step > 0 && step < totalSteps - 1 {
                Button {
                    withAnimation { step -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(MooniColor.textSecondary)
                        .padding(8)
                        .background(Color.white.opacity(0.10))
                        .clipShape(Circle())
                }
            } else {
                Spacer().frame(width: 32, height: 32)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(LinearGradient(colors: [MooniColor.accentSoft, MooniColor.accent],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(step + 1) / CGFloat(totalSteps))
                        .animation(.spring(response: 0.4), value: step)
                }
            }
            .frame(height: 4)

            Spacer().frame(width: 32, height: 32)
        }
    }

    // MARK: - Content
    @ViewBuilder
    private var content: some View {
        switch step {
        case 0:  HookScreen()
        case 1:  PickPetScreen(selected: $species, onPick: { picked in
                    species = picked
                    petName = picked.defaultName
                 })
        case 2:  NamePetScreen(species: species, name: $petName)
        case 3:  DemoScreen(species: species, stage: $demoStage)
        case 4:  GoalScreen(selection: $sleepGoal)
        case 5:  ScheduleScreen(bedtime: $bedtime, wakeTime: $wakeTime,
                                separateWeekends: $separateWeekends, weekendWake: $weekendWake)
        case 6:  ReflectionScreen(petName: petName, bedtime: bedtime, wakeTime: wakeTime)
        case 7:  RoomPickerScreen(species: species, name: petName, selection: $room)
        case 8:  NotificationPermissionScreen(petName: petName, state: notifications.authState)
        case 9:  HealthPermissionScreen(petName: petName, state: health.authState)
        case 10: SimulatedResultScreen(species: species, name: petName)
        case 11: GeneratingPlanScreen(progress: $planProgress, messageIndex: $planMessageIndex)
                    .onAppear { runGeneratingAnimation() }
        case 12: FirstQuestScreen(petName: petName, bedtime: bedtime, wakeTime: wakeTime)
        case 13: SoftPaywallScreen(petName: petName, goal: sleepGoal, onContinueFree: finishOnboarding)
        default: EmptyView()
        }
    }

    // MARK: - Footer
    private var footer: some View {
        Group {
            switch step {
            case 8:
                // Notification permission: dual buttons
                VStack(spacing: 10) {
                    PrimaryButton(title: "Yes, remind me", icon: "bell.fill") {
                        Task {
                            if notifications.authState == .notDetermined {
                                _ = await notifications.requestAuthorization()
                            }
                            advance()
                        }
                    }
                    SecondaryButton(title: "Not now") { advance() }
                }
            case 9:
                // Health permission: dual buttons
                VStack(spacing: 10) {
                    PrimaryButton(title: "Connect Apple Health", icon: "heart.text.square.fill") {
                        Task {
                            if health.authState == .notDetermined && health.isAvailable {
                                _ = await health.requestAuthorization()
                                if health.authState == .authorized {
                                    await appState.importHealthKitSleep()
                                }
                            }
                            advance()
                        }
                    }
                    SecondaryButton(title: "I'll add sleep manually") { advance() }
                }
            case 11:
                // Loading screen advances itself — no button
                EmptyView()
            case 13:
                // Paywall has its own buttons
                EmptyView()
            default:
                PrimaryButton(title: primaryTitle) { advance() }
                    .disabled(!canAdvance)
                    .opacity(canAdvance ? 1 : 0.5)
            }
        }
    }

    private var primaryTitle: String {
        switch step {
        case 0:  return "Meet your sleep pet"
        case 1:  return "Choose \(species.defaultName)"
        case 2:  return "\(petName.isEmpty ? species.defaultName : petName) is officially yours"
        case 3:  return demoStage < 2 ? "Continue" : "Got it"
        case 4:  return sleepGoal == nil ? "Pick one to continue" : "Continue"
        case 5:  return "Continue"
        case 6:  return "Continue"
        case 7:  return "Build \(petName)'s room"
        case 10: return "See how it works"
        case 12: return "Accept tonight's quest"
        default: return "Continue"
        }
    }

    private var canAdvance: Bool {
        switch step {
        case 4:  return sleepGoal != nil
        case 2:  return !petName.trimmingCharacters(in: .whitespaces).isEmpty
        default: return true
        }
    }

    // MARK: - Advance
    private func advance() {
        // Special demo screen: cycle internally before advancing
        if step == 3 && demoStage < 2 {
            withAnimation(.easeInOut) { demoStage += 1 }
            return
        }
        withAnimation(.easeInOut(duration: 0.35)) {
            step = min(step + 1, totalSteps - 1)
        }
    }

    private func runGeneratingAnimation() {
        planProgress = 0
        planMessageIndex = 0
        let messages = GeneratingPlanScreen.messages.count
        let stepDuration = 0.9
        for i in 0..<messages {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * stepDuration) {
                withAnimation(.easeInOut) {
                    planMessageIndex = i
                    planProgress = Double(i + 1) / Double(messages)
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(messages) * stepDuration + 0.4) {
            advance()
        }
    }

    private func finishOnboarding() {
        appState.completeOnboarding(
            species: species,
            name: petName,
            goal: sleepGoal ?? .wakeUpLessTired,
            goalHours: hoursBetween(bedtime, wakeTime),
            bedtime: bedtime,
            wakeTime: wakeTime,
            weekendWake: separateWeekends ? weekendWake : nil,
            room: room
        )

        // Schedule the bedtime nudge if user opted in.
        if notifications.authState == .authorized {
            notifications.scheduleNightlyBedtimeNudge(petName: petName, bedtime: bedtime)
        }
    }

    private func hoursBetween(_ a: Date, _ b: Date) -> Double {
        let cal = Calendar.current
        var end = b
        if end <= a { end = cal.date(byAdding: .day, value: 1, to: end) ?? end }
        let mins = cal.dateComponents([.minute], from: a, to: end).minute ?? 0
        return Double(mins) / 60.0
    }
}

// MARK: - Screen 1: Emotional hook
private struct HookScreen: View {
    @State private var glow = false
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Image(systemName: "moon.fill")
                    .font(.system(size: 90))
                    .foregroundStyle(LinearGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent],
                        startPoint: .top, endPoint: .bottom))
                    .offset(x: 70, y: -90)
                    .opacity(0.85)
                DreamSpiritView(pet: previewPet, size: 170)
                    .scaleEffect(glow ? 1.02 : 0.98)
                    .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: glow)
            }
            VStack(spacing: 12) {
                Text("Your sleep shapes\ntheir world.")
                    .font(MooniFont.display(34))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                Text("Raise a pet by improving your sleep.")
                    .font(MooniFont.body(16))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            Spacer()
        }
        .onAppear { glow = true }
    }

    private var previewPet: Pet {
        var p = Pet(); p.species = .fox; p.mood = .sleepy; p.equippedColor = "default_color"; p.equippedHat = nil
        return p
    }
}

// MARK: - Screen 2: Pick pet
private struct PickPetScreen: View {
    @Binding var selected: PetSpecies
    let onPick: (PetSpecies) -> Void

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text("Meet your sleep pet")
                    .font(MooniFont.display(28))
                    .foregroundColor(MooniColor.textPrimary)
                Text("Pick the one that feels like you.")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
            }
            .padding(.top, 8)

            VStack(spacing: 14) {
                ForEach(PetSpecies.allCases) { sp in
                    PetCardRow(species: sp, isSelected: selected == sp) {
                        withAnimation(.spring(response: 0.35)) {
                            selected = sp
                            onPick(sp)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)

            if selected != .fox || true {
                Text("\(selected.defaultName) chose you too.")
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.accentSoft)
                    .transition(.opacity)
                    .id(selected)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

private struct PetCardRow: View {
    let species: PetSpecies
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(species.tint.opacity(0.30))
                        .frame(width: 64, height: 64)
                    Image(systemName: species.icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(species.tint)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(species.defaultName) the \(species.displayName)")
                        .font(MooniFont.title(17))
                        .foregroundColor(MooniColor.textPrimary)
                    Text(species.tagline)
                        .font(MooniFont.caption(13))
                        .foregroundColor(MooniColor.textSecondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? MooniColor.accent : MooniColor.textMuted)
                    .font(.system(size: 22))
            }
            .padding(16)
            .background(Color.white.opacity(isSelected ? 0.12 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? species.tint : Color.white.opacity(0.10),
                            lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Screen 3: Name pet
private struct NamePetScreen: View {
    let species: PetSpecies
    @Binding var name: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            DreamSpiritView(pet: previewPet, size: 150)
            VStack(spacing: 8) {
                Text("What should we call your sleep buddy?")
                    .font(MooniFont.title(20))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("You can change this later.")
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.textMuted)
            }
            TextField("", text: $name,
                      prompt: Text(species.defaultName).foregroundColor(MooniColor.textMuted))
                .font(MooniFont.title(22))
                .multilineTextAlignment(.center)
                .foregroundColor(MooniColor.textPrimary)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(species.tint.opacity(0.45), lineWidth: 1)
                )
                .padding(.horizontal, 32)
                .focused($focused)
                .submitLabel(.done)
            Spacer()
        }
        .padding(.horizontal, 20)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
        }
    }

    private var previewPet: Pet {
        var p = Pet(); p.species = species; p.mood = .cozy; p.equippedColor = "default_color"; p.equippedHat = nil
        return p
    }
}

// MARK: - Screen 4: Core mechanic demo
private struct DemoScreen: View {
    let species: PetSpecies
    @Binding var stage: Int

    private var caption: String {
        switch stage {
        case 0: return "Short sleep makes \(species.defaultName) groggy."
        case 1: return "Good sleep helps \(species.defaultName) grow."
        default: return "Consistency unlocks new dreams."
        }
    }

    private var subtitle: String {
        switch stage {
        case 0: return "5 hours sleep"
        case 1: return "7.5 hours sleep"
        default: return "Consistent bedtime"
        }
    }

    private var demoPet: Pet {
        var p = Pet(); p.species = species
        p.mood = stage == 0 ? .groggy : (stage == 1 ? .cozy : .energized)
        p.equippedHat = nil
        return p
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            DreamSpiritView(pet: demoPet, size: 170)
                .id(stage)
                .transition(.scale.combined(with: .opacity))
            VStack(spacing: 8) {
                Text(subtitle)
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.textMuted)
                Text(caption)
                    .font(MooniFont.title(20))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    Capsule()
                        .fill(i <= stage ? MooniColor.accent : Color.white.opacity(0.18))
                        .frame(width: i == stage ? 22 : 10, height: 4)
                        .animation(.spring(response: 0.35), value: stage)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Screen 5: Goal
private struct GoalScreen: View {
    @Binding var selection: SleepGoal?

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text("What do you want help with most?")
                    .font(MooniFont.display(24))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                Text("We'll personalize your plan around this.")
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.textSecondary)
            }
            .padding(.top, 6)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(SleepGoal.allCases) { goal in
                        GoalRow(goal: goal, selected: selection == goal) {
                            withAnimation(.spring(response: 0.3)) { selection = goal }
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct GoalRow: View {
    let goal: SleepGoal
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: goal.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(selected ? MooniColor.accent : MooniColor.accentSoft)
                    .frame(width: 38, height: 38)
                    .background((selected ? MooniColor.accent : MooniColor.accentSoft).opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(goal.title)
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selected ? MooniColor.accent : MooniColor.textMuted)
                    .font(.system(size: 20))
            }
            .padding(14)
            .background(Color.white.opacity(selected ? 0.12 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? MooniColor.accent : Color.white.opacity(0.10),
                            lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Screen 6: Schedule
private struct ScheduleScreen: View {
    @Binding var bedtime: Date
    @Binding var wakeTime: Date
    @Binding var separateWeekends: Bool
    @Binding var weekendWake: Date

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("When do you usually want to sleep?")
                    .font(MooniFont.display(22))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Don't worry — you can fine-tune later.")
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.textSecondary)
            }
            .padding(.top, 6)

            VStack(spacing: 12) {
                timeRow(title: "Bedtime", icon: "moon.fill",
                        color: MooniColor.accent, selection: $bedtime)
                timeRow(title: "Wake up", icon: "sun.max.fill",
                        color: MooniColor.warning, selection: $wakeTime)

                Toggle(isOn: $separateWeekends) {
                    Text("Different wake time on weekends")
                        .font(MooniFont.caption(13))
                        .foregroundColor(MooniColor.textSecondary)
                }
                .tint(MooniColor.accent)
                .padding(.horizontal, 4)

                if separateWeekends {
                    timeRow(title: "Weekend wake", icon: "calendar",
                            color: MooniColor.accentSoft, selection: $weekendWake)
                }
            }
            .padding(.horizontal, 4)

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func timeRow(title: String, icon: String, color: Color,
                         selection: Binding<Date>) -> some View {
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
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Screen 7: Reflection
private struct ReflectionScreen: View {
    let petName: String
    let bedtime: Date
    let wakeTime: Date

    private var windowText: String {
        "\(bedtime.hourMinuteString)–\(wakeTime.hourMinuteString)"
    }

    private var hoursText: String {
        let cal = Calendar.current
        var end = wakeTime
        if end <= bedtime { end = cal.date(byAdding: .day, value: 1, to: end) ?? end }
        let mins = cal.dateComponents([.minute], from: bedtime, to: end).minute ?? 0
        let h = mins / 60
        let m = mins % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            ZStack {
                Circle()
                    .fill(MooniColor.accent.opacity(0.16))
                    .frame(width: 110, height: 110)
                    .blur(radius: 18)
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(LinearGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent],
                        startPoint: .top, endPoint: .bottom))
            }

            VStack(spacing: 10) {
                Text("Your target sleep window is")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                Text(windowText)
                    .font(MooniFont.display(36))
                    .foregroundColor(MooniColor.textPrimary)
                Text("That gives \(petName) about \(hoursText) to recover.")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Text("Even 30 minutes less sleep each night can build up over the week.")
                .font(MooniFont.caption(13))
                .foregroundColor(MooniColor.warning)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 4)

            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Screen 8: Room picker
private struct RoomPickerScreen: View {
    let species: PetSpecies
    let name: String
    @Binding var selection: PetRoom

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("Pick \(name)'s first room")
                    .font(MooniFont.display(24))
                    .foregroundColor(MooniColor.textPrimary)
                Text("You'll unlock more rooms as you grow.")
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.textSecondary)
            }
            .padding(.top, 6)

            // Preview
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(selection.gradient)
                    .frame(height: 170)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                DreamSpiritView(pet: previewPet, size: 110)
            }
            .padding(.horizontal, 4)

            // Picker
            HStack(spacing: 10) {
                ForEach(PetRoom.allCases) { r in
                    RoomChip(room: r, selected: selection == r) {
                        withAnimation(.spring(response: 0.35)) { selection = r }
                    }
                }
            }
            .padding(.horizontal, 4)

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var previewPet: Pet {
        var p = Pet(); p.species = species; p.mood = .calm; p.equippedHat = nil
        return p
    }
}

private struct RoomChip: View {
    let room: PetRoom
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(room.gradient)
                        .frame(height: 60)
                    Image(systemName: room.icon)
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.9))
                }
                Text(room.displayName)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textPrimary)
            }
            .padding(8)
            .background(Color.white.opacity(selected ? 0.12 : 0.04))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? MooniColor.accent : Color.white.opacity(0.10),
                            lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Screen 9: Notification permission
private struct NotificationPermissionScreen: View {
    let petName: String
    let state: NotificationManager.AuthState

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle().fill(MooniColor.warning.opacity(0.16))
                    .frame(width: 110, height: 110).blur(radius: 18)
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(LinearGradient(
                        colors: [Color.yellow, MooniColor.warning],
                        startPoint: .top, endPoint: .bottom))
            }
            VStack(spacing: 10) {
                Text("Should \(petName) remind you when it's time to wind down?")
                    .font(MooniFont.title(20))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                Text("We'll send gentle bedtime reminders, not spam.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            previewBubble
                .padding(.top, 8)

            if state == .authorized {
                Label("Reminders enabled", systemImage: "checkmark.seal.fill")
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.success)
            } else if state == .denied {
                Text("You can enable reminders later in Settings.")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.warning)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var previewBubble: some View {
        HStack {
            Image(systemName: "bell.fill")
                .foregroundColor(MooniColor.accent)
                .padding(8)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("\(petName) is getting sleepy…")
                    .font(MooniFont.title(13))
                    .foregroundColor(MooniColor.textPrimary)
                Text("Tap to start tonight's wind-down.")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }
}

// MARK: - Screen 10: Health permission
private struct HealthPermissionScreen: View {
    let petName: String
    let state: HealthKitManager.AuthState

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(MooniColor.danger.opacity(0.16))
                    .frame(width: 110, height: 110).blur(radius: 18)
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(LinearGradient(
                        colors: [Color.pink, MooniColor.danger],
                        startPoint: .top, endPoint: .bottom))
            }
            VStack(spacing: 10) {
                Text("Connect sleep data so \(petName) can wake up with you.")
                    .font(MooniFont.title(19))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                Text("Your sleep duration and consistency will shape \(petName)'s mood.")
                    .font(MooniFont.body(14))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 8) {
                infoRow(icon: "moon.zzz.fill", title: "Auto-detect bedtime & wake-up")
                infoRow(icon: "lock.shield.fill", title: "Private — read only")
                infoRow(icon: "iphone.gen3", title: "Works without an Apple Watch")
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)

            if state == .authorized {
                Label("Connected to Apple Health", systemImage: "checkmark.seal.fill")
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.success)
            } else if state == .denied {
                Text("Permission denied. You can enable it later in Settings → Health.")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.warning)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func infoRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(MooniColor.accent)
                .frame(width: 28)
            Text(title)
                .font(MooniFont.caption(13))
                .foregroundColor(MooniColor.textSecondary)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Screen 11: Simulated first result
private struct SimulatedResultScreen: View {
    let species: PetSpecies
    let name: String

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Tomorrow morning, \(name) will wake up like this…")
                    .font(MooniFont.title(18))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 6)

            VStack(spacing: 12) {
                outcomeCard(mood: .energized, label: "Great sleep",
                            detail: "Bright room, happy pet, full energy.")
                outcomeCard(mood: .calm, label: "Okay sleep",
                            detail: "Steady mood. \(name) is normal.")
                outcomeCard(mood: .groggy, label: "Poor sleep",
                            detail: "Tired pet, dim room — easy to recover.")
            }
            .padding(.horizontal, 4)
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func outcomeCard(mood: Pet.Mood, label: String, detail: String) -> some View {
        var p = Pet(); p.species = species; p.mood = mood; p.equippedHat = nil
        return HStack(spacing: 14) {
            DreamSpiritView(pet: p, size: 56)
                .frame(width: 80, height: 80)
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textPrimary)
                Text(detail)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Screen 12: Generating plan
private struct GeneratingPlanScreen: View {
    @Binding var progress: Double
    @Binding var messageIndex: Int

    static let messages: [String] = [
        "Learning your sleep rhythm…",
        "Building your first bedtime quest…",
        "Preparing your dream room…",
        "Tuning your wake-up window…"
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 6)
                    .frame(width: 120, height: 120)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(LinearGradient(colors: [MooniColor.accentSoft, MooniColor.accent],
                                           startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)
                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundColor(MooniColor.accentSoft)
            }
            Text(Self.messages[min(messageIndex, Self.messages.count - 1)])
                .font(MooniFont.title(17))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .id(messageIndex)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Screen 13: First quest
private struct FirstQuestScreen: View {
    let petName: String
    let bedtime: Date
    let wakeTime: Date

    private var windDownTime: String {
        let d = bedtime.addingTimeInterval(-30 * 60)
        return d.hourMinuteString
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("Tonight's quest")
                    .font(MooniFont.caption(14))
                    .foregroundColor(MooniColor.accentSoft)
                    .textCase(.uppercase)
                Text("Help \(petName) get cozy")
                    .font(MooniFont.display(26))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 8)

            VStack(spacing: 10) {
                questRow(icon: "leaf.fill", title: "Start wind-down by \(windDownTime)")
                questRow(icon: "iphone.slash", title: "Avoid phone in bed")
                questRow(icon: "sun.max.fill", title: "Wake up around \(wakeTime.hourMinuteString)")
            }
            .padding(.horizontal, 4)

            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(MooniColor.warning)
                Text("Reward: 20 dream stars")
                    .font(MooniFont.title(14))
                    .foregroundColor(MooniColor.textPrimary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 18)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
            .padding(.top, 6)

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func questRow(icon: String, title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(MooniColor.accent)
                .frame(width: 36, height: 36)
                .background(MooniColor.accent.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title)
                .font(MooniFont.title(15))
                .foregroundColor(MooniColor.textPrimary)
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Screen 14: Soft paywall
private struct SoftPaywallScreen: View {
    let petName: String
    let goal: SleepGoal?
    let onContinueFree: () -> Void

    @StateObject private var manager = SubscriptionManager.shared
    @State private var showPaywallSheet = false

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").foregroundColor(MooniColor.warning)
                    Text("Help \(petName) grow faster")
                        .font(MooniFont.display(24))
                        .foregroundColor(MooniColor.textPrimary)
                    Image(systemName: "sparkles").foregroundColor(MooniColor.warning)
                }
                .multilineTextAlignment(.center)
                if let g = goal {
                    Text(g.promise)
                        .font(MooniFont.body(14))
                        .foregroundColor(MooniColor.accentSoft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.top, 6)

            VStack(spacing: 8) {
                proRow(icon: "chart.bar.fill", title: "Advanced sleep coaching",
                       detail: "Sleep debt, consistency, recovery prediction")
                proRow(icon: "pawprint.fill", title: "Rare pets & full evolution",
                       detail: "Unlock dream forms and seasonal pets")
                proRow(icon: "house.fill", title: "All dream rooms",
                       detail: "Premium decorations & seasonal themes")
                proRow(icon: "wind", title: "Guided wind-downs & programs",
                       detail: "Sleep stories, breathing, 7-day reset")
            }
            .padding(.horizontal, 4)

            VStack(spacing: 10) {
                PrimaryButton(title: "Start free trial", icon: "sparkles") {
                    showPaywallSheet = true
                }
                Button {
                    onContinueFree()
                } label: {
                    Text("Continue free")
                        .font(MooniFont.body(15))
                        .foregroundColor(MooniColor.textSecondary)
                        .padding(.vertical, 8)
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .sheet(isPresented: $showPaywallSheet, onDismiss: {
            // Whether they bought or dismissed, finish onboarding either way.
            onContinueFree()
        }) {
            PaywallView()
        }
    }

    private func proRow(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(MooniColor.accent)
                .frame(width: 32, height: 32)
                .background(MooniColor.accent.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MooniFont.title(14))
                    .foregroundColor(MooniColor.textPrimary)
                Text(detail)
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textSecondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    OnboardingView().environmentObject(AppState())
}
