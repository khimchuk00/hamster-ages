import StoreKit
import SwiftUI

/// Formats an offer countdown ("47:12:05" / "12:05").
enum OfferTimer {
    static func text(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }
}

struct ShopView: View {
    let store: Store
    let progress: ProgressStore
    let ads: AdService
    @Environment(\.dismiss) private var dismiss
    @State private var toast: String?
    @State private var loadingAd = false

    var body: some View {
        ZStack {
            SheetBackdrop()
            VStack(spacing: 12) {
                HStack {
                    OutlinedText(text: "Shop", size: 26, color: Theme.gold)
                    Spacer()
                    CurrencyPill(icon: "🌻", value: progress.progress.seeds)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .black)).foregroundStyle(.white)
                            .frame(width: 36, height: 36).background(Circle().fill(Color.white.opacity(0.15)))
                    }
                }
                if progress.firstPurchaseBonusAvailable {
                    Label("First purchase bonus: double seeds on any seed pack!", systemImage: "sparkles")
                        .font(Theme.font(12)).foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(Capsule().fill(Theme.gold))
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            if let left = progress.starterOfferRemaining(now: ctx.date) {
                                ShopCard(title: "Starter Pack", subtitle: "3,000 🌻 + 2 Hero Crates", icon: "gift.fill",
                                         color: Theme.gold, badge: "×5 VALUE", timer: OfferTimer.text(left),
                                         price: store.product(.starterPack)?.displayPrice) { Task { await store.buy(.starterPack) } }
                            }
                        }
                        PiggyCard(amount: progress.piggy, breakable: progress.piggyBreakable,
                                  price: store.product(.piggy)?.displayPrice) { Task { await store.buy(.piggy) } }
                        freeSeedsCard
                        seedCard(.seedsSmall, title: "Seed Bag", icon: "leaf.fill", color: Theme.green, badge: nil)
                        seedCard(.seedsLarge, title: "Seed Barrel", icon: "shippingbox.fill", color: Theme.teal, badge: "+33%")
                        seedCard(.seedsMedium, title: "Seed Cart", icon: "cart.fill", color: Theme.orange, badge: "POPULAR")
                        seedCard(.seedsHuge, title: "Seed Silo", icon: "building.2.fill", color: Theme.purple, badge: "BEST VALUE")
                        if progress.progress.removeAds != true {
                            ShopCard(title: "No Ads", subtitle: "Removes interstitials forever", icon: "nosign", color: Theme.red, badge: nil,
                                     price: store.product(.removeAds)?.displayPrice) { Task { await store.buy(.removeAds) } }
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 2)
                }
                HStack {
                    Button("Restore Purchases") { Task { await store.restore() } }
                        .font(Theme.font(12)).foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    if let err = store.lastError {
                        Text(err).font(Theme.font(11)).foregroundStyle(Theme.red)
                    }
                }
            }
            .padding(16)
            .disabled(store.isPurchasing)
            .overlay { if store.isPurchasing { ProgressView().tint(.white).scaleEffect(1.5) } }

            if let toast {
                Text(toast)
                    .font(Theme.font(20)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Capsule().fill(Theme.gold))
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
    }

    private func seedCard(_ id: Store.ProductID, title: LocalizedStringKey, icon: String, color: Color, badge: LocalizedStringKey?) -> some View {
        let amount = id.seeds * (progress.firstPurchaseBonusAvailable ? 2 : 1)
        return ShopCard(title: title, subtitle: "\(amount.formatted()) 🌻", icon: icon, color: color, badge: badge,
                        price: store.product(id)?.displayPrice) { Task { await store.buy(id) } }
    }

    private var freeSeedsCard: some View {
        let left = progress.freeSeedsLeft()
        return ShopCard(title: "Free Seeds", subtitle: "\(progress.freeSeedsAmount) 🌻 · \(left)/\(RemoteConfig.values.freeSeeds)",
                        icon: "play.rectangle.fill", color: Theme.green, badge: "FREE",
                        price: left > 0 ? (loadingAd ? L10n.t("Loading…") : L10n.t("Watch")) : L10n.t("Tomorrow")) {
            guard left > 0, !loadingAd else { return }
            loadingAd = true
            ads.showRewarded(placement: "shop_free_seeds") { ok in
                loadingAd = false
                guard ok else { return }
                let n = progress.claimFreeSeeds()
                guard n > 0 else { return }
                Analytics.log(.adRewarded(placement: "shop_free_seeds"))
                Haptics.success()
                Sound.shared.play(.coin)
                withAnimation(.spring) { toast = "+\(n) 🌻" }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { toast = nil } }
            }
        }
    }
}

