import SpriteKit
import SwiftUI

struct BattleView: View {
    let controller: BattleController
    let store: ProgressStore
    let ads: AdService
    let onExit: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SpriteView(scene: controller.scene, preferredFramesPerSecond: 60, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()

                ScaledUI {
                ZStack {
                BattleHUD(c: controller)
                    // Card picks get the whole stage; the HUD fades out behind them.
                    .opacity(controller.cardOffer == nil ? 1 : 0)

                if controller.tutorialVisible, let step = controller.tutorialStep, controller.cardOffer == nil, controller.result == nil {
                    TutorialBubble(step: step)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let trait = controller.eliteIntro, controller.cardOffer == nil, controller.result == nil {
                    EliteIntroCard(trait: trait)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                if controller.versus {
                    VersusSplash(general: controller.general, skin: controller.skin, rat: controller.ratGeneral,
                                 stage: controller.stage, mode: controller.mode)
                        .transition(.opacity)
                }

                if let tip = controller.tip, controller.result == nil, controller.eliteIntro == nil {
                    TipCard(text: tip)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                if let taunt = controller.taunt, controller.result == nil {
                    TauntBubble(general: controller.ratGeneral, text: taunt)
                        .transition(.scale(scale: 0.6, anchor: .topTrailing).combined(with: .opacity))
                }

                if let banner = controller.banner {
                    OutlinedText(text: banner, size: 34, color: Theme.gold)
                        .transition(.scale.combined(with: .opacity))
                        .allowsHitTesting(false)
                }

                if let offer = controller.cardOffer {
                    CardPickView(controller: controller, cards: offer, ads: ads)
                        .transition(.opacity)
                }

                if controller.reviveOffer {
                    ReviveView(controller: controller, ads: ads)
                        .transition(.opacity)
                }

                if controller.isPaused {
                    PauseView(controller: controller, onQuit: onExit)
                }

                if let result = controller.result {
                    ResultView(result: result, store: store, ads: ads, onContinue: onExit)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
                }
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: controller.banner)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: controller.tutorialVisible)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: controller.taunt)
            .animation(.easeOut(duration: 0.2), value: controller.versus)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: controller.eliteIntro)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: controller.tip)
            .animation(.easeOut(duration: 0.2), value: controller.cardOffer == nil)
            .animation(.easeOut(duration: 0.25), value: controller.result == nil)
            .onAppear { applyInsets(geo) }
            .onChange(of: geo.size) { applyInsets(geo) }
        }
        .onAppear {
            Music.shared.play(.era(controller.era))
            controller.enableRevive(ads.isRewardedReady)
            GameCenter.setAccessPoint(visible: false)
            // Capture only what's needed: capturing `self` (which holds `controller`) in a closure stored on the
            // controller is a retain cycle that leaks the controller, simulation and scene after every battle.
            let isTutorial = controller.isTutorial
            controller.onFinish = { [store] r in
                if r.mode == .survival {
                    store.recordSurvival(seconds: r.duration, seeds: r.seeds, stats: r.stats)
                    GameCenter.submitSurvival(seconds: Int(r.duration))
                } else if r.mode == .challenge {
                    store.recordChallenge(won: r.won, seeds: r.seeds, stats: r.stats)
                    if r.won { GameCenter.submitDailyTime(seconds: Int(r.duration)) }
                } else {
                    store.recordBattle(stage: r.stage, won: r.won, seeds: r.seeds, stars: r.stars, stats: r.stats, hard: r.hard)
                }
                if isTutorial { store.completeTutorial() }
                GameCenter.sync(progress: store.progress, lastBattle: r.stats)
                ReviewPrompt.maybeAsk(progress: store.progress, lastStars: r.stars)
            }
        }
    }

    private func applyInsets(_ geo: GeometryProxy) {
        let i = geo.safeAreaInsets
        controller.scene.safeInsets = UIEdgeInsets(top: i.top, left: i.leading, bottom: i.bottom, right: i.trailing)
    }
}

// MARK: - HUD

