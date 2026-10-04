import Foundation

// MARK: - Elite rat traits

/// Elite rats appear from stage 4. Each trait has a clear counter so the player has a reason to adapt
/// their army mix instead of spamming one unit.
public enum RatTrait: String, CaseIterable, Codable {
    case swift, armored, shielded, plague, medic

    public var title: String {
        switch self {
        case .swift: return L10n.t("Swift Rat")
        case .armored: return L10n.t("Armored Rat")
        case .shielded: return L10n.t("Shield Rat")
        case .plague: return L10n.t("Plague Rat")
        case .medic: return L10n.t("Rat Medic")
        }
    }

    /// What it does.
    public var detail: String {
        switch self {
        case .swift: return L10n.t("Runs fast but is fragile")
        case .armored: return L10n.t("Arrows and bullets barely scratch it")
        case .shielded: return L10n.t("Its bubble blocks the first 3 hits")
        case .plague: return L10n.t("Bursts into 2 small rats when it falls")
        case .medic: return L10n.t("Heals hurt rats around it")
        }
    }

    /// How to beat it — shown when it first appears.
    public var counter: String {
        switch self {
        case .swift: return L10n.t("Counter: turrets and ranged units")
        case .armored: return L10n.t("Counter: melee and heavy units")
        case .shielded: return L10n.t("Counter: many quick hits (ranged, turrets)")
        case .plague: return L10n.t("Counter: splash damage and specials")
        case .medic: return L10n.t("Counter: take it out first — specials, long range")
        }
    }

    public var icon: String {
        switch self {
        case .swift: return "bolt.fill"
        case .armored: return "shield.fill"
        case .shielded: return "circle.circle.fill"
        case .plague: return "allergens.fill"
        case .medic: return "heart.fill"
        }
    }

    /// Stage from which this trait can show up in the campaign.
    public var firstStage: Int {
        switch self {
        case .swift: return 4
        case .armored: return 7
        case .shielded: return 9
        case .plague: return 12
        case .medic: return 6
        }
    }

    public static let shieldHits = 3
    /// Medic: heal share of max HP, how often, and how far.
    public static let medicHeal = 0.12
    public static let medicInterval = 2.2
    public static let medicRange = 150.0

    /// Medics only come as ranged rats (they hang back).
    public func fits(_ role: UnitRole) -> Bool { self != .medic || role == .ranged }

    public static func pool(stage: Int) -> [RatTrait] { allCases.filter { stage >= $0.firstStage } }

    /// Share of trained rats that come out elite.
    public static func chance(stage: Int) -> Double {
        guard stage >= 4 else { return 0 }
        return min(0.3, 0.06 + 0.015 * Double(stage - 4))
    }
}

/// How the damage was dealt — armored rats shrug off "pierce".
enum DamageKind { case melee, pierce, heavy, special }

// MARK: - Stance

/// Army-wide order. Gives the player a real decision mid-fight: pull back under the turrets,
/// hold the line, or push.
public enum Stance: Int, CaseIterable, Codable {
    case fallBack, hold, charge

    public var title: String {
        switch self {
        case .fallBack: return L10n.t("Fall back")
        case .hold: return L10n.t("Hold")
        case .charge: return L10n.t("Charge")
        }
    }

    public var icon: String {
        switch self {
        case .fallBack: return "arrow.uturn.backward"
        case .hold: return "hand.raised.fill"
        case .charge: return "flag.fill"
        }
    }

    /// Distance from the own base front where units stop (nil = no limit).
    var line: Double? {
        switch self {
        case .fallBack: return 30
        case .hold: return 215
        case .charge: return nil
        }
    }
}

// MARK: - Rat generals

/// Named enemy commanders. Each one plays differently, so stages feel like fights against someone.
public enum RatGeneral: String, CaseIterable, Codable {
    case gnawsworth, skritch, whiskerbane, squeak, cheddar, ratKing

    public var name: String {
        switch self {
        case .gnawsworth: return L10n.t("Captain Gnawsworth")
        case .skritch: return L10n.t("Warlord Skritch")
        case .whiskerbane: return L10n.t("Baroness Whiskerbane")
        case .squeak: return L10n.t("Professor Fizzle")
        case .cheddar: return L10n.t("Big Cheddar")
        case .ratKing: return L10n.t("The Rat King")
        }
    }

    /// One-line play style for the stage card.
    public var style: String {
        switch self {
        case .gnawsworth: return L10n.t("By the book")
        case .skritch: return L10n.t("Rushes you early")
        case .whiskerbane: return L10n.t("Turtles behind turrets")
        case .squeak: return L10n.t("Evolves fast")
        case .cheddar: return L10n.t("Endless cheap swarms")
        case .ratKing: return L10n.t("Leads giant royal rats")
        }
    }

    public var taunt: String {
        switch self {
        case .gnawsworth: return L10n.t("Ten-hut, rats! Show these fluffballs some discipline!")
        case .skritch: return L10n.t("No waiting! CHARGE! Always charge!")
        case .whiskerbane: return L10n.t("Come closer, darlings. My towers are hungry.")
        case .squeak: return L10n.t("Science! My rats evolve faster than yours.")
        case .cheddar: return L10n.t("More rats! MORE! Cheap and cheerful!")
        case .ratKing: return L10n.t("Kneel before your king, little hamsters!")
        }
    }

    /// Portrait accent colour (cape / badge).
    public var color: UInt32 {
        switch self {
        case .gnawsworth: return 0x5C6BC0
        case .skritch: return 0xD84315
        case .whiskerbane: return 0x8E24AA
        case .squeak: return 0x00897B
        case .cheddar: return 0xF9A825
        case .ratKing: return 0xB0306A
        }
    }

    public static func forStage(_ stage: Int) -> RatGeneral {
        if stage % 5 == 0 { return .ratKing }
        if stage <= 2 { return .gnawsworth }
        let rotation: [RatGeneral] = [.skritch, .whiskerbane, .squeak, .cheddar, .gnawsworth]
        // Count only non-boss stages from 3 so every general gets a turn before repeating.
        let index = (stage - 3) - (stage / 5)
        return rotation[index % rotation.count]
    }

    /// AI personality knobs.
    struct Profile {
        var weights: [Double] = [0.48, 0.34, 0.18]
        var evolveDelay: Double = 1
        /// Buys/upgrades turrets with less spare food.
        var turretEager = false
        var buysSecondSlot = true
        /// Holds under its turrets until it has this many units (nil = always charges).
        var massBeforeCharge: Int?
        var specialCrowd = 5
    }

    var profile: Profile {
        var p = Profile()
        switch self {
        case .gnawsworth, .ratKing: break
        case .skritch:
            p.weights = [0.62, 0.28, 0.10]
            p.evolveDelay = 1.6
            p.buysSecondSlot = false
            p.specialCrowd = 4
        case .whiskerbane:
            p.weights = [0.36, 0.44, 0.20]
            p.turretEager = true
            p.massBeforeCharge = 6
        case .squeak:
            p.weights = [0.36, 0.46, 0.18]
            p.evolveDelay = 0.4
        case .cheddar:
            p.weights = [0.72, 0.23, 0.05]
            p.specialCrowd = 6
        }
        return p
    }

    /// Small stat identity on top of the stage's difficulty.
    func apply(to m: inout SideModifiers) {
        switch self {
        case .squeak:
            m.xpGain *= 1.12
            m.income *= 0.96
        case .cheddar:
            m.unitCost *= 0.9
            m.unitHP *= 0.94
            m.trainSpeed *= 1.15
        case .skritch:
            m.moveSpeed *= 1.08
        default: break
        }
    }
}
