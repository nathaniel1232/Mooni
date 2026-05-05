import SwiftUI

struct PetScreenView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @Binding var showPaywall: Bool
    @State private var selectedKind: UnlockableItem.Kind = .hat

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                StarsBackground(count: 50)

                ScrollView {
                    VStack(spacing: 22) {
                        petHero
                        evolutionCard
                        personalityCard
                        levelCard
                        nextUnlockCard
                        kindPicker
                        itemGrid
                    }
                    .padding(20)
                }
            }
            .navigationTitle(appState.pet.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if !subscriptionManager.isPro {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showPaywall = true
                        } label: {
                            Label("Pro", systemImage: "sparkles")
                                .font(MooniFont.caption(12))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    LinearGradient(colors: [MooniColor.accentSoft, MooniColor.accent],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Hero
    private var petHero: some View {
        VStack(spacing: 6) {
            DreamSpiritView(pet: appState.pet, size: 200)
            Text(appState.pet.mood.label)
                .font(MooniFont.title(16))
                .foregroundColor(MooniColor.accent)
        }
    }

    // MARK: - Evolution
    private var evolutionCard: some View {
        let stages = Pet.EvolutionStage.allCases
        let currentIdx = stages.firstIndex(of: appState.pet.stage) ?? 0
        let consistency = appState.bedtimeConsistencyDays
        let nextStage: Pet.EvolutionStage? = currentIdx + 1 < stages.count ? stages[currentIdx + 1] : nil
        let toGo = nextStage.map { max(0, $0.consistencyRequired - consistency) }

        return MooniCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Evolution", systemImage: "arrow.up.right.circle.fill")
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    Text(appState.pet.stage.label)
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.accent)
                }

                HStack(spacing: 6) {
                    ForEach(Array(stages.enumerated()), id: \.element) { idx, stage in
                        Capsule()
                            .fill(idx <= currentIdx ? MooniColor.accent : Color.white.opacity(0.12))
                            .frame(height: 6)
                        if idx < stages.count - 1 {
                            Rectangle().fill(Color.clear).frame(width: 0)
                        }
                    }
                }

                if let next = nextStage, let togo = toGo {
                    Text(togo == 0
                         ? "Ready to evolve into \(next.label) — keep your streak!"
                         : "\(togo) more consistent night\(togo == 1 ? "" : "s") until \(next.label).")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                } else {
                    Text("Maxed out — \(appState.pet.name) is in their \(appState.pet.stage.label).")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }

                if !subscriptionManager.isPro {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                        Text("Adult, Dream form & Legendary forms unlock with Pro.")
                            .font(MooniFont.caption(11))
                    }
                    .foregroundColor(MooniColor.textMuted)
                }
            }
        }
    }

    // MARK: - Personality
    private var personalityCard: some View {
        let p = appState.petPersonality
        return MooniCard {
            HStack(spacing: 14) {
                Image(systemName: p.icon)
                    .font(.system(size: 22))
                    .foregroundColor(MooniColor.accentSoft)
                    .frame(width: 44, height: 44)
                    .background(MooniColor.accentSoft.opacity(0.16))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.label)
                        .font(MooniFont.title(15))
                        .foregroundColor(MooniColor.textPrimary)
                    Text(p.description)
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.textSecondary)
                }
                Spacer()
            }
        }
    }

    // MARK: - Level
    private var levelCard: some View {
        MooniCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Level \(appState.pet.level)")
                            .font(MooniFont.title(18))
                            .foregroundColor(MooniColor.textPrimary)
                        Text("Dream energy \(appState.pet.dreamEnergy) / \(appState.pet.energyForNextLevel)")
                            .font(MooniFont.caption(13))
                            .foregroundColor(MooniColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 24))
                        .foregroundColor(MooniColor.accent)
                }
                progressBar(value: appState.pet.levelProgress)
            }
        }
    }

    private func progressBar(value: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [MooniColor.accentSoft, MooniColor.accent], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * CGFloat(value))
            }
        }
        .frame(height: 8)
    }

    // MARK: - Next unlock
    @ViewBuilder
    private var nextUnlockCard: some View {
        if let next = nextUnlock() {
            MooniCard {
                HStack(spacing: 14) {
                    Image(systemName: next.icon)
                        .font(.system(size: 28))
                        .foregroundColor(MooniColor.accent)
                        .frame(width: 50, height: 50)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next unlock")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textSecondary)
                        Text(next.name)
                            .font(MooniFont.title(17))
                            .foregroundColor(MooniColor.textPrimary)
                        Text("Reach level \(next.requiredLevel)")
                            .font(MooniFont.caption(12))
                            .foregroundColor(MooniColor.textMuted)
                    }
                    Spacer()
                }
            }
        }
    }

    private func nextUnlock() -> UnlockableItem? {
        UnlockableItem.catalog
            .filter { $0.requiredLevel > appState.pet.level }
            .sorted { $0.requiredLevel < $1.requiredLevel }
            .first
    }

    // MARK: - Kind picker
    private var kindPicker: some View {
        HStack(spacing: 8) {
            ForEach([UnlockableItem.Kind.hat, .color, .background], id: \.self) { kind in
                let selected = selectedKind == kind
                Button {
                    withAnimation { selectedKind = kind }
                } label: {
                    Text(label(for: kind))
                        .font(MooniFont.caption(13))
                        .foregroundColor(selected ? MooniColor.background : MooniColor.textPrimary)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity)
                        .background(selected ? MooniColor.accent : Color.white.opacity(0.06))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func label(for kind: UnlockableItem.Kind) -> String {
        switch kind {
        case .hat: return "Hats"
        case .color: return "Colors"
        case .background: return "Backgrounds"
        case .animation: return "Animations"
        }
    }

    // MARK: - Items
    private var itemGrid: some View {
        let items = UnlockableItem.catalog.filter { $0.kind == selectedKind }
        let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]
        return LazyVGrid(columns: columns, spacing: 12) {
            if selectedKind == .hat {
                noneTile()
            }
            ForEach(items) { item in
                tile(for: item)
            }
        }
    }

    private func noneTile() -> some View {
        let selected = appState.pet.equippedHat == nil
        return Button {
            appState.unequipHat()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "circle.slash")
                    .font(.system(size: 26))
                    .foregroundColor(MooniColor.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text("None")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
            }
            .padding(8)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? MooniColor.accent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func tile(for item: UnlockableItem) -> some View {
        let unlocked = appState.pet.unlockedItems.contains(item.id)
        let equipped = isEquipped(item)
        return Button {
            if unlocked { appState.equip(item) }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 60)

                    if item.kind == .color {
                        Circle()
                            .fill(UnlockableItem.color(for: item.id))
                            .frame(width: 32, height: 32)
                            .shadow(color: UnlockableItem.color(for: item.id).opacity(0.5), radius: 6)
                    } else {
                        Image(systemName: item.icon)
                            .font(.system(size: 24))
                            .foregroundColor(unlocked ? MooniColor.textPrimary : MooniColor.textMuted)
                    }

                    if !unlocked {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.45))
                            .overlay(
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.white.opacity(0.7))
                            )
                            .frame(height: 60)
                    }
                }

                Text(item.name)
                    .font(MooniFont.caption(12))
                    .foregroundColor(unlocked ? MooniColor.textPrimary : MooniColor.textMuted)
                    .lineLimit(1)

                if !unlocked {
                    Text("Lvl \(item.requiredLevel)")
                        .font(MooniFont.caption(10))
                        .foregroundColor(MooniColor.textMuted)
                } else if equipped {
                    Text("Equipped")
                        .font(MooniFont.caption(10))
                        .foregroundColor(MooniColor.success)
                }
            }
            .padding(8)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(equipped ? MooniColor.accent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }

    private func isEquipped(_ item: UnlockableItem) -> Bool {
        switch item.kind {
        case .hat:        return appState.pet.equippedHat == item.id
        case .color:      return appState.pet.equippedColor == item.id
        case .background: return appState.pet.equippedBackground == item.id
        case .animation:  return false
        }
    }
}

#Preview {
    PetScreenView(showPaywall: .constant(false))
        .environmentObject(AppState.preview)
        .environmentObject(SubscriptionManager.shared)
}
