import Foundation
import SwiftUI

// MARK: - Enums

enum ClassStatus: String, Codable {
    case draft
    case pending
    case upcoming
    case inProgress
    case completed
    case cancelled
    
    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .pending: return "Pending"
        case .upcoming: return "Upcoming"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .draft: return .gray
        case .pending: return .yellow
        case .upcoming: return .yugiGray
        case .inProgress: return .orange
        case .completed: return .yugiGray
        case .cancelled: return .red
        }
    }
}

// MARK: - Models

struct Class: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let category: ClassCategory
    let provider: String  // Provider ID as String
    let providerName: String?  // Provider name for display
    let location: Location?  // Optional location field
    let schedule: Schedule
    let pricing: Pricing
    let maxCapacity: Int
    let currentEnrollment: Int
    var averageRating: Double
    let ageRange: String
    var isFavorite: Bool
    let isActive: Bool?  // Whether the class is active (not cancelled)
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, category, provider, providerName, location
        case schedule, pricing, maxCapacity, currentEnrollment
        case averageRating, ageRange, isFavorite, isActive
    }
    
    var isAvailable: Bool {
        currentEnrollment < maxCapacity
    }
    

}

struct Provider: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let qualifications: [String]
    let contactEmail: String
    let contactPhone: String
    let website: String?
    var rating: Double
}

struct Location: Identifiable, Codable {
    let id: String
    let name: String
    let address: Address
    let coordinates: Coordinates
    let accessibilityNotes: String?
    let parkingInfo: String?
    let babyChangingFacilities: String?
    
    struct Coordinates: Codable {
        let latitude: Double
        let longitude: Double
    }
}

struct Address: Codable {
    let street: String
    let city: String
    let state: String
    let postalCode: String
    let country: String
    
    var formatted: String {
        var components: [String] = []
        
        // Trim whitespace from all fields
        let trimmedStreet = street.trimmingCharacters(in: .whitespaces)
        let trimmedCity = city.trimmingCharacters(in: .whitespaces)
        let trimmedState = state.trimmingCharacters(in: .whitespaces)
        let trimmedPostalCode = postalCode.trimmingCharacters(in: .whitespaces)
        let trimmedCountry = country.trimmingCharacters(in: .whitespaces)
        
        // Add non-empty components
        if !trimmedStreet.isEmpty {
            components.append(trimmedStreet)
        }
        if !trimmedCity.isEmpty {
            components.append(trimmedCity)
        }
        if !trimmedState.isEmpty {
            components.append(trimmedState)
        }
        if !trimmedPostalCode.isEmpty {
            components.append(trimmedPostalCode)
        }
        if !trimmedCountry.isEmpty {
            components.append(trimmedCountry)
        }
        
        // Join with commas and spaces
        return components.joined(separator: ", ")
    }
}

struct Schedule: Codable {
    let startDate: Date
    let endDate: Date
    let recurringDays: [String]
    let timeSlots: [TimeSlot]
    let totalSessions: Int
    
    struct TimeSlot: Codable {
        let startTime: Date
        let duration: TimeInterval
        
        var endTime: Date {
            startTime.addingTimeInterval(duration)
        }
    }
    
    // Helper computed property to get WeekDay objects for UI compatibility
    var weekDays: Set<WeekDay> {
        return Set(recurringDays.compactMap { dayString in
            switch dayString.lowercased() {
            case "sunday": return .sunday
            case "monday": return .monday
            case "tuesday": return .tuesday
            case "wednesday": return .wednesday
            case "thursday": return .thursday
            case "friday": return .friday
            case "saturday": return .saturday
            default: return nil
            }
        })
    }
    
