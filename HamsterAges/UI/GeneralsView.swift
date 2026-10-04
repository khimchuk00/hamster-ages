import SwiftUI

struct GeneralsView: View {
    let store: ProgressStore
    let ads: AdService
    @Environment(\.dismiss) private var dismiss
    @State private var reveal: CrateResult?
    @State private var selected: GeneralID?

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 8)]

    var body: some View {
        let p = store.progress
        ZStack {
            Color(hex: 0x241B36).ignoresSafeArea()
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    OutlinedText(text: "Generals", size: 26, color: Theme.gold)
                    Spacer()
                    CurrencyPill(icon: "🌻", value: p.seeds)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .black)).foregroundStyle(.white)
                            .frame(width: 36, height: 36).background(Circle().fill(Color.white.opacity(0.15)))
                    }
                }
                HStack(alignment: .top, spacing: 16) {
                    // Collection grid
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(GeneralID.allCases) { g in
                                GeneralTile(general: g, level: p.generalLevel(g), equipped: p.equipped == g,
                                            selected: selected == g)
                                    .onTapGesture { selected = g }
                            }
                        }
                    }

                    // Detail + crates
                    VStack(spacing: 10) {
                        if let g = selected ?? p.equipped {
                            ScrollView(showsIndicators: false) {
                                GeneralDetail(general: g, level: p.generalLevel(g), equipped: p.equipped == g) {
                                    store.equip(g)
                                    Haptics.success()
                                }
                            }
                        }
                        Spacer(minLength: 0)
                        VStack(spacing: 6) {
                            Text("Hamster Crate").font(Theme.font(15)).foregroundStyle(.white)
                            Text("Rare 70% · Epic 25% · Legendary 5%")
                                .font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                            HStack(spacing: 8) {
                                Button {
                                    if let r = store.openCrate(free: false) { show(r) } else { Haptics.fail() }
                                } label: { Text("🌻 \(Generals.crateCost)").font(Theme.font(14)) }
                                .buttonStyle(ChunkyButtonStyle(color: p.seeds >= Generals.crateCost ? Theme.green : Theme.disabled, cornerRadius: 12, depth: 3, compact: true))

                                if store.freeCrateAvailable() {
                                    Button {
                                        ads.showRewarded(placement: "free_crate") { ok in
                                            if ok, let r = store.openCrate(free: true) {
                                                Analytics.log(.adRewarded(placement: "free_crate"))
                                                show(r)
                                            }
                                        }
                                    } label: { Label("Free", systemImage: "play.rectangle.fill").font(Theme.font(14)) }
                                    .buttonStyle(ChunkyButtonStyle(color: Theme.purple, cornerRadius: 12, depth: 3, compact: true))
                                }
                            }
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.07)))
                    }
                    .frame(width: 260)
                }
            }
            .padding(16)

            if let r = reveal {
                CrateReveal(result: r) { withAnimation { reveal = nil } }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
    }

    private func show(_ r: CrateResult) {
        Haptics.boom()
        Sound.shared.play(r.general.rarity == .legendary ? .win : .evolve)
        selected = r.general
        GameCenter.sync(progress: store.progress)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { reveal = r }
    }
}

private struct GeneralTile: View {
    let general: GeneralID
    let level: Int
    let equipped: Bool
    let selected: Bool

    var body: some View {
        let rc = rarityColor(general.rarity)
        VStack(spacing: 2) {
            Image(uiImage: ArtFactory.shared.general(general))
                .resizable().scaledToFit().frame(height: 48)
                .colorMultiply(level > 0 ? .white : .black)
                .opacity(level > 0 ? 1 : 0.5)
            Text(level > 0 ? general.name : "???").font(Theme.font(11)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            HStack(spacing: 1) {
                ForEach(0..<Generals.maxLevel, id: \.self) { i in
                    Image(systemName: "star.fill").font(.system(size: 7))
                        .foregroundStyle(i < level ? Theme.gold : .white.opacity(0.15))
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(rc.opacity(0.18)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Theme.gold : rc.opacity(0.7), lineWidth: selected ? 3 : 1.5))
        .overlay(alignment: .topTrailing) {
            if equipped {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.green).padding(4)
            }
        }
    }
}

private struct GeneralDetail: View {
    let general: GeneralID
    let level: Int
    let equipped: Bool
    let onEquip: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Image(uiImage: ArtFactory.shared.general(general)).resizable().scaledToFit().frame(height: 64)
                .colorMultiply(level > 0 ? .white : .black)
            Text(general.name).font(Theme.font(17)).foregroundStyle(.white)
            Text(general.rarity.title.localizedUppercase).font(Theme.font(10)).foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Capsule().fill(rarityColor(general.rarity)))
            Text(general.effectText(level: max(1, level)))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Label("\(general.ability.title): \(general.ability.detail)", systemImage: "bolt.circle.fill")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.purple.mix(with: .white, by: 0.4)).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if level > 0 && level < Generals.maxLevel {
                Text("Next: \(general.effectText(level: level + 1))")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.gold.opacity(0.9)).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if level > 0 {
                Button(equipped ? "Equipped" : "Equip", action: onEquip)
                    .buttonStyle(ChunkyButtonStyle(color: equipped ? Theme.disabled : Theme.teal, cornerRadius: 12, depth: 3))
                    .disabled(equipped)
            } else {
                Text("Find in a crate").font(Theme.font(12)).foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

private struct CrateReveal: View {
    let result: CrateResult
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 10) {
                OutlinedText(text: result.isNew ? "NEW GENERAL!" : (result.refund > 0 ? "MAXED!" : "LEVEL UP!"),
                             size: 28, color: Theme.gold)
                Image(uiImage: ArtFactory.shared.general(result.general))
                    .resizable().scaledToFit().frame(height: 130)
                    .shadow(color: rarityColor(result.general.rarity).opacity(0.9), radius: 20)
                Text(result.general.name).font(Theme.font(20)).foregroundStyle(.white)
                Text(result.general.rarity.title.localizedUppercase).font(Theme.font(11)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(Capsule().fill(rarityColor(result.general.rarity)))
                if result.refund > 0 {
                    Text("Already maxed — +\(result.refund) 🌻").font(Theme.font(14)).foregroundStyle(.white)
                } else {
                    Text("Level \(result.newLevel) · \(result.general.effectText(level: result.newLevel))")
                        .font(Theme.font(13)).foregroundStyle(.white.opacity(0.9))
                }
                Button("Nice!", action: onClose).buttonStyle(ChunkyButtonStyle(color: Theme.green))
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 24).fill(Theme.panel))
        }
    }
}

private func rarityColor(_ r: GeneralRarity) -> Color {
    switch r {
    case .rare: return Color(hex: 0x5B9BD5)
    case .epic: return Theme.purple
    case .legendary: return Theme.gold
    }
}