private struct BattleHUD: View {
    let c: BattleController

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                RoundIconButton(icon: "pause.fill") { c.isPaused = true }
                if let g = c.general {
                    Image(uiImage: ArtFactory.shared.general(g))
                        .resizable().scaledToFit()
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.panel))
                        .overlay(alignment: .bottomTrailing) {
                            Text("\(c.generalLevel)").font(Theme.font(9)).foregroundStyle(Theme.ink)
                                .frame(width: 14, height: 14).background(Circle().fill(Theme.gold))
                        }
                        .accessibilityLabel("\(g.name), \(g.effectText(level: c.generalLevel))")
                }
                BaseBar(title: GameConfig.eraNames[c.era], fraction: c.playerHP, color: Theme.teal, text: c.playerHPText, mirrored: false)
                Spacer(minLength: 4)
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        CurrencyPill(icon: "🌽", value: c.food)
                        Text(c.clock)
                            .font(Theme.font(12)).monospacedDigit()
                            .foregroundStyle(c.isOvertime ? Theme.red : .white.opacity(0.85))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule().fill(Theme.panel))
                    }
                    EvolveBar(c: c)
                        .tutorialAnchor(.evolve)
                    if let hp = c.bossHP {
                        BossBar(fraction: hp)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3), value: c.bossHP == nil)
                Spacer(minLength: 4)
                BaseBar(title: c.mode == .survival ? L10n.f("Rat Fortress · Wave %lld", c.wave) : (c.difficulty.isHard ? "☠︎ " + L10n.t("Hard") + " · " : "") + "\(c.ratGeneral.name) · \(GameConfig.eraNames[c.enemyEra])",
                        fraction: c.enemyHP, color: Theme.red, text: c.mode == .survival ? "∞" : nil, mirrored: true)
                RatGeneralBadge(general: c.ratGeneral, size: 40)
                RoundIconButton(icon: c.speed > 1 ? "forward.fill" : "play.fill", label: c.speed > 1 ? "×2" : "×1") { c.toggleSpeed() }
            }
            Spacer()
            if c.stancesEnabled {
                HStack {
                    StanceControl(c: c)
                    Spacer()
                }
                .padding(.bottom, 6)
            }
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(UnitRole.allCases, id: \.self) { role in
                    UnitButton(role: role, era: c.era, skin: c.skin, variant: c.loadout.variant(role), cost: c.unitCosts[role.rawValue], affordable: c.food >= c.unitCosts[role.rawValue] && c.queue.count < GameConfig.maxQueue) {
                        c.train(role)
                    }
                    .tutorialAnchor(role == .melee ? .unit : nil)
                }
                QueueView(queue: c.queue, fraction: c.trainFraction)
                Spacer(minLength: 4)
                ForEach(0..<2, id: \.self) { slot in
                    TurretButton(slot: slot, info: c.turretSlots.indices.contains(slot) ? c.turretSlots[slot] : TurretSlotInfo(unlocked: false),
                                 era: c.era, food: c.food, cost: c.turretCost, unlockCost: c.slotUnlockCost,
                                 onTap: { c.tapTurretSlot(slot) }, onSell: { c.sellTurret(slot) })
                    .tutorialAnchor(slot == 0 ? .turret : nil)
                }
                if let g = c.general {
                    HeroButton(general: g, ready: c.heroReady) { c.useHero() }
                }
                SpecialButton(era: c.era, fraction: c.specialFraction) { c.useSpecial() }
                    .tutorialAnchor(.special)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .overlayPreferenceValue(TutorialAnchorKey.self) { anchors in
            GeometryReader { proxy in
                if c.tutorialVisible, let target = c.tutorialStep?.target, let anchor = anchors[target] {
                    TutorialPointer(rect: proxy[anchor])
                }
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Share card

/// Slowly turning golden rays behind the victory panel.
private struct Sunburst: View {
    @State private var spin = false

    var body: some View {
        ZStack {
            ForEach(0..<16, id: \.self) { i in
                RayShape()
                    .fill(LinearGradient(colors: [Theme.gold.opacity(0.3), Theme.gold.opacity(0)], startPoint: .center, endPoint: .top))
                    .rotationEffect(.degrees(Double(i) * 22.5))
            }
            Circle().fill(RadialGradient(colors: [Theme.gold.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 260))
        }
        .rotationEffect(.degrees(spin ? 360 : 0))
        .onAppear { withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) { spin = true } }
    }

    private struct RayShape: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.midX, y: r.midY))
            p.addLine(to: CGPoint(x: r.midX - r.width * 0.06, y: r.minY))
            p.addLine(to: CGPoint(x: r.midX + r.width * 0.06, y: r.minY))
            p.closeSubpath()
            return p
        }
    }
}

/// 1200×630 image for sharing a win: army, rival, stars and a challenge line.
struct ShareCard: View {
    let result: BattleResult

