import Foundation
import Combine
import SwiftUI

// MARK: - Response models

struct StripeOnboardingLinkResponse: Codable {
    let url: String
}

struct StripeConnectStatusResponse: Codable {
    let hasAccount: Bool
    let onboardingComplete: Bool?
    let chargesEnabled: Bool?
    let payoutsEnabled: Bool?
    let requirementsCurrentlyDue: [String]?

    // Whether the provider is fully set up and able to receive payouts.
    var isFullyOnboarded: Bool {
        hasAccount
            && (onboardingComplete ?? false)
            && (payoutsEnabled ?? false)
    }

    // Whether the provider started onboarding but didn't finish.
    var isInProgress: Bool {
        hasAccount && !(onboardingComplete ?? false)
    }

    // Whether Stripe flagged requirements that need attention after onboarding.
    var hasRestrictions: Bool {
        hasAccount
            && (onboardingComplete ?? false)
            && !(payoutsEnabled ?? false)
    }
}

// MARK: - Status enum (for the dashboard widget)

enum StripeConnectStatus {
    case notStarted      // No Stripe account yet
    case inProgress      // Account created, onboarding incomplete
    case restricted      // Onboarded but payouts disabled / requirements due
    case active          // Fully onboarded, payouts enabled

    init(from response: StripeConnectStatusResponse) {
        if !response.hasAccount {
            self = .notStarted
        } else if response.isFullyOnboarded {
            self = .active
        } else if response.isInProgress {
            self = .inProgress
        } else {
            self = .restricted
        }
    }
}

// MARK: - Stripe Connect Service

class StripeConnectService: ObservableObject {
    static let shared = StripeConnectService()
    private init() {}

    /// POST /api/stripe/connect/onboard — creates (or resumes) the provider's
    /// Stripe Express account and returns the hosted onboarding URL.
    /// Passes platform: "ios" so the backend returns yugi:// scheme callbacks.
    func createOnboardingLink() -> AnyPublisher<StripeOnboardingLinkResponse, Error> {
        request(path: "/stripe/connect/onboard", method: "POST")
    }

    /// GET /api/stripe/connect/status — returns the provider's current
    /// onboarding / payouts status.
    func checkStatus() -> AnyPublisher<StripeConnectStatusResponse, Error> {
        request(path: "/stripe/connect/status", method: "GET")
    }

    /// POST /api/stripe/connect/refresh-link — generates a fresh onboarding
    /// link for providers who abandoned the flow mid-way.
    func refreshOnboardingLink() -> AnyPublisher<StripeOnboardingLinkResponse, Error> {
        request(path: "/stripe/connect/refresh-link", method: "POST")
    }

    // MARK: - Shared request helper

    private func request<T: Decodable>(
        path: String,
        method: String
    ) -> AnyPublisher<T, Error> {
        guard let url = URL(string: "\(APIConfig.baseURL)\(path)") else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        guard let token = APIService.shared.authToken else {
            return Fail(error: URLError(.userAuthenticationRequired)).eraseToAnyPublisher()
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        // Body is only sent for POSTs — and for POSTs we always pass platform: "ios"
        // so the backend returns yugi:// URL scheme callbacks for
        // ASWebAuthenticationSession to intercept.
        if method == "POST" {
            req.httpBody = try? JSONSerialization.data(withJSONObject: [
                "platform": "ios"
            ])
        }

        return URLSession.shared.dataTaskPublisher(for: req)
            .tryMap { data, response -> Data in
                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}
