import Foundation

/// Events needed to compute the soft-launch KPIs from GDD.md (D1/D7, battles per D0, tutorial → first win,
/// card/upgrade economy, rewarded-ad usage). Plug a real backend in by adding an `AnalyticsSink`
/// (TelemetryDeck / Firebase / Amplitude) to `Analytics.sinks` at launch.
enum AnalyticsEvent {
    case appOpen(daysSinceInstall: Int, session: Int)
    case tutorialStep(String)
    case tutorialComplete(won: Bool)
    case battleStart(stage: Int, attempt: Int)
    case battleEnd(stage: Int, won: Bool, seconds: Int, era: Int, kills: Int, stars: Int)
    case cardPicked(id: String, rarity: String, era: Int)
    case cardReroll(viaAd: Bool)
    case evolve(era: Int, seconds: Int)
    case upgradeBought(id: String, level: Int, cost: Int)
    case adRewarded(placement: String)
    case adShown(placement: String, rewarded: Bool)
    case dailyClaimed(day: Int)
    case purchase(productID: String)
    case crateOpened(general: String, rarity: String, free: Bool)
    case questClaimed(kind: String)
    case farmCollected(amount: Int, doubled: Bool)
    case stance(Int)

    var name: String {
        switch self {
        case .appOpen: return "app_open"
        case .tutorialStep: return "tutorial_step"
        case .tutorialComplete: return "tutorial_complete"
        case .battleStart: return "battle_start"
        case .battleEnd: return "battle_end"
        case .cardPicked: return "card_picked"
        case .cardReroll: return "card_reroll"
        case .evolve: return "evolve"
        case .upgradeBought: return "upgrade_bought"
        case .adRewarded: return "ad_rewarded"
        case .adShown: return "ad_shown"
        case .dailyClaimed: return "daily_claimed"
        case .purchase: return "purchase"
        case .crateOpened: return "crate_opened"
        case .questClaimed: return "quest_claimed"
        case .farmCollected: return "farm_collected"
        case .stance: return "stance"
        }
    }

    var params: [String: String] {
        switch self {
        case let .appOpen(d, s): return ["days_since_install": "\(d)", "session": "\(s)"]
        case let .tutorialStep(step): return ["step": step]
        case let .tutorialComplete(won): return ["won": "\(won)"]
        case let .battleStart(stage, attempt): return ["stage": "\(stage)", "attempt": "\(attempt)"]
        case let .battleEnd(stage, won, sec, era, kills, stars):
            return ["stage": "\(stage)", "won": "\(won)", "seconds": "\(sec)", "era": "\(era)", "kills": "\(kills)", "stars": "\(stars)"]
        case let .cardPicked(id, rarity, era): return ["card": id, "rarity": rarity, "era": "\(era)"]
        case let .cardReroll(ad): return ["via_ad": "\(ad)"]
        case let .evolve(era, sec): return ["era": "\(era)", "seconds": "\(sec)"]
        case let .upgradeBought(id, level, cost): return ["upgrade": id, "level": "\(level)", "cost": "\(cost)"]
        case let .adRewarded(p): return ["placement": p]
        case let .adShown(p, r): return ["placement": p, "rewarded": "\(r)"]
        case let .dailyClaimed(day): return ["day": "\(day)"]
        case let .purchase(id): return ["product": id]
        case let .crateOpened(g, r, free): return ["general": g, "rarity": r, "free": "\(free)"]
        case let .questClaimed(kind): return ["quest": kind]
        case let .farmCollected(amount, doubled): return ["amount": "\(amount)", "doubled": "\(doubled)"]
        case let .stance(s): return ["stance": ["fall_back", "hold", "charge"][s]]
        }
    }
}

protocol AnalyticsSink {
    func send(name: String, params: [String: String])
}

struct ConsoleAnalyticsSink: AnalyticsSink {
    func send(name: String, params: [String: String]) {
        #if DEBUG
        print("[ANALYTICS] \(name) \(params.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " "))")
        #endif
    }
}

@MainActor
enum Analytics {
    static var sinks: [AnalyticsSink] = [ConsoleAnalyticsSink()]

    static func log(_ event: AnalyticsEvent) {
        for sink in sinks { sink.send(name: event.name, params: event.params) }
    }

    /// Records install date + session count locally so every backend gets cohort info for D1/D7.
    static func trackAppOpen() {
        let d = UserDefaults.standard
        let installKey = "hamsterages.installDate", sessionKey = "hamsterages.sessions"
        let install = (d.object(forKey: installKey) as? Date) ?? {
            let now = Date.now
            d.set(now, forKey: installKey)
            return now
        }()
        let sessions = d.integer(forKey: sessionKey) + 1
        d.set(sessions, forKey: sessionKey)
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: install), to: cal.startOfDay(for: .now)).day ?? 0
        log(.appOpen(daysSinceInstall: days, session: sessions))
    }
}
