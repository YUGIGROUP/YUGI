import SwiftUI
import Combine

// Shared payment service to persist payment methods across app instances
class SharedPaymentService: ObservableObject {
    static let shared = SharedPaymentService()
    
    @Published var paymentMethods: [UserPaymentMethod] = []
    
    private let paymentMethodsKey = "persisted_payment_methods"
    
    private init() {
        loadPaymentMethods()
        
        // Start with empty payment methods for new users
        // No initial mock data - users should add their own payment methods
    }
    
    func addPaymentMethod(_ paymentMethod: UserPaymentMethod) {
        // If this is set as default, remove default from other cards
        if paymentMethod.isDefault {
            paymentMethods = paymentMethods.map { method in
                var updatedMethod = method
                updatedMethod = UserPaymentMethod(
                    id: method.id,
                    type: method.type,
                    lastFourDigits: method.lastFourDigits,
                    expiryMonth: method.expiryMonth,
                    expiryYear: method.expiryYear,
                    cardholderName: method.cardholderName,
                    isDefault: false
                )
                return updatedMethod
            }
        }
        
        paymentMethods.append(paymentMethod)
        savePaymentMethods()
        print("💳 SharedPaymentService: Added new payment method \(paymentMethod.id)")
        print("💳 SharedPaymentService: Total payment methods now: \(paymentMethods.count)")
    }
    
    func deletePaymentMethod(_ paymentMethod: UserPaymentMethod) {
        paymentMethods.removeAll { $0.id == paymentMethod.id }
        
        // If we deleted the default card and there are other cards, make the first one default
        if paymentMethod.isDefault && !paymentMethods.isEmpty {
            paymentMethods[0] = UserPaymentMethod(
                id: paymentMethods[0].id,
                type: paymentMethods[0].type,
                lastFourDigits: paymentMethods[0].lastFourDigits,
                expiryMonth: paymentMethods[0].expiryMonth,
                expiryYear: paymentMethods[0].expiryYear,
                cardholderName: paymentMethods[0].cardholderName,
                isDefault: true
            )
        }
        
        savePaymentMethods()
        print("💳 SharedPaymentService: Deleted payment method \(paymentMethod.id)")
        print("💳 SharedPaymentService: Total payment methods now: \(paymentMethods.count)")
    }
    
    func getDefaultPaymentMethod() -> UserPaymentMethod? {
        return paymentMethods.first { $0.isDefault }
    }
    
    func getPaymentMethods() -> [UserPaymentMethod] {
        return paymentMethods
    }
    
    func clearAllPaymentMethods() {
        paymentMethods.removeAll()
        savePaymentMethods()
        print("💳 SharedPaymentService: Cleared all payment methods")
    }
    
    private func savePaymentMethods() {
        if let encoded = try? JSONEncoder().encode(paymentMethods) {
            UserDefaults.standard.set(encoded, forKey: paymentMethodsKey)
        }
    }
    
    private func loadPaymentMethods() {
        if let data = UserDefaults.standard.data(forKey: paymentMethodsKey),
           let decoded = try? JSONDecoder().decode([UserPaymentMethod].self, from: data) {
            paymentMethods = decoded
        }
    }
} 