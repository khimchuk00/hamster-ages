import StoreKit
import UIKit

/// Asks for an App Store rating at a happy moment: right after a 3-star win, from the 3rd win on,
/// at most once per app version and once every 60 days (Apple also rate-limits to 3×/year).
@MainActor
enum ReviewPrompt {
    private static let versionKey = "hamsterages.reviewVersion"
    private static let dateKey = "hamsterages.reviewDate"

    static func maybeAsk(progress p: PlayerProgress, lastStars: Int) {
        guard lastStars == 3, p.wins >= 3 else { return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demo") { return }   // keeps CI / store screenshots clean
        #endif
        let d = UserDefaults.standard
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1"
        if d.string(forKey: versionKey) == version { return }
        if let last = d.object(forKey: dateKey) as? Date, Date.now.timeIntervalSince(last) < 60 * 86_400 { return }
        d.set(version, forKey: versionKey)
        d.set(Date.now, forKey: dateKey)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else { return }
            AppStore.requestReview(in: scene)
        }
    }
}
