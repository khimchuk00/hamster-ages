import SwiftUI

struct HomeView: View {
    let store: ProgressStore
    let shop: Store
    let ads: AdService
    let onPlay: (BattleMode) -> Void
    @State private var showGenerals = false
    @State private var showQuests = false
    @State private var showUpgrades = false
    @State private var showShop = false
    @State private var showSettings = false
    @State private var starToast: String?
    @State private var showDaily = false
    @State private var bob = false
    #if DEBUG
    @State private var showBalance = false
    #endif

    var body: some View {
        let p = store.progress
        let difficulty = StageDifficulty(stage: p.stage)
        GeometryReader { geo in
            ZStack {
                Image(uiImage: ArtFactory.shared.background(era: min(4, (p.stage - 1) / 6), size: geo.size, groundHeight: 70))
                    .resizable()
                    .ignoresSafeArea()

                HStack(alignment: .center, spacing: 20) {
                    // Left: logo + army parade
                    VStack(alignment: .leading, spacing: 6) {
                        OutlinedText(text: "HAMSTER", size: 44, color: Theme.orange)
                        OutlinedText(text: "AGES", size: 44, color: Theme.gold)
                            .padding(.top, -14)
                        Text("Hamsters vs rats, from the Stone Age to the stars")
                            .font(Theme.font(13))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.7), radius: 2, y: 1)
                        if let event = LiveEvents.activeTitle() {
                            Label(event, systemImage: "party.popper.fill")
                                .font(Theme.font(12)).foregroundStyle(Theme.ink)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Capsule().fill(Theme.gold))
                        }
                        StarRoadPill(progress: p, toast: starToast) {
                            guard let r = store.claimStarReward() else { return }
                            Haptics.success()
                            Sound.shared.play(.coin)
                            if let c = r.crate {
                                GameCenter.sync(progress: store.progress)
                                starToast = "\(c.general.name) \(c.isNew ? "joined!" : "Lv \(c.newLevel)")"
                            } else {
                                starToast = "+\(r.seeds) 🌻"
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { starToast = nil } }
                        }
                        if p.battlesPlayed >= 3 && p.starterBought != true {
                            Button { showShop = true } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "gift.fill").font(.system(size: 20)).foregroundStyle(Theme.gold)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text("STARTER PACK").font(Theme.font(13)).foregroundStyle(Theme.gold)
                                        Text("3,000 🌻 + No Ads" + (shop.product(.starterPack).map { " · \($0.displayPrice)" } ?? ""))
                                            .font(Theme.font(11)).foregroundStyle(.white)
                                    }
                                }
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.panel))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.gold, lineWidth: 2))
                            }
                            .buttonStyle(PressScale())
                            .padding(.top, 6)
                        }
                        Spacer()
                        HStack(alignment: .bottom, spacing: 12) {
                        HStack(alignment: .bottom, spacing: -6) {
                            ForEach([0, 2, 4], id: \.self) { era in
                                Image(uiImage: ArtFactory.shared.unit(.hamster, era: era, role: era == 4 ? .heavy : (era == 2 ? .ranged : .melee)))
                                    .resizable().scaledToFit()
                                    .frame(height: era == 4 ? 70 : 52)
                                    .offset(y: bob ? (era % 2 == 0 ? -4 : 0) : (era % 2 == 0 ? 0 : -4))
                            }
                        }
                        SeedFarmWidget(store: store, ads: ads)
                        }
                        .padding(.bottom, 8)
                    }
                    Spacer()

                    // Right: stage panel
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Button { showDaily = true } label: {
                                Image(systemName: "gift.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(Theme.panel))
                                    .overlay(alignment: .topTrailing) {
                                        if store.dailyStatus().available {
                                            Circle().fill(Theme.red).frame(width: 12, height: 12).offset(x: 2, y: -2)
                                        }
                                    }
                            }
                            .buttonStyle(PressScale())
                            Button { showQuests = true } label: {
                                Image(systemName: "list.bullet.clipboard.fill")
                                    .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                                    .frame(width: 32, height: 32).background(Circle().fill(Theme.panel))
                                    .overlay(alignment: .topTrailing) {
                                        if p.questBoard?.hasClaimable == true {
                                            Circle().fill(Theme.red).frame(width: 12, height: 12).offset(x: 2, y: -2)
                                        }
                                    }
                            }
                            .buttonStyle(PressScale())
                            Button { showShop = true } label: {
                                Image(systemName: "cart.fill")
                                    .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                                    .frame(width: 32, height: 32).background(Circle().fill(Theme.panel))
                            }
                            .buttonStyle(PressScale())
                            Button { showSettings = true } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                                    .frame(width: 32, height: 32).background(Circle().fill(Theme.panel))
                            }
                            .buttonStyle(PressScale())
                            Spacer()
                            CurrencyPill(icon: "🌻", value: p.seeds).fixedSize()
                        }

                        VStack(spacing: 4) {
                            if difficulty.isBoss {
                                Text("BOSS")
                                    .font(Theme.font(12)).foregroundStyle(.white)
                                    .padding(.horizontal, 10).padding(.vertical, 2)
                                    .background(Capsule().fill(Theme.red))
                            }
                            OutlinedText(text: "Stage \(p.stage)", size: 30)
                            Text("Rat army strength \(Int(difficulty.aiStats * 100))%")
                                .font(Theme.font(12)).foregroundStyle(.white.opacity(0.8))
                            if difficulty.modifier != .none {
                                Label(difficulty.modifier.title, systemImage: difficulty.modifier.icon)
                                    .font(Theme.font(12)).foregroundStyle(Theme.gold)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Capsule().fill(Color.black.opacity(0.35)))
                                    .help(difficulty.modifier.detail)
                            }
                        }

                        Button { onPlay(.campaign) } label: {
                            Label("BATTLE", systemImage: "flag.2.crossed.fill")
                                .font(Theme.font(24))
                                .frame(width: 200)
                        }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.green, cornerRadius: 18, depth: 6))

                        HStack(spacing: 8) {
                            Button { showUpgrades = true } label: {
                                Text("Upgrades").lineLimit(1).minimumScaleFactor(0.7).frame(width: 82)
                            }
                            .buttonStyle(ChunkyButtonStyle(color: Theme.orange))
                            .overlay(alignment: .topTrailing) {
                                if MetaUpgrade.allCases.contains(where: { store.canBuy($0) }) {
                                    Circle().fill(Theme.red).frame(width: 14, height: 14).offset(x: 4, y: -4)
                                }
                            }
                            .overlay(alignment: .top) {
                                // First-session coach mark: nudge toward the first upgrade.
                                if p.wins >= 1 && p.upgrades.isEmpty && MetaUpgrade.allCases.contains(where: { store.canBuy($0) }) {
                                    CoachBubble(text: "Spend seeds here!").offset(y: -44)
                                }
                            }
                            Button { showGenerals = true } label: {
                                Text("Heroes").lineLimit(1).minimumScaleFactor(0.7).frame(width: 82)
                            }
                            .buttonStyle(ChunkyButtonStyle(color: Theme.purple))
                            .overlay(alignment: .top) {
                                if p.tutorialDone == true && !p.upgrades.isEmpty && (p.generals?.count ?? 0) <= 1
                                    && store.freeCrateAvailable() {
                                    CoachBubble(text: "Free hero crate!").offset(y: -44)
                                }
                            }
                            .overlay(alignment: .topTrailing) {
                                if store.freeCrateAvailable() || p.seeds >= Generals.crateCost {
                                    Circle().fill(Theme.red).frame(width: 14, height: 14).offset(x: 4, y: -4)
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            if store.survivalUnlocked {
                                Button { onPlay(.survival) } label: {
                                    VStack(spacing: 0) {
                                        Text("SURVIVAL").font(Theme.font(13))
                                        Text(p.bestSurvival.map { "Best \(Int($0) / 60):\(String(format: "%02d", Int($0) % 60))" } ?? "Endless")
                                            .font(Theme.font(9))
                                    }
                                    .frame(width: 82)
                                }
                                .buttonStyle(ChunkyButtonStyle(color: Theme.red, cornerRadius: 12, depth: 3))
                            }
                            if store.challengeUnlocked {
                                let isOpen = store.challengeAvailable()
                                Button { onPlay(.challenge) } label: {
                                    VStack(spacing: 0) {
                                        Text("DAILY").font(Theme.font(13))
                                        Text(isOpen ? DailyChallenge.modifier(for: .now).title : "Cleared ✓").font(Theme.font(9))
                                    }
                                    .frame(width: 82)
                                }
                                .buttonStyle(ChunkyButtonStyle(color: isOpen ? Theme.teal : Theme.disabled, cornerRadius: 12, depth: 3))
                                .disabled(!isOpen)
                                .overlay(alignment: .topTrailing) {
                                    if isOpen { Circle().fill(Theme.red).frame(width: 12, height: 12).offset(x: 4, y: -4) }
                                }
                            }
                            if !store.survivalUnlocked && !store.challengeUnlocked {
                                Text("Daily Challenge unlocks after Stage \(DailyChallenge.unlockStage - 1)")
                                    .font(Theme.font(11)).foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        #if DEBUG
                        HStack {
                            Button("Balance sim") { showBalance = true }
                            Button("+5k seeds") { store.addSeeds(5000) }
                            Button("Stage+5") { store.debugSkipStages(5) }
                            Button("Reset") { store.debugReset() }
                        }
                        .font(Theme.font(10)).foregroundStyle(.white.opacity(0.6))
                        #endif
                    }
                    .padding(14)
                    .frame(width: 280)
                    .background(RoundedRectangle(cornerRadius: 24).fill(Theme.panel))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
        .onAppear {
            store.refreshDailyState()
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-screen"), i + 1 < args.count {
                switch args[i + 1] {
                case "heroes": showGenerals = true
                case "upgrades": showUpgrades = true
                case "shop": showShop = true
                case "quests": showQuests = true
                default: break
                }
            }
            #endif
            Music.shared.play(.menu)
            GameCenter.setAccessPoint(visible: true)
            withAnimation(.easeInOut(duration: 0.45).repeatForever()) { bob = true }
            // Don't greet brand-new players with a popup before their first battle.
            if store.progress.tutorialDone == true && store.dailyStatus().available { showDaily = true }
        }
        .sheet(isPresented: $showUpgrades) { UpgradesView(store: store) }
        .sheet(isPresented: $showDaily) { DailyRewardView(store: store) }
        .sheet(isPresented: $showShop) { ShopView(store: shop, progress: store) }
        .sheet(isPresented: $showGenerals) { GeneralsView(store: store, ads: ads) }
        .sheet(isPresented: $showQuests) { QuestsView(store: store) }
        .sheet(isPresented: $showSettings) { SettingsView(store: store, shop: shop) }
        #if DEBUG
        .sheet(isPresented: $showBalance) { BalanceDebugView() }
        #endif
    }
}

