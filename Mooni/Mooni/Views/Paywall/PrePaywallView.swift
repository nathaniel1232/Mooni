import SwiftUI
import Combine

/// Animated emotional pre-paywall sequence. Drives the prospect through
/// bad sleep → good sleep → benefit slides → yes-ladder → commitment → paywall.
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

    private enum Phase: Int, CaseIterable {
        case badSleep
        case goodSleep
        case transformList   // benefit slides, one per substage
        case yesLadder       // 5 quick yes-questions (foot-in-the-door)
        case signature       // type "I am committed" + draw signature
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

            VStack(spacing: 0) {
                phaseProgressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 28)   // breathing room so the pet halo
                                            // can never crowd the bar above it.

                Spacer(minLength: 0)

                Group {
                    switch phase {
                    case .badSleep:
                        BadSleepStage(subStage: subStage, petName: petName, species: species, profile: profile)
                    case .goodSleep:
                        GoodSleepStage(subStage: subStage, petName: petName, species: species)
                    case .transformList:
                        let item = BenefitSlideStage.items[min(subStage, BenefitSlideStage.items.count - 1)]
                        BenefitSlideStage(item: item, index: subStage, total: BenefitSlideStage.items.count)
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
                    }
                }
                .frame(height: 4)
            }
        }
    }

    private func progressFraction(for p: Phase) -> CGFloat {
        if p.rawValue < phase.rawValue { return 1 }
        if p.rawValue > phase.rawValue { return 0 }
        switch phase {
        case .badSleep:       return CGFloat(subStage + 1) / 3
        case .goodSleep:      return CGFloat(subStage + 1) / 3
        case .transformList:  return CGFloat(subStage + 1) / CGFloat(BenefitSlideStage.items.count)
        case .yesLadder:      return CGFloat(subStage + 1) / CGFloat(Self.yesLadderCount)
        case .signature:
            let typed = typedCommitment.trimmingCharacters(in: .whitespacesAndNewlines)
            let typedDone: CGFloat = Self.isCommitmentPhraseMatched(typed) ? 0.5 : CGFloat(min(typed.count, 14)) / 14 * 0.5
            let signed: CGFloat   = signatureStrokes.isEmpty ? 0 : 0.5
            return min(typedDone + signed, 1)
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
        case (.transformList, _):
            return subStage < BenefitSlideStage.items.count - 1 ? "Next" : "See my plan"
        case (.yesLadder, _): return "Yes"
        case (.signature, _): return "I commit — let's go"
        }
    }

    private var canAdvanceFromCurrent: Bool {
        if phase == .signature {
            return Self.isCommitmentPhraseMatched(typedCommitment) && !signatureStrokes.isEmpty
        }
        return true
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
        case .yesLadder:
            VStack(spacing: 10) {
                PrimaryButton(title: "YES", icon: "checkmark.circle.fill") {
                    advance()
                }
                Text("Tap to continue.")
                    .font(MooniFont.caption(11))
                    .foregroundColor(.white.opacity(0.4))
            }
        case .signature:
            VStack(spacing: 10) {
                PrimaryButton(title: primaryTitle, icon: "sparkles") {
                    if canAdvanceFromCurrent { advance() }
                }
                .disabled(!canAdvanceFromCurrent)
                .opacity(canAdvanceFromCurrent ? 1 : 0.4)
                Text("Your plan unlocks immediately.")
                    .font(MooniFont.caption(12))
                    .foregroundColor(.white.opacity(0.45))
            }
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
                if subStage < 2 { subStage += 1 } else { phase = .transformList; subStage = 0 }
            case .transformList:
                if subStage < BenefitSlideStage.items.count - 1 { subStage += 1 }
                else { phase = .yesLadder; subStage = 0 }
            case .yesLadder:
                if subStage < Self.yesLadderCount - 1 { subStage += 1 }
                else { phase = .signature; subStage = 0 }
            case .signature:
                onContinue()
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
            withAnimation(.easeOut(duration: 0.45)) { heroIn = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.15)) { statIn = true }
            withAnimation(.easeOut(duration: 0.35).delay(0.30)) { bodyIn = true }
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) { dimmer = true }
        }
        .onChange(of: subStage) { _, _ in
            statIn = false; bodyIn = false
            withAnimation(.easeOut(duration: 0.4)) { statIn = true }
            withAnimation(.easeOut(duration: 0.35).delay(0.15)) { bodyIn = true }
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
            Text("are silently lost\nto grogginess + fatigue.")
                .font(MooniFont.display(24))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 6)
        }
    }

    private var badStat3: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("\(petName) feels it too.")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("Tired you = tired \(petName).")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                statChip(icon: "battery.25", text: "−41% daily focus")
                statChip(icon: "exclamationmark.triangle.fill", text: "2.3× sick-day risk")
                statChip(icon: "calendar.badge.exclamationmark", text: "\(max(profile.daysLostPerYear, 18)) wasted days/year")
            }
            .opacity(bodyIn ? 1 : 0)
            .offset(y: bodyIn ? 0 : 8)

            Text("Every night together is a choice. \(petName) is rooting for the next one.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .opacity(bodyIn ? 1 : 0)
        }
    }

    private func statChip(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color.red.opacity(0.95))
                .frame(width: 36, height: 36)
                .background(Color.red.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(text)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
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
                        .fill(Color.yellow.opacity(glow ? 0.26 : 0.18))
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
                withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) { glow = true }
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
            withAnimation(.easeOut(duration: 0.45)) { heroIn = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.15)) { statIn = true }
            withAnimation(.easeOut(duration: 0.35).delay(0.30)) { bodyIn = true }
        }
        .onChange(of: subStage) { _, _ in
            statIn = false; bodyIn = false
            withAnimation(.easeOut(duration: 0.4)) { statIn = true }
            withAnimation(.easeOut(duration: 0.35).delay(0.15)) { bodyIn = true }
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
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("This is your future")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("if you commit tonight.")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                futureRow(day: "Tonight",   text: "Wind-down + your soundscape", icon: "moon.stars.fill")
                futureRow(day: "Day 3",     text: "First night of unbroken sleep", icon: "sparkles")
                futureRow(day: "Day 7",     text: "Wake before the alarm — rested", icon: "sun.max.fill")
                futureRow(day: "Day 30",    text: "Energy, mood & focus rebuilt",  icon: "bolt.fill")
            }
            .padding(.top, 4)
            .opacity(bodyIn ? 1 : 0)
            .offset(y: bodyIn ? 0 : 10)
        }
    }

    private func futureRow(day: String, text: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(MooniColor.accentSoft)
                .frame(width: 32, height: 32)
                .background(MooniColor.accentSoft.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            Text(day)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
                .tracking(1.4)
                .frame(width: 64, alignment: .leading)

            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func goodChip(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(MooniColor.success)
                .frame(width: 36, height: 36)
                .background(MooniColor.success.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(text)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MooniColor.success.opacity(0.32), lineWidth: 1)
        )
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

// MARK: - Benefit slides (one per screen, replaces transform list)

private struct BenefitSlideStage: View {
    let item: (icon: String, color: Color, text: String, context: String)
    let index: Int
    let total: Int

    @State private var appeared = false

    static let items: [(icon: String, color: Color, text: String, context: String)] = [
        ("bolt.fill",              MooniColor.warning, "+92% daily energy",
         "Most users notice the difference within the first week."),
        ("brain.head.profile",     MooniColor.accent,  "Sharper focus & memory",
         "Deep sleep doubles your brain's nightly cleanup efficiency."),
        ("heart.fill",             .pink,              "Lower heart strain",
         "Chronic poor sleep raises resting heart rate by up to 8 bpm."),
        ("flame.fill",             MooniColor.danger,  "Easier weight control",
         "Sleep-deprived people eat ~385 more calories the next day."),
        ("face.smiling.fill",      MooniColor.accent,  "Brighter, less puffy face",
         "Growth hormone — the skin's repair signal — peaks during deep sleep."),
        ("waveform.path.ecg",      MooniColor.success, "Lower cortisol",
         "Quality sleep cuts morning cortisol by up to 37%."),
        ("shield.fill",            MooniColor.accent,  "Stronger immune system",
         "Your immune system nearly doubles its activity while you sleep."),
        ("dollarsign.circle.fill", MooniColor.success, "Better money decisions",
         "Sleep-deprived brains make 20% riskier financial choices."),
        ("figure.run",             MooniColor.warning, "Faster fitness recovery",
         "Muscle repair happens almost entirely during deep sleep."),
        ("staroflife.fill",        .pink,              "Lower disease risk",
         "8 chronic conditions are directly linked to sleep deprivation.")
    ]

    var body: some View {
        VStack(spacing: 28) {
            // Counter
            Text("\(index + 1) / \(total)")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundColor(MooniColor.textMuted)
                .tracking(2)
                .padding(.top, 8)

            // Icon with glow
            ZStack {
                Circle()
                    .fill(item.color.opacity(0.14))
                    .frame(width: 170, height: 170)
                    .blur(radius: 36)
                    .scaleEffect(appeared ? 1.1 : 0.7)
                    .animation(.easeOut(duration: 1.2), value: appeared)

                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(item.color.opacity(0.18))
                        .frame(width: 110, height: 110)
                    Image(systemName: item.icon)
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundColor(item.color)
                }
                .scaleEffect(appeared ? 1 : 0.4)
                .animation(.spring(response: 0.55, dampingFraction: 0.65), value: appeared)
            }

            // Benefit headline
            Text(item.text)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(MooniColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 22)
                .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.12), value: appeared)

            // Context line
            Text(item.context)
                .font(MooniFont.body(16))
                .foregroundColor(MooniColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.easeOut(duration: 0.5).delay(0.28), value: appeared)
        }
        .onAppear {
            appeared = false
            DispatchQueue.main.async {
                appeared = true
                Haptics.soft()
            }
        }
        .onChange(of: index) { _, _ in
            appeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                appeared = true
                Haptics.soft()
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
