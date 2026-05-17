import Foundation

// MARK: - Provider summary (populated from userId on admin document endpoints)

struct AdminProviderSummary: Codable, Equatable {
    let id: String?
    let fullName: String?
    let email: String?
    let businessName: String?
    let businessAddress: String?
    let verificationStatus: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case fullName, email, businessName, businessAddress, verificationStatus
    }

    var displayName: String {
        if let businessName, !businessName.isEmpty { return businessName }
        if let fullName, !fullName.isEmpty { return fullName }
        return "Unknown provider"
    }

    var subtitle: String? {
        if let businessName, !businessName.isEmpty,
           let fullName, !fullName.isEmpty,
           businessName != fullName {
            return fullName
        }
        return email
    }
}

// MARK: - Pending document (admin queue item)

struct AdminPendingDocument: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let provider: AdminProviderSummary
    let documentType: String
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

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case userId
        case documentType
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
        documentType = try container.decode(String.self, forKey: .documentType)
        originalFileName = try container.decode(String.self, forKey: .originalFileName)
        mimeType = try container.decode(String.self, forKey: .mimeType)
        sizeBytes = try container.decode(Int.self, forKey: .sizeBytes)
        status = try container.decode(String.self, forKey: .status)
        uploadedAt = try container.decode(Date.self, forKey: .uploadedAt)
        reviewedAt = try container.decodeIfPresent(Date.self, forKey: .reviewedAt)
        reviewedBy = try container.decodeIfPresent(String.self, forKey: .reviewedBy)
        rejectionReason = try container.decodeIfPresent(String.self, forKey: .rejectionReason)
        expiryDate = try container.decodeIfPresent(Date.self, forKey: .expiryDate)

        if let populated = try? container.decode(AdminProviderSummary.self, forKey: .userId) {
            provider = populated
            userId = populated.id ?? ""
        } else {
            let uid = try container.decode(String.self, forKey: .userId)
            userId = uid
            provider = AdminProviderSummary(
                id: uid,
                fullName: nil,
                email: nil,
                businessName: nil,
                businessAddress: nil,
                verificationStatus: nil
            )
        }
    }
}

// MARK: - Detail (signed URL for QuickLook)

struct AdminDocumentDetail: Codable {
    let document: AdminPendingDocument
    let viewUrl: String
}

struct AdminDocumentsPendingResponse: Codable {
    let success: Bool
    let documents: [AdminPendingDocument]
}

struct AdminDocumentDetailResponse: Codable {
    let success: Bool
    let document: AdminPendingDocument
    let viewUrl: String
}

struct AdminDocumentActionResponse: Codable {
    let success: Bool
    let document: ProviderDocument
}