#if DEBUG
/// Runs headless AI-vs-AI battles across stages/meta levels to sanity-check the difficulty curve.
struct BalanceDebugView: View {
    @State private var lines: [String] = ["stage meta | win% | avg min | era"]
    @State private var running = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, l in
                    Text(l).font(.system(size: 14, design: .monospaced))
                }
                if running { ProgressView().padding(.top, 8) }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            for (stage, meta) in BalanceHarness.defaultMatrix {
                let line = await Task.detached(priority: .userInitiated) { () -> String in
                    let r = BalanceHarness.run(stage: stage, meta: meta, games: 8)
                    return String(format: "%5d %4d | %4.0f | %7.1f | %3.1f", r.stage, r.meta, r.winRate * 100, r.avgMinutes, r.avgEra)
                }.value
                lines.append(line)
                print("[BALANCE] " + line)
            }
            running = false
        }
    }
}
#endif

struct UpgradesView: View {
    let store: ProgressStore
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        ZStack {
            Color(hex: 0x241B36).ignoresSafeArea()
            VStack(spacing: 12) {
                HStack {
                    OutlinedText(text: "Upgrades", size: 26, color: Theme.gold)
                    Spacer()
                    CurrencyPill(icon: "🌻", value: store.progress.seeds)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .black)).foregroundStyle(.white)
                            .frame(width: 36, height: 36).background(Circle().fill(Color.white.opacity(0.15)))
                    }
                }
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(MetaUpgrade.allCases) { u in
                            UpgradeCard(upgrade: u, store: store)
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
            .padding(16)
        }
    }
}

