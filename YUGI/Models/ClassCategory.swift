import Foundation

enum ClassCategory: String, Codable, CaseIterable {
    case baby = "Baby"
    case toddler = "Toddler"
    case wellness = "Wellness"
    
    var description: String {
        switch self {
        case .baby:
            return "Classes for babies (0-12 months)"
        case .toddler:
            return "Classes for toddlers (1-3 years)"
        case .wellness:
            return "Parent & child wellness classes"
        }
    }
    
    var displayName: String {
        switch self {
        case .baby: return "Baby"
        case .toddler: return "Toddler"
        case .wellness: return "Wellness"
        }
    }
    
    var iconName: String {
        switch self {
        case .baby: return "baby"
        case .toddler: return "figure.child"
        case .wellness: return "heart.fill"
        }
    }
} 