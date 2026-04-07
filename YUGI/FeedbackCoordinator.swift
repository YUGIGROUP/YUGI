//
//  FeedbackCoordinator.swift
//  YUGI
//

import Foundation

struct FeedbackContext: Identifiable {
    let id = UUID()
    let bookingId: String
    let className: String
}

final class FeedbackCoordinator: ObservableObject {
    static let shared = FeedbackCoordinator()
    private init() {}

    @Published var pendingFeedback: FeedbackContext?

    /// Booking IDs the parent has dismissed during this session — won't be re-shown.
    private var dismissedThisSession: Set<String> = []

    func openFeedback(bookingId: String, className: String) {
        guard !dismissedThisSession.contains(bookingId) else { return }
        pendingFeedback = FeedbackContext(bookingId: bookingId, className: className)
    }

    /// Call when the parent taps "Not now" or swipes the sheet away without submitting.
    func skipFeedback(bookingId: String) {
        dismissedThisSession.insert(bookingId)
        if pendingFeedback?.bookingId == bookingId {
            pendingFeedback = nil
        }
    }

    // MARK: - Pending feedback fetch (called on app foreground)

    /// Fetches the first unreviewed booking from the server and presents the feedback
    /// carousel automatically — unless the parent has already dismissed it this session.
    func fetchAndShowPendingFeedback() {
            print("🎯 FeedbackCoordinator: fetchAndShowPendingFeedback called")
            guard let token = UserDefaults.standard.string(forKey: "authToken") else {
                print("🎯 FeedbackCoordinator: No auth token found")
                return
            }
            guard let url = URL(string: "https://yugi-production.up.railway.app/api/feedback/pending") else { return }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            print("🎯 FeedbackCoordinator: Calling /api/feedback/pending")

            URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                if let error = error {
                    print("🎯 FeedbackCoordinator: Error: \(error.localizedDescription)")
                    return
                }
                if let http = response as? HTTPURLResponse {
                    print("🎯 FeedbackCoordinator: Response status: \(http.statusCode)")
                }
                guard let self = self,
                      let data = data,
                      let http = response as? HTTPURLResponse, http.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let pending = json["pending"] as? [[String: Any]],
                      let first = pending.first,
                      let bookingId = first["bookingId"] as? String,
                      let className = first["className"] as? String
                else {
                    print("🎯 FeedbackCoordinator: No pending feedback or parse failed")
                    if let data = data, let raw = String(data: data, encoding: .utf8) {
                        print("🎯 FeedbackCoordinator: Raw: \(raw.prefix(300))")
                    }
                    return
                }

                print("🎯 FeedbackCoordinator: Found pending - \(bookingId) \(className)")

                DispatchQueue.main.async {
                    self.openFeedback(bookingId: bookingId, className: className)
                }
            }.resume()
        }
}
