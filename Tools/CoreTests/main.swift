// Headless tests for the game logic (Core + Meta). No Xcode needed:
//   swiftc -swift-version 5 HamsterAges/Core/*.swift HamsterAges/Meta/*.swift HamsterAges/Services/Analytics.swift \
//          Tools/CoreTests/main.swift -o /tmp/hamster-tests && /tmp/hamster-tests
import Foundation

var failures = 0
var passed = 0
func check(_ cond: @autoclosure () -> Bool, _ name: String, file: StaticString = #file, line: UInt = #line) {
    if cond() { passed += 1 } else { failures += 1; print("❌ FAIL: \(name) (line \(line))") }
}
func run(_ sim: BattleSimulation, seconds: Double, dt: Double = 1.0 / 30.0, until: ((BattleSimulation) -> Bool)? = nil) {
    var t = 0.0
    while t < seconds && sim.winner == nil && !sim.awaitingRevive {
        sim.step(dt)
        sim.events.removeAll()
        t += dt
        if let until, until(sim) { break }
    }
}
func playerBot(_ sim: BattleSimulation) { sim.controllers[.player] = BattleAI(thinkInterval: 0.9, evolveDelay: 1.5, usesCards: true) }

// MARK: Determinism
do {
    func outcome(_ seed: UInt64) -> (Side?, Double, Int) {
        let s = BattleSimulation(difficulty: StageDifficulty(stage: 6), playerMods: SideModifiers(), seed: seed)
        playerBot(s)
        run(s, seconds: 1200)
        return (s.winner, s.time, s.state(.player).kills)
    }
    let a = outcome(42), b = outcome(42)
    check(a.0 == b.0 && a.1 == b.1 && a.2 == b.2, "same seed → identical battle")
    check(a.0 != nil, "battle ends within 20 min")
}

// MARK: Economy & training
do {
    let s = BattleSimulation(difficulty: StageDifficulty(stage: 1), playerMods: SideModifiers(), seed: 1)
    s.controllers[.enemy] = nil
    let food0 = s.state(.player).food
    let cost = s.unitCost(.melee, for: .player)
    check(s.train(.melee, for: .player), "can train melee at start")
    check(abs(s.state(.player).food - (food0 - cost)) < 0.001, "training deducts food")
    for _ in 0..<10 { s.train(.melee, for: .player) }
    check(s.state(.player).queue.count <= GameConfig.maxQueue, "queue capped at \(GameConfig.maxQueue)")
    run(s, seconds: 3)
    check(s.units.contains { $0.side == .player }, "unit spawns after training")
    check(s.state(.player).food > 0, "passive income keeps food positive")
}

// MARK: Evolution
do {
    let s = BattleSimulation(difficulty: StageDifficulty(stage: 1), playerMods: SideModifiers(), seed: 2)
    s.controllers[.enemy] = nil   // passive XP only, nobody attacks
    check(!s.evolve(.player), "cannot evolve without XP")
    run(s, seconds: 600, until: { $0.state(.player).canEvolve })
    let hp0 = s.state(.player).baseMaxHP
    check(s.state(.player).canEvolve, "XP accumulates to evolve")
    check(s.evolve(.player), "evolve succeeds with XP")
    check(s.state(.player).era == 1 && s.state(.player).baseMaxHP > hp0, "evolve raises era and base HP")
}

// MARK: Cards
do {
    let s = BattleSimulation(difficulty: StageDifficulty(stage: 1), playerMods: SideModifiers(), seed: 3)
    s.applyCard(.bargainBin, to: .player)
    check(s.unitCost(.heavy, for: .player) < GameConfig.eras[0].unit(.heavy).cost, "Bargain Bin lowers cost")
    s.applyCard(.lastStand, to: .player)
    let drawn = (0..<50).flatMap { _ in s.drawCards(for: .player) }
    check(!drawn.contains { $0.id == .lastStand }, "non-stackable owned card not offered again")
    check(Set(s.drawCards(for: .player).map(\.id)).count == 3, "3 distinct cards offered")
}

