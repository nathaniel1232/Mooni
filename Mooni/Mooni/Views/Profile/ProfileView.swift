import SwiftUI
import Supabase

/// Me is the quiet account/settings/progress tab. It supports the app without
/// competing with the daily Luna care loop.
struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Binding var showPaywall: Bool

    @StateObject private var healthKit = HealthKitManager.shared
    @StateObject private var notifications = NotificationManager.shared
    @StateObject private var streak = StreakManager.shared

    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var showBadges = false
    @State private var showSleepStoryPreview = false

    @AppStorage(Haptics.hapticsKey) private var hapticsOn = true
    @AppStorage(Haptics.soundKey) private var soundOn = true

    #if DEBUG
    @State private var showMarketingVideo = false
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                StarsBackground(count: 28)

                ScrollView {
                    VStack(spacing: 16) {
                        lunaSummaryCard
                        sleepStoryPreviewCard
                        levelCard
                        sleepGoalCard
                        progressCard
                        unlocksCard
                        settingsCard
                        accountCard

                        if !subscriptionManager.isPro {
                            upgradeCard
                        }

                        #if DEBUG
                        devTools
                        #endif
                    }
                    .padding(20)
                    .padding(.bottom, 96)
                }
            }
            .navigationTitle("Me")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showBadges) {
                BadgesView()
                    .environmentObject(appState)
            }
            .fullScreenCover(isPresented: $showSleepStoryPreview) {
                SleepStoryView(
                    context: previewStoryContext(),
                    onFinished: { showSleepStoryPreview = false }
                )
            }
            .task {
                healthKit.refreshAuthState()
                await notifications.refreshAuthState()
            }
            #if DEBUG
            .fullScreenCover(isPresented: $showMarketingVideo) {
                MarketingVideoView()
            }
            #endif
        }
    }

    private var lunaSummaryCard: some View {
        MooniCard {
            HStack(spacing: 16) {
                DreamSpiritView(pet: appState.pet, size: 86)
                    .frame(width: 96, height: 96)

                VStack(alignment: .leading, spacing: 5) {
                    Text(appState.pet.name)
                        .font(MooniFont.display(24))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("\(appState.pet.species.displayName) • \(appState.pet.stage.label)")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                    Text("\(appState.petPersonality.label): \(shortPersonalityCopy)")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.accentSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
        }
    }

    /// Always-visible entry point so the morning Sleep Story can be opened
    /// on demand for review — works in Release, no logged night required
    /// (falls back to a representative sample night).
    private var sleepStoryPreviewCard: some View {
        Button {
            Haptics.tap()
            showSleepStoryPreview = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(MooniColor.accent.opacity(0.18))
                        .frame(width: 46, height: 46)
                    Image(systemName: "sparkles")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(MooniColor.accent)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Preview Sleep Story")
                        .font(MooniFont.title(16))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("See the morning reveal end to end")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(MooniColor.accent)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(MooniGradient.card)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(MooniColor.accent.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// Uses the most recent real night if there is one; otherwise builds a
    /// representative 7h12m night so the story always has something to show.
    private func previewStoryContext() -> SleepStoryContext {
        let entry: SleepEntry
        if let last = appState.lastEntry {
            entry = last
        } else {
            let cal = Calendar.current
            let now = Date()
            let wake = cal.date(bySettingHour: 7, minute: 12, second: 0, of: now) ?? now
            let bed = cal.date(byAdding: .hour, value: -7, to: wake)
                ?? now.addingTimeInterval(-7 * 3600)
            var sample = SleepEntry(
                bedtime: bed,
                wakeTime: wake,
                quality: .good,
                mood: .okay,
                notes: "[preview]",
                isEstimated: false,
                timeInBed: wake.timeIntervalSince(bed),
                source: .appActivityEstimate
            )
            SleepScoringManager.update(
                entry: &sample,
                goalHours: appState.goalHours,
                targetBedtime: appState.targetBedtime,
                consistencyDays: appState.bedtimeConsistencyDays,
                checkIn: nil,
                age: appState.profile.age
            )
            entry = sample
        }
        return SleepStoryContext(
            entry: entry,
            pet: appState.pet,
            petName: appState.pet.name,
            history: appState.entries,
            goalHours: appState.goalHours,
            currentStreak: streak.current,
            longestStreak: streak.longest,
            consistencyDays: appState.bedtimeConsistencyDays,
            leveledUpTo: appState.lastLevelUp
        )
    }

    private var levelCard: some View {
        let p = appState.pet
        return MooniCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [MooniColor.warning, MooniColor.accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)
                        Text("\(p.level)")
                            .font(MooniFont.title(22))
                            .foregroundColor(MooniColor.background)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Level \(p.level)")
                            .font(MooniFont.title(20))
                            .foregroundColor(MooniColor.textPrimary)
                        Text(p.levelTitle)
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.accentSoft)
                    }
                    Spacer()
                    StreakFlameChip(current: streak.current, freezes: streak.freezesRemaining)
                }
                MooniProgressBar(
                    value: p.levelProgress,
                    height: 10,
                    colors: [MooniColor.warning, MooniColor.accent]
                )
                Text("\(p.dreamEnergy) / \(p.energyForNextLevel) XP toward Level \(p.level + 1)")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
                if streak.freezesRemaining > 0 {
                    Text("You have \(streak.freezesRemaining) streak freeze\(streak.freezesRemaining == 1 ? "" : "s") — each level unlocks another.")
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.textMuted)
                }
            }
        }
    }

    private var sleepGoalCard: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Sleep goal")
                    .font(MooniFont.title(20))
                    .foregroundColor(MooniColor.textPrimary)

                MooniInfoRow(icon: "moon.zzz.fill", title: "Goal", value: String(format: "%.1fh", appState.goalHours))
                MooniInfoRow(icon: "bed.double.fill", title: "Bedtime", value: appState.targetBedtime.hourMinuteString)
                MooniInfoRow(icon: "sunrise.fill", title: "Wake time", value: appState.targetWakeTime.hourMinuteString, color: MooniColor.warning)

                if let goal = appState.sleepGoal {
                    Text(goal.title)
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                        .padding(.top, 2)
                }
            }
        }
    }

    private var progressCard: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Personal progress")
                    .font(MooniFont.title(20))
                    .foregroundColor(MooniColor.textPrimary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    MooniStatPill(icon: "flame.fill", value: "\(streak.current)", label: "Streak (days)", color: MooniColor.warning)
                    MooniStatPill(icon: "calendar", value: "\(appState.entries.count)", label: "Nights tracked", color: MooniColor.accent)
                    MooniStatPill(icon: "moon.fill", value: averageSleepText, label: "Average sleep")
                    MooniStatPill(icon: "snowflake", value: "\(streak.freezesRemaining)", label: "Streak freezes", color: MooniColor.accentSoft)
                }
            }
        }
    }

    private var unlocksCard: some View {
        let unlocked = appState.pet.unlockedItems.count
        let total = UnlockableItem.catalog.count

        return Button { showBadges = true } label: {
            MooniCard(padding: 18, cornerRadius: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Badges & unlocks", systemImage: "rosette")
                            .font(MooniFont.title(16))
                            .foregroundColor(MooniColor.textPrimary)
                        Spacer()
                        Text("\(unlocked)/\(total)")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(MooniColor.textMuted)
                    }

                    MooniProgressBar(value: Double(unlocked) / Double(max(total, 1)), height: 9)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var settingsCard: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Settings")
                    .font(MooniFont.title(20))
                    .foregroundColor(MooniColor.textPrimary)

                settingsButton(icon: "heart.text.square.fill", title: "Apple Health", value: healthStatusText) {
                    Task {
                        _ = await healthKit.requestAuthorization()
                        await appState.importHealthKitSleep()
                    }
                }

                Divider().background(Color.white.opacity(0.08))

                settingsButton(icon: "bell.fill", title: "Bedtime reminder", value: notificationStatusText) {
                    Task {
                        _ = await notifications.requestAuthorization()
                        notifications.scheduleNightlyBedtimeNudge(
                            petName: appState.pet.name,
                            bedtime: appState.targetBedtime
                        )
                    }
                }

                Divider().background(Color.white.opacity(0.08))

                settingsButton(icon: "sparkles", title: "Subscription", value: subscriptionManager.isPro ? "Premium active" : "Free plan") {
                    showPaywall = true
                }

                Divider().background(Color.white.opacity(0.08))

                feedbackToggleRow(icon: "hand.tap.fill",
                                  title: "Haptics",
                                  isOn: $hapticsOn)

                Divider().background(Color.white.opacity(0.08))

                feedbackToggleRow(icon: "speaker.wave.2.fill",
                                  title: "Sounds",
                                  isOn: $soundOn)

                Divider().background(Color.white.opacity(0.08))

                Link(destination: URL(string: "https://nathanielfiskaa.github.io/sleepowl-privacy/")!) {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(MooniColor.accent)
                            .frame(width: 30, height: 30)
                            .background(MooniColor.accent.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Text("Privacy Policy")
                            .font(MooniFont.body(15))
                            .foregroundColor(MooniColor.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(MooniColor.textMuted)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Account & data (App Store Review Guideline 5.1.1(v)) requires
    // apps with account creation to offer in-app account deletion.

    private var accountCard: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Account & data")
                    .font(MooniFont.title(20))
                    .foregroundColor(MooniColor.textPrimary)

                Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                    accountRow(icon: "doc.text.fill", color: MooniColor.accent,
                               title: "Terms of Use (EULA)", trailing: "arrow.up.right")
                }

                Divider().background(Color.white.opacity(0.08))

                Link(destination: URL(string: "https://nathanielfiskaa.github.io/sleepowl-privacy/")!) {
                    accountRow(icon: "lock.shield.fill", color: MooniColor.accentSoft,
                               title: "Privacy Policy", trailing: "arrow.up.right")
                }

                Divider().background(Color.white.opacity(0.08))

                Button { Task { await manageSubscriptionInSettings() } } label: {
                    accountRow(icon: "creditcard.fill", color: MooniColor.warning,
                               title: "Manage subscription", trailing: "chevron.right")
                }
                .buttonStyle(.plain)

                Divider().background(Color.white.opacity(0.08))

                Button { showDeleteConfirm = true } label: {
                    accountRow(icon: "trash.fill", color: MooniColor.danger,
                               title: "Delete account & data",
                               titleColor: MooniColor.danger,
                               trailing: "chevron.right")
                }
                .buttonStyle(.plain)

                if let err = deleteError {
                    Text(err)
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.danger)
                }
            }
        }
        .alert("Delete your account?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete everything", role: .destructive) {
                Task { await performAccountDeletion() }
            }
        } message: {
            Text("This erases your sleep history, pet, and signs you out of any cloud backup. This action can't be undone.")
        }
    }

    private func accountRow(icon: String, color: Color, title: String,
                            titleColor: Color = MooniColor.textPrimary,
                            trailing: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title)
                .font(MooniFont.body(15))
                .foregroundColor(titleColor)
            Spacer()
            Image(systemName: trailing)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(MooniColor.textMuted)
        }
        .padding(.vertical, 4)
    }

    @MainActor
    private func manageSubscriptionInSettings() async {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            await UIApplication.shared.open(url)
        }
    }

    @MainActor
    private func performAccountDeletion() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            // Best-effort Supabase sign-out + delete; failures don't block
            // local wipe — Apple still requires the local data to be removed.
            try? await Supa.client.auth.signOut()
            appState.eraseAllUserData()
            deleteError = nil
        } catch {
            deleteError = error.localizedDescription
        }
    }

    private func feedbackToggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(MooniColor.accent)
                .frame(width: 30, height: 30)
                .background(MooniColor.accent.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(title)
                .font(MooniFont.body(15))
                .foregroundColor(MooniColor.textPrimary)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(MooniColor.accent)
                .onChange(of: isOn.wrappedValue) { _, on in
                    if on { Haptics.soft() }
                }
        }
        .padding(.vertical, 4)
    }

    private func settingsButton(icon: String, title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(MooniColor.accent)
                    .frame(width: 30, height: 30)
                    .background(MooniColor.accent.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(title)
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textPrimary)

                Spacer()

                Text(value)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(MooniColor.textMuted)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var upgradeCard: some View {
        Button { showPaywall = true } label: {
            MooniCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Premium", systemImage: "sparkles")
                            .font(MooniFont.title(18))
                            .foregroundColor(MooniColor.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(MooniColor.accentSoft)
                    }

                    Text("Unlock \(appState.pet.name)'s full evolution path, rare rooms, guided wind-downs, programs, and deeper sleep insights.")
                        .font(MooniFont.body(14))
                        .foregroundColor(MooniColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var averageSleepText: String {
        let recent = appState.recentEntries
        guard !recent.isEmpty else { return "--" }
        let average = recent.map(\.hours).reduce(0, +) / Double(recent.count)
        return String(format: "%.1fh", average)
    }

    private var shortPersonalityCopy: String {
        switch appState.petPersonality {
        case .balanced: return "adapts to the night."
        case .consistent: return "loves a steady routine."
        case .nightOwl: return "needs a gentle wind-down."
        case .earlyBird: return "brightens with steady mornings."
        case .recovering: return "bounces back softly."
        case .explorer: return "is still finding rhythm."
        }
    }

    private var healthStatusText: String {
        if healthKit.isConnected { return "Connected" }
        switch healthKit.authState {
        case .authorized: return "Connected"
        case .denied: return "Needs access"
        case .notDetermined: return "Connect"
        case .unavailable: return "Unavailable"
        }
    }

    private var notificationStatusText: String {
        switch notifications.authState {
        case .authorized: return "On"
        case .denied: return "Off"
        case .notDetermined: return "Set up"
        }
    }

    // MARK: - DEBUG

    #if DEBUG
    private var devTools: some View {
        VStack(spacing: 10) {
            Divider().background(Color.white.opacity(0.1))
            Text("DEV TOOLS")
                .font(MooniFont.caption(11))
                .foregroundColor(MooniColor.textMuted)
                .textCase(.uppercase)
                .padding(.top, 4)

            // Hidden marketing-video launcher. Distinct visual style so it's
            // easy to find when recording TikTok / Reels demos.
            Button {
                showMarketingVideo = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                    Text("Start Marketing Video")
                        .font(MooniFont.title(14))
                    Spacer()
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(MooniColor.background)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    LinearGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            devButton("Skip Onboarding", icon: "fast.forward.fill") {
                appState.hasCompletedOnboarding = true
            }

            devButton("Reset All Data", icon: "trash.fill", color: MooniColor.danger) {
                appState.hasCompletedOnboarding = false
                appState.pet = Pet()
                appState.entries = []
                appState.routine = Routine()
                appState.dreamStars = 0
            }

            devButton("Log Sleep (8h tonight)", icon: "moon.zzz.fill") {
                let bed = appState.targetBedtime
                let wake = Calendar.current.date(byAdding: .hour, value: 8, to: bed) ?? bed
                _ = appState.logSleep(
                    bedtime: bed,
                    wakeTime: wake,
                    quality: .great,
                    mood: .energized,
                    notes: "[DEV]",
                    routineCompleted: true
                )
            }

            HStack(spacing: 8) {
                devButton("Growth +1", icon: "plus.circle.fill", width: nil) {
                    var p = appState.pet
                    p.dreamEnergy += p.energyForNextLevel
                    while p.dreamEnergy >= p.energyForNextLevel {
                        p.dreamEnergy -= p.energyForNextLevel
                        p.level += 1
                    }
                    for item in UnlockableItem.catalog where item.requiredLevel <= p.level {
                        p.unlockedItems.insert(item.id)
                    }
                    appState.pet = p
                }

                devButton("Unlock All", icon: "lock.open.fill", width: nil) {
                    var p = appState.pet
                    p.unlockedItems = Set(UnlockableItem.catalog.map { $0.id })
                    appState.pet = p
                }
            }

            devButton("Clear Sleep Logs", icon: "xmark.circle.fill", color: MooniColor.danger) {
                appState.entries = []
            }

            devButton("Cycle Mood", icon: "face.smiling.fill") {
                let moods: [Pet.Mood] = [.energized, .cozy, .calm, .sleepy, .groggy, .restless]
                let current = appState.pet.mood
                let nextIndex = (moods.firstIndex(of: current) ?? -1) + 1
                var p = appState.pet
                p.mood = moods[nextIndex % moods.count]
                appState.pet = p
            }

            devButton("Add Dream Stars (100)", icon: "sparkles") {
                appState.dreamStars += 100
            }

            devButton(
                subscriptionManager.devForcePro ? "Disable forced Pro" : "Force Pro on",
                icon: subscriptionManager.devForcePro ? "lock.fill" : "sparkles",
                color: subscriptionManager.devForcePro ? MooniColor.warning : MooniColor.success
            ) {
                subscriptionManager.devForcePro.toggle()
            }

            devButton("Trigger sleep mode", icon: "moon.fill") {
                appState.enterSleepMode()
            }

            devButton("Preview morning check-in", icon: "sun.max.fill") {
                seedDevEntryIfNeeded()
                appState.showMorningCheckIn = true
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(MooniColor.danger.opacity(0.3), lineWidth: 1)
        )
    }

    /// Seed a synthetic last-night entry so the morning check-in flow has
    /// something to display — bypasses the "still settling in" wait so we
    /// can preview the full check-in any time during development.
    private func seedDevEntryIfNeeded() {
        guard appState.entryNeedingMorningCheckIn == nil else { return }

        let cal = Calendar.current
        let now = Date()
        let wake = cal.date(bySettingHour: 7, minute: 12, second: 0, of: now) ?? now
        let bed = cal.date(byAdding: .hour, value: -7, to: wake) ?? now.addingTimeInterval(-7 * 3600)

        // Replace any existing same-day entry so the preview always shows
        // fresh "needs check-in" state.
        if let idx = appState.entries.firstIndex(where: { $0.dayKey == wake.dayKey }) {
            appState.entries.remove(at: idx)
        }
        MorningCheckInStore.clear(for: wake.dayKey)

        var entry = SleepEntry(
            bedtime: bed,
            wakeTime: wake,
            quality: .good,
            mood: .okay,
            notes: "[DEV preview]",
            routineCompleted: false,
            isEstimated: false,
            timeInBed: wake.timeIntervalSince(bed),
            source: .appActivityEstimate
        )
        SleepScoringManager.update(
            entry: &entry,
            goalHours: appState.goalHours,
            targetBedtime: appState.targetBedtime,
            consistencyDays: appState.bedtimeConsistencyDays,
            checkIn: nil,
            age: appState.profile.age
        )
        appState.entries.append(entry)
    }

    private func devButton(
        _ label: String,
        icon: String,
        color: Color = MooniColor.accent,
        width: CGFloat? = .infinity,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18)
                Text(label)
                    .font(MooniFont.caption(12))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
            }
            .foregroundColor(color)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(color.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .frame(maxWidth: width)
        }
        .buttonStyle(.plain)
    }
    #endif
}

#Preview {
    ProfileView(showPaywall: .constant(false))
        .environmentObject(AppState.preview)
        .environmentObject(SubscriptionManager.shared)
}
