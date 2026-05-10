import SwiftUI
import Combine

/// Animated emotional pre-paywall sequence. Three screens drive the prospect
/// through the problem (bad sleep), the promise (good sleep), and the
/// commitment ("ready to invest in [pet]'s health?") before the actual paywall.
struct PrePaywallView: View {
    let petName: String
    let species: PetSpecies
    let profile: OnboardingProfile
    let onContinue: () -> Void

    @State private var phase: Phase = .badSleep
    @State private var subStage: Int = 0

    // Signature stage state
    @State private var signatureStrokes: [SignatureStroke] = []
    @State private var typedCommitment: String = ""

    // Transformation list reveal count
    @State private var revealedTransformations: Int = 0

    private enum Phase: Int, CaseIterable {
        case badSleep
        case goodSleep
        case yesLadder       // 5 quick yes-questions (foot-in-the-door)
        case signature       // type "I am committed" + draw signature
        case transformAnim   // animated metrics climbing + pet evolving
        case transformList   // benefits revealing one by one
        case commitment      // final ready-to-invest stage
    }

    /// Number of yes-ladder sub-questions.
    private static let yesLadderCount = 5

    private static let yesLadderQuestions: [String] = [
        "Do you want to wake up rested tomorrow?",
        "Are you tired of being tired?",
        "Will you commit to your sleep this week?",
        "Will you let your pet grow with you?",
        "Are you ready to actually do this?"
    ]

