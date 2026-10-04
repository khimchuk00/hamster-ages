import Foundation

/// What one battle contributed to quests.
struct BattleStats: Equatable {
    var won = false
    var unitsTrained = 0
    var kills = 0
    var specialsUsed = 0
    var evolutions = 0
    var bossesKilled = 0
}

enum QuestKind: String, Codable, CaseIterable {
    case winBattles, trainUnits, killRats, useSpecial, evolve, openCrate, buyUpgrade

    var target: Int {
        switch self {
        case .winBattles: return 3
        case .trainUnits: return 60
        case .killRats: return 80
        case .useSpecial: return 4
        case .evolve: return 6
        case .openCrate: return 1
        case .buyUpgrade: return 2
        }
    }

    var reward: Int {
        switch self {
        case .winBattles: return 200
        case .trainUnits, .useSpecial: return 120
        case .killRats, .evolve: return 150
        case .openCrate, .buyUpgrade: return 100
        }
    }

    var title: String {
        switch self {
        case .winBattles: return L10n.f("Win %lld battles", target)
        case .trainUnits: return L10n.f("Train %lld hamsters", target)
        case .killRats: return L10n.f("Defeat %lld rats", target)
        case .useSpecial: return L10n.f("Use special attacks %lld times", target)
        case .evolve: return L10n.f("Evolve %lld times", target)
        case .openCrate: return L10n.t("Open a Hamster Crate")
        case .buyUpgrade: return L10n.f("Buy %lld upgrades", target)
        }
    }

    var icon: String {
        switch self {
        case .winBattles: return "flag.checkered"
        case .trainUnits: return "person.3.fill"
        case .killRats: return "scope"
        case .useSpecial: return "flame.fill"
        case .evolve: return "arrow.up.forward.circle.fill"
        case .openCrate: return "shippingbox.fill"
        case .buyUpgrade: return "arrow.up.circle.fill"
        }
    }
}

struct Quest: Codable, Equatable {
    let kind: QuestKind
    var progress = 0
    var claimed = false

    var isComplete: Bool { progress >= kind.target }
}

/// Three quests per calendar day + a bonus crate for finishing all three.
struct QuestBoard: Codable, Equatable {
    let dayKey: Int
    var quests: [Quest]
    var bonusClaimed = false

    var allClaimed: Bool { quests.allSatisfy(\.claimed) }
    var hasClaimable: Bool { quests.contains { $0.isComplete && !$0.claimed } || (allClaimed && !bonusClaimed) }

    static func dayKey(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0)
    }

    /// Deterministic per day, always includes one "play" quest so it's completable by just playing.
    static func make(for date: Date) -> QuestBoard {
        let key = dayKey(date)
        var rng = SeededRandom(seed: UInt64(key) &* 2_654_435_761)
        let pool = QuestKind.allCases.filter { $0 != .winBattles }.shuffled(using: &rng)
        let picks = [QuestKind.winBattles] + Array(pool.prefix(2))
        return QuestBoard(dayKey: key, quests: picks.map { Quest(kind: $0) })
    }
}

/// Star Road: milestones on total campaign stars (best stars per stage). Endless: after the fixed
/// list, a crate every 25 stars.
enum StarRoad {
    enum Reward: Equatable {
        case seeds(Int)
        case crate
    }

    private static let fixed: [(stars: Int, reward: Reward)] = [
        (5, .seeds(200)), (12, .crate), (20, .seeds(600)), (30, .crate),
        (45, .seeds(1500)), (60, .crate), (80, .seeds(3000)), (100, .crate),
    ]

    static func milestone(_ index: Int) -> (stars: Int, reward: Reward) {
        if index < fixed.count { return fixed[index] }
        let extra = index - fixed.count + 1
        return (100 + 25 * extra, extra % 2 == 0 ? .seeds(3000 + 500 * extra) : .crate)
    }
}

/// Idle "Seed Farm": seeds accumulate while the player is away (capped), collected on the home screen.
enum SeedFarm {
    static let capHours: Double = 8

    static func ratePerHour(highestStage: Int) -> Double { 30 + 10 * Double(max(1, highestStage)) }

    static func amount(since last: Date?, highestStage: Int, now: Date = .now) -> Int {
        guard let last else { return 0 }
        let hours = min(capHours, max(0, now.timeIntervalSince(last) / 3600))
        return Int(hours * ratePerHour(highestStage: highestStage))
    }

    static func capacity(highestStage: Int) -> Int { Int(capHours * ratePerHour(highestStage: highestStage)) }
}

/// Local, schedule-driven live events (no server): weekends pay more seeds.
enum LiveEvents {
    static func isWeekend(_ date: Date) -> Bool { Calendar.current.isDateInWeekend(date) }

    static func seedMultiplier(now: Date = .now) -> Double { isWeekend(now) ? 1.5 : 1 }

    static func activeTitle(now: Date = .now) -> String? { isWeekend(now) ? L10n.t("Weekend Seed Festival ×1.5") : nil }
}

/// One hand-crafted-by-seed battle per day: same stage, twist, starting cards and RNG for everyone that day.
enum DailyChallenge {
    static let unlockStage = 6

    static func stage(highestStage: Int) -> Int { max(5, highestStage - 1) }

    static func seed(for date: Date) -> UInt64 { UInt64(QuestBoard.dayKey(date)) &* 0x9E37_79B9_7F4A_7C15 }

    static func modifier(for date: Date) -> StageModifier {
        let pool = StageModifier.allCases.filter { $0 != .none }
        return pool[QuestBoard.dayKey(date) % pool.count]
    }

    /// Two free starting cards (never Last Stand) so each day's build feels different.
    static func startingCards(for date: Date) -> [CardID] {
        var rng = SeededRandom(seed: seed(for: date) ^ 0xC0FFEE)
        let pool = Card.all.filter { $0.id != .lastStand }.shuffled(using: &rng)
        return pool.prefix(2).map(\.id)
    }

    static func reward(stage: Int) -> Int { 2 * (50 + 20 * stage) }

    /// Every day also has a win condition twist (rotates independently of the modifier).
    static func goal(for date: Date) -> BattleGoal {
        let pool = BattleGoal.allCases
        return pool[(QuestBoard.dayKey(date) / 2) % pool.count]
    }
}
