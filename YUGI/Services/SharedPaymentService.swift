import SwiftUI
import Combine

/// Fetches and manages the parent's saved payment methods from Stripe via
/// YUGI's backend. No card data is stored locally — all payment methods
/// live on Stripe under the parent's Stripe Customer. This service caches
/// the list in memory only.
@MainActor
class SharedPaymentService: ObservableObject {
    static let shared = SharedPaymentService()
    private init() {
        clearLegacyUserDefaultsStorage()
    }

    @Published private(set) var paymentMethods: [UserPaymentMethod] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    /// Fetches the parent's saved payment methods from the backend.
    /// Updates the published `paymentMethods` array on success.
    func fetchPaymentMethods() async {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        guard let url = URL(string: "\(APIConfig.baseURL)/parent-payments/payment-methods") else {
            lastError = "Invalid URL"
            return
        }
        guard let token = APIService.shared.authToken else {
            lastError = "Not authenticated"
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                lastError = "Failed to fetch payment methods"
                return
            }
            let decoded = try JSONDecoder().decode(PaymentMethodsResponse.self, from: data)
            paymentMethods = decoded.paymentMethods
        } catch {
            lastError = "Failed to fetch payment methods: \(error.localizedDescription)"
        }
    }

    /// Deletes a saved payment method by detaching it from the parent's
    /// Stripe Customer. Refreshes the list on success.
    func deletePaymentMethod(_ paymentMethod: UserPaymentMethod) async {
        guard let url = URL(string: "\(APIConfig.baseURL)/parent-payments/payment-methods/\(paymentMethod.id)") else {
            lastError = "Invalid URL"
            return
        }
        guard let token = APIService.shared.authToken else {
            lastError = "Not authenticated"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                lastError = "Failed to delete payment method"
                return
            }
            await fetchPaymentMethods()
        } catch {
            lastError = "Failed to delete payment method: \(error.localizedDescription)"
        }
    }

    /// Returns the first saved payment method (used as the implicit default).
    /// Stripe handles "default payment method" at the Customer level but for
    /// our UI's purposes the first card in the array is treated as default.
    func defaultPaymentMethod() -> UserPaymentMethod? {
        paymentMethods.first
    }

    /// Clears the in-memory cache (e.g. on sign-out).
    func clearPaymentMethods() {
        paymentMethods = []
    }

    // MARK: - Legacy cleanup

    /// One-time cleanup of any placeholder cards stored in UserDefaults under
    /// the old architecture. Real card data was never stored locally (only
    /// display data and a UUID), so there's no sensitive data to remove —
    /// this just clears the now-obsolete storage key.
    private func clearLegacyUserDefaultsStorage() {
        let legacyKey = "persisted_payment_methods"
        if UserDefaults.standard.object(forKey: legacyKey) != nil {
            UserDefaults.standard.removeObject(forKey: legacyKey)
            print("💳 SharedPaymentService: Cleared legacy UserDefaults payment methods")
        }
    }
}

private struct PaymentMethodsResponse: Codable {
    let paymentMethods: [UserPaymentMethod]
}
