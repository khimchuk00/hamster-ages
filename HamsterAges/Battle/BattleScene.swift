import SpriteKit
import UIKit

/// Pure renderer: reads `BattleSimulation` state every frame and turns sim events into juice.
@MainActor
final class BattleScene: SKScene {
    private weak var controller: BattleController?
    private var sim: BattleSimulation? { controller?.sim }

    var safeInsets: UIEdgeInsets = .zero {
        didSet { if oldValue != safeInsets { layout() } }
    }

    private let panNode = SKNode()      // camera pan (world scrolls under the fixed HUD)
    private let world = SKNode()        // shakes inside panNode
    private let bgLayer = SKNode()
    private let baseLayer = SKNode()
    private let unitLayer = SKNode()
    private let fxLayer = SKNode()
    private var bgNode: SKSpriteNode?
    /// Living scenery: drifting clouds (parallax), ambient particles, foreground grass, screen vignette.
    private let cloudLayer = SKNode()
    private let ambientLayer = SKNode()
    private let fgLayer = SKNode()
    private var clouds: [(node: SKSpriteNode, speed: CGFloat)] = []
    private var vignetteNode: SKSpriteNode?
    private var baseShadows: [Side: SKSpriteNode] = [:]
    private var ambientTimer: TimeInterval = 0

    private var baseNodes: [Side: SKSpriteNode] = [:]
    private var turretNodes: [Side: [SKNode]] = [.player: [], .enemy: []]
    private var unitNodes: [Int: SKNode] = [:]
    private var bodies: [Int: SKSpriteNode] = [:]
    private var hpBars: [Int: SKSpriteNode] = [:]
    private var walking = Set<Int>()
    /// Resting tint per unit (boss / elite) that hit flashes return to.
    private var tints: [Int: (color: UIColor, blend: CGFloat)] = [:]
    private var bubbles: [Int: SKShapeNode] = [:]
    private var facingBack = Set<Int>()
    private var projectileNodes: [Int: SKSpriteNode] = [:]
    private var projectileArc: [Int: (startY: CGFloat, endY: CGFloat, arc: CGFloat, rotates: Bool)] = [:]

    private var lastTime: TimeInterval?
    private var bgEra = 0
    private var baseEra: [Side: Int] = [.player: 0, .enemy: 0]
    private var turretSignature = ""
    private var damageLabels = 0
    private var didSetup = false

    private let font = "ArialRoundedMTBold"
    private var groundY: CGFloat { max(78, size.height * 0.22) }
    private var hScale: CGFloat { min(1.9, max(0.8, size.height / 390)) }
    private var unitScale: CGFloat { 0.95 * hScale }

    /// The battlefield is wider than the screen; the camera follows the front line and can be dragged.
    private let mapScale: CGFloat = 1.6
    private var worldWidth: CGFloat { size.width * mapScale }
    private var cameraX: CGFloat = 0
    private var manualCameraUntil: TimeInterval = 0
    private var dragLastX: CGFloat?
    private var now: TimeInterval = 0
    private var endingFocusX: CGFloat?
    private var cinematicFocus: (x: CGFloat, until: TimeInterval)?
    /// Never paused: effects that must play while the battle is frozen (evolution set piece).
    private let cinemaLayer = SKNode()
    /// Screen-space effects above the world (flash, bounty tokens, confetti) — unaffected by camera pan.
    private let screenFX = SKNode()
    private var activeTokens = 0
    private var smokeTimer: TimeInterval = 0
    private var lastBaseHaptic: TimeInterval = 0
    private var lastCounterText: TimeInterval = 0

    private let minimap = SKNode()
    private var minimapBG: SKShapeNode?
    private var minimapView: SKShapeNode?
    private var minimapDots: [SKSpriteNode] = []
    private var minimapWidth: CGFloat { min(170, size.width * 0.2) }
    private var baseScale: CGFloat { 0.84 * hScale }

    init(controller: BattleController) {
        self.controller = controller
        super.init(size: CGSize(width: 844, height: 390))
        scaleMode = .resizeFill
        anchorPoint = .zero
        backgroundColor = UIColor(hex: 0x7EC8EE)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Setup & layout

    override func didMove(to view: SKView) {
        if !didSetup {
            didSetup = true
            addChild(panNode)
            panNode.addChild(world)
            cinemaLayer.zPosition = 60
            world.addChild(cinemaLayer)
            screenFX.zPosition = 300
            addChild(screenFX)
            minimap.zPosition = 200
            addChild(minimap)
            bgLayer.zPosition = -100
            cloudLayer.zPosition = -90
            ambientLayer.zPosition = 15
            baseLayer.zPosition = 10
            unitLayer.zPosition = 20
            fgLayer.zPosition = 40
            fxLayer.zPosition = 50
            [bgLayer, cloudLayer, ambientLayer, baseLayer, unitLayer, fgLayer, fxLayer].forEach(world.addChild)
            let v = SKSpriteNode(texture: tex(ArtFactory.shared.vignette()))
            v.zPosition = 250
            v.alpha = 0.32
            addChild(v)
            vignetteNode = v
            // The sim may already be past era 0 (showcase `-era`), so start from its real state.
            bgEra = sim?.state(.player).era ?? 0
            for side in Side.allCases {
                let era = sim?.state(side).era ?? 0
                baseEra[side] = era
                let n = SKSpriteNode(texture: tex(ArtFactory.shared.base(species(side), era: era)))
                n.anchorPoint = CGPoint(x: 0.5, y: 0)
                baseLayer.addChild(n)
                baseNodes[side] = n
            }
        }
        layout()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layout()
    }

    private func layout() {
        guard didSetup, size.width > 10 else { return }
        let bgSize = CGSize(width: worldWidth, height: size.height)
        // Not through `tex()`: backgrounds are evicted from ArtFactory, and an ObjectIdentifier key could be reused.
        let bg = SKSpriteNode(texture: SKTexture(image: ArtFactory.shared.background(era: bgEra, size: bgSize, groundHeight: groundY)))
        bg.anchorPoint = .zero
        bg.size = bgSize
        bgNode?.removeFromParent()
        bgLayer.addChild(bg)
        bgNode = bg

        for side in Side.allCases {
            guard let n = baseNodes[side] else { continue }
            n.setScale(baseScale)
            n.xScale = side == .player ? baseScale : -baseScale
            let w = 130 * baseScale
            let frontX = laneToScreen(BattleSimulation.baseFront(side))
            n.position = CGPoint(x: side == .player ? frontX - w / 2 + 12 : frontX + w / 2 - 12, y: groundY - 8)
            // Soft contact shadow grounds the base on the lane.
            let shadow = baseShadows[side] ?? {
                let s = SKSpriteNode(texture: tex(ArtFactory.shared.groundShadow()))
                s.zPosition = -1
                s.alpha = 0.9
                baseLayer.addChild(s)
                baseShadows[side] = s
                return s
            }()
            shadow.size = CGSize(width: w * 1.25, height: w * 0.22)
            shadow.position = CGPoint(x: n.position.x, y: groundY - 6)
        }
        turretSignature = ""
        refreshTurrets()
        buildScenery()
        layoutMinimap()
        cameraX = clampCamera(cameraX)
        panNode.position.x = -cameraX
    }

    private func species(_ side: Side) -> Species { side == .player ? .hamster : .rat }

    /// ArtFactory returns the same UIImage instance per asset, so textures are cached by image identity —
    /// creating an SKTexture from a UIImage on every spawn/shot is a measurable cost on older iPhones.
    private var textureCache: [ObjectIdentifier: SKTexture] = [:]
    private func tex(_ image: UIImage) -> SKTexture {
        let key = ObjectIdentifier(image)
        if let t = textureCache[key] { return t }
        let t = SKTexture(image: image)
        textureCache[key] = t
        return t
    }

    private func laneToScreen(_ x: Double) -> CGFloat {
        let left = safeInsets.left + 40
        let right = worldWidth - safeInsets.right - 40
        return left + CGFloat(x / GameConfig.laneLength) * (right - left)
    }

    private func unitY(_ depth: Double) -> CGFloat { groundY + CGFloat(depth) * 3 - 1 }

    // MARK: Frame

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime.map { currentTime - $0 } ?? 0
        lastTime = currentTime
        now = currentTime
        guard let controller else { return }
        controller.tick(dt)
        let frozen = controller.isFrozen
        unitLayer.isPaused = frozen
        fxLayer.isPaused = frozen
        unitLayer.speed = CGFloat(controller.speed)
        fxLayer.speed = CGFloat(controller.speed)
        sync()
        updateCamera(dt)
        updateMinimap()
        updateBaseDamage(currentTime, frozen: frozen)
        updateScenery(min(dt, 0.1), frozen: frozen)
    }

