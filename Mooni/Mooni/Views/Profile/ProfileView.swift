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
    @ObservedObject private var developerMode = DeveloperMode.shared

    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var showBadges = false
    @State private var showSleepStoryPreview = false
    @State private var showSleepGoalEditor = false
    @State private var showDeveloperMenu = false

    @AppStorage(Haptics.hapticsKey) private var hapticsOn = true
    @AppStorage(Haptics.soundKey) private var soundOn = true

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                StarsBackground(count: 28)

                ScrollView {
                    VStack(spacing: 16) {
                        lunaSummaryCard
                        // Only offer the Sleep Story once there's a real night
                        // to tell a story about — never let a brand-new user
                        // "preview" a fabricated night before their first sleep.
                        if subscriptionManager.isPro && appState.lastRealEntry != nil {
                            sleepStoryPreviewCard
                        }
                        levelCard
                        sleepGoalCard
                        progressCard
                        unlocksCard
                        settingsCard
                        if developerMode.isUnlocked {
                            developerCard
                        }
                        accountCard

                        if !subscriptionManager.isPro {
                            upgradeCard
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 96)
                }
                // iPad: cap content column; background stays full-bleed.
                .responsiveContainer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showBadges) {
                BadgesView()
                    .environmentObject(appState)
            }
            .sheet(isPresented: $showSleepGoalEditor) {
                SleepGoalEditorSheet(
                    initialBedtime: appState.targetBedtime,
                    initialWakeTime: appState.targetWakeTime,
                    initialGoal: appState.goalHours
                ) { bedtime, wakeTime, goal in
                    appState.targetBedtime = bedtime
                    appState.targetWakeTime = wakeTime
                    appState.goalHours = goal
                    // Re-align the bedtime/wake notification safety net to the
                    // new schedule so reminders and probes fire at the right
                    // times tonight, not the old ones.
                    NotificationManager.shared.reconcileSafetyNetNotifications(
                        petName: appState.pet.name,
                        bedtime: bedtime,
                        wakeTime: wakeTime
                    )
                }
                .presentationDetents([.medium, .large])
            }
            .fullScreenCover(isPresented: $showSleepStoryPreview) {
                SleepStoryView(
                    context: previewStoryContext(),
                    onFinished: { showSleepStoryPreview = false }
                )
            }
            .sheet(isPresented: $showDeveloperMenu) {
                DeveloperMenuView()
                    .environmentObject(appState)
                    .environmentObject(subscriptionManager)
            }
            .task {
                healthKit.refreshAuthState()
                await notifications.refreshAuthState()
            }
        }
    }

    /// Hidden developer tools — only visible once the paywall owl gesture has
    /// unlocked it (see DeveloperMode / PaywallView).
    private var developerCard: some View {
        Button { showDeveloperMenu = true } label: {
            MooniCard {
                HStack(spacing: 14) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(MooniColor.accentText)
                        .frame(width: 36, height: 36)
                        .background(MooniColor.accent.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Developer menu")
                            .font(MooniFont.title(15))
                            .foregroundColor(MooniColor.textPrimary)
                        Text("Simulate nights · jump into any screen")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(MooniColor.textMuted)
                }
            }
        }
        .buttonStyle(.plain)
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
                        .foregroundColor(MooniColor.accentText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
        }
    }

    /// Entry point to re-open the morning Sleep Story on demand. Only shown
    /// once the user has at least one real tracked night (see the gate in the
    /// body) — there's nothing honest to show before the first sleep.
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
                        .foregroundColor(MooniColor.accentText)
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
                    .foregroundColor(MooniColor.accentText)
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

    /// Builds the story from the most recent REAL night. The card that
    /// presents this is gated on `lastRealEntry != nil`, so there is always a
    /// genuine night here — we never fabricate a sample to show off a story
    /// the user hasn't earned yet. Falls back to `lastEntry` defensively.
    private func previewStoryContext() -> SleepStoryContext {
        let entry = appState.lastRealEntry ?? appState.lastEntry ?? {
            // Defensive only — unreachable while the gate holds. Keeps the
            // signature non-optional without inventing a "real" night.
            let now = Date()
            return SleepEntry(
                bedtime: now.addingTimeInterval(-7 * 3600),
                wakeTime: now,
                quality: .good,
                mood: .okay,
                notes: "[preview]",
                isEstimated: true,
                timeInBed: 7 * 3600,
                source: .appActivityEstimate
            )
        }()
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
                            .fill(MooniColor.accent.opacity(0.18))
                            .frame(width: 52, height: 52)
                        Circle()
                            .stroke(MooniColor.accent.opacity(0.45), lineWidth: 1.5)
                            .frame(width: 52, height: 52)
                        Text("\(p.level)")
                            .font(MooniFont.display(22))
                            .foregroundColor(MooniColor.accentText)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Level \(p.level)")
                            .font(MooniFont.title(20))
                            .foregroundColor(MooniColor.textPrimary)
                        Text("\(Int(p.levelProgress * 100))% to level \(p.level + 1)")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.accentText)
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
                HStack {
                    Text("Sleep goal")
                        .font(MooniFont.title(20))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    Button {
                        Haptics.tap()
                        showSleepGoalEditor = true
                    } label: {
                        Text("Edit")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.accentText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(MooniColor.accent.opacity(0.14))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

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

                settingsButton(
                    icon: "heart.text.square.fill",
                    title: "Apple Health",
                    value: subscriptionManager.isPro ? healthStatusText : "Pro feature",
                    locked: !subscriptionManager.isPro
                ) {
                    if !subscriptionManager.isPro {
                        showPaywall = true
                        return
                    }
                    Task {
                        _ = await healthKit.requestAuthorization()
                        await appState.importHealthKitSleep()
                    }
                }

                Divider().background(MooniColor.hairline)

                settingsButton(icon: "bell.fill", title: "Bedtime reminder", value: notificationStatusText) {
                    Task {
                        _ = await notifications.requestAuthorization()
                        notifications.scheduleNightlyBedtimeNudge(
                            petName: appState.pet.name,
                            bedtime: appState.targetBedtime
                        )
                    }
                }

                Divider().background(MooniColor.hairline)

                feedbackToggleRow(icon: "hand.tap.fill",
                                  title: "Haptics",
                                  isOn: $hapticsOn)

                Divider().background(MooniColor.hairline)

                feedbackToggleRow(icon: "speaker.wave.2.fill",
                                  title: "Sounds",
                                  isOn: $soundOn)

                Divider().background(MooniColor.hairline)

                Link(destination: URL(string: "https://sleepowlapp.vercel.app/privacy")!) {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(MooniColor.accentText)
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

                Link(destination: URL(string: "https://sleepowlapp.vercel.app/terms")!) {
                    accountRow(icon: "doc.text.fill", color: MooniColor.accent,
                               title: "Terms of Use (EULA)", trailing: "arrow.up.right")
                }

                Divider().background(MooniColor.hairline)

                Link(destination: URL(string: "https://sleepowlapp.vercel.app/privacy")!) {
                    accountRow(icon: "lock.shield.fill", color: MooniColor.accentSoft,
                               title: "Privacy Policy", trailing: "arrow.up.right")
                }

                Divider().background(MooniColor.hairline)

                Link(destination: URL(string: "https://sleepowlapp.vercel.app/support")!) {
                    accountRow(icon: "lifepreserver", color: MooniColor.accent,
                               title: "Support", trailing: "arrow.up.right")
                }

                Divider().background(MooniColor.hairline)

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
    private func performAccountDeletion() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            // Delete the server-side profile row (while the session is still
            // valid), then sign out + unlink RevenueCat. Throws if the server
            // delete fails so we can surface it.
            try await AppleSignInService.shared.deleteAccount()
            appState.eraseAllUserData()
            deleteError = nil
        } catch {
            // Server delete failed (e.g. offline). Still wipe ALL local data —
            // Apple requires on-device data removal regardless — but tell the
            // user the server copy couldn't be removed so they can retry.
            appState.eraseAllUserData()
            deleteError = "Your data was removed from this device, but we couldn't reach the server to finish deleting your account. Please try again when you're back online."
        }
    }

    private func feedbackToggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(MooniColor.accentText)
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

    private func settingsButton(
        icon: String,
        title: String,
        value: String,
        locked: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(MooniColor.accentText)
                    .frame(width: 30, height: 30)
                    .background(MooniColor.accent.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Text(title)
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textPrimary)

                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(MooniColor.warning)
                }

                Spacer()

                Text(value)
                    .font(MooniFont.caption(12))
                    .foregroundColor(locked ? MooniColor.warning : MooniColor.textSecondary)
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
                            .foregroundColor(MooniColor.accentText)
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
}

