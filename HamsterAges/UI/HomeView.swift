import SwiftUI

struct HomeView: View {
    let store: ProgressStore
    let shop: Store
    let ads: AdService
    let onPlay: (BattleMode) -> Void
    /// Campaign map: play (or replay) a specific stage.
    var onPlayStage: (Int, Bool) -> Void = { _, _ in }
    @State private var showMap = false
    @State private var showPrep = false
    @State private var showGenerals = false
    @State private var showQuests = false
    @State private var showUpgrades = false
    @State private var showShop = false
    @State private var showSettings = false
    @State private var showPass = false
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
                Image(uiImage: ArtFactory.shared.background(era: CampaignMapView.era(ofChapter: CampaignMapView.chapter(of: p.stage)), size: geo.size, groundHeight: 70))
                    .resizable()
                    .ignoresSafeArea()

                DriftingClouds(night: CampaignMapView.era(ofChapter: CampaignMapView.chapter(of: p.stage)) == 4)
                    .allowsHitTesting(false)

                // The player's army stands on the ground in the middle of the screen, led by their general.
                HomeArmy(era: CampaignMapView.era(ofChapter: CampaignMapView.chapter(of: p.stage)), skin: p.skin, loadout: p.loadout,
                         general: p.equipped.flatMap { p.generalLevel($0) > 0 ? $0 : nil }, bob: bob)
                    // Stands in the gap between the farm widget and the stage panel.
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 305)
                    .offset(y: -52)
                    .allowsHitTesting(false)

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
                        if p.tutorialDone == true, let event = LiveEvents.activeTitle() {
                            Label(event, systemImage: "party.popper.fill")
                                .font(Theme.font(12)).foregroundStyle(Theme.ink)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(Capsule().fill(Theme.gold))
                        }
                        HStack(spacing: 8) {
                        // Features unlock one by one so a new player isn't greeted by a wall of widgets.
                        if p.wins >= 1 {
                        StarRoadPill(progress: p, toast: starToast) {
                            guard let r = store.claimStarReward() else { return }
                            Haptics.success()
                            Sound.shared.play(.coin)
                            if let c = r.crate {
                                GameCenter.sync(progress: store.progress)
                                starToast = c.isNew ? L10n.f("%@ joined!", c.general.name) : L10n.f("%@ Lv %lld", c.general.name, c.newLevel)
                            } else {
                                starToast = "+\(r.seeds) 🌻"
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { starToast = nil } }
                        }
                        .fixedSize()
                        }
                        if p.highestStage >= 5 {
                            Button { showPass = true } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "crown.fill").foregroundStyle(Theme.gold)
                                    Text("HAMSTER PASS").foregroundStyle(Theme.gold)
                                    Text("\(store.passTier)/\(HamsterPass.tiers)").foregroundStyle(.white).monospacedDigit()
                                }
                                .font(Theme.font(12))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Capsule().fill(Theme.panel))
                                .overlay(Capsule().stroke(Theme.gold.opacity(0.7), lineWidth: 1.5))
                                .fixedSize()
                                .overlay(alignment: .topTrailing) {
                                    if store.passClaimable() > 0 {
                                        Circle().fill(Theme.red).frame(width: 12, height: 12).offset(x: 3, y: -3)
                                    }
                                }
                            }
                            .buttonStyle(PressScale())
                        }
                        if store.piggy >= ProgressStore.piggyCap {
                            Button { showShop = true } label: {
                                Image(uiImage: ArtFactory.shared.piggyBank()).resizable().scaledToFit().frame(width: 34, height: 28)
                                    .padding(.horizontal, 6).padding(.vertical, 1)
                                    .background(Capsule().fill(Theme.panel))
                                    .overlay(Capsule().stroke(Color(hex: 0xF8A5C2), lineWidth: 1.5))
                                    .overlay(alignment: .topTrailing) {
                                        Circle().fill(Theme.red).frame(width: 12, height: 12).offset(x: 3, y: -3)
                                    }
                            }
                            .buttonStyle(PressScale())
                            .accessibilityLabel(Text("Piggy Bank"))
                        }
                        }
                        if let left = store.starterOfferRemaining() {
                            Button { showShop = true } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "gift.fill").font(.system(size: 20)).foregroundStyle(Theme.gold)
                                    VStack(alignment: .leading, spacing: 0) {
                                        HStack(spacing: 6) {
                                            Text("STARTER PACK").font(Theme.font(13)).foregroundStyle(Theme.gold)
                                            Label(OfferTimer.text(left), systemImage: "timer").font(Theme.font(10)).foregroundStyle(.white.opacity(0.85))
                                        }
                                        Text(L10n.t("3,000 🌻 + 2 Hero Crates") + (shop.product(.starterPack).map { " · \($0.displayPrice)" } ?? ""))
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
                        if p.battlesPlayed >= 4 {
                            SeedFarmWidget(store: store, ads: ads).padding(.bottom, 8)
                        }
                    }
                    Spacer()

                    // Right: stage panel
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            if p.tutorialDone == true {
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
                            }
                            if p.battlesPlayed >= 3 {
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
                            }
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
                            if p.highestStage >= 2 {
                                Button { showMap = true } label: {
                                    HStack(spacing: 6) {
                                        OutlinedText(text: "Stage \(p.stage)", size: 30)
                                        Image(systemName: "map.fill").font(.system(size: 15, weight: .black)).foregroundStyle(Theme.ink)
                                            .frame(width: 30, height: 30).background(Circle().fill(Theme.gold))
                                    }
                                }
                                .buttonStyle(PressScale())
                                .accessibilityHint(Text("Map"))
                            } else {
                                OutlinedText(text: "Stage \(p.stage)", size: 30)
                            }
                            if p.battlesPlayed >= 1 {
                                let foe = RatGeneral.forStage(p.stage)
                                HStack(spacing: 6) {
                                    RatGeneralBadge(general: foe, size: 30)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(L10n.f("vs %@", foe.name)).font(Theme.font(12)).foregroundStyle(.white)
                                            .lineLimit(1).minimumScaleFactor(0.7)
                                        Text(p.stage >= 3 ? "\(foe.style) · \(Int(difficulty.aiStats * 100))%" : foe.style)
                                            .font(Theme.font(10)).foregroundStyle(Theme.gold).lineLimit(1).minimumScaleFactor(0.7)
                                    }
                                }
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(Color.black.opacity(0.3)))
                                .accessibilityElement(children: .combine)
                            }
                            let elites = RatTrait.pool(stage: p.stage)
                            if difficulty.modifier != .none || !elites.isEmpty {
                                HStack(spacing: 6) {
                                    if difficulty.modifier != .none {
                                        Label(difficulty.modifier.title, systemImage: difficulty.modifier.icon)
                                            .font(Theme.font(12)).foregroundStyle(Theme.gold)
                                            .help(difficulty.modifier.detail)
                                    }
                                    if !elites.isEmpty {
                                        HStack(spacing: 2) {
                                            ForEach(elites, id: \.self) { t in
                                                Image(uiImage: ArtFactory.shared.traitBadge(t)).resizable().frame(width: 16, height: 16)
                                                    .accessibilityLabel(t.title)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(Color.black.opacity(0.35)))
                            }
                        }

                        Button {
                            // From the 3rd battle on: scout the rival and set the squad first.
                            if p.battlesPlayed >= 3 { showPrep = true } else { onPlay(.campaign) }
                        } label: {
                            Label("BATTLE", systemImage: "flag.2.crossed.fill")
                                .font(Theme.font(24))
                                .frame(width: 200)
                        }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.green, cornerRadius: 18, depth: 6))

                        HStack(spacing: 8) {
                            if p.wins >= 1 {
                            Button { showUpgrades = true } label: {
                                Text("Army").lineLimit(1).minimumScaleFactor(0.5).frame(width: 86)
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
                            }
                            if p.battlesPlayed >= 2 {
                            Button { showGenerals = true } label: {
                                Text("Heroes").lineLimit(1).minimumScaleFactor(0.5).frame(width: 86)
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
                        }

                        HStack(spacing: 8) {
                            if store.survivalUnlocked {
                                Button { onPlay(.survival) } label: {
                                    VStack(spacing: 0) {
                                        Text("SURVIVAL").font(Theme.font(13)).lineLimit(1).minimumScaleFactor(0.5)
                                        Text(p.bestSurvival.map { L10n.f("Best %@", String(format: "%d:%02d", Int($0) / 60, Int($0) % 60)) } ?? L10n.t("Endless"))
                                            .font(Theme.font(9)).lineLimit(1).minimumScaleFactor(0.6)
                                    }
                                    .frame(width: 86)
                                }
                                .buttonStyle(ChunkyButtonStyle(color: Theme.red, cornerRadius: 12, depth: 3))
                            }
                            if store.challengeUnlocked {
                                let isOpen = store.challengeAvailable()
                                Button { onPlay(.challenge) } label: {
                                    VStack(spacing: 0) {
                                        Text("DAILY").font(Theme.font(13)).lineLimit(1).minimumScaleFactor(0.5)
                                        Text(isOpen ? (DailyChallenge.goal(for: .now) == .destroyBase ? DailyChallenge.modifier(for: .now).title
                                                                                          : DailyChallenge.goal(for: .now).title) : L10n.t("Cleared ✓")).font(Theme.font(9)).lineLimit(1).minimumScaleFactor(0.6)
                                    }
                                    .frame(width: 86)
                                }
                                .buttonStyle(ChunkyButtonStyle(color: isOpen ? Theme.teal : Theme.disabled, cornerRadius: 12, depth: 3))
                                .disabled(!isOpen)
                                .overlay(alignment: .topTrailing) {
                                    if isOpen { Circle().fill(Theme.red).frame(width: 12, height: 12).offset(x: 4, y: -4) }
                                }
                            }
                            if !store.survivalUnlocked && !store.challengeUnlocked && p.wins >= 1 {
                                Text("Daily Challenge unlocks after Stage \(DailyChallenge.unlockStage - 1)")
                                    .font(Theme.font(11)).foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        #if DEBUG
                        if !ProcessInfo.processInfo.arguments.contains("-demo") {
                        HStack {
                            Button("Balance sim") { showBalance = true }
                            Button("+5k seeds") { store.addSeeds(5000) }
                            Button("Stage+5") { store.debugSkipStages(5) }
                            Button("Reset") { store.debugReset() }
                        }
                        .font(Theme.font(10)).foregroundStyle(.white.opacity(0.6))
                        }
                        #endif
                    }
                    .padding(14)
                    .frame(width: 280)
                    .background(RoundedRectangle(cornerRadius: 24).fill(Color(hex: 0x2B2140, opacity: 0.95)))
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
                case "map": showMap = true
                case "prep": showPrep = true
                case "shop": showShop = true
                case "quests": showQuests = true
                case "pass": showPass = true
                default: break
                }
            }
            #endif
            SheetBackdrop.era = CampaignMapView.era(ofChapter: CampaignMapView.chapter(of: store.progress.stage))
            Music.shared.play(.menu)
            GameCenter.setAccessPoint(visible: true)
            withAnimation(.easeInOut(duration: 0.45).repeatForever()) { bob = true }
            // Don't greet brand-new players with a popup before their first battle.
            if store.progress.tutorialDone == true && store.dailyStatus().available { showDaily = true }
        }
        .fullScreenCover(isPresented: $showPrep) {
            ScaledUI { BattlePrepView(store: store, stage: store.progress.stage) { onPlay(.campaign) } }
        }
        .fullScreenCover(isPresented: $showMap) {
            ScaledUI { CampaignMapView(store: store) { stage, hard in onPlayStage(stage, hard) } }
        }
        .sheet(isPresented: $showUpgrades) {
            // New players start on the cheap base upgrades; once they own some, the Workshop leads.
            UpgradesView(store: store, initialTab: store.progress.upgrades.isEmpty ? .upgrades : .units).presentationSizing(.page)
        }
        .sheet(isPresented: $showDaily) { DailyRewardView(store: store).presentationSizing(.page) }
        .sheet(isPresented: $showShop) { ShopView(store: shop, progress: store, ads: ads).presentationSizing(.page) }
        .sheet(isPresented: $showGenerals) { GeneralsView(store: store, ads: ads).presentationSizing(.page) }
        .sheet(isPresented: $showQuests) { QuestsView(store: store).presentationSizing(.page) }
        .sheet(isPresented: $showSettings) { SettingsView(store: store, shop: shop).presentationSizing(.page) }
        .sheet(isPresented: $showPass) { PassView(store: store, shop: shop).presentationSizing(.page) }
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

/// Army screen: the Workshop (unit variants per role, levels, loadout) and the base Upgrades.
struct UpgradesView: View {
    enum Tab: Hashable { case units, upgrades }
    let store: ProgressStore
    var initialTab: Tab = .units
    @Environment(\.dismiss) private var dismiss
    @State private var tab: Tab?

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        let current = tab ?? initialTab
        ZStack {
            SheetBackdrop()
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    OutlinedText(text: "Army", size: 26, color: Theme.gold)
                    HStack(spacing: 2) {
                        tabButton(.units, title: L10n.t("Units"), icon: "person.3.fill")
                        tabButton(.upgrades, title: L10n.t("Upgrades"), icon: "arrow.up.circle.fill")
                    }
                    .padding(3)
                    .background(Capsule().fill(Theme.panel))
                    Spacer()
                    CurrencyPill(icon: "🌻", value: store.progress.seeds)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 16, weight: .black)).foregroundStyle(.white)
                            .frame(width: 36, height: 36).background(Circle().fill(Color.white.opacity(0.15)))
                    }
                }
                if current == .units {
                    WorkshopGrid(store: store)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(MetaUpgrade.allCases) { u in
                                UpgradeCard(upgrade: u, store: store)
                            }
                        }
                        .padding(.bottom, 12)
                    }
                }
            }
            .padding(16)
        }
    }

    private func tabButton(_ t: Tab, title: String, icon: String) -> some View {
        let on = (tab ?? initialTab) == t
        return Button {
            withAnimation(.spring(response: 0.25)) { tab = t }
            Haptics.tap()
        } label: {
            Label(title, systemImage: icon).font(Theme.font(13))
                .foregroundStyle(on ? Theme.ink : .white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(on ? Theme.gold : Color.clear))
        }
        .buttonStyle(.plain)
    }
}

