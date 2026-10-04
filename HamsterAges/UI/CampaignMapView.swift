import SwiftUI

/// The campaign as chapters of 10 stages on a winding path, one chapter per age.
/// Any cleared stage can be replayed for more stars; the next one is the glowing node.
struct CampaignMapView: View {
    let store: ProgressStore
    let onPlay: (Int, Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var chapter: Int
    @State private var hard = false
    @State private var selected: Int?
    @State private var pulse = false

    static let perChapter = 10
    static func chapter(of stage: Int) -> Int { (stage - 1) / perChapter }
    /// Background age for a chapter (the last age repeats).
    static func era(ofChapter c: Int) -> Int { min(GameConfig.eras.count - 1, c) }

    init(store: ProgressStore, onPlay: @escaping (Int, Bool) -> Void) {
        self.store = store
        self.onPlay = onPlay
        _chapter = State(initialValue: CampaignMapView.chapter(of: store.progress.stage))
    }

    private var current: Int { store.progress.stage }
    private var lastChapter: Int { CampaignMapView.chapter(of: current) }
    private var stages: [Int] { (1...CampaignMapView.perChapter).map { chapter * CampaignMapView.perChapter + $0 } }
    private var focus: Int {
        if let selected { return selected }
        if hard { return stages.first { (store.progress.hardStars?[$0] ?? 0) == 0 } ?? stages[0] }
        return stages.contains(current) ? current : stages[0]
    }
    private var hardOpen: Bool { store.hardUnlocked(chapter: chapter) }
    private func stars(_ stage: Int) -> Int { hard ? (store.progress.hardStars?[stage] ?? 0) : (store.progress.stars[stage] ?? 0) }
    private func nodeState(_ stage: Int) -> StageNode.NodeState {
        if hard { return stars(stage) > 0 ? .cleared : .next }
        return stage < current ? .cleared : stage == current ? .next : .locked
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image(uiImage: ArtFactory.shared.background(era: CampaignMapView.era(ofChapter: chapter), size: geo.size, groundHeight: 60))
                    .resizable().ignoresSafeArea()
                (hard ? Color(hex: 0x4A0E2E).opacity(0.45) : Color.black.opacity(0.18)).ignoresSafeArea()

                VStack(spacing: 6) {
                    header
                    GeometryReader { g in
                        let pts = positions(in: g.size)
                        ZStack {
                            Path { path in
                                path.move(to: pts[0])
                                for i in 1..<pts.count {
                                    let a = pts[i - 1], b = pts[i]
                                    path.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 + (i % 2 == 0 ? 26 : -26)))
                                }
                            }
                            .stroke(Color.white.opacity(0.75), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [2, 12]))
                            .shadow(color: .black.opacity(0.4), radius: 2, y: 1)

                            ForEach(Array(stages.enumerated()), id: \.offset) { i, stage in
                                StageNode(stage: stage, stars: stars(stage), state: nodeState(stage),
                                          selected: stage == focus, pulse: pulse && (!hard || stage == focus), hard: hard)
                                    .position(pts[i])
                                    .onTapGesture {
                                        selected = stage
                                        Haptics.tap()
                                    }
                            }
                        }
                    }
                    StageCard(stage: focus, stars: stars(focus), playable: hard || focus <= current, hard: hard) {
                        dismiss()
                        onPlay(focus, hard)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.7).repeatForever()) { pulse = true } }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                OutlinedText(text: L10n.f("Chapter %lld", chapter + 1), size: 24, color: Theme.gold)
                Text(GameConfig.eraNames[CampaignMapView.era(ofChapter: chapter)].localizedUppercase)
                    .font(Theme.font(11)).foregroundStyle(.white).shadow(color: .black.opacity(0.6), radius: 1, y: 1)
            }
            let got = stages.reduce(0) { $0 + stars($1) }
            Label("\(got)/\(stages.count * 3)", systemImage: "star.fill")
                .font(Theme.font(13)).foregroundStyle(Theme.gold)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(Theme.panel))
            if hardOpen {
                HStack(spacing: 0) {
                    ForEach([false, true], id: \.self) { h in
                        Button {
                            withAnimation(.spring(response: 0.3)) { hard = h; selected = nil }
                            Haptics.tap()
                        } label: {
                            Text(h ? L10n.t("Hard") : L10n.t("Normal")).font(Theme.font(12))
                                .foregroundStyle(hard == h ? (h ? Color.white : Theme.ink) : Color.white.opacity(0.8))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Capsule().fill(hard == h ? (h ? Theme.red : Theme.gold) : Color.clear))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(Capsule().fill(Theme.panel))
            }
            Spacer()
            HStack(spacing: 6) {
                ForEach(0...(lastChapter + 1), id: \.self) { c in
                    let locked = c > lastChapter
                    Button {
                        guard !locked else { Haptics.fail(); return }
                        withAnimation(.spring(response: 0.3)) {
                            chapter = c; selected = nil
                            if !store.hardUnlocked(chapter: c) { hard = false }
                        }
                    } label: {
                        Group {
                            if locked { Image(systemName: "lock.fill").font(.system(size: 11, weight: .black)) }
                            else { Text("\(c + 1)").font(Theme.font(14)) }
                        }
                        .foregroundStyle(c == chapter ? Theme.ink : .white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(c == chapter ? Theme.gold : Theme.panel))
                        .opacity(locked ? 0.6 : 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 16, weight: .black)).foregroundStyle(.white)
                    .frame(width: 36, height: 36).background(Circle().fill(Theme.panel))
            }
        }
    }

    /// A gentle zig-zag across the screen.
    private func positions(in size: CGSize) -> [CGPoint] {
        let n = CampaignMapView.perChapter
        let margin: CGFloat = 40
        let step = (size.width - margin * 2) / CGFloat(n - 1)
        return (0..<n).map { i in
            let wave = sin(Double(i) * 1.15 + 0.4)
            return CGPoint(x: margin + CGFloat(i) * step, y: size.height * (0.5 + 0.3 * CGFloat(wave)))
        }
    }
}

