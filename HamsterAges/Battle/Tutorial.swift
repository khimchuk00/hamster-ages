import Foundation

/// HUD element a tutorial hint points at.
enum TutorialTarget: Hashable {
    case unit, turret, special, evolve
}

/// First-battle onboarding. Each step appears once its condition is met; "blocking" steps freeze the
/// battle until the player performs the highlighted action, so nobody gets overrun while reading.
enum TutorialStep: Int, CaseIterable {
    case train, earn, turret, special, evolve, finish

    var text: String {
        switch self {
        case .train: return L10n.t("Tap the Clubber to train your first hamster warrior!")
        case .earn: return L10n.t("Hamsters march on their own. Defeat rats to earn 🌽 food and XP.")
        case .turret: return L10n.t("Build a turret — it shoots any rat that gets close to your base.")
        case .special: return L10n.t("Rats incoming! Unleash your special attack.")
        case .evolve: return L10n.t("Enough XP! Evolve to unlock stronger units and a new base.")
        case .finish: return L10n.t("Destroy the rat base to win. Good luck, commander!")
        }
    }

    var target: TutorialTarget? {
        switch self {
        case .train: return .unit
        case .turret: return .turret
        case .special: return .special
        case .evolve: return .evolve
        case .earn, .finish: return nil
        }
    }

    /// Only the very first action and the first evolution freeze the battle; other hints just point.
    var isBlocking: Bool { target == .unit || target == .evolve }

    /// Seconds a non-blocking hint stays on screen.
    var duration: Double { target == nil ? 5 : 7 }

    var analyticsName: String { String(describing: self) }
}
