import SwiftUI

/// Hamster Pass: a 28-day, 20-tier season track with a free row and a Gold (paid) row, plus the fur-skin wardrobe.
struct PassView: View {
    let store: ProgressStore
    let shop: Store
    @Environment(\.dismiss) private var dismiss
    @State private var toast: String?

    var body: some View {
        let p = store.progress
        let tier = store.passTier
        let premium = store.hasPremiumPass()
        ZStack {
            SheetBackdrop()
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 0) {
                        OutlinedText(text: "Hamster Pass", size: 26, color: Theme.gold)
                        Text("Season \(HamsterPass.season()) · \(daysLeft) days left")
                            .font(Theme.font(11)).foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    xpBar(tier: tier)
                    CurrencyPill(icon: "🌻", value: p.seeds)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .black)).foregroundStyle(.white)
                            .frame(width: 36, height: 36).background(Circle().fill(Color.white.opacity(0.15)))
                    }
                }

                HStack(spacing: 8) {
                    VStack(spacing: 8) {
                        Text("FREE").font(Theme.font(11)).foregroundStyle(.white.opacity(0.8)).frame(height: 74)
                        Text("GOLD").font(Theme.font(11)).foregroundStyle(Theme.gold).frame(height: 74)
                    }
                    .padding(.top, 36)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .frame(width: 44)
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(1...HamsterPass.tiers, id: \.self) { t in
                                    TierColumn(tier: t, reached: t <= tier, premiumOwned: premium, store: store) { premiumRow in
                                        claim(tier: t, premium: premiumRow)
                                    }
                                    .id(t)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                        .onAppear { proxy.scrollTo(max(1, min(HamsterPass.tiers, tier)), anchor: .center) }
                    }
                }

                HStack(spacing: 12) {
                    SkinPicker(store: store)
                    Spacer(minLength: 0)
                    if premium {
                        Label("Gold Pass active", systemImage: "crown.fill")
                            .font(Theme.font(13)).foregroundStyle(Theme.gold)
                    } else {
                        Button { Task { await shop.buy(.pass) } } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "crown.fill")
                                Text("Unlock Gold Pass")
                                if let price = shop.product(.pass)?.displayPrice { Text("· \(price)") }
                            }
                            .font(Theme.font(15))
                        }
                        .buttonStyle(ChunkyButtonStyle(color: shop.product(.pass) == nil ? Theme.disabled : Theme.orange, cornerRadius: 14, depth: 4))
                        .disabled(shop.product(.pass) == nil || shop.isPurchasing)
                    }
                }
                Text("Earn pass XP by winning battles, clearing quests and challenges.")
                    .font(Theme.font(10)).foregroundStyle(.white.opacity(0.55))
            }
            .padding(16)

            if let toast {
                Text(toast)
                    .font(Theme.font(18)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Capsule().fill(Theme.gold))
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .onAppear { store.ensurePassSeason() }
    }

    private var daysLeft: Int {
        max(1, Int((HamsterPass.seasonEnd().timeIntervalSinceNow / 86_400).rounded(.up)))
    }

    private func xpBar(tier: Int) -> some View {
        let xp = store.passXP
        let maxed = tier >= HamsterPass.tiers
        let into = maxed ? HamsterPass.xpPerTier : xp - tier * HamsterPass.xpPerTier
        return VStack(alignment: .trailing, spacing: 2) {
            Text("Tier \(tier)/\(HamsterPass.tiers)").font(Theme.font(12)).foregroundStyle(.white)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.4))
                Capsule().fill(Theme.gold.gradient)
                    .frame(width: 140 * CGFloat(into) / CGFloat(HamsterPass.xpPerTier))
            }
            .frame(width: 140, height: 10)
            .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
        }
    }

    private func claim(tier: Int, premium: Bool) {
        guard let result = store.claimPass(tier: tier, premium: premium) else { Haptics.fail(); return }
        Haptics.success()
        Sound.shared.play(.coin)
        let text: String
        switch result.reward {
        case .seeds(let n): text = "+\(n) 🌻"
        case .skin(let s): text = L10n.f("New skin: %@", s.title)
        case .crate:
            if let c = result.crate {
                text = c.isNew ? L10n.f("%@ joined!", c.general.name) : L10n.f("%@ Lv %lld", c.general.name, c.newLevel)
            } else { text = "🎁" }
        }
        withAnimation(.spring) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { withAnimation { toast = nil } }
    }
}