    // Helper computed property to get formatted day names
    var formattedDays: String {
        return recurringDays.map { dayString in
            switch dayString.lowercased() {
            case "sunday": return "Sun"
            case "monday": return "Mon"
            case "tuesday": return "Tue"
            case "wednesday": return "Wed"
            case "thursday": return "Thu"
            case "friday": return "Fri"
            case "saturday": return "Sat"
            default: return dayString.capitalized
            }
        }.joined(separator: ", ")
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
    let classId: String
    let userId: UUID
    let rating: Int
    let comment: String?
    let date: Date
    let verified: Bool
}

struct Booking: Identifiable, Codable {
    let id: UUID
    let classId: String
    let userId: UUID
    var status: ClassStatus
    let bookingDate: Date
    let numberOfParticipants: Int
    let selectedChildren: [Child]?
    let specialRequirements: String?
    var attended: Bool
    
    // Store original MongoDB ObjectId for API calls
    var mongoObjectId: String?
    
    struct Calendar: Codable {
        let eventId: String?
        let reminderSet: Bool
    }
    
    var calendar: Calendar?
    
    // Regular initializer for creating Booking instances in code
    init(
        id: UUID,
        classId: String,
        userId: UUID,
        status: ClassStatus,
        bookingDate: Date,
        numberOfParticipants: Int,
        selectedChildren: [Child]? = nil,
        specialRequirements: String? = nil,
        attended: Bool = false,
        calendar: Calendar? = nil,
        mongoObjectId: String? = nil
    ) {
        self.id = id
        self.classId = classId
        self.userId = userId
        self.status = status
        self.bookingDate = bookingDate
        self.numberOfParticipants = numberOfParticipants
        self.selectedChildren = selectedChildren
        self.specialRequirements = specialRequirements
        self.attended = attended
        self.calendar = calendar
        self.mongoObjectId = mongoObjectId
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case classId
        case userId = "parent"
        case status
        case bookingDate = "sessionDate"
        case numberOfParticipants
        case selectedChildren = "children"
        case specialRequirements
        case attended
        case calendar
        case mongoObjectId
    }
    
    enum DecodingKeys: String, CodingKey {
        case id = "_id"
        case classId
        case classNested = "class"
        case userId = "parent"
        case status
        case bookingDate = "sessionDate"
        case numberOfParticipants
        case selectedChildren = "children"
        case specialRequirements
        case attended
        case calendar
    }
    
    private enum ClassIdKey: String, CodingKey {
        case id = "_id"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DecodingKeys.self)
        
        // Handle _id as String (MongoDB ObjectId) and convert to UUID
        let idString = try container.decode(String.self, forKey: .id)
        // Store original MongoDB ObjectId for API calls
        self.mongoObjectId = idString
        // MongoDB ObjectIds are 24 hex characters, not UUIDs
        // Create a deterministic UUID from the ObjectId
        let paddedId = idString.padding(toLength: 32, withPad: "0", startingAt: 0)
        let uuidString = String(paddedId.prefix(8)) + "-" + 
                        String(paddedId.dropFirst(8).prefix(4)) + "-" +
                        String(paddedId.dropFirst(12).prefix(4)) + "-" +
                        String(paddedId.dropFirst(16).prefix(4)) + "-" +
                        String(paddedId.dropFirst(20).prefix(12))
        self.id = UUID(uuidString: uuidString) ?? UUID()
        
        // Get classId from nested class object or direct classId field
        if container.contains(.classNested) {
            let classContainer = try container.nestedContainer(keyedBy: ClassIdKey.self, forKey: .classNested)
            self.classId = try classContainer.decode(String.self, forKey: .id)
        } else {
            self.classId = try container.decode(String.self, forKey: .classId)
        }
        
        // Handle userId (parent) - MongoDB ObjectId as String
        let userIdString = try container.decode(String.self, forKey: .userId)
        let paddedUserId = userIdString.padding(toLength: 32, withPad: "0", startingAt: 0)
        let userIdUuidString = String(paddedUserId.prefix(8)) + "-" + 
                               String(paddedUserId.dropFirst(8).prefix(4)) + "-" +
                               String(paddedUserId.dropFirst(12).prefix(4)) + "-" +
                               String(paddedUserId.dropFirst(16).prefix(4)) + "-" +
                               String(paddedUserId.dropFirst(20).prefix(12))
        self.userId = UUID(uuidString: userIdUuidString) ?? UUID()
        