private struct ShopCard: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let icon: String
    let color: Color
    let badge: LocalizedStringKey?
    var timer: String? = nil
    /// Button text: the localized App Store price, or a label for free cards. Nil while products load.
    let price: String?
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 30, weight: .bold)).foregroundStyle(color)
                .frame(width: 58, height: 58).background(Circle().fill(color.opacity(0.18)))
            Text(title).font(Theme.font(16)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Text(subtitle).font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.8)
            if let timer {
                Label(timer, systemImage: "timer").font(Theme.font(11)).foregroundStyle(Theme.gold).monospacedDigit()
            }
            Spacer(minLength: 0)
            Button(action: action) {
                Group {
                    if let price { Text(price) } else { ProgressView().tint(.white) }
                }
                .font(Theme.font(15)).frame(minWidth: 70)
            }
            .buttonStyle(ChunkyButtonStyle(color: price == nil ? Theme.disabled : Theme.green, cornerRadius: 12, depth: 3))
            .disabled(price == nil)
        }
        .padding(12)
        .frame(width: 150, height: 210)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(color.opacity(0.6), lineWidth: 2))
        .overlay(alignment: .top) {
            if let badge {
                Text(badge).font(Theme.font(10)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.gold)).offset(y: -9)
            }
        }
    }
}

/// Piggy Bank: fills from battles, break it (IAP) to grab everything inside.
private struct PiggyCard: View {
    let amount: Int
    let breakable: Bool
    let price: String?
    let action: () -> Void

    var body: some View {
        let full = amount >= ProgressStore.piggyCap
        VStack(spacing: 6) {
            Image(uiImage: ArtFactory.shared.piggyBank()).resizable().scaledToFit().frame(height: 50)
            Text("Piggy Bank").font(Theme.font(16)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
            Text("\(amount.formatted()) 🌻").font(Theme.font(14)).foregroundStyle(Theme.gold).monospacedDigit()
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.4))
                Capsule().fill(LinearGradient(colors: [Color(hex: 0xF8A5C2), Theme.gold], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 126 * min(1, Double(amount) / Double(ProgressStore.piggyCap)))
            }
            .frame(width: 126, height: 8)
            Text(breakable ? (full ? L10n.t("Full! Break it now") : L10n.t("Fills up as you battle"))
                           : L10n.f("Break at %lld 🌻", ProgressStore.piggyMinBreak))
                .font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.75))
                .lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            Button(action: action) {
                Group {
                    if !breakable { Image(systemName: "lock.fill") }
                    else if let price { Text(price) } else { ProgressView().tint(.white) }
                }
                .font(Theme.font(15)).frame(minWidth: 70)
            }
            .buttonStyle(ChunkyButtonStyle(color: breakable && price != nil ? Theme.green : Theme.disabled, cornerRadius: 12, depth: 3))
            .disabled(!breakable || price == nil)
        }
        .padding(12)
        .frame(width: 150, height: 210)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: 0xF8A5C2).opacity(0.8), lineWidth: 2))
        .overlay(alignment: .top) {
            if full {
                Text("FULL").font(Theme.font(10)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.gold)).offset(y: -9)
            }
        }
    }
}