/// Three columns (melee / ranged / heavy), three variants each. Tap a card to field it; buy to unlock or level up.
private struct WorkshopGrid: View {
    let store: ProgressStore

    var body: some View {
        let p = store.progress
        let era = CampaignMapView.era(ofChapter: CampaignMapView.chapter(of: p.stage))
        HStack(alignment: .top, spacing: 10) {
            ForEach(UnitRole.allCases, id: \.self) { role in
                VStack(spacing: 6) {
                    Text(roleTitle(role).localizedUppercase).font(Theme.font(11)).foregroundStyle(.white.opacity(0.7))
                    ForEach(UnitVariant.of(role), id: \.self) { v in
                        VariantCard(variant: v, era: era, skin: p.skin, level: p.variantLevel(v),
                                    equipped: p.loadout.variant(role) == v, store: store)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func roleTitle(_ r: UnitRole) -> String {
        switch r {
        case .melee: return L10n.t("Melee")
        case .ranged: return L10n.t("Ranged")
        case .heavy: return L10n.t("Heavy")
        }
    }
}

private struct VariantCard: View {
    let variant: UnitVariant
    let era: Int
    let skin: FurSkin
    let level: Int
    let equipped: Bool
    let store: ProgressStore

    var body: some View {
        let locked = level == 0
        HStack(spacing: 8) {
            Image(uiImage: ArtFactory.shared.unit(.hamster, era: era, role: variant.role, skin: skin, variant: variant))
                .resizable().scaledToFit().frame(width: 50, height: 46)
                .saturation(locked ? 0 : 1).opacity(locked ? 0.6 : 1)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(variant.title).font(Theme.font(13)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                    if !locked {
                        Text("Lv \(level)").font(Theme.font(10)).foregroundStyle(Theme.gold).fixedSize()
                    }
                }
                Text(variant.detail).font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75)).lineLimit(2).minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                actionButton(locked: locked)
            }
            Spacer(minLength: 0)
        }
        .padding(7)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(equipped ? Theme.gold.opacity(0.16) : Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(equipped ? Theme.gold : .white.opacity(0.12), lineWidth: equipped ? 2.5 : 1))
        .overlay(alignment: .topTrailing) {
            if equipped {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 16)).foregroundStyle(Theme.gold)
                    .background(Circle().fill(Theme.ink)).offset(x: 5, y: -5)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !locked, !equipped else { return }
            store.equipVariant(variant)
            Haptics.tap()
            Sound.shared.play(.tap)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(equipped ? .isSelected : [])
    }

    @ViewBuilder private func actionButton(locked: Bool) -> some View {
        if locked {
            Button {
                if store.unlockVariant(variant) { store.equipVariant(variant); Haptics.success(); Sound.shared.play(.evolve) }
                else { Haptics.fail() }
            } label: {
                Label("\(variant.unlockCost)", systemImage: "lock.open.fill").font(Theme.font(11))
            }
            .buttonStyle(ChunkyButtonStyle(color: store.canUnlock(variant) ? Theme.purple : Theme.disabled, cornerRadius: 9, depth: 2, compact: true))
        } else if level >= UnitVariant.maxLevel {
            Text("MAX").font(Theme.font(11)).foregroundStyle(Theme.gold)
        } else {
            Button {
                if store.upgradeVariant(variant) { Haptics.success(); Sound.shared.play(.coin) } else { Haptics.fail() }
            } label: {
                Label("\(UnitVariant.upgradeCost(level: level))", systemImage: "arrow.up").font(Theme.font(11))
            }
            .buttonStyle(ChunkyButtonStyle(color: store.canUpgrade(variant) ? Theme.green : Theme.disabled, cornerRadius: 9, depth: 2, compact: true))
        }
    }
}

/// Compact row card: all 8 upgrades fit on one landscape iPhone screen without scrolling.
private struct UpgradeCard: View {
    let upgrade: MetaUpgrade
    let store: ProgressStore

    var body: some View {
        let level = store.progress.level(upgrade)
        let maxed = level >= upgrade.maxLevel
        HStack(spacing: 10) {
            Image(systemName: upgrade.icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.gold)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.white.opacity(0.08)))
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(upgrade.title).font(Theme.font(15)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                    Text("Lv \(level)/\(upgrade.maxLevel)").font(Theme.font(11)).foregroundStyle(.white.opacity(0.6))
                        .fixedSize()
                }
                // At level 0 show what the first purchase gives instead of "+0".
                Text(upgrade.effectText(level: max(1, level))).font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(level == 0 ? 0.55 : 0.85))
                    .lineLimit(1).minimumScaleFactor(0.7)
                if !maxed && level > 0 {
                    Text(L10n.f("Next: %@", upgrade.effectText(level: level + 1)))
                        .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(Theme.gold.opacity(0.9))
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            Spacer(minLength: 4)
            if maxed {
                Text("MAX").font(Theme.font(14)).foregroundStyle(Theme.gold).frame(minWidth: 76)
            } else {
                Button {
                    store.buy(upgrade)
                    Haptics.success()
                } label: {
                    Text("🌻 \(upgrade.cost(level: level))").font(Theme.font(14)).lineLimit(1).frame(minWidth: 64)
                }
                .buttonStyle(ChunkyButtonStyle(color: store.canBuy(upgrade) ? Theme.green : Theme.disabled, cornerRadius: 12, depth: 3))
                .disabled(!store.canBuy(upgrade))
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }
}

struct DailyRewardView: View {
    let store: ProgressStore
    @Environment(\.dismiss) private var dismiss
    @State private var claimed: Int?

    var body: some View {
        let status = store.dailyStatus()
        ZStack {
            SheetBackdrop()
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
/// A few clouds sliding across the menu sky (same art as the battlefield).
private struct DriftingClouds: View {
    let night: Bool

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<4, id: \.self) { i in
                        let speed = 9 + Double(i) * 4
                        let span = geo.size.width + 300
                        let x = (Double(i) * 271 - t * speed).truncatingRemainder(dividingBy: span)
                        Image(uiImage: ArtFactory.shared.cloud(i))
                            .resizable().scaledToFit()
                            .frame(width: 110 + CGFloat(i % 2) * 50)
                            .opacity(night ? 0.12 : 0.85)
                            .position(x: (x < 0 ? x + span : x) - 150, y: geo.size.height * (0.12 + 0.07 * Double(i % 3)))
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct HomeArmy: View {
    let era: Int
    let skin: FurSkin
    var loadout = Loadout()
    let general: GeneralID?
    let bob: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: -12) {
            ForEach(Array([UnitRole.ranged, .melee].enumerated()), id: \.offset) { i, role in
                Image(uiImage: ArtFactory.shared.unit(.hamster, era: era, role: role, skin: skin, variant: loadout.variant(role)))
                    .resizable().scaledToFit()
                    .frame(height: 50)
                    .offset(y: bob == (i % 2 == 0) ? -4 : 0)
            }
            if let general {
                Image(uiImage: ArtFactory.shared.general(general))
                    .resizable().scaledToFit()
                    .frame(height: 74)
                    .offset(y: bob ? -3 : 2)
                    .shadow(color: Theme.gold.opacity(0.6), radius: 8)
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 3, y: 3)
    }
}

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
                    if ready {
                        Text("CLAIM").foregroundStyle(Theme.gold)
                    } else {
                        Text("\(progress.totalStars)/\(next.stars)").foregroundStyle(.white).monospacedDigit()
                    }
                    switch next.reward {
                    case .seeds(let n): Text("→ \(n) 🌻").foregroundStyle(.white.opacity(0.8))
                    case .crate: Text("→ 🎁 Crate").foregroundStyle(.white.opacity(0.8))
                    }
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
    let text: LocalizedStringKey
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
