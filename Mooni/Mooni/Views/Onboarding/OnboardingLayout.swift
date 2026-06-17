import SwiftUI
import UIKit

// MARK: - Reveal coordination

/// Flipped true by a screen's scaffold once its title has finished typing, so
/// the answer rows below can begin their staggered slide-in. Defaults to `true`
/// so any view using `StaggeredReveal` outside an animated scaffold simply
/// reveals immediately instead of staying hidden forever.
private struct OnboardingRevealStartedKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var onboardingRevealStarted: Bool {
        get { self[OnboardingRevealStartedKey.self] }
        set { self[OnboardingRevealStartedKey.self] = newValue }
    }
}

// MARK: - FlowLayout

/// Wraps word subviews left-to-right, breaking to a new line when the next word
/// won't fit. Used by `TypewriterText` so the *whole* title is laid out up front
/// and only each word's opacity/offset animates — nothing reflows as words
/// appear. Honors leading / center alignment.
struct FlowLayout: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 3

    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(maxWidth: maxWidth, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: maxWidth.isFinite ? maxWidth : width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x: CGFloat
            switch alignment {
            case .center:   x = bounds.minX + (bounds.width - row.width) / 2
            case .trailing: x = bounds.minX + (bounds.width - row.width)
            default:        x = bounds.minX
            }
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if current.indices.isEmpty {
                current.indices = [index]; current.width = size.width; current.height = size.height
            } else if current.width + spacing + size.width <= maxWidth {
                current.indices.append(index)
                current.width += spacing + size.width
                current.height = max(current.height, size.height)
            } else {
                rows.append(current)
                current = Row(); current.indices = [index]; current.width = size.width; current.height = size.height
            }
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: - TypewriterText

/// Reveals a title word-by-word with a soft haptic per word — the "writing in"
/// effect for onboarding headlines. The full string is laid out immediately via
/// `FlowLayout` (each word a separate `Text`), so revealing a word only animates
/// its opacity/offset and the line never reflows or jumps. Respects Reduce
/// Motion (renders instantly). Uses the app's Outfit display font so it matches
/// `MooniFont.display`.
struct TypewriterText: View {
    let text: String
    var size: CGFloat = 30
    /// .leading for question headers, .center for content titles.
    var alignment: TextAlignment = .leading
    var color: Color = MooniColor.textPrimary
    /// Typing only runs once this flips true (lets the parent wait out the
    /// screen transition before the headline writes in).
    var start: Bool = true
    var onComplete: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed: Int = 0
    @State private var didStart = false

    private struct Tok: Identifiable { let id: Int; let word: String }

    /// Words grouped by explicit `\n` line, each tagged with a global index so
    /// the reveal counter spans the whole title across line breaks.
    private var lines: [[Tok]] {
        var result: [[Tok]] = []
        var counter = 0
        for rawLine in text.components(separatedBy: "\n") {
            let words = rawLine.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            var lineToks: [Tok] = []
            for w in words { lineToks.append(Tok(id: counter, word: w)); counter += 1 }
            result.append(lineToks)
        }
        return result
    }

    private var totalWords: Int { lines.reduce(0) { $0 + $1.count } }

    /// Real space advance for the display weight so inter-word spacing matches
    /// a native multi-word `Text`.
    private var spaceWidth: CGFloat {
        let f = UIFont(name: "Outfit-Bold", size: size) ?? UIFont.systemFont(ofSize: size, weight: .bold)
        return (" " as NSString).size(withAttributes: [.font: f]).width
    }

    private var hAlignment: HorizontalAlignment { alignment == .center ? .center : .leading }
    private var frameAlignment: Alignment { alignment == .center ? .center : .leading }

    var body: some View {
        VStack(alignment: hAlignment, spacing: 3) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                FlowLayout(alignment: hAlignment, spacing: spaceWidth, lineSpacing: 3) {
                    ForEach(line) { tok in
                        Text(tok.word)
                            .font(MooniFont.display(size))
                            .foregroundColor(color)
                            .lineSpacing(2)
                            .opacity(tok.id < revealed ? 1 : 0)
                            .offset(y: tok.id < revealed ? 0 : 5)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .animation(.easeOut(duration: 0.32), value: revealed)
        .onAppear { if start { begin() } }
        .onChange(of: start) { _, go in if go { begin() } }
    }

    private func begin() {
        guard !didStart else { return }
        didStart = true
        guard totalWords > 0 else { onComplete(); return }
        if reduceMotion {
            revealed = totalWords
            onComplete()
            return
        }
        Task { @MainActor in
            for i in 1...totalWords {
                revealed = i
                Haptics.tap()
                try? await Task.sleep(nanoseconds: 90_000_000)
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
            onComplete()
        }
    }
}

// MARK: - StaggeredReveal

/// Lays out its children in a VStack and slides them in one-by-one (with a light
/// tick each) once `\.onboardingRevealStarted` flips true. Drop-in around an
/// existing `ForEach` of option rows — `_VariadicView` flattens the ForEach so
/// each row is staggered individually without touching the row's own view.
struct StaggeredReveal<Content: View>: View {
    var spacing: CGFloat = 10
    var perItemDelay: Double = 0.07
    var haptics: Bool = true
    @ViewBuilder var content: Content

    var body: some View {
        _VariadicView.Tree(
            StaggerRoot(spacing: spacing, perItemDelay: perItemDelay, haptics: haptics)
        ) {
            content
        }
    }
}

private struct StaggerRoot: _VariadicView_MultiViewRoot {
    var spacing: CGFloat
    var perItemDelay: Double
    var haptics: Bool

    @ViewBuilder
    func body(children: _VariadicView.Children) -> some View {
        VStack(spacing: spacing) {
            ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                StaggerItem(index: index, perItemDelay: perItemDelay, haptics: haptics) {
                    child
                }
            }
        }
    }
}

/// Zero-size sentinel that fires `action` once `\.onboardingRevealStarted`
/// flips true — lets a screen kick off its own bespoke reveal sequence (e.g. a
/// "why it matters" line then the answers) in step with the title finishing.
struct OnRevealStart: View {
    let action: () -> Void
    @Environment(\.onboardingRevealStarted) private var started
    @State private var fired = false

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear { if started { fire() } }
            .onChange(of: started) { _, go in if go { fire() } }
    }

    private func fire() {
        guard !fired else { return }
        fired = true
        action()
    }
}

private struct StaggerItem<Content: View>: View {
    let index: Int
    let perItemDelay: Double
    let haptics: Bool
    @ViewBuilder var content: Content

    @Environment(\.onboardingRevealStarted) private var started
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .onAppear { maybeReveal() }
            .onChange(of: started) { _, _ in maybeReveal() }
    }

    private func maybeReveal() {
        guard started, !shown else { return }
        if reduceMotion { shown = true; return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * perItemDelay) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { shown = true }
            if haptics { Haptics.tick() }
        }
    }
}

