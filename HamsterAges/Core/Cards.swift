import Foundation

// MARK: - Deterministic RNG (so battles are reproducible in the headless harness)

public struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    public init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    public mutating func next() -> UInt64 {
        // SplitMix64
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Modifiers (meta upgrades + cards + difficulty all fold into this)

public struct SideModifiers {
    public var unitHP = 1.0
    public var unitDamage = 1.0
    public var roleDamage: [Double] = [1, 1, 1]
    public var roleHP: [Double] = [1, 1, 1]
    public var attackSpeed = 1.0
    public var moveSpeed = 1.0
    public var rangedRange = 1.0
    public var income = 1.0
    public var killFood = 1.0
    public var xpGain = 1.0
    public var trainSpeed = 1.0
    public var baseHP = 1.0
    public var turretDamage = 1.0
    public var turretRate = 1.0
    public var specialCooldown = 1.0
    public var specialDamage = 1.0
    public var unitCost = 1.0
    public var lifestealOnKill = 0.0
    public var rangedSplash = 0.0
    public var recruiterInterval: Double? = nil
    public var hasLastStand = false
    public var startFood = 0.0
    /// Damage taken multiplier per role (lower = tougher).
    public var roleArmor: [Double] = [1, 1, 1]
    public var roleAttackSpeed: [Double] = [1, 1, 1]
    public var turretRange = 1.0
    /// Damage multiplier against the enemy base.
    public var baseDamage = 1.0
    /// Base regeneration, share of max HP per second.
    public var baseRegen = 0.0

    public init() {}
}

// MARK: - Evolution cards

public enum CardRarity: Int, Codable, CaseIterable {
    case common, rare, epic

    var weight: Double {
        switch self {
        case .common: return 60
        case .rare: return 30
        case .epic: return 10
        }
    }
}

public enum CardID: String, Codable, CaseIterable {
    case sharpTeeth, eagleEye, thickFur, chubbyCheeks, fastLearner, hamsterWheel, fortify,
         turretGrease, recruiter, vampireBite, skyFury, bargainBin, berserk, splashShot,
         seedStash, lastStand, giantGrowth, warDrums,
         shieldWall, sniperNest, scavenger, rapidFire, siegeBreaker, secondWind
}

public struct Card: Identifiable, Equatable {
    public let id: CardID
    public let title: String
    public let detail: String
    public let icon: String     // SF Symbol name
    public let rarity: CardRarity
    public let stackable: Bool

    public static let all: [Card] = [
        Card(id: .sharpTeeth, title: "Sharp Teeth", detail: "Melee damage +25%", icon: "bolt.fill", rarity: .common, stackable: true),
        Card(id: .eagleEye, title: "Eagle Eye", detail: "Ranged range +20%, damage +10%", icon: "scope", rarity: .common, stackable: true),
        Card(id: .thickFur, title: "Thick Fur", detail: "All units +20% HP", icon: "shield.fill", rarity: .common, stackable: true),
        Card(id: .chubbyCheeks, title: "Chubby Cheeks", detail: "Food income +30%", icon: "leaf.fill", rarity: .common, stackable: true),
        Card(id: .fastLearner, title: "Fast Learner", detail: "XP gain +30%", icon: "graduationcap.fill", rarity: .common, stackable: true),
        Card(id: .fortify, title: "Fortify", detail: "Base max HP +25% and repair 25%", icon: "building.columns.fill", rarity: .common, stackable: true),
        Card(id: .turretGrease, title: "Turret Grease", detail: "Turrets +30% damage, +15% fire rate", icon: "gearshape.2.fill", rarity: .common, stackable: true),
        Card(id: .seedStash, title: "Seed Stash", detail: "Instantly gain a big pile of food", icon: "sack.fill", rarity: .common, stackable: true),
        Card(id: .hamsterWheel, title: "Hamster Wheel", detail: "Training 30% faster", icon: "arrow.triangle.2.circlepath", rarity: .rare, stackable: true),
        Card(id: .recruiter, title: "Recruiter", detail: "A free melee unit every 10s", icon: "person.badge.plus", rarity: .rare, stackable: true),
        Card(id: .vampireBite, title: "Vampire Bite", detail: "Units heal 20% HP on kill", icon: "drop.fill", rarity: .rare, stackable: true),
        Card(id: .skyFury, title: "Sky Fury", detail: "Special: -30% cooldown, +30% damage", icon: "cloud.bolt.fill", rarity: .rare, stackable: true),
        Card(id: .bargainBin, title: "Bargain Bin", detail: "Units cost 15% less", icon: "tag.fill", rarity: .rare, stackable: true),
        Card(id: .berserk, title: "Berserk", detail: "Attack speed +25%", icon: "flame.fill", rarity: .rare, stackable: true),
        Card(id: .splashShot, title: "Splash Shot", detail: "Ranged hits splash 50% to nearby foes", icon: "burst.fill", rarity: .epic, stackable: false),
        Card(id: .lastStand, title: "Last Stand", detail: "Once per battle your base survives at 40% HP", icon: "heart.circle.fill", rarity: .epic, stackable: false),
        Card(id: .giantGrowth, title: "Giant Growth", detail: "Heavy units +40% HP and damage", icon: "arrow.up.left.and.arrow.down.right", rarity: .epic, stackable: true),
        Card(id: .warDrums, title: "War Drums", detail: "All units +15% damage and speed", icon: "music.note", rarity: .epic, stackable: true),
        Card(id: .shieldWall, title: "Shield Wall", detail: "Melee units take 20% less damage", icon: "shield.lefthalf.filled", rarity: .common, stackable: true),
        Card(id: .sniperNest, title: "Sniper Nest", detail: "Turrets +25% range, +10% damage", icon: "binoculars.fill", rarity: .common, stackable: true),
        Card(id: .scavenger, title: "Scavenger", detail: "+40% food from defeated rats", icon: "takeoutbag.and.cup.and.straw.fill", rarity: .common, stackable: true),
        Card(id: .rapidFire, title: "Rapid Fire", detail: "Ranged units attack 30% faster", icon: "dot.radiowaves.right", rarity: .rare, stackable: true),
        Card(id: .siegeBreaker, title: "Siege Breaker", detail: "+50% damage to the rat base", icon: "hammer.fill", rarity: .rare, stackable: true),
        Card(id: .secondWind, title: "Second Wind", detail: "Your base slowly repairs itself", icon: "cross.case.fill", rarity: .rare, stackable: true),
    ]

    public static func card(_ id: CardID) -> Card { all.first { $0.id == id }! }

    /// Draws `count` distinct cards, weighted by rarity, skipping non-stackable cards already owned.
    public static func draw(count: Int, owned: [CardID], rng: inout SeededRandom, epicBoost: Double = 1) -> [Card] {
        var pool = all.filter { $0.stackable || !owned.contains($0.id) }
        var result: [Card] = []
        while result.count < count, !pool.isEmpty {
            let weights = pool.map { $0.rarity == .epic ? $0.rarity.weight * epicBoost : $0.rarity.weight }
            let total = weights.reduce(0, +)
            var roll = Double.random(in: 0..<total, using: &rng)
            var pick = pool.count - 1
            for (i, w) in weights.enumerated() {
                if roll < w { pick = i; break }
                roll -= w
            }
            result.append(pool.remove(at: pick))
        }
        return result
    }
}