    var body: some View {
        ZStack {
            // Constant dark background — matches the rest of onboarding.
            MooniColor.background
                .ignoresSafeArea()
            StarsBackground(count: 80)

            VStack {
                phaseProgressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                Spacer(minLength: 0)

                Group {
                    switch phase {
                    case .badSleep:
                        BadSleepStage(subStage: subStage, petName: petName, species: species, profile: profile)
                    case .goodSleep:
                        GoodSleepStage(subStage: subStage, petName: petName, species: species)
                    case .yesLadder:
                        YesLadderStage(
                            question: Self.yesLadderQuestions[min(subStage, Self.yesLadderCount - 1)],
                            stepIndex: subStage,
                            total: Self.yesLadderCount,
                            petName: petName
                        )
                    case .signature:
                        SignatureStage(
                            petName: petName,
                            typedCommitment: $typedCommitment,
                            strokes: $signatureStrokes
                        )
                    case .transformAnim:
                        TransformAnimStage(petName: petName, species: species)
                    case .transformList:
                        TransformListStage(revealed: $revealedTransformations)
                    case .commitment:
                        CommitmentStage(petName: petName, species: species, profile: profile)
                    }
                }
                .id("\(phase.rawValue)-\(subStage)")
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))

                Spacer(minLength: 0)

                footer
                    .padding(.horizontal, 24)
                    .padding(.bottom, 36)
            }
        }
    }

    private var phaseProgressBar: some View {
        HStack(spacing: 6) {
            ForEach(Phase.allCases, id: \.rawValue) { p in
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.25))
                        Capsule()
                            .fill(Color.white)
                            .frame(width: geo.size.width * progressFraction(for: p))
                            .animation(.spring(response: 0.4), value: phase)
                            .animation(.spring(response: 0.4), value: subStage)
                            .animation(.spring(response: 0.4), value: revealedTransformations)
                    }
                }
                .frame(height: 4)
            }
        }
    }

    /// 0…1 fill for a single phase pill, taking sub-stage progress into account
    /// so the bar inches forward on every tap rather than jumping once per phase.
    private func progressFraction(for p: Phase) -> CGFloat {
        if p.rawValue < phase.rawValue { return 1 }
        if p.rawValue > phase.rawValue { return 0 }
        switch phase {
        case .badSleep:      return CGFloat(subStage + 1) / 3
        case .goodSleep:     return CGFloat(subStage + 1) / 3
        case .yesLadder:     return CGFloat(subStage + 1) / CGFloat(Self.yesLadderCount)
        case .signature:
            let typed = typedCommitment.trimmingCharacters(in: .whitespacesAndNewlines)
            let typedDone: CGFloat = Self.isCommitmentPhraseMatched(typed) ? 0.5 : CGFloat(min(typed.count, 14)) / 14 * 0.5
            let signed: CGFloat   = signatureStrokes.isEmpty ? 0 : 0.5
            return min(typedDone + signed, 1)
        case .transformAnim: return 0.5
        case .transformList:
            let total = TransformListStage.items.count
            return total == 0 ? 1 : CGFloat(revealedTransformations) / CGFloat(total)
        case .commitment:    return 1
        }
    }

    private var primaryTitle: String {
        switch (phase, subStage) {
        case (.badSleep, 0):  return "I see myself"
        case (.badSleep, 1):  return "That's me"
        case (.badSleep, _):  return "I want to change this"
        case (.goodSleep, 0): return "I want to feel this"
        case (.goodSleep, 1): return "Show me \(petName)"
        case (.goodSleep, _): return "Continue"
        case (.yesLadder, _): return "Yes"
        case (.signature, _): return "I commit — sign me up"
        case (.transformAnim, _): return "Show me everything"
        case (.transformList, _): return revealedTransformations >= TransformListStage.items.count ? "I want all of this" : "..."
        case (.commitment, _): return "Yes, I'm ready"
        }
    }

    private var canAdvanceFromCurrent: Bool {
        switch phase {
        case .signature:
            return Self.isCommitmentPhraseMatched(typedCommitment) && !signatureStrokes.isEmpty
        case .transformList:
            return revealedTransformations >= TransformListStage.items.count
        default:
            return true
        }
    }

    fileprivate static func isCommitmentPhraseMatched(_ text: String) -> Bool {
        let words = normalizedCommitmentWords(text)
        guard !words.isEmpty else { return false }

        let normalized = words.joined()
        let exactTargets = [
            "iamcommitted",
            "iamcommited",
            "imcommitted",
            "imcommited"
        ]

        if exactTargets.contains(normalized) { return true }
        if exactTargets.contains(where: { editDistance(normalized, $0) <= 3 }) { return true }

        let selfWords = ["i", "im", "iam", "me", "my"]
        let commitmentWords = ["committed", "commited", "commit", "promise", "ready", "agree", "dedicated"]
        let hasSelfWord = words.contains { selfWords.contains($0) }
        let hasCommitmentWord = words.contains { word in
            commitmentWords.contains(word) ||
            editDistance(word, "committed") <= 2 ||
            editDistance(word, "commit") <= 1 ||
            editDistance(word, "promise") <= 2
        }

        return hasSelfWord && hasCommitmentWord
    }

    private static func normalizedCommitmentWords(_ text: String) -> [String] {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
    }

    private static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previous = Array(0...b.count)
        var current = Array(repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let substitution = previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
                current[j] = min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    substitution
                )
            }
            swap(&previous, &current)
        }

        return previous[b.count]
    }

    @ViewBuilder
    private var footer: some View {
        switch phase {
        case .commitment:
            VStack(spacing: 10) {
                PrimaryButton(title: primaryTitle, icon: "sparkles") {
                    onContinue()
                }
                Text("This decision changes \(petName)'s future too.")
                    .font(MooniFont.caption(12))
                    .foregroundColor(.white.opacity(0.55))
            }
        case .yesLadder:
            // Just one big "Yes" to keep momentum. No button to tap "no".
            VStack(spacing: 10) {
                PrimaryButton(title: "YES", icon: "checkmark.circle.fill") {
                    advance()
                }
                Text("Tap to commit.")
                    .font(MooniFont.caption(11))
                    .foregroundColor(.white.opacity(0.4))
            }
        case .transformList:
            PrimaryButton(title: primaryTitle, icon: revealedTransformations >= TransformListStage.items.count ? "sparkles" : nil) {
                if canAdvanceFromCurrent { advance() }
            }
            .disabled(!canAdvanceFromCurrent)
            .opacity(canAdvanceFromCurrent ? 1 : 0.4)
        case .signature:
            PrimaryButton(title: primaryTitle, icon: "signature") {
                if canAdvanceFromCurrent { advance() }
            }
            .disabled(!canAdvanceFromCurrent)
            .opacity(canAdvanceFromCurrent ? 1 : 0.4)
        default:
            PrimaryButton(title: primaryTitle) {
                advance()
            }
        }
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.45)) {
            switch phase {
            case .badSleep:
                if subStage < 2 { subStage += 1 } else { phase = .goodSleep; subStage = 0 }
            case .goodSleep:
                if subStage < 2 { subStage += 1 } else { phase = .yesLadder; subStage = 0 }
            case .yesLadder:
                if subStage < Self.yesLadderCount - 1 { subStage += 1 }
                else { phase = .signature; subStage = 0 }
            case .signature:
                phase = .transformAnim; subStage = 0
            case .transformAnim:
                phase = .transformList; subStage = 0
            case .transformList:
                phase = .commitment; subStage = 0
            case .commitment:
                break
            }
        }
    }
}

