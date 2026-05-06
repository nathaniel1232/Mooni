import SwiftUI

/// Public entry point used everywhere in the app. Internally delegates to
/// `PetIllustration` so we have a single source of truth for the pet art.
struct DreamSpiritView: View {
    let pet: Pet
    var size: CGFloat = 200

    var body: some View {
        PetIllustration(pet: pet, size: size)
    }
}

#Preview {
    ZStack {
        MooniGradient.night.ignoresSafeArea()
        VStack(spacing: 20) {
            HStack(spacing: 14) {
                DreamSpiritView(pet: { var p = Pet(); p.species = .fox;   p.mood = .rested; return p }(), size: 130)
                DreamSpiritView(pet: { var p = Pet(); p.species = .panda; p.mood = .good;   return p }(), size: 130)
            }
            HStack(spacing: 14) {
                DreamSpiritView(pet: { var p = Pet(); p.species = .owl;   p.mood = .tired;  return p }(), size: 130)
                DreamSpiritView(pet: { var p = Pet(); p.species = .fox;   p.mood = .low;    return p }(), size: 130)
            }
        }
    }
}
