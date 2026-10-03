import Foundation

// MARK: - Basic enums

public enum Side: Int, Codable, CaseIterable {
    case player, enemy

    public var opponent: Side { self == .player ? .enemy : .player }
    /// +1 for player (moves right), -1 for enemy (moves left).
    public var direction: Double { self == .player ? 1 : -1 }
}

public enum BattleMode: String, Codable {
    case campaign, survival, challenge

    /// Campaign-style rules: stage modifiers, overtime, sudden death.
    public var hasStageRules: Bool { self != .survival }
}

public enum UnitRole: Int, Codable, CaseIterable {
    case melee, ranged, heavy
}

// MARK: - Stat blocks

public struct UnitStats {
    public let name: String
    public let cost: Double
    public let hp: Double
    public let damage: Double
    public let attackInterval: Double
    public let range: Double
    public let speed: Double
    public let trainTime: Double
    public let width: Double
    public let isRanged: Bool
    public let projectileSpeed: Double
}

public struct TurretStats {
    public let name: String
    public let cost: Double
    public let damage: Double
    public let interval: Double
    public let range: Double
    public let projectileSpeed: Double
    public let splash: Double
}

public struct SpecialStats {
    public let name: String
    public let damage: Double
    public let cooldown: Double
}

public struct EraDef {
    public let index: Int
    public let name: String
    public let units: [UnitStats]          // indexed by UnitRole.rawValue
    public let turret: TurretStats
    public let special: SpecialStats
    public let baseHP: Double
    public let income: Double              // passive food / second
    /// Cumulative XP needed to evolve *out of* this era. nil for the last era.
    public let xpToEvolve: Double?

    public func unit(_ role: UnitRole) -> UnitStats { units[role.rawValue] }
}

// MARK: - Tunables

public enum GameConfig {
    public static let laneLength: Double = 1000
    public static let baseWidth: Double = 70
    public static let maxQueue = 5
    public static let startFood: Double = 140
    public static let killFoodMultiplier: Double = 0.6
    public static let killXPMultiplier: Double = 1.1
    /// Share of XP a side receives when one of its own units dies (comeback mechanic).
    public static let lossXPShare: Double = 0.25
    public static let passiveXPPerSecond: Double = 2
    public static let turretSlotCost: [Double] = [0, 150]   // slot 0 free, slot 1 unlock price
    public static let specialDelay: Double = 0.7
    public static let unitSpacing: Double = 4
    /// After this many seconds turrets go offline and unit damage ramps up, so late-game stalemates end.
    public static let overtimeStart: Double = 270
    /// Extra unit damage per minute of overtime (1.5 = +150%/min).
    public static let overtimeDamagePerMinute: Double = 1.5
    /// Campaign hard stop: from this time both bases crumble (share of max HP per second).
    public static let suddenDeathStart: Double = 420
    public static let suddenDeathRate: Double = 0.015
    /// Boss stages: the Rat King (a super heavy unit) marches in periodically.
    public static let bossFirstSpawn: Double = 45
    public static let bossInterval: Double = 100
    public static let bossHP: Double = 2.5
    public static let bossDamage: Double = 1.25
    /// Survival mode: endless, enemy grows stronger every interval; unlocked after beating stage 10.
    public static let survivalBaseStage = 8
    public static let survivalUnlockStage = 11
    public static let survivalRampInterval: Double = 30
    public static let survivalRamp: Double = 1.12

    public static let eraNames = ["Stone Age", "Medieval", "Gunpowder", "Modern", "Future"].map(L10n.t)
    /// Cost scale per era, power scale grows slightly faster so newer eras are more cost-efficient.
    static let costScale: [Double] = [1, 2.4, 5.5, 12, 26]
    static let powerBonus: [Double] = [1, 1.15, 1.32, 1.52, 1.75]

    public static let eras: [EraDef] = (0..<5).map(makeEra)

    static let unitNames: [[String]] = [
        ["Clubber", "Pebbler", "Boulder Brute"],
        ["Squire", "Archer", "Iron Knight"],
        ["Duelist", "Musketeer", "Cannoneer"],
        ["Trooper", "Rifler", "Tank"],
        ["Plasma Blade", "Blaster", "Mech"],
    ].map { $0.map(L10n.t) }
    static let turretNames = ["Rock Catapult", "Ballista", "Cannon", "Machine Gun", "Laser Tower"].map(L10n.t)
    static let specialNames = ["Meteor Shower", "Arrow Storm", "Barrage", "Air Strike", "Orbital Laser"].map(L10n.t)

