#if DEBUG
import SwiftUI

/// CI-only contact sheets for reviewing the procedural art: `-screen art`, `artrat`, `artbase`.
struct DebugArtSheet: View {
    enum Kind { case units(Species), bases }
    let kind: Kind

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x8FD3F4), Color(hex: 0xC9E9A6)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            switch kind {
            case .units(let species):
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(0..<GameConfig.eras.count, id: \.self) { era in
                        VStack(spacing: 2) {
                            ForEach(UnitRole.allCases, id: \.self) { role in
                                Image(uiImage: ArtFactory.shared.unit(species, era: era, role: role))
                                    .resizable().scaledToFit()
                                    .frame(width: role == .heavy ? 150 : 100, height: role == .heavy ? 125 : 100)
                                    .scaleEffect(x: species == .rat ? -1 : 1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
            case .bases:
                VStack(spacing: 4) {
                    HStack(alignment: .bottom, spacing: 10) {
                        ForEach(0..<GameConfig.eras.count, id: \.self) { era in
                            Image(uiImage: ArtFactory.shared.base(.hamster, era: era)).resizable().scaledToFit().frame(height: 170)
                        }
                    }
                    HStack(spacing: 18) {
                        ForEach(0..<GameConfig.eras.count, id: \.self) { era in
                            Image(uiImage: ArtFactory.shared.turret(era: era, species: .hamster)).resizable().scaledToFit().frame(height: 60)
                            Image(uiImage: ArtFactory.shared.turret(era: era, species: .rat)).resizable().scaledToFit().frame(height: 60)
                                .scaleEffect(x: -1)
                        }
                    }
                }
            }
        }
    }
}
#endif
