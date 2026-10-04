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
        AdPolicy.noteRewardedShown()
        // Simulates a short ad, then grants the reward.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { completion(true) }
    }

    func showInterstitial(placement: String) {
        #if DEBUG
        print("[ADS] interstitial at \(placement)")
        #endif
    }
}

/// Session state for interstitial pacing; the rules themselves live in `AdRules` (remote-configurable).
@MainActor
enum AdPolicy {
    private static var lastInterstitial: Date?
    private static var lastRewarded: Date?

    static func noteRewardedShown() { lastRewarded = .now }

    static func shouldShowInterstitial(battlesPlayed: Int, removeAds: Bool, lastBattleWon: Bool, stage: Int) -> Bool {
        let ok = AdRules.shouldShowInterstitial(battlesPlayed: battlesPlayed, removeAds: removeAds, lastBattleWon: lastBattleWon,
                                                stage: stage, now: .now, lastInterstitial: lastInterstitial, lastRewarded: lastRewarded)
        if ok { lastInterstitial = .now }
        return ok
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

/// Game-feel switches (Settings). Screen shake also honours the system Reduce Motion setting.
@MainActor
enum Juice {
    static var shakeSetting: Bool = !UserDefaults.standard.bool(forKey: "hamsterages.shakeOff") {
        didSet { UserDefaults.standard.set(!shakeSetting, forKey: "hamsterages.shakeOff") }
    }

    static var shakeEnabled: Bool { shakeSetting && !UIAccessibility.isReduceMotionEnabled }
}
