import Foundation

// MARK: - Entities

public final class UnitEntity {
    public let id: Int
    public let side: Side
    public let role: UnitRole
    public let era: Int
    public var x: Double
    public var hp: Double
    public let maxHP: Double
    public let damage: Double
    public let attackInterval: Double
    public let range: Double
    public let speed: Double
    public let width: Double
    public let isRanged: Bool
    public let projectileSpeed: Double
    public let cost: Double
    /// Visual depth offset in -1...1 so a crowd doesn't look like a single line.
    public let depth: Double
    /// The Rat King on boss stages.
    public let isBoss: Bool
    /// Damage taken multiplier (Shield Wall).
    public let armor: Double
    /// Elite rat trait (nil for normal units).
    public let trait: RatTrait?
    /// Small rat that bursts out of a Plague Rat.
    public let isMinion: Bool
    /// Hits the Shield Rat's bubble can still absorb.
    public internal(set) var shield: Int
    public var cooldown: Double = 0
    public var isMoving = false
    /// Walking back toward its own base (Fall back stance).
    public internal(set) var isRetreating = false
    /// Rat King: > 0 while winding up a ground slam.
    public internal(set) var windup: Double = 0
    var slamCooldown = GameConfig.bossSlamFirst
    var healCooldown = 1.0
    /// Rat King: already called the royal guard (once, at half health).
    var summoned = false
    public var isAlive: Bool { hp > 0 }
    /// Visual size relative to a normal unit of the same role.
    public var sizeScale: Double { isBoss ? 1.4 : isMinion ? 0.7 : 1 }

    init(id: Int, side: Side, role: UnitRole, era: Int, x: Double, stats s: UnitStats, mods m: SideModifiers,
         boss: Bool = false, trait: RatTrait? = nil, minion: Bool = false) {
        isBoss = boss
        self.trait = boss || minion ? nil : trait
        isMinion = minion
        shield = self.trait == .shielded ? RatTrait.shieldHits : 0
        armor = m.roleArmor[role.rawValue]
        var hpK = boss ? GameConfig.bossHP : 1, dmgK = boss ? GameConfig.bossDamage : 1, speedK = boss ? 0.8 : 1
        var costK = boss ? 4.0 : 1
        switch self.trait {
        case .swift?: hpK *= 0.7; speedK *= 1.6
        case .armored?: hpK *= 1.1; speedK *= 0.92
        case .medic?: dmgK *= 0.5
        case .shielded?, .plague?: break
        case nil: break
        }
        if self.trait != nil { costK *= 1.4 }       // elites pay a bigger bounty
        if minion { hpK *= 0.35; dmgK *= 0.5; speedK *= 1.15; costK *= 0.2 }
        self.id = id
        self.side = side
        self.role = role
        self.era = era
        self.x = x
        maxHP = s.hp * m.unitHP * m.roleHP[role.rawValue] * hpK
        hp = maxHP
        damage = s.damage * m.unitDamage * m.roleDamage[role.rawValue] * dmgK
        attackInterval = s.attackInterval / (m.attackSpeed * m.roleAttackSpeed[role.rawValue])
        range = s.isRanged ? s.range * m.rangedRange : s.range
        speed = s.speed * m.moveSpeed * speedK
        width = s.width * (boss ? 1.4 : minion ? 0.7 : 1)
        isRanged = s.isRanged
        projectileSpeed = s.projectileSpeed
        cost = s.cost * costK
        depth = Double((id * 37) % 7) / 3.0 - 1.0
        cooldown = 0.2
    }
}

public struct Projectile {
    public let id: Int
    public let side: Side
    public let era: Int
    public let fromTurret: Bool
    public let isHeavy: Bool
    public let startX: Double
    public var x: Double
    public var targetID: Int?       // nil → enemy base
    public var targetX: Double
    public let speed: Double
    public let damage: Double
    public let splash: Double       // radius; 0 = single target
    public let splashFactor: Double
    public let sourceID: Int?
}

public enum BattleEvent {
    case spawned(unitID: Int)
    case attacked(unitID: Int)
    case unitHit(unitID: Int, damage: Double)
    case died(unitID: Int, x: Double, side: Side, era: Int, role: UnitRole)
    case baseHit(side: Side, damage: Double)
    case projectileFired(id: Int)
    case projectileImpact(id: Int, x: Double)
    case turretFired(side: Side, slot: Int)
    case specialLaunched(side: Side, era: Int)
    case specialImpact(side: Side, era: Int)
    case evolved(side: Side, era: Int)
    case lastStand(side: Side)
    case overtimeStarted
    case bossSpawned(unitID: Int)
    /// A rat with an elite trait came out of the enemy base.
    case eliteSpawned(unitID: Int, trait: RatTrait)
    /// A Shield Rat's bubble absorbed a hit (`left` = 0 → popped).
    case shieldHit(unitID: Int, left: Int)
    /// The Rat King raises its paws — a slam lands in `GameConfig.bossSlamWindup` seconds.
    case bossWindup(unitID: Int, x: Double, radius: Double)
    case bossSlam(unitID: Int, x: Double, radius: Double)
    /// Counter feedback: the hit was weak (`effective` = false) or strong against this rat's trait.
    case counterHit(unitID: Int, effective: Bool)
    /// A Rat Medic patched up an ally.
    case healed(unitID: Int, by: Int, amount: Double)
    /// The Rat King, hurt, calls in his guard.
    case bossSummon(unitID: Int)
    case waveUp(level: Int)
    case reviveOffered
    case suddenDeathStarted
    case heroAbility(side: Side, ability: HeroAbility)
    case reward(side: Side, food: Double, x: Double)
    case gameOver(winner: Side)
}