private struct StageNode: View {
    enum NodeState { case cleared, next, locked }
    let stage: Int
    let stars: Int
    let state: NodeState
    let selected: Bool
    let pulse: Bool
    var hard = false

    var body: some View {
        let boss = stage % 5 == 0
        let d: CGFloat = boss ? 54 : 42
        VStack(spacing: 2) {
            ZStack {
                if state == .next {
                    Circle().stroke(Theme.gold, lineWidth: 3).frame(width: d + 14, height: d + 14)
                        .scaleEffect(pulse ? 1.15 : 0.95).opacity(pulse ? 0.2 : 0.9)
                }
                Circle()
                    .fill(fill.gradient)
                    .frame(width: d, height: d)
                    .overlay(Circle().stroke(selected ? Color.white : Theme.ink, lineWidth: selected ? 3.5 : 2.5))
                    .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
                if boss {
                    RatGeneralBadge(general: .ratKing, size: d - 10).opacity(state == .locked ? 0.55 : 1)
                    Text("\(stage)").font(Theme.font(11)).foregroundStyle(.white)
                        .padding(.horizontal, 5).background(Capsule().fill(Theme.red)).offset(y: d / 2)
                } else if state == .locked {
                    Image(systemName: "lock.fill").font(.system(size: 14, weight: .black)).foregroundStyle(.white.opacity(0.75))
                } else {
                    Text("\(stage)").font(Theme.font(17)).foregroundStyle(state == .next ? Theme.ink : .white)
                }
            }
            .overlay(alignment: .top) {
                if boss { Image(uiImage: ArtFactory.shared.crown()).resizable().frame(width: 26, height: 17).offset(y: -14) }
            }
            HStack(spacing: 1) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: "star.fill").font(.system(size: 9, weight: .black))
                        .foregroundStyle(i < stars ? Theme.gold : Color.black.opacity(0.35))
                }
            }
            .opacity(state == .cleared ? 1 : 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.f("Stage %lld", stage))
    }

    private var fill: Color {
        switch state {
        case .cleared: return hard ? Theme.purple : Theme.green
        case .next: return hard ? Theme.red : Theme.gold
        case .locked: return Theme.disabled
        }
    }
}

private struct StageCard: View {
    let stage: Int
    let stars: Int
    let playable: Bool
    var hard = false
    let onPlay: () -> Void

    var body: some View {
        let foe = RatGeneral.forStage(stage)
        let d = StageDifficulty(stage: stage)
        let elites = RatTrait.pool(stage: stage)
        HStack(spacing: 10) {
            RatGeneralBadge(general: foe, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(L10n.f("Stage %lld", stage)).font(Theme.font(16)).foregroundStyle(.white)
                    if hard {
                        Text(L10n.t("Hard").localizedUppercase).font(Theme.font(10)).foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 1).background(Capsule().fill(Theme.purple))
                    }
                    if d.isBoss {
                        Text("BOSS").font(Theme.font(10)).foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 1).background(Capsule().fill(Theme.red))
                    }
                    if stars > 0 {
                        HStack(spacing: 1) {
                            ForEach(0..<3, id: \.self) { i in
                                Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(i < stars ? Theme.gold : .white.opacity(0.2))
                            }
                        }
                    }
                }
                Text("\(L10n.f("vs %@", foe.name)) · \(foe.style)").font(Theme.font(11)).foregroundStyle(Theme.gold)
                    .lineLimit(1).minimumScaleFactor(0.7)
                HStack(spacing: 6) {
                    if d.modifier != .none {
                        Label(d.modifier.title, systemImage: d.modifier.icon).font(Theme.font(10)).foregroundStyle(.white.opacity(0.85))
                    }
                    ForEach(elites, id: \.self) { t in
                        Image(uiImage: ArtFactory.shared.traitBadge(t)).resizable().frame(width: 14, height: 14)
                    }
                }
            }
            Spacer(minLength: 6)
            Text("🌻 \(ProgressStore.reward(stage: stage, won: true, damageFraction: 1, hard: hard))")
                .font(Theme.font(13)).foregroundStyle(.white)
            Button(action: onPlay) {
                Label(stars > 0 ? L10n.t("Replay") : L10n.t("BATTLE"), systemImage: "flag.2.crossed.fill").font(Theme.font(16))
            }
            .buttonStyle(ChunkyButtonStyle(color: playable ? (hard ? Theme.red : Theme.green) : Theme.disabled, cornerRadius: 14, depth: 4))
            .disabled(!playable)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.panel))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.2), lineWidth: 1))
    }
}
