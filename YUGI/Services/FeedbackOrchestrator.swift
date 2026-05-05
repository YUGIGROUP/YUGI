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
        if hasShownThisSession {
            print("🎯 Orchestrator: canShowPrompt: blocked by hasShownThisSession")
            return false
        }

        let history = prunedHistoryTimestamps()
        if history.count >= 3 {
            print("🎯 Orchestrator: canShowPrompt: blocked by 7d cap (count=\(history.count))")
            return false
        }

        if let last = lastShownDate(), Date().timeIntervalSince(last) < twentyFourHours {
            let hoursAgo = Date().timeIntervalSince(last) / 3600
            print("🎯 Orchestrator: canShowPrompt: blocked by 24h cooldown (last shown \(String(format: "%.1f", hoursAgo)) hours ago)")
            return false
        }

        print("🎯 Orchestrator: canShowPrompt: allowed")
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

        let countAfter = prunedHistoryTimestamps().count
        print("🎯 Orchestrator: marked prompt shown, hasShownThisSession=true, history count=\(countAfter)")
    }

    /// Parent sign-in entry point: post-booking first, else post-save (unless venue search is active).
    func checkAndPresentBestPrompt() async {
        print("🎯 Orchestrator: checkAndPresentBestPrompt called")

        if APIService.shared.authToken == nil {
            print("🎯 Orchestrator: auth gate failed — authToken is nil")
            return
        }
        print("🎯 Orchestrator: auth gate passed")

        let promptAllowed = canShowPrompt()
        print("🎯 Orchestrator: canShowPrompt result: \(promptAllowed)" + (promptAllowed ? "" : " (see canShowPrompt logs above for reason)"))
        guard promptAllowed else { return }

        print("🎯 Orchestrator: checking for pending booking feedback...")
        if let ctx = await FeedbackCoordinator.shared.fetchFirstPendingBookingFeedback() {
            print("🎯 Orchestrator: found pending booking: \(ctx.bookingId) (\(ctx.className))")
            let opened = FeedbackCoordinator.shared.openFeedback(bookingId: ctx.bookingId, className: ctx.className)
            if opened {
                didShowPrompt()
                return
            }
            print("🎯 Orchestrator: pending booking not opened (e.g. dismissed this session) — falling through to venue save check")
        } else {
            print("🎯 Orchestrator: no pending booking")
        }

        guard !FeedbackPromptManager.shared.isVenueSearchActive else {
            print("🎯 Orchestrator: skipping pending venue save — VenueCheckScreen active")
            return
        }

        print("🎯 Orchestrator: checking for pending venue save...")
        if let prompt = await APIService.shared.getPendingPrompt() {
            print("🎯 Orchestrator: found pending save: \(prompt.placeId) (\(prompt.venueName))")
            FeedbackPromptManager.shared.presentPrompt(prompt: prompt)
            didShowPrompt()
        } else {
            print("🎯 Orchestrator: no pending save")
        }
    }

#if DEBUG
    func DEBUG_resetCooldownState() {
        UserDefaults.standard.removeObject(forKey: Self.lastShownKey)
        UserDefaults.standard.removeObject(forKey: Self.historyKey)
        hasShownThisSession = false
        print("🎯 Orchestrator: DEBUG cooldown state reset — lastShown cleared, history cleared, session flag reset")
    }
#endif
}
