import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

enum Theme {
    static let cream = Color(hex: 0xFFF4DE)
    static let ink = Color(hex: 0x3A2A22)
    static let orange = Color(hex: 0xF4A259)
    static let teal = Color(hex: 0x23A8C9)
    static let red = Color(hex: 0xE04848)
    static let gold = Color(hex: 0xFFC83D)
    static let green = Color(hex: 0x5BC25B)
    static let purple = Color(hex: 0x8E5BD9)
    static let panel = Color(hex: 0x2B2140, opacity: 0.82)
    static let disabled = Color(hex: 0x8A8496)

    static func font(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }

    static func rarityColor(_ r: CardRarity) -> Color {
        switch r {
        case .common: return Color(hex: 0x5B9BD5)
        case .rare: return purple
        case .epic: return gold
        }
    }
}

/// Chunky, "pressable" casual-game button.
struct ChunkyButtonStyle: ButtonStyle {
    var color: Color = Theme.green
    var cornerRadius: CGFloat = 14
    var depth: CGFloat = 4
    /// Smaller padding/font for dense widgets.
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(Theme.font(compact ? 13 : 17))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 0, x: 0, y: 1.5)
            .padding(.horizontal, compact ? 10 : 16)
            .padding(.vertical, compact ? 6 : 10)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(color)
                    .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(.white.opacity(0.35), lineWidth: 1.5).padding(1))
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(color.mix(with: .black, by: 0.35))
                    .offset(y: pressed ? 1 : depth)
            )
            .offset(y: pressed ? depth - 1 : 0)
            .scaleEffect(pressed ? 0.98 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: pressed)
    }
}

/// Text with a dark outline — readable on any background.
/// Literals are localized (`LocalizedStringKey`); `String` values are shown verbatim (localize them via `L10n`).
struct OutlinedText: View {
    private let key: LocalizedStringKey?
    private let plain: String
    var size: CGFloat = 20
    var color: Color = .white
    var outline: Color = Theme.ink

    init(text: LocalizedStringKey, size: CGFloat = 20, color: Color = .white, outline: Color = Theme.ink) {
        key = text; plain = ""
        self.size = size; self.color = color; self.outline = outline
    }

    init<S: StringProtocol>(text: S, size: CGFloat = 20, color: Color = .white, outline: Color = Theme.ink) {
        key = nil; plain = String(text)
        self.size = size; self.color = color; self.outline = outline
    }

    private var label: Text { key.map { Text($0) } ?? Text(verbatim: plain) }

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let a = Double(i) / 8 * 2 * .pi
                label.font(Theme.font(size)).foregroundStyle(outline)
                    .offset(x: cos(a) * size * 0.08, y: sin(a) * size * 0.08)
            }
            label.font(Theme.font(size)).foregroundStyle(color)
        }
    }
}

struct CurrencyPill: View {
    let icon: String
    let value: Int
    var body: some View {
        HStack(spacing: 4) {
            Text(icon).font(.system(size: 16))
            Text("\(value)")
                .font(Theme.font(16))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.panel))
        .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
    }
}

struct ProgressRing: View {
    let fraction: Double
    var color: Color = Theme.gold
    var lineWidth: CGFloat = 4
    var body: some View {
        Circle()
            .trim(from: 0, to: fraction)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }
}
