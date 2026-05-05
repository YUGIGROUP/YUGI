import Foundation
import Combine

@MainActor
final class FeedbackPromptManager: ObservableObject {
    static let shared = FeedbackPromptManager()

    @Published var pendingPrompt: PendingPrompt?
    @Published var isShowingPrompt: Bool = false
    @Published var isVenueSearchActive: Bool = false

    private init() {}

    func presentPrompt(prompt: PendingPrompt) {
        pendingPrompt = prompt
        isShowingPrompt = true
    }

    func dismissPrompt() {
        isShowingPrompt = false
        pendingPrompt = nil
    }

    func setVenueSearchActive(_ isActive: Bool) {
        isVenueSearchActive = isActive
    }
}
