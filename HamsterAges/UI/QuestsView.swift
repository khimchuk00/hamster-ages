import SwiftUI

struct QuestsView: View {
    let store: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @State private var bonusResult: CrateResult?

    var body: some View {
        ZStack {
            Color(hex: 0x241B36).ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    OutlinedText(text: "Daily Quests", size: 26, color: Theme.gold)
                    Spacer()
                    CurrencyPill(icon: "🌻", value: store.progress.seeds)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .black)).foregroundStyle(.white)
                            .frame(width: 36, height: 36).background(Circle().fill(Color.white.opacity(0.15)))
                    }
                }
                if let board = store.progress.questBoard {
                    ForEach(Array(board.quests.enumerated()), id: \.offset) { i, q in
                        QuestRow(quest: q) {
                            if store.claimQuest(at: i) > 0 {
                                Haptics.success()
                                Sound.shared.play(.coin)
                            }
                        }
                    }
                    HStack(spacing: 12) {
                        Image(systemName: "shippingbox.fill").font(.system(size: 26)).foregroundStyle(Theme.gold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Complete all 3 → free Hamster Crate").font(Theme.font(14)).foregroundStyle(.white)
                            Text("New quests every day at midnight").font(Theme.font(11)).foregroundStyle(.white.opacity(0.6))
                        }
                        Spacer()
                        if board.bonusClaimed {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: 26)).foregroundStyle(Theme.green)
                        } else {
                            Button("Open") {
                                if let r = store.claimQuestBonus() {
                                    Haptics.boom()
                                    Sound.shared.play(.evolve)
                                    withAnimation(.spring) { bonusResult = r }
                                }
                            }
                            .buttonStyle(ChunkyButtonStyle(color: board.allClaimed ? Theme.purple : Theme.disabled, cornerRadius: 12, depth: 3))
                            .disabled(!board.allClaimed)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.gold.opacity(0.12)))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.gold.opacity(0.5), lineWidth: 1.5))
                }
                Spacer(minLength: 0)
            }
            .padding(16)

            if let r = bonusResult {
                ZStack {
                    Color.black.opacity(0.7).ignoresSafeArea().onTapGesture { bonusResult = nil }
                    VStack(spacing: 10) {
                        OutlinedText(text: r.isNew ? "NEW GENERAL!" : "LEVEL UP!", size: 26, color: Theme.gold)
                        Image(uiImage: ArtFactory.shared.general(r.general)).resizable().scaledToFit().frame(height: 120)
                        Text("\(r.general.name) · Lv \(r.newLevel)").font(Theme.font(18)).foregroundStyle(.white)
                        Button("Nice!") { bonusResult = nil }.buttonStyle(ChunkyButtonStyle(color: Theme.green))
                    }
                    .padding(24)
                    .background(RoundedRectangle(cornerRadius: 24).fill(Theme.panel))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear { store.refreshDailyState() }
    }
}

private struct QuestRow: View {
    let quest: Quest
    let onClaim: () -> Void

    var body: some View {
        let k = quest.kind
        HStack(spacing: 12) {
            Image(systemName: k.icon).font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.orange)
                .frame(width: 40, height: 40).background(Circle().fill(Color.white.opacity(0.08)))
            VStack(alignment: .leading, spacing: 4) {
                Text(k.title).font(Theme.font(14)).foregroundStyle(.white)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.4))
                    GeometryReader { g in
                        Capsule().fill(Theme.green.gradient)
                            .frame(width: g.size.width * min(1, Double(quest.progress) / Double(k.target)))
                    }
                    Text("\(quest.progress)/\(k.target)").font(Theme.font(10)).foregroundStyle(.white).frame(maxWidth: .infinity)
                }
                .frame(height: 14)
            }
            Spacer(minLength: 8)
            if quest.claimed {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 26)).foregroundStyle(Theme.green)
            } else {
                Button(action: onClaim) { Text("🌻 \(k.reward)").font(Theme.font(14)) }
                    .buttonStyle(ChunkyButtonStyle(color: quest.isComplete ? Theme.green : Theme.disabled, cornerRadius: 12, depth: 3))
                    .disabled(!quest.isComplete)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.07)))
    }
}

/// Idle seed farm widget for the home screen. Re-reads the clock every 30 s.
struct SeedFarmWidget: View {
    let store: ProgressStore
    let ads: AdService
    @State private var collected: Int?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            let amount = store.farmAmount(now: ctx.date)
            let cap = SeedFarm.capacity(highestStage: store.progress.highestStage)
            HStack(spacing: 8) {
                Text("🌻").font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text("SEED FARM").font(Theme.font(11)).foregroundStyle(Theme.gold)
                    Text(collected.map { L10n.f("+%lld collected!", $0) } ?? "\(amount) / \(cap)")
                        .font(Theme.font(13)).foregroundStyle(.white).monospacedDigit()
                }
                Button("Collect") { collect(doubled: false) }
                    .buttonStyle(ChunkyButtonStyle(color: amount > 0 ? Theme.green : Theme.disabled, cornerRadius: 10, depth: 3, compact: true))
                    .disabled(amount <= 0)
                Button {
                    ads.showRewarded(placement: "farm_x2") { ok in
                        if ok {
                            Analytics.log(.adRewarded(placement: "farm_x2"))
                            collect(doubled: true)
                        }
                    }
                } label: { Label("×2", systemImage: "play.rectangle.fill") }
                .buttonStyle(ChunkyButtonStyle(color: amount > 0 ? Theme.purple : Theme.disabled, cornerRadius: 10, depth: 3, compact: true))
                .disabled(amount <= 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panel))
            .fixedSize()
        }
    }

    private func collect(doubled: Bool) {
        let n = store.collectFarm(doubled: doubled)
        guard n > 0 else { return }
        Haptics.success()
        Sound.shared.play(.coin)
        withAnimation { collected = n }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { collected = nil } }
    }
}
