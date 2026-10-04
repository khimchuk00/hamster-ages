import Foundation

// MARK: - Fur skins

/// Cosmetic fur colours for the player's hamsters. Earned on the Hamster Pass.
enum FurSkin: String, CaseIterable, Codable {
    case classic, cocoa, golden, snow, midnight

    var title: String {
        switch self {
        case .classic: return L10n.t("Classic")
        case .cocoa: return L10n.t("Cocoa")
        case .golden: return L10n.t("Golden")
        case .snow: return L10n.t("Snowball")
        case .midnight: return L10n.t("Midnight")
        }
    }

    /// fur, furDark, belly (hex)
    var colors: (fur: UInt32, furDark: UInt32, belly: UInt32) {
        switch self {
        case .classic: return (0xF4A259, 0xB0642A, 0xFFEBCD)
        case .cocoa: return (0x9C6644, 0x5E3B24, 0xE8D2B8)
        case .golden: return (0xFFD045, 0xC28A12, 0xFFF4C9)
        case .snow: return (0xF4F1EC, 0xB9B2A8, 0xFFFFFF)
        case .midnight: return (0x4B4A6B, 0x26253D, 0xA9A6C9)
        }
    }
}

// MARK: - Hamster Pass (28-day season track)

enum HamsterPass {
    static let tiers = 20
    static let xpPerTier = 100
    static let seasonDays = 28
    /// Season 1 started on Monday 5 January 2026 (UTC).
    static let epoch = Date(timeIntervalSince1970: 1_767_571_200)

    enum Reward: Equatable {
        case seeds(Int)
        case crate
        case skin(FurSkin)
    }

    static func season(now: Date = .now) -> Int {
        max(1, Int(floor(now.timeIntervalSince(epoch) / Double(seasonDays * 86_400))) + 1)
    }

    static func seasonEnd(now: Date = .now) -> Date {
        epoch.addingTimeInterval(Double(season(now: now) * seasonDays * 86_400))
    }

    static func tier(xp: Int) -> Int { min(tiers, xp / xpPerTier) }

    static func freeReward(tier t: Int) -> Reward {
        switch t {
        case 5, 10, 15: return .crate
        case tiers: return .skin(.cocoa)
        default: return .seeds(60 + 10 * t)
        }
    }

    /// Premium track; its final skin alternates between seasons so each season has an exclusive.
    static func premiumReward(tier t: Int, season: Int) -> Reward {
        switch t {
        case 4, 8, 12, 16: return .crate
        case 10: return .skin(.golden)
        case tiers: return .skin(season % 2 == 0 ? .midnight : .snow)
        default: return .seeds(150 + 25 * t)
        }
    }

    // XP sources
    static func xp(battleWon won: Bool, stars: Int) -> Int { won ? 40 + 10 * stars : 15 }
    static func xp(survivalWave wave: Int) -> Int { min(80, 10 * wave) }
    static func xp(challengeWon won: Bool) -> Int { won ? 80 : 20 }
    static let questXP = 25
}

struct PassClaim {
    let reward: HamsterPass.Reward
    let crate: CrateResult?
}
