import UIKit

enum Species { case hamster, rat }

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

/// All game art is drawn procedurally with Core Graphics and cached — no external assets, no IP risk.
@MainActor
final class ArtFactory {
    static let shared = ArtFactory()
    private var cache: [String: UIImage] = [:]

    // MARK: Palette

    struct Palette {
        let fur, furDark, belly, innerEar, team, teamDark: UIColor
    }

    static func palette(_ s: Species) -> Palette {
        switch s {
        case .hamster:
            return Palette(fur: UIColor(hex: 0xF4A259), furDark: UIColor(hex: 0xB0642A),
                           belly: UIColor(hex: 0xFFEBCD), innerEar: UIColor(hex: 0xF5A3A3),
                           team: UIColor(hex: 0x23A8C9), teamDark: UIColor(hex: 0x15708A))
        case .rat:
            return Palette(fur: UIColor(hex: 0x9B93B5), furDark: UIColor(hex: 0x575073),
                           belly: UIColor(hex: 0xD3CDE3), innerEar: UIColor(hex: 0xF0A5B8),
                           team: UIColor(hex: 0xE04848), teamDark: UIColor(hex: 0x9C2626))
        }
    }

    static let outline = UIColor(hex: 0x3A2A22)

    // MARK: Public API

    /// Light units are drawn in a 64x64 critter frame plus room on the right for long weapons.
    static let lightUnitSize = CGSize(width: 78, height: 64)
    /// Horizontal anchor that keeps the critter's body (not the canvas) centred on the unit's lane position.
    static func unitAnchorX(_ role: UnitRole) -> CGFloat { role == .heavy ? 0.5 : 32 / lightUnitSize.width }

    func unit(_ species: Species, era: Int, role: UnitRole) -> UIImage {
        cached("u-\(species)-\(era)-\(role)") {
            let size = role == .heavy ? CGSize(width: 96, height: 80) : ArtFactory.lightUnitSize   // extra width for raised blades
            return render(size) { ctx in
                if role == .heavy {
                    self.drawHeavy(ctx, species, era)
                } else {
                    self.drawCritter(ctx, species, era: era, at: .zero, scale: 1, hat: true, weapon: role)
                }
            }
        }
    }

    func base(_ species: Species, era: Int) -> UIImage {
        cached("b-\(species)-\(era)") {
            render(CGSize(width: 130, height: 160)) { ctx in self.drawBase(ctx, species, era) }
        }
    }

    /// Where turret slots sit on the base image (in image points, origin top-left).
    static func turretAnchors(era: Int) -> [CGPoint] {
        let topY: [CGFloat] = [44, 30, 34, 74, 24]
        return [CGPoint(x: 62, y: topY[era]), CGPoint(x: 104, y: 96)]
    }

    func turret(era: Int, species: Species) -> UIImage {
        cached("t-\(era)-\(species)") {
            render(CGSize(width: 44, height: 34)) { ctx in self.drawTurret(ctx, era, species) }
        }
    }

    func projectile(era: Int, heavy: Bool, species: Species) -> UIImage {
        cached("p-\(era)-\(heavy)-\(species)") {
            let team = ArtFactory.palette(species).team
            switch (era, heavy) {
            case (0, _):
                return self.render(CGSize(width: 12, height: 12)) { _ in
                    self.fill(UIBezierPath(ovalIn: CGRect(x: 1, y: 1, width: 10, height: 10)), UIColor(hex: 0x8D8D8D), stroke: UIColor(hex: 0x555555))
                }
            case (1, _):
                return self.render(CGSize(width: 22, height: 6)) { _ in
                    self.fill(UIBezierPath(rect: CGRect(x: 0, y: 2.2, width: 16, height: 1.6)), UIColor(hex: 0x7A4B26))
                    let tip = UIBezierPath()
                    tip.move(to: CGPoint(x: 15, y: 0)); tip.addLine(to: CGPoint(x: 22, y: 3)); tip.addLine(to: CGPoint(x: 15, y: 6)); tip.close()
                    self.fill(tip, UIColor(hex: 0x9AA4AE))
                    self.fill(UIBezierPath(rect: CGRect(x: 0, y: 0.5, width: 4, height: 5)), team)
                }
            case (2, _), (3, true):
                let r: CGFloat = heavy ? 14 : 10
                return self.render(CGSize(width: r, height: r)) { _ in
                    self.fill(UIBezierPath(ovalIn: CGRect(x: 0.5, y: 0.5, width: r - 1, height: r - 1)), UIColor(hex: 0x2B2B2B))
                    self.fill(UIBezierPath(ovalIn: CGRect(x: r * 0.25, y: r * 0.2, width: r * 0.25, height: r * 0.25)), UIColor(white: 1, alpha: 0.5))
                }
            case (3, false):
                return self.render(CGSize(width: 12, height: 5)) { _ in
                    self.fill(UIBezierPath(roundedRect: CGRect(x: 0, y: 0.5, width: 12, height: 4), cornerRadius: 2), UIColor(hex: 0xFFD54A))
                }
            default:
                let w: CGFloat = heavy ? 26 : 20
                return self.render(CGSize(width: w, height: 10)) { ctx in
                    ctx.cgContext.setShadow(offset: .zero, blur: 4, color: team.cgColor)
                    self.fill(UIBezierPath(roundedRect: CGRect(x: 3, y: 3, width: w - 6, height: 4), cornerRadius: 2), UIColor.white.blend(team, 0.35))
                }
            }
        }
    }

    /// Portrait for a collectible general: a hamster with a cape, era gear and (legendary) a crown.
    func general(_ g: GeneralID) -> UIImage {
        cached("g-\(g.rawValue)") {
            render(CGSize(width: 80, height: 80)) { ctx in
                let cape = UIColor(hex: g.capeColor)
                let capePath = UIBezierPath()
                capePath.move(to: CGPoint(x: 26, y: 40))
                capePath.addQuadCurve(to: CGPoint(x: 10, y: 72), controlPoint: CGPoint(x: 8, y: 52))
                capePath.addLine(to: CGPoint(x: 44, y: 72))
                capePath.addQuadCurve(to: CGPoint(x: 44, y: 40), controlPoint: CGPoint(x: 50, y: 56))
                capePath.close()
                self.fill(capePath, cape, stroke: ArtFactory.outline, width: 1.5)
                self.drawCritter(ctx, .hamster, era: g.portraitEra, at: CGPoint(x: 8, y: 10), scale: 1,
                                 hat: g.rarity != .legendary, weapon: g.portraitRole)
                if g.rarity == .legendary {
                    let crown = UIBezierPath()
                    crown.move(to: CGPoint(x: 24, y: 34)); crown.addLine(to: CGPoint(x: 22, y: 20))
                    crown.addLine(to: CGPoint(x: 30, y: 27)); crown.addLine(to: CGPoint(x: 36, y: 16))
                    crown.addLine(to: CGPoint(x: 42, y: 27)); crown.addLine(to: CGPoint(x: 50, y: 20))
                    crown.addLine(to: CGPoint(x: 48, y: 34)); crown.close()
                    self.fill(crown, UIColor(hex: 0xFFC83D), stroke: ArtFactory.outline, width: 1.4)
                    self.fill(self.circle(36, 28, 2.2), cape)
                }
            }
        }
    }

    func crown() -> UIImage {
        cached("crown") {
            render(CGSize(width: 30, height: 20)) { _ in
                let p = UIBezierPath()
                p.move(to: CGPoint(x: 3, y: 18)); p.addLine(to: CGPoint(x: 1, y: 4))
                p.addLine(to: CGPoint(x: 9, y: 11)); p.addLine(to: CGPoint(x: 15, y: 1))
                p.addLine(to: CGPoint(x: 21, y: 11)); p.addLine(to: CGPoint(x: 29, y: 4))
                p.addLine(to: CGPoint(x: 27, y: 18)); p.close()
                self.fill(p, UIColor(hex: 0xFFC83D), stroke: ArtFactory.outline, width: 1.4)
                self.fill(self.circle(15, 13, 2.4), UIColor(hex: 0xE04848))
            }
        }
    }

