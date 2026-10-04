#if DEBUG
import SwiftUI

/// CI-only contact sheet of every unit sprite (`-screen art`), for reviewing the procedural art.
struct DebugArtSheet: View {
    let species: Species

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x8FD3F4), Color(hex: 0xC9E9A6)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
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
        }
    }
}
#endif