    // MARK: Scenery

    /// Clouds and foreground tufts for the current age; rebuilt on layout and on evolution.
    private func buildScenery() {
        cloudLayer.removeAllChildren()
        fgLayer.removeAllChildren()
        clouds = []
        vignetteNode?.size = CGSize(width: size.width * 1.08, height: size.height * 1.12)
        vignetteNode?.position = CGPoint(x: size.width / 2, y: size.height / 2)
        var r = SeededRandom(seed: UInt64(31 + bgEra))
        func rnd(_ a: CGFloat, _ b: CGFloat) -> CGFloat { CGFloat.random(in: a...b, using: &r) }
        let night = bgEra == 4
        for i in 0..<(Int(worldWidth / 280) + 3) {
            let c = SKSpriteNode(texture: tex(ArtFactory.shared.cloud(i)))
            let depth = rnd(0.55, 1.1)
            c.setScale(hScale * depth * 0.9)
            c.position = CGPoint(x: rnd(-100, worldWidth + 100), y: size.height * rnd(0.6, 0.86))
            c.alpha = night ? 0.12 : (bgEra == 3 ? 0.7 : 0.95) * (0.75 + 0.25 * depth)
            if night { c.color = UIColor(hex: 0xB78CFF); c.colorBlendFactor = 0.6 }
            if bgEra == 2 { c.color = UIColor(hex: 0xFFE0B2); c.colorBlendFactor = 0.35 }
            c.zPosition = depth
            cloudLayer.addChild(c)
            clouds.append((c, 4 + 9 * depth))
        }
        // Grass tufts along the front edge of the lane, slightly overlapping the troops' feet for depth.
        var x: CGFloat = rnd(10, 60)
        while x < worldWidth {
            let t = SKSpriteNode(texture: tex(ArtFactory.shared.tuft(era: bgEra, Int(rnd(0, 2.99)))))
            t.anchorPoint = CGPoint(x: 0.5, y: 0)
            t.setScale(hScale * rnd(0.65, 0.95))
            t.position = CGPoint(x: x, y: groundY - 15 * hScale - rnd(0, 4))
            fgLayer.addChild(t)
            x += rnd(55, 140) * hScale
        }
    }

    private func updateScenery(_ dt: TimeInterval, frozen: Bool) {
        // Clouds drift and sit "further away" than the lane (parallax against the camera).
        cloudLayer.position.x = cameraX * 0.55
        if !frozen {
            for c in clouds {
                c.node.position.x -= c.speed * CGFloat(dt)
                if c.node.position.x < -160 { c.node.position.x = worldWidth + 160 }
            }
        }
        ambientTimer -= dt
        guard ambientTimer <= 0, ambientLayer.children.count < 28 else { return }
        ambientTimer = 0.22
        spawnAmbient()
    }

    /// One ambient particle in view: pollen, leaves, desert dust, city soot or neon sparkles.
    private func spawnAmbient() {
        let x = cameraX + CGFloat.random(in: 0...size.width)
        let top = size.height * 0.9, ground = groundY + 6
        let n: SKSpriteNode
        let life = Double.random(in: 4...7)
        switch bgEra {
        case 1:
            n = SKSpriteNode(texture: tex(ArtFactory.shared.leaf([UIColor(hex: 0xE67E22), UIColor(hex: 0xC0392B), UIColor(hex: 0xF1C40F)].randomElement()!)))
            n.setScale(hScale * CGFloat.random(in: 0.7...1.1))
            n.position = CGPoint(x: x, y: top)
            n.run(.repeatForever(.rotate(byAngle: .pi, duration: Double.random(in: 1.2...2.2))))
            n.run(.sequence([.group([.moveBy(x: -CGFloat.random(in: 40...120), y: ground - top, duration: life),
                                     .sequence([.wait(forDuration: life - 0.8), .fadeOut(withDuration: 0.8)])]), .removeFromParent()]))
        case 3:
            n = SKSpriteNode(texture: tex(ArtFactory.shared.dot(UIColor(white: 0.35, alpha: 1), radius: 2)))
            n.setScale(hScale * CGFloat.random(in: 0.5...1))
            n.alpha = 0.5
            n.position = CGPoint(x: x, y: top)
            n.run(.sequence([.group([.moveBy(x: -CGFloat.random(in: 20...60), y: ground - top, duration: life),
                                     .sequence([.wait(forDuration: life - 0.6), .fadeOut(withDuration: 0.6)])]), .removeFromParent()]))
        case 4:
            n = SKSpriteNode(texture: tex(ArtFactory.shared.dot(UIColor(hex: 0x9FF7FF), radius: 3)))
            n.blendMode = .add
            n.setScale(hScale * CGFloat.random(in: 0.4...0.9))
            n.alpha = 0
            n.position = CGPoint(x: x, y: CGFloat.random(in: ground + 20...top))
            n.run(.sequence([.fadeAlpha(to: 0.9, duration: 0.6), .group([.moveBy(x: 0, y: 24, duration: 2), .fadeOut(withDuration: 2)]),
                             .removeFromParent()]))
        default:
            // Pollen (Stone Age) / dust motes (Gunpowder) floating up and across.
            let col = bgEra == 2 ? UIColor(hex: 0xE6C9A0) : UIColor(hex: 0xFFF6C2)
            n = SKSpriteNode(texture: tex(ArtFactory.shared.dot(col, radius: 2.5)))
            n.setScale(hScale * CGFloat.random(in: 0.5...1))
            n.alpha = 0
            n.position = CGPoint(x: x, y: CGFloat.random(in: ground...ground + size.height * 0.35))
            n.run(.sequence([.fadeAlpha(to: 0.8, duration: 0.8),
                             .group([.moveBy(x: CGFloat.random(in: -50...50), y: CGFloat.random(in: 20...60), duration: life),
                                     .sequence([.wait(forDuration: life - 1), .fadeOut(withDuration: 1)])]),
                             .removeFromParent()]))
        }
        ambientLayer.addChild(n)
    }

    // MARK: Camera

    private func clampCamera(_ x: CGFloat) -> CGFloat { min(max(0, x), max(0, worldWidth - size.width)) }

    /// Midpoint between the two front lines (own base when the field is empty).
    private func followTarget() -> CGFloat {
        if let x = endingFocusX { return x - size.width / 2 }
        if let c = cinematicFocus, now < c.until { return c.x - size.width / 2 }
        guard let sim else { return 0 }
        let mine = sim.units.filter { $0.side == .player }.map(\.x)
        let theirs = sim.units.filter { $0.side == .enemy }.map(\.x)
        if mine.isEmpty && theirs.isEmpty { return 0 }
        let pFront = mine.max() ?? BattleSimulation.baseFront(.player)
        let eFront = theirs.min() ?? BattleSimulation.baseFront(.enemy)
        return laneToScreen((pFront + eFront) / 2) - size.width / 2
    }

