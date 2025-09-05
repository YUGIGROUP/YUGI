import Foundation

struct ClassSearchModel: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let location: Location
    let ageRange: AgeRange
    let price: Price
    let instructor: Instructor
    let schedule: Schedule
    
    struct Location: Codable {
        let address: String
        let postcode: String
        let town: String
        let coordinates: Coordinates
        
        struct Coordinates: Codable {
            let latitude: Double
            let longitude: Double
        }
    }
    
    struct AgeRange: Codable {
        let minAge: Int
        let maxAge: Int
        
        var displayString: String {
            if maxAge == Int.max {
                return "\(minAge)+ years"
            }
            return "\(minAge)-\(maxAge) years"
        }
    }
    
    struct Price: Codable {
        let amount: Double
        let currency: String
        let type: PriceType
        
        enum PriceType: String, Codable {
            case perClass = "per class"
            case perMonth = "per month"
            case perTerm = "per term"
        }
        
        var displayString: String {
            return String(format: "%.2f \(currency) \(type.rawValue)", amount)
        }
    }
    
    struct Instructor: Codable {
        let id: UUID
        let name: String
        let bio: String
        let qualifications: [String]
    }
    
    struct Schedule: Codable {
        let dayOfWeek: String
        let startTime: String
        let duration: Int // in minutes
        let availability: Int
        
        var displayString: String {
            return "\(dayOfWeek) at \(startTime) (\(duration) mins)"
        }
    }
}

// Sample data for preview and testing
extension ClassSearchModel {
    static var sampleData: [ClassSearchModel] {
        [
            ClassSearchModel(
                id: UUID(),
                name: "Baby Sensory Play",
                description: "Interactive sensory play sessions designed for babies to explore and develop through play.",
                location: Location(
                    address: "123 Play Street",
                    postcode: "SW1A 1AA",
                    town: "London",
                    coordinates: Location.Coordinates(latitude: 51.5074, longitude: -0.1278)
                ),
                ageRange: AgeRange(minAge: 0, maxAge: 1),
                price: Price(
                    amount: 15.0,
                    currency: "£",
                    type: .perClass
                ),
                instructor: Instructor(
                    id: UUID(),
                    name: "Sarah Johnson",
                    bio: "Early years specialist with 10 years experience",
                    qualifications: ["Early Years Education", "Baby Sensory Certified"]
                ),
                schedule: Schedule(
                    dayOfWeek: "Monday",
                    startTime: "10:00",
                    duration: 45,
                    availability: 8
                )
            ),
            ClassSearchModel(
                id: UUID(),
                name: "Toddler Music & Movement",
                description: "Fun and engaging music sessions for toddlers to develop rhythm and coordination.",
                location: Location(
                    address: "456 Music Lane",
                    postcode: "SW1A 2BB",
                    town: "London",
                    coordinates: Location.Coordinates(latitude: 51.5074, longitude: -0.1278)
                ),
                ageRange: AgeRange(minAge: 1, maxAge: 3),
                price: Price(
                    amount: 12.0,
                    currency: "£",
                    type: .perClass
                ),
                instructor: Instructor(
                    id: UUID(),
                    name: "Mike Thompson",
                    bio: "Music teacher specializing in early years education",
                    qualifications: ["Music Education", "Early Years Development"]
                ),
                schedule: Schedule(
                    dayOfWeek: "Tuesday",
                    startTime: "11:00",
                    duration: 45,
                    availability: 10
                )
            )
        ]
    }
} 