    var body: some View {
        ZStack {
            Image(uiImage: ArtFactory.shared.background(era: result.era, size: CGSize(width: 600, height: 315), groundHeight: 60))
                .resizable()
            LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
            HStack(alignment: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    OutlinedText(text: "HAMSTER AGES", size: 34, color: Theme.gold)
                    if result.mode == .survival {
                        OutlinedText(text: L10n.f("SURVIVED %@", String(format: "%d:%02d", Int(result.duration) / 60, Int(result.duration) % 60)), size: 28)
                        Text(L10n.f("Wave %lld", result.wave)).font(Theme.font(18)).foregroundStyle(.white)
                    } else {
                        OutlinedText(text: L10n.f("Stage %lld cleared!", result.stage), size: 28)
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { i in
                                Image(systemName: "star.fill").font(.system(size: 26))
                                    .foregroundStyle(i < result.stars ? Theme.gold : .white.opacity(0.3))
                            }
                        }
                        Text(L10n.f("vs %@", result.ratGeneral.name)).font(Theme.font(16)).foregroundStyle(.white)
                    }
                    Spacer()
                    Text("Can your hamsters do better?").font(Theme.font(15)).foregroundStyle(Theme.gold)
                }
                .padding(24)
                Spacer()
                HStack(alignment: .bottom, spacing: -14) {
                    ForEach([UnitRole.heavy, .ranged, .melee], id: \.self) { role in
                        Image(uiImage: ArtFactory.shared.unit(.hamster, era: result.era, role: role, skin: result.skin))
                            .resizable().scaledToFit().frame(height: role == .heavy ? 110 : 80)
                    }
                    if let g = result.general {
                        Image(uiImage: ArtFactory.shared.general(g)).resizable().scaledToFit().frame(height: 110)
                    }
                }
                .padding(.trailing, 20).padding(.bottom, 26)
            }
        }
        .frame(width: 600, height: 315)
        .clipped()
    }
}

// MARK: - Rats & orders

/// Rat commander portrait (faces left, toward the hamsters).
struct RatGeneralBadge: View {
    let general: RatGeneral
    var size: CGFloat = 40

    var body: some View {
        Image(uiImage: ArtFactory.shared.ratGeneral(general))
            .resizable().scaledToFit()
            .scaleEffect(x: -1, y: 1)
            .frame(width: size, height: size)
            .background(Circle().fill(Color(hex: general.color).opacity(0.35)))
            .overlay(Circle().stroke(Color(hex: general.color), lineWidth: 2))
            .clipShape(Circle())
            .accessibilityLabel(general.name)
    }
}

/// Fall back / Hold / Charge — one army-wide order.
/// A narrow vertical column at the screen edge: it only covers the player's own base, never the fight.
private struct StanceControl: View {
    let c: BattleController

    var body: some View {
        VStack(spacing: 2) {
            ForEach(Stance.allCases, id: \.self) { s in
                let on = c.stance == s
                Button { c.setStance(s) } label: {
                    VStack(spacing: 0) {
                        Image(systemName: s.icon).font(.system(size: 13, weight: .black))
                        Text(s.title).font(Theme.font(8)).lineLimit(1).minimumScaleFactor(0.6)
                    }
                    .foregroundStyle(on ? Theme.ink : .white)
                    .frame(width: 46, height: 30)
                    .background(RoundedRectangle(cornerRadius: 10).fill(on ? stanceColor(s) : Color.clear))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 13).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(.white.opacity(0.25), lineWidth: 1))
        .animation(.spring(response: 0.25), value: c.stance)
    }

    private func stanceColor(_ s: Stance) -> Color {
        switch s {
        case .fallBack: return Theme.teal
        case .hold: return Theme.gold
        case .charge: return Theme.orange
        }
    }
}

private struct TauntBubble: View {
    let general: RatGeneral
    let text: String

    var body: some View {
        VStack {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(general.name.localizedUppercase).font(Theme.font(10)).foregroundStyle(Color(hex: general.color))
                    Text(text)
                        .font(Theme.font(13)).foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: 260, alignment: .trailing)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cream))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: general.color), lineWidth: 2.5))
                RatGeneralBadge(general: general, size: 46)
            }
            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
            .padding(.top, 56)
            .padding(.trailing, 56)
            .frame(maxWidth: .infinity, alignment: .trailing)
            Spacer()
        }
        .allowsHitTesting(false)
    }
}

/// Two portraits slam in from the sides with a big "VS".
private struct VersusSplash: View {
    let general: GeneralID?
    let skin: FurSkin
    let rat: RatGeneral
    let stage: Int
    let mode: BattleMode
    @State private var inside = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.teal.opacity(0.55), .clear, Theme.red.opacity(0.55)], startPoint: .leading, endPoint: .trailing)
                .ignoresSafeArea()
            HStack(spacing: 0) {
                Group {
                    if let g = general {
                        Image(uiImage: ArtFactory.shared.general(g)).resizable().scaledToFit()
                    } else {
                        Image(uiImage: ArtFactory.shared.unit(.hamster, era: 1, role: .melee, skin: skin)).resizable().scaledToFit()
                    }
                }
                .frame(width: 150, height: 150)
                .offset(x: inside ? 0 : -400)
                VStack(spacing: 2) {
                    OutlinedText(text: "VS", size: 64, color: Theme.gold)
                        .scaleEffect(inside ? 1 : 2.4)
                    if mode == .campaign {
                        Text(L10n.f("Stage %lld", stage)).font(Theme.font(14)).foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.6), radius: 2)
                    }
                }
                .frame(width: 160)
                VStack(spacing: 2) {
                    RatGeneralBadge(general: rat, size: 140)
                    Text(rat.name).font(Theme.font(14)).foregroundStyle(.white).shadow(color: .black.opacity(0.6), radius: 2)
                }
                .offset(x: inside ? 0 : 400)
            }
        }
        .allowsHitTesting(false)
        .onAppear { withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { inside = true } }
    }
}

