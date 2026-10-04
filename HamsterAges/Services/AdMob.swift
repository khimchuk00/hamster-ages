import AppTrackingTransparency
import GoogleMobileAds
import UIKit
import UserMessagingPlatform

/// Ad unit IDs. These are Google's public TEST units — they never pay out.
/// Before release: create the app in AdMob, then paste your rewarded / interstitial unit IDs here and your
/// app ID into `HamsterAges-Info.plist` (GADApplicationIdentifier).
enum AdConfig {
    static let rewardedUnit = "ca-app-pub-3940256099942544/1712485313"
    static let interstitialUnit = "ca-app-pub-3940256099942544/4411468910"
    static var usesTestUnits: Bool { rewardedUnit.hasPrefix("ca-app-pub-3940256099942544") }
}

/// Google AdMob implementation of `AdService`.
/// Flow: UMP consent (GDPR/US-state regions only) → App Tracking Transparency prompt → SDK start → preload.
@MainActor
final class AdMobService: NSObject, AdService, FullScreenContentDelegate {
    private var rewarded: RewardedAd?
    private var interstitial: InterstitialAd?
    private var loadingRewarded = false
    private var loadingInterstitial = false
    private var started = false
    private var consentRequested = false
    private var rewardCompletion: ((Bool) -> Void)?
    private var earnedReward = false

    var isRewardedReady: Bool { rewarded != nil }

    /// Call once the player has finished the tutorial (we don't greet new players with consent/ATT dialogs).
    func start() {
        guard !consentRequested else { return }
        consentRequested = true
        // Consent from an earlier session lets us start right away.
        startSDKIfAllowed()
        ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters()) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if let vc = UIApplication.topViewController() {
                    try? await ConsentForm.loadAndPresentIfRequired(from: vc)
                }
                if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                    _ = await ATTrackingManager.requestTrackingAuthorization()
                }
                self.startSDKIfAllowed()
            }
        }
    }

    /// GDPR "privacy options" entry point (Settings shows it only where the regulation requires it).
    static var privacyOptionsRequired: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    static func presentPrivacyOptions() {
        guard let vc = UIApplication.topViewController() else { return }
        Task { @MainActor in try? await ConsentForm.presentPrivacyOptionsForm(from: vc) }
    }

    private func startSDKIfAllowed() {
        guard !started, ConsentInformation.shared.canRequestAds else { return }
        started = true
        MobileAds.shared.start()
        loadRewarded()
        loadInterstitial()
    }

    private func loadRewarded() {
        guard started, rewarded == nil, !loadingRewarded else { return }
        loadingRewarded = true
        Task { @MainActor in
            defer { loadingRewarded = false }
            do {
                let ad = try await RewardedAd.load(with: AdConfig.rewardedUnit, request: Request())
                ad.fullScreenContentDelegate = self
                rewarded = ad
            } catch {
                retry { $0.loadRewarded() }
            }
        }
    }

    private func loadInterstitial() {
        guard started, interstitial == nil, !loadingInterstitial else { return }
        loadingInterstitial = true
        Task { @MainActor in
            defer { loadingInterstitial = false }
            do {
                let ad = try await InterstitialAd.load(with: AdConfig.interstitialUnit, request: Request())
                ad.fullScreenContentDelegate = self
                interstitial = ad
            } catch {
                retry { $0.loadInterstitial() }
            }
        }
    }

    private func retry(_ work: @escaping (AdMobService) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated { work(self) }
        }
    }

    // MARK: AdService

    func showRewarded(placement: String, completion: @escaping (Bool) -> Void) {
        guard let ad = rewarded, let vc = UIApplication.topViewController() else {
            completion(false)
            loadRewarded()
            return
        }
        rewardCompletion = completion
        earnedReward = false
        Analytics.log(.adShown(placement: placement, rewarded: true))
        ad.present(from: vc) { [weak self] in
            MainActor.assumeIsolated { self?.earnedReward = true }
        }
    }

    func showInterstitial(placement: String) {
        guard let ad = interstitial, let vc = UIApplication.topViewController() else {
            loadInterstitial()
            return
        }
        Analytics.log(.adShown(placement: placement, rewarded: false))
        ad.present(from: vc)
    }

    // MARK: FullScreenContentDelegate (the SDK calls these on the main thread)

    nonisolated func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        MainActor.assumeIsolated { Music.shared.pause() }
    }

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        let id = ObjectIdentifier(ad)
        MainActor.assumeIsolated { self.finished(id) }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        let id = ObjectIdentifier(ad)
        MainActor.assumeIsolated { self.finished(id) }
    }

    private func finished(_ id: ObjectIdentifier) {
        Music.shared.resume()
        if let r = rewarded, ObjectIdentifier(r) == id {
            rewarded = nil
            let done = rewardCompletion
            rewardCompletion = nil
            done?(earnedReward)
            loadRewarded()
        } else if let i = interstitial, ObjectIdentifier(i) == id {
            interstitial = nil
            loadInterstitial()
        }
    }
}

extension UIApplication {
    /// The view controller ads and consent forms present from.
    @MainActor static func topViewController() -> UIViewController? {
        let scenes = shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var vc = scene?.keyWindow?.rootViewController
        while let presented = vc?.presentedViewController { vc = presented }
        return vc
    }
}