        // Decode status - backend returns "pending", "confirmed", etc.
        let statusString = try container.decode(String.self, forKey: .status)
        // Map backend statuses to iOS enum values
        switch statusString.lowercased() {
        case "pending":
            self.status = .pending
        case "confirmed":
            self.status = .upcoming  // Map "confirmed" to "upcoming"
        case "cancelled":
            self.status = .cancelled
        case "completed":
            self.status = .completed
        default:
            self.status = .pending
        }
        
        // Decode bookingDate (sessionDate)
        self.bookingDate = try container.decode(Date.self, forKey: .bookingDate)
        
        // Get numberOfParticipants from children count
        let children = try container.decodeIfPresent([Child].self, forKey: .selectedChildren) ?? []
        self.numberOfParticipants = children.count
        
        self.selectedChildren = children.isEmpty ? nil : children
        self.specialRequirements = try container.decodeIfPresent(String.self, forKey: .specialRequirements)
        self.attended = try container.decodeIfPresent(Bool.self, forKey: .attended) ?? false
        self.calendar = try container.decodeIfPresent(Calendar.self, forKey: .calendar)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Use mongoObjectId if available, otherwise convert UUID to string
        if let mongoId = mongoObjectId {
            try container.encode(mongoId, forKey: .id)
        } else {
            // Convert UUID back to string format (we'll use a simple string representation)
            try container.encode(id.uuidString, forKey: .id)
        }
        try container.encode(classId, forKey: .classId)
        try container.encode(userId.uuidString, forKey: .userId)
        
        // Map status back to backend format
        let statusString: String
        switch status {
        case .pending:
            statusString = "pending"
        case .upcoming:
            statusString = "confirmed"  // Map "upcoming" back to "confirmed"
        case .cancelled:
            statusString = "cancelled"
        case .completed:
            statusString = "completed"
        default:
            statusString = "pending"
        }
        try container.encode(statusString, forKey: .status)
        
        try container.encode(bookingDate, forKey: .bookingDate)
        try container.encode(numberOfParticipants, forKey: .numberOfParticipants)
        try container.encodeIfPresent(selectedChildren, forKey: .selectedChildren)
        try container.encodeIfPresent(specialRequirements, forKey: .specialRequirements)
        try container.encode(attended, forKey: .attended)
        try container.encodeIfPresent(calendar, forKey: .calendar)
        // Don't encode mongoObjectId - it's only for internal use
    }
}

// Enhanced booking for UI display with class information
struct EnhancedBooking: Identifiable, Codable, Hashable {
    let booking: Booking
    let classInfo: Class
    
    var id: UUID { booking.id }
    var classId: String { booking.classId }
    var userId: UUID { booking.userId }
    var status: ClassStatus { booking.status }
    var bookingDate: Date { booking.bookingDate }
    var numberOfParticipants: Int { booking.numberOfParticipants }
    var selectedChildren: [Child]? { booking.selectedChildren }
    var specialRequirements: String? { booking.specialRequirements }
    var attended: Bool { booking.attended }
    
    // Class information
    var className: String { classInfo.name }
    var providerName: String { 
        // TODO: Implement provider name lookup by ID
        // For now, return a placeholder or the provider ID
        "Provider \(classInfo.provider)"
    }
    var price: Decimal { classInfo.pricing.amount }
    var currency: String { classInfo.pricing.currency }
    
    // MARK: - Hashable Conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(booking.id)
        hasher.combine(classInfo.id)
    }
    
    static func == (lhs: EnhancedBooking, rhs: EnhancedBooking) -> Bool {
        return lhs.booking.id == rhs.booking.id && lhs.classInfo.id == rhs.classInfo.id
    }
} 