    func dot(_ color: UIColor, radius: CGFloat) -> UIImage {
        cached("d-\(color.description)-\(radius)") {
            render(CGSize(width: radius * 2, height: radius * 2)) { _ in
                self.fill(UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2)), color)
            }
        }
    }

    func meteor(era: Int) -> UIImage {
        cached("m-\(era)") {
            render(CGSize(width: 30, height: 30)) { ctx in
                let colors: [UInt32] = [0xFF7A1A, 0x8B5A2B, 0x2B2B2B, 0x4B5320, 0x7DF9FF]
                ctx.cgContext.setShadow(offset: .zero, blur: 8, color: UIColor(hex: 0xFFB347).cgColor)
                self.fill(UIBezierPath(ovalIn: CGRect(x: 5, y: 5, width: 20, height: 20)), UIColor(hex: colors[era]))
                self.fill(UIBezierPath(ovalIn: CGRect(x: 9, y: 8, width: 7, height: 6)), UIColor(white: 1, alpha: 0.45))
            }
        }
    }

    func background(era: Int, size rawSize: CGSize, groundHeight: CGFloat) -> UIImage {
        let size = CGSize(width: max(64, rawSize.width), height: max(groundHeight + 64, rawSize.height))
        let key = "bg-\(era)-\(Int(size.width))x\(Int(size.height))-\(Int(groundHeight))"
        return cached(key) {
            render(size, scale: 2) { ctx in self.drawBackground(ctx, era: era, size: size, groundHeight: groundHeight) }
        }
    }

    // MARK: Helpers

    private func cached(_ key: String, _ make: () -> UIImage) -> UIImage {
        if let img = cache[key] { return img }
        let img = make()
        cache[key] = img
        return img
    }

    private func render(_ size: CGSize, scale: CGFloat = 3, _ draw: (UIGraphicsImageRendererContext) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image(actions: draw)
    }

    private func fill(_ path: UIBezierPath, _ color: UIColor, stroke: UIColor? = nil, width: CGFloat = 1.6) {
        color.setFill()
        path.fill()
        if let stroke {
            stroke.setStroke()
            path.lineWidth = width
            path.lineJoinStyle = .round
            path.stroke()
        }
    }

    private func line(_ from: CGPoint, _ to: CGPoint, _ color: UIColor, width: CGFloat) {
        let p = UIBezierPath()
        p.move(to: from)
        p.addLine(to: to)
        p.lineWidth = width
        p.lineCapStyle = .round
        color.setStroke()
        p.stroke()
    }

    private func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> UIBezierPath {
        UIBezierPath(ovalIn: CGRect(x: x, y: y, width: w, height: h))
    }

    private func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> UIBezierPath {
        UIBezierPath(ovalIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    }

    // MARK: Critters (local 64x64 frame, facing right)

    private func drawCritter(_ ctx: UIGraphicsImageRendererContext, _ s: Species, era: Int, at origin: CGPoint,
                             scale: CGFloat, hat: Bool, weapon: UnitRole?) {
        let c = ctx.cgContext
        let p = ArtFactory.palette(s)
        let ol = ArtFactory.outline
        let light = p.fur.blend(.white, 0.32)
        c.saveGState()
        c.translateBy(x: origin.x, y: origin.y)
        c.scaleBy(x: scale, y: scale)

        // Feet (back foot darker for depth)
        fill(oval(17, 53, 12, 8), p.furDark.blend(.black, 0.15), stroke: ol, width: 1.2)
        fill(oval(34, 53.5, 13, 8), p.furDark, stroke: ol, width: 1.2)

        let body: UIBezierPath
        if s == .rat {
            // Segmented tail
            let tail = UIBezierPath()
            tail.move(to: CGPoint(x: 13, y: 48))
            tail.addCurve(to: CGPoint(x: 1, y: 22), controlPoint1: CGPoint(x: -3, y: 50), controlPoint2: CGPoint(x: 9, y: 32))
            tail.lineWidth = 4.2; tail.lineCapStyle = .round
            ol.setStroke(); tail.stroke()
            tail.lineWidth = 2.6
            p.innerEar.blend(p.furDark, 0.25).setStroke(); tail.stroke()
            // Big ears behind the head
            for (cx, cy, r) in [(22.0, 23.0, 9.5), (35.0, 20.5, 8.5)] as [(CGFloat, CGFloat, CGFloat)] {
                let ear = circle(cx, cy, r)
                gradient(ear, light, p.fur)
                stroke(ear, ol, 1.8)
                fill(circle(cx + 0.5, cy + 0.5, r * 0.55), p.innerEar)
            }
            // Body with a pointy snout merged in
            body = UIBezierPath()
            body.move(to: CGPoint(x: 9, y: 46))
            body.addCurve(to: CGPoint(x: 30, y: 25), controlPoint1: CGPoint(x: 8, y: 33), controlPoint2: CGPoint(x: 18, y: 25))
            body.addCurve(to: CGPoint(x: 61, y: 39), controlPoint1: CGPoint(x: 42, y: 25), controlPoint2: CGPoint(x: 52, y: 32))
            body.addCurve(to: CGPoint(x: 46, y: 47), controlPoint1: CGPoint(x: 62, y: 44), controlPoint2: CGPoint(x: 52, y: 46))
            body.addCurve(to: CGPoint(x: 29, y: 59), controlPoint1: CGPoint(x: 47, y: 55), controlPoint2: CGPoint(x: 39, y: 59))
            body.addCurve(to: CGPoint(x: 9, y: 46), controlPoint1: CGPoint(x: 17, y: 59), controlPoint2: CGPoint(x: 10, y: 54))
            body.close()
        } else {
            for (cx, cy) in [(19.5, 26.0), (37.0, 23.0)] as [(CGFloat, CGFloat)] {
                let ear = circle(cx, cy, 6.8)
                gradient(ear, light, p.fur)
                stroke(ear, ol, 1.8)
                fill(circle(cx, cy + 0.4, 3.6), p.innerEar)
            }
            body = oval(8, 23, 46, 37)
        }

        // Body: soft top-left light, darker underside, then a rim shadow on the back.
        gradient(body, light, p.fur, from: CGPoint(x: 20, y: 24), to: CGPoint(x: 30, y: 52))
        c.saveGState()
        body.addClip()
        fill(oval(-6, 40, 30, 30), p.furDark.withAlphaComponent(0.35))
        fill(oval(22, 40, 26, 21), p.belly)
        drawOutfit(era: era, palette: p, hasHat: hat)
        c.restoreGState()
        stroke(body, ol, 2)

        // Fur tuft
        let tuft = UIBezierPath()
        tuft.move(to: CGPoint(x: 25, y: 25)); tuft.addLine(to: CGPoint(x: 27, y: 18.5))
        tuft.addLine(to: CGPoint(x: 29.5, y: 24)); tuft.addLine(to: CGPoint(x: 32, y: 18))
        tuft.addLine(to: CGPoint(x: 34, y: 24.5))
        if !hat { fill(tuft, light, stroke: ol, width: 1.2) }

        if s == .rat {
            // Squinting, angry eye with a red iris
            fill(oval(39, 29.5, 10, 8), .white, stroke: ol, width: 1.2)
            fill(circle(45, 33.5, 2.8), UIColor(hex: 0xC62828))
            fill(circle(45.4, 33.6, 1.4), UIColor(hex: 0x1D1A22))
            fill(circle(46.2, 32.6, 0.7), .white)
            line(CGPoint(x: 37.5, y: 27.5), CGPoint(x: 49, y: 31), ol, width: 2.6)          // heavy brow
            fill(circle(60.5, 39, 2.6), UIColor(hex: 0xC2185B), stroke: ol, width: 0.8)       // nose
            fill(UIBezierPath(roundedRect: CGRect(x: 52.5, y: 42.5, width: 2.6, height: 3.6), cornerRadius: 0.6), .white, stroke: ol, width: 0.7)
            fill(UIBezierPath(roundedRect: CGRect(x: 55.2, y: 42.2, width: 2.6, height: 3.4), cornerRadius: 0.6), .white, stroke: ol, width: 0.7)
            let wc = UIColor(white: 0.3, alpha: 0.8)
            line(CGPoint(x: 56, y: 39), CGPoint(x: 64, y: 36), wc, width: 0.7)
            line(CGPoint(x: 56, y: 40.5), CGPoint(x: 64, y: 41.5), wc, width: 0.7)
        } else {
            // Puffy cheek pouch + blush
            let cheek = oval(39, 38.5, 15, 12)
            gradient(cheek, light, p.fur.blend(.white, 0.1))
            stroke(cheek, ol, 1.2)
            fill(oval(42, 43, 8, 4.5), UIColor(hex: 0xFF8A80, alpha: 0.55))
            // Big shiny eye
            fill(oval(38.5, 29, 10, 11), .white, stroke: ol, width: 1.3)
            fill(circle(44.2, 35, 3.4), UIColor(hex: 0x2A1E1A))
            fill(circle(45.4, 33.4, 1.3), .white)
            fill(circle(43, 36.8, 0.6), UIColor(white: 1, alpha: 0.8))
            // Nose, mouth, whiskers
            fill(circle(53.5, 38.5, 2.1), UIColor(hex: 0xE5737A), stroke: ol, width: 0.8)
            let mouth = UIBezierPath()
            mouth.move(to: CGPoint(x: 50.5, y: 41.5))
            mouth.addQuadCurve(to: CGPoint(x: 53, y: 42), controlPoint: CGPoint(x: 51.6, y: 43.4))
            mouth.addQuadCurve(to: CGPoint(x: 55.5, y: 41.2), controlPoint: CGPoint(x: 54.5, y: 43.2))
            mouth.lineWidth = 1; mouth.lineCapStyle = .round
            ol.setStroke(); mouth.stroke()
            let wc = UIColor(white: 0.35, alpha: 0.65)
            line(CGPoint(x: 55, y: 38.5), CGPoint(x: 62, y: 36.5), wc, width: 0.7)
            line(CGPoint(x: 55, y: 40), CGPoint(x: 62, y: 40.5), wc, width: 0.7)
        }

        if hat { drawHat(ctx, era: era, palette: p) }
        if let w = weapon { drawWeapon(ctx, era: era, role: w, palette: p) }
        // Arm in front of the weapon handle
        let arm = oval(40.5, 44, 11, 9)
        gradient(arm, light, p.fur)
        stroke(arm, ol, 1.4)
        c.restoreGState()
    }

    /// Era clothing, drawn clipped to the body so it follows the silhouette. Team colour sits on the belt
    /// so both armies stay readable at a glance.
    private func drawOutfit(era: Int, palette p: Palette, hasHat: Bool) {
        let ol = ArtFactory.outline
        switch era {
        case 0: // fur pelt over one shoulder
            let pelt = UIBezierPath()
            pelt.move(to: CGPoint(x: 14, y: 36)); pelt.addLine(to: CGPoint(x: 24, y: 32))
            pelt.addLine(to: CGPoint(x: 48, y: 58)); pelt.addLine(to: CGPoint(x: 36, y: 62)); pelt.close()
            fill(pelt, UIColor(hex: 0x9C6A3F), stroke: ol, width: 1)
            for i in 0..<3 { fill(circle(25 + CGFloat(i) * 7, 42 + CGFloat(i) * 6, 1.6), UIColor(hex: 0x6E4523)) }
            fill(UIBezierPath(rect: CGRect(x: 0, y: 50, width: 64, height: 3.5)), p.team)
        case 1: // chainmail + tabard
            fill(UIBezierPath(rect: CGRect(x: 0, y: 47, width: 64, height: 20)), UIColor(hex: 0xA7B0BA))
            for row in 0..<3 { for col in 0..<9 {
                fill(circle(4 + CGFloat(col) * 7 + CGFloat(row % 2) * 3.5, 50 + CGFloat(row) * 4, 1.3), UIColor(hex: 0x7F8A96))
            } }
            fill(UIBezierPath(rect: CGRect(x: 21, y: 34, width: 20, height: 30)), p.team, stroke: p.teamDark, width: 1.2)
            fill(UIBezierPath(rect: CGRect(x: 29.5, y: 36, width: 3, height: 26)), UIColor(hex: 0xF2C14E))
            fill(UIBezierPath(rect: CGRect(x: 23, y: 43, width: 16, height: 3)), UIColor(hex: 0xF2C14E))
        case 2: // coat with cross belts
            fill(UIBezierPath(rect: CGRect(x: 0, y: 40, width: 64, height: 30)), p.team.blend(.black, 0.12))
            line(CGPoint(x: 16, y: 38), CGPoint(x: 44, y: 62), UIColor(hex: 0xF4F1E8), width: 3)
            line(CGPoint(x: 44, y: 38), CGPoint(x: 18, y: 62), UIColor(hex: 0xF4F1E8), width: 3)
            fill(circle(30, 50, 2.4), UIColor(hex: 0xF2C14E), stroke: ol, width: 0.7)
            fill(UIBezierPath(rect: CGRect(x: 0, y: 40, width: 64, height: 2)), p.teamDark)
        case 3: // camo vest + team armband
            fill(UIBezierPath(rect: CGRect(x: 0, y: 39, width: 64, height: 30)), UIColor(hex: 0x6B7B3A))
            for (x, y, w) in [(14.0, 44.0, 9.0), (30.0, 50.0, 11.0), (20.0, 56.0, 8.0), (40.0, 44.0, 7.0)] as [(CGFloat, CGFloat, CGFloat)] {
                fill(oval(x, y, w, w * 0.6), UIColor(hex: 0x4E5A28))
            }
            fill(UIBezierPath(roundedRect: CGRect(x: 32, y: 46, width: 9, height: 7), cornerRadius: 1.5), UIColor(hex: 0x56632C), stroke: ol, width: 0.8)
            fill(UIBezierPath(rect: CGRect(x: 0, y: 39, width: 64, height: 3)), p.team)
        default: // sleek suit with a glowing team stripe
            fill(UIBezierPath(rect: CGRect(x: 0, y: 38, width: 64, height: 30)), UIColor(hex: 0xE3E8F0))
            fill(UIBezierPath(rect: CGRect(x: 0, y: 52, width: 64, height: 10)), UIColor(hex: 0xC5CCD8))
            if let c = UIGraphicsGetCurrentContext() {
                c.saveGState()
                c.setShadow(offset: .zero, blur: 4, color: p.team.cgColor)
                fill(UIBezierPath(rect: CGRect(x: 0, y: 46, width: 64, height: 3)), p.team)
                c.restoreGState()
            }
            fill(circle(30, 42.5, 2.2), p.team.blend(.white, 0.4))
        }
    }

    private func gradient(_ path: UIBezierPath, _ top: UIColor, _ bottom: UIColor, from: CGPoint? = nil, to: CGPoint? = nil) {
        guard let c = UIGraphicsGetCurrentContext() else { return }
        let b = path.bounds
        c.saveGState()
        path.addClip()
        if let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1]) {
            c.drawLinearGradient(g, start: from ?? CGPoint(x: b.minX + b.width * 0.3, y: b.minY),
                                 end: to ?? CGPoint(x: b.midX, y: b.maxY), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        c.restoreGState()
    }

    private func stroke(_ path: UIBezierPath, _ color: UIColor, _ width: CGFloat) {
        color.setStroke()
        path.lineWidth = width
        path.lineJoinStyle = .round
        path.stroke()
    }

    /// Soft ground shadow drawn under every unit by the battle scene.
    func groundShadow() -> UIImage {
        cached("shadow") {
            render(CGSize(width: 40, height: 12)) { ctx in
                let c = ctx.cgContext
                let colors = [UIColor(white: 0, alpha: 0.32).cgColor, UIColor(white: 0, alpha: 0).cgColor] as CFArray
                if let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1]) {
                    c.saveGState()
                    c.translateBy(x: 20, y: 6)
                    c.scaleBy(x: 1, y: 0.3)
                    c.drawRadialGradient(g, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 20, options: [])
                    c.restoreGState()
                }
            }
        }
    }

    private func drawHat(_ ctx: UIGraphicsImageRendererContext, era: Int, palette p: Palette) {
        let ol = ArtFactory.outline
        let gold = UIColor(hex: 0xF2C14E)
        switch era {
        case 0: // headband with trailing tails + a feather
            let tails = UIBezierPath()
            tails.move(to: CGPoint(x: 15, y: 28)); tails.addQuadCurve(to: CGPoint(x: 3, y: 23), controlPoint: CGPoint(x: 9, y: 22))
            tails.addLine(to: CGPoint(x: 6, y: 29)); tails.addQuadCurve(to: CGPoint(x: 3, y: 35), controlPoint: CGPoint(x: 6, y: 32))
            tails.addQuadCurve(to: CGPoint(x: 15, y: 31), controlPoint: CGPoint(x: 9, y: 35)); tails.close()
            shade(tails, p.team, width: 1)
            shade(UIBezierPath(roundedRect: CGRect(x: 13, y: 26.5, width: 34, height: 5.5), cornerRadius: 2.7), p.team, width: 1)
            let feather = UIBezierPath()
            feather.move(to: CGPoint(x: 29, y: 27)); feather.addQuadCurve(to: CGPoint(x: 26, y: 6), controlPoint: CGPoint(x: 21, y: 15))
            feather.addQuadCurve(to: CGPoint(x: 29, y: 27), controlPoint: CGPoint(x: 33, y: 14)); feather.close()
            shade(feather, UIColor(hex: 0x6AB04C), width: 1)
            line(CGPoint(x: 28.5, y: 26), CGPoint(x: 26.3, y: 8), UIColor(hex: 0x3E7A2B), width: 0.7)
        case 1: // kettle helm with rivets, nasal guard and plume
            let plume = UIBezierPath()
            plume.move(to: CGPoint(x: 27, y: 18)); plume.addQuadCurve(to: CGPoint(x: 14, y: 6), controlPoint: CGPoint(x: 26, y: 5))
            plume.addQuadCurve(to: CGPoint(x: 33, y: 18), controlPoint: CGPoint(x: 26, y: 12)); plume.close()
            shade(plume, p.team, width: 1)
            let dome = UIBezierPath(arcCenter: CGPoint(x: 31, y: 33), radius: 16.5, startAngle: .pi, endAngle: 0, clockwise: true)
            dome.close()
            shade(dome, UIColor(hex: 0xB4BEC8), width: 1.5)
            shade(UIBezierPath(roundedRect: CGRect(x: 13.5, y: 30, width: 35, height: 4.5), cornerRadius: 2), UIColor(hex: 0x8C98A4), width: 1)
            for x in [18.0, 25.0, 32.0, 39.0, 45.0] as [CGFloat] { fill(circle(x, 32.2, 0.9), UIColor(hex: 0xEEF2F5)) }
            shade(UIBezierPath(roundedRect: CGRect(x: 43, y: 33, width: 3.2, height: 8), cornerRadius: 1.2), UIColor(hex: 0x8C98A4), width: 0.8)
            line(CGPoint(x: 22, y: 21), CGPoint(x: 27, y: 18.5), UIColor(white: 1, alpha: 0.75), width: 1.4)
        case 2: // tricorn with gold trim and cockade
            let hat = UIBezierPath()
            hat.move(to: CGPoint(x: 11, y: 29))
            hat.addQuadCurve(to: CGPoint(x: 31, y: 11), controlPoint: CGPoint(x: 15, y: 13))
            hat.addQuadCurve(to: CGPoint(x: 51, y: 29), controlPoint: CGPoint(x: 47, y: 13))
            hat.addQuadCurve(to: CGPoint(x: 11, y: 29), controlPoint: CGPoint(x: 31, y: 22))
            shade(hat, UIColor(hex: 0x33365A), width: 1.5)
            let trim = UIBezierPath()
            trim.move(to: CGPoint(x: 12.5, y: 28)); trim.addQuadCurve(to: CGPoint(x: 49.5, y: 28), controlPoint: CGPoint(x: 31, y: 21))
            trim.lineWidth = 1.8; gold.setStroke(); trim.stroke()
            gem(40, 20.5, 3.6, p.team)
            fill(circle(40, 20.5, 1.2), .white)
        case 3: // steel helmet with netting and team band
            let dome = UIBezierPath(arcCenter: CGPoint(x: 31, y: 32), radius: 17.5, startAngle: .pi, endAngle: 0, clockwise: true)
            dome.close()
            shade(dome, UIColor(hex: 0x6B7B3A), width: 1.5)
            for i in 0..<4 { line(CGPoint(x: 18 + CGFloat(i) * 7, y: 18 + (i % 2 == 0 ? 2 : 0)), CGPoint(x: 22 + CGFloat(i) * 7, y: 31), UIColor(hex: 0x3F4A1E, alpha: 0.6), width: 0.7) }
            fill(UIBezierPath(rect: CGRect(x: 15, y: 24, width: 32, height: 3.2)), p.team)
            shade(UIBezierPath(roundedRect: CGRect(x: 10.5, y: 30, width: 41, height: 4.5), cornerRadius: 2.2), UIColor(hex: 0x56632C), width: 1)
            line(CGPoint(x: 21, y: 20), CGPoint(x: 27, y: 17), UIColor(white: 1, alpha: 0.45), width: 1.6)
        default: // sci-fi helmet with a glowing visor and antenna
            let dome = UIBezierPath(arcCenter: CGPoint(x: 31, y: 33), radius: 16.5, startAngle: .pi, endAngle: 0, clockwise: true)
            dome.close()
            shade(dome, UIColor(hex: 0xE6EBF2), outline: UIColor(hex: 0x6E7A8A), width: 1.5, light: 0.7, dark: 0.12)
            line(CGPoint(x: 24, y: 18), CGPoint(x: 19, y: 6), UIColor(hex: 0x7C8796), width: 1.6)
            gem(19, 6, 2.8, p.team)
            fill(UIBezierPath(rect: CGRect(x: 15, y: 27, width: 32, height: 2.4)), p.team)
            ctx.cgContext.saveGState()
            ctx.cgContext.setShadow(offset: .zero, blur: 5, color: UIColor(hex: 0x5EF2FF).cgColor)
            let visor = UIBezierPath(roundedRect: CGRect(x: 35, y: 29, width: 18, height: 9.5), cornerRadius: 4.5)
            gradient(visor, UIColor(hex: 0xC8FBFF), UIColor(hex: 0x2BB8D6))
            stroke(visor, UIColor(hex: 0x1E8FA6), 1)
            ctx.cgContext.restoreGState()
            line(CGPoint(x: 38, y: 31.5), CGPoint(x: 43, y: 31.5), UIColor(white: 1, alpha: 0.85), width: 1.2)
        }
    }

    // MARK: Weapons (critter frame; the hand sits at ~(46, 48))

    /// Shaded fill + outline in one go.
    private func shade(_ path: UIBezierPath, _ base: UIColor, outline: UIColor = ArtFactory.outline, width: CGFloat = 1.1,
                       light: CGFloat = 0.45, dark: CGFloat = 0.18) {
        gradient(path, base.blend(.white, light), base.blend(.black, dark))
        stroke(path, outline, width)
    }

    /// Straight blade along +x from `from` to `to` (local coords), with a fuller and a bright edge.
    private func blade(from x0: CGFloat, to x1: CGFloat, width w: CGFloat, steel: UIColor) {
        let b = UIBezierPath()
        b.move(to: CGPoint(x: x0, y: -w / 2)); b.addLine(to: CGPoint(x: x1 - w * 1.2, y: -w / 2))
        b.addLine(to: CGPoint(x: x1, y: 0)); b.addLine(to: CGPoint(x: x1 - w * 1.2, y: w / 2))
        b.addLine(to: CGPoint(x: x0, y: w / 2)); b.close()
        gradient(b, .white, steel, from: CGPoint(x: x0, y: -w / 2), to: CGPoint(x: x0, y: w / 2))
        stroke(b, ArtFactory.outline, 1.1)
        line(CGPoint(x: x0 + 2, y: 0), CGPoint(x: x1 - w * 2, y: 0), steel.blend(.black, 0.3), width: w * 0.22)   // fuller
        line(CGPoint(x: x0 + 2, y: -w / 2 + 0.7), CGPoint(x: x1 - w * 1.4, y: -w / 2 + 0.7), UIColor(white: 1, alpha: 0.9), width: 0.7)
    }

    private func gem(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ color: UIColor) {
        let g = circle(x, y, r)
        gradient(g, color.blend(.white, 0.55), color.blend(.black, 0.2))
        stroke(g, ArtFactory.outline, 0.7)
        fill(circle(x - r * 0.35, y - r * 0.35, r * 0.3), UIColor(white: 1, alpha: 0.85))
    }

    private func grip(from x0: CGFloat, to x1: CGFloat, height h: CGFloat, color: UIColor) {
        let g = UIBezierPath(roundedRect: CGRect(x: x0, y: -h / 2, width: x1 - x0, height: h), cornerRadius: h * 0.35)
        shade(g, color, width: 0.9)
        var x = x0 + 1.6
        while x < x1 - 0.8 { line(CGPoint(x: x, y: -h / 2 + 0.4), CGPoint(x: x + 1.2, y: h / 2 - 0.4), color.blend(.black, 0.4), width: 0.6); x += 2.2 }
    }

    private func drawWeapon(_ ctx: UIGraphicsImageRendererContext, era: Int, role: UnitRole, palette p: Palette) {
        let c = ctx.cgContext
        let ol = ArtFactory.outline
        let steel = UIColor(hex: 0xB9C4CF), gold = UIColor(hex: 0xF2C14E), wood = UIColor(hex: 0x9C6A3F), leather = UIColor(hex: 0x6B3F22)
        if role == .melee {
            c.saveGState()
            c.translateBy(x: 46, y: 48.5)
            c.rotate(by: -1.08)          // raised, pointing up-forward
            switch era {
            case 0: // stone axe lashed to a wooden haft
                let haft = UIBezierPath(roundedRect: CGRect(x: -4, y: -2.2, width: 38, height: 4.4), cornerRadius: 2)
                shade(haft, wood)
                let head = UIBezierPath()
                head.move(to: CGPoint(x: 24, y: -2)); head.addLine(to: CGPoint(x: 27, y: -12))
                head.addLine(to: CGPoint(x: 34, y: -15)); head.addLine(to: CGPoint(x: 37, y: -9))
                head.addLine(to: CGPoint(x: 35, y: -2)); head.close()
                shade(head, UIColor(hex: 0x9AA1A6), width: 1.2)
                line(CGPoint(x: 28, y: -11), CGPoint(x: 33, y: -6), UIColor(hex: 0x6F767B), width: 0.8)       // chip facet
                line(CGPoint(x: 31, y: -13), CGPoint(x: 35, y: -10), UIColor(white: 1, alpha: 0.6), width: 0.8)
                for i in 0..<3 { line(CGPoint(x: 24 + CGFloat(i) * 3.4, y: -3), CGPoint(x: 26 + CGFloat(i) * 3.4, y: 3), UIColor(hex: 0xD9B77E), width: 1.3) }
            case 1: // knight's longsword
                gem(-4, 0, 2.6, p.team)                                                   // pommel
                grip(from: -2, to: 7, height: 4, color: leather)
                let guardBar = UIBezierPath()
                guardBar.move(to: CGPoint(x: 7, y: -8)); guardBar.addQuadCurve(to: CGPoint(x: 7, y: 8), controlPoint: CGPoint(x: 11, y: 0))
                guardBar.addLine(to: CGPoint(x: 9.6, y: 8)); guardBar.addQuadCurve(to: CGPoint(x: 9.6, y: -8), controlPoint: CGPoint(x: 13.5, y: 0))
                guardBar.close()
                shade(guardBar, gold, width: 0.9)
                blade(from: 10, to: 42, width: 5.6, steel: steel)
                gem(10.5, 0, 1.7, p.team)
            case 2: // cavalry sabre with a basket guard
                grip(from: -3, to: 6, height: 4, color: UIColor(hex: 0x2B2B2B))
                let basket = UIBezierPath()
                basket.move(to: CGPoint(x: 6, y: -5)); basket.addQuadCurve(to: CGPoint(x: -3, y: 6), controlPoint: CGPoint(x: 6, y: 9))
                basket.lineWidth = 3.4; ol.setStroke(); basket.stroke()
                basket.lineWidth = 2; gold.setStroke(); basket.stroke()
                let s = UIBezierPath()
                s.move(to: CGPoint(x: 6, y: -2.6)); s.addQuadCurve(to: CGPoint(x: 42, y: -9), controlPoint: CGPoint(x: 26, y: -1))
                s.addQuadCurve(to: CGPoint(x: 6, y: 2.6), controlPoint: CGPoint(x: 26, y: 5)); s.close()
                gradient(s, .white, steel, from: CGPoint(x: 6, y: -3), to: CGPoint(x: 6, y: 3))
                stroke(s, ol, 1.1)
                let edge = UIBezierPath()
                edge.move(to: CGPoint(x: 8, y: -1.8)); edge.addQuadCurve(to: CGPoint(x: 38, y: -7.4), controlPoint: CGPoint(x: 25, y: -0.6))
                edge.lineWidth = 0.7; UIColor(white: 1, alpha: 0.9).setStroke(); edge.stroke()
                fill(UIBezierPath(roundedRect: CGRect(x: 5, y: -4.5, width: 2.6, height: 9), cornerRadius: 1), gold, stroke: ol, width: 0.7)
            case 3: // machete
                grip(from: -3, to: 8, height: 5, color: UIColor(hex: 0x3A3A3A))
                fill(UIBezierPath(rect: CGRect(x: 7.5, y: -4, width: 2.2, height: 8)), UIColor(hex: 0x555B60), stroke: ol, width: 0.7)
                let m = UIBezierPath()
                m.move(to: CGPoint(x: 9.5, y: -2.8)); m.addLine(to: CGPoint(x: 34, y: -3.6))
                m.addQuadCurve(to: CGPoint(x: 37, y: 3.6), controlPoint: CGPoint(x: 39, y: -1))
                m.addLine(to: CGPoint(x: 9.5, y: 2.8)); m.close()
                gradient(m, UIColor(hex: 0xF4F6F8), UIColor(hex: 0x8E979F), from: CGPoint(x: 10, y: -3), to: CGPoint(x: 10, y: 3))
                stroke(m, ol, 1.1)
                line(CGPoint(x: 11, y: -2), CGPoint(x: 33, y: -2.8), UIColor(white: 1, alpha: 0.9), width: 0.7)
            default: // plasma sword
                grip(from: -3, to: 7, height: 4.6, color: UIColor(hex: 0x5A6270))
                fill(UIBezierPath(roundedRect: CGRect(x: 6, y: -5.5, width: 3.4, height: 11), cornerRadius: 1.5), UIColor(hex: 0xD3DAE4), stroke: ol, width: 0.8)
                c.saveGState()
                c.setShadow(offset: .zero, blur: 7, color: p.team.cgColor)
                fill(UIBezierPath(roundedRect: CGRect(x: 9, y: -3.4, width: 34, height: 6.8), cornerRadius: 3.4), p.team.blend(.white, 0.25))
                c.restoreGState()
                fill(UIBezierPath(roundedRect: CGRect(x: 10, y: -1.4, width: 31, height: 2.8), cornerRadius: 1.4), .white)
                gem(-3.5, 0, 2.2, p.team)
            }
            c.restoreGState()
        } else {
            switch era {
            case 0: // forked slingshot loaded with a pebble
                let fork = UIBezierPath()
                fork.move(to: CGPoint(x: 45, y: 52)); fork.addLine(to: CGPoint(x: 50, y: 41))
                fork.move(to: CGPoint(x: 50, y: 41)); fork.addLine(to: CGPoint(x: 46, y: 31))
                fork.move(to: CGPoint(x: 50, y: 41)); fork.addLine(to: CGPoint(x: 57, y: 33))
                fork.lineCapStyle = .round
                fork.lineWidth = 4.4; ol.setStroke(); fork.stroke()
                fork.lineWidth = 2.6; wood.setStroke(); fork.stroke()
                line(CGPoint(x: 46, y: 31), CGPoint(x: 51, y: 36), UIColor(hex: 0xC0392B), width: 1.2)
                line(CGPoint(x: 57, y: 33), CGPoint(x: 51, y: 36), UIColor(hex: 0xC0392B), width: 1.2)
                let rock = circle(51.5, 36.5, 3.4)
                shade(rock, UIColor(hex: 0x9A9A9A))
            case 1: // recurve bow, arrow nocked
                let bow = UIBezierPath()
                bow.move(to: CGPoint(x: 47, y: 27)); bow.addQuadCurve(to: CGPoint(x: 53, y: 32), controlPoint: CGPoint(x: 52, y: 27))
                bow.addQuadCurve(to: CGPoint(x: 53, y: 58), controlPoint: CGPoint(x: 62, y: 45))
                bow.addQuadCurve(to: CGPoint(x: 47, y: 63), controlPoint: CGPoint(x: 52, y: 63))
                bow.lineCapStyle = .round
                bow.lineWidth = 4.6; ol.setStroke(); bow.stroke()
                bow.lineWidth = 2.8; UIColor(hex: 0xA0673A).setStroke(); bow.stroke()
                fill(UIBezierPath(roundedRect: CGRect(x: 55.5, y: 43, width: 4, height: 6), cornerRadius: 1.5), leather)
                line(CGPoint(x: 47.5, y: 28), CGPoint(x: 40, y: 46), UIColor(white: 0.95, alpha: 1), width: 0.8)
                line(CGPoint(x: 40, y: 46), CGPoint(x: 47.5, y: 62), UIColor(white: 0.95, alpha: 1), width: 0.8)
                line(CGPoint(x: 38, y: 46), CGPoint(x: 64, y: 46), UIColor(hex: 0x7A4B26), width: 1.4)
                let tip = UIBezierPath()
                tip.move(to: CGPoint(x: 62, y: 43.6)); tip.addLine(to: CGPoint(x: 66, y: 46)); tip.addLine(to: CGPoint(x: 62, y: 48.4)); tip.close()
                shade(tip, steel, width: 0.6)
                let fl = UIBezierPath()
                fl.move(to: CGPoint(x: 38, y: 46)); fl.addLine(to: CGPoint(x: 34, y: 43)); fl.addLine(to: CGPoint(x: 41, y: 46))
                fl.addLine(to: CGPoint(x: 34, y: 49)); fl.close()
                fill(fl, p.team, stroke: ol, width: 0.6)
            case 2: // flintlock musket with brass bands
                let stock = UIBezierPath()
                stock.move(to: CGPoint(x: 27, y: 44)); stock.addLine(to: CGPoint(x: 44, y: 43))
                stock.addLine(to: CGPoint(x: 44, y: 48)); stock.addLine(to: CGPoint(x: 27, y: 53)); stock.close()
                shade(stock, wood)
                let barrel = UIBezierPath(rect: CGRect(x: 40, y: 41.6, width: 26, height: 3.6))
                shade(barrel, UIColor(hex: 0x4A4F55), width: 0.9)
                for x in [47.0, 56.0] as [CGFloat] { fill(UIBezierPath(rect: CGRect(x: x, y: 41.2, width: 2, height: 4.4)), gold, stroke: ol, width: 0.5) }
                fill(UIBezierPath(rect: CGRect(x: 40, y: 39, width: 3, height: 3)), UIColor(hex: 0x4A4F55), stroke: ol, width: 0.6)   // flint hammer
            case 3: // assault rifle with magazine and scope
                let stock = UIBezierPath(roundedRect: CGRect(x: 27, y: 42, width: 13, height: 8), cornerRadius: 2)
                shade(stock, UIColor(hex: 0x5B4A36))
                let body = UIBezierPath(roundedRect: CGRect(x: 38, y: 40.5, width: 18, height: 6.5), cornerRadius: 1.5)
                shade(body, UIColor(hex: 0x3A3F44))
                shade(UIBezierPath(rect: CGRect(x: 55, y: 42, width: 11, height: 3)), UIColor(hex: 0x2A2E33), width: 0.8)
                let mag = UIBezierPath()
                mag.move(to: CGPoint(x: 46, y: 47)); mag.addLine(to: CGPoint(x: 50.5, y: 47))
                mag.addLine(to: CGPoint(x: 52, y: 55)); mag.addLine(to: CGPoint(x: 48, y: 55.5)); mag.close()
                shade(mag, UIColor(hex: 0x2A2E33), width: 0.8)
                shade(UIBezierPath(roundedRect: CGRect(x: 42, y: 36.5, width: 11, height: 3.6), cornerRadius: 1.8), UIColor(hex: 0x2A2E33), width: 0.8)
                fill(circle(53, 38.3, 1.1), UIColor(hex: 0x7FD6FF))
            default: // plasma rifle
                let gun = UIBezierPath(roundedRect: CGRect(x: 30, y: 39, width: 30, height: 10), cornerRadius: 4.5)
                shade(gun, UIColor(hex: 0xE3E8F0), outline: p.teamDark, width: 1.2, light: 0.6, dark: 0.12)
                fill(UIBezierPath(roundedRect: CGRect(x: 34, y: 42.5, width: 20, height: 2.6), cornerRadius: 1.3), p.team)
                shade(UIBezierPath(roundedRect: CGRect(x: 40, y: 48, width: 6, height: 6), cornerRadius: 1.5), UIColor(hex: 0x5A6270), width: 0.8)
                c.saveGState()
                c.setShadow(offset: .zero, blur: 6, color: p.team.cgColor)
                fill(circle(61, 44, 3.4), p.team.blend(.white, 0.35))
                c.restoreGState()
            }
        }
    }

    // MARK: Heavy units (96x80, facing right)

    private func drawHeavy(_ ctx: UIGraphicsImageRendererContext, _ s: Species, _ era: Int) {
        let c = ctx.cgContext
        let p = ArtFactory.palette(s)
        let ol = ArtFactory.outline
        let gold = UIColor(hex: 0xF2C14E), wood = UIColor(hex: 0x9C6A3F)
        switch era {
        case 0: // Boulder Brute: big critter, skull helmet, giant stone maul raised overhead
            drawCritter(ctx, s, era: 0, at: CGPoint(x: 4, y: -2), scale: 1.28, hat: false, weapon: nil)
            let skull = UIBezierPath(arcCenter: CGPoint(x: 44, y: 39), radius: 19, startAngle: .pi, endAngle: 0, clockwise: true)
            skull.close()
            shade(skull, UIColor(hex: 0xF2EAD8), width: 1.6)
            for (x, y) in [(30.0, 18.0), (54.0, 18.0)] as [(CGFloat, CGFloat)] {
                let horn = UIBezierPath()
                horn.move(to: CGPoint(x: x - 4, y: y + 8)); horn.addQuadCurve(to: CGPoint(x: x + (x < 40 ? -6 : 6), y: y - 8), controlPoint: CGPoint(x: x + (x < 40 ? -8 : 8), y: y + 2))
                horn.addQuadCurve(to: CGPoint(x: x + 4, y: y + 8), controlPoint: CGPoint(x: x, y: y))
                horn.close()
                shade(horn, UIColor(hex: 0xEDE3CC), width: 1.2)
            }
            fill(oval(36, 28, 6, 5), UIColor(hex: 0x3B2F2A)); fill(oval(46, 28, 6, 5), UIColor(hex: 0x3B2F2A))
            c.saveGState()
            c.translateBy(x: 64, y: 62)
            c.rotate(by: -1.2)
            shade(UIBezierPath(roundedRect: CGRect(x: -4, y: -3, width: 40, height: 6), cornerRadius: 3), wood, width: 1.2)
            let head = UIBezierPath(roundedRect: CGRect(x: 26, y: -13, width: 16, height: 26), cornerRadius: 6)
            shade(head, UIColor(hex: 0x9AA1A6), width: 1.6)
            line(CGPoint(x: 30, y: -9), CGPoint(x: 38, y: -4), UIColor(white: 1, alpha: 0.5), width: 1.2)
            for i in 0..<3 { line(CGPoint(x: 24 + CGFloat(i) * 2.5, y: -4), CGPoint(x: 24 + CGFloat(i) * 2.5, y: 4), UIColor(hex: 0xD9B77E), width: 1.6) }
            c.restoreGState()
            fill(oval(54, 52, 13, 11), p.fur.blend(.white, 0.2), stroke: ol, width: 1.4)          // fist on the haft
        case 1: // Iron Knight: lance with pennant, kite shield, plated critter
            line(CGPoint(x: 34, y: 56), CGPoint(x: 95, y: 42), ol, width: 5.2)
            line(CGPoint(x: 34, y: 56), CGPoint(x: 95, y: 42), wood, width: 3.4)
            let tip = UIBezierPath()
            tip.move(to: CGPoint(x: 84, y: 41.5)); tip.addLine(to: CGPoint(x: 96, y: 41.8)); tip.addLine(to: CGPoint(x: 85, y: 47.5)); tip.close()
            shade(tip, UIColor(hex: 0xC9D1D9), width: 0.8)
            let pennant = UIBezierPath()
            pennant.move(to: CGPoint(x: 72, y: 45)); pennant.addLine(to: CGPoint(x: 82, y: 36))
            pennant.addLine(to: CGPoint(x: 80, y: 41)); pennant.addLine(to: CGPoint(x: 86, y: 39)); pennant.addLine(to: CGPoint(x: 76, y: 48)); pennant.close()
            shade(pennant, p.team, width: 0.9)
            drawCritter(ctx, s, era: 1, at: CGPoint(x: 6, y: 4), scale: 1.18, hat: true, weapon: nil)
            let shield = UIBezierPath()
            shield.move(to: CGPoint(x: 54, y: 39)); shield.addLine(to: CGPoint(x: 78, y: 39))
            shield.addQuadCurve(to: CGPoint(x: 66, y: 77), controlPoint: CGPoint(x: 80, y: 66))
            shield.addQuadCurve(to: CGPoint(x: 54, y: 39), controlPoint: CGPoint(x: 52, y: 66)); shield.close()
            shade(shield, p.team, width: 1.8)
            let rim = UIBezierPath()
            rim.move(to: CGPoint(x: 56.5, y: 41.5)); rim.addLine(to: CGPoint(x: 75.5, y: 41.5))
            rim.addQuadCurve(to: CGPoint(x: 66, y: 73), controlPoint: CGPoint(x: 77, y: 64))
            rim.addQuadCurve(to: CGPoint(x: 56.5, y: 41.5), controlPoint: CGPoint(x: 55, y: 64)); rim.close()
            rim.lineWidth = 1.6; gold.setStroke(); rim.stroke()
            let chevron = UIBezierPath()
            chevron.move(to: CGPoint(x: 58, y: 50)); chevron.addLine(to: CGPoint(x: 66, y: 58)); chevron.addLine(to: CGPoint(x: 74, y: 50))
            chevron.lineWidth = 3.4; chevron.lineCapStyle = .round; gold.setStroke(); chevron.stroke()
            gem(66, 64, 2.6, UIColor(hex: 0xFFFFFF))
        case 2: // bronze cannon on a wooden carriage, gunner with a lit fuse
            drawCritter(ctx, s, era: 2, at: CGPoint(x: -6, y: 14), scale: 0.95, hat: true, weapon: nil)
            shade(UIBezierPath(roundedRect: CGRect(x: 26, y: 54, width: 40, height: 9), cornerRadius: 3), wood, width: 1.2)   // carriage
            c.saveGState()
            c.translateBy(x: 42, y: 50)
            c.rotate(by: -0.14)
            let barrel = UIBezierPath()
            barrel.move(to: CGPoint(x: 0, y: -10)); barrel.addLine(to: CGPoint(x: 44, y: -7.5))
            barrel.addLine(to: CGPoint(x: 44, y: 7.5)); barrel.addLine(to: CGPoint(x: 0, y: 10))
            barrel.addQuadCurve(to: CGPoint(x: 0, y: -10), controlPoint: CGPoint(x: -8, y: 0)); barrel.close()
            gradient(barrel, UIColor(hex: 0xF0C77A), UIColor(hex: 0x8A5A1E), from: CGPoint(x: 0, y: -10), to: CGPoint(x: 0, y: 10))
            stroke(barrel, ol, 1.6)
            for x in [10.0, 30.0] as [CGFloat] { shade(UIBezierPath(rect: CGRect(x: x, y: -10, width: 3.5, height: 20)), UIColor(hex: 0xC99A45), width: 0.9) }
            shade(UIBezierPath(roundedRect: CGRect(x: 42, y: -10, width: 6, height: 20), cornerRadius: 2), UIColor(hex: 0xC99A45), width: 1.1)
            fill(oval(44.5, -5, 3, 10), UIColor(hex: 0x1E1A16))
            line(CGPoint(x: 4, y: -7), CGPoint(x: 40, y: -5.4), UIColor(white: 1, alpha: 0.55), width: 1.4)
            c.restoreGState()
            let wheel = circle(48, 63, 14)
            shade(wheel, wood, width: 1.8)
            for i in 0..<8 {
                let a = CGFloat(i) * .pi / 4
                line(CGPoint(x: 48, y: 63), CGPoint(x: 48 + cos(a) * 12, y: 63 + sin(a) * 12), UIColor(hex: 0x5E3A1E), width: 1.8)
            }
            let tire = circle(48, 63, 12.6)
            tire.lineWidth = 2.2; UIColor(hex: 0x4A4F55).setStroke(); tire.stroke()
            gem(48, 63, 3.4, UIColor(hex: 0x8A8F96))
            // lit fuse
            line(CGPoint(x: 30, y: 52), CGPoint(x: 35, y: 41), UIColor(hex: 0x7A4B26), width: 1.4)
            c.saveGState()
            c.setShadow(offset: .zero, blur: 5, color: UIColor(hex: 0xFFB347).cgColor)
            fill(circle(35, 40, 2.4), UIColor(hex: 0xFFD54A))
            c.restoreGState()
        case 3: // tank with a commander in the hatch
            drawCritter(ctx, s, era: 3, at: CGPoint(x: 26, y: -8), scale: 0.62, hat: true, weapon: nil)
            shade(UIBezierPath(roundedRect: CGRect(x: 60, y: 27.5, width: 35, height: 7), cornerRadius: 2), UIColor(hex: 0x56632C), width: 1.3)   // gun
            shade(UIBezierPath(roundedRect: CGRect(x: 88, y: 26, width: 7, height: 10), cornerRadius: 2), UIColor(hex: 0x4E5A28), width: 1.1)
            let turret = UIBezierPath(roundedRect: CGRect(x: 28, y: 20, width: 40, height: 22), cornerRadius: 10)
            shade(turret, UIColor(hex: 0x6E7F3C), width: 1.8)
            shade(UIBezierPath(roundedRect: CGRect(x: 36, y: 18, width: 16, height: 5), cornerRadius: 2), UIColor(hex: 0x56632C), width: 1)  // hatch
            let hull = UIBezierPath()
            hull.move(to: CGPoint(x: 2, y: 42)); hull.addLine(to: CGPoint(x: 86, y: 40)); hull.addLine(to: CGPoint(x: 94, y: 52))
            hull.addLine(to: CGPoint(x: 4, y: 56)); hull.close()
            shade(hull, UIColor(hex: 0x7A8B45), width: 1.8)
            fill(UIBezierPath(rect: CGRect(x: 8, y: 46, width: 76, height: 3.6)), p.team)
            star(at: CGPoint(x: 48, y: 31), r: 5.5, color: UIColor.white.blend(p.team, 0.25))
            let track = UIBezierPath(roundedRect: CGRect(x: 1, y: 54, width: 92, height: 22), cornerRadius: 11)
            shade(track, UIColor(hex: 0x3A3C30), width: 1.8)
            for i in 0..<6 {
                let w = circle(12 + CGFloat(i) * 14, 65, 6)
                shade(w, UIColor(hex: 0x7D806D), width: 1.1)
                fill(circle(12 + CGFloat(i) * 14, 65, 2), UIColor(hex: 0x3A3C30))
            }
            for i in 0..<15 { line(CGPoint(x: 5 + CGFloat(i) * 6, y: 55), CGPoint(x: 5 + CGFloat(i) * 6, y: 57.5), UIColor(hex: 0x1F201A), width: 1.2) }
        default: // mech with a critter pilot
            let leg = UIColor(hex: 0x8E99A8)
            for (hip, foot) in [(CGPoint(x: 40, y: 54), CGPoint(x: 28, y: 73)), (CGPoint(x: 54, y: 54), CGPoint(x: 64, y: 73))] {
                line(hip, foot, ol, width: 9)
                line(hip, foot, leg, width: 6.5)
                c.saveGState()
                c.setShadow(offset: .zero, blur: 4, color: p.team.cgColor)
                fill(circle((hip.x + foot.x) / 2, (hip.y + foot.y) / 2, 3.2), p.team.blend(.white, 0.3), stroke: ol, width: 0.8)
                c.restoreGState()
                shade(UIBezierPath(roundedRect: CGRect(x: foot.x - 10, y: 71.5, width: 20, height: 7), cornerRadius: 3), UIColor(hex: 0x5A6270), width: 1.1)
            }
            let torso = UIBezierPath(roundedRect: CGRect(x: 18, y: 16, width: 58, height: 42), cornerRadius: 14)
            shade(torso, UIColor(hex: 0xD9DFE8), outline: UIColor(hex: 0x5E6A7A), width: 2, light: 0.6, dark: 0.15)
            fill(UIBezierPath(rect: CGRect(x: 22, y: 50, width: 50, height: 4)), p.team)
            fill(circle(46, 34, 15), UIColor(hex: 0x10263A, alpha: 0.35))
            drawCritter(ctx, s, era: 4, at: CGPoint(x: 29, y: 17), scale: 0.5, hat: false, weapon: nil)
            let glass = circle(46, 34, 15)
            gradient(glass, UIColor(hex: 0xBFF8FF, alpha: 0.45), UIColor(hex: 0x5EF2FF, alpha: 0.15))
            stroke(glass, UIColor(hex: 0x1E8FA6), 1.8)
            line(CGPoint(x: 38, y: 25), CGPoint(x: 43, y: 22), UIColor(white: 1, alpha: 0.8), width: 1.6)
            // shoulder cannon
            shade(UIBezierPath(roundedRect: CGRect(x: 62, y: 30, width: 30, height: 11), cornerRadius: 5), UIColor(hex: 0xAAB4C2), outline: UIColor(hex: 0x5E6A7A), width: 1.4)
            fill(UIBezierPath(rect: CGRect(x: 68, y: 34.5, width: 18, height: 2)), p.team)
            c.saveGState()
            c.setShadow(offset: .zero, blur: 7, color: p.team.cgColor)
            fill(circle(92, 35.5, 4), p.team.blend(.white, 0.35))
            c.restoreGState()
        }
    }

    private func star(at center: CGPoint, r: CGFloat, color: UIColor) {
        let path = UIBezierPath()
        for i in 0..<10 {
            let a = -CGFloat.pi / 2 + CGFloat(i) * .pi / 5
            let rr = i % 2 == 0 ? r : r * 0.45
            let pt = CGPoint(x: center.x + cos(a) * rr, y: center.y + sin(a) * rr)
            i == 0 ? path.move(to: pt) : path.addLine(to: pt)
        }
        path.close()
        fill(path, color, stroke: ArtFactory.outline, width: 0.8)
    }

    // MARK: Bases (130x160, facing right)

    private func drawBase(_ ctx: UIGraphicsImageRendererContext, _ s: Species, _ era: Int) {
        let c = ctx.cgContext
        let p = ArtFactory.palette(s)
        let ol = ArtFactory.outline
        let wood = UIColor(hex: 0xA97142)
        func flag(_ x: CGFloat, _ top: CGFloat, _ bottom: CGFloat) {
            line(CGPoint(x: x, y: bottom), CGPoint(x: x, y: top), ol, width: 4)
            line(CGPoint(x: x, y: bottom), CGPoint(x: x, y: top), UIColor(hex: 0x8D6A4A), width: 2.4)
            let f = UIBezierPath()
            f.move(to: CGPoint(x: x, y: top + 1)); f.addQuadCurve(to: CGPoint(x: x + 24, y: top + 6), controlPoint: CGPoint(x: x + 12, y: top - 3))
            f.addLine(to: CGPoint(x: x + 20, y: top + 10))
            f.addQuadCurve(to: CGPoint(x: x, y: top + 15), controlPoint: CGPoint(x: x + 10, y: top + 17)); f.close()
            shade(f, p.team, width: 1.1)
            fill(circle(x, top, 2), UIColor(hex: 0xF2C14E), stroke: ol, width: 0.6)
        }
        func glowWindow(_ r: CGRect) {
            c.saveGState()
            c.setShadow(offset: .zero, blur: 5, color: UIColor(hex: 0xFFC857).cgColor)
            fill(UIBezierPath(roundedRect: r, cornerRadius: min(r.width, r.height) * 0.3), UIColor(hex: 0xFFD27A), stroke: ol, width: 1)
            c.restoreGState()
        }
        switch era {
        case 0: // rock cave with a torch
            let mound = UIBezierPath()
            mound.move(to: CGPoint(x: 0, y: 160))
            mound.addCurve(to: CGPoint(x: 62, y: 46), controlPoint1: CGPoint(x: 0, y: 90), controlPoint2: CGPoint(x: 22, y: 46))
            mound.addCurve(to: CGPoint(x: 130, y: 160), controlPoint1: CGPoint(x: 104, y: 46), controlPoint2: CGPoint(x: 130, y: 100))
            mound.close()
            shade(mound, UIColor(hex: 0x8F7F70), width: 2.4, light: 0.3, dark: 0.25)
            for (x, y, w, h) in [(14.0, 82.0, 22.0, 13.0), (78.0, 68.0, 26.0, 14.0), (30.0, 118.0, 20.0, 12.0), (54.0, 58.0, 14.0, 9.0)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                shade(oval(x, y, w, h), UIColor(hex: 0x7A6A5B), width: 1, light: 0.2, dark: 0.2)
            }
            fill(oval(36, 49, 30, 11), UIColor(hex: 0x6AB04C), stroke: ol, width: 1)            // moss
            let door = UIBezierPath()
            door.move(to: CGPoint(x: 68, y: 160)); door.addQuadCurve(to: CGPoint(x: 122, y: 160), controlPoint: CGPoint(x: 95, y: 80)); door.close()
            gradient(door, UIColor(hex: 0x1C1512), UIColor(hex: 0x4A3B33), from: CGPoint(x: 95, y: 110), to: CGPoint(x: 95, y: 160))
            stroke(door, ol, 2)
            line(CGPoint(x: 72, y: 160), CGPoint(x: 80, y: 120), wood, width: 4)
            line(CGPoint(x: 118, y: 160), CGPoint(x: 110, y: 120), wood, width: 4)
            // torch
            line(CGPoint(x: 64, y: 132), CGPoint(x: 62, y: 112), UIColor(hex: 0x6B4A2B), width: 3.2)
            c.saveGState()
            c.setShadow(offset: .zero, blur: 10, color: UIColor(hex: 0xFF9F1A).cgColor)
            let flame = UIBezierPath()
            flame.move(to: CGPoint(x: 62, y: 114)); flame.addQuadCurve(to: CGPoint(x: 61, y: 99), controlPoint: CGPoint(x: 55, y: 107))
            flame.addQuadCurve(to: CGPoint(x: 62, y: 114), controlPoint: CGPoint(x: 69, y: 106)); flame.close()
            gradient(flame, UIColor(hex: 0xFFF3B0), UIColor(hex: 0xFF7A1A))
            c.restoreGState()
            flag(28, 22, 64)
        case 1: // stone keep
            let wall = UIBezierPath(rect: CGRect(x: 16, y: 44, width: 98, height: 116))
            shade(wall, UIColor(hex: 0xBDB8AD), width: 2.2, light: 0.3, dark: 0.18)
            for i in 0..<5 {
                shade(UIBezierPath(rect: CGRect(x: 14 + CGFloat(i) * 21.5, y: 30, width: 15, height: 17)), UIColor(hex: 0xBDB8AD), width: 2, light: 0.3, dark: 0.1)
            }
            for row in 0..<5 { for col in 0..<4 {
                let off: CGFloat = row % 2 == 0 ? 0 : 12
                fill(UIBezierPath(roundedRect: CGRect(x: 22 + CGFloat(col) * 24 + off, y: 56 + CGFloat(row) * 19, width: 18, height: 2.2), cornerRadius: 1), UIColor(hex: 0x958F83))
            } }
            let door = UIBezierPath()
            door.move(to: CGPoint(x: 70, y: 160)); door.addLine(to: CGPoint(x: 70, y: 122))
            door.addQuadCurve(to: CGPoint(x: 106, y: 122), controlPoint: CGPoint(x: 88, y: 98)); door.addLine(to: CGPoint(x: 106, y: 160)); door.close()
            shade(door, UIColor(hex: 0x7A5230), width: 1.8)
            for x in [79.0, 88.0, 97.0] as [CGFloat] { line(CGPoint(x: x, y: 116), CGPoint(x: x, y: 160), UIColor(hex: 0x5A3A20), width: 1.2) }
            for y in [128.0, 146.0] as [CGFloat] { for x in [76.0, 100.0] as [CGFloat] { fill(circle(x, y, 1.6), UIColor(hex: 0x3A3F44)) } }
            // banner
            let banner = UIBezierPath()
            banner.move(to: CGPoint(x: 28, y: 60)); banner.addLine(to: CGPoint(x: 56, y: 60)); banner.addLine(to: CGPoint(x: 56, y: 104))
            banner.addLine(to: CGPoint(x: 42, y: 96)); banner.addLine(to: CGPoint(x: 28, y: 104)); banner.close()
            shade(banner, p.team, width: 1.4)
            gem(42, 76, 5, UIColor(hex: 0xF2C14E))
            glowWindow(CGRect(x: 86, y: 64, width: 10, height: 16))
            flag(64, 0, 32)
        case 2: // log fort with a blockhouse
            let house = UIBezierPath(rect: CGRect(x: 24, y: 40, width: 76, height: 50))
            shade(house, UIColor(hex: 0xA3703F), width: 2)
            for i in 0..<5 { line(CGPoint(x: 26, y: 48 + CGFloat(i) * 9), CGPoint(x: 98, y: 48 + CGFloat(i) * 9), UIColor(hex: 0x7A4B26), width: 1.2) }
            let roof = UIBezierPath()
            roof.move(to: CGPoint(x: 16, y: 42)); roof.addLine(to: CGPoint(x: 62, y: 30)); roof.addLine(to: CGPoint(x: 108, y: 42)); roof.close()
            shade(roof, UIColor(hex: 0x6B4A2B), width: 1.8)
            glowWindow(CGRect(x: 52, y: 54, width: 18, height: 12))
            for i in 0..<9 {
                let x = 3 + CGFloat(i) * 14
                let log = UIBezierPath()
                log.move(to: CGPoint(x: x, y: 160)); log.addLine(to: CGPoint(x: x, y: 86)); log.addLine(to: CGPoint(x: x + 6.5, y: 72))
                log.addLine(to: CGPoint(x: x + 13, y: 86)); log.addLine(to: CGPoint(x: x + 13, y: 160)); log.close()
                shade(log, wood, width: 1.5)
                line(CGPoint(x: x + 3.5, y: 92), CGPoint(x: x + 3.5, y: 156), UIColor(white: 1, alpha: 0.25), width: 1.4)
            }
            shade(UIBezierPath(rect: CGRect(x: 2, y: 110, width: 126, height: 7)), p.team, width: 1.2)
            flag(30, 4, 34)
        case 3: // concrete bunker behind sandbags
            let bunker = UIBezierPath()
            bunker.move(to: CGPoint(x: 4, y: 160)); bunker.addLine(to: CGPoint(x: 20, y: 80))
            bunker.addLine(to: CGPoint(x: 112, y: 80)); bunker.addLine(to: CGPoint(x: 128, y: 160)); bunker.close()
            shade(bunker, UIColor(hex: 0x9AA0A4), width: 2.2, light: 0.3, dark: 0.22)
            for (x, y) in [(30.0, 96.0), (88.0, 108.0), (60.0, 90.0)] as [(CGFloat, CGFloat)] { line(CGPoint(x: x, y: y), CGPoint(x: x + 8, y: y + 6), UIColor(hex: 0x6E7477), width: 1) }
            shade(UIBezierPath(roundedRect: CGRect(x: 38, y: 102, width: 58, height: 10), cornerRadius: 3), UIColor(hex: 0x2B2E30), width: 1.4)
            shade(UIBezierPath(rect: CGRect(x: 14, y: 126, width: 104, height: 7)), p.team, width: 1.2)
            line(CGPoint(x: 100, y: 80), CGPoint(x: 106, y: 52), UIColor(hex: 0x3A3F44), width: 1.6)          // antenna
            fill(circle(106, 52, 2.4), UIColor(hex: 0xE04848))
            for row in 0..<2 { for i in 0..<(6 - row) {
                shade(oval(4 + CGFloat(i) * 21 + CGFloat(row) * 10, 146 - CGFloat(row) * 10, 24, 14), UIColor(hex: 0xCBB68A), width: 1.2)
            } }
            flag(26, 36, 82)
        default: // sci-fi citadel
            let core = UIBezierPath(roundedRect: CGRect(x: 36, y: 40, width: 58, height: 120), cornerRadius: 14)
            shade(core, UIColor(hex: 0xDCE2EA), outline: UIColor(hex: 0x6E7A8A), width: 2, light: 0.6, dark: 0.18)
            let wing = UIBezierPath(roundedRect: CGRect(x: 8, y: 118, width: 114, height: 42), cornerRadius: 12)
            shade(wing, UIColor(hex: 0xBCC4D0), outline: UIColor(hex: 0x6E7A8A), width: 2, light: 0.5, dark: 0.18)
            c.saveGState()
            c.setShadow(offset: .zero, blur: 8, color: p.team.cgColor)
            fill(UIBezierPath(roundedRect: CGRect(x: 46, y: 58, width: 4, height: 92), cornerRadius: 2), p.team.blend(.white, 0.3))
            fill(UIBezierPath(roundedRect: CGRect(x: 80, y: 58, width: 4, height: 92), cornerRadius: 2), p.team.blend(.white, 0.3))
            fill(UIBezierPath(roundedRect: CGRect(x: 14, y: 132, width: 102, height: 4), cornerRadius: 2), p.team.blend(.white, 0.3))
            let orb = circle(65, 40, 17)
            gradient(orb, p.team.blend(.white, 0.6), p.team.withAlphaComponent(0.55))
            stroke(orb, p.teamDark, 1.6)
            c.restoreGState()
            line(CGPoint(x: 57, y: 32), CGPoint(x: 63, y: 28), UIColor(white: 1, alpha: 0.8), width: 2)
            let door = UIBezierPath(roundedRect: CGRect(x: 55, y: 82, width: 20, height: 30), cornerRadius: 8)
            gradient(door, UIColor(hex: 0x3A3D5A), UIColor(hex: 0x1C1E2E))
            stroke(door, UIColor(hex: 0x6E7A8A), 1.4)
        }
    }

    // MARK: Turrets (44x34, facing right)

    private func drawTurret(_ ctx: UIGraphicsImageRendererContext, _ era: Int, _ s: Species) {
        let c = ctx.cgContext
        let p = ArtFactory.palette(s)
        let ol = ArtFactory.outline
        let wood = UIColor(hex: 0x9C6A3F)
        switch era {
        case 0: // catapult
            shade(UIBezierPath(roundedRect: CGRect(x: 5, y: 23, width: 32, height: 6), cornerRadius: 2), wood)
            for x in [10.0, 32.0] as [CGFloat] { shade(circle(x, 30, 4), UIColor(hex: 0x6B4A2B)); fill(circle(x, 30, 1.2), ol) }
            line(CGPoint(x: 20, y: 24), CGPoint(x: 34, y: 6), ol, width: 4.6)
            line(CGPoint(x: 20, y: 24), CGPoint(x: 34, y: 6), UIColor(hex: 0x8D5A33), width: 3)
            shade(UIBezierPath(rect: CGRect(x: 17, y: 14, width: 4, height: 10)), wood, width: 0.8)
            shade(circle(35, 6, 5), UIColor(hex: 0x9A9A9A))
        case 1: // ballista
            shade(UIBezierPath(roundedRect: CGRect(x: 6, y: 14, width: 32, height: 5), cornerRadius: 2), wood)
            let bow = UIBezierPath()
            bow.move(to: CGPoint(x: 29, y: 2)); bow.addQuadCurve(to: CGPoint(x: 29, y: 32), controlPoint: CGPoint(x: 42, y: 17))
            bow.lineWidth = 4.4; ol.setStroke(); bow.stroke()
            bow.lineWidth = 2.8; UIColor(hex: 0x8D5A33).setStroke(); bow.stroke()
            line(CGPoint(x: 29, y: 2), CGPoint(x: 13, y: 16.5), .white, width: 0.8)
            line(CGPoint(x: 29, y: 32), CGPoint(x: 13, y: 16.5), .white, width: 0.8)
            line(CGPoint(x: 13, y: 16.5), CGPoint(x: 43, y: 16.5), UIColor(hex: 0x6B4A2B), width: 1.6)
            shade(UIBezierPath(rect: CGRect(x: 4, y: 21, width: 18, height: 11)), p.team, width: 1)
        case 2: // bronze cannon
            let barrel = UIBezierPath(roundedRect: CGRect(x: 10, y: 7, width: 33, height: 13), cornerRadius: 6)
            gradient(barrel, UIColor(hex: 0xF0C77A), UIColor(hex: 0x8A5A1E))
            stroke(barrel, ol, 1.3)
            shade(UIBezierPath(rect: CGRect(x: 38, y: 6, width: 4, height: 15)), UIColor(hex: 0xC99A45), width: 0.8)
            shade(UIBezierPath(roundedRect: CGRect(x: 4, y: 19, width: 28, height: 8), cornerRadius: 2), wood)
            for x in [12.0, 26.0] as [CGFloat] { shade(circle(x, 28, 5), UIColor(hex: 0x6B4A2B)); fill(circle(x, 28, 1.5), ol) }
        case 3: // machine-gun nest
            for i in 0..<3 { shade(oval(2 + CGFloat(i) * 12, 24, 16, 9), UIColor(hex: 0xCBB68A), width: 1) }
            shade(UIBezierPath(roundedRect: CGRect(x: 9, y: 9, width: 20, height: 15), cornerRadius: 3), UIColor(hex: 0x3A3F44), width: 1.2)
            shade(UIBezierPath(rect: CGRect(x: 27, y: 13, width: 17, height: 4)), UIColor(hex: 0x2A2E33), width: 0.8)
            for i in 0..<3 { fill(UIBezierPath(rect: CGRect(x: 30 + CGFloat(i) * 4, y: 12, width: 1.4, height: 6)), UIColor(hex: 0x6E7477)) }
            fill(UIBezierPath(rect: CGRect(x: 11, y: 11, width: 4, height: 11)), p.team)
        default: // laser tower
            shade(UIBezierPath(roundedRect: CGRect(x: 6, y: 20, width: 30, height: 12), cornerRadius: 5), UIColor(hex: 0xBCC4D0), outline: UIColor(hex: 0x6E7A8A), width: 1.2)
            shade(circle(21, 18, 10), UIColor(hex: 0xDCE2EA), outline: UIColor(hex: 0x6E7A8A), width: 1.2, light: 0.6)
            shade(UIBezierPath(roundedRect: CGRect(x: 26, y: 15, width: 17, height: 5), cornerRadius: 2), UIColor(hex: 0x8E99A8), width: 0.8)
            c.saveGState()
            c.setShadow(offset: .zero, blur: 6, color: p.team.cgColor)
            fill(circle(21, 18, 4), p.team.blend(.white, 0.3))
            fill(circle(43, 17.5, 2.2), p.team.blend(.white, 0.4))
            c.restoreGState()
        }
    }

    // MARK: Backgrounds

    private func drawBackground(_ ctx: UIGraphicsImageRendererContext, era: Int, size: CGSize, groundHeight: CGFloat) {
        let c = ctx.cgContext
        let skies: [(UInt32, UInt32)] = [(0x6EC3F0, 0xE4F6FF), (0x8FB6E6, 0xF6F0DC), (0xF09A4E, 0xFDE6C4),
                                         (0x8FA6B4, 0xE2E6E4), (0x16153A, 0x5B3F82)]
        let hills: [(UInt32, UInt32, UInt32)] = [(0xB3D9A6, 0x8DC27F, 0x6AAA5E), (0xA9BFA2, 0x86A57F, 0x5F865A),
                                                 (0xD9A877, 0xB98B5E, 0x8C6A48), (0xA5B0B5, 0x86939A, 0x5F6B72),
                                                 (0x4A3F7E, 0x3A3368, 0x2A2550)]
        let grounds: [(UInt32, UInt32)] = [(0x7CB342, 0x8B5E34), (0x6A994E, 0x6F4E37), (0xC9A56A, 0x8A6A45),
                                           (0x6B705C, 0x4F4A3E), (0x3D3B66, 0x26244A)]
        let (top, bottom) = skies[era]
        let w = size.width, h = size.height, gy = h - groundHeight
        let space = CGColorSpace(name: CGColorSpace.sRGB)
        if let g = CGGradient(colorsSpace: space, colors: [UIColor(hex: top).cgColor, UIColor(hex: bottom).cgColor] as CFArray, locations: [0, 1]) {
            c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: gy), options: [.drawsAfterEndLocation])
        }
        var r = SeededRandom(seed: UInt64(7 + era))
        func rnd(_ a: CGFloat, _ b: CGFloat) -> CGFloat { CGFloat.random(in: a...max(a + 0.001, b), using: &r) }

        // Sun / moon with a soft glow, stars at night
        let sunCenter = CGPoint(x: w * 0.82, y: h * 0.2)
        func glow(_ p: CGPoint, _ radius: CGFloat, _ color: UIColor) {
            if let g = CGGradient(colorsSpace: space, colors: [color.withAlphaComponent(0.55).cgColor, color.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1]) {
                c.drawRadialGradient(g, startCenter: p, startRadius: 0, endCenter: p, endRadius: radius, options: [])
            }
        }
        if era == 4 {
            for _ in 0..<Int(w / 10) { fill(circle(rnd(0, w), rnd(0, gy * 0.75), rnd(0.5, 1.7)), UIColor(white: 1, alpha: rnd(0.4, 0.95))) }
            glow(CGPoint(x: w * 0.22, y: h * 0.24), 90, UIColor(hex: 0xB78CFF))
            let planet = circle(w * 0.22, h * 0.24, 34)
            gradient(planet, UIColor(hex: 0xE7C6FF), UIColor(hex: 0x7A4FC2))
            let ring = UIBezierPath(ovalIn: CGRect(x: w * 0.22 - 58, y: h * 0.24 - 9, width: 116, height: 18))
            ring.lineWidth = 3; UIColor(hex: 0xF4E1FF, alpha: 0.8).setStroke(); ring.stroke()
            // Crescent moon: the disc minus an offset disc (even-odd, clipped to the disc).
            glow(sunCenter, 60, UIColor(hex: 0xF4F1FF))
            let disc = circle(sunCenter.x, sunCenter.y, 20)
            c.saveGState()
            disc.addClip()
            let crescent = UIBezierPath()
            crescent.append(disc)
            crescent.append(circle(sunCenter.x + 9, sunCenter.y - 6, 18))
            crescent.usesEvenOddFillRule = true
            fill(crescent, UIColor(hex: 0xF4F1FF))
            c.restoreGState()
        } else {
            let sun = era == 2 ? UIColor(hex: 0xFFD27A) : UIColor(hex: 0xFFF3B0)
            glow(sunCenter, 110, sun)
            fill(circle(sunCenter.x, sunCenter.y, 26), sun)
            for _ in 0..<Int(w / 220) + 2 {
                let x = rnd(0, w), y = rnd(h * 0.06, h * 0.32), s = rnd(0.7, 1.3)
                let a: CGFloat = era == 3 ? 0.6 : 0.92
                let shadeCol = UIColor(white: era == 3 ? 0.78 : 0.88, alpha: a)
                fill(oval(x, y + 6 * s, 76 * s, 18 * s), shadeCol)
                fill(oval(x + 10 * s, y - 8 * s, 34 * s, 26 * s), UIColor(white: 1, alpha: a))
                fill(oval(x + 32 * s, y - 14 * s, 30 * s, 30 * s), UIColor(white: 1, alpha: a))
                fill(oval(x + 4 * s, y + 2 * s, 66 * s, 16 * s), UIColor(white: 1, alpha: a))
            }
        }

        func ridge(_ color: UIColor, base: CGFloat, amp: CGFloat, freq: CGFloat, phase: CGFloat, jag: Bool = false) {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: gy))
            var x: CGFloat = 0
            while x <= w + 6 {
                var y = base - amp * (0.5 + 0.5 * sin(x / w * .pi * freq + phase))
                if jag { y -= amp * 0.18 * abs(sin(x / 23 + phase * 3)) }
                path.addLine(to: CGPoint(x: x, y: y))
                x += 6
            }
            path.addLine(to: CGPoint(x: w, y: gy)); path.close()
            fill(path, color)
        }
        let (far, mid, near) = hills[era]
        // Far layer: mountains / mesas / skyline
        switch era {
        case 2: // mesas
            for _ in 0..<Int(w / 260) + 2 {
                let x = rnd(-40, w), mw = rnd(90, 180), mh = rnd(h * 0.14, h * 0.26)
                let mesa = UIBezierPath()
                mesa.move(to: CGPoint(x: x, y: gy)); mesa.addLine(to: CGPoint(x: x + 18, y: gy - mh))
                mesa.addLine(to: CGPoint(x: x + mw - 18, y: gy - mh)); mesa.addLine(to: CGPoint(x: x + mw, y: gy)); mesa.close()
                fill(mesa, UIColor(hex: far))
                fill(UIBezierPath(rect: CGRect(x: x + 18, y: gy - mh, width: mw - 36, height: 5)), UIColor(hex: far).blend(.white, 0.2))
            }
        case 3: // city skyline
            var x: CGFloat = -10
            while x < w {
                let bw = rnd(26, 60), bh = rnd(h * 0.12, h * 0.36)
                fill(UIBezierPath(rect: CGRect(x: x, y: gy - bh, width: bw, height: bh)), UIColor(hex: far))
                for wy in stride(from: gy - bh + 8, to: gy - 10, by: 12) {
                    for wx in stride(from: x + 5, to: x + bw - 6, by: 10) where rnd(0, 1) > 0.55 {
                        fill(UIBezierPath(rect: CGRect(x: wx, y: wy, width: 4, height: 5)), UIColor(hex: 0xFFE7A0, alpha: 0.55))
                    }
                }
                x += bw + rnd(2, 14)
            }
        case 4: // neon spires
            for _ in 0..<Int(w / 120) + 2 {
                let x = rnd(0, w), sh = rnd(h * 0.18, h * 0.45), sw = rnd(10, 22)
                let spire = UIBezierPath()
                spire.move(to: CGPoint(x: x - sw, y: gy)); spire.addLine(to: CGPoint(x: x, y: gy - sh)); spire.addLine(to: CGPoint(x: x + sw, y: gy)); spire.close()
                fill(spire, UIColor(hex: far))
                c.saveGState()
                c.setShadow(offset: .zero, blur: 6, color: UIColor(hex: 0x5EF2FF).cgColor)
                fill(circle(x, gy - sh + 4, 2.4), UIColor(hex: 0x9FF7FF))
                c.restoreGState()
            }
        default:
            ridge(UIColor(hex: far), base: gy - 30, amp: h * 0.24, freq: 2.4, phase: 0.3, jag: true)
            if era == 0 { // smoking volcano
                let vx = w * 0.62
                let v = UIBezierPath()
                v.move(to: CGPoint(x: vx - 120, y: gy - 20)); v.addLine(to: CGPoint(x: vx - 24, y: gy - h * 0.42))
                v.addLine(to: CGPoint(x: vx + 24, y: gy - h * 0.42)); v.addLine(to: CGPoint(x: vx + 120, y: gy - 20)); v.close()
                fill(v, UIColor(hex: 0x9C8E86))
                fill(UIBezierPath(rect: CGRect(x: vx - 24, y: gy - h * 0.42, width: 48, height: 6)), UIColor(hex: 0xFF8A3D))
                for i in 0..<4 { fill(circle(vx - 6 + CGFloat(i) * 9, gy - h * 0.46 - CGFloat(i) * 14, 10 + CGFloat(i) * 3), UIColor(white: 0.85, alpha: 0.55)) }
            }
        }
        ridge(UIColor(hex: mid), base: gy - 6, amp: h * 0.17, freq: 3.6, phase: 1.4)

        // Mid props
        func tree(_ x: CGFloat, _ s: CGFloat, _ col: UIColor) {
            fill(UIBezierPath(rect: CGRect(x: x - 2 * s, y: gy - 14 * s, width: 4 * s, height: 14 * s)), UIColor(hex: 0x6B4A2B))
            for i in 0..<3 {
                let t = UIBezierPath()
                let y0 = gy - 10 * s - CGFloat(i) * 9 * s
                t.move(to: CGPoint(x: x - (14 - CGFloat(i) * 3) * s, y: y0)); t.addLine(to: CGPoint(x: x, y: y0 - 16 * s))
                t.addLine(to: CGPoint(x: x + (14 - CGFloat(i) * 3) * s, y: y0)); t.close()
                fill(t, col)
            }
        }
        switch era {
        case 0, 1:
            for _ in 0..<Int(w / 70) { tree(rnd(0, w), rnd(0.8, 1.4), UIColor(hex: mid).blend(.black, 0.18)) }
            if era == 1 { // distant castle on a hill
                for k in 0..<Int(w / 700) + 1 {
                    let cx = w * 0.3 + CGFloat(k) * 640, cy = gy - h * 0.2
                    let col = UIColor(hex: far).blend(.black, 0.1)
                    fill(UIBezierPath(rect: CGRect(x: cx, y: cy, width: 70, height: 50)), col)
                    for i in 0..<4 { fill(UIBezierPath(rect: CGRect(x: cx + 4 + CGFloat(i) * 18, y: cy - 8, width: 10, height: 8)), col) }
                    fill(UIBezierPath(rect: CGRect(x: cx + 26, y: cy - 34, width: 18, height: 34)), col)
                    let roof = UIBezierPath(); roof.move(to: CGPoint(x: cx + 22, y: cy - 34)); roof.addLine(to: CGPoint(x: cx + 35, y: cy - 52)); roof.addLine(to: CGPoint(x: cx + 48, y: cy - 34)); roof.close()
                    fill(roof, UIColor(hex: 0xB0605A).blend(UIColor(hex: far), 0.5))
                }
            }
        case 2:
            for _ in 0..<Int(w / 120) {
                let x = rnd(0, w), s = rnd(0.8, 1.3), col = UIColor(hex: 0x5E8F4A)
                fill(UIBezierPath(roundedRect: CGRect(x: x - 4 * s, y: gy - 30 * s, width: 8 * s, height: 30 * s), cornerRadius: 4 * s), col)
                fill(UIBezierPath(roundedRect: CGRect(x: x - 13 * s, y: gy - 22 * s, width: 6 * s, height: 12 * s), cornerRadius: 3 * s), col)
                fill(UIBezierPath(roundedRect: CGRect(x: x + 7 * s, y: gy - 26 * s, width: 6 * s, height: 14 * s), cornerRadius: 3 * s), col)
            }
        case 3:
            var x: CGFloat = 40
            while x < w { // power line poles
                fill(UIBezierPath(rect: CGRect(x: x, y: gy - 60, width: 3, height: 60)), UIColor(hex: 0x4F4A3E))
                fill(UIBezierPath(rect: CGRect(x: x - 9, y: gy - 56, width: 21, height: 2.5)), UIColor(hex: 0x4F4A3E))
                let wire = UIBezierPath(); wire.move(to: CGPoint(x: x, y: gy - 55)); wire.addQuadCurve(to: CGPoint(x: x + 180, y: gy - 55), controlPoint: CGPoint(x: x + 90, y: gy - 40))
                wire.lineWidth = 0.8; UIColor(white: 0.2, alpha: 0.6).setStroke(); wire.stroke()
                x += 180
            }
        default:
            break
        }
        ridge(UIColor(hex: near), base: gy + 4, amp: h * 0.08, freq: 6.3, phase: 2.6)

        // Ground with a grassy lip, stones and tufts
        let (lip, dirt) = grounds[era]
        if let g = CGGradient(colorsSpace: space, colors: [UIColor(hex: dirt).cgColor, UIColor(hex: dirt).blend(.black, 0.25).cgColor] as CFArray, locations: [0, 1]) {
            c.saveGState()
            c.clip(to: CGRect(x: 0, y: gy, width: w, height: groundHeight))
            c.drawLinearGradient(g, start: CGPoint(x: 0, y: gy), end: CGPoint(x: 0, y: h), options: [])
            c.restoreGState()
        }
        let lipPath = UIBezierPath()
        lipPath.move(to: CGPoint(x: 0, y: gy))
        var lx: CGFloat = 0
        while lx <= w + 8 {
            lipPath.addLine(to: CGPoint(x: lx, y: gy + 9 + 3 * sin(lx / 9)))
            lx += 8
        }
        lipPath.addLine(to: CGPoint(x: w, y: gy)); lipPath.close()
        fill(lipPath, UIColor(hex: lip))
        fill(UIBezierPath(rect: CGRect(x: 0, y: gy, width: w, height: 2.5)), UIColor(hex: lip).blend(.white, 0.25))
        for _ in 0..<Int(w / 18) {
            let x = rnd(0, w), y = rnd(gy + 16, h - 4), s = rnd(0.6, 1.4)
            fill(oval(x, y, 8 * s, 4 * s), UIColor(hex: dirt).blend(.black, 0.22))
            fill(oval(x + 1.5 * s, y + 0.5 * s, 4 * s, 1.6 * s), UIColor(hex: dirt).blend(.white, 0.18))
        }
        if era < 3 {
            for _ in 0..<Int(w / 26) {
                let x = rnd(0, w), col = UIColor(hex: lip).blend(.black, 0.15)
                for k in 0..<3 { line(CGPoint(x: x + CGFloat(k) * 2, y: gy + 3), CGPoint(x: x + CGFloat(k) * 2 + (CGFloat(k) - 1) * 2, y: gy - 3), col, width: 1.2) }
            }
        }
        if era == 4 {
            c.saveGState()
            c.setShadow(offset: .zero, blur: 6, color: UIColor(hex: 0x5EF2FF).cgColor)
            fill(UIBezierPath(rect: CGRect(x: 0, y: gy, width: w, height: 2)), UIColor(hex: 0x5EF2FF))
            c.restoreGState()
        }
    }
}


extension UIColor {
    func blend(_ other: UIColor, _ t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: a1 + (a2 - a1) * t)
    }
}
