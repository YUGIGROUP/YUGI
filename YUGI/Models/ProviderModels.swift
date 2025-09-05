import Foundation

// MARK: - Provider Business Models

struct BusinessInfo: Codable {
    var name: String = ""
    var description: String = ""
}

struct ContactInfo: Codable {
    var email: String = ""
    var phone: String = ""
    var website: String = ""
    var address: String = ""
}

// MARK: - Provider Verification Status

enum ProviderVerificationStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case underReview = "under_review"
    case approved = "approved"
    case rejected = "rejected"
    
    var displayName: String {
        switch self {
        case .pending:
            return "Pending Verification"
        case .underReview:
            return "Under Review"
        case .approved:
            return "Verified"
        case .rejected:
            return "Rejected"
        }
    }
    
    var description: String {
        switch self {
        case .pending:
            return "Your application is being processed"
        case .underReview:
            return "We're reviewing your documents and information"
        case .approved:
            return "You're all set to start posting classes"
        case .rejected:
            return "Your application was not approved"
        }
    }
    
    var icon: String {
        switch self {
        case .pending:
            return "clock.fill"
        case .underReview:
            return "magnifyingglass"
        case .approved:
            return "checkmark.circle.fill"
        case .rejected:
            return "xmark.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .pending:
            return "orange"
        case .underReview:
            return "blue"
        case .approved:
            return "green"
        case .rejected:
            return "red"
        }
    }
}

struct ProviderAccount: Identifiable, Codable {
    let id: UUID
    let businessName: String
    let contactEmail: String
    let contactPhone: String
    let businessAddress: String
    let servicesDescription: String
    let bio: String
    let targetAgeGroups: [String]
    let verificationStatus: ProviderVerificationStatus
    let applicationDate: Date
    let verificationDate: Date?
    let rejectionReason: String?
    let profileImageURL: URL?
    let qualificationsURL: URL?
    let dbsCertificateURL: URL?
    let isActive: Bool
    let rating: Double
    let totalClasses: Int
    let totalBookings: Int
    
    init(
        id: UUID = UUID(),
        businessName: String,
        contactEmail: String,
        contactPhone: String,
        businessAddress: String,
        servicesDescription: String,
        bio: String,
        targetAgeGroups: [String],
        verificationStatus: ProviderVerificationStatus = .pending,
        applicationDate: Date = Date(),
        verificationDate: Date? = nil,
        rejectionReason: String? = nil,
        profileImageURL: URL? = nil,
        qualificationsURL: URL? = nil,
        dbsCertificateURL: URL? = nil,
        isActive: Bool = true,
        rating: Double = 0.0,
        totalClasses: Int = 0,
        totalBookings: Int = 0
    ) {
        self.id = id
        self.businessName = businessName
        self.contactEmail = contactEmail
        self.contactPhone = contactPhone
        self.businessAddress = businessAddress
        self.servicesDescription = servicesDescription
        self.bio = bio
        self.targetAgeGroups = targetAgeGroups
        self.verificationStatus = verificationStatus
        self.applicationDate = applicationDate
        self.verificationDate = verificationDate
        self.rejectionReason = rejectionReason
        self.profileImageURL = profileImageURL
        self.qualificationsURL = qualificationsURL
        self.dbsCertificateURL = dbsCertificateURL
        self.isActive = isActive
        self.rating = rating
        self.totalClasses = totalClasses
        self.totalBookings = totalBookings
    }
}

struct ProviderApplication: Codable {
    let businessName: String
    let contactEmail: String
    let contactPhone: String
    let businessAddress: String
    let servicesDescription: String
    let bio: String
    let targetAgeGroups: [String]
    let profileImageData: Data?
    let qualificationsImageData: Data?
    let dbsCertificateImageData: Data?
    let applicationDate: Date
    
    init(
        businessName: String,
        contactEmail: String,
        contactPhone: String,
        businessAddress: String,
        servicesDescription: String,
        bio: String,
        targetAgeGroups: [String],
        profileImageData: Data? = nil,
        qualificationsImageData: Data? = nil,
        dbsCertificateImageData: Data? = nil,
        applicationDate: Date = Date()
    ) {
        self.businessName = businessName
        self.contactEmail = contactEmail
        self.contactPhone = contactPhone
        self.businessAddress = businessAddress
        self.servicesDescription = servicesDescription
        self.bio = bio
        self.targetAgeGroups = targetAgeGroups
        self.profileImageData = profileImageData
        self.qualificationsImageData = qualificationsImageData
        self.dbsCertificateImageData = dbsCertificateImageData
        self.applicationDate = applicationDate
    }
}

// MARK: - Provider Dashboard Models

struct ProviderStats: Codable {
    let totalClasses: Int
    let activeClasses: Int
    let totalBookings: Int
    let pendingBookings: Int
    let completedBookings: Int
    let averageRating: Double
    let totalRevenue: Double
    let monthlyRevenue: Double
    
    init(
        totalClasses: Int = 0,
        activeClasses: Int = 0,
        totalBookings: Int = 0,
        pendingBookings: Int = 0,
        completedBookings: Int = 0,
        averageRating: Double = 0.0,
        totalRevenue: Double = 0.0,
        monthlyRevenue: Double = 0.0
    ) {
        self.totalClasses = totalClasses
        self.activeClasses = activeClasses
        self.totalBookings = totalBookings
        self.pendingBookings = pendingBookings
        self.completedBookings = completedBookings
        self.averageRating = averageRating
        self.totalRevenue = totalRevenue
        self.monthlyRevenue = monthlyRevenue
    }
} 