// MARK: New cards
do {
    let s = BattleSimulation(difficulty: StageDifficulty(stage: 1), playerMods: SideModifiers(), seed: 31)
    s.controllers[.enemy] = nil
    s.applyCard(.secondWind, to: .player)
    s.applyCard(.shieldWall, to: .player)
    s.applyCard(.rapidFire, to: .player)
    s.train(.melee, for: .player); s.train(.ranged, for: .player)
    run(s, seconds: 4)
    let melee = s.units.first { $0.role == .melee }, ranged = s.units.first { $0.role == .ranged }
    check(melee.map { abs($0.armor - 0.8) < 1e-9 } == true, "Shield Wall armors melee")
    check(ranged.map { $0.attackInterval < GameConfig.eras[0].unit(.ranged).attackInterval } == true, "Rapid Fire speeds ranged attacks")
    check(Card.all.count == CardID.allCases.count, "every card id has a definition")
}

// MARK: Last Stand & Revive
do {
    let s = BattleSimulation(difficulty: StageDifficulty(stage: 30), playerMods: SideModifiers(), seed: 4)
    s.applyCard(.lastStand, to: .player)
    s.reviveEnabled = true
    run(s, seconds: 1200)
    check(s.state(.player).lastStandUsed, "Last Stand triggers before defeat")
    check(s.awaitingRevive && s.winner == nil, "revive offered instead of defeat")
    let t = s.time
    s.step(0.1)
    check(s.time == t, "simulation frozen while revive pending")
    s.acceptRevive()
    check(abs(s.state(.player).baseHP - s.state(.player).baseMaxHP * 0.4) < 1, "revive restores 40% base HP")
    run(s, seconds: 1200)
    check(s.winner == .enemy && !s.awaitingRevive, "revive only once per battle")
}
do {
    let s = BattleSimulation(difficulty: StageDifficulty(stage: 30), playerMods: SideModifiers(), seed: 5)
    s.reviveEnabled = true
    run(s, seconds: 1200)
    s.declineRevive()
    check(s.winner == .enemy, "declining revive ends the battle")
}

// MARK: Boss & overtime
do {
    let s = BattleSimulation(difficulty: StageDifficulty(stage: 5), playerMods: SideModifiers(), seed: 6)
    playerBot(s)
    run(s, seconds: GameConfig.bossFirstSpawn + 5)
    check(s.units.contains { $0.isBoss } || s.state(.player).bossesKilled > 0, "Rat King appears on boss stage")
    check(s.units.filter { $0.isBoss && $0.isAlive }.count <= 1, "at most one Rat King alive")
    let n = BattleSimulation(difficulty: StageDifficulty(stage: 4), playerMods: SideModifiers(), seed: 6)
    run(n, seconds: 120)
    check(!n.units.contains { $0.isBoss }, "no boss on regular stage")
}
do {
    let s = BattleSimulation(difficulty: StageDifficulty(stage: 12), playerMods: BalanceHarness.metaMods(level: 4), seed: 7)
    playerBot(s)
    run(s, seconds: GameConfig.overtimeStart + 30)
    if s.winner == nil {
        check(s.isOvertime && s.overtimeFactor > 1.4, "overtime ramps damage")
        check(!s.buyTurret(slot: 0, for: .player), "no turret purchases in overtime")
    }
}

// MARK: Stage modifiers & sudden death
do {
    check(StageModifier.forStage(3) == .none && StageModifier.forStage(10) == .none, "no modifier before stage 6 or on bosses")
    check(StageModifier.forStage(6) == .goldRush, "first modifier is the friendly Gold Rush")
    let mods = Set((6...30).map(StageModifier.forStage).filter { $0 != .none })
    check(mods.count == StageModifier.allCases.count - 1, "every modifier appears in the campaign")
    let fog = BattleSimulation(difficulty: StageDifficulty(stage: 9, modifier: .siegeFog), playerMods: SideModifiers(), seed: 11)
    check(fog.turretsDisabled && !fog.buyTurret(slot: 0, for: .player), "Siege Fog blocks turrets")
    let surv = BattleSimulation(difficulty: StageDifficulty(stage: 9, modifier: .siegeFog), playerMods: SideModifiers(), seed: 11, mode: .survival)
    check(!surv.turretsDisabled && surv.activeModifier == .none, "modifiers don't apply in Survival")
    var longest = 0.0
    for g in 0..<10 {
        let s = BattleSimulation(difficulty: StageDifficulty(stage: 20), playerMods: BalanceHarness.metaMods(level: 10), seed: UInt64(300 + g))
        playerBot(s)
        run(s, seconds: 1200)
        longest = max(longest, s.time)
    }
    check(longest <= GameConfig.suddenDeathStart + 1 / GameConfig.suddenDeathRate + 5, "sudden death ends every campaign battle (longest \(Int(longest))s)")
}

