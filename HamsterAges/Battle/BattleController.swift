import Foundation
import Observation

struct BattleResult {
    let won: Bool
    let stage: Int
    let seeds: Int
    let stars: Int
    let kills: Int
    let duration: Double
    let stats: BattleStats
    var mode: BattleMode = .campaign
    var wave = 0
}

struct TurretSlotInfo: Equatable {
    var unlocked: Bool
    var era: Int?
}

/// Owns the simulation, drives it from the scene's frame loop and publishes a throttled HUD snapshot.
@MainActor
@Observable
final class BattleController {
    let stage: Int
    let difficulty: StageDifficulty
    let mode: BattleMode
    /// Daily challenge pays its big reward only for the first clear of the day.
    let challengeFirstClear: Bool
    let general: GeneralID?
    let generalLevel: Int
    /// Player's equipped fur skin (cosmetic).
    let skin: FurSkin
    let sim: BattleSimulation
    @ObservationIgnored private(set) var scene: BattleScene!
    @ObservationIgnored private var accumulator = 0.0
    @ObservationIgnored private var hudTimer = 0.0
    private let fixedStep = 1.0 / 60.0
    @ObservationIgnored var onFinish: ((BattleResult) -> Void)?

    // HUD snapshot
    var food = 0
    var era = 0
    var enemyEra = 0
    var xpProgress = 0.0
    var canEvolve = false
    var playerHP = 1.0
    var enemyHP = 1.0
    var playerHPText = ""
    var queue: [UnitRole] = []
    var trainFraction = 0.0
    var specialFraction = 1.0
    var unitCosts: [Int] = [0, 0, 0]
    var turretCost = 0
    var slotUnlockCost = 0
    var turretSlots: [TurretSlotInfo] = []
    var speed: Double = 1
    var isPaused = false
    var cardOffer: [Card]?
    var cardOfferTitle = ""
    var rerollsLeft: Int
    var ownedCards: [CardID] = []
    var result: BattleResult?
    var banner: String?
    var clock = "0:00"
    var heroReady = false
    var wave = 1
    var isOvertime = false
    /// Rat King health while one is on the field (boss bar).
    var bossHP: Double?
    /// Short scripted moment (evolution set piece) — the battle is frozen while it plays.
    var cinematic = false
    @ObservationIgnored private var hitStop = 0.0

    // Rats & orders
    let ratGeneral: RatGeneral
    /// Army order buttons (hidden in the very first battle to keep it simple).
    let stancesEnabled: Bool
    var stance: Stance = .charge
    /// The rat general's speech bubble.
    var taunt: String?
    /// "New elite rat" card shown the first time a trait appears this battle.
    var eliteIntro: RatTrait?
    @ObservationIgnored private var seenTraits = Set<RatTrait>()
    @ObservationIgnored private var slamWarnings = 0

    // Tutorial (first battle only)
    let isTutorial: Bool
    var tutorialStep: TutorialStep?
    var tutorialVisible = false
    @ObservationIgnored private var tutorialShownAt = 0.0
    @ObservationIgnored private var tutorialStepStart = 0.0

    /// Battle time is frozen while paused, picking a card, or showing a blocking tutorial hint.
    var isFrozen: Bool {
        isPaused || cinematic || cardOffer != nil || reviveOffer || (tutorialVisible && tutorialStep?.isBlocking == true)
    }
    var reviveOffer = false

