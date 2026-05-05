import Foundation
import Combine

/// Single gate for post-booking and post-save feedback prompts: auth, priority, cooldowns, and session lock.
@MainActor
final class FeedbackOrchestrator: ObservableObject {
    static let shared = FeedbackOrchestrator()

    private static let lastShownKey = "feedback_last_shown_at"
    private static let historyKey = "feedback_shown_history"

    private let twentyFourHours: TimeInterval = 24 * 60 * 60
    private let sevenDays: TimeInterval = 7 * 24 * 60 * 60

    @Published private(set) var hasShownThisSession: Bool = false

    private init() {}

    /// Persists pruned history (drops entries older than 7 days).
    private func prunedHistoryTimestamps() -> [TimeInterval] {
        let now = Date().timeIntervalSince1970
        let cutoff = now - sevenDays
        let raw = UserDefaults.standard.array(forKey: Self.historyKey) as? [TimeInterval] ?? []
        let pruned = raw.filter { $0 >= cutoff }
        if pruned.count != raw.count {
            UserDefaults.standard.set(pruned, forKey: Self.historyKey)
        }
        return pruned
    }

    private func lastShownDate() -> Date? {
        let t = UserDefaults.standard.double(forKey: Self.lastShownKey)
        guard t > 0 else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    func canShowPrompt() -> Bool {
        if hasShownThisSession { return false }

        let history = prunedHistoryTimestamps()
        if history.count >= 3 { return false }

        if let last = lastShownDate(), Date().timeIntervalSince(last) < twentyFourHours {
            return false
        }

        return true
    }

    /// Call after a prompt is actually presented (sheet shown).
    func didShowPrompt() {
        hasShownThisSession = true
        let now = Date().timeIntervalSince1970
        UserDefaults.standard.set(now, forKey: Self.lastShownKey)
        var history = prunedHistoryTimestamps()
        history.append(now)
        UserDefaults.standard.set(history, forKey: Self.historyKey)
    }

    /// Parent sign-in entry point: post-booking first, else post-save (unless venue search is active).
    func checkAndPresentBestPrompt() async {
        guard APIService.shared.authToken != nil else { return }
        guard canShowPrompt() else { return }

        if let ctx = await FeedbackCoordinator.shared.fetchFirstPendingBookingFeedback() {
            let opened = FeedbackCoordinator.shared.openFeedback(bookingId: ctx.bookingId, className: ctx.className)
            if opened {
                didShowPrompt()
                return
            }
            // First pending booking exists but was dismissed this session — fall through to post-save.
        }

        guard !FeedbackPromptManager.shared.isVenueSearchActive else { return }

        if let prompt = await APIService.shared.getPendingPrompt() {
            FeedbackPromptManager.shared.presentPrompt(prompt: prompt)
            didShowPrompt()
        }
    }
}