public struct QueuedUnit {
    public let role: UnitRole
    public let era: Int
}

public struct TurretSlot {
    public var unlocked: Bool
    public var era: Int?
    public var cooldown: Double = 0
}

public struct SideState {
    public var food: Double
    public var xp: Double = 0
    public var era: Int = 0
    public var baseHP: Double
    public var baseMaxHP: Double
    public var queue: [QueuedUnit] = []
    public var trainProgress: Double = 0
    public var turrets: [TurretSlot] = [TurretSlot(unlocked: true), TurretSlot(unlocked: false)]
    public var specialCooldown: Double = 8
    public var mods: SideModifiers
    public var cards: [CardID] = []
    public var lastStandUsed = false
    public var recruiterTimer: Double = 0
    public var damageToEnemyBase: Double = 0
    public var kills = 0
    public var unitsTrained = 0
    public var specialsUsed = 0
    public var heroAbility: HeroAbility?
    public var heroUsed = false
    public var chargeTimer: Double = 0
    public var overclockTimer: Double = 0
    public var heroReady: Bool { heroAbility != nil && !heroUsed }
    public var bossesKilled = 0
    /// Army-wide order (player HUD / AI general).
    public var stance: Stance = .charge

    public var eraDef: EraDef { GameConfig.eras[era] }
    public var specialMaxCooldown: Double { eraDef.special.cooldown * mods.specialCooldown }

    /// 0...1 progress inside the current era's XP band.
    public var xpProgress: Double {
        guard let need = eraDef.xpToEvolve else { return 1 }
        let prev = era == 0 ? 0 : (GameConfig.eras[era - 1].xpToEvolve ?? 0)
        return min(1, max(0, (xp - prev) / (need - prev)))
    }
    public var canEvolve: Bool {
        guard let need = eraDef.xpToEvolve else { return false }
        return xp >= need
    }
    public var trainFraction: Double {
        guard let q = queue.first else { return 0 }
        return min(1, trainProgress / GameConfig.eras[q.era].unit(q.role).trainTime)
    }
}

// MARK: - Simulation

public final class BattleSimulation {
    public private(set) var units: [UnitEntity] = []
    public private(set) var projectiles: [Projectile] = []
    public private(set) var time: Double = 0
    public private(set) var winner: Side?
    public let difficulty: StageDifficulty
    public var rng: SeededRandom
    public var events: [BattleEvent] = []
    /// AI controllers. The enemy always has one; the harness can attach one to the player too.
    public var controllers: [Side: BattleAI] = [:]

    private var sides: [SideState]
    private var nextID = 1
    private var pendingSpecials: [(side: Side, era: Int, damage: Double, timeLeft: Double)] = []

    private var bossTimer = GameConfig.bossFirstSpawn

    public let mode: BattleMode
    /// The rat commander for this battle (AI personality + taunts).
    public let ratGeneral: RatGeneral
    /// How this battle is won (Daily Challenge twists); set before the first step.
    public var goal: BattleGoal = .destroyBase
    /// Siege Fog modifier.
    public private(set) var turretsDisabled = false
    public var activeModifier: StageModifier { mode.hasStageRules ? difficulty.modifier : .none }
    /// Player may revive their base once per battle (rewarded ad). The UI sets this when ads are available.
    public var reviveEnabled = false
    public private(set) var awaitingRevive = false
    private var reviveUsed = false
    /// Survival: how many difficulty ramps have happened.
    public private(set) var survivalWave = 1
    private var survivalTimer = GameConfig.survivalRampInterval

    public var isOvertime: Bool { mode.hasStageRules && time >= GameConfig.overtimeStart }
    /// Unit damage multiplier that ramps up during overtime.
    public var overtimeFactor: Double {
        guard isOvertime else { return 1 }   // Survival has no overtime; its ramp is the wave system.
        return 1 + max(0, time - GameConfig.overtimeStart) / 60 * GameConfig.overtimeDamagePerMinute
    }

    public init(difficulty: StageDifficulty, playerMods: SideModifiers, seed: UInt64, mode: BattleMode = .campaign) {
        self.difficulty = difficulty
        self.mode = mode
        ratGeneral = mode == .survival ? .ratKing : RatGeneral.forStage(difficulty.stage)
        rng = SeededRandom(seed: seed)
        var enemyMods = BattleSimulation.enemyModifiers(difficulty)
        ratGeneral.apply(to: &enemyMods)
        func makeSide(_ m: SideModifiers) -> SideState {
            let hp = GameConfig.eras[0].baseHP * m.baseHP
            return SideState(food: GameConfig.startFood + m.startFood, baseHP: hp, baseMaxHP: hp, mods: m)
        }
        sides = [makeSide(playerMods), makeSide(enemyMods)]
        controllers[.enemy] = BattleAI(difficulty: difficulty, general: ratGeneral)
        if mode.hasStageRules { applyStageModifier(difficulty.modifier) }
        if difficulty.isBoss {
            // Bosses open with a free epic card.
            let epics = Card.all.filter { $0.rarity == .epic && $0.id != .lastStand }
            if let c = epics.randomElement(using: &rng) { applyCard(c.id, to: .enemy) }
        }
    }

