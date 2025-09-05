import Foundation

enum UserType: String, CaseIterable, Codable {
    case parent = "parent"
    case provider = "provider"

    var description: String {
        switch self {
        case .parent: return "Book and manage classes for your children"
        case .provider: return "List and manage your classes and services"
        }
    }
    var displayName: String {
        switch self {
        case .parent: return "Parent"
        case .provider: return "Provider"
        }
    }
} 