// MARK: - Phase 1: Bad sleep

private struct BadSleepStage: View {
    let subStage: Int
    let petName: String
    let species: PetSpecies
    let profile: OnboardingProfile

    @State private var dimmer = false
    @State private var heartbeat = false
    /// Animation gates — each in its own state so we can sequence them on
    /// onAppear instead of letting halo/pet/text race independently.
    @State private var heroIn = false
    @State private var statIn = false
    @State private var bodyIn = false

    private var sadPet: Pet {
        var p = Pet(); p.species = species; p.mood = .low; return p
    }

    var body: some View {
        VStack(spacing: 18) {
            // Eyebrow + small pet medallion at top — pet stays present
            // but no longer dominates the screen. Problems are primary.
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(dimmer ? 0.32 : 0.10))
                        .frame(width: 86, height: 86)
                        .blur(radius: 14)
                    PetIllustration(pet: sadPet, size: 76)
                        .grayscale(dimmer ? 0.55 : 0.15)
                }
                .frame(width: 92, height: 92)
                .scaleEffect(heroIn ? 1.0 : 0.85)
                .opacity(heroIn ? 1.0 : 0.0)

                VStack(alignment: .leading, spacing: 2) {
                    Text("WITHOUT CHANGE…")
                        .font(MooniFont.caption(12))
                        .foregroundColor(.white.opacity(0.55))
                        .tracking(1.6)
                    Text("\(petName) is at risk")
                        .font(MooniFont.title(15))
                        .foregroundColor(.white.opacity(0.85))
                }
                .opacity(heroIn ? 1.0 : 0.0)
                .offset(x: heroIn ? 0 : -8)
                Spacer()
            }
            .padding(.horizontal, 4)

            // Big problem statement — the screen's actual point.
            Group {
                switch subStage {
                case 0: badStat1
                case 1: badStat2
                default: badStat3
                }
            }
            .opacity(statIn ? 1 : 0)
            .offset(y: statIn ? 0 : 12)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 24)
        .onAppear {
            // Reset on every sub-stage swap and replay in lockstep so the
            // halo, pet, headline and chips arrive in a single coherent wave.
            heroIn = false; statIn = false; bodyIn = false
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { heroIn = true }
            withAnimation(.easeOut(duration: 0.45).delay(0.18)) { statIn = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.36)) { bodyIn = true }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { dimmer = true }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { heartbeat = true }
        }
        .onChange(of: subStage) { _, _ in
            statIn = false; bodyIn = false
            withAnimation(.easeOut(duration: 0.45)) { statIn = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.18)) { bodyIn = true }
        }
    }

    private var badStat1: some View {
        VStack(spacing: 14) {
            Text("You're aging \(profile.sleepAgeYearsAdded) yrs faster")
                .font(MooniFont.display(38))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                statChip(icon: "brain.head.profile", text: "−27.4% memory recall")
                statChip(icon: "heart.fill", text: "+48% cardiovascular strain")
                statChip(icon: "face.smiling", text: "−63% mood resilience")
            }
            .opacity(bodyIn ? 1 : 0)
            .offset(y: bodyIn ? 0 : 6)
        }
    }

    private var badStat2: some View {
        VStack(spacing: 12) {
            Text("\(max(profile.daysLostPerYear, 18)) days/year")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(
                    colors: [Color.red.opacity(0.9), Color.orange.opacity(0.85)],
                    startPoint: .top, endPoint: .bottom))
                .scaleEffect(heartbeat ? 1.04 : 0.97)
            Text("are silently lost\nto grogginess + fatigue.")
                .font(MooniFont.display(24))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 6)
        }
    }

    private var badStat3: some View {
        VStack(spacing: 12) {
            Text("\(petName) feels it too.")
                .font(MooniFont.display(34))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("Tired you = tired \(petName). Stuck together until you decide to change tonight.")
                .font(MooniFont.body(16))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .opacity(bodyIn ? 1 : 0)
        }
    }

    private func statChip(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(Color.red.opacity(0.85))
            Text(text)
                .font(MooniFont.title(15))
                .foregroundColor(.white)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.red.opacity(0.32), lineWidth: 1)
        )
    }
}