    private func applyStageModifier(_ m: StageModifier) {
        let heavy = UnitRole.heavy.rawValue
        switch m {
        case .none: break
        case .goldRush:
            for side in Side.allCases { mutate(side) { $0.mods.income *= 1.3; $0.mods.xpGain *= 1.3 } }
        case .swarm:
            mutate(.enemy) { $0.mods.unitCost *= 0.7; $0.mods.income *= 1.1; $0.mods.trainSpeed *= 1.3 }
            controllers[.enemy]?.weights = [0.7, 0.25, 0.05]
        case .giants:
            mutate(.enemy) { $0.mods.roleHP[heavy] *= 1.25; $0.mods.roleDamage[heavy] *= 1.1 }
            controllers[.enemy]?.weights = [0.4, 0.33, 0.27]
        case .siegeFog:
            turretsDisabled = true
        case .armored:
            mutate(.enemy) { $0.mods.unitHP *= 1.25; $0.mods.unitDamage *= 0.9 }
        case .blitz:
            for side in Side.allCases {
                mutate(side) { $0.mods.moveSpeed *= 1.3; $0.mods.trainSpeed *= 1.3; $0.mods.attackSpeed *= 1.1 }
            }
        }
    }

    public static func enemyModifiers(_ d: StageDifficulty) -> SideModifiers {
        var m = SideModifiers()
        m.unitHP = d.aiStats
        m.unitDamage = d.aiStats
        m.turretDamage = d.aiStats
        m.baseHP = 0.9 + 0.1 * d.aiStats
        m.income = d.aiIncome
        m.killFood = 0.85 + 0.15 * d.aiIncome
        m.xpGain = 0.9 + 0.1 * d.aiIncome
        return m
    }

    // MARK: State access

    public func state(_ side: Side) -> SideState { sides[side.rawValue] }
    private func mutate(_ side: Side, _ body: (inout SideState) -> Void) { body(&sides[side.rawValue]) }

    public static func baseFront(_ side: Side) -> Double {
        side == .player ? GameConfig.baseWidth : GameConfig.laneLength - GameConfig.baseWidth
    }
    public static func spawnX(_ side: Side, width: Double) -> Double {
        baseFront(side) + side.direction * (width / 2 + 2)
    }

    // MARK: Commands (player HUD and AI)

    public func unitCost(_ role: UnitRole, for side: Side) -> Double {
        let s = state(side)
        return (s.eraDef.unit(role).cost * s.mods.unitCost).rounded()
    }

    public func turretCost(for side: Side) -> Double { state(side).eraDef.turret.cost }

    public func slotUnlockCost(for side: Side) -> Double {
        (GameConfig.turretSlotCost[1] * GameConfig.costScale[state(side).era]).rounded()
    }

    @discardableResult
    public func train(_ role: UnitRole, for side: Side) -> Bool {
        guard winner == nil else { return false }
        let cost = unitCost(role, for: side)
        let s = state(side)
        guard s.queue.count < GameConfig.maxQueue, s.food >= cost else { return false }
        mutate(side) {
            $0.food -= cost
            $0.queue.append(QueuedUnit(role: role, era: $0.era))
        }
        return true
    }

    public func setStance(_ stance: Stance, for side: Side) {
        mutate(side) { $0.stance = stance }
    }

    /// Elite traits the rats can field right now and the share of trained rats that get one.
    public var eliteOdds: (pool: [RatTrait], chance: Double) {
        switch mode {
        case .survival:
            let stage = GameConfig.survivalBaseStage + 2 * (survivalWave - 1)
            return (RatTrait.pool(stage: stage), RatTrait.chance(stage: stage))
        case .campaign, .challenge:
            return (RatTrait.pool(stage: difficulty.stage), RatTrait.chance(stage: difficulty.stage))
        }
    }

    @discardableResult
    public func evolve(_ side: Side) -> Bool {
        guard winner == nil, state(side).canEvolve else { return false }
        mutate(side) { s in
            s.era += 1
            let newMax = s.eraDef.baseHP * s.mods.baseHP
            s.baseHP += newMax - s.baseMaxHP
            s.baseMaxHP = newMax
            s.specialCooldown = min(s.specialCooldown, 6)
        }
        events.append(.evolved(side: side, era: state(side).era))
        return true
    }

    /// Showcase / CI screenshots only: jumps `side` straight to `target` era with some food to spend.
    public func debugJump(_ side: Side, toEra target: Int) {
        let t = min(target, GameConfig.eras.count - 1)
        while state(side).era < t {
            mutate(side) { $0.xp = 1e9 }
            guard evolve(side) else { break }
        }
        mutate(side) { $0.xp = 0; $0.food += 300 * GameConfig.costScale[$0.era] }
        events.removeAll()
    }

    /// Buys (or upgrades to the current era) the turret in `slot`. Old turret is refunded 50%.
    @discardableResult
    public func buyTurret(slot: Int, for side: Side) -> Bool {
        let s = state(side)
        guard winner == nil, !isOvertime, !turretsDisabled, slot < s.turrets.count, s.turrets[slot].unlocked,
              !(side == .player && goal == .noTurrets) else { return false }
        if let e = s.turrets[slot].era, e >= s.era { return false }
        let refund = s.turrets[slot].era.map { GameConfig.eras[$0].turret.cost * 0.5 } ?? 0
        let cost = turretCost(for: side)
        guard s.food + refund >= cost else { return false }
        mutate(side) {
            $0.food += refund - cost
            $0.turrets[slot].era = $0.era
            $0.turrets[slot].cooldown = 0.3
        }
        return true
    }

    @discardableResult
    public func sellTurret(slot: Int, for side: Side) -> Bool {
        guard let e = state(side).turrets[slot].era else { return false }
        mutate(side) {
            $0.food += GameConfig.eras[e].turret.cost * 0.5
            $0.turrets[slot].era = nil
        }
        return true
    }

