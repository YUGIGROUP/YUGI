import Foundation
import Combine
import SwiftUI

// MARK: - Response model

struct SupportResponse: Codable {
    let success: Bool
    let message: String
}

// MARK: - Support Service

class SupportService: ObservableObject {
    static let shared = SupportService()
    private init() {}

    /// POST /api/support  — forwards the message to the YUGI support inbox.
    /// The backend reads the sender's name and email from the auth token.
    func sendMessage(_ text: String) -> AnyPublisher<SupportResponse, Error> {
        guard let url = URL(string: "\(APIConfig.baseURL)/support") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        guard let token = APIService.shared.authToken else {
            return Fail(error: URLError(.userAuthenticationRequired)).eraseToAnyPublisher()
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["message": text])

        return URLSession.shared.dataTaskPublisher(for: req)
            .tryMap { data, response -> Data in
                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode) else {
                    // Try to surface the server error message
                    if let body = try? JSONDecoder().decode(SupportResponse.self, from: data) {
                        throw NSError(domain: "SupportService", code: 0,
                                      userInfo: [NSLocalizedDescriptionKey: body.message])
                    }
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: SupportResponse.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}

// MARK: - Admin dashboard support (mock only — not wired to live backend)

enum ContactCategory: String, CaseIterable, Codable {
    case general, booking, payment, technical, feedback, other

    var displayName: String {
        switch self {
        case .general:   return "General Inquiry"
        case .booking:   return "Booking Issue"
        case .payment:   return "Payment Problem"
        case .technical: return "Technical Support"
        case .feedback:  return "Feedback & Suggestions"
        case .other:     return "Other"
        }
    }

    var color: Color {
        switch self {
        case .general:   return .yugiMocha
        case .booking:   return .yugiSage
        case .payment:   return .yugiBlush
        case .technical: return .yugiDeepSage
        case .feedback:  return .yugiBlush
        case .other:     return .yugiMocha
        }
    }
}

struct SupportMessage: Codable {
    let id: UUID
    let userId: String?
    let category: ContactCategory
    let message: String
    let timestamp: Date
    let userEmail: String?
    let userName: String?

    init(category: ContactCategory, message: String,
         userEmail: String? = nil, userName: String? = nil) {
        self.id        = UUID()
        self.userId    = APIService.shared.currentUser?.id
        self.category  = category
        self.message   = message
        self.timestamp = Date()
        self.userEmail = userEmail
        self.userName  = userName
    }
}

class AdminSupportViewModel: ObservableObject {
    @Published var supportMessages: [SupportMessage] = []
    @Published var isLoading = false
    @Published var error: String?

    private var cancellables = Set<AnyCancellable>()

    func loadSupportMessages() {
        isLoading = true
        error     = nil

        // Mock data — replace with a real admin endpoint when available
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isLoading = false
            self?.supportMessages = [
                SupportMessage(category: .general,   message: "I can't find the class I'm looking for",       userEmail: "parent1@example.com", userName: "Sarah Johnson"),
                SupportMessage(category: .technical, message: "The app keeps crashing when I try to book",     userEmail: "parent2@example.com", userName: "Mike Smith"),
                SupportMessage(category: .booking,   message: "I need to cancel my booking for tomorrow",      userEmail: "parent3@example.com", userName: "Emma Wilson"),
                SupportMessage(category: .payment,   message: "I was charged twice for the same class",        userEmail: "parent4@example.com", userName: "David Brown"),
            ]
        }
    }

    func resolveMessage(_ id: UUID) {
        supportMessages.removeAll { $0.id == id }
    }
}
