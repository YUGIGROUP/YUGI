import Foundation
import CoreLocation

// MARK: - Enums

enum ClassStatus: String, Codable {
    case upcoming
    case inProgress
    case completed
    case cancelled
}

// MARK: - Models

struct Class: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let category: ClassCategory
    let provider: Provider
    let location: Location
    let schedule: Schedule
    let pricing: Pricing
    let maxCapacity: Int
    let currentEnrollment: Int
    var averageRating: Double
    let ageRange: String
    var isFavorite: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, category, provider, location
        case schedule, pricing, maxCapacity, currentEnrollment
        case averageRating, ageRange, isFavorite
    }
    
    var isAvailable: Bool {
        currentEnrollment < maxCapacity
    }
}

struct Provider: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let qualifications: [String]
    let contactEmail: String
    let contactPhone: String
    let website: String?
    var rating: Double
}

struct Location: Identifiable, Codable {
    let id: UUID
    let name: String
    let address: Address
    let coordinates: Coordinates
    let accessibilityNotes: String?
    let parkingInfo: String?
    
    struct Coordinates: Codable {
        let latitude: Double
        let longitude: Double
        
        var clLocation: CLLocation {
            CLLocation(latitude: latitude, longitude: longitude)
        }
    }
}

struct Address: Codable {
    let street: String
    let city: String
    let state: String
    let postalCode: String
    let country: String
    
    var formatted: String {
        "\(street), \(city), \(state) \(postalCode)"
    }
}

struct Schedule: Codable {
    let startDate: Date
    let endDate: Date
    let recurringDays: Set<WeekDay>
    let timeSlots: [TimeSlot]
    let totalSessions: Int
    
    struct TimeSlot: Codable {
        let startTime: Date
        let duration: TimeInterval
        
        var endTime: Date {
            startTime.addingTimeInterval(duration)
        }
    }
}

enum WeekDay: Int, Codable, CaseIterable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7
    
    var shortName: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }
}

struct Pricing: Codable {
    let amount: Decimal
    let currency: String
    let type: PricingType
    let description: String?
    
    enum PricingType: String, Codable {
        case perSession
        case perMonth
        case package
    }
}

struct Review: Identifiable, Codable {
    let id: UUID
    let classId: UUID
    let userId: UUID
    let rating: Int
    let comment: String?
    let date: Date
    let verified: Bool
}

struct Booking: Identifiable, Codable {
    let id: UUID
    let classId: UUID
    let userId: UUID
    let status: ClassStatus
    let bookingDate: Date
    let numberOfParticipants: Int
    let specialRequirements: String?
    var attended: Bool
    
    struct Calendar: Codable {
        let eventId: String?
        let reminderSet: Bool
    }
    
    var calendar: Calendar?
} 