    private static func makeEra(_ i: Int) -> EraDef {
        let c = costScale[i]
        let p = costScale[i] * powerBonus[i]
        let n = unitNames[i]
        let melee = UnitStats(name: n[0], cost: (15 * c).rounded(), hp: 60 * p, damage: 14 * p,
                              attackInterval: 1.0, range: 8, speed: 44, trainTime: 1.0,
                              width: 30, isRanged: false, projectileSpeed: 0)
        let ranged = UnitStats(name: n[1], cost: (25 * c).rounded(), hp: 40 * p, damage: 10 * p,
                               attackInterval: 1.25, range: 150, speed: 40, trainTime: 1.3,
                               width: 30, isRanged: true, projectileSpeed: 420)
        let heavy = UnitStats(name: n[2], cost: (90 * c).rounded(), hp: 330 * p, damage: 36 * p,
                              attackInterval: 1.6, range: i >= 2 ? 120 : 10, speed: 30, trainTime: 2.6,
                              width: 46, isRanged: i >= 2, projectileSpeed: 360)
        let turret = TurretStats(name: turretNames[i], cost: (80 * c).rounded(), damage: 7 * p,
                                 interval: [1.3, 1.1, 1.2, 0.45, 0.8][i],
                                 range: 230 + Double(i) * 15, projectileSpeed: 520,
                                 splash: [0, 0, 45, 0, 30][i])
        let special = SpecialStats(name: specialNames[i], damage: 70 * p, cooldown: 40)
        let xp: [Double?] = [320, 1350, 4300, 12500, nil]
        return EraDef(index: i, name: eraNames[i], units: [melee, ranged, heavy], turret: turret,
                      special: special, baseHP: [500, 1150, 2500, 5400, 11500][i],
                      income: [3, 7, 16, 35, 76][i], xpToEvolve: xp[i])
    }
}

// MARK: - Hero abilities

/// Once-per-battle active skill of the equipped general.
public enum HeroAbility: String, CaseIterable, Codable {
    case charge, volley, picnic, eureka, overclock, bulwark, royalDecree, bigBang

    public var title: String {
        switch self {
        case .charge: return L10n.t("Charge!")
        case .volley: return L10n.t("Volley")
        case .picnic: return L10n.t("Picnic")
        case .eureka: return L10n.t("Eureka")
        case .overclock: return L10n.t("Overclock")
        case .bulwark: return L10n.t("Bulwark")
        case .royalDecree: return L10n.t("Royal Decree")
        case .bigBang: return L10n.t("Big Bang")
        }
    }

    public var detail: String {
        switch self {
        case .charge: return L10n.f("Melee units deal +50%% damage for 10s")
        case .volley: return L10n.t("Arrows hit every rat on the field")
        case .picnic: return L10n.t("Instantly gain 30s worth of food")
        case .eureka: return L10n.t("Gain a big chunk of XP")
        case .overclock: return L10n.f("Units attack and move 50%% faster for 8s")
        case .bulwark: return L10n.f("Heal all units 50%% and the base 15%%")
        case .royalDecree: return L10n.t("3 free warriors join the fight")
        case .bigBang: return L10n.t("Your special attack recharges instantly")
        }
    }

    public static let chargeDuration: Double = 10
    public static let overclockDuration: Double = 8
}

// MARK: - Stage modifiers

/// Per-stage twist (from stage 6, never on boss stages or in Survival) so campaign battles don't all feel the same.
public enum StageModifier: String, CaseIterable, Codable {
    case none, goldRush, swarm, giants, siegeFog, armored, blitz

    public var title: String {
        switch self {
        case .none: return ""
        case .goldRush: return L10n.t("Gold Rush")
        case .swarm: return L10n.t("Rat Swarm")
        case .giants: return L10n.t("Giants")
        case .siegeFog: return L10n.t("Siege Fog")
        case .armored: return L10n.t("Armored Rats")
        case .blitz: return L10n.t("Blitz")
        }
    }

    public var detail: String {
        switch self {
        case .none: return ""
        case .goldRush: return L10n.f("Everyone earns +30%% food and XP")
        case .swarm: return L10n.t("Hordes of cheap rat warriors")
        case .giants: return L10n.t("Rats field more, tougher heavy units")
        case .siegeFog: return L10n.t("No turrets for either side")
        case .armored: return L10n.f("Rats have +25%% HP, −10%% damage")
        case .blitz: return L10n.f("Everything moves and trains 30%% faster")
        }
    }

    public var icon: String {
        switch self {
        case .none: return "circle"
        case .goldRush: return "dollarsign.circle.fill"
        case .swarm: return "ant.fill"
        case .giants: return "figure.stand"
        case .siegeFog: return "cloud.fog.fill"
        case .armored: return "shield.lefthalf.filled"
        case .blitz: return "hare.fill"
        }
    }

    public static func forStage(_ stage: Int) -> StageModifier {
        guard stage >= 6, stage % 5 != 0 else { return .none }
        let pool = allCases.filter { $0 != .none }
        // Cycle through the twists in order, counting only non-boss stages from 6.
        let index = (stage - 6) - (stage / 5 - 1)
        return pool[index % pool.count]
    }
}

// MARK: - Stage difficulty

public struct StageDifficulty {
    public let stage: Int
    public let aiIncome: Double
    public let aiStats: Double
    public let aiThinkInterval: Double
    public let aiUsesCards: Bool
    public let aiEvolveDelay: Double
    public let isBoss: Bool
    public let modifier: StageModifier

    public init(stage: Int, modifier forced: StageModifier? = nil) {
        let s = Double(max(1, stage) - 1)
        let boss = stage % 5 == 0
        self.stage = max(1, stage)
        isBoss = boss
        aiIncome = min(2.6, 0.6 + 0.045 * s)
        aiStats = min(2.2, 0.8 + 0.03 * s)
        aiThinkInterval = max(0.45, 1.3 - 0.05 * s)
        aiUsesCards = stage >= 4
        aiEvolveDelay = max(0.5, 10 - 0.6 * s)
        modifier = forced ?? StageModifier.forStage(stage)
    }
}
