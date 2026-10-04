import SwiftUI

@main
struct HamsterAgesApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("-demo") { AppServices.progress.debugDemoState() }
                    #endif
                    Analytics.trackAppOpen()
                    Music.shared.prewarm()
                    #if DEBUG
                    if !ProcessInfo.processInfo.arguments.contains("-demo") { GameCenter.authenticate() }
                    #else
                    GameCenter.authenticate()
                    #endif
                }
        }
    }
}

/// Long-lived services, created exactly once (RootView.init can run many times).
@MainActor
enum AppServices {
    static let progress = ProgressStore()
    static let store = Store(progress: progress)
    /// Real AdMob in normal runs; the instant stub for CI/screenshots (`-demo`) and when `-stubads` is passed.
    static let ads: AdService = {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-demo") || args.contains("-stubads") { return StubAdService() }
        return AdMobService()
    }()

    static func startAdsIfReady() {
        guard progress.progress.tutorialDone == true else { return }
        (ads as? AdMobService)?.start()
    }
}

struct RootView: View {
    @State private var store: ProgressStore
    @State private var shop: Store
    @State private var battle: BattleController?
    #if DEBUG
    @State private var artSheet: DebugArtSheet.Kind?
    #endif
    @Environment(\.scenePhase) private var scenePhase
    private let ads: AdService = AppServices.ads

    init() {
        _store = State(initialValue: AppServices.progress)
        _shop = State(initialValue: AppServices.store)
    }

    var body: some View {
        ZStack {
            if let battle {
                BattleView(controller: battle, store: store, ads: ads) {
                    let r = battle.result
                    withAnimation(.easeInOut(duration: 0.3)) { self.battle = nil }
                    AppServices.startAdsIfReady()
                    let p = store.progress
                    if p.wins >= 1 { Reminders.requestPermissionIfNeeded() }
                    if AdPolicy.shouldShowInterstitial(battlesPlayed: p.battlesPlayed, removeAds: p.removeAds == true,
                                                       lastBattleWon: r?.won ?? true, stage: r?.stage ?? p.stage) {
                        ads.showInterstitial(placement: "battle_exit")
                    }
                }
                .transition(.opacity)
            } else {
                ScaledUI {
                HomeView(store: store, shop: shop, ads: ads) { mode in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        let stage = mode == .challenge
                            ? DailyChallenge.stage(highestStage: store.progress.highestStage)
                            : store.progress.stage
                        battle = BattleController(stage: stage, progress: store.progress, mode: mode)
                    }
                } onPlayStage: { stage in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        battle = BattleController(stage: min(stage, store.progress.stage), progress: store.progress)
                    }
                }
                }
                .transition(.opacity)
            }
            #if DEBUG
            if let artSheet { DebugArtSheet(kind: artSheet) }
            #endif
        }
        .onAppear {
            RemoteConfig.refresh()
            AppServices.startAdsIfReady()
            // Brand-new players go straight into their first battle — no menus, no popups.
            if store.progress.tutorialDone != true && store.progress.battlesPlayed == 0
                && !ProcessInfo.processInfo.arguments.contains("-demo") {
                battle = BattleController(stage: 1, progress: store.progress)
            }
            #if DEBUG
            // CI screenshots: `-screen battle` jumps straight into a battle.
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-screen"), i + 1 < args.count, args[i + 1] == "battle" {
                let forced = args.firstIndex(of: "-stage").flatMap { $0 + 1 < args.count ? Int(args[$0 + 1]) : nil }
                battle = BattleController(stage: forced ?? store.progress.stage, progress: store.progress)
            }
            if let i = args.firstIndex(of: "-screen"), i + 1 < args.count, args[i + 1].hasPrefix("art") {
                switch args[i + 1] {
                case "artrat": artSheet = .units(.rat)
                case "artbase": artSheet = .bases
                case "artbg": artSheet = .backgrounds
                case "artgen": artSheet = .ratGenerals
                case "artshare": artSheet = .shareCard
                default: artSheet = .units(.hamster)
                }
            }
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.syncFromCloud(); store.refreshDailyState() }
            if phase == .background { Reminders.reschedule(progress: store.progress) }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
    }
}