// MARK: - Phase 2: Good sleep

private struct GoodSleepStage: View {
    let subStage: Int
    let petName: String
    let species: PetSpecies

    @State private var glow = false

    private var brightPet: Pet {
        var p = Pet(); p.species = species; p.mood = .energized;        return p
    }

    @State private var heroIn = false
    @State private var statIn = false
    @State private var bodyIn = false

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(glow ? 0.40 : 0.18))
                        .frame(width: 96, height: 96)
                        .blur(radius: 18)
                    PetIllustration(pet: brightPet, size: 80)
                }
                .frame(width: 92, height: 92)
                .scaleEffect(heroIn ? 1.0 : 0.85)
                .opacity(heroIn ? 1.0 : 0.0)

                VStack(alignment: .leading, spacing: 2) {
                    Text("WITH SLEEPOWL…")
                        .font(MooniFont.caption(12))
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(1.6)
                    Text("\(petName) gets brighter")
                        .font(MooniFont.title(15))
                        .foregroundColor(.white.opacity(0.92))
                }
                .opacity(heroIn ? 1.0 : 0.0)
                .offset(x: heroIn ? 0 : -8)
                Spacer()
            }
            .padding(.horizontal, 4)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { glow = true }
            }

            Group {
                switch subStage {
                case 0: goodStat1
                case 1: goodStat2
                default: goodStat3
                }
            }
            .opacity(statIn ? 1 : 0)
            .offset(y: statIn ? 0 : 12)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 24)
        .onAppear {
            heroIn = false; statIn = false; bodyIn = false
            withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) { heroIn = true }
            withAnimation(.easeOut(duration: 0.45).delay(0.18)) { statIn = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.36)) { bodyIn = true }
        }
        .onChange(of: subStage) { _, _ in
            statIn = false; bodyIn = false
            withAnimation(.easeOut(duration: 0.45)) { statIn = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.18)) { bodyIn = true }
        }
    }

    private var goodStat1: some View {
        VStack(spacing: 14) {
            Text("Wake up rested\nin 7 nights")
                .font(MooniFont.display(38))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            VStack(spacing: 8) {
                goodChip(icon: "bolt.fill", text: "+87% morning energy")
                goodChip(icon: "brain.head.profile", text: "+43% mental clarity")
                goodChip(icon: "face.smiling", text: "+62% mood lift")
            }
            .opacity(bodyIn ? 1 : 0)
            .offset(y: bodyIn ? 0 : 6)
        }
    }

    private var goodStat2: some View {
        VStack(spacing: 14) {
            Text("\(petName) glows with you")
                .font(MooniFont.display(32))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("Real sleep → real evolution. Each rested night, \(petName) levels up beside you.")
                .font(MooniFont.body(16))
                .foregroundColor(.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            HStack(spacing: 10) {
                evolutionChip(label: "Day 1", mood: .calm)
                Image(systemName: "arrow.right").foregroundColor(.white.opacity(0.6))
                evolutionChip(label: "Day 7", mood: .cozy)
                Image(systemName: "arrow.right").foregroundColor(.white.opacity(0.6))
                evolutionChip(label: "Day 30", mood: .energized)
            }
            .padding(.top, 6)
        }
    }

    private var goodStat3: some View {
        VStack(spacing: 14) {
            Text("This is your future")
                .font(MooniFont.display(28))
                .foregroundColor(.white)
            Text("if you commit to better sleep tonight.")
                .font(MooniFont.body(16))
                .foregroundColor(.white.opacity(0.92))
                .multilineTextAlignment(.center)
        }
    }

    private func goodChip(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(MooniColor.success)
            Text(text)
                .font(MooniFont.title(14))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.10))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 1))
    }

    private func evolutionChip(label: String, mood: Pet.Mood) -> some View {
        VStack(spacing: 6) {
            PetIllustration(
                pet: { var p = Pet(); p.species = species; p.mood = mood; p.equippedHat = nil; return p }(),
                size: 50
            )
            .frame(width: 70, height: 70)
            Text(label)
                .font(MooniFont.caption(11))
                .foregroundColor(.white.opacity(0.85))
        }
    }
}

// MARK: - Phase 3: Commitment

private struct CommitmentStage: View {
    let petName: String
    let species: PetSpecies
    let profile: OnboardingProfile

