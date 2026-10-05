import Foundation

// MARK: - Unit variants (Army Workshop)

/// Three variants per role. The player picks one per role before battle (loadout) and levels them up with seeds;
/// rat generals field their own favourites, so every army plays a little differently.
public enum UnitVariant: String, CaseIterable, Codable {
    case brawler, spearman, berserker      // melee
    case archer, slinger, sniper           // ranged
    case brute, guardian, bombardier       // heavy

    public var role: UnitRole {
        switch self {
        case .brawler, .spearman, .berserker: return .melee
        case .archer, .slinger, .sniper: return .ranged
        case .brute, .guardian, .bombardier: return .heavy
        }
    }

    /// The free starting variant of each role.
    public static func standard(_ role: UnitRole) -> UnitVariant {
        switch role {
        case .melee: return .brawler
        case .ranged: return .archer
        case .heavy: return .brute
        }
    }

    public static func of(_ role: UnitRole) -> [UnitVariant] { allCases.filter { $0.role == role } }
    public var isStandard: Bool { self == UnitVariant.standard(role) }

    public var title: String {
        switch self {
        case .brawler: return L10n.t("Brawler")
        case .spearman: return L10n.t("Spearman")
        case .berserker: return L10n.t("Berserker")
        case .archer: return L10n.t("Archer")
        case .slinger: return L10n.t("Slinger")
        case .sniper: return L10n.t("Sharpshooter")
        case .brute: return L10n.t("Brute")
        case .guardian: return L10n.t("Guardian")
        case .bombardier: return L10n.t("Bombardier")
        }
    }

    public var detail: String {
        switch self {
        case .brawler: return L10n.t("Solid all-rounder")
        case .spearman: return L10n.t("Long reach: strikes from the second rank")
        case .berserker: return L10n.t("Attacks very fast, but fragile")
        case .archer: return L10n.t("Steady damage from range")
        case .slinger: return L10n.t("Cheap and quick to train, weaker shots")
        case .sniper: return L10n.t("Huge range and big hits, slow to reload")
        case .brute: return L10n.t("Tough frontline bruiser")
        case .guardian: return L10n.t("A walking wall: lots of HP, little damage")
        case .bombardier: return L10n.t("Lobs exploding shots from any age")
        }
    }

    public var icon: String {
        switch self {
        case .brawler: return "figure.boxing"
        case .spearman: return "arrow.up.right"
        case .berserker: return "flame.fill"
        case .archer: return "scope"
        case .slinger: return "circle.dotted"
        case .sniper: return "binoculars.fill"
        case .brute: return "shield.fill"
        case .guardian: return "shield.lefthalf.filled"
        case .bombardier: return "burst.fill"
        }
    }

    public static let maxLevel = 10
    /// HP and damage per level above 1.
    public static let levelBonus = 0.05

    /// Seeds to unlock (0 for the standard variant).
    public var unlockCost: Int {
        switch self {
        case .brawler, .archer, .brute: return 0
        case .spearman, .slinger, .guardian: return 900
        case .berserker, .sniper, .bombardier: return 2200
        }
    }

    /// Seeds to go from `level` to `level + 1`.
    public static func upgradeCost(level: Int) -> Int { Int((120 * pow(1.42, Double(level - 1))).rounded()) }

    /// Applies the variant (and its level) to an era's base stats.
    public func apply(_ s: UnitStats, level: Int) -> UnitStats {
        var cost = s.cost, hp = s.hp, dmg = s.damage, interval = s.attackInterval, range = s.range
        var speed = s.speed, train = s.trainTime, ranged = s.isRanged, projectile = s.projectileSpeed
        switch self {
        case .brawler, .archer, .brute: break
        case .spearman: range = 42; hp *= 0.85; dmg *= 0.9; cost *= 1.15
        case .berserker: interval *= 0.62; hp *= 0.8; speed *= 1.15; cost *= 1.1
        case .slinger: cost *= 0.65; hp *= 0.85; dmg *= 0.7; train *= 0.7; range *= 0.85
        case .sniper: range *= 1.5; dmg *= 1.7; interval *= 1.8; cost *= 1.3; hp *= 0.9
        case .guardian: hp *= 1.6; dmg *= 0.55; cost *= 1.1; speed *= 0.9
        case .bombardier:
            hp *= 0.7; dmg *= 0.85
            if !ranged { ranged = true; range = 115; projectile = 330 }
        }
        let k = 1 + UnitVariant.levelBonus * Double(max(1, level) - 1)
        return UnitStats(name: s.name, cost: cost.rounded(), hp: hp * k, damage: dmg * k, attackInterval: interval,
                         range: range, speed: speed, trainTime: train, width: s.width, isRanged: ranged,
                         projectileSpeed: projectile)
    }
}

/// What a side brings to battle: one variant per role and its level.
public struct Loadout: Equatable {
    public var variants: [UnitVariant]
    public var levels: [Int]

    public init(variants: [UnitVariant] = UnitRole.allCases.map(UnitVariant.standard), levels: [Int] = [1, 1, 1]) {
        self.variants = variants
        self.levels = levels
    }

    public func variant(_ role: UnitRole) -> UnitVariant { variants[role.rawValue] }
    public func stats(era: Int, role: UnitRole) -> UnitStats {
        variant(role).apply(GameConfig.eras[era].unit(role), level: levels[role.rawValue])
    }
}

extension RatGeneral {
    /// Each commander's favourite troops.
    public var loadout: Loadout {
        switch self {
        case .gnawsworth, .ratKing: return Loadout()
        case .skritch: return Loadout(variants: [.berserker, .archer, .brute])
        case .whiskerbane: return Loadout(variants: [.brawler, .archer, .guardian])
        case .squeak: return Loadout(variants: [.brawler, .sniper, .brute])
        case .cheddar: return Loadout(variants: [.brawler, .slinger, .brute])
        case .grimtail: return Loadout(variants: [.brawler, .archer, .bombardier])
        case .sneakpaw: return Loadout(variants: [.spearman, .sniper, .brute])
        }
    }
}

/// Campaign chapters start further up the timeline: chapter 2 opens in the Medieval age, and so on.
public enum ChapterStart {
    public static func era(stage: Int) -> Int { min(GameConfig.eras.count - 1, (max(1, stage) - 1) / 10) }
}
