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
        Card(id: .sharpTeeth, title: L10n.t("Sharp Teeth"), detail: L10n.f("Melee damage +25%%"), icon: "bolt.fill", rarity: .common, stackable: true),
        Card(id: .eagleEye, title: L10n.t("Eagle Eye"), detail: L10n.f("Ranged range +20%%, damage +10%%"), icon: "scope", rarity: .common, stackable: true),
        Card(id: .thickFur, title: L10n.t("Thick Fur"), detail: L10n.f("All units +20%% HP"), icon: "shield.fill", rarity: .common, stackable: true),
        Card(id: .chubbyCheeks, title: L10n.t("Chubby Cheeks"), detail: L10n.f("Food income +30%%"), icon: "leaf.fill", rarity: .common, stackable: true),
        Card(id: .fastLearner, title: L10n.t("Fast Learner"), detail: L10n.f("XP gain +30%%"), icon: "graduationcap.fill", rarity: .common, stackable: true),
        Card(id: .fortify, title: L10n.t("Fortify"), detail: L10n.f("Base max HP +25%% and repair 25%%"), icon: "building.columns.fill", rarity: .common, stackable: true),
        Card(id: .turretGrease, title: L10n.t("Turret Grease"), detail: L10n.f("Turrets +30%% damage, +15%% fire rate"), icon: "gearshape.2.fill", rarity: .common, stackable: true),
        Card(id: .seedStash, title: L10n.t("Seed Stash"), detail: L10n.t("Instantly gain a big pile of food"), icon: "sack.fill", rarity: .common, stackable: true),
        Card(id: .hamsterWheel, title: L10n.t("Hamster Wheel"), detail: L10n.f("Training 30%% faster"), icon: "arrow.triangle.2.circlepath", rarity: .rare, stackable: true),
        Card(id: .recruiter, title: L10n.t("Recruiter"), detail: L10n.t("A free melee unit every 10s"), icon: "person.badge.plus", rarity: .rare, stackable: true),
        Card(id: .vampireBite, title: L10n.t("Vampire Bite"), detail: L10n.f("Units heal 20%% HP on kill"), icon: "drop.fill", rarity: .rare, stackable: true),
        Card(id: .skyFury, title: L10n.t("Sky Fury"), detail: L10n.f("Special: -30%% cooldown, +30%% damage"), icon: "cloud.bolt.fill", rarity: .rare, stackable: true),
        Card(id: .bargainBin, title: L10n.t("Bargain Bin"), detail: L10n.f("Units cost 15%% less"), icon: "tag.fill", rarity: .rare, stackable: true),
        Card(id: .berserk, title: L10n.t("Berserk"), detail: L10n.f("Attack speed +25%%"), icon: "flame.fill", rarity: .rare, stackable: true),
        Card(id: .splashShot, title: L10n.t("Splash Shot"), detail: L10n.f("Ranged hits splash 50%% to nearby foes"), icon: "burst.fill", rarity: .epic, stackable: false),
        Card(id: .lastStand, title: L10n.t("Last Stand"), detail: L10n.f("Once per battle your base survives at 40%% HP"), icon: "heart.circle.fill", rarity: .epic, stackable: false),
        Card(id: .giantGrowth, title: L10n.t("Giant Growth"), detail: L10n.f("Heavy units +40%% HP and damage"), icon: "arrow.up.left.and.arrow.down.right", rarity: .epic, stackable: true),
        Card(id: .warDrums, title: L10n.t("War Drums"), detail: L10n.f("All units +15%% damage and speed"), icon: "music.note", rarity: .epic, stackable: true),
        Card(id: .shieldWall, title: L10n.t("Shield Wall"), detail: L10n.f("Melee units take 20%% less damage"), icon: "shield.lefthalf.filled", rarity: .common, stackable: true),
        Card(id: .sniperNest, title: L10n.t("Sniper Nest"), detail: L10n.f("Turrets +25%% range, +10%% damage"), icon: "binoculars.fill", rarity: .common, stackable: true),
        Card(id: .scavenger, title: L10n.t("Scavenger"), detail: L10n.f("+40%% food from defeated rats"), icon: "takeoutbag.and.cup.and.straw.fill", rarity: .common, stackable: true),
        Card(id: .rapidFire, title: L10n.t("Rapid Fire"), detail: L10n.f("Ranged units attack 30%% faster"), icon: "dot.radiowaves.right", rarity: .rare, stackable: true),
        Card(id: .siegeBreaker, title: L10n.t("Siege Breaker"), detail: L10n.f("+50%% damage to the rat base"), icon: "hammer.fill", rarity: .rare, stackable: true),
        Card(id: .secondWind, title: L10n.t("Second Wind"), detail: L10n.t("Your base slowly repairs itself"), icon: "cross.case.fill", rarity: .rare, stackable: true),
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