    @State private var pulse = false
    @State private var heartGlow = false

    private var bondedPet: Pet {
        var p = Pet(); p.species = species; p.mood = .cozy;        return p
    }

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(MooniColor.accent.opacity(heartGlow ? 0.35 : 0.18))
                    .frame(width: 240, height: 240)
                    .blur(radius: 32)
                PetIllustration(pet: bondedPet, size: 160)
                Image(systemName: "heart.fill")
                    .font(.system(size: 38))
                    .foregroundColor(.pink.opacity(0.85))
                    .offset(x: 80, y: -80)
                    .scaleEffect(pulse ? 1.15 : 0.92)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { heartGlow = true }
            }

            VStack(spacing: 12) {
                Text("Are you ready to invest")
                    .font(MooniFont.display(26))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("in your & \(petName)'s health?")
                    .font(MooniFont.display(26))
                    .foregroundStyle(LinearGradient(
                        colors: [MooniColor.accentSoft, MooniColor.accent],
                        startPoint: .leading, endPoint: .trailing))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)

            VStack(spacing: 10) {
                bondRow(icon: "moon.zzz.fill", text: "A personalized sleep plan made for you")
                bondRow(icon: "pawprint.fill", text: "\(petName)'s evolution unlocked")
                bondRow(icon: "sparkles", text: "Become the version of you that sleeps well")
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 24)
    }

    private func bondRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(MooniColor.accent)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(text)
                .font(MooniFont.title(14))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Yes ladder stage (foot-in-the-door)

private struct YesLadderStage: View {
    let question: String
    let stepIndex: Int
    let total: Int
    let petName: String

    @State private var pulse = false
    @State private var checkRise = false

    var body: some View {
        VStack(spacing: 24) {
            // Step indicator dots (small)
            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { i in
                    Circle()
                        .fill(i <= stepIndex ? MooniColor.success : Color.white.opacity(0.18))
                        .frame(width: i == stepIndex ? 10 : 6, height: i == stepIndex ? 10 : 6)
                        .animation(.spring(response: 0.4), value: stepIndex)
                }
            }
            .padding(.top, 8)

            // Big check icon that rises in
            ZStack {
                Circle()
                    .fill(MooniColor.success.opacity(0.20))
                    .frame(width: 130, height: 130)
                    .blur(radius: 24)
                    .scaleEffect(pulse ? 1.08 : 0.96)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 70))
                    .foregroundStyle(LinearGradient(
                        colors: [MooniColor.success, MooniColor.accentSoft],
                        startPoint: .top, endPoint: .bottom))
                    .scaleEffect(checkRise ? 1.0 : 0.4)
                    .opacity(checkRise ? 1 : 0)
                    .shadow(color: MooniColor.success.opacity(0.6), radius: 18)
            }
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.65)) { checkRise = true }
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true }
            }

            VStack(spacing: 10) {
                Text("Question \(stepIndex + 1) of \(total)")
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textMuted)
                    .tracking(2)
                    .textCase(.uppercase)

                Text(question)
                    .font(MooniFont.display(28))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if stepIndex == total - 1 {
                    Text("\(petName) is waiting for your answer.")
                        .font(MooniFont.body(14))
                        .foregroundColor(MooniColor.accentSoft)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Signature stage

struct SignatureStroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
}

private struct SignatureStage: View {
    let petName: String
    @Binding var typedCommitment: String
    @Binding var strokes: [SignatureStroke]

    @FocusState private var fieldFocused: Bool
    @State private var current: [CGPoint] = []

    private var matched: Bool {
        PrePaywallView.isCommitmentPhraseMatched(typedCommitment)
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("YOUR SLEEP CONTRACT")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.accentSoft)
                    .tracking(2)
                Text("Sign your commitment")
                    .font(MooniFont.display(26))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Type the words and sign with your finger.\nThis is between you and \(petName).")
                    .font(MooniFont.body(13))
                    .foregroundColor(MooniColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Typed commitment
            VStack(alignment: .leading, spacing: 6) {
                Text("Type: \"I am committed\"")
                    .font(MooniFont.caption(11))
                    .foregroundColor(MooniColor.textMuted)
                ZStack(alignment: .leading) {
                    if typedCommitment.isEmpty {
                        Text("I am committed")
                            .font(MooniFont.title(18))
                            .foregroundColor(MooniColor.textMuted.opacity(0.45))
                            .padding(.leading, 14)
                    }
                    TextField("", text: $typedCommitment)
                        .font(MooniFont.title(18))
                        .foregroundColor(MooniColor.textPrimary)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .focused($fieldFocused)
                        .submitLabel(.done)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(matched ? MooniColor.success.opacity(0.6) : Color.white.opacity(0.12), lineWidth: 1)
                )
                if matched {
                    Label("Verified", systemImage: "checkmark.seal.fill")
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.success)
                }
            }
            .padding(.horizontal, 20)