    @discardableResult
    public func unlockSlot(for side: Side) -> Bool {
        let cost = slotUnlockCost(for: side)
        let s = state(side)
        guard winner == nil, !s.turrets[1].unlocked, s.food >= cost, !(side == .player && goal == .noTurrets) else { return false }
        mutate(side) {
            $0.food -= cost
            $0.turrets[1].unlocked = true
        }
        return true
    }

    @discardableResult
    public func useSpecial(_ side: Side) -> Bool {
        let s = state(side)
        guard winner == nil, s.specialCooldown <= 0 else { return false }
        let dmg = s.eraDef.special.damage * s.mods.specialDamage
        mutate(side) {
            $0.specialCooldown = $0.specialMaxCooldown
            $0.specialsUsed += 1
        }
        pendingSpecials.append((side, s.era, dmg, GameConfig.specialDelay))
        events.append(.specialLaunched(side: side, era: s.era))
        return true
    }

    public func drawCards(for side: Side, count: Int = 3) -> [Card] {
        Card.draw(count: count, owned: state(side).cards, rng: &rng, epicBoost: difficulty.isBoss ? 1.5 : 1)
    }

    public func applyCard(_ id: CardID, to side: Side) {
        mutate(side) { s in
            switch id {
            case .sharpTeeth: s.mods.roleDamage[UnitRole.melee.rawValue] *= 1.25
            case .eagleEye:
                s.mods.rangedRange *= 1.2
                s.mods.roleDamage[UnitRole.ranged.rawValue] *= 1.1
            case .thickFur: s.mods.unitHP *= 1.2
            case .chubbyCheeks: s.mods.income *= 1.3
            case .fastLearner: s.mods.xpGain *= 1.3
            case .fortify:
                let old = s.baseMaxHP
                s.mods.baseHP *= 1.25
                s.baseMaxHP *= 1.25
                s.baseHP = min(s.baseMaxHP, s.baseHP + (s.baseMaxHP - old) + 0.25 * s.baseMaxHP)
            case .turretGrease:
                s.mods.turretDamage *= 1.3
                s.mods.turretRate *= 1.15
            case .seedStash: s.food += 160 * GameConfig.costScale[s.era]
            case .hamsterWheel: s.mods.trainSpeed *= 1.3
            case .recruiter: s.mods.recruiterInterval = (s.mods.recruiterInterval ?? 14.3) * 0.7
            case .vampireBite: s.mods.lifestealOnKill += 0.2
            case .skyFury:
                s.mods.specialCooldown *= 0.7
                s.mods.specialDamage *= 1.3
                s.specialCooldown *= 0.7
            case .bargainBin: s.mods.unitCost *= 0.85
            case .berserk: s.mods.attackSpeed *= 1.25
            case .splashShot: s.mods.rangedSplash = 0.5
            case .lastStand: s.mods.hasLastStand = true
            case .giantGrowth:
                s.mods.roleHP[UnitRole.heavy.rawValue] *= 1.4
                s.mods.roleDamage[UnitRole.heavy.rawValue] *= 1.4
            case .warDrums:
                s.mods.unitDamage *= 1.15
                s.mods.moveSpeed *= 1.15
            case .shieldWall: s.mods.roleArmor[UnitRole.melee.rawValue] *= 0.8
            case .sniperNest:
                s.mods.turretRange *= 1.25
                s.mods.turretDamage *= 1.1
            case .scavenger: s.mods.killFood *= 1.4
            case .rapidFire: s.mods.roleAttackSpeed[UnitRole.ranged.rawValue] *= 1.3
            case .siegeBreaker: s.mods.baseDamage *= 1.5
            case .secondWind: s.mods.baseRegen += 0.005
            }
            s.cards.append(id)
        }
    }

    // MARK: Tick

    public func step(_ dt: Double) {
        guard winner == nil, !awaitingRevive else { return }
        let wasOvertime = isOvertime
        time += dt
        if let limit = goal.seconds, time >= limit {
            // Hold Out: surviving is winning. Beat the Clock: out of time is losing.
            let w: Side = goal == .holdOut ? .player : .enemy
            winner = w
            events.append(.gameOver(winner: w))
            return
        }
        if !wasOvertime && isOvertime { events.append(.overtimeStarted) }
        if mode.hasStageRules && time >= GameConfig.suddenDeathStart {
            if time - dt < GameConfig.suddenDeathStart { events.append(.suddenDeathStarted) }
            // The weaker base (by %) falls first; player is checked last so ties favor the player.
            for side in [Side.enemy, .player] where winner == nil && !awaitingRevive {
                damageBase(side, amount: state(side).baseMaxHP * GameConfig.suddenDeathRate * dt, by: side.opponent)
            }
        }
        for side in Side.allCases {
            updateEconomy(side, dt)
            updateTraining(side, dt)
            updateRecruiter(side, dt)
            updateTurrets(side, dt)
        }
        updateBoss(dt)
        updateSurvival(dt)
        updateUnits(dt)
        updateProjectiles(dt)
        updateSpecials(dt)
        units.removeAll { !$0.isAlive }
        for side in Side.allCases where winner == nil {
            controllers[side]?.update(sim: self, side: side, dt: dt)
        }
    }

    private func updateEconomy(_ side: Side, _ dt: Double) {
        mutate(side) { s in
            s.food += s.eraDef.income * s.mods.income * dt
            s.xp += GameConfig.passiveXPPerSecond * GameConfig.costScale[s.era] * s.mods.xpGain * dt
            s.specialCooldown = max(0, s.specialCooldown - dt)
            s.chargeTimer = max(0, s.chargeTimer - dt)
            if s.mods.baseRegen > 0 && s.baseHP > 0 {
                s.baseHP = min(s.baseMaxHP, s.baseHP + s.baseMaxHP * s.mods.baseRegen * dt)
            }
            s.overclockTimer = max(0, s.overclockTimer - dt)
        }
    }

