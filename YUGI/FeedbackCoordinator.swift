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

    func openFeedback(bookingId: String, className: String) {
        pendingFeedback = FeedbackContext(bookingId: bookingId, className: className)
    }
}
