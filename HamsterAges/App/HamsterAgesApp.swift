import SwiftUI

@main
struct HamsterAgesApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    Analytics.trackAppOpen()
                    Music.shared.prewarm()
                    GameCenter.authenticate()
                }
        }
    }
}

/// Long-lived services, created exactly once (RootView.init can run many times).
@MainActor
enum AppServices {
    static let progress = ProgressStore()
    static let store = Store(progress: progress)
}

struct RootView: View {
    @State private var store: ProgressStore
    @State private var shop: Store
    @State private var battle: BattleController?
    @Environment(\.scenePhase) private var scenePhase
    private let ads: AdService = StubAdService()

    init() {
        _store = State(initialValue: AppServices.progress)
        _shop = State(initialValue: AppServices.store)
    }

    var body: some View {
        ZStack {
            if let battle {
                BattleView(controller: battle, store: store, ads: ads) {
                    withAnimation(.easeInOut(duration: 0.3)) { self.battle = nil }
                    let p = store.progress
                    if p.wins >= 1 { Reminders.requestPermissionIfNeeded() }
                    if AdPolicy.shouldShowInterstitial(battlesPlayed: p.battlesPlayed, removeAds: p.removeAds == true) {
                        ads.showInterstitial(placement: "battle_exit")
                    }
                }
                .transition(.opacity)
            } else {
                HomeView(store: store, shop: shop, ads: ads) { mode in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        let stage = mode == .challenge
                            ? DailyChallenge.stage(highestStage: store.progress.highestStage)
                            : store.progress.stage
                        battle = BattleController(stage: stage, progress: store.progress, mode: mode)
                    }
                }
                .transition(.opacity)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refreshDailyState() }
            if phase == .background { Reminders.reschedule(progress: store.progress) }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
    }
}
