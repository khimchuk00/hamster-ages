import StoreKit
import SwiftUI

struct ShopView: View {
    let store: Store
    let progress: ProgressStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: 0x241B36).ignoresSafeArea()
            VStack(spacing: 14) {
                HStack {
                    OutlinedText(text: "Shop", size: 26, color: Theme.gold)
                    Spacer()
                    CurrencyPill(icon: "🌻", value: progress.progress.seeds)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .black)).foregroundStyle(.white)
                            .frame(width: 36, height: 36).background(Circle().fill(Color.white.opacity(0.15)))
                    }
                }
                HStack(spacing: 12) {
                    if progress.progress.starterBought != true {
                        ShopCard(title: "Starter Pack", subtitle: "3,000 🌻 + No Ads", icon: "gift.fill",
                                 color: Theme.gold, badge: "BEST VALUE",
                                 product: store.product(.starterPack)) { Task { await store.buy(.starterPack) } }
                    }
                    ShopCard(title: "Seed Bag", subtitle: "1,200 🌻", icon: "leaf.fill", color: Theme.green, badge: nil,
                             product: store.product(.seedsSmall)) { Task { await store.buy(.seedsSmall) } }
                    ShopCard(title: "Seed Barrel", subtitle: "8,000 🌻", icon: "shippingbox.fill", color: Theme.teal, badge: "+33%",
                             product: store.product(.seedsLarge)) { Task { await store.buy(.seedsLarge) } }
                    if progress.progress.removeAds != true {
                        ShopCard(title: "No Ads", subtitle: "Removes interstitials forever", icon: "nosign", color: Theme.purple, badge: nil,
                                 product: store.product(.removeAds)) { Task { await store.buy(.removeAds) } }
                    }
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
        }
    }
}

private struct ShopCard: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let icon: String
    let color: Color
    let badge: LocalizedStringKey?
    let product: Product?
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 34, weight: .bold)).foregroundStyle(color)
                .frame(width: 64, height: 64).background(Circle().fill(color.opacity(0.18)))
            Text(title).font(Theme.font(16)).foregroundStyle(.white)
            Text(subtitle).font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center)
            Spacer(minLength: 0)
            Button(action: action) {
                Text(product?.displayPrice ?? "…").font(Theme.font(15)).frame(minWidth: 70)
            }
            .buttonStyle(ChunkyButtonStyle(color: product == nil ? Theme.disabled : Theme.green, cornerRadius: 12, depth: 3))
            .disabled(product == nil)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 200)
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
