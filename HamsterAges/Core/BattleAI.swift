import Foundation

/// Simple, readable opponent. Difficulty comes from `StageDifficulty` (reaction time, evolve delay, cards)
/// and from the economic/stat modifiers applied to its side.
public final class BattleAI {
    private let thinkInterval: Double
    private let evolveDelay: Double
    private let usesCards: Bool
    private var thinkTimer: Double = 1.0
    private var evolveAt: Double?
    private var plannedRole: UnitRole?
    /// Composition weights: melee, ranged, heavy.
    public var weights: [Double] = [0.48, 0.34, 0.18]
    private var profile = RatGeneral.Profile()

    public init(difficulty: StageDifficulty, general: RatGeneral = .gnawsworth) {
        profile = general.profile
        thinkInterval = difficulty.aiThinkInterval
        evolveDelay = difficulty.aiEvolveDelay * profile.evolveDelay
        usesCards = difficulty.aiUsesCards
        weights = profile.weights
    }

    /// Used by the headless harness to let an AI play the player's side with "human-like" settings.
    public init(thinkInterval: Double, evolveDelay: Double, usesCards: Bool) {
        self.thinkInterval = thinkInterval
        self.evolveDelay = evolveDelay
        self.usesCards = usesCards
    }

    public func update(sim: BattleSimulation, side: Side, dt: Double) {
        thinkTimer -= dt
        guard thinkTimer <= 0 else { return }
        thinkTimer = thinkInterval * Double.random(in: 0.8...1.2, using: &sim.rng)

        // 1. Evolve (after a human-ish delay).
        if sim.state(side).canEvolve {
            if evolveAt == nil { evolveAt = sim.time + evolveDelay }
            if let t = evolveAt, sim.time >= t {
                sim.evolve(side)
                evolveAt = nil
                if usesCards, let card = sim.drawCards(for: side).first {
                    sim.applyCard(card.id, to: side)
                }
            }
        }

        // 2. Special when the opponent has a crowd on the field.
        let foes = sim.units.filter { $0.side == side.opponent }
        let foesNearBase = foes.filter {
            abs($0.x - BattleSimulation.baseFront(side)) < GameConfig.laneLength * 0.45
        }.count
        if sim.state(side).specialCooldown <= 0, foes.count >= profile.specialCrowd || foesNearBase >= 3 {
            sim.useSpecial(side)
        }

        // Turtle generals mass up under their turrets, then push; they never wait past overtime.
        if let mass = profile.massBeforeCharge {
            let mine = sim.units.filter { $0.side == side }.count
            let current = sim.state(side).stance
            let push = sim.isOvertime || mine >= mass || (current == .charge && mine > mass / 3)
            let want: Stance = push ? .charge : .hold
            if want != current { sim.setStance(want, for: side) }
        }

        // 3. Turrets: keep slot 0 current, open slot 1 when rich (not possible in overtime / Siege Fog).
        let s = sim.state(side)
        if !sim.turretsDisabled && !sim.isOvertime {
            let turretCost = sim.turretCost(for: side)
            let reserve = sim.unitCost(.melee, for: side) * (profile.turretEager ? 1 : 2)
            for slot in 0..<2 where s.turrets[slot].unlocked {
                let outdated = s.turrets[slot].era.map { $0 < s.era } ?? true
                if outdated, s.food >= turretCost + reserve, s.era >= 1 || slot == 0 && s.food > turretCost * 1.6,
                   sim.buyTurret(slot: slot, for: side) {
                    return
                }
            }
            if profile.buysSecondSlot, !s.turrets[1].unlocked, s.era >= (profile.turretEager ? 0 : 1),
               s.food > sim.slotUnlockCost(for: side) + turretCost * (profile.turretEager ? 1.1 : 1.5),
               sim.unlockSlot(for: side) {
                return
            }
        }

        // 4. Units: pick a role and save for it.
        if plannedRole == nil { plannedRole = pickRole(sim) }
        if let role = plannedRole, sim.state(side).queue.count < 3, sim.train(role, for: side) {
            plannedRole = nil
        }
    }

    private func pickRole(_ sim: BattleSimulation) -> UnitRole {
        let total = weights.reduce(0, +)
        var r = Double.random(in: 0..<total, using: &sim.rng)
        for (i, w) in weights.enumerated() {
            if r < w { return UnitRole(rawValue: i)! }
            r -= w
        }
        return .melee
    }
}