/// Single source of truth for the onboarding flow's look.
///
/// Every screen used to hand-roll its own padding, spacing, header chip and
/// a different tint per card (warning / danger / pink / accent …) which made
/// the flow feel inconsistent and noisy. Screens now compose from these
/// shared atoms so the whole flow reads as ONE designed product: identical
/// edge padding, identical vertical rhythm, identical typography, and a
/// single accent colour throughout. Change it here → changes everywhere.
enum OnboardingLayout {
    /// Horizontal screen-edge padding for every onboarding step.
    static let hPad: CGFloat = 24
    /// The one accent. No per-card rainbow.
    static let accent: Color = MooniColor.accent
}

extension View {
    /// Standard onboarding screen edge padding.
    func onboardingEdge() -> some View {
        padding(.horizontal, OnboardingLayout.hPad)
    }
}

// MARK: - Atoms

/// Small uppercase eyebrow chip above a title. Always the single accent.
struct OBEyebrow: View {
    let emoji: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            EmojiIcon(emoji: emoji, size: 12, tint: OnboardingLayout.accent)
            Text(text.uppercased())
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundColor(OnboardingLayout.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(OnboardingLayout.accent.opacity(0.16))
        .clipShape(Capsule())
    }
}

struct OBTitle: View {
    let text: String
    var animated: Bool
    var onComplete: () -> Void
    init(_ text: String, animated: Bool = true, onComplete: @escaping () -> Void = {}) {
        self.text = text
        self.animated = animated
        self.onComplete = onComplete
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var armed = false

    var body: some View {
        Group {
            if animated {
                TypewriterText(text: text, size: 30, alignment: .center,
                               start: armed, onComplete: onComplete)
            } else {
                Text(text)
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            guard animated else { return }
            if reduceMotion { armed = true; return }
            // Let the screen transition settle before the headline writes in.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { armed = true }
        }
    }
}

struct OBSubtitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(MooniFont.body(15))
            .foregroundColor(MooniColor.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Left-aligned title + optional subtitle for *question* screens. The quiz
/// reads top-left (title sits on the same band as the back chevron) instead of
/// the old dead-centre look, which felt floaty and pushed the answer controls
/// too far down the screen. Content screens still use the centred OBTitle.
struct QuestionHeader: View {
    let title: String
    var subtitle: String? = nil
    var animated: Bool = true
    /// Fired when the title finishes typing — the scaffold uses this to start
    /// revealing the answer rows below.
    var onTitleComplete: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var armed = false
    @State private var showSubtitle = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if animated {
                TypewriterText(text: title, size: 30, alignment: .leading, start: armed) {
                    withAnimation(.easeOut(duration: 0.3)) { showSubtitle = true }
                    onTitleComplete()
                }
            } else {
                Text(title)
                    .font(MooniFont.display(30))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let subtitle {
                Text(subtitle)
                    .font(MooniFont.body(15))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(animated ? (showSubtitle ? 1 : 0) : 1)
                    .offset(y: animated ? (showSubtitle ? 0 : 4) : 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            guard animated else { onTitleComplete(); return }
            if reduceMotion { armed = true; return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { armed = true }
        }
    }
}

/// The one card used for every list / option / stat row in onboarding.
/// Single accent, optional subtitle, built-in reveal offset.
struct OBCard: View {
    let emoji: String
    let title: String
    var subtitle: String? = nil
    var visible: Bool = true

    var body: some View {
        HStack(spacing: 14) {
            EmojiIcon(emoji: emoji, size: 24, tint: OnboardingLayout.accent)
                .frame(width: 52, height: 52)
                .background(OnboardingLayout.accent.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(MooniColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(MooniFont.body(13))
                        .foregroundColor(MooniColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(OnboardingLayout.accent.opacity(0.18), lineWidth: 1)
        )
        .opacity(visible ? 1 : 0)
        .offset(x: visible ? 0 : -16)
    }
}

// MARK: - Scaffold

/// Every "title + content" onboarding screen flows through this so the
/// eyebrow→title→subtitle→content rhythm and edge padding are pixel-identical
/// on every step. Screens with a hero visual on top use `OBTitle`/`OBSubtitle`
/// directly under their visual instead.
struct OnboardingScaffold<Content: View>: View {
    var eyebrow: (emoji: String, text: String)? = nil
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content

    @State private var revealRest = false

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 12) {
                if let eyebrow {
                    OBEyebrow(emoji: eyebrow.emoji, text: eyebrow.text)
                }
                OBTitle(title, onComplete: {
                    withAnimation(.easeOut(duration: 0.3)) { revealRest = true }
                })
                if let subtitle {
                    OBSubtitle(subtitle)
                        .opacity(revealRest ? 1 : 0)
                        .offset(y: revealRest ? 0 : 4)
                }
            }
            // Content keeps its own entrance choreography; we only publish the
            // reveal signal so any `StaggeredReveal` inside waits for the title.
            content
                .environment(\.onboardingRevealStarted, revealRest)
        }
        .frame(maxWidth: .infinity)
        .onboardingEdge()
    }
}
