import Foundation
// import YUGI if needed

struct User: Identifiable, Codable {
    let id: String
    let email: String
    let fullName: String
    let userType: UserType
    let profileImage: String?
    let phoneNumber: String?
    let businessName: String?
    let businessAddress: String?
    let qualifications: String?
    let dbsCertificate: String?
    let bio: String?
    let services: String?
    let verificationStatus: String
    let children: [Child]?
    let isActive: Bool
    let isEmailVerified: Bool
    let createdAt: Date
    let updatedAt: Date
    let location: UserLocation?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email, fullName, userType, profileImage, phoneNumber
        case businessName, businessAddress, qualifications, dbsCertificate
        case bio, services
        case verificationStatus, children, isActive, isEmailVerified
        case createdAt, updatedAt, location
    }
    
    // Custom decoder to handle missing fields with default values
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Required fields
        self.id = try container.decode(String.self, forKey: .id)
        self.email = try container.decode(String.self, forKey: .email)
        self.fullName = try container.decode(String.self, forKey: .fullName)
        self.userType = try container.decode(UserType.self, forKey: .userType)
        
        // Optional fields
        self.profileImage = try container.decodeIfPresent(String.self, forKey: .profileImage)
        self.phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        self.businessName = try container.decodeIfPresent(String.self, forKey: .businessName)
        self.businessAddress = try container.decodeIfPresent(String.self, forKey: .businessAddress)
        self.qualifications = try container.decodeIfPresent(String.self, forKey: .qualifications)
        self.dbsCertificate = try container.decodeIfPresent(String.self, forKey: .dbsCertificate)
        self.bio = try container.decodeIfPresent(String.self, forKey: .bio)
        self.services = try container.decodeIfPresent(String.self, forKey: .services)
        self.location = try container.decodeIfPresent(UserLocation.self, forKey: .location)
        
        // Fields with default values if missing
        self.verificationStatus = try container.decodeIfPresent(String.self, forKey: .verificationStatus) ?? "pending"
        self.children = try container.decodeIfPresent([Child].self, forKey: .children) ?? []
        self.isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        self.isEmailVerified = try container.decodeIfPresent(Bool.self, forKey: .isEmailVerified) ?? false
        
        // Date fields with default values if missing
        if let createdAtString = try? container.decode(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            self.createdAt = formatter.date(from: createdAtString) ?? Date()
        } else {
            self.createdAt = Date()
        }
        
        if let updatedAtString = try? container.decode(String.self, forKey: .updatedAt) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            self.updatedAt = formatter.date(from: updatedAtString) ?? Date()
        } else {
            self.updatedAt = Date()
        }
    }
}

struct UserLocation: Codable {
    let lat: Double
    let lng: Double
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case lat, lng, updatedAt
    }
}

struct Child: Identifiable, Codable {
    let id: String?
    let name: String
    let age: Int
    let dateOfBirth: Date?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name, age, dateOfBirth
    }
    
    // Regular initializer for creating Child objects
    init(childId: String?, childName: String, childAge: Int, childDateOfBirth: Date?) {
        self.id = childId
        self.name = childName
        self.age = childAge
        self.dateOfBirth = childDateOfBirth
    }
    
    // Custom decoder to handle _id -> id mapping
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.age = try container.decode(Int.self, forKey: .age)
        self.dateOfBirth = try container.decodeIfPresent(Date.self, forKey: .dateOfBirth)
    }
} 