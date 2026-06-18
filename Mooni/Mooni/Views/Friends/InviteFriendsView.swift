import SwiftUI

/// Friends hub. Three sections:
///   1. **Your code** — big, copyable, tap-to-copy, with explainer.
///   2. **Invite** — one-tap iMessage / share sheet with prefilled text.
///   3. **Add a friend** — 6-char paste field for incoming codes.
///   4. **Your friends** — list with avatar + remove.
///
/// Presented as a sheet from the LeagueCard "Invite friends" CTA and from
/// ProfileView. Self-contained — does not require any in-flight backend.
struct InviteFriendsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var manager = FriendsManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var codeInput: String = ""
    @State private var addStatus: AddStatus = .idle
    @State private var copied: Bool = false

    enum AddStatus: Equatable {
        case idle
        case ok(String)
        case error(String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    yourCodeCard
                    inviteButtonCard
                    addFriendCard
                    if !manager.friends.isEmpty {
                        friendsListCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .background(MooniGradient.night.ignoresSafeArea())
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(MooniColor.accentText)
                }
            }
        }
        .onAppear { syncWidget() }
        .onChange(of: manager.friends.count) { _, _ in syncWidget() }
    }

    // MARK: - Your code
    private var yourCodeCard: some View {
        VStack(spacing: 14) {
            Text("YOUR SLEEPOWL CODE")
                .font(MooniFont.caption(12))
                .tracking(1.4)
                .foregroundColor(MooniColor.textMuted)

            Button {
                UIPasteboard.general.string = manager.myCode
                Haptics.success()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut) { copied = false }
                }
            } label: {
                HStack(spacing: 10) {
                    Text(manager.myCode)
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .tracking(6)
                        .foregroundColor(MooniColor.textPrimary)
                    Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(copied ? MooniColor.xpGreen : MooniColor.accentSoft)
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(MooniColor.hairline)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(MooniColor.accentSoft.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Text("Share this code so friends can add you on Sleepowl.")
                .font(MooniFont.body(13))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }

    // MARK: - Invite button (the viral hook)
    private var inviteButtonCard: some View {
        let text = manager.inviteShareText(petName: appState.pet.name)
        return VStack(spacing: 10) {
            ShareLink(
                item: text,
                subject: Text("Sleep with me on Sleepowl"),
                message: Text(text)
            ) {
                HStack(spacing: 10) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Invite a friend")
                        .font(MooniFont.title(17))
                }
                .foregroundColor(MooniColor.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(MooniColor.accent)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .simultaneousGesture(TapGesture().onEnded { Haptics.soft() })

            Text("Opens iMessage / share sheet. Your code is prefilled.")
                .font(MooniFont.caption(11))
                .foregroundColor(MooniColor.textMuted)
        }
    }

    // MARK: - Add a friend
    private var addFriendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Got a code?")
                .font(MooniFont.title(15))
                .foregroundColor(MooniColor.textPrimary)

            HStack(spacing: 8) {
                TextField("e.g. AB3KP9", text: $codeInput)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .tracking(4)
                    .foregroundColor(MooniColor.textPrimary)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(MooniColor.hairline)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(MooniColor.hairline, lineWidth: 1)
                    )
                    .submitLabel(.go)
                    .onSubmit(addFromInput)

                Button {
                    addFromInput()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(MooniColor.background)
                        .frame(width: 50, height: 50)
                        .background(MooniColor.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(FriendCodeGenerator.sanitize(codeInput) == nil)
                .opacity(FriendCodeGenerator.sanitize(codeInput) == nil ? 0.5 : 1)
            }

            statusLine
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(MooniColor.hairline)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(MooniColor.hairline, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var statusLine: some View {
        switch addStatus {
        case .idle: EmptyView()
        case .ok(let name):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(MooniColor.xpGreen)
                Text("Added \(name)")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.xpGreenSoft)
            }
        case .error(let msg):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(MooniColor.warning)
                Text(msg)
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.warning)
            }
        }
    }

    private func addFromInput() {
        let result = manager.addFriend(rawCode: codeInput)
        switch result {
        case .added(let f):
            addStatus = .ok(f.resolvedName)
            codeInput = ""
        case .exists:
            addStatus = .error("That friend is already in your list.")
        case .invalid:
            addStatus = .error("Code must be 6 letters/numbers.")
            Haptics.error()
        case .selfCode:
            addStatus = .error("That's your own code. Share it instead.")
            Haptics.warning()
        }
    }

    // MARK: - Friends list
    private var friendsListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your friends")
                .font(MooniFont.title(15))
                .foregroundColor(MooniColor.textPrimary)

            ForEach(manager.friends) { friend in
                friendRow(friend)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(MooniColor.hairline)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(MooniColor.hairline, lineWidth: 1)
        )
    }

    private func friendRow(_ friend: FriendCode) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(MooniColor.accent.opacity(0.22))
                    .frame(width: 40, height: 40)
                Text(friend.avatarInitial)
                    .font(MooniFont.title(16))
                    .foregroundColor(MooniColor.textPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.resolvedName)
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textPrimary)
                Text(friend.code)
                    .font(MooniFont.caption(11))
                    .tracking(1.6)
                    .foregroundColor(MooniColor.textMuted)
            }

            Spacer(minLength: 0)

            Button {
                Haptics.soft()
                manager.removeFriend(code: friend.code)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(MooniColor.textMuted)
                    .padding(8)
                    .background(Circle().fill(MooniColor.hairline))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Widget sync
    private func syncWidget() {
        manager.syncToWidget(
            myLatest: appState.lastEntry,
            petName: appState.pet.name
        )
    }
}

#Preview {
    InviteFriendsView()
        .environmentObject(AppState.preview)
}
