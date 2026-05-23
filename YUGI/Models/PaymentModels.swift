import SwiftUI

// MARK: - Payment Models

struct UserPaymentMethod: Identifiable, Codable {
    let id: String          // Stripe payment method ID, e.g. "pm_1Q..."
    let brand: String       // Stripe's lowercase brand name: "visa", "mastercard", "amex", etc.
    let last4: String       // Last four digits
    let expMonth: Int       // Expiry month (1-12)
    let expYear: Int        // Expiry year (four digits, e.g. 2028)
}

extension UserPaymentMethod {
    /// Maps Stripe's brand string to our local CardType for UI display.
    /// Falls back to .visa for unknown brands.
    var displayType: CardType {
        switch brand.lowercased() {
        case "visa": return .visa
        case "mastercard": return .mastercard
        case "amex", "american express": return .amex
        case "discover": return .discover
        default: return .visa
        }
    }
}

enum CardType: String, CaseIterable, Codable {
    case visa = "visa"
    case mastercard = "mastercard"
    case amex = "amex"
    case discover = "discover"
    
    var displayName: String {
        switch self {
        case .visa: return "Visa"
        case .mastercard: return "Mastercard"
        case .amex: return "American Express"
        case .discover: return "Discover"
        }
    }
    
    var iconName: String {
        switch self {
        case .visa: return "creditcard.fill"
        case .mastercard: return "creditcard.fill"
        case .amex: return "creditcard.fill"
        case .discover: return "creditcard.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .visa: return Color.yugiMocha
        case .mastercard: return Color.yugiMocha
        case .amex: return Color.yugiMocha
        case .discover: return Color.yugiMocha
        }
    }
}
