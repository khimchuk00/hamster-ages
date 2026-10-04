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

// MARK: Hamster Pass & skins
MainActor.assumeIsolated {
    let e = HamsterPass.epoch
    check(HamsterPass.season(now: e.addingTimeInterval(60)) == 1 && HamsterPass.season(now: e.addingTimeInterval(28 * 86_400 + 60)) == 2,
          "pass seasons are 28 days")
    check(HamsterPass.season(now: e.addingTimeInterval(-86_400)) == 1, "dates before the epoch clamp to season 1")
    let now = e.addingTimeInterval(3 * 86_400)
    UserDefaults.standard.removeObject(forKey: "hamsterages.progress.v1")
    let store = ProgressStore()
    store.addPassXP(250, now: now)
    check(store.passTier == 2 && store.passXP == 250, "pass XP → tier")
    let seeds0 = store.progress.seeds
    let c1 = store.claimPass(tier: 1, premium: false, now: now)
    check(c1?.reward == .seeds(70) && store.progress.seeds == seeds0 + 70, "free tier 1 pays seeds")
    check(store.claimPass(tier: 1, premium: false, now: now) == nil, "a tier can't be claimed twice")
    check(store.claimPass(tier: 3, premium: false, now: now) == nil, "locked tiers can't be claimed")
    check(store.claimPass(tier: 1, premium: true, now: now) == nil, "premium track needs the pass")
    store.unlockPremiumPass(now: now)
    store.addPassXP(5000, now: now)
    check(store.passXP == HamsterPass.tiers * HamsterPass.xpPerTier, "pass XP caps at the last tier")
    let golden = store.claimPass(tier: 10, premium: true, now: now)
    check(golden?.reward == .skin(.golden) && store.progress.owns(.golden), "premium tier 10 unlocks the golden skin")
    let crate = store.claimPass(tier: 5, premium: false, now: now)
    check(crate?.crate != nil, "crate tiers open a crate")
    store.equipSkin(.golden)
    check(store.progress.skin == .golden, "skin equips")
    store.equipSkin(.midnight)
    check(store.progress.skin == .golden, "unowned skin can't be equipped")
    let next = e.addingTimeInterval(29 * 86_400)
    store.addPassXP(30, now: next)
    check(store.passXP == 30 && !store.hasPremiumPass(now: next) && store.progress.owns(.golden),
          "new season resets XP and premium, keeps skins")
    check(HamsterPass.premiumReward(tier: 20, season: 1) != HamsterPass.premiumReward(tier: 20, season: 2), "final skin rotates by season")
    store.resetAll()
    check(store.progress.owns(.golden) && store.progress.skin == .golden, "reset keeps cosmetics")
    UserDefaults.standard.removeObject(forKey: "hamsterages.progress.v1")
}

