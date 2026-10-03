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

    func unit(_ species: Species, era: Int, role: UnitRole) -> UIImage {
        cached("u-\(species)-\(era)-\(role)") {
            let size = role == .heavy ? CGSize(width: 96, height: 80) : CGSize(width: 64, height: 64)
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
        c.saveGState()
        c.translateBy(x: origin.x, y: origin.y)
        c.scaleBy(x: scale, y: scale)

        // Feet
        fill(oval(19, 54, 11, 7), p.furDark)
        fill(oval(35, 54, 11, 7), p.furDark)

        if s == .rat {
            let tail = UIBezierPath()
            tail.move(to: CGPoint(x: 13, y: 48))
            tail.addCurve(to: CGPoint(x: 2, y: 26), controlPoint1: CGPoint(x: -2, y: 50), controlPoint2: CGPoint(x: 8, y: 34))
            tail.lineWidth = 2.6
            tail.lineCapStyle = .round
            p.innerEar.blend(p.furDark, 0.3).setStroke()
            tail.stroke()
            // Big ears behind the head
            fill(circle(23, 24, 9), p.fur, stroke: ol)
            fill(circle(23, 24, 5), p.innerEar)
            fill(circle(35, 22, 8), p.fur, stroke: ol)
            fill(circle(35, 22, 4.5), p.innerEar)
            // Body + snout
            fill(oval(9, 27, 40, 31), p.fur, stroke: ol)
            fill(oval(36, 32, 24, 15), p.fur, stroke: ol)
            fill(oval(11, 28, 36, 29), p.fur)            // hides the snout seam
            fill(oval(37, 33, 20, 13), p.fur)
            fill(oval(25, 41, 19, 15), p.belly)
            // Face
            fill(circle(44, 34, 2.9), UIColor(hex: 0x1D1A22))
            fill(circle(44.9, 33.1, 0.9), .white)
            line(CGPoint(x: 40, y: 29), CGPoint(x: 47.5, y: 31.2), ol, width: 2)   // grumpy brow
            fill(circle(59, 39, 2.5), UIColor(hex: 0xC2185B))
            line(CGPoint(x: 55, y: 41), CGPoint(x: 63, y: 39), UIColor(white: 0.35, alpha: 0.8), width: 0.8)
            line(CGPoint(x: 55, y: 42.5), CGPoint(x: 63, y: 44), UIColor(white: 0.35, alpha: 0.8), width: 0.8)
        } else {
            fill(circle(20, 26, 6.5), p.fur, stroke: ol)
            fill(circle(20, 26, 3.3), p.innerEar)
            fill(circle(37, 23, 6.5), p.fur, stroke: ol)
            fill(circle(37, 23, 3.3), p.innerEar)
            fill(oval(9, 24, 44, 36), p.fur, stroke: ol)
            fill(oval(25, 38, 23, 20), p.belly)
            // Face
            fill(circle(42, 35, 3.4), UIColor(hex: 0x1D1A22))
            fill(circle(43.1, 33.9, 1.1), .white)
            fill(oval(38, 40, 10, 5.5), UIColor(hex: 0xFF8A80, alpha: 0.55))
            fill(circle(51.5, 38.5, 2.3), UIColor(hex: 0xE5737A))
            let smile = UIBezierPath()
            smile.move(to: CGPoint(x: 47, y: 42.5))
            smile.addQuadCurve(to: CGPoint(x: 51, y: 42.5), controlPoint: CGPoint(x: 49, y: 45))
            smile.lineWidth = 1.1
            ol.setStroke()
            smile.stroke()
        }

        if hat { drawHat(ctx, era: era, palette: p) }
        if let w = weapon { drawWeapon(ctx, era: era, role: w, palette: p) }
        // Arm in front of the weapon handle
        fill(oval(41, 44, 10, 8), p.fur, stroke: ol, width: 1.2)
        c.restoreGState()
    }

    private func drawHat(_ ctx: UIGraphicsImageRendererContext, era: Int, palette p: Palette) {
        let ol = ArtFactory.outline
        switch era {
        case 0: // headband + leaf
            fill(UIBezierPath(roundedRect: CGRect(x: 14, y: 27, width: 32, height: 5), cornerRadius: 2.5), p.team, stroke: p.teamDark, width: 1)
            let tails = UIBezierPath()
            tails.move(to: CGPoint(x: 15, y: 29)); tails.addLine(to: CGPoint(x: 6, y: 25)); tails.addLine(to: CGPoint(x: 7, y: 33)); tails.close()
            fill(tails, p.team)
            fill(oval(26, 12, 7, 15), UIColor(hex: 0x6AB04C), stroke: UIColor(hex: 0x3E7A2B), width: 1)
        case 1: // knight helmet + plume
            let dome = UIBezierPath(arcCenter: CGPoint(x: 31, y: 33), radius: 16, startAngle: .pi, endAngle: 0, clockwise: true)
            dome.close()
            fill(dome, UIColor(hex: 0xAEB8C2), stroke: UIColor(hex: 0x5F6B77))
            fill(UIBezierPath(rect: CGRect(x: 15, y: 30, width: 32, height: 4)), UIColor(hex: 0x8C98A4))
            fill(oval(22, 9, 9, 14), p.team, stroke: p.teamDark, width: 1)
        case 2: // tricorn
            let hat = UIBezierPath()
            hat.move(to: CGPoint(x: 12, y: 29))
            hat.addQuadCurve(to: CGPoint(x: 31, y: 12), controlPoint: CGPoint(x: 16, y: 14))
            hat.addQuadCurve(to: CGPoint(x: 50, y: 29), controlPoint: CGPoint(x: 46, y: 14))
            hat.addQuadCurve(to: CGPoint(x: 12, y: 29), controlPoint: CGPoint(x: 31, y: 22))
            fill(hat, UIColor(hex: 0x2E3047), stroke: ol)
            fill(circle(40, 21, 3.2), p.team)
        case 3: // army helmet
            let dome = UIBezierPath(arcCenter: CGPoint(x: 31, y: 32), radius: 17, startAngle: .pi, endAngle: 0, clockwise: true)
            dome.close()
            fill(dome, UIColor(hex: 0x6B7B3A), stroke: UIColor(hex: 0x3F4A1E))
            fill(UIBezierPath(roundedRect: CGRect(x: 11, y: 30, width: 40, height: 4), cornerRadius: 2), UIColor(hex: 0x56632C))
            fill(UIBezierPath(rect: CGRect(x: 16, y: 24, width: 30, height: 3)), p.team)
        default: // future helmet + visor
            let dome = UIBezierPath(arcCenter: CGPoint(x: 31, y: 33), radius: 16, startAngle: .pi, endAngle: 0, clockwise: true)
            dome.close()
            fill(dome, UIColor(hex: 0xE3E8F0), stroke: UIColor(hex: 0x7C8796))
            line(CGPoint(x: 24, y: 18), CGPoint(x: 19, y: 7), UIColor(hex: 0x7C8796), width: 1.6)
            fill(circle(19, 7, 3), p.team)
            ctx.cgContext.saveGState()
            ctx.cgContext.setShadow(offset: .zero, blur: 4, color: UIColor(hex: 0x5EF2FF).cgColor)
            fill(UIBezierPath(roundedRect: CGRect(x: 35, y: 29, width: 17, height: 9), cornerRadius: 4), UIColor(hex: 0x5EF2FF, alpha: 0.85), stroke: UIColor(hex: 0x1E8FA6), width: 1)
            ctx.cgContext.restoreGState()
        }
    }

    private func drawWeapon(_ ctx: UIGraphicsImageRendererContext, era: Int, role: UnitRole, palette p: Palette) {
        let c = ctx.cgContext
        let ol = ArtFactory.outline
        if role == .melee {
            c.saveGState()
            c.translateBy(x: 47, y: 47)
            c.rotate(by: -0.9)
            switch era {
            case 0:
                fill(UIBezierPath(roundedRect: CGRect(x: 0, y: -2.5, width: 18, height: 5), cornerRadius: 2), UIColor(hex: 0x8D5A33), stroke: ol, width: 1)
                fill(circle(19, 0, 5.5), UIColor(hex: 0x9C6A3F), stroke: ol, width: 1)
            case 1:
                fill(UIBezierPath(rect: CGRect(x: 3, y: -2, width: 20, height: 4)), UIColor(hex: 0xDDE4EA), stroke: UIColor(hex: 0x7F8C99), width: 1)
                fill(UIBezierPath(rect: CGRect(x: 1, y: -5, width: 3, height: 10)), UIColor(hex: 0xE3B341))
            case 2:
                let blade = UIBezierPath()
                blade.move(to: CGPoint(x: 3, y: -2)); blade.addQuadCurve(to: CGPoint(x: 25, y: -6), controlPoint: CGPoint(x: 15, y: -1))
                blade.addQuadCurve(to: CGPoint(x: 3, y: 2), controlPoint: CGPoint(x: 15, y: 4)); blade.close()
                fill(blade, UIColor(hex: 0xE6EBF0), stroke: UIColor(hex: 0x7F8C99), width: 1)
                fill(UIBezierPath(rect: CGRect(x: 1, y: -4, width: 3, height: 8)), UIColor(hex: 0xE3B341))
            case 3:
                fill(UIBezierPath(rect: CGRect(x: 0, y: -2, width: 7, height: 4)), UIColor(hex: 0x2C2C2C))
                fill(UIBezierPath(rect: CGRect(x: 7, y: -1.5, width: 11, height: 3)), UIColor(hex: 0xBFC6CC), stroke: UIColor(hex: 0x6E7780), width: 0.8)
            default:
                c.setShadow(offset: .zero, blur: 5, color: p.team.cgColor)
                fill(UIBezierPath(roundedRect: CGRect(x: 3, y: -2.5, width: 24, height: 5), cornerRadius: 2.5), UIColor.white.blend(p.team, 0.4))
                fill(UIBezierPath(rect: CGRect(x: 0, y: -3, width: 4, height: 6)), UIColor(hex: 0x5A6270))
            }
            c.restoreGState()
        } else {
            switch era {
            case 0:
                line(CGPoint(x: 47, y: 47), CGPoint(x: 54, y: 39), UIColor(hex: 0x7A4B26), width: 1.4)
                fill(circle(55, 38, 3.8), UIColor(hex: 0x8D8D8D), stroke: ol, width: 1)
            case 1:
                let bow = UIBezierPath()
                bow.move(to: CGPoint(x: 49, y: 30)); bow.addQuadCurve(to: CGPoint(x: 49, y: 62), controlPoint: CGPoint(x: 63, y: 46))
                bow.lineWidth = 2.6; UIColor(hex: 0x8D5A33).setStroke(); bow.stroke()
                line(CGPoint(x: 49, y: 30), CGPoint(x: 49, y: 62), UIColor(white: 0.95, alpha: 1), width: 0.8)
            case 2:
                fill(UIBezierPath(rect: CGRect(x: 34, y: 43, width: 29, height: 3.5)), UIColor(hex: 0x3B2F2F))
                fill(UIBezierPath(roundedRect: CGRect(x: 30, y: 43, width: 12, height: 7), cornerRadius: 2), UIColor(hex: 0x8D5A33), stroke: ol, width: 0.8)
            case 3:
                fill(UIBezierPath(rect: CGRect(x: 34, y: 42, width: 27, height: 4.5)), UIColor(hex: 0x3A3F44))
                fill(UIBezierPath(rect: CGRect(x: 45, y: 46, width: 4, height: 7)), UIColor(hex: 0x2A2E33))
                fill(UIBezierPath(rect: CGRect(x: 42, y: 38.5, width: 9, height: 3)), UIColor(hex: 0x2A2E33))
            default:
                fill(UIBezierPath(roundedRect: CGRect(x: 39, y: 40, width: 19, height: 9), cornerRadius: 3), UIColor(hex: 0xEEF2F7), stroke: p.teamDark, width: 1.2)
                c.saveGState()
                c.setShadow(offset: .zero, blur: 4, color: p.team.cgColor)
                fill(circle(58.5, 44.5, 3), p.team)
                c.restoreGState()
            }
        }
    }

    // MARK: Heavy units (96x80, facing right)

    private func drawHeavy(_ ctx: UIGraphicsImageRendererContext, _ s: Species, _ era: Int) {
        let c = ctx.cgContext
        let p = ArtFactory.palette(s)
        let ol = ArtFactory.outline
        switch era {
        case 0: // Boulder Brute: big critter + bone helmet + stone hammer
            drawCritter(ctx, s, era: 0, at: CGPoint(x: 6, y: -2), scale: 1.28, hat: false, weapon: nil)
            let skull = UIBezierPath(arcCenter: CGPoint(x: 46, y: 39), radius: 19, startAngle: .pi, endAngle: 0, clockwise: true)
            skull.close()
            fill(skull, UIColor(hex: 0xF2EAD8), stroke: ol)
            fill(oval(32, 16, 8, 14), UIColor(hex: 0xF2EAD8), stroke: ol, width: 1)
            c.saveGState()
            c.translateBy(x: 66, y: 62)
            c.rotate(by: -1.05)
            fill(UIBezierPath(roundedRect: CGRect(x: 0, y: -3, width: 26, height: 6), cornerRadius: 2), UIColor(hex: 0x7A4B26), stroke: ol, width: 1)
            fill(UIBezierPath(roundedRect: CGRect(x: 20, y: -11, width: 14, height: 22), cornerRadius: 5), UIColor(hex: 0x8F8F8F), stroke: ol, width: 1.4)
            c.restoreGState()
        case 1: // Iron Knight: lance + shield
            line(CGPoint(x: 40, y: 54), CGPoint(x: 95, y: 44), UIColor(hex: 0x8D5A33), width: 3.5)
            fill(UIBezierPath(rect: CGRect(x: 86, y: 41.5, width: 9, height: 5)), UIColor(hex: 0xC9D1D9))
            drawCritter(ctx, s, era: 1, at: CGPoint(x: 8, y: 4), scale: 1.18, hat: true, weapon: nil)
            let shield = UIBezierPath()
            shield.move(to: CGPoint(x: 56, y: 40)); shield.addLine(to: CGPoint(x: 76, y: 40))
            shield.addQuadCurve(to: CGPoint(x: 66, y: 74), controlPoint: CGPoint(x: 78, y: 64))
            shield.addQuadCurve(to: CGPoint(x: 56, y: 40), controlPoint: CGPoint(x: 54, y: 64)); shield.close()
            fill(shield, p.team, stroke: ol, width: 1.6)
            fill(UIBezierPath(rect: CGRect(x: 64.5, y: 44, width: 3, height: 24)), UIColor(hex: 0xE3B341))
        case 2: // Cannon on wheels, critter behind
            drawCritter(ctx, s, era: 2, at: CGPoint(x: -4, y: 14), scale: 0.95, hat: true, weapon: nil)
            c.saveGState()
            c.translateBy(x: 44, y: 50)
            c.rotate(by: -0.12)
            fill(UIBezierPath(roundedRect: CGRect(x: 0, y: -9, width: 48, height: 18), cornerRadius: 8), UIColor(hex: 0x2D2D2D), stroke: ol)
            fill(UIBezierPath(rect: CGRect(x: 40, y: -11, width: 6, height: 22)), UIColor(hex: 0x3D3D3D))
            fill(UIBezierPath(rect: CGRect(x: 10, y: -9, width: 4, height: 18)), p.team)
            c.restoreGState()
            fill(circle(50, 63, 14), UIColor(hex: 0x8D5A33), stroke: ol)
            for i in 0..<6 {
                let a = CGFloat(i) * .pi / 3
                line(CGPoint(x: 50, y: 63), CGPoint(x: 50 + cos(a) * 12, y: 63 + sin(a) * 12), UIColor(hex: 0x5E3A1E), width: 2)
            }
            fill(circle(50, 63, 3.5), UIColor(hex: 0x5E3A1E))
        case 3: // Tank
            drawCritter(ctx, s, era: 3, at: CGPoint(x: 26, y: -6), scale: 0.62, hat: true, weapon: nil)
            fill(UIBezierPath(roundedRect: CGRect(x: 30, y: 22, width: 38, height: 22), cornerRadius: 10), UIColor(hex: 0x6B7B3A), stroke: ol)
            fill(UIBezierPath(rect: CGRect(x: 62, y: 28, width: 33, height: 6)), UIColor(hex: 0x56632C), stroke: ol, width: 1.2)
            fill(UIBezierPath(roundedRect: CGRect(x: 4, y: 38, width: 86, height: 22), cornerRadius: 8), UIColor(hex: 0x7A8B45), stroke: ol)
            fill(UIBezierPath(rect: CGRect(x: 10, y: 44, width: 74, height: 4)), p.team)
            fill(UIBezierPath(roundedRect: CGRect(x: 2, y: 56, width: 90, height: 20), cornerRadius: 10), UIColor(hex: 0x33352B), stroke: ol)
            for i in 0..<6 { fill(circle(12 + CGFloat(i) * 14, 66, 5.5), UIColor(hex: 0x5A5D4C), stroke: ol, width: 1) }
        default: // Mech with critter pilot
            let leg = UIColor(hex: 0x8E99A8)
            line(CGPoint(x: 40, y: 54), CGPoint(x: 28, y: 74), leg, width: 7)
            line(CGPoint(x: 52, y: 54), CGPoint(x: 62, y: 74), leg, width: 7)
            fill(UIBezierPath(roundedRect: CGRect(x: 18, y: 72, width: 18, height: 6), cornerRadius: 3), UIColor(hex: 0x5A6270))
            fill(UIBezierPath(roundedRect: CGRect(x: 54, y: 72, width: 18, height: 6), cornerRadius: 3), UIColor(hex: 0x5A6270))
            fill(UIBezierPath(roundedRect: CGRect(x: 20, y: 18, width: 54, height: 40), cornerRadius: 12), UIColor(hex: 0xD3DAE4), stroke: UIColor(hex: 0x6E7A8A), width: 2)
            fill(UIBezierPath(rect: CGRect(x: 24, y: 50, width: 46, height: 4)), p.team)
            c.saveGState()
            fill(circle(46, 35, 14), UIColor(hex: 0x5EF2FF, alpha: 0.35), stroke: UIColor(hex: 0x1E8FA6), width: 1.5)
            drawCritter(ctx, s, era: 4, at: CGPoint(x: 29, y: 18), scale: 0.5, hat: false, weapon: nil)
            c.restoreGState()
            fill(UIBezierPath(roundedRect: CGRect(x: 66, y: 34, width: 28, height: 9), cornerRadius: 4), UIColor(hex: 0xAAB4C2), stroke: UIColor(hex: 0x6E7A8A), width: 1.2)
            c.saveGState()
            c.setShadow(offset: .zero, blur: 6, color: p.team.cgColor)
            fill(circle(93, 38.5, 3.5), p.team)
            c.restoreGState()
        }
    }

    // MARK: Bases (130x160, facing right)

    private func drawBase(_ ctx: UIGraphicsImageRendererContext, _ s: Species, _ era: Int) {
        let p = ArtFactory.palette(s)
        let ol = ArtFactory.outline
        func flag(_ x: CGFloat, _ top: CGFloat, _ bottom: CGFloat) {
            line(CGPoint(x: x, y: bottom), CGPoint(x: x, y: top), UIColor(hex: 0x5E4632), width: 2.5)
            let f = UIBezierPath()
            f.move(to: CGPoint(x: x, y: top)); f.addLine(to: CGPoint(x: x + 22, y: top + 7)); f.addLine(to: CGPoint(x: x, y: top + 14)); f.close()
            fill(f, p.team, stroke: p.teamDark, width: 1)
        }
        switch era {
        case 0:
            let mound = UIBezierPath()
            mound.move(to: CGPoint(x: 0, y: 160))
            mound.addCurve(to: CGPoint(x: 62, y: 46), controlPoint1: CGPoint(x: 0, y: 90), controlPoint2: CGPoint(x: 22, y: 46))
            mound.addCurve(to: CGPoint(x: 130, y: 160), controlPoint1: CGPoint(x: 104, y: 46), controlPoint2: CGPoint(x: 130, y: 100))
            mound.close()
            fill(mound, UIColor(hex: 0x8C7B6B), stroke: ol, width: 2)
            fill(oval(16, 80, 20, 12), UIColor(hex: 0x7A6A5B))
            fill(oval(80, 70, 24, 13), UIColor(hex: 0x7A6A5B))
            let door = UIBezierPath()
            door.move(to: CGPoint(x: 70, y: 160)); door.addQuadCurve(to: CGPoint(x: 120, y: 160), controlPoint: CGPoint(x: 95, y: 84)); door.close()
            fill(door, UIColor(hex: 0x3B2F2A))
            fill(oval(40, 50, 26, 10), UIColor(hex: 0x6AB04C))
            flag(28, 22, 64)
        case 1:
            fill(UIBezierPath(rect: CGRect(x: 18, y: 44, width: 94, height: 116)), UIColor(hex: 0xB9B4A9), stroke: ol, width: 2)
            for i in 0..<5 {
                fill(UIBezierPath(rect: CGRect(x: 16 + CGFloat(i) * 21, y: 30, width: 14, height: 16)), UIColor(hex: 0xB9B4A9), stroke: ol, width: 2)
            }
            for row in 0..<4 { for col in 0..<3 {
                let off: CGFloat = row % 2 == 0 ? 0 : 14
                fill(UIBezierPath(rect: CGRect(x: 26 + CGFloat(col) * 28 + off, y: 60 + CGFloat(row) * 22, width: 18, height: 2)), UIColor(hex: 0x9C978C))
            } }
            let door = UIBezierPath()
            door.move(to: CGPoint(x: 72, y: 160)); door.addLine(to: CGPoint(x: 72, y: 124))
            door.addQuadCurve(to: CGPoint(x: 104, y: 124), controlPoint: CGPoint(x: 88, y: 104)); door.addLine(to: CGPoint(x: 104, y: 160)); door.close()
            fill(door, UIColor(hex: 0x6B4A2B), stroke: ol)
            fill(UIBezierPath(rect: CGRect(x: 30, y: 62, width: 26, height: 44)), p.team, stroke: p.teamDark, width: 1.2)
            flag(64, 0, 32)
        case 2:
            fill(UIBezierPath(rect: CGRect(x: 26, y: 38, width: 72, height: 50)), UIColor(hex: 0x9C6B3F), stroke: ol, width: 2)
            fill(UIBezierPath(rect: CGRect(x: 20, y: 34, width: 84, height: 8)), UIColor(hex: 0x7A4B26), stroke: ol, width: 1.5)
            for i in 0..<9 {
                let x = 4 + CGFloat(i) * 14
                let log = UIBezierPath(roundedRect: CGRect(x: x, y: 80, width: 13, height: 80), cornerRadius: 6)
                fill(log, UIColor(hex: 0xA97142), stroke: ol, width: 1.4)
                let tip = UIBezierPath()
                tip.move(to: CGPoint(x: x, y: 86)); tip.addLine(to: CGPoint(x: x + 6.5, y: 72)); tip.addLine(to: CGPoint(x: x + 13, y: 86)); tip.close()
                fill(tip, UIColor(hex: 0xA97142), stroke: ol, width: 1.2)
            }
            fill(UIBezierPath(rect: CGRect(x: 52, y: 52, width: 18, height: 14)), UIColor(hex: 0x3B2F2A))
            fill(UIBezierPath(rect: CGRect(x: 4, y: 112, width: 122, height: 6)), p.team)
            flag(32, 4, 36)
        case 3:
            let bunker = UIBezierPath()
            bunker.move(to: CGPoint(x: 4, y: 160)); bunker.addLine(to: CGPoint(x: 20, y: 80))
            bunker.addLine(to: CGPoint(x: 112, y: 80)); bunker.addLine(to: CGPoint(x: 128, y: 160)); bunker.close()
            fill(bunker, UIColor(hex: 0x8E9396), stroke: ol, width: 2)
            fill(UIBezierPath(rect: CGRect(x: 40, y: 104, width: 54, height: 9)), UIColor(hex: 0x2B2E30))
            fill(UIBezierPath(rect: CGRect(x: 14, y: 128, width: 104, height: 6)), p.team)
            for i in 0..<5 { fill(oval(8 + CGFloat(i) * 24, 146, 26, 14), UIColor(hex: 0xC8B48A), stroke: ol, width: 1.2) }
            flag(26, 36, 82)
        default:
            fill(UIBezierPath(roundedRect: CGRect(x: 36, y: 40, width: 58, height: 120), cornerRadius: 14), UIColor(hex: 0xD7DCE5), stroke: UIColor(hex: 0x6E7A8A), width: 2)
            fill(UIBezierPath(roundedRect: CGRect(x: 10, y: 120, width: 110, height: 40), cornerRadius: 10), UIColor(hex: 0xBCC4D0), stroke: UIColor(hex: 0x6E7A8A), width: 2)
            ctx.cgContext.saveGState()
            ctx.cgContext.setShadow(offset: .zero, blur: 8, color: p.team.cgColor)
            fill(UIBezierPath(rect: CGRect(x: 46, y: 60, width: 4, height: 90)), p.team)
            fill(UIBezierPath(rect: CGRect(x: 80, y: 60, width: 4, height: 90)), p.team)
            fill(UIBezierPath(rect: CGRect(x: 14, y: 132, width: 102, height: 4)), p.team)
            fill(circle(65, 40, 16), p.team.withAlphaComponent(0.7), stroke: p.teamDark, width: 1.5)
            ctx.cgContext.restoreGState()
            fill(UIBezierPath(roundedRect: CGRect(x: 56, y: 80, width: 18, height: 28), cornerRadius: 6), UIColor(hex: 0x2B2D42))
        }
    }

    // MARK: Turrets (44x34, facing right)

    private func drawTurret(_ ctx: UIGraphicsImageRendererContext, _ era: Int, _ s: Species) {
        let p = ArtFactory.palette(s)
        let ol = ArtFactory.outline
        switch era {
        case 0:
            fill(UIBezierPath(rect: CGRect(x: 6, y: 24, width: 30, height: 6)), UIColor(hex: 0x8D5A33), stroke: ol, width: 1.2)
            fill(circle(10, 30, 4), UIColor(hex: 0x5E3A1E)); fill(circle(32, 30, 4), UIColor(hex: 0x5E3A1E))
            line(CGPoint(x: 20, y: 24), CGPoint(x: 34, y: 6), UIColor(hex: 0x7A4B26), width: 3)
            fill(circle(35, 6, 5), UIColor(hex: 0x8D8D8D), stroke: ol, width: 1)
        case 1:
            fill(UIBezierPath(rect: CGRect(x: 8, y: 14, width: 30, height: 5)), UIColor(hex: 0x8D5A33), stroke: ol, width: 1.2)
            let bow = UIBezierPath()
            bow.move(to: CGPoint(x: 30, y: 2)); bow.addQuadCurve(to: CGPoint(x: 30, y: 32), controlPoint: CGPoint(x: 42, y: 17))
            bow.lineWidth = 3; UIColor(hex: 0x6B4A2B).setStroke(); bow.stroke()
            line(CGPoint(x: 30, y: 2), CGPoint(x: 14, y: 16.5), .white, width: 0.8)
            line(CGPoint(x: 30, y: 32), CGPoint(x: 14, y: 16.5), .white, width: 0.8)
            fill(UIBezierPath(rect: CGRect(x: 4, y: 22, width: 18, height: 10)), p.team, stroke: ol, width: 1)
        case 2:
            fill(UIBezierPath(roundedRect: CGRect(x: 10, y: 8, width: 32, height: 13), cornerRadius: 6), UIColor(hex: 0x2D2D2D), stroke: ol, width: 1.2)
            fill(UIBezierPath(rect: CGRect(x: 4, y: 20, width: 26, height: 8)), UIColor(hex: 0x8D5A33), stroke: ol, width: 1.2)
            fill(circle(12, 29, 5), UIColor(hex: 0x5E3A1E)); fill(circle(26, 29, 5), UIColor(hex: 0x5E3A1E))
        case 3:
            for i in 0..<3 { fill(oval(2 + CGFloat(i) * 12, 24, 16, 9), UIColor(hex: 0xC8B48A), stroke: ol, width: 1) }
            fill(UIBezierPath(roundedRect: CGRect(x: 10, y: 10, width: 18, height: 14), cornerRadius: 3), UIColor(hex: 0x3A3F44), stroke: ol, width: 1.2)
            fill(UIBezierPath(rect: CGRect(x: 26, y: 14, width: 18, height: 4)), UIColor(hex: 0x2A2E33))
            fill(UIBezierPath(rect: CGRect(x: 12, y: 12, width: 4, height: 10)), p.team)
        default:
            fill(UIBezierPath(roundedRect: CGRect(x: 6, y: 20, width: 30, height: 12), cornerRadius: 5), UIColor(hex: 0xBCC4D0), stroke: UIColor(hex: 0x6E7A8A), width: 1.2)
            fill(circle(21, 18, 10), UIColor(hex: 0xD7DCE5), stroke: UIColor(hex: 0x6E7A8A), width: 1.2)
            fill(UIBezierPath(rect: CGRect(x: 26, y: 15, width: 17, height: 5)), UIColor(hex: 0x8E99A8))
            ctx.cgContext.saveGState()
            ctx.cgContext.setShadow(offset: .zero, blur: 5, color: p.team.cgColor)
            fill(circle(21, 18, 4), p.team)
            ctx.cgContext.restoreGState()
        }
    }

    // MARK: Backgrounds

    private func drawBackground(_ ctx: UIGraphicsImageRendererContext, era: Int, size: CGSize, groundHeight: CGFloat) {
        let c = ctx.cgContext
        let skies: [(UInt32, UInt32)] = [(0x7EC8EE, 0xE4F6FF), (0x9DBEE3, 0xF6F0DC), (0xF2A65A, 0xFBE3C4),
                                         (0x8FA6B4, 0xDDE3E6), (0x1C1B3A, 0x5B3F82)]
        let hills: [(UInt32, UInt32)] = [(0x9CCB8F, 0x6FAF63), (0x8DAA87, 0x638A5F), (0xA38E77, 0x7E6B57),
                                         (0x7C8A8F, 0x58656B), (0x3B3666, 0x2A2550)]
        let grounds: [(UInt32, UInt32)] = [(0x7CB342, 0x8B5E34), (0x6A994E, 0x6F4E37), (0xB5A16A, 0x8A6A45),
                                           (0x6B705C, 0x4F4A3E), (0x3D3B66, 0x26244A)]
        let (top, bottom) = skies[era]
        let colors = [UIColor(hex: top).cgColor, UIColor(hex: bottom).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height - groundHeight), options: [])
        }
        let w = size.width, h = size.height, gy = h - groundHeight

        // Sun / moon / stars
        if era == 4 {
            var r = SeededRandom(seed: 42)
            for _ in 0..<60 {
                let x = CGFloat.random(in: 0...w, using: &r), y = CGFloat.random(in: 0...max(1, gy * 0.8), using: &r)
                fill(circle(x, y, CGFloat.random(in: 0.6...1.6, using: &r)), UIColor(white: 1, alpha: 0.8))
            }
            fill(circle(w * 0.78, h * 0.18, 22), UIColor(hex: 0xF4F1FF))
            fill(circle(w * 0.78 + 8, h * 0.18 - 6, 20), UIColor(hex: top))
        } else {
            let sun = era == 2 ? UIColor(hex: 0xFFE08A) : UIColor(hex: 0xFFF3B0)
            fill(circle(w * 0.8, h * 0.2, 24), sun.withAlphaComponent(0.9))
            var r = SeededRandom(seed: UInt64(7 + era))
            for _ in 0..<4 {
                let x = CGFloat.random(in: 0...w, using: &r), y = CGFloat.random(in: h * 0.08...h * 0.35, using: &r)
                let cloud = UIColor(white: 1, alpha: era == 3 ? 0.55 : 0.85)
                fill(oval(x, y, 60, 18), cloud)
                fill(oval(x + 14, y - 10, 34, 22), cloud)
            }
        }

        func hillLayer(_ color: UIColor, base: CGFloat, amp: CGFloat, freq: CGFloat, phase: CGFloat) {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: gy))
            var x: CGFloat = 0
            while x <= w {
                let y = base - amp * (0.5 + 0.5 * sin(x / w * .pi * freq + phase))
                path.addLine(to: CGPoint(x: x, y: y))
                x += 6
            }
            path.addLine(to: CGPoint(x: w, y: gy))
            path.close()
            fill(path, color)
        }
        hillLayer(UIColor(hex: hills[era].0), base: gy - 10, amp: h * 0.22, freq: 3.2, phase: 0.8)
        hillLayer(UIColor(hex: hills[era].1), base: gy + 2, amp: h * 0.12, freq: 5.1, phase: 2.1)

        // Ground
        fill(UIBezierPath(rect: CGRect(x: 0, y: gy, width: w, height: groundHeight)), UIColor(hex: grounds[era].1))
        fill(UIBezierPath(rect: CGRect(x: 0, y: gy, width: w, height: 10)), UIColor(hex: grounds[era].0))
        var r = SeededRandom(seed: UInt64(99 + era))
        for _ in 0..<40 {
            let x = CGFloat.random(in: 0...max(1, w), using: &r), y = CGFloat.random(in: (gy + 16)...max(gy + 17, h), using: &r)
            fill(oval(x, y, 6, 3), UIColor(hex: grounds[era].1).blend(.black, 0.18))
        }
        if era == 4 {
            c.setShadow(offset: .zero, blur: 6, color: UIColor(hex: 0x5EF2FF).cgColor)
            fill(UIBezierPath(rect: CGRect(x: 0, y: gy, width: w, height: 2)), UIColor(hex: 0x5EF2FF))
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
