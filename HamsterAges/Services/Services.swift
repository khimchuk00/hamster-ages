import UIKit

/// Rewarded-ad abstraction. Swap `StubAdService` for an AdMob / AppLovin MAX implementation later.
@MainActor
protocol AdService {
    var isRewardedReady: Bool { get }
    func showRewarded(placement: String, completion: @escaping (Bool) -> Void)
    func showInterstitial(placement: String)
}

@MainActor
final class StubAdService: AdService {
    var isRewardedReady: Bool { true }

    func showRewarded(placement: String, completion: @escaping (Bool) -> Void) {
        // Simulates a short ad, then grants the reward.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { completion(true) }
    }

    func showInterstitial(placement: String) {
        #if DEBUG
        print("[ADS] interstitial at \(placement)")
        #endif
    }
}

/// GDD rule: no interstitials before the 3rd battle, then at most one every 2 battles; never with Remove Ads.
@MainActor
enum AdPolicy {
    static func shouldShowInterstitial(battlesPlayed: Int, removeAds: Bool) -> Bool {
        !removeAds && battlesPlayed >= 3 && battlesPlayed % 2 == 1
    }
}

@MainActor
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notify = UINotificationFeedbackGenerator()

    static var isEnabled: Bool = !UserDefaults.standard.bool(forKey: "hamsterages.hapticsOff") {
        didSet { UserDefaults.standard.set(!isEnabled, forKey: "hamsterages.hapticsOff") }
    }

    static func tap() { if isEnabled { light.impactOccurred() } }
    static func boom() { if isEnabled { heavy.impactOccurred() } }
    static func success() { if isEnabled { notify.notificationOccurred(.success) } }
    static func fail() { if isEnabled { notify.notificationOccurred(.error) } }
}