    init(stage: Int, progress: PlayerProgress, mode: BattleMode = .campaign) {
        self.stage = stage
        self.mode = mode
        let today = Date.now
        challengeFirstClear = mode == .challenge && progress.challengeClearedDay != QuestBoard.dayKey(today)
        switch mode {
        case .campaign: difficulty = StageDifficulty(stage: stage)
        case .survival: difficulty = StageDifficulty(stage: GameConfig.survivalBaseStage)
        case .challenge: difficulty = StageDifficulty(stage: stage, modifier: DailyChallenge.modifier(for: today))
        }
        general = progress.equipped.flatMap { progress.generalLevel($0) > 0 ? $0 : nil }
        generalLevel = general.map { progress.generalLevel($0) } ?? 0
        skin = progress.skin
        let tutorial = progress.tutorialDone != true && stage == 1 && mode == .campaign
        var mods = progress.battleModifiers
        // First battle: faster XP so every new player sees an evolution within ~1:00–1:30.
        if tutorial { mods.xpGain *= 1.5 }
        sim = BattleSimulation(difficulty: difficulty, playerMods: mods,
                               seed: mode == .challenge ? DailyChallenge.seed(for: today) : UInt64.random(in: 1...UInt64.max),
                               mode: mode)
        if mode == .challenge {
            for id in DailyChallenge.startingCards(for: today) { sim.applyCard(id, to: .player) }
        }
        sim.setHeroAbility(general?.ability, for: .player)
        rerollsLeft = progress.level(.charm)
        ratGeneral = sim.ratGeneral
        stancesEnabled = !tutorial
        isTutorial = tutorial
        tutorialStep = isTutorial ? .train : nil
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-era"), i + 1 < args.count, let era = Int(args[i + 1]) {
            for side in Side.allCases { sim.debugJump(side, toEra: era) }
        }
        #endif
        scene = BattleScene(controller: self)
        Analytics.log(.battleStart(stage: stage, attempt: progress.battlesPlayed + 1))
        refreshHUD()
        offerCards(title: L10n.t("Opening Card"))
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-autoplay") {
            // CI screenshots: a bot plays the player's side at double speed.
            sim.controllers[.player] = BattleAI(thinkInterval: 0.6, evolveDelay: 1, usesCards: true)
            speed = 2
        }
        #endif
    }

    // MARK: Frame loop (called from BattleScene.update)

    func tick(_ rawDT: Double) {
        guard !isFrozen, result == nil, sim.winner == nil else { return }
        if hitStop > 0 {           // brief impact freeze for big moments; rendering keeps going
            hitStop -= rawDT
            return
        }
        accumulator += min(rawDT, 0.1) * speed
        while accumulator >= fixedStep {
            sim.step(fixedStep)
            accumulator -= fixedStep
            let events = sim.events
            sim.events.removeAll(keepingCapacity: true)
            scene.handle(events)
            for e in events {
                switch e {
                case .evolved(side: .player, era: let newEra):
                    playEvolution(newEra)
                case .lastStand(side: .player):
                    flashBanner(L10n.t("LAST STAND!"))
                    impact(0.09)
                case .specialImpact:
                    impact(0.07)
                case .died(_, _, _, _, let role) where role == .heavy:
                    impact(0.035)
                case .waveUp(level: let w):
                    flashBanner(L10n.f("WAVE %lld! RATS GROW STRONGER", w))
                case .bossSpawned:
                    flashBanner(L10n.t("THE RAT KING APPROACHES!"))
                    Haptics.boom()
                    impact(0.1)
                case .suddenDeathStarted:
                    flashBanner(L10n.t("SUDDEN DEATH! BASES CRUMBLE"))
                    Haptics.boom()
                case .overtimeStarted:
                    flashBanner(L10n.t("OVERTIME! TURRETS DOWN"))
                    Haptics.boom()
                case .eliteSpawned(_, let trait) where !seenTraits.contains(trait):
                    seenTraits.insert(trait)
                    showEliteIntro(trait)
                case .bossWindup:
                    // Teach the counter the first couple of times: pull back out of the slam zone.
                    if stancesEnabled && slamWarnings < 2 && stance != .fallBack {
                        slamWarnings += 1
                        flashBanner(L10n.t("SLAM INCOMING — FALL BACK!"))
                    }
                default: break
                }
            }
            if sim.winner != nil { finish(); break }
            if sim.awaitingRevive {
                reviveOffer = true
                Haptics.boom()
                break
            }
            if cardOffer != nil || cinematic || hitStop > 0 { break }
        }
        hudTimer += rawDT
        if hudTimer >= 0.1 {
            hudTimer = 0
            refreshHUD()
        }
    }

    private func refreshHUD() {
        let p = sim.state(.player)
        let e = sim.state(.enemy)
        set(\.food, Int(p.food))
        set(\.era, p.era)
        set(\.enemyEra, e.era)
        set(\.xpProgress, (p.xpProgress * 100).rounded() / 100)
        set(\.canEvolve, p.canEvolve)
        set(\.playerHP, (p.baseHP / p.baseMaxHP * 200).rounded() / 200)
        set(\.enemyHP, (e.baseHP / e.baseMaxHP * 200).rounded() / 200)
        set(\.playerHPText, "\(Int(max(0, p.baseHP)))")
        set(\.queue, p.queue.map(\.role))
        set(\.trainFraction, (p.trainFraction * 20).rounded() / 20)
        set(\.specialFraction, p.specialMaxCooldown > 0 ? ((1 - p.specialCooldown / p.specialMaxCooldown) * 50).rounded() / 50 : 1)
        set(\.unitCosts, UnitRole.allCases.map { Int(sim.unitCost($0, for: .player)) })
        set(\.turretCost, Int(sim.turretCost(for: .player)))
        set(\.slotUnlockCost, Int(sim.slotUnlockCost(for: .player)))
        set(\.turretSlots, p.turrets.map { TurretSlotInfo(unlocked: $0.unlocked, era: $0.era) })
        set(\.ownedCards, p.cards)
        let t = Int(sim.time)
        set(\.clock, String(format: "%d:%02d", t / 60, t % 60))
        set(\.isOvertime, sim.isOvertime)
        set(\.wave, sim.survivalWave)
        set(\.heroReady, p.heroReady)
        if let boss = sim.units.first(where: { $0.isBoss }) {
            set(\.bossHP, (max(0, boss.hp / boss.maxHP) * 100).rounded() / 100)
        } else {
            set(\.bossHP, nil)
        }
        updateTutorial()
    }

    // MARK: Tutorial

    private func updateTutorial() {
        guard let step = tutorialStep, cardOffer == nil, result == nil else { return }
        let p = sim.state(.player)
        if tutorialVisible {
            if !step.isBlocking && sim.time - tutorialShownAt >= step.duration { advanceTutorial() }
            // Food spent on units/slot unlock while frozen: hide the turret hint (it re-shows when affordable,
            // or times out) instead of freezing the battle forever with no way to earn food.
            if step == .turret && p.food < sim.turretCost(for: .player) { tutorialVisible = false }
            return
        }
        let ready: Bool
        switch step {
        case .train, .earn, .finish:
            ready = true
        case .turret:
            if p.turrets.contains(where: { $0.era != nil }) { advanceTutorial(); return }
            ready = p.food >= sim.turretCost(for: .player)
        case .special:
            ready = p.specialCooldown <= 0 && sim.units.filter { $0.side == .enemy }.count >= 2
        case .evolve:
            ready = p.canEvolve
        }
        // Never let one step stall the whole tutorial.
        if !ready && sim.time - tutorialStepStart > 45 { advanceTutorial(); return }
        if ready {
            tutorialVisible = true
            tutorialShownAt = sim.time
            Analytics.log(.tutorialStep(step.analyticsName))
        }
    }

    private func advanceTutorial() {
        guard let step = tutorialStep else { return }
        tutorialVisible = false
        tutorialStepStart = sim.time
        tutorialStep = TutorialStep(rawValue: step.rawValue + 1)
    }

    private func tutorialAction(_ target: TutorialTarget) {
        if tutorialVisible, tutorialStep?.target == target { advanceTutorial() }
    }

    /// Only assigns when the value changed, so SwiftUI isn't invalidated 10×/s for nothing.
    private func set<T: Equatable>(_ kp: ReferenceWritableKeyPath<BattleController, T>, _ value: T) {
        if self[keyPath: kp] != value { self[keyPath: kp] = value }
    }

    // MARK: Player commands

    func train(_ role: UnitRole) {
        if sim.train(role, for: .player) {
            Haptics.tap()
            Sound.shared.play(.tap)
            tutorialAction(.unit)
        } else {
            Haptics.fail()
        }
        refreshHUD()
    }

    func evolve() {
        if sim.evolve(.player) {
            Haptics.success()
            tutorialAction(.evolve)
        }
        let events = sim.events
        sim.events.removeAll()
        scene.handle(events)
        for e in events {
            if case .evolved(side: .player, era: let newEra) = e { playEvolution(newEra) }
        }
        refreshHUD()
    }

    func tapTurretSlot(_ slot: Int) {
        let p = sim.state(.player)
        if !p.turrets[slot].unlocked {
            sim.unlockSlot(for: .player) ? Haptics.tap() : Haptics.fail()
        } else if sim.buyTurret(slot: slot, for: .player) {
            Haptics.tap()
            tutorialAction(.turret)
        } else {
            Haptics.fail()
        }
        refreshHUD()
        scene.refreshTurrets()
    }

    func sellTurret(_ slot: Int) {
        if sim.sellTurret(slot: slot, for: .player) { Haptics.tap() }
        refreshHUD()
        scene.refreshTurrets()
    }

    func useSpecial() {
        if sim.useSpecial(.player) {
            Haptics.boom()
            tutorialAction(.special)
            scene.handle(sim.events)
            sim.events.removeAll()
        } else {
            Haptics.fail()
        }
        refreshHUD()
    }

    func toggleSpeed() { speed = speed == 1 ? 2 : 1 }

    func setStance(_ s: Stance) {
        guard stancesEnabled, s != stance else { return }
        stance = s
        sim.setStance(s, for: .player)
        Haptics.tap()
        Sound.shared.play(.tap)
        Analytics.log(.stance(s.rawValue))
    }

    func useHero() {
        guard let ability = sim.state(.player).heroAbility, sim.useHeroAbility(.player) else {
            Haptics.fail()
            return
        }
        scene.handle(sim.events)
        sim.events.removeAll()
        flashBanner(ability.title.localizedUppercase)
        Haptics.boom()
        refreshHUD()
    }

    // MARK: Revive

    func enableRevive(_ on: Bool) { sim.reviveEnabled = on && !isTutorial }

    func acceptRevive() {
        guard reviveOffer else { return }
        sim.acceptRevive()
        scene.handle(sim.events)
        sim.events.removeAll()
        reviveOffer = false
        flashBanner(L10n.t("BASE RESTORED!"))
        Analytics.log(.adRewarded(placement: "revive"))
        Haptics.success()
        refreshHUD()
    }

    func declineRevive() {
        // finish() only becomes idempotent once `result` is set 1.2 s later; a second call here would
        // schedule a second onFinish and record the battle (seeds, quests) twice.
        guard reviveOffer else { return }
        sim.declineRevive()
        reviveOffer = false
        scene.handle(sim.events)
        sim.events.removeAll()
        finish()
    }

    // MARK: Cards

    private func offerCards(title: String) {
        cardOfferTitle = title
        cardOffer = sim.drawCards(for: .player)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-autoplay"), let first = cardOffer?.first {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.pick(first) }
        }
        #endif
    }

    func pick(_ card: Card) {
        let firstPick = sim.state(.player).cards.isEmpty
        sim.applyCard(card.id, to: .player)
        if firstPick, sim.activeModifier != .none {
            flashBanner(sim.activeModifier.title.localizedUppercase + "!")
        }
        if firstPick && !isTutorial {
            let line = ratGeneral.taunt
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.taunt = line
                Sound.shared.play(.squeak)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.6) { [weak self] in
                if self?.taunt == line { self?.taunt = nil }
            }
        }
        Analytics.log(.cardPicked(id: card.id.rawValue, rarity: String(describing: card.rarity), era: sim.state(.player).era))
        cardOffer = nil
        Haptics.success()
        Sound.shared.play(.card)
        refreshHUD()
    }

    func reroll() {
        guard rerollsLeft > 0 else { return }
        rerollsLeft -= 1
        Analytics.log(.cardReroll(viaAd: false))
        cardOffer = sim.drawCards(for: .player)
    }

    func grantReroll() {
        Analytics.log(.cardReroll(viaAd: true))
        Analytics.log(.adRewarded(placement: "card_reroll"))
        cardOffer = sim.drawCards(for: .player)
    }

    // MARK: End

    private func finish() {
        guard result == nil, let winner = sim.winner else { return }
        let won = winner == .player
        let p = sim.state(.player)
        let hpFrac = p.baseHP / p.baseMaxHP
        let stars = won ? (hpFrac > 0.66 ? 3 : hpFrac > 0.33 ? 2 : 1) : 0
        let baseSeeds: Int
        switch mode {
        case .survival: baseSeeds = ProgressStore.survivalReward(wave: sim.survivalWave)
        case .challenge where won && challengeFirstClear: baseSeeds = DailyChallenge.reward(stage: stage)
        default: baseSeeds = ProgressStore.reward(stage: stage, won: won, damageFraction: sim.enemyBaseDamageFraction)
        }
        let seeds = Int((Double(baseSeeds) * LiveEvents.seedMultiplier()).rounded())
        let stats = BattleStats(won: won, unitsTrained: p.unitsTrained, kills: p.kills, specialsUsed: p.specialsUsed,
                                evolutions: p.era, bossesKilled: p.bossesKilled)
        var r = BattleResult(won: won, stage: stage, seeds: seeds, stars: stars, kills: p.kills, duration: sim.time, stats: stats)
        r.mode = mode
        r.wave = sim.survivalWave
        Analytics.log(.battleEnd(stage: stage, won: won, seconds: Int(sim.time), era: p.era, kills: p.kills, stars: stars))
        if isTutorial { Analytics.log(.tutorialComplete(won: won)) }
        tutorialStep = nil
        tutorialVisible = false
        refreshHUD()
        won ? Haptics.success() : Haptics.fail()
        Sound.shared.play(won ? .win : .lose)
        scene.playEnding(won: won)
        // Let the base-destruction animation play before the overlay.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self else { return }
            self.result = r
            self.onFinish?(r)
        }
    }

    // MARK: Moments

    /// Evolution set piece: freeze, camera on the base, flash + morph, era banner — then the card pick.
    private func playEvolution(_ newEra: Int) {
        Analytics.log(.evolve(era: newEra, seconds: Int(sim.time)))
        cinematic = true
        scene.playEvolution(era: newEra)
        Haptics.success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.flashBanner(GameConfig.eraNames[newEra].localizedUppercase + "!")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            guard let self else { return }
            self.cinematic = false
            self.offerCards(title: L10n.f("Evolved to %@", GameConfig.eraNames[newEra]))
        }
    }

    /// Hit-stop: the whole battle pauses for a few frames so big impacts land.
    private func impact(_ seconds: Double) {
        hitStop = max(hitStop, seconds)
    }

    private func showEliteIntro(_ trait: RatTrait) {
        eliteIntro = trait
        Sound.shared.play(.card)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.eliteIntro == trait { self?.eliteIntro = nil }
        }
    }

    private func flashBanner(_ text: String) {
        banner = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            if self?.banner == text { self?.banner = nil }
        }
    }
}