private struct TipCard: View {
    let text: String

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                HStack(spacing: -6) {
                    ForEach(UnitRole.allCases, id: \.self) { role in
                        Image(uiImage: ArtFactory.shared.unit(.hamster, era: 1, role: role)).resizable().scaledToFit().frame(width: 30, height: 30)
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("TIP").font(Theme.font(12)).foregroundStyle(Theme.teal)
                    Text(text).font(Theme.font(12)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(maxWidth: 360, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cream))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.teal, lineWidth: 2.5))
            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
            .padding(.top, 60)
            .padding(.leading, 56)
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }
        .allowsHitTesting(false)
    }
}

private struct EliteIntroCard: View {
    let trait: RatTrait

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                Image(uiImage: ArtFactory.shared.traitBadge(trait)).resizable().frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(L10n.f("NEW: %@", trait.title.localizedUppercase)).font(Theme.font(14)).foregroundStyle(Theme.red)
                    Text(trait.detail).font(Theme.font(12)).foregroundStyle(Theme.ink)
                    Label(trait.counter, systemImage: "lightbulb.fill").font(Theme.font(11)).foregroundStyle(Theme.teal)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(maxWidth: 330, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cream))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.red, lineWidth: 2.5))
            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
            .padding(.top, 60)
            .padding(.leading, 56)
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Tutorial UI

struct TutorialAnchorKey: PreferenceKey {
    static var defaultValue: [TutorialTarget: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [TutorialTarget: Anchor<CGRect>], nextValue: () -> [TutorialTarget: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    func tutorialAnchor(_ target: TutorialTarget?) -> some View {
        anchorPreference(key: TutorialAnchorKey.self, value: .bounds) { a in
            target.map { [$0: a] } ?? [:]
        }
    }
}

private struct TutorialPointer: View {
    let rect: CGRect
    @State private var pulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.gold, lineWidth: 4)
                .frame(width: rect.width + 14, height: rect.height + 14)
                .scaleEffect(pulse ? 1.12 : 1)
                .opacity(pulse ? 0.4 : 1)
            Image(systemName: "hand.point.down.fill")
                .font(.system(size: 30))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 3, y: 2)
                .offset(y: -(rect.height / 2 + 26) + (pulse ? -6 : 0))
        }
        .position(x: rect.midX, y: rect.midY)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

private struct TutorialBubble: View {
    let step: TutorialStep

    var body: some View {
        VStack {
            HStack(spacing: 10) {
                Image(uiImage: ArtFactory.shared.unit(.hamster, era: 1, role: .melee))
                    .resizable().scaledToFit().frame(width: 44, height: 44)
                Text(step.text)
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(maxWidth: 440)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.cream))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.orange, lineWidth: 3))
            .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
            .padding(.top, 58)
            Spacer()
        }
        .allowsHitTesting(false)
    }
}

private struct RoundIconButton: View {
    let icon: String
    var label: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Image(systemName: icon).font(.system(size: 14, weight: .black))
                if let label { Text(label).font(Theme.font(10)) }
            }
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(Circle().fill(Theme.panel))
            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct BaseBar: View {
    let title: String
    let fraction: Double
    let color: Color
    let text: String?
    let mirrored: Bool

    var body: some View {
        VStack(alignment: mirrored ? .trailing : .leading, spacing: 2) {
            Text(title.localizedUppercase)
                .font(Theme.font(10)).lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
            ZStack(alignment: mirrored ? .trailing : .leading) {
                Capsule().fill(Color.black.opacity(0.45))
                Capsule().fill(color.gradient)
                    .frame(width: max(0, 150 * fraction))
                if let text {
                    Text(text).font(Theme.font(10)).foregroundStyle(.white).padding(.horizontal, 6)
                }
            }
            .frame(width: 150, height: 14)
            .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 1.2))
            .animation(.easeOut(duration: 0.2), value: fraction)
        }
    }
}

private struct BossBar: View {
    let fraction: Double