    private func updateCamera(_ dt: TimeInterval) {
        let cinematic = endingFocusX != nil || (cinematicFocus.map { now < $0.until } ?? false)
        if dragLastX == nil && (now > manualCameraUntil || cinematic) {
            let target = clampCamera(followTarget())
            cameraX += (target - cameraX) * CGFloat(min(1, dt * (cinematic ? 5 : 1.8)))
        }
        cameraX = clampCamera(cameraX)
        panNode.position.x = -cameraX.rounded()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        if let bg = minimapBG, bg.contains(t.location(in: minimap)) {
            jumpCamera(toMinimapX: t.location(in: minimap).x)
        }
        dragLastX = p.x
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let last = dragLastX else { return }
        let x = t.location(in: self).x
        if let bg = minimapBG, bg.contains(t.location(in: minimap)) {
            jumpCamera(toMinimapX: t.location(in: minimap).x)
        } else {
            cameraX = clampCamera(cameraX - (x - last))
        }
        dragLastX = x
        manualCameraUntil = now + 3.5
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        dragLastX = nil
        manualCameraUntil = max(manualCameraUntil, now + 3.5)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { dragLastX = nil }

    private func jumpCamera(toMinimapX x: CGFloat) {
        let w = minimapWidth
        let f = (x + w / 2) / w
        cameraX = clampCamera(f * worldWidth - size.width / 2)
        manualCameraUntil = now + 3.5
    }

    // MARK: Minimap

    private func layoutMinimap() {
        minimap.removeAllChildren()
        minimapDots.removeAll()
        let w = minimapWidth, h: CGFloat = 12
        minimap.position = CGPoint(x: size.width * 0.52, y: max(18, safeInsets.bottom + 10))
        let bg = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: h / 2)
        bg.fillColor = UIColor(white: 0, alpha: 0.45)
        bg.strokeColor = UIColor(white: 1, alpha: 0.35)
        bg.lineWidth = 1
        minimap.addChild(bg)
        minimapBG = bg
        for (side, x) in [(Side.player, -w / 2 + 4), (Side.enemy, w / 2 - 4)] {
            let b = SKSpriteNode(color: ArtFactory.palette(species(side)).team, size: CGSize(width: 5, height: h - 2))
            b.position = CGPoint(x: x, y: 0)
            minimap.addChild(b)
        }
        let view = SKShapeNode(rectOf: CGSize(width: w * size.width / worldWidth, height: h + 4), cornerRadius: 3)
        view.strokeColor = .white
        view.lineWidth = 1.5
        view.fillColor = UIColor(white: 1, alpha: 0.12)
        minimap.addChild(view)
        minimapView = view
    }

    private func updateMinimap() {
        guard let sim, let view = minimapView else { return }
        let w = minimapWidth
        view.position.x = (cameraX + size.width / 2) / worldWidth * w - w / 2
        let units = sim.units
        while minimapDots.count < units.count {
            let d = SKSpriteNode(color: .white, size: CGSize(width: 3, height: 3))
            minimap.addChild(d)
            minimapDots.append(d)
        }
        for (i, d) in minimapDots.enumerated() {
            guard i < units.count else { d.isHidden = true; continue }
            let u = units[i]
            d.isHidden = false
            d.color = u.side == .player ? UIColor(hex: 0x7FE3FF) : UIColor(hex: 0xFF8A8A)
            d.size = u.isBoss ? CGSize(width: 5, height: 5) : CGSize(width: 3, height: 3)
            d.position = CGPoint(x: laneToScreen(u.x) / worldWidth * w - w / 2, y: u.side == .player ? 1.5 : -1.5)
        }
    }

    private func sync() {
        guard let sim else { return }
        var alive = Set<Int>()
        for u in sim.units {
            alive.insert(u.id)
            let node = unitNodes[u.id] ?? makeUnitNode(u)
            node.position = CGPoint(x: laneToScreen(u.x), y: unitY(u.depth))
            if u.isMoving != walking.contains(u.id) {
                setWalking(u.id, u.isMoving)
            }
            if u.isRetreating != facingBack.contains(u.id), let body = bodies[u.id] {
                // Turn around while falling back, face the enemy again when the order changes.
                if u.isRetreating { facingBack.insert(u.id) } else { facingBack.remove(u.id) }
                body.xScale = -body.xScale
            }
            if let bar = hpBars[u.id] {
                let f = CGFloat(max(0, u.hp / u.maxHP))
                bar.parent?.isHidden = f >= 0.999 && !u.isBoss
                bar.xScale = f
            }
        }
        for (id, node) in unitNodes where !alive.contains(id) {
            if node.action(forKey: "die") == nil { node.removeFromParent() }
            forget(id)
        }

        let liveProjectiles = Set(sim.projectiles.map(\.id))
        for p in sim.projectiles {
            guard let node = projectileNodes[p.id], let arc = projectileArc[p.id] else { continue }
            let span = abs(p.targetX - p.startX)
            let t = CGFloat(span < 1 ? 1 : min(1, abs(p.x - p.startX) / span))
            let y = arc.startY + (arc.endY - arc.startY) * t + arc.arc * 4 * t * (1 - t)
            node.position = CGPoint(x: laneToScreen(p.x), y: y)
            if arc.rotates {
                let dx = (laneToScreen(p.targetX) - laneToScreen(p.startX))
                let dy = (arc.endY - arc.startY) + arc.arc * 4 * (1 - 2 * t)
                node.zRotation = atan2(dy, dx) - (dx < 0 ? .pi : 0)
            } else {
                node.zRotation += 0.25
            }
        }
        for (id, node) in projectileNodes where !liveProjectiles.contains(id) {
            node.removeFromParent()
            projectileNodes[id] = nil
            projectileArc[id] = nil
        }

        let sig = Side.allCases.map { s in sim.state(s).turrets.map { "\($0.unlocked)\($0.era ?? -1)" }.joined() }.joined(separator: "|")
        if sig != turretSignature { refreshTurrets() }
    }

    private func forget(_ id: Int) {
        unitNodes[id] = nil
        bodies[id] = nil
        hpBars[id] = nil
        walking.remove(id)
        tints[id] = nil
        bubbles[id] = nil
        facingBack.remove(id)
    }

    /// Resting colour of a unit: the Rat King is royal purple, elites carry their trait's hue.
    private func restingTint(_ u: UnitEntity) -> (color: UIColor, blend: CGFloat)? {
        if u.isBoss { return (UIColor(hex: 0xB0306A), 0.25) }
        if u.isMinion { return (UIColor(hex: 0x8BC34A), 0.35) }
        switch u.trait {
        case .armored?: return (UIColor(hex: 0x7E97B0), 0.4)
        case .plague?: return (UIColor(hex: 0x8BC34A), 0.3)
        case .swift?: return (UIColor(hex: 0xFFD54A), 0.18)
        case .medic?: return (UIColor(hex: 0xF8BBD0), 0.25)
        case .giant?: return (UIColor(hex: 0x8D6E63), 0.2)
        case .shielded?, nil: return nil
        }
    }