    private func spawnClear(_ side: Side, width: Double) -> Bool {
        let x = BattleSimulation.spawnX(side, width: width)
        return !units.contains { $0.side == side && $0.isAlive && abs($0.x - x) < ($0.width + width) / 2 + 2 }
    }

    private func spawn(_ role: UnitRole, era: Int, side: Side, boss: Bool = false, trait: RatTrait? = nil) {
        let stats = GameConfig.eras[era].unit(role)
        let u = UnitEntity(id: nextID, side: side, role: role, era: era,
                           x: BattleSimulation.spawnX(side, width: stats.width * (boss ? 1.4 : 1)),
                           stats: stats, mods: state(side).mods, boss: boss, trait: trait)
        nextID += 1
        units.append(u)
        if boss {
            events.append(.bossSpawned(unitID: u.id))
        } else {
            mutate(side) { $0.unitsTrained += 1 }
        }
        events.append(.spawned(unitID: u.id))
        if let t = u.trait { events.append(.eliteSpawned(unitID: u.id, trait: t)) }
    }

    /// Rolls an elite trait for a freshly trained rat.
    private func rollTrait(_ side: Side, role: UnitRole) -> RatTrait? {
        guard side == .enemy else { return nil }
        let pool = eliteOdds.pool.filter { $0.fits(role) }
        guard !pool.isEmpty, Double.random(in: 0..<1, using: &rng) < eliteOdds.chance else { return nil }
        return pool.randomElement(using: &rng)
    }

    /// Rat Medic: periodically heals the most hurt ally in reach.
    private func updateMedic(_ u: UnitEntity, _ dt: Double) {
        u.healCooldown -= dt
        guard u.healCooldown <= 0 else { return }
        let patient = units.filter {
            $0.side == u.side && $0.isAlive && $0 !== u && $0.hp < $0.maxHP && abs($0.x - u.x) <= RatTrait.medicRange
        }.min { $0.hp / $0.maxHP < $1.hp / $1.maxHP }
        guard let p = patient else { u.healCooldown = 0.3; return }
        let amount = min(p.maxHP - p.hp, p.maxHP * RatTrait.medicHeal)
        p.hp += amount
        u.healCooldown = RatTrait.medicInterval
        events.append(.healed(unitID: p.id, by: u.id, amount: amount))
    }

    /// Three royal guards drop in just behind the hurt king.
    private func summonGuard(for king: UnitEntity) {
        let stats = GameConfig.eras[king.era].unit(.melee)
        for k in 0..<GameConfig.bossGuards {
            let x = king.x - king.side.direction * (king.width / 2 + 18 + Double(k) * (stats.width + GameConfig.unitSpacing))
            let u = UnitEntity(id: nextID, side: king.side, role: .melee, era: king.era, x: x,
                               stats: stats, mods: state(king.side).mods)
            u.cooldown = 0.8
            nextID += 1
            units.append(u)
            events.append(.spawned(unitID: u.id))
        }
        events.append(.bossSummon(unitID: king.id))
    }

    /// A Plague Rat bursts into two small rats where it fell.
    private func spawnMinions(from dead: UnitEntity) {
        let stats = GameConfig.eras[dead.era].unit(.melee)
        for k in 0..<2 {
            let x = dead.x - dead.side.direction * Double(k) * 14
            let u = UnitEntity(id: nextID, side: dead.side, role: .melee, era: dead.era, x: x,
                               stats: stats, mods: state(dead.side).mods, minion: true)
            u.cooldown = 0.5
            nextID += 1
            units.append(u)
            events.append(.spawned(unitID: u.id))
        }
    }

    /// Survival: every interval the rats get stronger and richer.
    private func updateSurvival(_ dt: Double) {
        guard mode == .survival else { return }
        survivalTimer -= dt
        guard survivalTimer <= 0 else { return }
        survivalTimer = GameConfig.survivalRampInterval
        survivalWave += 1
        let k = GameConfig.survivalRamp
        mutate(.enemy) {
            $0.mods.unitHP *= k
            $0.mods.unitDamage *= k
            $0.mods.income *= k
        }
        events.append(.waveUp(level: survivalWave))
    }

    /// Boss stages: one Rat King at a time, first at 0:45 then every 1:40.
    private func updateBoss(_ dt: Double) {
        guard difficulty.isBoss || mode == .survival else { return }
        // The next Rat King's timer only runs while no king is on the field.
        if units.contains(where: { $0.isBoss && $0.isAlive }) { return }
        bossTimer -= dt
        guard bossTimer <= 0 else { return }
        let width = GameConfig.eras[state(.enemy).era].unit(.heavy).width * 1.4
        if !units.contains(where: { $0.isBoss && $0.isAlive }), spawnClear(.enemy, width: width) {
            spawn(.heavy, era: state(.enemy).era, side: .enemy, boss: true)
            bossTimer = GameConfig.bossInterval
        }
    }

    private func updateTraining(_ side: Side, _ dt: Double) {
        let s = state(side)
        guard let q = s.queue.first else { return }
        let stats = GameConfig.eras[q.era].unit(q.role)
        let progress = min(stats.trainTime, s.trainProgress + dt * s.mods.trainSpeed)
        mutate(side) { $0.trainProgress = progress }
        if progress >= stats.trainTime, spawnClear(side, width: stats.width) {
            mutate(side) {
                $0.queue.removeFirst()
                $0.trainProgress = 0
            }
            spawn(q.role, era: q.era, side: side, trait: rollTrait(side, role: q.role))
        }
    }

