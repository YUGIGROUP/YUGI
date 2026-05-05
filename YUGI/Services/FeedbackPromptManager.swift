import Foundation
import Combine

@MainActor
final class FeedbackPromptManager: ObservableObject {
    static let shared = FeedbackPromptManager()

    @Published var pendingPrompt: PendingPrompt?
    @Published var isShowingPrompt: Bool = false
    @Published var isVenueSearchActive: Bool = false

    private let apiService = APIService.shared
    private var hasCheckedThisSession = false
    private(set) var hasShownThisSession = false

    private init() {}

    func checkForPendingPrompt() async {
        guard !hasCheckedThisSession, !hasShownThisSession else { return }
        hasCheckedThisSession = true

        guard !isVenueSearchActive else { return }

        guard let prompt = await apiService.getPendingPrompt() else { return }
        guard !isVenueSearchActive else { return }

        pendingPrompt = prompt
        isShowingPrompt = true
        hasShownThisSession = true
    }

    func dismissPrompt() {
        isShowingPrompt = false
        pendingPrompt = nil
    }

    func setVenueSearchActive(_ isActive: Bool) {
        isVenueSearchActive = isActive
    }
}
