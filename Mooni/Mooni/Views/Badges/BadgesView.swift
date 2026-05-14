import SwiftUI

/// Full-screen list of every badge / unlock the pet can earn. Tapping the
/// "Badges & unlocks" card on the Me tab brings this up.
struct BadgesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private var unlockedIds: Set<String> { appState.pet.unlockedItems }
    private var level: Int { appState.pet.level }

    private var grouped: [(title: String, items: [UnlockableItem])] {
        let catalog = UnlockableItem.catalog
        return [
            ("Colors",      catalog.filter { $0.kind == .color }),
            ("Backgrounds", catalog.filter { $0.kind == .background }),
            ("Animations",  catalog.filter { $0.kind == .animation })
        ].filter { !$0.items.isEmpty }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MooniGradient.night.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        ForEach(grouped, id: \.title) { section in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(section.title)
                                    .font(MooniFont.title(17))
                                    .foregroundColor(MooniColor.textPrimary)
                                    .padding(.horizontal, 4)
                                LazyVGrid(
                                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                                    spacing: 10
                                ) {
                                    ForEach(section.items) { item in
                                        badgeTile(item)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 36)
                }
            }
            .navigationTitle("Badges & unlocks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(MooniColor.accent)
                }
            }
        }
    }

    private var header: some View {
        let unlocked = unlockedIds.count
        let total = UnlockableItem.catalog.count
        return MooniCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(unlocked) of \(total) unlocked")
                        .font(MooniFont.title(18))
                        .foregroundColor(MooniColor.textPrimary)
                    Spacer()
                    Text("Level \(level)")
                        .font(MooniFont.caption(12))
                        .foregroundColor(MooniColor.accentSoft)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(MooniColor.accent.opacity(0.18))
                        .clipShape(Capsule())
                }
                MooniProgressBar(value: Double(unlocked) / Double(max(total, 1)), height: 9)
                Text("Earn XP from sleep logs to level up — every level unlocks new badges, plus an extra streak freeze.")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func badgeTile(_ item: UnlockableItem) -> some View {
        let isUnlocked = unlockedIds.contains(item.id)
        let canUnlock = level >= item.requiredLevel
        let tint: Color = isUnlocked ? MooniColor.accent : MooniColor.textMuted
        return VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(isUnlocked ? 0.18 : 0.06))
                    .frame(height: 70)
                Image(systemName: isUnlocked ? item.icon : "lock.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(isUnlocked ? tint : MooniColor.textMuted)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(MooniFont.title(14))
                    .foregroundColor(MooniColor.textPrimary)
                    .lineLimit(1)
                Text(isUnlocked
                     ? "Unlocked"
                     : (canUnlock ? "Ready to unlock" : "Level \(item.requiredLevel) required"))
                    .font(MooniFont.caption(11))
                    .foregroundColor(isUnlocked ? MooniColor.success : MooniColor.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isUnlocked ? MooniColor.accent.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .opacity(isUnlocked ? 1 : 0.85)
    }
}

#Preview {
    BadgesView()
        .environmentObject(AppState.preview)
}
