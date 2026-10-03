import Foundation

/// Headless AI-vs-AI balance runs. Used by Tools/SimHarness (CLI) and by the DEBUG screen in the app.
public enum BalanceHarness {
    public struct Row {
        public let stage: Int
        public let meta: Int
        public let winRate: Double
        public let avgMinutes: Double
        public let avgEra: Double
        public let games: Int
    }

    public static func metaMods(level: Int) -> SideModifiers {
        var m = SideModifiers()
        let l = Double(level)
        m.baseHP = 1 + 0.08 * l
        m.startFood = 20 * l
        m.income = 1 + 0.05 * l
        m.unitHP = 1 + 0.05 * l
        m.unitDamage = 1 + 0.05 * l
        m.xpGain = 1 + 0.05 * l
        m.turretDamage = 1 + 0.06 * l
        return m
    }

    public static func run(stage: Int, meta: Int, games: Int) -> Row {
        var wins = 0
        var minutes = 0.0
        var eras = 0
        for g in 0..<games {
            let sim = BattleSimulation(difficulty: StageDifficulty(stage: stage), playerMods: metaMods(level: meta),
                                       seed: UInt64(stage * 1000 + meta * 100 + g + 1))
            sim.controllers[.player] = BattleAI(thinkInterval: 0.9, evolveDelay: 1.5, usesCards: true)
            if let c = sim.drawCards(for: .player).first { sim.applyCard(c.id, to: .player) }
            let dt = 1.0 / 30.0
            while sim.winner == nil && sim.time < 1200 {
                sim.step(dt)
                sim.events.removeAll(keepingCapacity: true)
            }
            if sim.winner == .player { wins += 1 }
            minutes += sim.time / 60
            eras += sim.state(.player).era
        }
        let n = Double(games)
        return Row(stage: stage, meta: meta, winRate: Double(wins) / n, avgMinutes: minutes / n,
                   avgEra: Double(eras) / n, games: games)
    }

    public static let defaultMatrix: [(stage: Int, meta: Int)] = [
        (1, 0), (2, 0), (3, 0), (5, 0), (6, 0), (8, 0), (8, 3), (10, 3), (10, 6), (15, 6), (15, 10), (20, 10), (25, 14),
    ]

    public static func report(games: Int = 12) -> String {
        var lines = ["stage meta | win% | avg min | era"]
        for (stage, meta) in defaultMatrix {
            let r = run(stage: stage, meta: meta, games: games)
            lines.append(String(format: "%5d %4d | %4.0f | %7.1f | %3.1f", r.stage, r.meta, r.winRate * 100, r.avgMinutes, r.avgEra))
        }
        return lines.joined(separator: "\n")
    }
}