    var body: some View {
        HStack(spacing: 6) {
            Image(uiImage: ArtFactory.shared.crown()).resizable().scaledToFit().frame(width: 18, height: 12)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.5))
                Capsule().fill(LinearGradient(colors: [Color(hex: 0xB0306A), Theme.red], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 150 * fraction)
                Text("RAT KING").font(Theme.font(9)).foregroundStyle(.white).frame(maxWidth: .infinity)
            }
            .frame(width: 150, height: 12)
            .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 1))
            .animation(.easeOut(duration: 0.2), value: fraction)
        }
    }
}

private struct EvolveBar: View {
    let c: BattleController
    @State private var pulse = false

    var body: some View {
        Group {
            if c.canEvolve {
                Button { c.evolve() } label: {
                    Label("EVOLVE", systemImage: "arrow.up.forward.circle.fill").font(Theme.font(14))
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.purple, cornerRadius: 12, depth: 3))
                .scaleEffect(pulse ? 1.07 : 0.97)
                .onAppear { withAnimation(.easeInOut(duration: 0.5).repeatForever()) { pulse = true } }
                .onDisappear { pulse = false }
            } else if c.era < GameConfig.eras.count - 1 {
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.45))
                    Capsule().fill(Theme.purple.gradient).frame(width: 160 * c.xpProgress)
                    Text("XP \(Int(c.xpProgress * 100))% → \(GameConfig.eraNames[c.era + 1])")
                        .font(Theme.font(10)).foregroundStyle(.white).frame(maxWidth: .infinity)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(width: 160, height: 16)
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                .animation(.easeOut(duration: 0.2), value: c.xpProgress)
            } else {
                Text("FINAL AGE").font(Theme.font(11)).foregroundStyle(Theme.gold)
            }
        }
    }
}

private struct UnitButton: View {
    let role: UnitRole
    let era: Int
    var skin: FurSkin = .classic
    var variant: UnitVariant? = nil
    let cost: Int
    let affordable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Image(uiImage: ArtFactory.shared.unit(.hamster, era: era, role: role, skin: skin, variant: variant))
                    .resizable().scaledToFit()
                    .frame(height: 40)
                Text("\(cost)")
                    .font(Theme.font(12))
                    .foregroundStyle(affordable ? .white : Theme.red.mix(with: .white, by: 0.4))
            }
            .frame(width: 58, height: 60)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(affordable ? Theme.gold : .white.opacity(0.2), lineWidth: affordable ? 2 : 1))
            .saturation(affordable ? 1 : 0.3)
        }
        .buttonStyle(PressScale())
    }
}

private struct QueueView: View {
    let queue: [UnitRole]
    let fraction: Double
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<GameConfig.maxQueue, id: \.self) { i in
                ZStack {
                    Circle().fill(i < queue.count ? Theme.orange : Color.black.opacity(0.35)).frame(width: 9, height: 9)
                    if i == 0 && !queue.isEmpty {
                        ProgressRing(fraction: fraction, color: .white, lineWidth: 2).frame(width: 14, height: 14)
                    }
                }
                .frame(width: 14, height: 14)
            }
        }
        .padding(.bottom, 4)
    }
}

private struct TurretButton: View {
    let slot: Int
    let info: TurretSlotInfo
    let era: Int
    let food: Int
    let cost: Int
    let unlockCost: Int
    let onTap: () -> Void
    let onSell: () -> Void

    private var label: (String, Int?) {
        if !info.unlocked { return (L10n.t("Unlock"), unlockCost) }
        guard let e = info.era else { return (L10n.t("Turret"), cost) }
        return e < era ? (L10n.t("Upgrade"), cost) : (L10n.t("Ready"), nil)
    }

    var body: some View {
        let (title, price) = label
        let affordable = price.map { food >= $0 } ?? true
        Button(action: onTap) {
            VStack(spacing: 1) {
                if !info.unlocked {
                    Image(systemName: "lock.fill").font(.system(size: 18)).foregroundStyle(.white.opacity(0.8)).frame(height: 28)
                } else {
                    Image(uiImage: ArtFactory.shared.turret(era: info.era ?? era, species: .hamster))
                        .resizable().scaledToFit().frame(height: 28)
                        .opacity(info.era == nil ? 0.45 : 1)
                }
                Text(title).font(Theme.font(9)).foregroundStyle(.white.opacity(0.85)).lineLimit(1).minimumScaleFactor(0.6)
                if let price {
                    Text("\(price)").font(Theme.font(11)).foregroundStyle(affordable ? .white : Theme.red.mix(with: .white, by: 0.4))
                }
            }
            .frame(width: 54, height: 60)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(price != nil && affordable ? Theme.gold : .white.opacity(0.2), lineWidth: price != nil && affordable ? 2 : 1))
        }
        .buttonStyle(PressScale())
        .contextMenu {
            if info.era != nil {
                Button(role: .destructive, action: onSell) { Label("Sell turret (50%)", systemImage: "dollarsign.circle") }
            }
        }
    }
}

