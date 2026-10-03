import Foundation
import Observation

// MARK: - Permanent upgrades

enum MetaUpgrade: String, Codable, CaseIterable, Identifiable {
    case baseArmor, rations, foraging, training, weapons, scholar, engineering, charm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .baseArmor: return "Base Armor"
        case .rations: return "Rations"
        case .foraging: return "Foraging"
        case .training: return "Training"
        case .weapons: return "Weapons"
        case .scholar: return "Scholar"
        case .engineering: return "Engineering"
        case .charm: return "Lucky Charm"
        }
    }

    var icon: String {
        switch self {
        case .baseArmor: return "building.columns.fill"
        case .rations: return "takeoutbag.and.cup.and.straw.fill"
        case .foraging: return "leaf.fill"
        case .training: return "heart.fill"
        case .weapons: return "bolt.fill"
        case .scholar: return "graduationcap.fill"
        case .engineering: return "gearshape.2.fill"
        case .charm: return "dice.fill"
        }
    }

    var maxLevel: Int { self == .charm ? 3 : 25 }

    func effectText(level: Int) -> String {
        let l = Double(level)
        switch self {
        case .baseArmor: return "Base HP +\(Int(8 * l))%"
        case .rations: return "Start food +\(Int(20 * l))"
        case .foraging: return "Food income +\(Int(5 * l))%"
        case .training: return "Unit HP +\(Int(5 * l))%"
        case .weapons: return "Unit damage +\(Int(5 * l))%"
        case .scholar: return "XP gain +\(Int(5 * l))%"
        case .engineering: return "Turret damage +\(Int(6 * l))%"
        case .charm: return "\(level) card reroll\(level == 1 ? "" : "s") per battle"
        }
    }

    func cost(level: Int) -> Int {
        let base: Double = self == .charm ? 600 : 60
        let growth: Double = self == .charm ? 3.0 : 1.25
        return Int((base * pow(growth, Double(level))).rounded())
    }
}

// MARK: - Saved progress

struct PlayerProgress: Codable {
    var seeds = 0
    var stage = 1
    var highestStage = 1
    var upgrades: [String: Int] = [:]
    var stars: [Int: Int] = [:]
    var dailyStreak = 0
    var lastDailyClaim: Date?
    var battlesPlayed = 0
    var wins = 0
    // Fields added after v1 are optional so older saves still decode.
    var tutorialDone: Bool?
    var removeAds: Bool?
    var starterBought: Bool?
    var generals: [String: Int]?
    var equippedGeneral: String?
    var lastFreeCrate: Date?
    var questBoard: QuestBoard?
    var lastFarmCollect: Date?
    var bestSurvival: Double?
    var starMilestonesClaimed: Int?
    var challengeClearedDay: Int?

    var totalStars: Int { stars.values.reduce(0, +) }
    var nextStarMilestone: (stars: Int, reward: StarRoad.Reward) { StarRoad.milestone(starMilestonesClaimed ?? 0) }
    var starRewardReady: Bool { totalStars >= nextStarMilestone.stars }

    func generalLevel(_ g: GeneralID) -> Int { generals?[g.rawValue] ?? 0 }
    var equipped: GeneralID? { equippedGeneral.flatMap(GeneralID.init(rawValue:)) }

    func level(_ u: MetaUpgrade) -> Int { upgrades[u.rawValue] ?? 0 }

    var battleModifiers: SideModifiers {
        var m = SideModifiers()
        func l(_ u: MetaUpgrade) -> Double { Double(level(u)) }
        m.baseHP = 1 + 0.08 * l(.baseArmor)
        m.startFood = 20 * l(.rations)
        m.income = 1 + 0.05 * l(.foraging)
        m.unitHP = 1 + 0.05 * l(.training)
        m.unitDamage = 1 + 0.05 * l(.weapons)
        m.xpGain = 1 + 0.05 * l(.scholar)
        m.turretDamage = 1 + 0.06 * l(.engineering)
        if let g = equipped, generalLevel(g) > 0 { g.apply(level: generalLevel(g), to: &m) }
        return m
    }
}

// MARK: - Store

