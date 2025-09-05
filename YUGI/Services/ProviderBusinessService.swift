import Foundation
import Combine
import UIKit

// MARK: - Response Models
struct ProviderProfileResponse: Codable {
    let data: ProviderProfileData
}

struct ProviderProfileData: Codable {
    let businessName: String?
    let businessAddress: String?
    let phoneNumber: String?
    let email: String?
    let servicesDescription: String?
}

class ProviderBusinessService: ObservableObject {
    static let shared = ProviderBusinessService()
    
    @Published var businessInfo: BusinessInfo
    @Published var contactInfo: ContactInfo
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var dbsCertificateImage: UIImage?
    @Published var qualificationsImage: UIImage?
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    
    private init() {
        // Initialize with default values
        self.businessInfo = BusinessInfo()
        self.contactInfo = ContactInfo()
        
        // Load saved data
        loadBusinessData()
    }
    
    // MARK: - Data Management
    
    func loadBusinessData() {
        // Load from UserDefaults or other storage
        if let savedBusinessName = UserDefaults.standard.string(forKey: "providerBusinessName") {
            businessInfo.name = savedBusinessName
        }
        
        if let savedDescription = UserDefaults.standard.string(forKey: "providerBusinessDescription") {
            businessInfo.description = savedDescription
        }
        
        if let savedEmail = UserDefaults.standard.string(forKey: "providerContactEmail") {
            contactInfo.email = savedEmail
        }
        
        if let savedPhone = UserDefaults.standard.string(forKey: "providerContactPhone") {
            contactInfo.phone = savedPhone
        }
        
        if let savedWebsite = UserDefaults.standard.string(forKey: "providerWebsite") {
            contactInfo.website = savedWebsite
        }
        
        if let savedAddress = UserDefaults.standard.string(forKey: "providerBusinessAddress") {
            contactInfo.address = savedAddress
        }
        
        // Load DBS certificate image
        if let dbsData = UserDefaults.standard.data(forKey: "providerDBSCertificate"),
           let dbsImage = UIImage(data: dbsData) {
            dbsCertificateImage = dbsImage
        } else {
            dbsCertificateImage = nil
        }
        // Load qualifications image
        if let qualData = UserDefaults.standard.data(forKey: "providerQualifications"),
           let qualImage = UIImage(data: qualData) {
            qualificationsImage = qualImage
        } else {
            qualificationsImage = nil
        }
    }
    
    func saveBusinessData() {
        UserDefaults.standard.set(businessInfo.name, forKey: "providerBusinessName")
        UserDefaults.standard.set(businessInfo.description, forKey: "providerBusinessDescription")
        UserDefaults.standard.set(contactInfo.email, forKey: "providerContactEmail")
        UserDefaults.standard.set(contactInfo.phone, forKey: "providerContactPhone")
        UserDefaults.standard.set(contactInfo.website, forKey: "providerWebsite")
        UserDefaults.standard.set(contactInfo.address, forKey: "providerBusinessAddress")
    }
    
    // MARK: - Sign-up Integration
    
    func updateFromSignUp(
        businessName: String,
        businessAddress: String,
        contactEmail: String,
        contactPhone: String,
        bio: String
    ) {
        businessInfo.name = businessName
        businessInfo.description = bio
        contactInfo.email = contactEmail
        contactInfo.phone = contactPhone
        contactInfo.address = businessAddress
        
        // Save to persistent storage only
        saveBusinessData()
    }
    
    // MARK: - API Integration
    
    func updateBusinessInfoOnServer() {
        guard apiService.isAuthenticated else { return }
        
        isLoading = true
        errorMessage = nil
        
        apiService.updateBusinessInfo(
            businessName: businessInfo.name.isEmpty ? nil : businessInfo.name,
            businessAddress: contactInfo.address.isEmpty ? nil : contactInfo.address,
            phoneNumber: contactInfo.phone.isEmpty ? nil : contactInfo.phone
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            },
            receiveValue: { [weak self] response in
                // Update local data with server response
                self?.updateFromUserData(response.data)
                self?.saveBusinessData()
            }
        )
        .store(in: &cancellables)
    }
    
    func fetchBusinessInfoFromServer() {
        guard apiService.isAuthenticated else { return }
        
        isLoading = true
        errorMessage = nil
        
        // For now, we'll use the current user data since there's no specific provider profile endpoint
        if let currentUser = apiService.currentUser {
            updateFromUserData(currentUser)
            saveBusinessData()
            isLoading = false
        } else {
            // If no current user, try to fetch it
            apiService.fetchCurrentUser()
            
            // Since fetchCurrentUser doesn't return a publisher, we'll check again after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                if let currentUser = self?.apiService.currentUser {
                    self?.updateFromUserData(currentUser)
                    self?.saveBusinessData()
                }
                self?.isLoading = false
            }
        }
    }
    
    private func updateFromUserData(_ user: User) {
        if let businessName = user.businessName {
            businessInfo.name = businessName
        }
        
        if let businessAddress = user.businessAddress {
            contactInfo.address = businessAddress
        }
        
        if let phoneNumber = user.phoneNumber {
            contactInfo.phone = phoneNumber
        }
        
        contactInfo.email = user.email
        
        // Note: servicesDescription is not part of the User model,
        // so we keep the local description
    }
    
    // MARK: - Validation
    
    func validateBusinessInfo() -> [String] {
        var errors: [String] = []
        
        if businessInfo.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Business name is required")
        }
        
        if businessInfo.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Business description is required")
        }
        
        if contactInfo.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Email address is required")
        } else if !isValidEmail(contactInfo.email) {
            errors.append("Please enter a valid email address")
        }
        
        if contactInfo.phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Phone number is required")
        }
        
        if contactInfo.address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Business address is required")
        }
        
        return errors
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    // MARK: - Reset
    
    func reset() {
        businessInfo = BusinessInfo()
        contactInfo = ContactInfo()
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "providerBusinessName")
        UserDefaults.standard.removeObject(forKey: "providerBusinessDescription")
        UserDefaults.standard.removeObject(forKey: "providerContactEmail")
        UserDefaults.standard.removeObject(forKey: "providerContactPhone")
        UserDefaults.standard.removeObject(forKey: "providerWebsite")
        UserDefaults.standard.removeObject(forKey: "providerBusinessAddress")
    }
} 