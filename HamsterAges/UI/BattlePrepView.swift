import SwiftUI

/// Pre-battle screen: scout the rival general's troops and pick your squad to answer them.
struct BattlePrepView: View {
    let store: ProgressStore
    let stage: Int
    let onFight: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let foe = RatGeneral.forStage(stage)
        let d = StageDifficulty(stage: stage)
        let era = ChapterStart.era(stage: stage)
        ZStack {
            SheetBackdrop()
            VStack(spacing: 10) {
                HStack {
                    OutlinedText(text: L10n.f("Stage %lld", stage), size: 26, color: Theme.gold)
                    if d.isBoss {
                        Text("BOSS").font(Theme.font(11)).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 2).background(Capsule().fill(Theme.red))
                    }
                    Text(GameConfig.eraNames[era].localizedUppercase).font(Theme.font(12)).foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .black)).foregroundStyle(.white)
                            .frame(width: 36, height: 36).background(Circle().fill(Color.white.opacity(0.15)))
                    }
                }
                HStack(alignment: .top, spacing: 14) {
                    // Your squad
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR SQUAD").font(Theme.font(12)).foregroundStyle(Theme.teal)
                        HStack(spacing: 8) {
                            ForEach(UnitRole.allCases, id: \.self) { role in
                                SquadSlot(role: role, era: era, store: store)
                            }
                        }
                        Text("Tap a unit to swap it for another one from your Workshop.")
                            .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Theme.panel))

                    // The rival
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            RatGeneralBadge(general: foe, size: 48)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(foe.name).font(Theme.font(15)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                                Text(foe.style).font(Theme.font(11)).foregroundStyle(Theme.gold).lineLimit(1).minimumScaleFactor(0.7)
                            }
                        }
                        Text("THEIR TROOPS").font(Theme.font(11)).foregroundStyle(Theme.red)
                        HStack(spacing: 4) {
                            ForEach(UnitRole.allCases, id: \.self) { role in
                                let v = foe.loadout.variant(role)
                                VStack(spacing: 0) {
                                    Image(uiImage: ArtFactory.shared.unit(.rat, era: era, role: role, variant: v))
                                        .resizable().scaledToFit().frame(width: 52, height: 44).scaleEffect(x: -1, y: 1)
                                    Text(v.title).font(Theme.font(9)).foregroundStyle(.white.opacity(0.85)).lineLimit(1).minimumScaleFactor(0.6)
                                }
                                .frame(width: 62)
                            }
                        }
                        let elites = RatTrait.pool(stage: stage)
                        if d.modifier != .none || !elites.isEmpty {
                            HStack(spacing: 6) {
                                if d.modifier != .none {
                                    Label(d.modifier.title, systemImage: d.modifier.icon).font(Theme.font(11)).foregroundStyle(Theme.gold)
                                }
                                ForEach(elites, id: \.self) { t in
                                    Image(uiImage: ArtFactory.shared.traitBadge(t)).resizable().frame(width: 16, height: 16)
                                }
                            }
                        }
                    }
                    .padding(12)
                    .frame(width: 250, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Theme.panel))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: foe.color).opacity(0.7), lineWidth: 2))
                }
                Spacer(minLength: 0)
                HStack {
                    Text(L10n.t("Melee beats heavy · heavy beats ranged · ranged beats melee"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Button {
                        dismiss()
                        onFight()
                    } label: {
                        Label("FIGHT!", systemImage: "flag.2.crossed.fill").font(Theme.font(22)).frame(width: 190)
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.green, cornerRadius: 18, depth: 6))
                }
            }
            .padding(16)
        }
    }
}

/// One role in the squad; tapping cycles through the unlocked variants of that role.
private struct SquadSlot: View {
    let role: UnitRole
    let era: Int
    let store: ProgressStore

    var body: some View {
        let p = store.progress
        let current = p.loadout.variant(role)
        let owned = UnitVariant.of(role).filter { p.variantLevel($0) > 0 }
        Button {
            guard owned.count > 1, let i = owned.firstIndex(of: current) else { Haptics.fail(); return }
            store.equipVariant(owned[(i + 1) % owned.count])
            Haptics.tap()
            Sound.shared.play(.tap)
        } label: {
            VStack(spacing: 2) {
                Image(uiImage: ArtFactory.shared.unit(.hamster, era: era, role: role, skin: p.skin, variant: current))
                    .resizable().scaledToFit().frame(width: 74, height: 62)
                Text(current.title).font(Theme.font(12)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                Text("Lv \(p.variantLevel(current))").font(Theme.font(10)).foregroundStyle(Theme.gold)
                HStack(spacing: 3) {
                    ForEach(UnitVariant.of(role), id: \.self) { v in
                        Circle().fill(v == current ? Theme.gold : (p.variantLevel(v) > 0 ? Color.white.opacity(0.5) : Color.white.opacity(0.15)))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .padding(8)
            .frame(width: 96)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(owned.count > 1 ? Theme.gold.opacity(0.6) : .white.opacity(0.12), lineWidth: 1.5))
        }
        .buttonStyle(PressScale())
    }
}
