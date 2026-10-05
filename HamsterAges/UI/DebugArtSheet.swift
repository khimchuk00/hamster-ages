#if DEBUG
import SwiftUI

/// CI-only contact sheets for reviewing the procedural art: `-screen art`, `artrat`, `artbase`.
struct DebugArtSheet: View {
    enum Kind { case units(Species), bases, backgrounds, ratGenerals, shareCard, variants }
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
            case .backgrounds:
                VStack(spacing: 2) {
                    ForEach(0..<GameConfig.eras.count, id: \.self) { era in
                        Image(uiImage: ArtFactory.shared.background(era: era, size: CGSize(width: 1350, height: 390), groundHeight: 86))
                            .resizable().scaledToFit()
                    }
                }
                .padding(.horizontal, 60)
            case .variants:
                VStack(spacing: 0) {
                    ForEach(0..<GameConfig.eras.count, id: \.self) { era in
                        HStack(alignment: .bottom, spacing: 4) {
                            ForEach(UnitVariant.allCases, id: \.self) { v in
                                Image(uiImage: ArtFactory.shared.unit(.hamster, era: era, role: v.role, variant: v))
                                    .resizable().scaledToFit().frame(width: v.role == .heavy ? 76 : 62, height: 62)
                            }
                        }
                    }
                }
            case .shareCard:
                let sample: BattleResult = {
                    var r = BattleResult(won: true, stage: 12, seeds: 290, stars: 3, kills: 41, duration: 214, stats: BattleStats())
                    r.era = 3; r.ratGeneral = .squeak; r.general = .queenSqueak
                    return r
                }()
                ShareCard(result: sample).scaleEffect(1.2)
            case .ratGenerals:
                VStack(spacing: 14) {
                    HStack(spacing: 6) {
                        ForEach(RatGeneral.allCases, id: \.self) { g in
                            VStack(spacing: 4) {
                                RatGeneralBadge(general: g, size: 78)
                                Text(g.name).font(Theme.font(12)).foregroundStyle(Theme.ink)
                                Text(g.style).font(Theme.font(10)).foregroundStyle(Theme.ink.opacity(0.7))
                            }
                            .frame(width: 92)
                        }
                    }
                    HStack(spacing: 10) {
                        ForEach(RatTrait.allCases, id: \.self) { t in
                            HStack(spacing: 6) {
                                Image(uiImage: ArtFactory.shared.traitBadge(t)).resizable().frame(width: 32, height: 32)
                                VStack(alignment: .leading) {
                                    Text(t.title).font(Theme.font(13)).foregroundStyle(Theme.ink)
                                    Text(t.counter).font(Theme.font(9)).foregroundStyle(Theme.ink.opacity(0.7))
                                }
                                .frame(width: 78, alignment: .leading)
                            }
                        }
                    }
                }
            case .bases:
                VStack(spacing: 4) {
                    HStack(alignment: .bottom, spacing: 10) {
                        ForEach(0..<GameConfig.eras.count, id: \.self) { era in
                            // Damage states shown on alternate bases (none / cracked / wrecked).
                            ZStack {
                                Image(uiImage: ArtFactory.shared.base(.hamster, era: era)).resizable().scaledToFit()
                                if era % 3 > 0 {
                                    Image(uiImage: ArtFactory.shared.baseCracks(.hamster, era: era, level: era % 3)).resizable().scaledToFit()
                                }
                            }
                            .frame(height: 170)
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