// MARK: Ads pacing, offers, free seeds, cloud merge
MainActor.assumeIsolated {
    let cfg = RemoteValues()
    let t0 = Date(timeIntervalSince1970: 2_000_000_000)
    func ok(_ b: Int, won: Bool = true, stage: Int = 10, last: Date? = nil, rew: Date? = nil, removeAds: Bool = false) -> Bool {
        AdRules.shouldShowInterstitial(battlesPlayed: b, removeAds: removeAds, lastBattleWon: won, stage: stage, now: t0,
                                       lastInterstitial: last, lastRewarded: rew, config: cfg)
    }
    check(!ok(1) && !ok(2) && ok(3) && !ok(4) && ok(5), "interstitials from battle 3, every 2nd battle")
    check(!ok(5, removeAds: true), "No Ads disables interstitials")
    check(!ok(5, won: false, stage: 4) && ok(5, won: false, stage: 9), "no interstitial after an early loss")
    check(!ok(5, last: t0.addingTimeInterval(-60)) && ok(5, last: t0.addingTimeInterval(-200)), "minimum time between interstitials")
    check(!ok(5, rew: t0.addingTimeInterval(-30)), "no interstitial right after a rewarded ad")

    UserDefaults.standard.removeObject(forKey: "hamsterages.progress.v1")
    let store = ProgressStore()
    check(store.starterOfferRemaining() == nil, "starter offer closed for new players")
    store.recordBattle(stage: 1, won: false, seeds: 10, stars: 0)
    let left = store.starterOfferRemaining() ?? 0
    check(left > 71 * 3600 && left <= 72 * 3600, "starter offer opens for 72h after the first loss")
    check(store.starterOfferRemaining(now: .now.addingTimeInterval(73 * 3600)) == nil, "starter offer expires")
    let s0 = store.progress.seeds
    check(store.grantPurchasedSeeds(1200) == 2400 && store.grantPurchasedSeeds(1200) == 1200 && store.progress.seeds == s0 + 3600,
          "first seed purchase is doubled once")
    let day = Date()
    check(store.freeSeedsLeft(now: day) == 3, "3 free seed ads per day")
    for _ in 0..<3 { store.claimFreeSeeds(now: day) }
    check(store.freeSeedsLeft(now: day) == 0 && store.claimFreeSeeds(now: day) == 0, "free seeds capped per day")
    check(store.freeSeedsLeft(now: day.addingTimeInterval(86_400)) == 3, "free seeds reset next day")

    var a = PlayerProgress(); a.highestStage = 5; a.battlesPlayed = 9
    var b = PlayerProgress(); b.highestStage = 7; b.battlesPlayed = 3
    check(ProgressStore.mostAdvanced(a, b)?.highestStage == 7 && ProgressStore.mostAdvanced(a, nil)?.highestStage == 5,
          "cloud merge keeps the most advanced save")
    UserDefaults.standard.removeObject(forKey: "hamsterages.progress.v1")
}

// Showcase jump + localization fallbacks
do {
    let s = BattleSimulation(difficulty: StageDifficulty(stage: 3), playerMods: SideModifiers(), seed: 9)
    s.debugJump(.player, toEra: 3)
    s.debugJump(.enemy, toEra: 9)
    check(s.state(.player).era == 3 && s.state(.enemy).era == GameConfig.eras.count - 1, "debugJump reaches the requested era (clamped)")
    check(s.state(.player).baseMaxHP == GameConfig.eras[3].baseHP * s.state(.player).mods.baseHP, "debugJump base HP follows the era")
    check(s.events.isEmpty, "debugJump leaves no pending events")
    check(L10n.f("Win %lld battles", 3) == "Win 3 battles", "L10n.f formats integers")
    check(L10n.f("Melee damage +25%%") == "Melee damage +25%", "L10n.f unescapes literal percent")
    check(L10n.f("Rats · %@", "Future") == "Rats · Future", "L10n.f formats strings")
}