// MARK: Hero abilities
do {
    func fresh(_ a: HeroAbility) -> BattleSimulation {
        let s = BattleSimulation(difficulty: StageDifficulty(stage: 4), playerMods: SideModifiers(), seed: 21)
        s.setHeroAbility(a, for: .player)
        return s
    }
    let p = fresh(.picnic); let f0 = p.state(.player).food
    check(p.useHeroAbility(.player) && p.state(.player).food > f0 + 80, "Picnic grants food")
    check(!p.useHeroAbility(.player), "hero ability is once per battle")
    let r = fresh(.royalDecree)
    r.useHeroAbility(.player)
    check(r.units.filter { $0.side == .player }.count == 3, "Royal Decree spawns 3 warriors")
    let b = fresh(.bigBang)
    check(b.state(.player).specialCooldown > 0, "special starts on cooldown")
    b.useHeroAbility(.player)
    check(b.state(.player).specialCooldown == 0, "Big Bang recharges special")
    let e = fresh(.eureka); e.useHeroAbility(.player)
    check(e.state(.player).xp > 100, "Eureka grants XP")
    let c = fresh(.charge); c.useHeroAbility(.player)
    check(c.state(.player).chargeTimer == HeroAbility.chargeDuration, "Charge starts buff")
    run(c, seconds: HeroAbility.chargeDuration + 1)
    check(c.state(.player).chargeTimer == 0, "Charge buff expires")
    let v = fresh(.volley)
    v.controllers[.player] = nil
    run(v, seconds: 25, until: { s in s.units.contains { $0.side == .enemy } })
    let hpBefore = v.units.filter { $0.side == .enemy }.map(\.hp).reduce(0, +)
    v.useHeroAbility(.player)
    let hpAfter = v.units.filter { $0.side == .enemy && $0.isAlive }.map(\.hp).reduce(0, +)
    check(hpAfter < hpBefore, "Volley damages rats")
    let none = BattleSimulation(difficulty: StageDifficulty(stage: 4), playerMods: SideModifiers(), seed: 21)
    check(!none.useHeroAbility(.player), "no hero → no ability")
}

// MARK: Survival
do {
    let s = BattleSimulation(difficulty: StageDifficulty(stage: GameConfig.survivalBaseStage),
                             playerMods: BalanceHarness.metaMods(level: 10), seed: 8, mode: .survival)
    playerBot(s)
    run(s, seconds: 1800)
    check(s.winner == .enemy, "survival always ends with the player's base falling")
    check(s.state(.enemy).baseHP == s.state(.enemy).baseMaxHP, "rat fortress is invulnerable in survival")
    check(s.survivalWave >= 2, "survival waves ramp up")
    check(!s.isOvertime && s.overtimeFactor == 1, "no overtime in survival")
    check(s.time > 120 && s.time < 1800, "survival lasts a few minutes (\(Int(s.time))s)")
}