    private func makeUnitNode(_ u: UnitEntity) -> SKNode {
        let container = SKNode()
        container.zPosition = CGFloat(-u.depth) + (u.role == .heavy ? -0.5 : 0)
        let variant = sim?.state(u.side).loadout.variant(u.role)
        let texture = tex(ArtFactory.shared.unit(species(u.side), era: u.era, role: u.role, skin: controller?.skin ?? .classic,
                                                  variant: variant))
        let body = SKSpriteNode(texture: texture)
        body.name = "body"
        body.anchorPoint = CGPoint(x: ArtFactory.unitAnchorX(u.role), y: 0.06)
        body.setScale(unitScale * CGFloat(u.sizeScale))
        if let tint = restingTint(u) {
            body.color = tint.color
            body.colorBlendFactor = tint.blend
            tints[u.id] = tint
        }
        if u.side == .enemy { body.xScale = -abs(body.xScale) }
        body.userData = ["sy": body.yScale]
        let shadow = SKSpriteNode(texture: tex(ArtFactory.shared.groundShadow()))
        let shadowW = (u.role == .heavy ? 70 : 40) * unitScale * CGFloat(u.sizeScale)
        shadow.size = CGSize(width: shadowW, height: shadowW * 0.3)
        shadow.position = CGPoint(x: 0, y: 2)
        shadow.zPosition = -0.4
        container.addChild(shadow)
        container.addChild(body)
        if u.isBoss {
            let crown = SKSpriteNode(texture: tex(ArtFactory.shared.crown()))
            crown.setScale(hScale)
            crown.position = CGPoint(x: 0, y: body.size.height * 0.92)
            crown.zPosition = 1
            crown.run(.repeatForever(.sequence([.moveBy(x: 0, y: 3, duration: 0.4), .moveBy(x: 0, y: -3, duration: 0.4)])))
            container.addChild(crown)
        }
        if let trait = u.trait {
            let badge = SKSpriteNode(texture: tex(ArtFactory.shared.traitBadge(trait)))
            badge.setScale(hScale * 0.8)
            badge.position = CGPoint(x: 0, y: body.size.height + 13 * hScale)
            badge.zPosition = 2
            badge.run(.repeatForever(.sequence([.moveBy(x: 0, y: 2, duration: 0.5), .moveBy(x: 0, y: -2, duration: 0.5)])))
            container.addChild(badge)
            if trait == .swift {
                // Speed streaks trailing behind
                for k in 0..<2 {
                    let streak = SKSpriteNode(color: UIColor(white: 1, alpha: 0.55), size: CGSize(width: 10 * hScale, height: 1.6))
                    streak.position = CGPoint(x: (u.side == .player ? -1 : 1) * 16 * hScale, y: (12 + CGFloat(k) * 8) * hScale)
                    streak.zPosition = -0.2
                    streak.run(.repeatForever(.sequence([.fadeAlpha(to: 0.15, duration: 0.18), .fadeAlpha(to: 0.8, duration: 0.18)])))
                    container.addChild(streak)
                }
            }
            if trait == .shielded {
                let r = body.size.height * 0.62
                let bubble = SKShapeNode(ellipseOf: CGSize(width: r * 2.1, height: r * 2))
                bubble.position = CGPoint(x: 0, y: body.size.height * 0.48)
                bubble.fillColor = UIColor(hex: 0x4FC3F7, alpha: 0.16)
                bubble.strokeColor = UIColor(hex: 0xB3E5FC, alpha: 0.9)
                bubble.lineWidth = 1.6
                bubble.glowWidth = 1.5
                bubble.zPosition = 1.5
                bubble.run(.repeatForever(.sequence([.scale(to: 1.05, duration: 0.5), .scale(to: 0.97, duration: 0.5)])))
                container.addChild(bubble)
                bubbles[u.id] = bubble
            }
        }

        let barBG = SKSpriteNode(color: UIColor(white: 0, alpha: 0.45), size: CGSize(width: 24 * hScale, height: 3.5))
        barBG.position = CGPoint(x: 0, y: body.size.height + (u.isBoss ? 16 : 3))
        if u.isMinion { barBG.xScale = 0.7 }
        barBG.isHidden = true
        if u.isBoss { barBG.xScale = 2.2; barBG.yScale = 1.6 }
        // Team-coloured bars (blue vs orange is colour-blind safe).
        let bar = SKSpriteNode(color: u.side == .player ? UIColor(hex: 0x4FC3F7) : UIColor(hex: 0xFF8A3D),
                               size: CGSize(width: 24 * hScale, height: 3.5))
        bar.anchorPoint = CGPoint(x: 0, y: 0.5)
        bar.position = CGPoint(x: -12 * hScale, y: 0)
        barBG.addChild(bar)
        container.addChild(barBG)

        container.position = CGPoint(x: laneToScreen(u.x), y: unitY(u.depth))
        unitLayer.addChild(container)
        unitNodes[u.id] = container
        bodies[u.id] = body
        hpBars[u.id] = bar

        // Light units blink now and then, so the army feels alive.
        if u.role != .heavy {
            let skin = controller?.skin ?? .classic
            let open = texture
            let shut = tex(ArtFactory.shared.unit(species(u.side), era: u.era, role: u.role, skin: skin, face: .blink, variant: variant))
            let first = Double((u.id * 53) % 30) / 10
            body.run(.sequence([.wait(forDuration: first),
                                .repeatForever(.sequence([.setTexture(shut), .wait(forDuration: 0.12), .setTexture(open),
                                                          .wait(forDuration: 2.5, withRange: 3)]))]), withKey: "blink")
        }

        // Spawn pop
        body.alpha = 0
        let sy = body.yScale
        body.run(.group([.fadeIn(withDuration: 0.15), .sequence([.scaleY(to: sy * 1.2, duration: 0.08), .scaleY(to: sy, duration: 0.12)])]))
        return container
    }

    private func setWalking(_ id: Int, _ on: Bool) {
        guard let body = bodies[id] else { return }
        if on {
            walking.insert(id)
            // Bouncy hop: stretch on the way up, squash on landing.
            let sy = body.userData?["sy"] as? CGFloat ?? body.yScale
            let up = SKAction.group([.moveTo(y: 3.5 * hScale, duration: 0.16), .rotate(toAngle: 0.06, duration: 0.16),
                                     .scaleY(to: sy * 1.05, duration: 0.16)])
            let down = SKAction.group([.moveTo(y: 0, duration: 0.16), .rotate(toAngle: -0.04, duration: 0.16),
                                       .scaleY(to: sy * 0.95, duration: 0.16)])
            up.timingMode = .easeOut
            down.timingMode = .easeIn
            body.run(.repeatForever(.sequence([up, down])), withKey: "walk")
        } else {
            walking.remove(id)
            body.removeAction(forKey: "walk")
            let sy = body.userData?["sy"] as? CGFloat ?? body.yScale
            body.run(.group([.moveTo(y: 0, duration: 0.08), .rotate(toAngle: 0, duration: 0.08), .scaleY(to: sy, duration: 0.08)]))
        }
    }

    // MARK: Turrets

    func refreshTurrets() {
        guard let sim, didSetup else { return }
        turretSignature = Side.allCases.map { s in sim.state(s).turrets.map { "\($0.unlocked)\($0.era ?? -1)" }.joined() }.joined(separator: "|")
        for side in Side.allCases {
            turretNodes[side]?.forEach { $0.removeFromParent() }
            turretNodes[side] = []
            guard let base = baseNodes[side] else { continue }
            let st = sim.state(side)
            let anchors = ArtFactory.turretAnchors(era: baseEra[side] ?? 0)
            for (slot, t) in st.turrets.enumerated() {
                let pos = turretPosition(side: side, anchor: anchors[slot], base: base)
                if let era = t.era {
                    let n = SKSpriteNode(texture: tex(ArtFactory.shared.turret(era: era, species: species(side))))
                    n.anchorPoint = CGPoint(x: 0.5, y: 0.1)
                    n.setScale(baseScale * 1.05)
                    if side == .enemy { n.xScale = -baseScale * 1.05 }
                    n.position = pos
                    n.zPosition = 1
                    if sim.isOvertime { n.alpha = 0.35 }
                    baseLayer.addChild(n)
                    turretNodes[side]?.append(n)
                } else if t.unlocked {
                    let pad = SKShapeNode(rectOf: CGSize(width: 22 * hScale, height: 5 * hScale), cornerRadius: 2)
                    pad.fillColor = UIColor(white: 0.2, alpha: 0.5)
                    pad.strokeColor = .clear
                    pad.position = pos
                    pad.zPosition = 1
                    baseLayer.addChild(pad)
                    turretNodes[side]?.append(pad)
                }
            }
        }
    }

    private func turretPosition(side: Side, anchor: CGPoint, base: SKSpriteNode) -> CGPoint {
        let dx = (anchor.x - 65) * baseScale * (side == .player ? 1 : -1)
        let dy = (160 - anchor.y) * baseScale
        return CGPoint(x: base.position.x + dx, y: base.position.y + dy)
    }

    // MARK: Events → effects