// MARK: Elite rats, stances, rat generals, boss slam
do {
    check(RatTrait.chance(stage: 3) == 0 && RatTrait.pool(stage: 3).isEmpty, "no elite rats before stage 4")
    check(RatTrait.pool(stage: 4) == [.swift] && RatTrait.pool(stage: 12).count == RatTrait.allCases.count, "elite traits unlock with stages")
    check(RatTrait.chance(stage: 40) <= 0.3, "elite share is capped")
    check(RatGeneral.forStage(1) == .gnawsworth && RatGeneral.forStage(5) == .ratKing && RatGeneral.forStage(10) == .ratKing,
          "first stages get the gentle general, boss stages the Rat King")
    let rotation = (3...12).filter { $0 % 5 != 0 }.map(RatGeneral.forStage)
    check(Set(rotation).count == 5, "every rat general shows up before repeating")

    // Elites appear, shields absorb hits, plague rats split.
    let s = BattleSimulation(difficulty: StageDifficulty(stage: 14), playerMods: SideModifiers(), seed: 78)
    playerBot(s)
    var traits = Set<RatTrait>(), shieldHits = 0, heals = 0, sawMinion = false, eliteIDs = Set<Int>()
    var t = 0.0
    while t < 400 && s.winner == nil && !s.awaitingRevive {
        s.step(1.0 / 30)
        for e in s.events {
            if case .eliteSpawned(let id, let trait) = e { traits.insert(trait); eliteIDs.insert(id) }
            if case .shieldHit = e { shieldHits += 1 }
            if case .healed = e { heals += 1 }
        }
        if s.units.contains(where: { $0.isMinion }) { sawMinion = true }
        s.events.removeAll()
        t += 1.0 / 30
    }
    check(traits.count >= 3, "several elite traits appear at stage 14 (\(traits))")
    check(shieldHits > 0, "shield bubbles absorb hits")
    check(heals > 0, "rat medics heal their friends")
    check(sawMinion, "plague rats burst into minions")
    check(s.units.allSatisfy { $0.trait != .medic || $0.role == .ranged }, "medics are always ranged rats")
    check(s.units.allSatisfy { $0.side == .enemy || $0.trait == nil }, "only rats get elite traits")

    // Hold keeps the army under the turrets; Fall back walks it home.
    let h = BattleSimulation(difficulty: StageDifficulty(stage: 3), playerMods: SideModifiers(), seed: 5)
    playerBot(h)
    h.setStance(.hold, for: .player)
    run(h, seconds: 40)
    let front = BattleSimulation.baseFront(.player)
    check(h.units.filter { $0.side == .player }.allSatisfy { $0.x <= front + 215.5 }, "Hold: no unit walks past the hold line")
    h.setStance(.charge, for: .player)
    var pushed = 0.0
    run(h, seconds: 60) { sim in
        pushed = max(pushed, sim.units.filter { $0.side == .player }.map(\.x).max() ?? 0)
        return false
    }
    h.setStance(.fallBack, for: .player)
    run(h, seconds: 25)
    let mine = h.units.filter { $0.side == .player }
    check(pushed > front + 215 || mine.isEmpty, "Charge pushes past the hold line")
    check(mine.allSatisfy { $0.x <= front + 30.5 }, "Fall back: everyone returns to the base")

    // Turtle general holds until it has a crowd.
    let turtleStage = (3...30).first { RatGeneral.forStage($0) == .whiskerbane }!
    let w = BattleSimulation(difficulty: StageDifficulty(stage: turtleStage), playerMods: SideModifiers(), seed: 3)
    check(w.ratGeneral == .whiskerbane, "stage \(turtleStage) is led by Whiskerbane")
    run(w, seconds: 20)
    let ef = BattleSimulation.baseFront(.enemy)
    let rats = w.units.filter { $0.side == .enemy }
    check(rats.count >= 6 || rats.allSatisfy { $0.x >= ef - 215.5 }, "Whiskerbane holds under her turrets until she has 6 rats")

    // Rat King telegraphs a slam, then hits.
    let b = BattleSimulation(difficulty: StageDifficulty(stage: 10), playerMods: SideModifiers(), seed: 11)
    playerBot(b)
    var windupAt: Double?, slamAt: Double?
    t = 0
    while t < 400 && b.winner == nil && !b.awaitingRevive && slamAt == nil {
        b.step(1.0 / 60)
        for e in b.events {
            if case .bossWindup = e, windupAt == nil { windupAt = b.time }
            if case .bossSlam = e, windupAt != nil { slamAt = b.time }
        }
        b.events.removeAll()
        t += 1.0 / 60
    }
    check(windupAt != nil && slamAt != nil, "the Rat King winds up and slams")
    var summons = 0
    t = 0
    while t < 400 && b.winner == nil && !b.awaitingRevive && summons == 0 {
        b.step(1.0 / 30)
        for e in b.events { if case .bossSummon = e { summons += 1 } }
        b.events.removeAll()
        t += 1.0 / 30
    }
    check(summons >= 1, "a hurt Rat King calls his guard")
    if let w0 = windupAt, let s0 = slamAt {
        check(abs((s0 - w0) - GameConfig.bossSlamWindup) < 0.05, "the slam lands exactly after the wind-up")
    }
}

print(failures == 0 ? "✅ All \(passed) checks passed" : "\(failures) failed, \(passed) passed")
exit(failures == 0 ? 0 : 1)