private struct UpgradeCard: View {
    let upgrade: MetaUpgrade
    let store: ProgressStore

    var body: some View {
        let level = store.progress.level(upgrade)
        let maxed = level >= upgrade.maxLevel
        VStack(spacing: 6) {
            Image(systemName: upgrade.icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.gold)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.white.opacity(0.08)))
            Text(upgrade.title).font(Theme.font(15)).foregroundStyle(.white)
            Text("Lv \(level)/\(upgrade.maxLevel)").font(Theme.font(11)).foregroundStyle(.white.opacity(0.6))
            Text(upgrade.effectText(level: level)).font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            if maxed {
                Text("MAX").font(Theme.font(14)).foregroundStyle(Theme.gold).padding(.vertical, 8)
            } else {
                Button {
                    store.buy(upgrade)
                    Haptics.success()
                } label: {
                    Text("🌻 \(upgrade.cost(level: level))").font(Theme.font(14))
                }
                .buttonStyle(ChunkyButtonStyle(color: store.canBuy(upgrade) ? Theme.green : Theme.disabled, cornerRadius: 12, depth: 3))
                .disabled(!store.canBuy(upgrade))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}

struct DailyRewardView: View {
    let store: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @State private var claimed: Int?

    var body: some View {
        let status = store.dailyStatus()
        ZStack {
            Color(hex: 0x241B36).ignoresSafeArea()
            VStack(spacing: 16) {
                OutlinedText(text: "Daily Seeds", size: 28, color: Theme.gold)
                Text("Come back every day — the streak resets if you miss one.")
                    .font(Theme.font(13)).foregroundStyle(.white.opacity(0.8))
                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { day in
                        let isToday = day == status.dayIndex
                        let done = day < status.dayIndex || (!status.available && day == status.dayIndex - 1)
                        VStack(spacing: 4) {
                            Text("Day \(day + 1)").font(Theme.font(11)).foregroundStyle(.white.opacity(0.75))
                            Text(day == 6 ? "🎁" : "🌻").font(.system(size: day == 6 ? 30 : 24))
                            Text("\(ProgressStore.dailyRewards[day])").font(Theme.font(13)).foregroundStyle(.white)
                        }
                        .frame(width: 66, height: 92)
                        .background(RoundedRectangle(cornerRadius: 14).fill(isToday && status.available ? Theme.purple : Color.white.opacity(0.08)))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isToday && status.available ? Theme.gold : .clear, lineWidth: 2))
                        .overlay { if done { Image(systemName: "checkmark.circle.fill").font(.system(size: 26)).foregroundStyle(Theme.green) } }
                    }
                }
                if let claimed {
                    OutlinedText(text: "+\(claimed) 🌻", size: 24, color: Theme.gold)
                    Button("Awesome!") { dismiss() }.buttonStyle(ChunkyButtonStyle(color: Theme.green))
                } else if status.available {
                    Button("Claim") {
                        withAnimation(.spring) { claimed = store.claimDaily() }
                        Haptics.success()
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.green))
                } else {
                    Text("Come back tomorrow!").font(Theme.font(15)).foregroundStyle(.white)
                    Button("Close") { dismiss() }.buttonStyle(ChunkyButtonStyle(color: Theme.teal))
                }
            }
            .padding(20)
        }
    }
}