    func handle(_ events: [BattleEvent]) {
        guard let sim, didSetup else { return }
        for e in events {
            switch e {
            case .attacked(let id):
                guard let body = bodies[id], let u = sim.units.first(where: { $0.id == id }) else { break }
                let d: CGFloat = u.side == .player ? 1 : -1
                if u.isRanged {
                    body.run(.sequence([.moveBy(x: -3 * d, y: 0, duration: 0.05), .moveBy(x: 3 * d, y: 0, duration: 0.1)]), withKey: "atk")
                    if u.era >= 2, let node = unitNodes[id] { muzzleFlash(at: CGPoint(x: node.position.x + d * 30 * unitScale, y: node.position.y + 18 * unitScale), era: u.era, side: u.side) }
                } else {
                    body.run(.sequence([.group([.moveBy(x: 7 * d, y: 0, duration: 0.07), .rotate(byAngle: -0.15 * d, duration: 0.07)]),
                                        .group([.moveBy(x: -7 * d, y: 0, duration: 0.12), .rotate(byAngle: 0.15 * d, duration: 0.12)])]), withKey: "atk")
                }

            case .unitHit(let id, let dmg):
                guard let body = bodies[id], let node = unitNodes[id] else { break }
                Sound.shared.play(.hit, minInterval: 0.07)
                // Restore the boss / elite tint after the flash instead of wiping it on the first hit.
                let restore = tints[id].map { SKAction.colorize(with: $0.color, colorBlendFactor: $0.blend, duration: 0.14) }
                    ?? SKAction.colorize(withColorBlendFactor: 0, duration: 0.14)
                body.run(.sequence([.colorize(with: .white, colorBlendFactor: 0.75, duration: 0), restore]), withKey: "flash")
                if body.action(forKey: "kb") == nil, let u = sim.units.first(where: { $0.id == id }), !u.isBoss {
                    let d: CGFloat = u.side == .player ? -1 : 1
                    body.run(.sequence([.moveBy(x: 3 * d * hScale, y: 0, duration: 0.04),
                                        .moveBy(x: -3 * d * hScale, y: 0, duration: 0.1)]), withKey: "kb")
                }
                if damageLabels < 14 {
                    floatText("\(Int(dmg.rounded()))", at: CGPoint(x: node.position.x, y: node.position.y + body.size.height),
                              color: .white, size: 11 * hScale, rise: 22)
                    damageLabels += 1
                    run(.wait(forDuration: 0.5)) { [weak self] in self?.damageLabels -= 1 }
                }

            case .died(let id, let x, let side, let era, let role):
                Sound.shared.play(.pop, minInterval: 0.06)
                let pos = CGPoint(x: laneToScreen(x), y: unitNodes[id]?.position.y ?? groundY)
                if let node = unitNodes[id] {
                    if role != .heavy, let body = bodies[id] {
                        body.removeAction(forKey: "blink")
                        body.texture = tex(ArtFactory.shared.unit(species(side), era: era, role: role,
                                                                  skin: controller?.skin ?? .classic, face: .dead,
                                                                  variant: sim.state(side).loadout.variant(role)))
                    }
                    node.run(.sequence([.group([.fadeOut(withDuration: 0.25), .scale(to: 0.6, duration: 0.25),
                                                .rotate(byAngle: side == .player ? 0.8 : -0.8, duration: 0.25)]),
                                        .removeFromParent()]), withKey: "die")
                    forget(id)
                }
                puff(at: CGPoint(x: pos.x, y: pos.y + 14 * hScale), color: ArtFactory.palette(species(side)).fur,
                     count: role == .heavy ? 12 : 7, spread: role == .heavy ? 34 : 22)

            case .reward(let side, let food, let x):
                if side == .player {
                    Sound.shared.play(.coin, minInterval: 0.1)
                    let p = CGPoint(x: laneToScreen(x), y: groundY + 40 * hScale)
                    if activeTokens < 6 {
                        bountyToken(Int(food), from: CGPoint(x: p.x - cameraX, y: p.y))
                    } else {
                        floatText("+\(Int(food))", at: p, color: UIColor(hex: 0xFFD54A), size: 13 * hScale, rise: 30)
                    }
                }

            case .projectileFired(let id):
                guard let p = sim.projectiles.first(where: { $0.id == id }) else { break }
                spawnProjectile(p)

            case .projectileImpact(let id, let x):
                let y = projectileNodes[id]?.position.y ?? groundY + 16
                spark(at: CGPoint(x: laneToScreen(x), y: y))

            case .turretFired(let side, let slot):
                if let nodes = turretNodes[side], slot < nodes.count {
                    let d: CGFloat = side == .player ? -1 : 1
                    nodes[slot].run(.sequence([.moveBy(x: 3 * d, y: 0, duration: 0.04), .moveBy(x: -3 * d, y: 0, duration: 0.1)]))
                }

            case .baseHit(let side, _):
                if side == .player && now - lastBaseHaptic > 1.5 {
                    lastBaseHaptic = now
                    Haptics.tap()
                }
                guard let base = baseNodes[side], base.action(forKey: "hit") == nil else { break }
                base.run(.sequence([.colorize(with: UIColor(hex: 0xFF5A5A), colorBlendFactor: 0.35, duration: 0),
                                    .moveBy(x: 2, y: 0, duration: 0.04), .moveBy(x: -4, y: 0, duration: 0.06),
                                    .moveBy(x: 2, y: 0, duration: 0.04),
                                    .colorize(withColorBlendFactor: 0, duration: 0.12)]), withKey: "hit")

            case .specialLaunched(let side, let era):
                launchSpecial(by: side, era: era)

            case .specialImpact:
                Sound.shared.play(.boom, minInterval: 0.2)
                shake(intensity: 7)

            case .evolved(let side, let era):
                baseEra[side] = era
                if let base = baseNodes[side] {
                    base.texture = tex(ArtFactory.shared.base(species(side), era: era))
                    let s = baseScale
                    base.run(.sequence([.scaleY(to: s * 1.15, duration: 0.12), .scaleY(to: s, duration: 0.2)]))
                    puff(at: CGPoint(x: base.position.x, y: base.position.y + 60 * hScale),
                         color: UIColor(hex: 0xFFF3B0), count: 16, spread: 60)
                }
                refreshTurrets()
                if side == .player {
                    crossfadeBackground(to: era)
                    Music.shared.play(.era(era))
                    Sound.shared.play(.evolve)
                }

            case .lastStand(let side):
                if let base = baseNodes[side] {
                    base.run(.repeat(.sequence([.colorize(with: UIColor(hex: 0xFFD54A), colorBlendFactor: 0.6, duration: 0.15),
                                                .colorize(withColorBlendFactor: 0, duration: 0.15)]), count: 4))
                }

            case .overtimeStarted:
                for side in Side.allCases { turretNodes[side]?.forEach { $0.run(.fadeAlpha(to: 0.35, duration: 0.4)) } }
                shake(intensity: 4)

            case .waveUp:
                shake(intensity: 3)
                Sound.shared.play(.card)

            case .bossSpawned:
                shake(intensity: 6)
                Sound.shared.play(.boom)

            case .heroAbility(let side, let ability):
                guard side == .player else { break }
                Sound.shared.play(.evolve)
                shake(intensity: 5)
                if let base = baseNodes[.player] {
                    puff(at: CGPoint(x: base.position.x + 40 * hScale, y: base.position.y + 70 * hScale),
                         color: UIColor(hex: 0xFFC83D), count: 18, spread: 70)
                }
                if ability == .volley { launchSpecial(by: .player, era: 1) }

            case .suddenDeathStarted:
                shake(intensity: 8)
                Sound.shared.play(.boom)

            case .shieldHit(let id, let left):
                guard let bubble = bubbles[id], let node = unitNodes[id] else { break }
                if left > 0 {
                    bubble.run(.sequence([.group([.scale(to: 1.18, duration: 0.05), .fadeAlpha(to: 1, duration: 0.05)]),
                                          .group([.scale(to: 1, duration: 0.15), .fadeAlpha(to: 0.4 + 0.2 * CGFloat(left), duration: 0.15)])]))
                    Sound.shared.play(.tap, minInterval: 0.08)
                    spark(at: CGPoint(x: node.position.x, y: node.position.y + bubble.position.y))
                } else {
                    bubble.removeAllActions()
                    bubble.run(.sequence([.group([.scale(to: 1.6, duration: 0.18), .fadeOut(withDuration: 0.18)]), .removeFromParent()]))
                    bubbles[id] = nil
                    puff(at: CGPoint(x: node.position.x, y: node.position.y + bubble.position.y),
                         color: UIColor(hex: 0xB3E5FC), count: 10, spread: 26)
                    Sound.shared.play(.pop)
                    floatText(L10n.t("POP!"), at: CGPoint(x: node.position.x, y: node.position.y + bubble.position.y * 2.2),
                              color: UIColor(hex: 0xB3E5FC), size: 13 * hScale, rise: 26)
                }

            case .bossWindup(let id, let x, let radius):
                bossWindup(id: id, x: x, radius: radius)

            case .bossSlam(let id, let x, let radius):
                bossSlam(id: id, x: x, radius: radius)

            case .healed(let id, let healer, let amount):
                guard let node = unitNodes[id], let body = bodies[id] else { break }
                let top = CGPoint(x: node.position.x, y: node.position.y + body.size.height * 0.6)
                if let from = unitNodes[healer], let hb = bodies[healer] {
                    let path = CGMutablePath()
                    path.move(to: CGPoint(x: from.position.x, y: from.position.y + hb.size.height * 0.7))
                    path.addLine(to: top)
                    let beam = SKShapeNode(path: path)
                    beam.strokeColor = UIColor(hex: 0xF48FB1, alpha: 0.9)
                    beam.lineWidth = 2.5
                    beam.glowWidth = 2
                    beam.zPosition = 12
                    fxLayer.addChild(beam)
                    beam.run(.sequence([.fadeOut(withDuration: 0.35), .removeFromParent()]))
                }
                puff(at: top, color: UIColor(hex: 0xF8BBD0), count: 5, spread: 14)
                floatText("+\(Int(amount.rounded()))", at: CGPoint(x: top.x, y: top.y + 10 * hScale),
                          color: UIColor(hex: 0xF48FB1), size: 11 * hScale, rise: 20)

            case .setBonus(let side, _):
                if let base = baseNodes[side] {
                    puff(at: CGPoint(x: base.position.x, y: base.position.y + 80 * hScale), color: UIColor(hex: 0xFFD54A), count: 20, spread: 70)
                }

            case .bossSummon(let id):
                if let node = unitNodes[id] {
                    puff(at: CGPoint(x: node.position.x - 30 * hScale, y: node.position.y + 20 * hScale),
                         color: UIColor(hex: 0xB0306A), count: 18, spread: 50)
                }
                shake(intensity: 5)
                Sound.shared.play(.squeak)

            case .counterHit(let id, let effective):
                guard now - lastCounterText > 0.35, let node = unitNodes[id], let body = bodies[id] else { break }
                lastCounterText = now
                floatText(effective ? L10n.t("CRUSH!") : L10n.t("RESIST"),
                          at: CGPoint(x: node.position.x, y: node.position.y + body.size.height + 12 * hScale),
                          color: effective ? UIColor(hex: 0xFFB74D) : UIColor(hex: 0xB0BEC5), size: (effective ? 14 : 11) * hScale, rise: 26)

            case .eliteSpawned(let id, _):
                if let node = unitNodes[id] {
                    let ring = SKShapeNode(ellipseOf: CGSize(width: 46 * hScale, height: 12 * hScale))
                    ring.strokeColor = UIColor(hex: 0xFFD54A)
                    ring.lineWidth = 2
                    ring.position = CGPoint(x: node.position.x, y: node.position.y + 2)
                    ring.zPosition = node.zPosition - 0.1
                    fxLayer.addChild(ring)
                    ring.run(.sequence([.group([.scale(to: 1.8, duration: 0.4), .fadeOut(withDuration: 0.4)]), .removeFromParent()]))
                }

            case .spawned, .gameOver, .reviveOffered:
                break
            }
        }
    }

