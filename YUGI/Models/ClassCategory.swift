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
        case .baby: return "figure.child.circle"
        case .toddler: return "figure.child"
        case .wellness: return "heart.fill"
        }
    }
}

// MARK: - Codable (case-insensitive decode, capitalized encode)
extension ClassCategory {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self).trimmingCharacters(in: .whitespacesAndNewlines)
        switch raw.lowercased() {
        case "baby":
            self = .baby
        case "toddler":
            self = .toddler
        case "wellness":
            self = .wellness
        default:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ClassCategory value: \(raw)")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue) // Always capitalized first letter per rawValue
    }
} 