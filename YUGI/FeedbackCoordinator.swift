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

    @discardableResult
    func openFeedback(bookingId: String, className: String) -> Bool {
        guard !dismissedThisSession.contains(bookingId) else { return false }
        pendingFeedback = FeedbackContext(bookingId: bookingId, className: className)
        return true
    }

    /// Call when the parent taps "Not now" or swipes the sheet away without submitting.
    func skipFeedback(bookingId: String) {
        dismissedThisSession.insert(bookingId)
        if pendingFeedback?.bookingId == bookingId {
            pendingFeedback = nil
        }
    }

    // MARK: - Pending feedback (GET /api/feedback/pending)

    func hasPendingFeedback() async -> Bool {
        await fetchFirstPendingBookingFeedback() != nil
    }

    func fetchFirstPendingBookingFeedback() async -> FeedbackContext? {
        guard let token = UserDefaults.standard.string(forKey: "authToken"),
              let url = URL(string: "\(APIConfig.baseURL)/feedback/pending") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = APIConfig.timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        print("🎯 FeedbackCoordinator: GET \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                print("🎯 FeedbackCoordinator: Unexpected status \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pending = json["pending"] as? [[String: Any]],
                  let first = pending.first,
                  let bookingId = Self.string(fromMongoJSON: first["bookingId"]),
                  let className = first["className"] as? String else {
                print("🎯 FeedbackCoordinator: No pending feedback or parse failed")
                if let raw = String(data: data, encoding: .utf8) {
                    print("🎯 FeedbackCoordinator: Raw: \(raw.prefix(300))")
                }
                return nil
            }

            print("🎯 FeedbackCoordinator: Found pending - \(bookingId) \(className)")
            return FeedbackContext(bookingId: bookingId, className: className)
        } catch {
            print("🎯 FeedbackCoordinator: Error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Presents the first pending booking feedback sheet if any (respects session dismissals).
    func fetchAndShowPendingFeedback() {
        print("🎯 FeedbackCoordinator: fetchAndShowPendingFeedback called")
        Task { @MainActor in
            guard let ctx = await fetchFirstPendingBookingFeedback() else { return }
            _ = openFeedback(bookingId: ctx.bookingId, className: ctx.className)
        }
    }

    private static func string(fromMongoJSON value: Any?) -> String? {
        if let s = value as? String { return s }
        if let dict = value as? [String: Any] {
            if let oid = dict["$oid"] as? String { return oid }
        }
        return nil
    }
}
