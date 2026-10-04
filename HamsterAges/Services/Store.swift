import Foundation
import Observation
import StoreKit

/// StoreKit 2 in-app purchases. Product IDs must match App Store Connect (and HamsterAges.storekit for local testing).
@MainActor
@Observable
final class Store {
    enum ProductID: String, CaseIterable {
        case removeAds = "com.valkhim.hamsterages.removeads"
        case starterPack = "com.valkhim.hamsterages.starterpack"
        case seedsSmall = "com.valkhim.hamsterages.seeds.small"
        case seedsLarge = "com.valkhim.hamsterages.seeds.large"
        case seedsMedium = "com.valkhim.hamsterages.seeds.medium"
        case seedsHuge = "com.valkhim.hamsterages.seeds.huge"
        /// Gold Hamster Pass for the current season (consumable: bought again each season).
        case pass = "com.valkhim.hamsterages.pass"
        /// Breaks the Piggy Bank (consumable; amount depends on how full it is).
        case piggy = "com.valkhim.hamsterages.piggy"

        /// Seeds granted by the product (0 for none).
        var seeds: Int {
            switch self {
            case .removeAds, .pass, .piggy: return 0
            case .starterPack: return 3000
            case .seedsSmall: return 1200
            case .seedsLarge: return 8000
            case .seedsMedium: return 20000
            case .seedsHuge: return 45000
            }
        }

        var removesAds: Bool { self == .removeAds }
        /// Starter Pack also opens two hero crates.
        var crates: Int { self == .starterPack ? 2 : 0 }
    }

    private(set) var products: [String: Product] = [:]
    private(set) var isPurchasing = false
    var lastError: String?

    @ObservationIgnored private let progress: ProgressStore
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init(progress: ProgressStore) {
        self.progress = progress
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await loadProducts() }
    }

    func product(_ id: ProductID) -> Product? { products[id.rawValue] }

    func loadProducts() async {
        do {
            let list = try await Product.products(for: ProductID.allCases.map(\.rawValue))
            products = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
        } catch {
            lastError = L10n.t("Store unavailable")
        }
    }

    func buy(_ id: ProductID) async {
        guard let product = product(id), !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                await handle(verification)
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restore() async {
        try? await AppStore.sync()
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, let id = ProductID(rawValue: t.productID) {
                if id.removesAds { progress.setRemoveAds() }
                if id == .starterPack { progress.markStarterBought() }
            }
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            if case .unverified(let t, _) = result { await t.finish() }
            return
        }
        if let id = ProductID(rawValue: transaction.productID), transaction.revocationDate == nil {
            // Non-consumables can be redelivered (restore, new device): grant their seeds only once.
            let alreadyOwned = id == .starterPack && progress.progress.starterBought == true
            if id.seeds > 0 && !alreadyOwned {
                if id == .starterPack { progress.addSeeds(id.seeds) } else { _ = progress.grantPurchasedSeeds(id.seeds) }
            }
            if !alreadyOwned { for _ in 0..<id.crates { _ = progress.openCrate(free: false, questBonus: true) } }
            if id.removesAds { progress.setRemoveAds() }
            if id == .starterPack { progress.markStarterBought() }
            if id == .pass { progress.unlockPremiumPass() }
            if id == .piggy { progress.breakPiggy() }
            Analytics.log(.purchase(productID: id.rawValue))
            Haptics.success()
        }
        await transaction.finish()
    }
}