            // Signature canvas
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Sign here")
                        .font(MooniFont.caption(11))
                        .foregroundColor(MooniColor.textMuted)
                    Spacer()
                    if !strokes.isEmpty {
                        Button(action: { strokes.removeAll(); current.removeAll() }) {
                            Label("Clear", systemImage: "trash")
                                .font(MooniFont.caption(11))
                                .foregroundColor(MooniColor.textSecondary)
                        }
                    }
                }

                SignatureCanvas(strokes: $strokes, current: $current)
                    .frame(height: 130)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(strokes.isEmpty ? Color.white.opacity(0.12) : MooniColor.accent.opacity(0.5), lineWidth: 1)
                    )
                    .overlay(
                        Group {
                            if strokes.isEmpty && current.isEmpty {
                                HStack(spacing: 6) {
                                    Image(systemName: "hand.draw.fill")
                                        .foregroundColor(MooniColor.textMuted)
                                    Text("Draw your signature")
                                        .font(MooniFont.caption(13))
                                        .foregroundColor(MooniColor.textMuted)
                                }
                            }
                        }
                    )
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, 4)
        .onTapGesture {
            // Allow tapping outside the field to dismiss the keyboard.
            fieldFocused = false
        }
    }
}

private struct SignatureCanvas: View {
    @Binding var strokes: [SignatureStroke]
    @Binding var current: [CGPoint]

    var body: some View {
        Canvas { context, size in
            for stroke in strokes {
                drawStroke(stroke.points, context: context)
            }
            if !current.isEmpty {
                drawStroke(current, context: context)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    current.append(value.location)
                }
                .onEnded { _ in
                    if !current.isEmpty {
                        strokes.append(SignatureStroke(points: current))
                        current = []
                    }
                }
        )
    }

    private func drawStroke(_ points: [CGPoint], context: GraphicsContext) {
        guard points.count > 1 else { return }
        var path = Path()
        path.move(to: points[0])
        for p in points.dropFirst() {
            path.addLine(to: p)
        }
        context.stroke(
            path,
            with: .color(MooniColor.accentSoft),
            style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
        )
    }
}

// MARK: - Transform animation stage (pet evolves, metrics climb)

private struct TransformAnimStage: View {
    let petName: String
    let species: PetSpecies

    @State private var phase: Int = 0
    @State private var sleepScore: Double = 38
    @State private var energy: Double = 24
    @State private var clarity: Double = 30

    private let timer = Timer.publish(every: 0.9, on: .main, in: .common).autoconnect()

