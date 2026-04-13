import Foundation

enum ClassCategory: String, Codable, CaseIterable {
    case baby = "Baby"
    case toddler = "Toddler"
    case preschool = "Preschool"
    case schoolAge = "School Age"
    case wellness = "Wellness"
    case send = "SEND"

    var description: String {
        switch self {
        case .baby: return "Classes for babies (0-12 months)"
        case .toddler: return "Classes for toddlers (1-3 years)"
        case .preschool: return "Classes for preschoolers (3-5 years)"
        case .schoolAge: return "Classes for school-age children (5+)"
        case .wellness: return "Parent & child wellness classes"
        case .send: return "Classes for children with special educational needs and disabilities"
        }
    }

    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .baby: return "figure.child.circle"
        case .toddler: return "figure.child"
        case .preschool: return "pencil.and.scribble"
        case .schoolAge: return "book.fill"
        case .wellness: return "heart.fill"
        case .send: return "accessibility"
        }
    }
}

// MARK: - Codable (case-insensitive decode, capitalised encode)
extension ClassCategory {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self).trimmingCharacters(in: .whitespacesAndNewlines)
        if let matched = ClassCategory(aiString: raw) {
            self = matched
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ClassCategory value: \(raw)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }

    // Maps a string (from AI or backend) to a ClassCategory, case-insensitively
    init?(aiString: String) {
        let normalised = aiString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalised {
        case "baby": self = .baby
        case "toddler": self = .toddler
        case "preschool": self = .preschool
        case "school age": self = .schoolAge
        case "wellness": self = .wellness
        case "send", "special needs", "special educational needs": self = .send
        default: return nil
        }
    }
}
