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
        case .train: return "Tap the Clubber to train your first hamster warrior!"
        case .earn: return "Hamsters march on their own. Defeat rats to earn 🌽 food and XP."
        case .turret: return "Build a turret — it shoots any rat that gets close to your base."
        case .special: return "Rats incoming! Unleash your special attack."
        case .evolve: return "Enough XP! Evolve to unlock stronger units and a new base."
        case .finish: return "Destroy the rat base to win. Good luck, commander!"
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

    var isBlocking: Bool { target != nil }

    /// Seconds a non-blocking hint stays on screen.
    var duration: Double { 5 }

    var analyticsName: String { String(describing: self) }
}
