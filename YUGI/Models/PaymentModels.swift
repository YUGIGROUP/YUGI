import SwiftUI

// MARK: - Payment Models

struct UserPaymentMethod: Identifiable, Codable {
    let id: String
    let type: CardType
    let lastFourDigits: String
    let expiryMonth: Int
    let expiryYear: Int
    let cardholderName: String
    let isDefault: Bool
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
        case .visa: return Color(hex: "#BC6C5C")
        case .mastercard: return Color(hex: "#BC6C5C")
        case .amex: return Color(hex: "#BC6C5C")
        case .discover: return Color(hex: "#BC6C5C")
        }
    }
} 