    private func updateRecruiter(_ side: Side, _ dt: Double) {
        guard let interval = state(side).mods.recruiterInterval else { return }
        mutate(side) { $0.recruiterTimer += dt }
        let era = state(side).era
        if state(side).recruiterTimer >= interval,
           spawnClear(side, width: GameConfig.eras[era].unit(.melee).width) {
            mutate(side) { $0.recruiterTimer = 0 }
            spawn(.melee, era: era, side: side)
        }
    }

    /// The opponent unit that is furthest advanced toward `side`'s base... i.e. the first one `side` meets.
    public func frontUnit(of side: Side) -> UnitEntity? {
        var best: UnitEntity?
        for u in units where u.side == side && u.isAlive {
            if best == nil || u.x * side.direction > best!.x * side.direction { best = u }
        }
        return best
    }

    private func updateTurrets(_ side: Side, _ dt: Double) {
        guard !isOvertime else { return }
        let s = state(side)
        let front = BattleSimulation.baseFront(side)
        for slot in s.turrets.indices {
            guard let era = s.turrets[slot].era else { continue }
            let t = GameConfig.eras[era].turret
            let cd = s.turrets[slot].cooldown - dt * s.mods.turretRate
            mutate(side) { $0.turrets[slot].cooldown = max(0, cd) }
            guard cd <= 0, let target = frontUnit(of: side.opponent) else { continue }
            let dist = (target.x - front) * side.direction - target.width / 2
            guard dist <= t.range * s.mods.turretRange else { continue }
            let p = Projectile(id: nextID, side: side, era: era, fromTurret: true, isHeavy: false,
                               startX: front - side.direction * 22, x: front - side.direction * 22,
                               targetID: target.id, targetX: target.x, speed: t.projectileSpeed,
                               damage: t.damage * s.mods.turretDamage, splash: t.splash, splashFactor: 0.6,
                               sourceID: nil)
            nextID += 1
            projectiles.append(p)
            mutate(side) { $0.turrets[slot].cooldown = t.interval }
            events.append(.turretFired(side: side, slot: slot))
            events.append(.projectileFired(id: p.id))
        }
    }

    private func updateUnits(_ dt: Double) {
        for side in Side.allCases {
            let dir = side.direction
            let enemyBaseFront = BattleSimulation.baseFront(side.opponent)
            let stance = state(side).stance
            // Stance line: units don't walk past it (Hold) or walk back to it (Fall back).
            let line = stance.line.map { BattleSimulation.baseFront(side) + dir * $0 }
            let haste = state(side).overclockTimer > 0 ? 1.5 : 1.0
            let own = units.filter { $0.side == side && $0.isAlive }.sorted { $0.x * dir > $1.x * dir }
            var ahead: UnitEntity?
            for u in own where u.isAlive {
                u.cooldown -= dt
                defer { ahead = u }
                if u.isBoss && updateBossSlam(u, dt) { continue }
                if u.trait == .medic { updateMedic(u, dt) }

                if stance == .fallBack, let line, (u.x - line) * dir > 0.5 {
                    // Disengage and walk home; slightly slower than the advance so it's a real choice.
                    u.isRetreating = true
                    u.isMoving = true
                    var newX = u.x - dir * u.speed * 0.9 * haste * dt
                    if (newX - line) * dir < 0 { newX = line }
                    u.x = newX
                    continue
                }
                u.isRetreating = false

                let foe = frontUnit(of: side.opponent)
                let baseDist = (enemyBaseFront - u.x) * dir - u.width / 2
                var targetUnit: UnitEntity?
                var dist = baseDist
                if let f = foe {
                    let d = (f.x - u.x) * dir - (f.width + u.width) / 2
                    if d <= baseDist { targetUnit = f; dist = d }
                }
                if dist <= u.range {
                    u.isMoving = false
                    if u.cooldown <= 0 {
                        attack(u, target: targetUnit)
                        u.cooldown = u.attackInterval / haste
                    }
                } else {
                    var newX = u.x + dir * u.speed * haste * dt
                    func clamp(_ limit: Double) {
                        if (newX - limit) * dir > 0 { newX = (u.x - limit) * dir > 0 ? u.x : limit }
                    }
                    if let a = ahead { clamp(a.x - dir * ((a.width + u.width) / 2 + GameConfig.unitSpacing)) }
                    if let f = foe { clamp(f.x - dir * ((f.width + u.width) / 2)) }
                    clamp(enemyBaseFront - dir * u.width / 2)
                    if let line { clamp(line) }
                    u.isMoving = abs(newX - u.x) > 0.0001
                    u.x = newX
                }
            }
        }
    }

