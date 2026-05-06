import SwiftUI

struct PetScreenView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Binding var showPaywall: Bool

    @State private var selectedTab: CustomizationTab = .hats
    @State private var showEvolutionPath = false

    private enum CustomizationTab: String, CaseIterable, Identifiable {
        case hats
        case colors
        case rooms
        case backgrounds

        var id: String { rawValue }

        var title: String {
            switch self {
            case .hats: return "Hats"
            case .colors: return "Colors"
            case .rooms: return "Rooms"
            case .backgrounds: return "Backgrounds"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                StarsBackground(count: 38)

                ScrollView {
                    VStack(spacing: 20) {
                        hero
                        evolutionCard
                        personalityCard
                        customizationSection
                    }
                    .padding(20)
                    .padding(.bottom, 96)
                }
            }
            .navigationTitle("Luna")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if !subscriptionManager.isPro {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showPaywall = true
                        } label: {
                            Label("Premium", systemImage: "sparkles")
                                .font(MooniFont.caption(12))
                                .foregroundColor(MooniColor.background)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(MooniColor.accentSoft)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .sheet(isPresented: $showEvolutionPath) {
                EvolutionPathSheet(showPaywall: $showPaywall)
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Luna")
                    .font(MooniFont.display(32))
                    .foregroundColor(MooniColor.textPrimary)
                Text("\(appState.pet.name) feels \(appState.pet.mood.label.lowercased()).")
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LunaMoodHero(
                pet: appState.pet,
                mood: appState.pet.mood,
                size: 220,
                caption: nil
            )

            HStack(spacing: 10) {
                MooniStatPill(icon: "heart.fill", value: appState.pet.mood.label, label: "Mood", color: MooniColor.success)
                MooniStatPill(icon: appState.petPersonality.icon, value: appState.petPersonality.label, label: "Trait", color: MooniColor.accent)
            }
        }
    }

    private var evolutionCard: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next: \(nextStageName) Luna")
                            .font(MooniFont.title(20))
                            .foregroundColor(MooniColor.textPrimary)
                        Text(evolutionCopy)
                            .font(MooniFont.body(14))
                            .foregroundColor(MooniColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    Image(systemName: "sparkles")
                        .foregroundColor(MooniColor.accentSoft)
                        .frame(width: 38, height: 38)
                        .background(MooniColor.accent.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }

                stageTrack

                MooniProgressBar(value: appState.growthProgress, height: 10)

                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundColor(MooniColor.warning)
                    Text("Unlock: Starry Blanket")
                        .font(MooniFont.caption(13))
                        .foregroundColor(MooniColor.warning)
                    Spacer()
                }
                .padding(.vertical, 4)

                SecondaryButton(title: "View evolution path", icon: "arrow.up.right.circle.fill") {
                    showEvolutionPath = true
                }

                if shouldShowEvolutionLock {
                    MooniPremiumLockCard(
                        icon: "moon.stars.fill",
                        title: "Full evolution path",
                        subtitle: "Unlock adult, dream form, rare animations, and seasonal forms.",
                        actionTitle: "Let Luna keep growing"
                    ) {
                        showPaywall = true
                    }
                }
            }
        }
    }

    private var stageTrack: some View {
        let stages: [Pet.EvolutionStage] = [.baby, .young, .adult, .dream, .legendary]
        let currentIndex = stages.firstIndex(of: appState.pet.stage) ?? 0

        return HStack(spacing: 8) {
            ForEach(Array(stages.enumerated()), id: \.element) { index, stage in
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(index <= currentIndex ? MooniColor.accent.opacity(0.28) : Color.white.opacity(0.07))
                            .frame(width: 42, height: 42)

                        if isPremiumStage(stage), !subscriptionManager.isPro {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(MooniColor.textMuted)
                        } else {
                            Text(stageInitial(stage))
                                .font(MooniFont.title(14))
                                .foregroundColor(index <= currentIndex ? MooniColor.accentSoft : MooniColor.textMuted)
                        }
                    }

                    Text(shortStageLabel(stage))
                        .font(MooniFont.caption(10))
                        .foregroundColor(index <= currentIndex ? MooniColor.textPrimary : MooniColor.textMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var personalityCard: some View {
        let personality = appState.petPersonality

        return MooniCard(padding: 18, cornerRadius: 24) {
            HStack(spacing: 14) {
                Image(systemName: personality.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(MooniColor.accentSoft)
                    .frame(width: 48, height: 48)
                    .background(MooniColor.accent.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(personality.label) Luna")
                        .font(MooniFont.title(16))
                        .foregroundColor(MooniColor.textPrimary)
                    Text(personalityCopy(personality))
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
        }
    }

    private var customizationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Customize Luna")
                        .font(MooniFont.title(20))
                        .foregroundColor(MooniColor.textPrimary)
                    Text("\(appState.dreamStars) dream stars")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.warning)
                }
                Spacer()
            }
            .padding(.horizontal, 4)

            tabPicker
            customizationGrid
            premiumPreviewShelf
        }
    }

    private var tabPicker: some View {
        HStack(spacing: 8) {
            ForEach(CustomizationTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(MooniFont.caption(12))
                        .foregroundColor(selectedTab == tab ? MooniColor.background : MooniColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(selectedTab == tab ? MooniColor.accentSoft : Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var customizationGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

        LazyVGrid(columns: columns, spacing: 12) {
            switch selectedTab {
            case .hats:
                noneHatTile
                ForEach(items(for: .hat)) { item in
                    itemTile(item)
                }
            case .colors:
                ForEach(items(for: .color)) { item in
                    itemTile(item)
                }
            case .rooms:
                ForEach(PetRoom.allCases) { room in
                    roomTile(room)
                }
            case .backgrounds:
                ForEach(items(for: .background)) { item in
                    itemTile(item)
                }
            }
        }
    }

    private var noneHatTile: some View {
        Button {
            appState.unequipHat()
        } label: {
            tileShell(
                title: "None",
                subtitle: appState.pet.equippedHat == nil ? "Equipped" : "Starter",
                isSelected: appState.pet.equippedHat == nil,
                isLocked: false
            ) {
                Image(systemName: "circle.slash")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundColor(MooniColor.textPrimary)
            }
        }
        .buttonStyle(.plain)
    }

    private func itemTile(_ item: UnlockableItem) -> some View {
        let premiumLocked = isPremiumItem(item) && !subscriptionManager.isPro
        let unlocked = appState.pet.unlockedItems.contains(item.id)
        let equipped = isEquipped(item)
        let cost = starCost(for: item)
        let subtitle: String = {
            if premiumLocked { return premiumLockLabel(for: item) }
            if equipped { return "Equipped" }
            if unlocked { return "Owned" }
            return "\(cost) stars"
        }()

        return Button {
            if premiumLocked {
                showPaywall = true
            } else if unlocked {
                appState.equip(item)
            } else if appState.spendDreamStars(cost) {
                appState.unlock(item)
                appState.equip(item)
            }
        } label: {
            tileShell(title: item.name, subtitle: subtitle, isSelected: equipped, isLocked: premiumLocked) {
                if item.kind == .color {
                    Circle()
                        .fill(UnlockableItem.color(for: item.id))
                        .frame(width: 32, height: 32)
                        .shadow(color: UnlockableItem.color(for: item.id).opacity(0.45), radius: 8)
                } else {
                    Image(systemName: item.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(premiumLocked ? MooniColor.textMuted : MooniColor.textPrimary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func roomTile(_ room: PetRoom) -> some View {
        let selected = appState.pet.room == room
        let locked = !subscriptionManager.isPro && !selected && room != .moonBedroom

        return Button {
            if locked {
                showPaywall = true
            } else {
                var pet = appState.pet
                pet.room = room
                appState.pet = pet
            }
        } label: {
            tileShell(
                title: room.displayName,
                subtitle: locked ? "Premium unlock" : (selected ? "Equipped" : "Room"),
                isSelected: selected,
                isLocked: locked
            ) {
                Image(systemName: room.icon)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundColor(locked ? MooniColor.textMuted : MooniColor.accentSoft)
            }
        }
        .buttonStyle(.plain)
    }

    private var premiumPreviewShelf: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rare previews")
                .font(MooniFont.title(17))
                .foregroundColor(MooniColor.textPrimary)
                .padding(.horizontal, 4)
                .padding(.top, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                premiumPreviewTile(title: "Dream Crown", subtitle: "Premium unlock", icon: "crown.fill")
                premiumPreviewTile(title: "Aurora Room", subtitle: "Seasonal item", icon: "sun.haze.fill")
                premiumPreviewTile(title: "Cloud Bed", subtitle: "Dream room", icon: "bed.double.fill")
                premiumPreviewTile(title: "Rare Dream Form", subtitle: "Rare sleep form", icon: "moon.stars.fill")
            }
        }
    }

    private func premiumPreviewTile(title: String, subtitle: String, icon: String) -> some View {
        Button {
            showPaywall = true
        } label: {
            MooniCard(padding: 14, cornerRadius: 22) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(MooniColor.accentSoft)
                        .frame(width: 38, height: 38)
                        .background(MooniColor.accent.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(MooniFont.title(13))
                            .foregroundColor(MooniColor.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        Text(subtitle)
                            .font(MooniFont.caption(10))
                            .foregroundColor(MooniColor.accentSoft)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(MooniColor.textMuted)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func tileShell<Icon: View>(
        title: String,
        subtitle: String,
        isSelected: Bool,
        isLocked: Bool,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 68)

                icon()

                if isLocked {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.34))
                        .frame(height: 68)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.76))
                }
            }

            Text(title)
                .font(MooniFont.caption(12))
                .foregroundColor(isLocked ? MooniColor.textMuted : MooniColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(subtitle)
                .font(MooniFont.caption(10))
                .foregroundColor(isSelected ? MooniColor.success : (isLocked ? MooniColor.textMuted : MooniColor.textSecondary))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(9)
        .background(Color.white.opacity(isSelected ? 0.11 : 0.045))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isSelected ? MooniColor.accent : Color.white.opacity(0.06), lineWidth: 1.4)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    // MARK: - Helpers

    private var evolutionCopy: String {
        guard let next = appState.nextEvolutionStage else {
            return "Luna has reached her brightest dream form."
        }

        if !subscriptionManager.isPro && isPremiumStage(next) {
            return "Luna is ready for deeper dream forms. Premium unlocks the full path."
        }

        let nights = appState.nightsUntilNextEvolution
        if nights == 0 {
            return "Luna is ready to grow into \(next.label)."
        }
        return "\(nights) more consistent night\(nights == 1 ? "" : "s") until \(next.label)."
    }

    private var nextStageName: String {
        appState.nextEvolutionStage?.label.replacingOccurrences(of: " form", with: "") ?? "Dream"
    }

    private var shouldShowEvolutionLock: Bool {
        guard let next = appState.nextEvolutionStage else { return false }
        return !subscriptionManager.isPro && isPremiumStage(next)
    }

    private func isPremiumStage(_ stage: Pet.EvolutionStage) -> Bool {
        switch stage {
        case .adult, .dream, .legendary: return true
        case .egg, .baby, .young: return false
        }
    }

    private func stageInitial(_ stage: Pet.EvolutionStage) -> String {
        switch stage {
        case .egg: return "E"
        case .baby: return "B"
        case .young: return "Y"
        case .adult: return "A"
        case .dream: return "D"
        case .legendary: return "L"
        }
    }

    private func shortStageLabel(_ stage: Pet.EvolutionStage) -> String {
        switch stage {
        case .egg: return "Egg"
        case .baby: return "Baby"
        case .young: return "Young"
        case .adult: return "Adult"
        case .dream: return "Dream"
        case .legendary: return "Rare"
        }
    }

    private func personalityCopy(_ personality: Personality) -> String {
        switch personality {
        case .consistent:
            return "Cozy: does best with consistent routines."
        case .nightOwl:
            return "Night Owl: active late, needs gentle wind-down."
        case .earlyBird:
            return "Bright and steady when mornings stay calm."
        case .recovering:
            return "Recovering gently after harder nights."
        case .explorer:
            return "Curious and flexible, still learning a steady rhythm."
        case .balanced:
            return "Balanced: adapts to whatever the night brings."
        }
    }

    private func items(for kind: UnlockableItem.Kind) -> [UnlockableItem] {
        UnlockableItem.catalog
            .filter { $0.kind == kind }
            .sorted { lhs, rhs in
                let lhsLocked = isPremiumItem(lhs) && !subscriptionManager.isPro
                let rhsLocked = isPremiumItem(rhs) && !subscriptionManager.isPro
                if lhsLocked != rhsLocked { return !lhsLocked }
                return lhs.requiredLevel < rhs.requiredLevel
            }
    }

    private func isPremiumItem(_ item: UnlockableItem) -> Bool {
        if item.id == "bg_starry_blanket" { return false }
        return item.requiredLevel >= 5 || item.kind == .background
    }

    private func premiumLockLabel(for item: UnlockableItem) -> String {
        if item.kind == .background { return "Premium unlock" }
        if item.id.contains("crown") { return "Premium unlock" }
        if item.id.contains("gold") { return "Seasonal item" }
        return "Rare sleep item"
    }

    private func starCost(for item: UnlockableItem) -> Int {
        max(0, item.requiredLevel - 1) * 20
    }

    private func isEquipped(_ item: UnlockableItem) -> Bool {
        switch item.kind {
        case .hat: return appState.pet.equippedHat == item.id
        case .color: return appState.pet.equippedColor == item.id
        case .background: return appState.pet.equippedBackground == item.id
        case .animation: return false
        }
    }
}

private struct EvolutionPathSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss
    @Binding var showPaywall: Bool

    private let stages: [Pet.EvolutionStage] = [.baby, .young, .adult, .dream, .legendary]

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                StarsBackground(count: 26)

                ScrollView {
                    VStack(spacing: 16) {
                        LunaMoodHero(
                            pet: appState.pet,
                            mood: .cozy,
                            size: 170,
                            caption: "Sleep rhythm helps Luna grow."
                        )

                        ForEach(stages, id: \.self) { stage in
                            stageRow(stage)
                        }

                        if !subscriptionManager.isPro {
                            MooniPremiumLockCard(
                                icon: "moon.stars.fill",
                                title: "Full evolution path",
                                subtitle: "Premium unlocks adult, dream, rare forms, and seasonal animations.",
                                actionTitle: "Unlock rare sleep forms"
                            ) {
                                showPaywall = true
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 80)
                }
            }
            .navigationTitle("Evolution Path")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(MooniColor.accent)
                }
            }
        }
    }

    private func stageRow(_ stage: Pet.EvolutionStage) -> some View {
        let currentIndex = stages.firstIndex(of: appState.pet.stage) ?? 0
        let stageIndex = stages.firstIndex(of: stage) ?? 0
        let isCurrent = stage == appState.pet.stage
        let isReached = stageIndex <= currentIndex
        let isLocked = !subscriptionManager.isPro && [.adult, .dream, .legendary].contains(stage)

        return Button {
            if isLocked {
                showPaywall = true
            }
        } label: {
            MooniCard(padding: 16, cornerRadius: 24) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(isReached ? MooniColor.accent.opacity(0.24) : Color.white.opacity(0.07))
                            .frame(width: 50, height: 50)
                        Image(systemName: isLocked ? "lock.fill" : (isReached ? "sparkles" : "moon.fill"))
                            .foregroundColor(isLocked ? MooniColor.textMuted : MooniColor.accentSoft)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(stage.label)
                            .font(MooniFont.title(16))
                            .foregroundColor(MooniColor.textPrimary)
                        Text(stageCopy(stage, isCurrent: isCurrent, isLocked: isLocked))
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func stageCopy(_ stage: Pet.EvolutionStage, isCurrent: Bool, isLocked: Bool) -> String {
        if isCurrent { return "Current stage. Keep Luna's rhythm steady." }
        if isLocked { return "Premium unlock. A deeper Luna form waits here." }
        return "\(stage.consistencyRequired) calm nights to reach this stage."
    }
}

#Preview {
    PetScreenView(showPaywall: .constant(false))
        .environmentObject(AppState.preview)
        .environmentObject(SubscriptionManager.shared)
}