@MainActor
@Observable
final class ProgressStore {
    private(set) var progress: PlayerProgress
    private let key = "hamsterages.progress.v1"
    static let dailyRewards = [50, 80, 120, 160, 220, 300, 600]

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let p = try? JSONDecoder().decode(PlayerProgress.self, from: data) {
            progress = p
        } else {
            progress = PlayerProgress()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // Upgrades
    func canBuy(_ u: MetaUpgrade) -> Bool {
        progress.level(u) < u.maxLevel && progress.seeds >= u.cost(level: progress.level(u))
    }

    func buy(_ u: MetaUpgrade) {
        guard canBuy(u) else { return }
        let cost = u.cost(level: progress.level(u))
        progress.seeds -= cost
        progress.upgrades[u.rawValue] = progress.level(u) + 1
        Analytics.log(.upgradeBought(id: u.rawValue, level: progress.level(u), cost: cost))
        advanceQuest(.buyUpgrade, by: 1)
        save()
    }

    // Battle rewards
    static func reward(stage: Int, won: Bool, damageFraction: Double) -> Int {
        let full = 50 + 20 * stage
        return won ? full : Int((Double(full) * 0.55 * damageFraction).rounded()) + 5
    }

    static func survivalReward(wave: Int) -> Int { 40 * wave + 10 * wave * wave / 4 }

    /// Survival never advances the campaign; it pays per wave and keeps a personal best.
    func recordSurvival(seconds: Double, seeds: Int, stats: BattleStats) {
        progress.seeds += seeds
        progress.battlesPlayed += 1
        progress.bestSurvival = max(progress.bestSurvival ?? 0, seconds)
        refreshDailyState()
        advanceQuest(.trainUnits, by: stats.unitsTrained)
        advanceQuest(.killRats, by: stats.kills)
        advanceQuest(.useSpecial, by: stats.specialsUsed)
        advanceQuest(.evolve, by: stats.evolutions)
        save()
    }

    var survivalUnlocked: Bool { progress.highestStage >= GameConfig.survivalUnlockStage }
    var challengeUnlocked: Bool { progress.highestStage >= DailyChallenge.unlockStage }
    func challengeAvailable(now: Date = .now) -> Bool { progress.challengeClearedDay != QuestBoard.dayKey(now) }

    /// Daily challenge never advances the campaign; a win marks today's challenge cleared.
    func recordChallenge(won: Bool, seeds: Int, stats: BattleStats, now: Date = .now) {
        progress.seeds += seeds
        progress.battlesPlayed += 1
        refreshDailyState(now: now)
        if won {
            progress.wins += 1
            progress.challengeClearedDay = QuestBoard.dayKey(now)
            advanceQuest(.winBattles, by: 1)
        }
        advanceQuest(.trainUnits, by: stats.unitsTrained)
        advanceQuest(.killRats, by: stats.kills)
        advanceQuest(.useSpecial, by: stats.specialsUsed)
        advanceQuest(.evolve, by: stats.evolutions)
        save()
    }

    func recordBattle(stage: Int, won: Bool, seeds: Int, stars: Int, stats: BattleStats = BattleStats()) {
        progress.seeds += seeds
        refreshDailyState()
        if won { advanceQuest(.winBattles, by: 1) }
        advanceQuest(.trainUnits, by: stats.unitsTrained)
        advanceQuest(.killRats, by: stats.kills)
        advanceQuest(.useSpecial, by: stats.specialsUsed)
        advanceQuest(.evolve, by: stats.evolutions)
        progress.battlesPlayed += 1
        if won {
            progress.wins += 1
            progress.stars[stage] = max(progress.stars[stage] ?? 0, stars)
            if stage == progress.stage {
                progress.stage += 1
                progress.highestStage = max(progress.highestStage, progress.stage)
            }
        }
        save()
    }

    func completeTutorial() {
        progress.tutorialDone = true
        // First general for free, so every player meets the collection right after onboarding.
        if progress.generalLevel(.sirNibbles) == 0 {
            progress.generals = (progress.generals ?? [:]).merging([GeneralID.sirNibbles.rawValue: 1]) { $1 }
            // Don't swap out a general the player already pulled from a crate before finishing the tutorial.
            if progress.equipped == nil { progress.equippedGeneral = GeneralID.sirNibbles.rawValue }
        }
        save()
    }

    // MARK: Daily quests & seed farm

    /// Rolls the quest board over at midnight and starts the farm clock. Call on app open / home appear.
    func refreshDailyState(now: Date = .now) {
        var changed = false
        if progress.questBoard?.dayKey != QuestBoard.dayKey(now) {
            progress.questBoard = QuestBoard.make(for: now)
            changed = true
        }
        if progress.lastFarmCollect == nil {
            progress.lastFarmCollect = now
            changed = true
        }
        if changed { save() }
    }

    private func advanceQuest(_ kind: QuestKind, by n: Int) {
        guard n > 0 else { return }
        refreshDailyState()   // roll over at midnight / create the board before crediting progress
        guard var board = progress.questBoard else { return }
        for i in board.quests.indices where board.quests[i].kind == kind && !board.quests[i].claimed {
            board.quests[i].progress = min(kind.target, board.quests[i].progress + n)
        }
        progress.questBoard = board
    }

    @discardableResult
    func claimQuest(at index: Int) -> Int {
        guard var board = progress.questBoard, board.quests.indices.contains(index),
              board.quests[index].isComplete, !board.quests[index].claimed else { return 0 }
        board.quests[index].claimed = true
        let reward = board.quests[index].kind.reward
        progress.questBoard = board
        progress.seeds += reward
        save()
        Analytics.log(.questClaimed(kind: board.quests[index].kind.rawValue))
        return reward
    }

    func claimQuestBonus() -> CrateResult? {
        guard var board = progress.questBoard, board.allClaimed, !board.bonusClaimed else { return nil }
        board.bonusClaimed = true
        progress.questBoard = board
        return openCrate(free: false, questBonus: true)
    }

    /// Claims the next Star Road milestone. Returns seeds granted and/or the crate result.
    func claimStarReward() -> (seeds: Int, crate: CrateResult?)? {
        guard progress.starRewardReady else { return nil }
        let m = progress.nextStarMilestone
        progress.starMilestonesClaimed = (progress.starMilestonesClaimed ?? 0) + 1
        switch m.reward {
        case .seeds(let n):
            progress.seeds += n
            save()
            return (n, nil)
        case .crate:
            return (0, openCrate(free: false, questBonus: true))
        }
    }

    func farmAmount(now: Date = .now) -> Int {
        SeedFarm.amount(since: progress.lastFarmCollect, highestStage: progress.highestStage, now: now)
    }

    @discardableResult
    func collectFarm(doubled: Bool, now: Date = .now) -> Int {
        let amount = farmAmount(now: now) * (doubled ? 2 : 1)
        guard amount > 0 else { return 0 }
        progress.seeds += amount
        progress.lastFarmCollect = now
        save()
        Analytics.log(.farmCollected(amount: amount, doubled: doubled))
        return amount
    }

    // MARK: Generals

    func equip(_ g: GeneralID) {
        guard progress.generalLevel(g) > 0 else { return }
        progress.equippedGeneral = g.rawValue
        save()
    }

    func freeCrateAvailable(now: Date = .now) -> Bool {
        guard let last = progress.lastFreeCrate else { return true }
        // Strictly a later calendar day: winding the clock forward, claiming, then back must not re-open it.
        let cal = Calendar.current
        return cal.startOfDay(for: now) > cal.startOfDay(for: last)
    }

    /// Opens a crate. Paid crates cost seeds; the free one is once per day (behind a rewarded ad).
    func openCrate(free: Bool, questBonus: Bool = false) -> CrateResult? {
        if questBonus {
            // Paid for by completing all daily quests: no cost, no daily limit.
        } else if free {
            guard freeCrateAvailable() else { return nil }
            progress.lastFreeCrate = .now
        } else {
            guard progress.seeds >= Generals.crateCost else { return nil }
            progress.seeds -= Generals.crateCost
        }
        let g = Generals.roll()
        let old = progress.generalLevel(g)
        var refund = 0
        if old >= Generals.maxLevel {
            refund = g.rarity.maxedRefund
            progress.seeds += refund
        } else {
            progress.generals = (progress.generals ?? [:]).merging([g.rawValue: old + 1]) { $1 }
        }
        if progress.equippedGeneral == nil { progress.equippedGeneral = g.rawValue }
        advanceQuest(.openCrate, by: 1)
        save()
        Analytics.log(.crateOpened(general: g.rawValue, rarity: g.rarity.title, free: free))
        return CrateResult(general: g, newLevel: min(Generals.maxLevel, old + 1), isNew: old == 0, refund: refund)
    }

    func setRemoveAds() {
        progress.removeAds = true
        save()
    }

    func markStarterBought() {
        progress.starterBought = true
        save()
    }

    func addSeeds(_ n: Int) {
        progress.seeds += n
        save()
    }

    // Daily reward (7-day streak; missing a day resets)
    func dailyStatus(now: Date = .now) -> (available: Bool, dayIndex: Int) {
        let cal = Calendar.current
        guard let last = progress.lastDailyClaim else { return (true, 0) }
        if cal.isDate(last, inSameDayAs: now) { return (false, progress.dailyStreak % 7) }
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: last), to: cal.startOfDay(for: now)).day ?? 99
        if days < 0 { return (false, progress.dailyStreak % 7) }   // clock moved back
        return (true, days == 1 ? progress.dailyStreak % 7 : 0)
    }

    @discardableResult
    func claimDaily(now: Date = .now) -> Int {
        let status = dailyStatus(now: now)
        guard status.available else { return 0 }
        let amount = Self.dailyRewards[status.dayIndex]
        progress.dailyStreak = status.dayIndex + 1
        progress.lastDailyClaim = now
        progress.seeds += amount
        save()
        Analytics.log(.dailyClaimed(day: status.dayIndex + 1))
        return amount
    }

    /// Wipes game progress but keeps purchase entitlements (they're restorable anyway).
    func resetAll() {
        var fresh = PlayerProgress()
        fresh.removeAds = progress.removeAds
        fresh.starterBought = progress.starterBought
        fresh.tutorialDone = progress.tutorialDone
        // Keep daily timers so a reset can't re-claim today's rewards.
        fresh.lastDailyClaim = progress.lastDailyClaim
        fresh.dailyStreak = progress.dailyStreak
        fresh.lastFreeCrate = progress.lastFreeCrate
        progress = fresh
        save()
    }

    #if DEBUG
    func debugSkipStages(_ n: Int) {
        progress.stage += n
        progress.highestStage = max(progress.highestStage, progress.stage)
        save()
    }

    func debugReset() {
        progress = PlayerProgress()
        save()
    }
    #endif
}