    private var pet: Pet {
        var p = Pet(); p.species = species
        p.mood = phase >= 2 ? .energized : (phase == 1 ? .cozy : .groggy)
        return p
    }

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text("Watch what changes in 30 days")
                    .font(MooniFont.display(24))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                Text("\(petName) grows with every cozy night.")
                    .font(MooniFont.body(13))
                    .foregroundColor(MooniColor.textSecondary)
            }
            .padding(.top, 4)

            ZStack {
                Circle()
                    .fill(MooniColor.accent.opacity(0.18 + 0.08 * Double(phase)))
                    .frame(width: 220, height: 220)
                    .blur(radius: 30)
                DreamSpiritView(pet: pet, size: 160)
                    .id(phase)
                    .transition(.scale.combined(with: .opacity))
            }

            // Day chips with active state
            HStack(spacing: 10) {
                dayChip("Day 1", active: phase >= 0, color: MooniColor.danger)
                Image(systemName: "arrow.right").foregroundColor(.white.opacity(0.4))
                dayChip("Day 14", active: phase >= 1, color: MooniColor.warning)
                Image(systemName: "arrow.right").foregroundColor(.white.opacity(0.4))
                dayChip("Day 30", active: phase >= 2, color: MooniColor.success)
            }

            // Climbing metrics
            VStack(spacing: 8) {
                metricRow("Sleep score", value: sleepScore, suffix: "", color: MooniColor.accent)
                metricRow("Daily energy", value: energy, suffix: "%", color: MooniColor.warning)
                metricRow("Mental clarity", value: clarity, suffix: "%", color: MooniColor.success)
            }
            .padding(14)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 24)
        }
        .onReceive(timer) { _ in
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                if phase < 2 {
                    phase += 1
                    sleepScore = phase == 1 ? 64 : 88
                    energy     = phase == 1 ? 58 : 92
                    clarity    = phase == 1 ? 60 : 90
                }
            }
        }
    }

    private func dayChip(_ label: String, active: Bool, color: Color) -> some View {
        Text(label)
            .font(MooniFont.caption(11))
            .foregroundColor(active ? color : MooniColor.textMuted)
            .padding(.vertical, 6).padding(.horizontal, 12)
            .background(active ? color.opacity(0.18) : Color.white.opacity(0.06))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(active ? color.opacity(0.5) : Color.white.opacity(0.10), lineWidth: 1))
    }

    private func metricRow(_ label: String, value: Double, suffix: String, color: Color) -> some View {
        HStack {
            Text(label)
                .font(MooniFont.caption(13))
                .foregroundColor(MooniColor.textSecondary)
                .frame(width: 110, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(LinearGradient(colors: [color.opacity(0.85), color],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(value / 100))
                        .animation(.spring(response: 0.7, dampingFraction: 0.75), value: value)
                }
            }
            .frame(height: 8)
            Text("\(Int(value))\(suffix)")
                .font(MooniFont.title(13))
                .foregroundColor(color)
                .frame(width: 44, alignment: .trailing)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.6), value: value)
        }
    }
}

// MARK: - Transformation list (benefits revealing one-by-one)

private struct TransformListStage: View {
    @Binding var revealed: Int

    static let items: [(icon: String, color: Color, text: String)] = [
        ("bolt.fill",                MooniColor.warning, "+92% daily energy"),
        ("brain.head.profile",       MooniColor.accent,  "Sharper focus & memory"),
        ("heart.fill",               .pink,              "Lower heart strain"),
        ("flame.fill",               MooniColor.danger,  "Easier weight control"),
        ("face.smiling.fill",        MooniColor.accent,  "Brighter, less puffy face"),
        ("waveform.path.ecg",        MooniColor.success, "Lower cortisol"),
        ("shield.fill",              MooniColor.accent,  "Stronger immune system"),
        ("dollarsign.circle.fill",   MooniColor.success, "Better money decisions"),
        ("figure.run",               MooniColor.warning, "Faster fitness recovery"),
        ("staroflife.fill",          .pink,              "Lower disease risk")
    ]

    private let timer = Timer.publish(every: 0.55, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("YOU WILL TRANSFORM")
                    .font(MooniFont.caption(12))
                    .foregroundColor(MooniColor.accentSoft)
                    .tracking(2)
                Text("Sleep changes everything")
                    .font(MooniFont.display(24))
                    .foregroundColor(MooniColor.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 4)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(Array(Self.items.enumerated()), id: \.offset) { idx, item in
                        HStack(spacing: 14) {
                            Image(systemName: item.icon)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(item.color)
                                .frame(width: 38, height: 38)
                                .background(item.color.opacity(0.16))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            Text(item.text)
                                .font(MooniFont.title(15))
                                .foregroundColor(MooniColor.textPrimary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "checkmark")
                                .foregroundColor(MooniColor.success)
                                .font(.system(size: 12, weight: .bold))
                                .opacity(idx < revealed ? 1 : 0)
                        }
                        .padding(.vertical, 11)
                        .padding(.horizontal, 14)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .opacity(idx < revealed ? 1 : 0)
                        .offset(y: idx < revealed ? 0 : 16)
                        .scaleEffect(idx < revealed ? 1 : 0.9)
                        .animation(.spring(response: 0.55, dampingFraction: 0.7), value: revealed)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 440)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.05),
                        .init(color: .black, location: 0.95),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
        .onAppear {
            // Reset whenever the view appears.
            revealed = 0
        }
        .onReceive(timer) { _ in
            if revealed < Self.items.count {
                revealed += 1
            }
        }
    }
}

#Preview {
    PrePaywallView(
        petName: "Nova",
        species: .owl,
        profile: OnboardingProfile(),
        onContinue: {}
    )
}
