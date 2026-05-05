import SwiftUI

/// Profile / Progress tab — long-term achievement view.
/// Free users see basic streaks & 7-day average; Pro users see deeper trends.
struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Binding var showPaywall: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        identityCard
                        streakCard
                        statsGrid
                        badgesCard
                        if subscriptionManager.isPro {
                            historicalTrends
                        } else {
                            historicalTeaser
                        }
                        manageRow
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Identity card
    private var identityCard: some View {
        MooniCard {
            HStack(spacing: 14) {
                DreamSpiritView(pet: appState.pet, size: 70)
                    .frame(width: 100, height: 100)
                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.pet.name)
                        .font(MooniFont.display(22))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("\(appState.pet.species.displayName) · \(appState.pet.stage.label)")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                    if let goal = appState.sleepGoal {
                        Text(goal.title)
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.accentSoft)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Streak card
    private var streakCard: some View {
        let cur = appState.bedtimeConsistencyDays
        return MooniCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(MooniColor.warning.opacity(0.16))
                        .frame(width: 64, height: 64)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 28))
                        .foregroundColor(MooniColor.warning)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(cur) day streak")
                        .font(MooniFont.title(18))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("Consistent bedtime within 30 minutes of your target.")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }
                Spacer()
            }
        }
    }

    // MARK: - Stats grid
    private var statsGrid: some View {
        let recent = appState.recentEntries
        let avg = recent.isEmpty ? 0 : recent.map(\.hours).reduce(0, +) / Double(recent.count)
        let total = appState.entries.count
        return HStack(spacing: 12) {
            statTile(icon: "moon.zzz.fill", color: MooniColor.accent,
                     value: String(format: "%.1fh", avg), label: "Avg / night")
            statTile(icon: "calendar", color: MooniColor.accentSoft,
                     value: "\(total)", label: "Nights tracked")
            statTile(icon: "sparkles", color: MooniColor.warning,
                     value: "\(appState.dreamStars)", label: "Dream stars")
        }
    }

    private func statTile(icon: String, color: Color, value: String, label: String) -> some View {
        MooniCard(padding: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon).foregroundColor(color)
                Text(value)
                    .font(MooniFont.title(18))
                    .foregroundColor(MooniColor.textPrimary)
                Text(label)
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textSecondary)
            }
        }
    }

    // MARK: - Badges card
    private var badgesCard: some View {
        let unlocked = appState.pet.unlockedItems.count
        let total = UnlockableItem.catalog.count
        return MooniCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Badges & unlocks", systemImage: "rosette")
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    Text("\(unlocked) / \(total)")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }
                progressBar(value: Double(unlocked) / Double(max(total, 1)))
            }
        }
    }

    private func progressBar(value: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [MooniColor.accentSoft, MooniColor.accent],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * CGFloat(min(max(value, 0), 1)))
            }
        }
        .frame(height: 8)
    }

    // MARK: - Premium history trends
    private var historicalTrends: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Long-term trends", systemImage: "chart.line.uptrend.xyaxis")
                    .font(MooniFont.title(15))
                    .foregroundColor(MooniColor.textPrimary)
                let monthly = monthlyAverage()
                Text(monthly == nil
                     ? "Keep tracking — your monthly trend will appear soon."
                     : String(format: "Your 30-day average: %.1fh / night.", monthly!))
                    .font(MooniFont.caption(13))
                    .foregroundColor(MooniColor.textSecondary)
            }
        }
    }

    private func monthlyAverage() -> Double? {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recent = appState.entries.filter { $0.wakeTime >= cutoff }
        guard !recent.isEmpty else { return nil }
        return recent.map(\.hours).reduce(0, +) / Double(recent.count)
    }

    private var historicalTeaser: some View {
        Button { showPaywall = true } label: {
            MooniCard {
                HStack {
                    Label("Long-term trends", systemImage: "chart.line.uptrend.xyaxis")
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.accent)
                    Spacer()
                    Image(systemName: "lock.fill")
                        .foregroundColor(MooniColor.textMuted)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Manage row
    private var manageRow: some View {
        VStack(spacing: 10) {
            if !subscriptionManager.isPro {
                Button { showPaywall = true } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Upgrade to Mooni Pro")
                            .font(MooniFont.title(15))
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.white)
                    .padding(14)
                    .background(LinearGradient(colors: [MooniColor.accentSoft, MooniColor.accent],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            #if DEBUG
            devTools
            #endif
        }
    }

    // MARK: - DEBUG: Dev tools
    #if DEBUG
    private var devTools: some View {
        VStack(spacing: 10) {
            Divider().background(Color.white.opacity(0.1))
            Text("DEV TOOLS")
                .font(MooniFont.caption(11))
                .foregroundColor(MooniColor.textMuted)
                .textCase(.uppercase)
                .padding(.top, 4)

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
                devButton("Level +1", icon: "plus.circle.fill", width: nil) {
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
                devButton("Max Out", icon: "star.fill", width: nil) {
                    var p = appState.pet
                    p.level = 20
                    p.dreamEnergy = 0
                    for item in UnlockableItem.catalog {
                        p.unlockedItems.insert(item.id)
                    }
                    appState.pet = p
                }
            }

            devButton("Clear All Sleep Logs", icon: "xmark.circle.fill", color: MooniColor.danger) {
                appState.entries = []
            }

            devButton("Unlock All Items", icon: "lock.open.fill") {
                var p = appState.pet
                p.unlockedItems = Set(UnlockableItem.catalog.map { $0.id })
                appState.pet = p
            }

            devButton("Cycle Mood", icon: "face.smiling.fill") {
                let moods: [Pet.Mood] = [.energized, .cozy, .calm, .sleepy, .groggy, .restless]
                let current = appState.pet.mood
                let nextIdx = (moods.firstIndex(of: current) ?? -1) + 1
                var p = appState.pet
                p.mood = moods[nextIdx % moods.count]
                appState.pet = p
            }

            devButton("Add Dream Stars (100)", icon: "sparkles") {
                appState.dreamStars += 100
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MooniColor.danger.opacity(0.3), lineWidth: 1)
        )
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
                Spacer()
            }
            .foregroundColor(color)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(color.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