#Preview {
    ProfileView(showPaywall: .constant(false))
        .environmentObject(AppState.preview)
        .environmentObject(SubscriptionManager.shared)
}

// MARK: - Ideal sleep time editor

/// Lets the user change their target bedtime, wake time, and nightly goal
/// after onboarding. Seeded from the current values; on Save it hands the new
/// values back to ProfileView, which writes them to AppState and re-aligns the
/// notification safety net.
private struct SleepGoalEditorSheet: View {
    let initialBedtime: Date
    let initialWakeTime: Date
    let initialGoal: Double
    let onSave: (Date, Date, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var bedtime: Date
    @State private var wakeTime: Date

    init(initialBedtime: Date, initialWakeTime: Date, initialGoal: Double,
         onSave: @escaping (Date, Date, Double) -> Void) {
        self.initialBedtime = initialBedtime
        self.initialWakeTime = initialWakeTime
        self.initialGoal = initialGoal
        self.onSave = onSave
        _bedtime = State(initialValue: initialBedtime)
        _wakeTime = State(initialValue: initialWakeTime)
    }

    /// The nightly target follows from the schedule — we don't make the user
    /// dial in "how many hours" anymore; that's our job to compute.
    private var goalHours: Double {
        let cal = Calendar.current
        var end = wakeTime
        if end <= bedtime { end = cal.date(byAdding: .day, value: 1, to: end) ?? end }
        let mins = cal.dateComponents([.minute], from: bedtime, to: end).minute ?? 0
        return Double(mins) / 60.0
    }

    var body: some View {
        ZStack {
            MooniGradient.night.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Your sleep schedule")
                            .font(MooniFont.title(22))
                            .foregroundColor(MooniColor.textPrimary)
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(MooniColor.textSecondary)
                                .frame(width: 30, height: 30)
                                .background(MooniColor.hairline)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 2)

                    timeRow(title: "Bedtime", systemImage: "bed.double.fill",
                            tint: MooniColor.accent, selection: $bedtime)
                    timeRow(title: "Wake time", systemImage: "sunrise.fill",
                            tint: MooniColor.warning, selection: $wakeTime)
                    windowRow

                    Text("\(goalHelperLead) Your reminders and sleep tracking adjust to this schedule.")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    PrimaryButton(title: "Save", variant: .white) {
                        Haptics.tap()
                        onSave(bedtime, wakeTime, goalHours)
                        dismiss()
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
        }
        // Follow the app's day/night theme so system controls (the time
        // pickers) match the cream morning surface instead of staying dark.
        .preferredColorScheme(ThemeManager.currentMode == .light ? .light : .dark)
    }

    /// The computed window formatted as "8h 15m" (drops minutes when 0).
    private var windowText: String {
        let total = Int((goalHours * 60).rounded())
        let h = total / 60, m = total % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    /// Tiny human-readable lead-in for the helper line (kept out of the view
    /// builder for clarity).
    private var goalHelperLead: String {
        "That's a \(windowText) night."
    }

    private func timeRow(title: String, systemImage: String, tint: Color,
                         selection: Binding<Date>) -> some View {
        MooniCard {
            HStack {
                Label {
                    Text(title).font(MooniFont.body(15)).foregroundColor(MooniColor.textPrimary)
                } icon: {
                    Image(systemName: systemImage).foregroundColor(tint)
                }
                Spacer()
                DatePicker("", selection: selection, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(MooniColor.accent)
            }
        }
    }

    /// Read-only: the nightly sleep window is a CONSEQUENCE of bedtime + wake,
    /// not a number the user dials. We compute and show it.
    private var windowRow: some View {
        MooniCard {
            HStack {
                Label {
                    Text("Sleep window").font(MooniFont.body(15)).foregroundColor(MooniColor.textPrimary)
                } icon: {
                    Image(systemName: "moon.zzz.fill").foregroundColor(MooniColor.accentText)
                }
                Spacer()
                Text(windowText)
                    .font(MooniFont.title(16))
                    .foregroundColor(MooniColor.textPrimary)
            }
        }
    }
}