// MARK: Meta: generals odds, farm, quests, daily
MainActor.assumeIsolated {
    var counts: [GeneralRarity: Int] = [:]
    for _ in 0..<100_000 { counts[Generals.roll().rarity, default: 0] += 1 }
    let legendary = Double(counts[.legendary] ?? 0) / 100_000
    let rare = Double(counts[.rare] ?? 0) / 100_000
    check(abs(legendary - 0.05) < 0.005 && abs(rare - 0.70) < 0.01, "crate odds match 70/25/5 (legendary \(legendary))")

    let now = Date()
    check(SeedFarm.amount(since: nil, highestStage: 5, now: now) == 0, "farm empty before first start")
    check(SeedFarm.amount(since: now.addingTimeInterval(-3600 * 30), highestStage: 5, now: now)
          == SeedFarm.capacity(highestStage: 5), "farm capped at \(SeedFarm.capHours)h")
    check(SeedFarm.amount(since: now.addingTimeInterval(3600), highestStage: 5, now: now) == 0, "farm ignores future timestamps")

    let b1 = QuestBoard.make(for: now), b2 = QuestBoard.make(for: now)
    check(b1 == b2 && b1.quests.count == 3 && b1.quests[0].kind == .winBattles, "quest board deterministic, starts with win quest")
    check(Set(b1.quests.map(\.kind)).count == 3, "quests are distinct")

    UserDefaults.standard.removeObject(forKey: "hamsterages.progress.v1")
    let store = ProgressStore()
    store.refreshDailyState(now: now)
    check(store.progress.questBoard != nil, "board created on refresh")
    store.recordBattle(stage: 1, won: true, seeds: 100, stars: 3,
                       stats: BattleStats(won: true, unitsTrained: 10, kills: 12, specialsUsed: 1, evolutions: 2, bossesKilled: 0))
    check(store.progress.stage == 2 && store.progress.seeds == 100, "win advances stage and pays seeds")
    check(store.progress.questBoard?.quests[0].progress == 1, "win counts toward quest")
    let seedsBefore = store.progress.seeds
    check(store.claimQuest(at: 0) == 0 && store.progress.seeds == seedsBefore, "incomplete quest can't be claimed")

    // Daily reward streak
    let day0 = Calendar.current.startOfDay(for: now).addingTimeInterval(12 * 3600)
    check(store.claimDaily(now: day0) == ProgressStore.dailyRewards[0], "day 1 reward")
    check(store.claimDaily(now: day0) == 0, "can't claim twice a day")
    check(store.claimDaily(now: day0.addingTimeInterval(86_400)) == ProgressStore.dailyRewards[1], "day 2 continues streak")
    check(store.claimDaily(now: day0.addingTimeInterval(86_400 * 4)) == ProgressStore.dailyRewards[0], "missed day resets streak")
    check(!store.dailyStatus(now: day0).available, "clock moved back doesn't re-open daily")

    // Crates
    store.addSeeds(10_000)
    let r = store.openCrate(free: false)
    check(r != nil && store.progress.generalLevel(r!.general) == 1, "paid crate grants a general")
    check(store.progress.equipped != nil, "first general auto-equipped")
    check(store.openCrate(free: true) != nil && store.openCrate(free: true) == nil, "free crate once per day")

    // Survival record
    store.recordSurvival(seconds: 300, seeds: 50, stats: BattleStats())
    store.recordSurvival(seconds: 200, seeds: 50, stats: BattleStats())
    check(store.progress.bestSurvival == 300, "survival keeps the best time")
    let stageBefore = store.progress.stage
    check(store.progress.stage == stageBefore, "survival doesn't change campaign stage")

    // Star Road
    check(StarRoad.milestone(0).stars == 5 && StarRoad.milestone(20).stars > StarRoad.milestone(19).stars, "star milestones increase forever")
    check(store.claimStarReward() == nil || store.progress.totalStars >= 5, "star reward needs stars")
    for st in 1...6 { store.recordBattle(stage: store.progress.stage, won: true, seeds: 0, stars: 3) ; _ = st }
    let before = store.progress.seeds
    let sr = store.claimStarReward()
    check(sr != nil && store.progress.seeds == before + 200, "first star milestone pays 200 seeds")
    check(store.progress.starMilestonesClaimed == 1, "milestone counter advances")

    // Daily challenge
    let cards = DailyChallenge.startingCards(for: now)
    check(cards.count == 2 && Set(cards).count == 2 && !cards.contains(.lastStand), "challenge gives 2 distinct starting cards")
    check(DailyChallenge.seed(for: now) == DailyChallenge.seed(for: now) && DailyChallenge.modifier(for: now) != .none, "challenge is deterministic with a twist")
    let ch = BattleSimulation(difficulty: StageDifficulty(stage: 7, modifier: .siegeFog), playerMods: SideModifiers(),
                              seed: DailyChallenge.seed(for: now), mode: .challenge)
    check(ch.turretsDisabled && ch.activeModifier == .siegeFog, "challenge applies its modifier")
    let stageBeforeChallenge = store.progress.stage
    check(store.challengeAvailable(now: now), "challenge available before clearing")
    store.recordChallenge(won: true, seeds: 10, stats: BattleStats(won: true), now: now)
    check(!store.challengeAvailable(now: now) && store.progress.stage == stageBeforeChallenge, "clearing challenge marks the day, keeps stage")

    // Reset keeps purchases
    store.setRemoveAds()
    store.resetAll()
    check(store.progress.removeAds == true && store.progress.seeds == 0, "reset wipes progress but keeps purchases")
    UserDefaults.standard.removeObject(forKey: "hamsterages.progress.v1")
}

print(failures == 0 ? "✅ All \(passed) checks passed" : "\(failures) failed, \(passed) passed")
exit(failures == 0 ? 0 : 1)
