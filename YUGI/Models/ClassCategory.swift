import Foundation

enum ClassCategory: String, Codable, CaseIterable {
    case baby = "Baby"
    case toddler = "Toddler"
    case preschool = "Preschool"
    case schoolAge = "School Age"
    case wellness = "Wellness"
    case music = "Music"
    case art = "Art"
    case sports = "Sports"
    case dance = "Dance"
    case swimming = "Swimming"
    case cooking = "Cooking"
    case stem = "STEM"
    case languages = "Languages"
    case drama = "Drama"
    case outdoors = "Outdoors"
    case specialNeeds = "Special Needs"
    case party = "Party"
    case other = "Other"

    var description: String {
        switch self {
        case .baby: return "Classes for babies (0-12 months)"
        case .toddler: return "Classes for toddlers (1-3 years)"
        case .preschool: return "Classes for preschoolers (3-5 years)"
        case .schoolAge: return "Classes for school-age children (5+)"
        case .wellness: return "Parent & child wellness classes"
        case .music: return "Music and singing classes"
        case .art: return "Arts and crafts classes"
        case .sports: return "Sports and physical activity classes"
        case .dance: return "Dance and movement classes"
        case .swimming: return "Swimming and water classes"
        case .cooking: return "Cooking and baking classes"
        case .stem: return "Science, technology, engineering and maths"
        case .languages: return "Language learning classes"
        case .drama: return "Drama and performance classes"
        case .outdoors: return "Outdoor and nature classes"
        case .specialNeeds: return "Classes for children with special needs"
        case .party: return "Party and events"
        case .other: return "Other classes"
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
        case .music: return "music.note"
        case .art: return "paintbrush.fill"
        case .sports: return "figure.run"
        case .dance: return "figure.dance"
        case .swimming: return "figure.pool.swim"
        case .cooking: return "fork.knife"
        case .stem: return "flask.fill"
        case .languages: return "globe"
        case .drama: return "theatermasks.fill"
        case .outdoors: return "leaf.fill"
        case .specialNeeds: return "accessibility"
        case .party: return "party.popper.fill"
        case .other: return "star.fill"
        }
    }
}

// MARK: - Codable (case-insensitive decode, capitalized encode)
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
        case "music": self = .music
        case "art": self = .art
        case "sports": self = .sports
        case "dance": self = .dance
        case "swimming": self = .swimming
        case "cooking": self = .cooking
        case "stem": self = .stem
        case "languages": self = .languages
        case "drama": self = .drama
        case "outdoors": self = .outdoors
        case "special needs": self = .specialNeeds
        case "party": self = .party
        case "other": self = .other
        default: return nil
        }
    }
}