private struct SpecialButton: View {
    let era: Int
    let fraction: Double
    let action: () -> Void
    var ready: Bool { fraction >= 1 }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(ready ? Theme.red.gradient : Theme.panel.gradient)
                Image(uiImage: ArtFactory.shared.meteor(era: era)).resizable().scaledToFit().padding(12)
                    .saturation(ready ? 1 : 0.2)
                ProgressRing(fraction: fraction, color: ready ? Theme.gold : .white.opacity(0.7), lineWidth: 4)
                    .padding(2)
            }
            .frame(width: 62, height: 62)
            .overlay(alignment: .bottom) {
                Text(GameConfig.eras[era].special.name.localizedUppercase)
                    .font(Theme.font(9)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.5)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .offset(y: 6)
            }
        }
        .buttonStyle(PressScale())
        .disabled(!ready)
    }
}

private struct HeroButton: View {
    let general: GeneralID
    let ready: Bool
    let action: () -> Void
    @State private var glow = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(ready ? Theme.purple.gradient : Theme.panel.gradient)
                Image(uiImage: ArtFactory.shared.general(general)).resizable().scaledToFit().padding(4)
                    .saturation(ready ? 1 : 0)
                Circle().stroke(ready ? Theme.gold : .white.opacity(0.2), lineWidth: ready ? 3 : 1)
                    .scaleEffect(ready && glow ? 1.08 : 1)
            }
            .frame(width: 56, height: 56)
            .overlay(alignment: .bottom) {
                Text(general.ability.title.localizedUppercase)
                    .font(Theme.font(9)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.5)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .offset(y: 6)
            }
        }
        .buttonStyle(PressScale())
        .disabled(!ready)
        .onAppear { withAnimation(.easeInOut(duration: 0.7).repeatForever()) { glow = true } }
        .accessibilityLabel("\(general.ability.title): \(general.ability.detail)")
    }
}

struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.15, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Card pick

private struct CardPickView: View {
    let controller: BattleController
    let cards: [Card]
    let ads: AdService
    @State private var adRerollUsed = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.68).ignoresSafeArea()
            VStack(spacing: 7) {
                OutlinedText(text: controller.cardOfferTitle, size: 22, color: Theme.gold)
                Text(controller.isTutorial && controller.ownedCards.isEmpty ? "Cards power up your army for this battle — pick any!" : "Choose one upgrade for this battle")
                    .font(Theme.font(13)).foregroundStyle(.white.opacity(0.85))
                SetProgressRow(owned: controller.ownedCards)
                HStack(spacing: 14) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { i, card in
                        CardView(card: card, stacks: controller.ownedCards.filter { $0 == card.id }.count,
                                 familyCount: controller.ownedCards.filter { Card.tag(of: $0) == card.tag }.count)
                            .onTapGesture { controller.pick(card) }
                            .offset(y: appeared ? 0 : 40)
                            .opacity(appeared ? 1 : 0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(Double(i) * 0.07), value: appeared)
                    }
                }
                HStack(spacing: 12) {
                    if controller.rerollsLeft > 0 {
                        Button { controller.reroll() } label: {
                            Label("Reroll (\(controller.rerollsLeft))", systemImage: "dice.fill")
                        }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.teal))
                    } else if !adRerollUsed {
                        Button {
                            adRerollUsed = true
                            ads.showRewarded(placement: "card_reroll") { ok in if ok { controller.grantReroll() } }
                        } label: {
                            Label("Free Reroll", systemImage: "play.rectangle.fill")
                        }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.teal))
                    }
                }
            }
            .padding()
        }
        .onAppear { appeared = true }
        .id(cards.map(\.id.rawValue).joined())
    }
}

/// Card families collected so far: "Claw 2/3", or the bonus name once complete.
private struct SetProgressRow: View {
    let owned: [CardID]

    var body: some View {
        let tags = CardTag.allCases.filter { t in owned.contains { Card.tag(of: $0) == t } }
        if !tags.isEmpty {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { t in
                    let n = owned.filter { Card.tag(of: $0) == t }.count
                    let done = n >= CardTag.setSize
                    Label(done ? t.bonusTitle : "\(t.title) \(n)/\(CardTag.setSize)", systemImage: done ? "checkmark.seal.fill" : t.icon)
                        .font(Theme.font(11)).foregroundStyle(done ? Theme.ink : .white)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(done ? Theme.gold : Color(hex: t.color).opacity(0.45)))
                }
            }
        }
    }
}

private struct CardView: View {
    let card: Card
    let stacks: Int
    /// Cards of this card's family already owned.
    var familyCount = 0