/// Compact Star Road progress: total stars → next milestone, tappable when ready.
private struct StarRoadPill: View {
    let progress: PlayerProgress
    let toast: String?
    let onClaim: () -> Void

    var body: some View {
        let next = progress.nextStarMilestone
        let ready = progress.starRewardReady
        Button(action: onClaim) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill").foregroundStyle(Theme.gold)
                if let toast {
                    Text(toast).foregroundStyle(.white)
                } else {
                    Text("\(progress.totalStars)/\(next.stars)").foregroundStyle(.white).monospacedDigit()
                    switch next.reward {
                    case .seeds(let n): Text("→ \(n) 🌻").foregroundStyle(.white.opacity(0.8))
                    case .crate: Text("→ 🎁 Crate").foregroundStyle(.white.opacity(0.8))
                    }
                    if ready { Text("CLAIM").foregroundStyle(Theme.gold) }
                }
            }
            .font(Theme.font(12))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(Theme.panel))
            .overlay(Capsule().stroke(ready ? Theme.gold : .white.opacity(0.2), lineWidth: ready ? 2 : 1))
        }
        .buttonStyle(PressScale())
        .disabled(!ready && toast == nil)
    }
}


/// Small bouncing callout used for first-session hints on the home screen.
private struct CoachBubble: View {
    let text: String
    @State private var bounce = false

    var body: some View {
        VStack(spacing: 0) {
            Text(text)
                .font(Theme.font(12)).foregroundStyle(Theme.ink)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Theme.cream))
                .overlay(Capsule().stroke(Theme.orange, lineWidth: 2))
                .fixedSize()
            Image(systemName: "arrowtriangle.down.fill").font(.system(size: 10)).foregroundStyle(Theme.orange)
                .offset(y: -2)
        }
        .offset(y: bounce ? -4 : 0)
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeInOut(duration: 0.5).repeatForever()) { bounce = true } }
    }
}