private struct TierColumn: View {
    let tier: Int
    let reached: Bool
    let premiumOwned: Bool
    let store: ProgressStore
    let onClaim: (Bool) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("\(tier)")
                .font(Theme.font(13)).foregroundStyle(reached ? Theme.ink : .white.opacity(0.7))
                .frame(width: 28, height: 28)
                .background(Circle().fill(reached ? Theme.gold : Color.white.opacity(0.12)))
            RewardCell(reward: HamsterPass.freeReward(tier: tier),
                       claimed: (store.progress.passClaimedFree ?? []).contains(tier),
                       claimable: store.canClaimPass(tier: tier, premium: false),
                       locked: false, gold: false) { onClaim(false) }
            RewardCell(reward: HamsterPass.premiumReward(tier: tier, season: HamsterPass.season()),
                       claimed: (store.progress.passClaimedPremium ?? []).contains(tier),
                       claimable: store.canClaimPass(tier: tier, premium: true),
                       locked: !premiumOwned, gold: true) { onClaim(true) }
        }
        .frame(width: 78)
        .opacity(reached ? 1 : 0.75)
    }
}

private struct RewardCell: View {
    let reward: HamsterPass.Reward
    let claimed: Bool
    let claimable: Bool
    let locked: Bool
    let gold: Bool
    let onClaim: () -> Void

    var body: some View {
        Button(action: onClaim) {
            VStack(spacing: 2) {
                icon.frame(height: 36)
                Text(caption).font(Theme.font(10)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(width: 74, height: 74)
            .background(RoundedRectangle(cornerRadius: 14).fill(gold ? Theme.gold.opacity(0.16) : Color.white.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(claimable ? Theme.green : (gold ? Theme.gold.opacity(0.6) : .white.opacity(0.15)),
                                                               lineWidth: claimable ? 3 : 1.5))
            .overlay(alignment: .topTrailing) {
                if claimed {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green).padding(3)
                } else if locked {
                    Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(.white.opacity(0.8)).padding(5)
                }
            }
            .opacity(claimed ? 0.55 : 1)
        }
        .buttonStyle(PressScale())
        .disabled(!claimable)
    }

    @ViewBuilder private var icon: some View {
        switch reward {
        case .seeds: Text("🌻").font(.system(size: 26))
        case .crate: Image(systemName: "shippingbox.fill").font(.system(size: 26)).foregroundStyle(Theme.purple.mix(with: .white, by: 0.3))
        case .skin(let s):
            Image(uiImage: ArtFactory.shared.unit(.hamster, era: 0, role: .melee, skin: s)).resizable().scaledToFit()
        }
    }

    private var caption: String {
        switch reward {
        case .seeds(let n): return "\(n)"
        case .crate: return L10n.t("Crate")
        case .skin(let s): return s.title
        }
    }
}

/// Owned skins; tap to wear.
struct SkinPicker: View {
    let store: ProgressStore

    var body: some View {
        HStack(spacing: 6) {
            Text("Skins").font(Theme.font(12)).foregroundStyle(.white.opacity(0.8))
            ForEach(FurSkin.allCases, id: \.self) { s in
                let owned = store.progress.owns(s)
                let worn = store.progress.skin == s
                Button {
                    store.equipSkin(s)
                    Haptics.tap()
                } label: {
                    Image(uiImage: ArtFactory.shared.unit(.hamster, era: 0, role: .melee, skin: s))
                        .resizable().scaledToFit().frame(width: 40, height: 34)
                        .saturation(owned ? 1 : 0).opacity(owned ? 1 : 0.35)
                        .padding(3)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(worn ? 0.18 : 0.05)))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(worn ? Theme.gold : .clear, lineWidth: 2))
                }
                .buttonStyle(PressScale())
                .disabled(!owned)
                .accessibilityLabel(s.title)
            }
        }
    }
}