    /// Rat King ground slam: a telegraphed wind-up, then heavy damage to everything in front of it.
    /// Returns true while the king is busy (winding up), so it neither moves nor attacks.
    private func updateBossSlam(_ u: UnitEntity, _ dt: Double) -> Bool {
        let dir = u.side.direction
        let radius = GameConfig.bossSlamRadius + u.width / 2
        if u.windup > 0 {
            u.windup -= dt
            u.isMoving = false
            if u.windup <= 0 {
                u.windup = 0
                events.append(.bossSlam(unitID: u.id, x: u.x, radius: radius))
                let dmg = u.damage * GameConfig.bossSlamDamage * overtimeFactor
                for t in units where t.side == u.side.opponent && t.isAlive
                    && (t.x - u.x) * dir > -u.width / 2 && (t.x - u.x) * dir - t.width / 2 <= radius {
                    damage(t, amount: dmg, by: u.side, sourceID: u.id, kind: .heavy)
                }
                u.cooldown = max(u.cooldown, 0.6)
            }
            return true
        }
        u.slamCooldown -= dt
        guard u.slamCooldown <= 0 else { return false }
        let victims = units.filter {
            $0.side == u.side.opponent && $0.isAlive && ($0.x - u.x) * dir > 0 && ($0.x - u.x) * dir - $0.width / 2 <= radius
        }
        guard victims.count >= 2 || victims.contains(where: { $0.role == .heavy }) else { return false }
        u.windup = GameConfig.bossSlamWindup
        u.slamCooldown = GameConfig.bossSlamInterval
        u.isMoving = false
        events.append(.bossWindup(unitID: u.id, x: u.x, radius: radius))
        return true
    }

    private func attack(_ u: UnitEntity, target: UnitEntity?) {
        events.append(.attacked(unitID: u.id))
        let charge = u.role == .melee && state(u.side).chargeTimer > 0 ? 1.5 : 1.0
        if u.isRanged {
            let mods = state(u.side).mods
            let startX = u.x + u.side.direction * u.width / 2
            let p = Projectile(id: nextID, side: u.side, era: u.era, fromTurret: false, isHeavy: u.role == .heavy,
                               startX: startX, x: startX,
                               targetID: target?.id,
                               targetX: target?.x ?? BattleSimulation.baseFront(u.side.opponent),
                               speed: u.projectileSpeed,
                               damage: u.damage * overtimeFactor * charge * (target == nil ? mods.baseDamage : 1),
                               splash: u.role == .heavy ? 40 : (mods.rangedSplash > 0 ? 45 : 0),
                               splashFactor: u.role == .heavy ? 0.5 : mods.rangedSplash,
                               sourceID: u.id)
            nextID += 1
            projectiles.append(p)
            events.append(.projectileFired(id: p.id))
        } else if let t = target {
            damage(t, amount: u.damage * overtimeFactor * charge, by: u.side, sourceID: u.id,
                   kind: u.role == .heavy ? .heavy : .melee)
        } else {
            damageBase(u.side.opponent, amount: u.damage * overtimeFactor * charge * state(u.side).mods.baseDamage, by: u.side)
        }
    }

    private func unit(_ id: Int?) -> UnitEntity? {
        guard let id else { return nil }
        return units.first { $0.id == id && $0.isAlive }
    }

    private func updateProjectiles(_ dt: Double) {
        var keep: [Projectile] = []
        for var p in projectiles {
            if let t = unit(p.targetID) { p.targetX = t.x }
            let dir = p.targetX >= p.x ? 1.0 : -1.0
            let stepDist = p.speed * dt
            if abs(p.targetX - p.x) <= stepDist {
                p.x = p.targetX
                resolveImpact(p)
                events.append(.projectileImpact(id: p.id, x: p.x))
            } else {
                p.x += dir * stepDist
                keep.append(p)
            }
        }
        projectiles = keep
    }

    private func resolveImpact(_ p: Projectile) {
        if p.targetID == nil {
            damageBase(p.side.opponent, amount: p.damage, by: p.side)
            return
        }
        // Target may have died in flight: hit whatever foe is right there instead.
        let primary = unit(p.targetID) ?? units.first {
            $0.side == p.side.opponent && $0.isAlive && abs($0.x - p.x) < $0.width / 2 + 10
        }
        // Cannonballs, shells and turret blasts crack armor; arrows and bullets don't.
        let kind: DamageKind = p.isHeavy || (p.fromTurret && p.splash > 0) ? .heavy : .pierce
        if let primary { damage(primary, amount: p.damage, by: p.side, sourceID: p.sourceID, kind: kind) }
        if p.splash > 0 {
            for u in units where u.side == p.side.opponent && u.isAlive && u !== primary
                && abs(u.x - p.x) <= p.splash {
                damage(u, amount: p.damage * p.splashFactor, by: p.side, sourceID: p.sourceID, kind: kind)
            }
        }
    }

    private func updateSpecials(_ dt: Double) {
        guard !pendingSpecials.isEmpty else { return }
        var keep: [(side: Side, era: Int, damage: Double, timeLeft: Double)] = []
        for var s in pendingSpecials {
            s.timeLeft -= dt
            if s.timeLeft <= 0 {
                events.append(.specialImpact(side: s.side, era: s.era))
                for u in units where u.side == s.side.opponent && u.isAlive {
                    damage(u, amount: s.damage, by: s.side, sourceID: nil, kind: .special)
                }
            } else {
                keep.append(s)
            }
        }
        pendingSpecials = keep
    }

