import SwiftUI

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

    private enum Phase: Int, CaseIterable {
        case badSleep, goodSleep, commitment
    }

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
                    case .badSleep:   BadSleepStage(subStage: subStage, petName: petName, species: species, profile: profile)
                    case .goodSleep:  GoodSleepStage(subStage: subStage, petName: petName, species: species)
                    case .commitment: CommitmentStage(petName: petName, species: species, profile: profile)
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
                Capsule()
                    .fill(p.rawValue <= phase.rawValue ? Color.white : Color.white.opacity(0.25))
                    .frame(height: 4)
            }
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
        case (.commitment, _): return "Yes, I'm ready"
        }
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
                if subStage < 2 { subStage += 1 } else { phase = .commitment; subStage = 0 }
            case .commitment: break
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

    private var sadPet: Pet {
        var p = Pet(); p.species = species; p.mood = .low; p.equippedHat = nil
        return p
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Without change…")
                .font(MooniFont.caption(13))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(1.4)

            ZStack {
                // Dim halo
                Circle()
                    .fill(Color.red.opacity(dimmer ? 0.25 : 0.05))
                    .frame(width: 240, height: 240)
                    .blur(radius: 30)
                PetIllustration(pet: sadPet, size: 170)
                    .grayscale(dimmer ? 0.6 : 0.0)
                    .opacity(dimmer ? 0.85 : 1.0)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { dimmer = true }
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { heartbeat = true }
            }

            switch subStage {
            case 0:
                badStat1
            case 1:
                badStat2
            default:
                badStat3
            }

            Spacer().frame(height: 12)
        }
        .padding(.horizontal, 28)
    }

    private var badStat1: some View {
        VStack(spacing: 14) {
            Text("Sleep less than you need…")
                .font(MooniFont.display(26))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("…and your body ages \(profile.sleepAgeYearsAdded) years faster.")
                .font(MooniFont.body(16))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
            statChip(icon: "brain.head.profile", text: "−27% memory")
            statChip(icon: "heart.fill", text: "+48% heart strain")
            statChip(icon: "face.smiling", text: "−65% mood resilience")
        }
    }

    private var badStat2: some View {
        VStack(spacing: 14) {
            Text("Each tired night")
                .font(MooniFont.display(26))
                .foregroundColor(.white)
            Text("steals from your future.")
                .font(MooniFont.display(26))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            VStack(spacing: 6) {
                Text("\(max(profile.daysLostPerYear, 18))")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(Color.red.opacity(0.9))
                    .scaleEffect(heartbeat ? 1.05 : 0.96)
                Text("days a year lost to grogginess")
                    .font(MooniFont.body(15))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 6)
        }
    }

    private var badStat3: some View {
        VStack(spacing: 12) {
            Text("And \(petName) feels it too.")
                .font(MooniFont.display(24))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("Tired you = tired pet. Together you stay stuck — until you decide to change.")
                .font(MooniFont.body(15))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
    }

    private func statChip(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(Color.red.opacity(0.85))
            Text(text)
                .font(MooniFont.title(14))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.07))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.red.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Phase 2: Good sleep

private struct GoodSleepStage: View {
    let subStage: Int
    let petName: String
    let species: PetSpecies

    @State private var glow = false

    private var brightPet: Pet {
        var p = Pet(); p.species = species; p.mood = .energized; p.equippedHat = "hat_nightcap"
        return p
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("With Mooni…")
                .font(MooniFont.caption(13))
                .foregroundColor(.white.opacity(0.85))
                .textCase(.uppercase)
                .tracking(1.4)

            ZStack {
                // Sun-like halo
                Circle()
                    .fill(Color.yellow.opacity(glow ? 0.35 : 0.18))
                    .frame(width: 280, height: 280)
                    .blur(radius: 36)
                ForEach(0..<8, id: \.self) { i in
                    Capsule()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 4, height: 36)
                        .offset(y: -120)
                        .rotationEffect(.degrees(Double(i) * 45))
                        .opacity(glow ? 1 : 0.4)
                }
                PetIllustration(pet: brightPet, size: 180)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { glow = true }
            }

            switch subStage {
            case 0: goodStat1
            case 1: goodStat2
            default: goodStat3
            }

            Spacer().frame(height: 12)
        }
        .padding(.horizontal, 28)
    }

    private var goodStat1: some View {
        VStack(spacing: 14) {
            Text("Imagine waking up rested.")
                .font(MooniFont.display(26))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("Mooni Pro members report it in their first week.")
                .font(MooniFont.body(15))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            VStack(spacing: 8) {
                goodChip(icon: "bolt.fill", text: "+92% morning energy")
                goodChip(icon: "brain.head.profile", text: "+40% mental clarity")
                goodChip(icon: "face.smiling", text: "+65% mood lift")
            }
        }
    }

    private var goodStat2: some View {
        VStack(spacing: 14) {
            Text("\(petName) glows with you.")
                .font(MooniFont.display(26))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("Better sleep evolves your pet. Real changes, real reflections of you.")
                .font(MooniFont.body(15))
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
        var p = Pet(); p.species = species; p.mood = .cozy; p.equippedHat = "hat_nightcap"
        return p
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

#Preview {
    PrePaywallView(
        petName: "Nova",
        species: .fox,
        profile: OnboardingProfile(),
        onContinue: {}
    )
}
