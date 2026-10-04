import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Tunables that can change without an App Store release. Fetched from a static JSON file in the public
/// repo (config/remote.json), cached, and always backed by the built-in defaults below.
struct RemoteValues: Codable, Equatable {
    var interstitialFirstBattle: Int?
    var interstitialEvery: Int?
    var interstitialMinSeconds: Double?
    var interstitialAfterRewardedSeconds: Double?
    var noInterstitialAfterLossBelowStage: Int?
    var freeSeedsPerDay: Int?
    var starterOfferHours: Double?

    var firstBattle: Int { interstitialFirstBattle ?? 3 }
    var every: Int { max(1, interstitialEvery ?? 2) }
    var minSeconds: Double { interstitialMinSeconds ?? 180 }
    var afterRewardedSeconds: Double { interstitialAfterRewardedSeconds ?? 120 }
    var lossGraceStage: Int { noInterstitialAfterLossBelowStage ?? 8 }
    var freeSeeds: Int { max(0, freeSeedsPerDay ?? 3) }
    var starterHours: Double { starterOfferHours ?? 72 }
}

enum RemoteConfig {
    static let url = URL(string: "https://raw.githubusercontent.com/khimchuk00/hamster-ages/main/config/remote.json")!
    private static let cacheKey = "hamsterages.remoteConfig"

    nonisolated(unsafe) static var values: RemoteValues = {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let v = try? JSONDecoder().decode(RemoteValues.self, from: data) { return v }
        return RemoteValues()
    }()

    /// Fetches the latest values in the background; failures keep the cached/default values.
    static func refresh() {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request) { data, response, _ in
            guard let data, (response as? HTTPURLResponse)?.statusCode == 200,
                  let v = try? JSONDecoder().decode(RemoteValues.self, from: data) else { return }
            DispatchQueue.main.async {
                values = v
                UserDefaults.standard.set(data, forKey: cacheKey)
            }
        }.resume()
    }
}

/// Interstitial rules (pure, testable). Rewarded ads are never limited here.
enum AdRules {
    static func shouldShowInterstitial(battlesPlayed: Int, removeAds: Bool, lastBattleWon: Bool, stage: Int,
                                       now: Date, lastInterstitial: Date?, lastRewarded: Date?,
                                       config: RemoteValues = RemoteConfig.values) -> Bool {
        guard !removeAds, battlesPlayed >= config.firstBattle else { return false }
        guard (battlesPlayed - config.firstBattle) % config.every == 0 else { return false }
        // Don't kick a player who just lost early in the campaign.
        if !lastBattleWon && stage < config.lossGraceStage { return false }
        if let t = lastInterstitial, now.timeIntervalSince(t) < config.minSeconds { return false }
        if let t = lastRewarded, now.timeIntervalSince(t) < config.afterRewardedSeconds { return false }
        return true
    }
}
