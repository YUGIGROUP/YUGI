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
        case verificationStatus, children, isActive, isEmailVerified
        case createdAt, updatedAt, location
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
        case id
        case name, age, dateOfBirth
    }
} 