    var body: some View {
        let rc = Theme.rarityColor(card.rarity)
        VStack(spacing: 8) {
            Text(card.rarity.title.localizedUppercase)
                .font(Theme.font(10))
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 2)
                .background(Capsule().fill(rc))
            ZStack {
                // Glossy medallion
                Circle().fill(LinearGradient(colors: [rc.mix(with: .white, by: 0.35), rc.mix(with: .black, by: 0.25)],
                                             startPoint: .top, endPoint: .bottom))
                    .frame(width: 62, height: 62)
                    .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 2))
                    .overlay(Ellipse().fill(.white.opacity(0.28)).frame(width: 40, height: 18).offset(y: -16))
                    .shadow(color: rc.opacity(0.7), radius: 8)
                Image(systemName: card.icon).font(.system(size: 28, weight: .heavy)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
            }
            Text(card.title).font(Theme.font(16)).foregroundStyle(.white).multilineTextAlignment(.center)
            Text(card.detail).font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if stacks > 0 {
                Text("Owned ×\(stacks)").font(Theme.font(10)).foregroundStyle(Theme.gold)
            }
            Spacer(minLength: 0)
            if familyCount == CardTag.setSize - 1 {
                Label(L10n.f("Completes %@!", card.tag.bonusTitle), systemImage: "sparkles")
                    .font(Theme.font(10)).foregroundStyle(Theme.ink)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.gold))
                    .lineLimit(1).minimumScaleFactor(0.7)
            } else {
                Label(card.tag.title, systemImage: card.tag.icon)
                    .font(Theme.font(10)).foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(Color(hex: card.tag.color).opacity(0.5)))
            }
        }
        .padding(11)
        .frame(width: 168, height: 200)
        .background(RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [rc.mix(with: Color(hex: 0x2B2140), by: 0.55), Color(hex: 0x231A35)],
                                                                            startPoint: .top, endPoint: .bottom)))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.12), lineWidth: 1).padding(4))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(rc, lineWidth: 3))
        .shadow(color: rc.opacity(card.rarity == .epic ? 0.7 : 0.3), radius: card.rarity == .epic ? 14 : 6)
        .contentShape(Rectangle())
    }
}

// MARK: - Revive

private struct ReviveView: View {
    let controller: BattleController
    let ads: AdService
    @State private var loading = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 14) {
                OutlinedText(text: "YOUR BASE IS FALLING!", size: 30, color: Theme.red)
                Text("Watch a short video to restore 40% of your base and blast the rats at your gates.")
                    .font(Theme.font(14)).foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center).frame(maxWidth: 380)
                HStack(spacing: 14) {
                    Button("Give up") { controller.declineRevive() }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.disabled))
                        .disabled(loading)
                    Button {
                        loading = true
                        ads.showRewarded(placement: "revive") { ok in
                            loading = false
                            if ok { controller.acceptRevive() } else { controller.declineRevive() }
                        }
                    } label: {
                        Label(loading ? "Loading…" : "Revive", systemImage: "play.rectangle.fill")
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.green))
                    .disabled(loading)
                }
            }
            .padding(26)
            .background(RoundedRectangle(cornerRadius: 26).fill(Theme.panel))
        }
    }
}

// MARK: - Pause

private struct PauseView: View {
    let controller: BattleController
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                OutlinedText(text: "Paused", size: 30)
                if controller.sim.activeModifier != .none {
                    Label("\(controller.sim.activeModifier.title) — \(controller.sim.activeModifier.detail)", systemImage: controller.sim.activeModifier.icon)
                        .font(Theme.font(13)).foregroundStyle(Theme.gold)
                }
                if !controller.ownedCards.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(controller.ownedCards.enumerated()), id: \.offset) { _, id in
                            let card = Card.card(id)
                            Image(systemName: card.icon)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.rarityColor(card.rarity))
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Color.black.opacity(0.4)))
                        }
                    }
                }
                HStack(spacing: 14) {
                    Button("Surrender", action: onQuit).buttonStyle(ChunkyButtonStyle(color: Theme.red))
                    Button("Resume") { controller.isPaused = false }.buttonStyle(ChunkyButtonStyle(color: Theme.green))
                }
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 24).fill(Theme.panel))
        }
    }
}

// MARK: - Result

private struct ResultView: View {
    let result: BattleResult
    let store: ProgressStore
    let ads: AdService
    let onContinue: () -> Void
    @State private var doubled = false
    @State private var loadingAd = false
    @State private var shownStars = 0
    @State private var showButtons = false
    @State private var shareImage: UIImage?

    private func clock(_ t: Double) -> String { String(format: "%d:%02d", Int(t) / 60, Int(t) % 60) }

