import Foundation

// MARK: - Document type & status

enum DocumentType: String, CaseIterable, Codable {
    case insurance = "insurance"
    case dbs = "dbs"
    case qualifications = "qualifications"

    var displayName: String {
        switch self {
        case .insurance:
            return "Public Liability Insurance"
        case .dbs:
            return "DBS Certificate"
        case .qualifications:
            return "Qualifications"
        }
    }

    func isRequired(forTier tier: String) -> Bool {
        switch tier {
        case "class":
            return self == .insurance
        case "drop_off":
            return true
        default:
            return false
        }
    }

    func isOptional(forTier tier: String) -> Bool {
        switch tier {
        case "class":
            return self == .dbs || self == .qualifications
        default:
            return false
        }
    }

    func isApplicable(forTier tier: String) -> Bool {
        isRequired(forTier: tier) || isOptional(forTier: tier)
    }
}

enum DocumentStatus: String, CaseIterable, Codable {
    case pending
    case approved
    case rejected
    case expired

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .expired: return "Expired"
        }
    }
}

// MARK: - Provider document model

struct ProviderDocument: Identifiable, Codable {
    let id: String
    let userId: String
    let documentType: String
    let s3Key: String
    let originalFileName: String
    let mimeType: String
    let sizeBytes: Int
    let status: String
    let uploadedAt: Date
    let reviewedAt: Date?
    let reviewedBy: String?
    let rejectionReason: String?
    let expiryDate: Date?

    var typedDocumentType: DocumentType? {
        DocumentType(rawValue: documentType)
    }

    var typedStatus: DocumentStatus? {
        DocumentStatus(rawValue: status)
    }

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId
        case documentType
        case s3Key
        case originalFileName
        case mimeType
        case sizeBytes
        case status
        case uploadedAt
        case reviewedAt
        case reviewedBy
        case rejectionReason
        case expiryDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        documentType = try container.decode(String.self, forKey: .documentType)
        s3Key = try container.decodeIfPresent(String.self, forKey: .s3Key) ?? ""
        originalFileName = try container.decode(String.self, forKey: .originalFileName)
        mimeType = try container.decode(String.self, forKey: .mimeType)
        sizeBytes = try container.decode(Int.self, forKey: .sizeBytes)
        status = try container.decode(String.self, forKey: .status)
        uploadedAt = try container.decode(Date.self, forKey: .uploadedAt)
        reviewedAt = try container.decodeIfPresent(Date.self, forKey: .reviewedAt)
        reviewedBy = try container.decodeIfPresent(String.self, forKey: .reviewedBy)
        rejectionReason = try container.decodeIfPresent(String.self, forKey: .rejectionReason)
        expiryDate = try container.decodeIfPresent(Date.self, forKey: .expiryDate)
    }
}

struct ProviderDocumentUploadResponse: Codable {
    let success: Bool
    let document: ProviderDocument
}

struct ProviderDocumentsListResponse: Codable {
    let success: Bool
    let documents: [ProviderDocument]
}

struct ProviderDocumentDeleteResponse: Codable {
    let success: Bool
}