    private func spawnProjectile(_ p: Projectile) {
        let texture = tex(ArtFactory.shared.projectile(era: p.era, heavy: p.isHeavy, species: species(p.side)))
        let n = SKSpriteNode(texture: texture)
        n.setScale(hScale)
        if p.side == .enemy { n.xScale = -hScale }
        n.zPosition = 30
        let startY: CGFloat
        if p.fromTurret {
            let anchor = ArtFactory.turretAnchors(era: baseEra[p.side] ?? 0)[0]
            startY = groundY - 8 + (160 - anchor.y) * baseScale + 10
        } else {
            startY = groundY + (p.isHeavy ? 26 : 22) * hScale
        }
        let endY = p.targetID == nil ? groundY + 40 * hScale : groundY + 16 * hScale
        let lobbed = p.era <= 2 && !(p.era == 2 && !p.isHeavy && !p.fromTurret)
        let dist = abs(laneToScreen(p.targetX) - laneToScreen(p.startX))
        projectileArc[p.id] = (startY, endY, lobbed ? dist * 0.14 : 0, p.era == 1 || p.era >= 3)
        n.position = CGPoint(x: laneToScreen(p.x), y: startY)
        unitLayer.addChild(n)
        projectileNodes[p.id] = n
    }

    // MARK: Juice helpers

    private func floatText(_ text: String, at pos: CGPoint, color: UIColor, size: CGFloat, rise: CGFloat) {
        let l = SKLabelNode(fontNamed: font)
        l.text = text
        l.fontSize = size
        l.fontColor = color
        l.position = pos
        l.zPosition = 60
        let shadow = SKLabelNode(fontNamed: font)
        shadow.text = text
        shadow.fontSize = size
        shadow.fontColor = UIColor(white: 0, alpha: 0.45)
        shadow.position = CGPoint(x: 1, y: -1)
        shadow.zPosition = -1
        l.addChild(shadow)
        fxLayer.addChild(l)
        l.run(.sequence([.group([.moveBy(x: CGFloat.random(in: -6...6), y: rise, duration: 0.6),
                                 .sequence([.wait(forDuration: 0.35), .fadeOut(withDuration: 0.25)])]),
                         .removeFromParent()]))
    }

    private func puff(at pos: CGPoint, color: UIColor, count: Int, spread: CGFloat) {
        let texture = tex(ArtFactory.shared.dot(.white, radius: 6))
        for i in 0..<count {
            let d = SKSpriteNode(texture: texture)
            d.color = i % 3 == 0 ? .white : color
            d.colorBlendFactor = 1
            d.setScale(CGFloat.random(in: 0.5...1.1) * hScale)
            d.position = pos
            d.zPosition = 55
            fxLayer.addChild(d)
            let a = CGFloat.random(in: 0...(2 * .pi))
            let r = CGFloat.random(in: spread * 0.4...spread) * hScale
            d.run(.sequence([.group([.moveBy(x: cos(a) * r, y: abs(sin(a)) * r * 0.8, duration: 0.4),
                                     .fadeOut(withDuration: 0.4), .scale(to: 0.1, duration: 0.4)]),
                             .removeFromParent()]))
        }
    }

    /// Telegraph: a red danger zone fills the ground in front of the king while he rears up.
    private func bossWindup(id: Int, x: Double, radius: Double) {
        let dir: CGFloat = sim?.units.first(where: { $0.id == id })?.side == .player ? 1 : -1
        let w = laneToScreen(x + Double(dir) * radius) - laneToScreen(x)
        let zone = SKShapeNode(rect: CGRect(x: min(0, w), y: -8 * hScale, width: abs(w), height: 16 * hScale), cornerRadius: 8 * hScale)
        zone.position = CGPoint(x: laneToScreen(x), y: groundY - 2)
        zone.fillColor = UIColor(hex: 0xFF3B30, alpha: 0.18)
        zone.strokeColor = UIColor(hex: 0xFF3B30, alpha: 0.9)
        zone.lineWidth = 2
        zone.zPosition = -1
        zone.name = "slam-\(id)"
        unitLayer.addChild(zone)
        let windup = GameConfig.bossSlamWindup / max(1, controller?.speed ?? 1)
        zone.run(.sequence([.repeat(.sequence([.fadeAlpha(to: 0.35, duration: windup / 8), .fadeAlpha(to: 1, duration: windup / 8)]), count: 4),
                            .removeFromParent()]))
        let warn = SKLabelNode(fontNamed: font)
        warn.text = "!"
        warn.fontSize = 30 * hScale
        warn.fontColor = UIColor(hex: 0xFF3B30)
        warn.position = CGPoint(x: laneToScreen(x) + w / 2, y: groundY + 40 * hScale)
        warn.zPosition = 20
        fxLayer.addChild(warn)
        warn.setScale(0.2)
        warn.run(.sequence([.scale(to: 1.2, duration: 0.15), .scale(to: 1, duration: 0.1), .wait(forDuration: windup - 0.4),
                            .fadeOut(withDuration: 0.15), .removeFromParent()]))
        if let body = bodies[id] {
            // Rear up: lean back and rise
            body.run(.sequence([.group([.rotate(toAngle: 0.18 * dir, duration: windup * 0.8), .moveTo(y: 10 * hScale, duration: windup * 0.8)])]), withKey: "windup")
        }
        Sound.shared.play(.card)
    }