    private func damage(_ target: UnitEntity, amount: Double, by attacker: Side, sourceID: Int?, kind: DamageKind) {
        guard target.isAlive else { return }
        if target.shield > 0 {
            if kind == .special {
                target.shield = 0                     // specials pop the bubble and still hurt
                events.append(.shieldHit(unitID: target.id, left: 0))
            } else {
                target.shield -= 1
                events.append(.shieldHit(unitID: target.id, left: target.shield))
                return
            }
        }
        var dealt = amount * target.armor
        if target.trait == .armored {
            if kind == .pierce {
                dealt *= GameConfig.armoredPierceFactor
                events.append(.counterHit(unitID: target.id, effective: false))
            } else if kind == .heavy {
                dealt *= GameConfig.armoredHeavyFactor
                events.append(.counterHit(unitID: target.id, effective: true))
            }
        }
        target.hp -= dealt
        events.append(.unitHit(unitID: target.id, damage: dealt))
        if target.isBoss && target.isAlive && !target.summoned && target.hp < target.maxHP * 0.5 {
            target.summoned = true
            summonGuard(for: target)
        }
        guard !target.isAlive else { return }

        events.append(.died(unitID: target.id, x: target.x, side: target.side, era: target.era, role: target.role))
        let food = target.cost * GameConfig.killFoodMultiplier * state(attacker).mods.killFood
        let xp = target.cost * GameConfig.killXPMultiplier
        mutate(attacker) {
            $0.food += food
            $0.xp += xp * $0.mods.xpGain
            $0.kills += 1
            if target.isBoss { $0.bossesKilled += 1 }
        }
        mutate(target.side) { $0.xp += xp * GameConfig.lossXPShare * $0.mods.xpGain }
        events.append(.reward(side: attacker, food: food, x: target.x))
        if target.trait == .plague { spawnMinions(from: target) }
        let steal = state(attacker).mods.lifestealOnKill
        if steal > 0, let killer = unit(sourceID) {
            killer.hp = min(killer.maxHP, killer.hp + killer.maxHP * steal)
        }
    }

    private func damageBase(_ victim: Side, amount: Double, by attacker: Side) {
        guard winner == nil else { return }
        if mode == .survival && victim == .enemy {
            // The rat fortress can't fall in Survival — damage only counts toward the score.
            mutate(attacker) { $0.damageToEnemyBase += amount }
            events.append(.baseHit(side: victim, damage: amount))
            return
        }
        mutate(victim) { $0.baseHP -= amount }
        mutate(attacker) { $0.damageToEnemyBase += amount }
        events.append(.baseHit(side: victim, damage: amount))
        let s = state(victim)
        if s.baseHP <= 0 {
            if s.mods.hasLastStand && !s.lastStandUsed {
                mutate(victim) {
                    $0.lastStandUsed = true
                    $0.baseHP = $0.baseMaxHP * 0.4
                }
                events.append(.lastStand(side: victim))
            } else if victim == .player && reviveEnabled && !reviveUsed {
                mutate(victim) { $0.baseHP = 0 }
                awaitingRevive = true
                events.append(.reviveOffered)
            } else {
                mutate(victim) { $0.baseHP = 0 }
                winner = attacker
                events.append(.gameOver(winner: attacker))
            }
        }
    }

    // MARK: Hero abilities

    public func setHeroAbility(_ ability: HeroAbility?, for side: Side) {
        mutate(side) { $0.heroAbility = ability }
    }

    @discardableResult
    public func useHeroAbility(_ side: Side) -> Bool {
        let s = state(side)
        guard winner == nil, !awaitingRevive, let ability = s.heroAbility, !s.heroUsed else { return false }
        mutate(side) { $0.heroUsed = true }
        switch ability {
        case .charge:
            mutate(side) { $0.chargeTimer = HeroAbility.chargeDuration }
        case .overclock:
            mutate(side) { $0.overclockTimer = HeroAbility.overclockDuration }
        case .volley:
            let dmg = s.eraDef.special.damage * s.mods.specialDamage * 0.6
            for u in units where u.side == side.opponent && u.isAlive { damage(u, amount: dmg, by: side, sourceID: nil, kind: .special) }
        case .picnic:
            mutate(side) { $0.food += $0.eraDef.income * $0.mods.income * 30 }
        case .eureka:
            mutate(side) { st in
                let need = st.eraDef.xpToEvolve ?? 0
                let prev = st.era == 0 ? 0 : (GameConfig.eras[st.era - 1].xpToEvolve ?? 0)
                if need > 0 { st.xp += (need - prev) * 0.35 } else { st.food += st.eraDef.income * st.mods.income * 30 }
            }
        case .bulwark:
            for u in units where u.side == side && u.isAlive { u.hp = min(u.maxHP, u.hp + u.maxHP * 0.5) }
            mutate(side) { $0.baseHP = min($0.baseMaxHP, $0.baseHP + $0.baseMaxHP * 0.15) }
        case .royalDecree:
            let era = s.era
            for k in 0..<3 {
                spawn(.melee, era: era, side: side)
                if let u = units.last { u.x -= side.direction * Double(k) * (u.width + GameConfig.unitSpacing) }
            }
        case .bigBang:
            mutate(side) { $0.specialCooldown = 0 }
        }
        events.append(.heroAbility(side: side, ability: ability))
        return true
    }

    // MARK: Revive

    /// Restores the player's base to 40% and blasts the rats crowding it, once per battle.
    public func acceptRevive() {
        guard awaitingRevive else { return }
        awaitingRevive = false
        reviveUsed = true
        mutate(.player) { $0.baseHP = $0.baseMaxHP * 0.4 }
        let front = BattleSimulation.baseFront(.player)
        for u in units where u.side == .enemy && u.isAlive && u.x - front < 260 {
            damage(u, amount: u.maxHP * (u.isBoss ? 0.35 : 1.0), by: .player, sourceID: nil, kind: .special)
        }
        events.append(.specialImpact(side: .player, era: state(.player).era))
    }

    public func declineRevive() {
        guard awaitingRevive else { return }
        awaitingRevive = false
        winner = .enemy
        events.append(.gameOver(winner: .enemy))
    }

    // MARK: Results

    /// 0...1 share of the enemy base destroyed by the player (used for loss rewards).
    public var enemyBaseDamageFraction: Double {
        let e = state(.enemy)
        return min(1, max(0, 1 - e.baseHP / e.baseMaxHP))
    }
}
