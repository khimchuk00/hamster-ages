import Foundation

/// Collectible heroes (gacha-lite, the Battle Cats / Capybara Go meta pattern).
/// One general is equipped per battle and gives a passive bonus. Duplicates level a general up (max 5).
enum GeneralRarity: Int, Codable, CaseIterable {
    case rare, epic, legendary

    var title: String { L10n.t(["Rare", "Epic", "Legendary"][rawValue]) }
    /// Drop weight in a crate.
    var weight: Double { [70, 25, 5][rawValue] }
    /// Seeds refunded for a duplicate of a maxed general.
    var maxedRefund: Int { [150, 400, 1500][rawValue] }
}

enum GeneralID: String, Codable, CaseIterable, Identifiable {
    case sirNibbles, archie, grannyGrain, professor, bolt, ironBelly, queenSqueak, drBoom

    var id: String { rawValue }

    var name: String {
        switch self {
        case .sirNibbles: return L10n.t("Sir Nibbles")
        case .archie: return L10n.t("Archie Longshot")
        case .grannyGrain: return L10n.t("Granny Grain")
        case .professor: return L10n.t("Prof. Whiskers")
        case .bolt: return L10n.t("Bolt")
        case .ironBelly: return L10n.t("Iron Belly")
        case .queenSqueak: return L10n.t("Queen Squeak")
        case .drBoom: return L10n.t("Dr. Boom")
        }
    }

    var rarity: GeneralRarity {
        switch self {
        case .sirNibbles, .archie, .grannyGrain: return .rare
        case .professor, .bolt, .ironBelly: return .epic
        case .queenSqueak, .drBoom: return .legendary
        }
    }

    /// Visual: which era's gear the portrait wears, and the cape color.
    var ability: HeroAbility {
        switch self {
        case .sirNibbles: return .charge
        case .archie: return .volley
        case .grannyGrain: return .picnic
        case .professor: return .eureka
        case .bolt: return .overclock
        case .ironBelly: return .bulwark
        case .queenSqueak: return .royalDecree
        case .drBoom: return .bigBang
        }
    }

    var portraitEra: Int {
        switch self {
        case .sirNibbles: return 1
        case .archie: return 1
        case .grannyGrain: return 0
        case .professor: return 2
        case .bolt: return 4
        case .ironBelly: return 3
        case .queenSqueak: return 1
        case .drBoom: return 3
        }
    }

    var portraitRole: UnitRole {
        switch self {
        case .archie, .professor: return .ranged
        default: return .melee
        }
    }

    var capeColor: UInt32 {
        switch self {
        case .sirNibbles: return 0x3D7DD8
        case .archie: return 0x4CAF50
        case .grannyGrain: return 0xC9A227
        case .professor: return 0x7E57C2
        case .bolt: return 0x00B8D4
        case .ironBelly: return 0x795548
        case .queenSqueak: return 0xE91E63
        case .drBoom: return 0xFF6D00
        }
    }

    func effectText(level: Int) -> String {
        let l = Double(level)
        switch self {
        case .sirNibbles: return L10n.f("Melee damage +%lld%%", Int(8 * l))
        case .archie: return L10n.f("Ranged damage +%lld%%, range +%lld%%", Int(6 * l), Int(4 * l))
        case .grannyGrain: return L10n.f("Food income +%lld%%", Int(6 * l))
        case .professor: return L10n.f("XP gain +%lld%%", Int(8 * l))
        case .bolt: return L10n.f("Attack speed +%lld%%, move +%lld%%", Int(5 * l), Int(3 * l))
        case .ironBelly: return L10n.f("Unit HP +%lld%%", Int(7 * l))
        case .queenSqueak: return L10n.f("Units +%lld%% HP & damage, special −%lld%% cooldown", Int(5 * l), Int(5 * l))
        case .drBoom: return L10n.f("Special damage +%lld%%, turrets +%lld%%", Int(15 * l), Int(8 * l))
        }
    }

    func apply(level: Int, to m: inout SideModifiers) {
        let l = Double(level)
        switch self {
        case .sirNibbles: m.roleDamage[UnitRole.melee.rawValue] *= 1 + 0.08 * l
        case .archie:
            m.roleDamage[UnitRole.ranged.rawValue] *= 1 + 0.06 * l
            m.rangedRange *= 1 + 0.04 * l
        case .grannyGrain: m.income *= 1 + 0.06 * l
        case .professor: m.xpGain *= 1 + 0.08 * l
        case .bolt:
            m.attackSpeed *= 1 + 0.05 * l
            m.moveSpeed *= 1 + 0.03 * l
        case .ironBelly: m.unitHP *= 1 + 0.07 * l
        case .queenSqueak:
            m.unitHP *= 1 + 0.05 * l
            m.unitDamage *= 1 + 0.05 * l
            m.specialCooldown *= max(0.5, 1 - 0.05 * l)
        case .drBoom:
            m.specialDamage *= 1 + 0.15 * l
            m.turretDamage *= 1 + 0.08 * l
        }
    }
}

enum Generals {
    static let maxLevel = 5
    static let crateCost = 600

    /// Per-general weight = rarity weight split across that rarity's generals, so the per-rarity odds
    /// shown in the UI (70/25/5) are exactly what the roll produces.
    static func weight(_ g: GeneralID) -> Double {
        g.rarity.weight / Double(GeneralID.allCases.filter { $0.rarity == g.rarity }.count)
    }

    static func roll() -> GeneralID {
        let all = GeneralID.allCases
        let total = all.reduce(0) { $0 + weight($1) }
        var r = Double.random(in: 0..<total)
        for g in all {
            if r < weight(g) { return g }
            r -= weight(g)
        }
        return .sirNibbles
    }
}

/// What a crate produced, for the reveal screen.
struct CrateResult: Identifiable, Equatable {
    let id = UUID()
    let general: GeneralID
    let newLevel: Int
    let isNew: Bool
    let refund: Int
}