    private var modeTitle: String {
        switch result.mode {
        case .survival: return L10n.t("Survival")
        case .challenge: return L10n.t("Daily Challenge")
        case .campaign: return L10n.f("Stage %lld", result.stage)
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            if result.won || result.mode == .survival {
                Sunburst().frame(width: 760, height: 760).frame(width: 1, height: 1).allowsHitTesting(false)
            }
            VStack(spacing: 12) {
                if result.mode == .survival {
                    OutlinedText(text: L10n.f("SURVIVED %@", clock(result.duration)), size: 36, color: Theme.gold)
                    let best = store.progress.bestSurvival ?? 0
                    Text(abs(best - result.duration) < 0.01 ? L10n.f("🏆 New personal best! Wave %lld", result.wave) : L10n.f("Wave %lld · Best %@", result.wave, clock(best)))
                        .font(Theme.font(15)).foregroundStyle(.white)
                } else {
                OutlinedText(text: result.won ? "VICTORY!" : "DEFEAT", size: 40, color: result.won ? Theme.gold : Theme.red)
                }
                if result.mode == .survival {
                    EmptyView()
                } else if result.won {
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: "star.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(i < shownStars ? Theme.gold : Color.white.opacity(0.2))
                                .scaleEffect(i < shownStars ? 1 : 0.7)
                        }
                    }
                } else {
                    Text("Upgrade your hamsters and try again!")
                        .font(Theme.font(14)).foregroundStyle(.white.opacity(0.85))
                    // Point at the cheapest upgrade the player can already afford (after this battle's seeds).
                    if let u = MetaUpgrade.allCases.filter({ store.canBuy($0) })
                        .min(by: { $0.cost(level: store.progress.level($0)) < $1.cost(level: store.progress.level($1)) }) {
                        Label(L10n.f("Tip: %@ for %lld 🌻", u.title, u.cost(level: store.progress.level(u))), systemImage: u.icon)
                            .font(Theme.font(12)).foregroundStyle(Theme.gold)
                    }
                }
                HStack(spacing: 16) {
                    Label(modeTitle, systemImage: "flag.fill")
                    Label("\(result.kills) kills", systemImage: "scope")
                    Label(clock(result.duration), systemImage: "clock.fill")
                }
                .font(Theme.font(12)).foregroundStyle(.white.opacity(0.8))
                if let event = LiveEvents.activeTitle() {
                    Text(event).font(Theme.font(11)).foregroundStyle(Theme.gold)
                }
                CurrencyPill(icon: "🌻", value: doubled ? result.seeds * 2 : result.seeds)
                    .scaleEffect(1.3)
                    .padding(.vertical, 4)
                HStack(spacing: 14) {
                    // No ad offer after the very first (tutorial) battle.
                    if !doubled && store.progress.battlesPlayed > 1 {
                        Button {
                            loadingAd = true
                            ads.showRewarded(placement: "double_reward") { ok in
                                loadingAd = false
                                if ok {
                                    store.addSeeds(result.seeds)
                                    Analytics.log(.adRewarded(placement: "double_reward"))
                                    withAnimation { doubled = true }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "play.rectangle.fill")
                                Text(loadingAd ? "Loading…" : "×2 Seeds")
                                if !loadingAd { Text("+\(result.seeds) 🌻").font(Theme.font(12)).opacity(0.85) }
                            }
                        }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.purple))
                        .disabled(loadingAd)
                    }
                    Button(result.won ? "Next" : "Continue", action: onContinue)
                        .buttonStyle(ChunkyButtonStyle(color: Theme.green))
                }
                .opacity(showButtons ? 1 : 0)
                .allowsHitTesting(showButtons)
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 28).fill(Theme.panel))
            .overlay(alignment: .topTrailing) {
                // Brag card for wins and survival runs — free word of mouth.
                if let img = shareImage, showButtons {
                    ShareLink(item: Image(uiImage: img), preview: SharePreview("Hamster Ages", image: Image(uiImage: img))) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 16, weight: .black)).foregroundStyle(.white)
                            .frame(width: 40, height: 40).background(Circle().fill(Theme.teal))
                    }
                    .padding(12)
                    .accessibilityLabel(Text("Share"))
                    .simultaneousGesture(TapGesture().onEnded { Analytics.log(.shareTapped(mode: result.mode.rawValue)) })
                }
            }
        }
        .onAppear {
            if result.won || result.mode == .survival {
                let renderer = ImageRenderer(content: ShareCard(result: result))
                renderer.scale = 2
                shareImage = renderer.uiImage
            }
            for i in 0..<result.stars {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + Double(i) * 0.3) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.45)) { shownStars = i + 1 }
                    Haptics.tap()
                    Sound.shared.play(i == 2 ? .evolve : .coin)
                }
            }
            // Buttons appear after the celebration so nobody taps an ad by accident.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(result.stars) * 0.3) {
                withAnimation(.easeOut(duration: 0.25)) { showButtons = true }
            }
        }
    }
}
