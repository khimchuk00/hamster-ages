import GameKit
import UIKit

/// Game Center: one leaderboard (highest stage) + achievements. IDs must be created in App Store Connect.
@MainActor
enum GameCenter {
    static let leaderboardID = "com.valkhim.hamsterages.highest_stage"
    static let survivalLeaderboardID = "com.valkhim.hamsterages.survival_seconds"

    static func submitSurvival(seconds: Int) {
        guard isAuthenticated else { return }
        Task {
            try? await GKLeaderboard.submitScore(seconds, context: 0, player: GKLocalPlayer.local,
                                                 leaderboardIDs: [survivalLeaderboardID])
        }
    }

    enum Achievement: String, CaseIterable {
        case firstWin = "com.valkhim.hamsterages.first_win"
        case medieval = "com.valkhim.hamsterages.reach_medieval"
        case futureAge = "com.valkhim.hamsterages.reach_future"
        case kingslayer = "com.valkhim.hamsterages.kingslayer"
        case stage10 = "com.valkhim.hamsterages.stage_10"
        case stage25 = "com.valkhim.hamsterages.stage_25"
        case legendary = "com.valkhim.hamsterages.legendary_general"
        case fullRoster = "com.valkhim.hamsterages.all_generals"
    }

    private(set) static var isAuthenticated = false
    /// Whether a menu (not a battle) is on screen; the access point is only shown there.
    private static var onMenu = true
    private static var reported = Set<String>()

    static func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { viewController, _ in
            Task { @MainActor in
                if let viewController {
                    topViewController()?.present(viewController, animated: true)
                } else {
                    isAuthenticated = GKLocalPlayer.local.isAuthenticated
                    setAccessPoint(visible: onMenu)
                }
            }
        }
    }

    /// Shows the floating Game Center button on menus only (it would cover the battle HUD).
    static func setAccessPoint(visible: Bool) {
        onMenu = visible
        guard isAuthenticated else { return }
        GKAccessPoint.shared.location = .bottomTrailing
        GKAccessPoint.shared.isActive = visible
    }

    /// Called after every battle and progress change.
    static func sync(progress p: PlayerProgress, lastBattle: BattleStats? = nil) {
        guard isAuthenticated else { return }
        let best = max(1, p.highestStage - 1)   // highestStage is the next unbeaten stage
        Task {
            try? await GKLeaderboard.submitScore(best, context: 0, player: GKLocalPlayer.local,
                                                 leaderboardIDs: [leaderboardID])
        }
        var earned: [Achievement] = []
        if p.wins >= 1 { earned.append(.firstWin) }
        if best >= 10 { earned.append(.stage10) }
        if best >= 25 { earned.append(.stage25) }
        if let b = lastBattle {
            if b.evolutions >= 1 { earned.append(.medieval) }
            if b.evolutions >= 4 { earned.append(.futureAge) }
            if b.bossesKilled >= 1 { earned.append(.kingslayer) }
        }
        let owned = GeneralID.allCases.filter { p.generalLevel($0) > 0 }
        if owned.contains(where: { $0.rarity == .legendary }) { earned.append(.legendary) }
        if owned.count == GeneralID.allCases.count { earned.append(.fullRoster) }

        let fresh = earned.filter { !reported.contains($0.rawValue) }
        guard !fresh.isEmpty else { return }
        fresh.forEach { reported.insert($0.rawValue) }
        let achievements = fresh.map { a -> GKAchievement in
            let g = GKAchievement(identifier: a.rawValue)
            g.percentComplete = 100
            g.showsCompletionBanner = true
            return g
        }
        Task { try? await GKAchievement.report(achievements) }
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