    private func bossSlam(id: Int, x: Double, radius: Double) {
        let dir: CGFloat = sim?.units.first(where: { $0.id == id })?.side == .player ? 1 : -1
        if let body = bodies[id] {
            body.removeAction(forKey: "windup")
            body.run(.group([.rotate(toAngle: 0, duration: 0.06), .moveTo(y: 0, duration: 0.06)]))
        }
        let center = CGPoint(x: laneToScreen(x + Double(dir) * radius / 2), y: groundY)
        let w = abs(laneToScreen(x + radius) - laneToScreen(x))
        let wave = SKShapeNode(ellipseOf: CGSize(width: w * 0.4, height: 14 * hScale))
        wave.position = center
        wave.strokeColor = UIColor(hex: 0xFFE0B2)
        wave.lineWidth = 4
        wave.glowWidth = 2
        wave.zPosition = 15
        fxLayer.addChild(wave)
        wave.run(.sequence([.group([.scaleX(to: 2.6, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
        for k in 0..<4 {
            puff(at: CGPoint(x: center.x + (CGFloat(k) - 1.5) * w / 4, y: groundY + 6), color: UIColor(hex: 0xC8A27A), count: 6, spread: 26)
        }
        shake(intensity: 9)
        Sound.shared.play(.boom)
        Haptics.boom()
    }

    private func muzzleFlash(at pos: CGPoint, era: Int, side: Side) {
        let f = SKSpriteNode(texture: tex(ArtFactory.shared.dot(.white, radius: 6)))
        f.color = era >= 4 ? ArtFactory.palette(species(side)).team.blend(.white, 0.4) : UIColor(hex: 0xFFE082)
        f.colorBlendFactor = 1
        f.blendMode = .add
        f.position = pos
        f.zPosition = 56
        f.setScale(0.5 * hScale)
        fxLayer.addChild(f)
        f.run(.sequence([.group([.scale(to: 1.1 * hScale, duration: 0.06), .fadeOut(withDuration: 0.12)]), .removeFromParent()]))
    }

    private func spark(at pos: CGPoint) {
        let texture = tex(ArtFactory.shared.dot(.white, radius: 4))
        for _ in 0..<3 {
            let d = SKSpriteNode(texture: texture)
            d.color = UIColor(hex: 0xFFE082)
            d.colorBlendFactor = 1
            d.setScale(0.6 * hScale)
            d.position = pos
            d.zPosition = 55
            fxLayer.addChild(d)
            d.run(.sequence([.group([.moveBy(x: .random(in: -10...10), y: .random(in: 0...10), duration: 0.18),
                                     .fadeOut(withDuration: 0.18)]), .removeFromParent()]))
        }
    }

    private func shake(intensity: CGFloat) {
        guard Juice.shakeEnabled else { return }
        world.removeAction(forKey: "shake")
        world.position = .zero
        var seq: [SKAction] = []
        for i in 0..<6 {
            let k = intensity * CGFloat(6 - i) / 6
            seq.append(.moveTo(x: CGFloat.random(in: -k...k), duration: 0.035))
            seq.append(.moveTo(y: CGFloat.random(in: -k...k) * 0.5, duration: 0.0))
        }
        seq.append(.move(to: .zero, duration: 0.04))
        world.run(.sequence(seq), withKey: "shake")
    }

    private func launchSpecial(by side: Side, era: Int) {
        guard let sim else { return }
        let foes = sim.units.filter { $0.side == side.opponent }.map(\.x)
        let lo = side == .player ? GameConfig.laneLength * 0.3 : GameConfig.baseWidth
        let hi = side == .player ? GameConfig.laneLength - GameConfig.baseWidth : GameConfig.laneLength * 0.7
        let dir: CGFloat = side == .player ? 1 : -1
        for i in 0..<12 {
            let lx = foes.isEmpty || i >= foes.count * 2 ? Double.random(in: lo...hi) : foes[i % foes.count] + Double.random(in: -15...15)
            let target = CGPoint(x: laneToScreen(lx), y: groundY + 8)
            let delay = Double(i) * 0.04
            if era == 4 {
                let beam = SKSpriteNode(color: UIColor(hex: side == .player ? 0x7DF9FF : 0xFF7DA8), size: CGSize(width: 10 * hScale, height: size.height))
                beam.anchorPoint = CGPoint(x: 0.5, y: 0)
                beam.position = CGPoint(x: target.x, y: target.y)
                beam.alpha = 0
                beam.blendMode = .add
                beam.zPosition = 58
                fxLayer.addChild(beam)
                beam.run(.sequence([.wait(forDuration: delay + 0.35), .fadeAlpha(to: 0.9, duration: 0.15),
                                    .group([.fadeOut(withDuration: 0.35), .scaleX(to: 0.2, duration: 0.35)]),
                                    .removeFromParent()]))
                run(.wait(forDuration: delay + 0.5)) { [weak self] in
                    self?.puff(at: target, color: UIColor(hex: 0x7DF9FF), count: 6, spread: 26)
                }
            } else {
                let m = SKSpriteNode(texture: tex(ArtFactory.shared.meteor(era: era)))
                m.setScale(hScale * (era == 0 ? 1.1 : 0.8))
                m.position = CGPoint(x: target.x - dir * 140, y: size.height + 40)
                m.zPosition = 58
                fxLayer.addChild(m)
                let fall = SKAction.move(to: target, duration: GameConfig.specialDelay - delay * 0.5)
                fall.timingMode = .easeIn
                m.run(.sequence([.wait(forDuration: delay), fall, .removeFromParent()]))
                run(.wait(forDuration: delay + GameConfig.specialDelay - delay * 0.5)) { [weak self] in
                    self?.puff(at: target, color: UIColor(hex: 0xFF9F43), count: 7, spread: 30)
                }
            }
        }
    }

    private func crossfadeBackground(to era: Int) {
        bgEra = era
        let bgSize = CGSize(width: worldWidth, height: size.height)
        let bg = SKSpriteNode(texture: SKTexture(image: ArtFactory.shared.background(era: era, size: bgSize, groundHeight: groundY)))
        bg.anchorPoint = .zero
        bg.size = bgSize
        bg.alpha = 0
        bgLayer.addChild(bg)
        let old = bgNode
        bgNode = bg
        bg.run(.fadeIn(withDuration: 0.8)) { old?.removeFromParent() }
        buildScenery()
    }

    func playEnding(won: Bool) {
        let loser: Side = won ? .enemy : .player
        guard let base = baseNodes[loser] else { return }
        endingFocusX = base.position.x
        shake(intensity: 10)
        for i in 0..<5 {
            run(.wait(forDuration: Double(i) * 0.15)) { [weak self] in
                guard let self else { return }
                self.puff(at: CGPoint(x: base.position.x + CGFloat.random(in: -30...30), y: base.position.y + CGFloat.random(in: 20...90) * self.hScale),
                          color: UIColor(hex: 0xFF9F43), count: 10, spread: 50)
            }
        }
        base.run(.sequence([.wait(forDuration: 0.4), .group([.moveBy(x: 0, y: -30, duration: 0.6), .fadeAlpha(to: 0.3, duration: 0.6)])]))
        guard won, let sim else { return }
        // Victory: the army cheers (hops), confetti rains.
        for u in sim.units where u.side == .player {
            guard let body = bodies[u.id] else { continue }
            body.removeAllActions()
            let delay = Double.random(in: 0...0.25)
            let hop = SKAction.sequence([.moveBy(x: 0, y: 14 * hScale, duration: 0.18), .moveBy(x: 0, y: -14 * hScale, duration: 0.16)])
            hop.timingMode = .easeOut
            body.run(.sequence([.wait(forDuration: 0.5 + delay), .repeat(hop, count: 4)]))
        }
        unitLayer.isPaused = false
        confetti()
    }

    // MARK: Moments

    /// Evolution set piece. Runs while the battle is frozen, so everything here lives in never-paused layers.
    func playEvolution(era: Int) {
        guard let base = baseNodes[.player] else { return }
        cinematicFocus = (base.position.x + size.width * 0.25, now + 1.3)
        // White flash over the whole screen.
        let flash = SKSpriteNode(color: .white, size: CGSize(width: size.width * 2, height: size.height * 2))
        flash.position = CGPoint(x: size.width / 2, y: size.height / 2)
        flash.alpha = 0
        screenFX.addChild(flash)
        flash.run(.sequence([.wait(forDuration: 0.25), .fadeAlpha(to: 0.85, duration: 0.06),
                             .fadeOut(withDuration: 0.45), .removeFromParent()]))
        // Base swells, rings of sparkles burst around it.
        let s = baseScale
        base.run(.sequence([.wait(forDuration: 0.25),
                            .group([.scaleX(to: s * 1.18, duration: 0.15), .scaleY(to: s * 1.25, duration: 0.15)]),
                            .group([.scaleX(to: s, duration: 0.3), .scaleY(to: s, duration: 0.3)])]))
        let center = CGPoint(x: base.position.x, y: base.position.y + 70 * hScale)
        let texture = tex(ArtFactory.shared.dot(.white, radius: 6))
        for i in 0..<28 {
            let d = SKSpriteNode(texture: texture)
            d.color = i % 2 == 0 ? UIColor(hex: 0xFFE082) : ArtFactory.palette(.hamster).team.blend(.white, 0.4)
            d.colorBlendFactor = 1
            d.blendMode = .add
            d.position = center
            d.setScale(0.1)
            cinemaLayer.addChild(d)
            let a = CGFloat(i) / 28 * 2 * .pi
            let r = (90 + CGFloat.random(in: 0...30)) * hScale
            d.run(.sequence([.wait(forDuration: 0.28),
                             .group([.move(by: CGVector(dx: cos(a) * r, dy: sin(a) * r * 0.7), duration: 0.6),
                                     .scale(to: CGFloat.random(in: 0.6...1.2) * hScale, duration: 0.2),
                                     .sequence([.wait(forDuration: 0.3), .fadeOut(withDuration: 0.3)])]),
                             .removeFromParent()]))
        }
        // Every hamster on the field "puffs" into its new gear.
        if let sim {
            for u in sim.units where u.side == .player {
                guard let node = unitNodes[u.id] else { continue }
                let p = CGPoint(x: node.position.x, y: node.position.y + 20 * hScale)
                run(.wait(forDuration: 0.3)) { [weak self] in
                    self?.cinemaPuff(at: p)
                }
            }
        }
        run(.wait(forDuration: 0.3)) { [weak self] in self?.shake(intensity: 6) }
    }

    private func cinemaPuff(at pos: CGPoint) {
        let texture = tex(ArtFactory.shared.dot(.white, radius: 6))
        for _ in 0..<8 {
            let d = SKSpriteNode(texture: texture)
            d.color = UIColor(hex: 0xFFF3B0)
            d.colorBlendFactor = 1
            d.position = pos
            d.setScale(0.8 * hScale)
            cinemaLayer.addChild(d)
            let a = CGFloat.random(in: 0...(2 * .pi)), r = CGFloat.random(in: 10...26) * hScale
            d.run(.sequence([.group([.moveBy(x: cos(a) * r, y: abs(sin(a)) * r, duration: 0.35),
                                     .fadeOut(withDuration: 0.35), .scale(to: 0.1, duration: 0.35)]), .removeFromParent()]))
        }
    }

    /// Food bounty flies from the kill to the food counter at the top of the HUD.
    private func bountyToken(_ amount: Int, from p: CGPoint) {
        activeTokens += 1
        let token = SKNode()
        token.position = p
        let label = SKLabelNode(fontNamed: font)
        label.text = "+\(amount) 🌽"
        label.fontSize = 13 * hScale
        label.fontColor = UIColor(hex: 0xFFD54A)
        label.verticalAlignmentMode = .center
        let shadow = SKLabelNode(fontNamed: font)
        shadow.text = label.text
        shadow.fontSize = label.fontSize
        shadow.fontColor = UIColor(white: 0, alpha: 0.5)
        shadow.verticalAlignmentMode = .center
        shadow.position = CGPoint(x: 1, y: -1.5)
        token.addChild(shadow)
        token.addChild(label)
        screenFX.addChild(token)
        let target = CGPoint(x: size.width / 2 - 24, y: size.height - safeInsets.top - 26)
        let rise = SKAction.moveBy(x: 0, y: 26, duration: 0.25)
        rise.timingMode = .easeOut
        let fly = SKAction.move(to: target, duration: 0.5)
        fly.timingMode = .easeIn
        token.run(.sequence([rise, .group([fly, .scale(to: 0.6, duration: 0.5), .sequence([.wait(forDuration: 0.35), .fadeOut(withDuration: 0.15)])]),
                             .removeFromParent()])) { [weak self] in self?.activeTokens -= 1 }
    }

    private func confetti() {
        let colors: [UInt32] = [0xFFD54A, 0x4FC3F7, 0xFF8A65, 0x81C784, 0xBA68C8, 0xFFFFFF]
        for i in 0..<70 {
            let c = SKSpriteNode(color: UIColor(hex: colors[i % colors.count]), size: CGSize(width: 6 * hScale, height: 10 * hScale))
            c.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: size.height + CGFloat.random(in: 10...160))
            c.zRotation = CGFloat.random(in: 0...(2 * .pi))
            screenFX.addChild(c)
            let fall = SKAction.moveBy(x: CGFloat.random(in: -60...60), y: -(size.height + 200), duration: Double.random(in: 1.8...3.0))
            let spin = SKAction.rotate(byAngle: CGFloat.random(in: -8...8), duration: 2.5)
            c.run(.sequence([.wait(forDuration: 0.6 + Double.random(in: 0...0.6)), .group([fall, spin]), .removeFromParent()]))
        }
    }

    /// Damaged bases smoke (below 50%) and smoulder (below 25%).
    private func updateBaseDamage(_ t: TimeInterval, frozen: Bool) {
        guard let sim, !frozen, t - smokeTimer > 0.35 else { return }
        smokeTimer = t
        let texture = tex(ArtFactory.shared.dot(.white, radius: 8))
        for side in Side.allCases {
            guard let base = baseNodes[side] else { continue }
            let st = sim.state(side)
            let f = st.baseHP / max(1, st.baseMaxHP)
            guard f < 0.5, f > 0 else { continue }
            let p = CGPoint(x: base.position.x + CGFloat.random(in: -30...30) * hScale, y: base.position.y + CGFloat.random(in: 60...110) * hScale)
            let smoke = SKSpriteNode(texture: texture)
            smoke.color = UIColor(white: f < 0.25 ? 0.25 : 0.45, alpha: 1)
            smoke.colorBlendFactor = 1
            smoke.alpha = 0.6
            smoke.position = p
            smoke.setScale(0.5 * hScale)
            smoke.zPosition = 54
            fxLayer.addChild(smoke)
            smoke.run(.sequence([.group([.moveBy(x: CGFloat.random(in: -10...10), y: 50 * hScale, duration: 1.4),
                                         .scale(to: 1.4 * hScale, duration: 1.4), .fadeOut(withDuration: 1.4)]), .removeFromParent()]))
            if f < 0.25 {
                let ember = SKSpriteNode(texture: texture)
                ember.color = UIColor(hex: 0xFF8A3D)
                ember.colorBlendFactor = 1
                ember.blendMode = .add
                ember.position = CGPoint(x: p.x, y: p.y - 14 * hScale)
                ember.setScale(0.35 * hScale)
                ember.zPosition = 55
                fxLayer.addChild(ember)
                ember.run(.sequence([.group([.moveBy(x: 0, y: 24 * hScale, duration: 0.6), .fadeOut(withDuration: 0.6)]), .removeFromParent()]))
            }
        }
    }
}
