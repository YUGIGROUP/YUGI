import SwiftUI
import Combine
import UIKit

// MARK: - Provider Profile Popup

struct ProviderProfilePopup: View {
    let providerId: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiService = APIService.shared
    @State private var providerInfo: ProviderInfo?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        ZStack {
            // Full background
            Color(hex: "#BC6C5C")
                .ignoresSafeArea()
            
            VStack {
                // Header with Done button
                HStack {
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text("Loading provider information...")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.system(size: 16))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        Text("Error loading provider information")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header with Profile Picture
                            VStack(spacing: 16) {
                                // Profile Picture
                                if let profileImage = providerInfo?.profileImage, !profileImage.isEmpty {
                                    // Check if it's a base64 data URL, raw base64, or regular URL
                                    if profileImage.hasPrefix("data:image/") {
                                        // Handle base64 data URL
                                        if let data = Data(base64Encoded: String(profileImage.dropFirst(profileImage.firstIndex(of: ",")?.utf16Offset(in: profileImage) ?? 0 + 1))) {
                                            if let uiImage = UIImage(data: data) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(Circle())
                                            } else {
                                                Circle()
                                                    .fill(Color.white.opacity(0.2))
                                                    .frame(width: 80, height: 80)
                                                    .overlay(
                                                        Text(providerDisplayName.prefix(1).uppercased())
                                                            .font(.system(size: 32, weight: .bold))
                                                            .foregroundColor(.white)
                                                    )
                                            }
                                        } else {
                                            Circle()
                                                .fill(Color.white.opacity(0.2))
                                                .frame(width: 80, height: 80)
                                                .overlay(
                                                    Text(providerDisplayName.prefix(1).uppercased())
                                                        .font(.system(size: 32, weight: .bold))
                                                        .foregroundColor(.white)
                                                )
                                        }
                                    } else if profileImage.hasPrefix("/9j/") || profileImage.hasPrefix("iVBORw0KGgo") {
                                        // Handle raw base64 image data (JPEG or PNG)
                                        if let data = Data(base64Encoded: profileImage) {
                                            if let uiImage = UIImage(data: data) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 80, height: 80)
                                                    .clipShape(Circle())
                                            } else {
                                                Circle()
                                                    .fill(Color.white.opacity(0.2))
                                                    .frame(width: 80, height: 80)
                                                    .overlay(
                                                        Text(providerDisplayName.prefix(1).uppercased())
                                                            .font(.system(size: 32, weight: .bold))
                                                            .foregroundColor(.white)
                                                    )
                                            }
                                        } else {
                                            Circle()
                                                .fill(Color.white.opacity(0.2))
                                                .frame(width: 80, height: 80)
                                                .overlay(
                                                    Text(providerDisplayName.prefix(1).uppercased())
                                                        .font(.system(size: 32, weight: .bold))
                                                        .foregroundColor(.white)
                                                )
                                        }
                                    } else {
                                        // Handle regular URL
                                        AsyncImage(url: URL(string: profileImage)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Circle()
                                                .fill(Color.white.opacity(0.2))
                                                .frame(width: 80, height: 80)
                                                .overlay(
                                                    Text(providerDisplayName.prefix(1).uppercased())
                                                        .font(.system(size: 32, weight: .bold))
                                                        .foregroundColor(.white)
                                                )
                                        }
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                    }
                                } else {
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 80, height: 80)
                                        .overlay(
                                            Text(providerDisplayName.prefix(1).uppercased())
                                                .font(.system(size: 32, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                }
                                
                                Text(providerDisplayName)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 20)
                        
                            // About Section (Bio + Services combined)
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "person.text.rectangle")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                    
                                    Text("About")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                
                                Text(providerAboutText)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(nil)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(hex: "#BC6C5C"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                            )
                            .padding(.horizontal, 20)
                            
                            // Contact Information
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "envelope.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                    
                                    Text("Contact")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    if let email = providerInfo?.email, !email.isEmpty {
                                        HStack {
                                            Image(systemName: "envelope")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.8))
                                            Text(email)
                                                .font(.system(size: 14))
                                                .foregroundColor(.white.opacity(0.9))
                                        }
                                    }
                                    
                                    if let phone = providerInfo?.phoneNumber, !phone.isEmpty {
                                        HStack {
                                            Image(systemName: "phone")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.8))
                                            Text(phone)
                                                .font(.system(size: 14))
                                                .foregroundColor(.white.opacity(0.9))
                                        }
                                    }
                                    
                                    if let address = providerInfo?.businessAddress, !address.isEmpty {
                                        HStack {
                                            Image(systemName: "location")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.8))
                                            Text(address)
                                                .font(.system(size: 14))
                                                .foregroundColor(.white.opacity(0.9))
                                        }
                                    }
                                    
                                    if providerContactText.isEmpty {
                                        Text("Contact information not available")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                }
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(hex: "#BC6C5C"))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                            )
                            .padding(.horizontal, 20)
                            
                            Spacer(minLength: 40)
                        }
                    }
                }
            }
        }
        .onAppear {
            fetchProviderInfo()
        }
    }
    
    // MARK: - Computed Properties
    
    private var providerDisplayName: String {
        if let businessName = providerInfo?.businessName, !businessName.isEmpty {
            return businessName
        } else if let fullName = providerInfo?.fullName, !fullName.isEmpty {
            return fullName
        } else {
            return "Provider"
        }
    }
    
    private var providerAboutText: String {
        var aboutSections: [String] = []
        
        // Add bio if available
        if let bio = providerInfo?.bio, !bio.isEmpty {
            aboutSections.append(bio)
        }
        
        // Add services if available
        if let services = providerInfo?.services, !services.isEmpty {
            aboutSections.append("Services: \(services)")
        }
        
        // If we have bio or services, return them
        if !aboutSections.isEmpty {
            return aboutSections.joined(separator: "\n\n")
        }
        
        // Fallback to business name or default message
        if let businessName = providerInfo?.businessName, !businessName.isEmpty {
            return "Welcome to \(businessName)! We are a trusted provider of children's classes and activities."
        } else {
            return "Provider information will be available soon."
        }
    }
    
    
    private var providerContactText: String {
        var contactInfo: [String] = []
        
        if let email = providerInfo?.email, !email.isEmpty {
            contactInfo.append("Email: \(email)")
        }
        if let phone = providerInfo?.phoneNumber, !phone.isEmpty {
            contactInfo.append("Phone: \(phone)")
        }
        if let address = providerInfo?.businessAddress, !address.isEmpty {
            contactInfo.append("Address: \(address)")
        }
        
        return contactInfo.joined(separator: "\n")
    }
    
    // MARK: - Methods
    
    private func fetchProviderInfo() {
        isLoading = true
        errorMessage = nil
        
        print("🔍 ProviderProfilePopup - Fetching provider info for ID: \(providerId)")
        
        apiService.fetchProviderInfo(providerId: providerId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { response in
                    providerInfo = response.data
                    print("🔍 ProviderProfilePopup - Received providerInfo:")
                    print("  - bio: \(response.data.bio ?? "nil")")
                    print("  - services: \(response.data.services ?? "nil")")
                    print("  - email: \(response.data.email)")
                    print("  - businessName: \(response.data.businessName ?? "nil")")
                }
            )
            .store(in: &cancellables)
    }
}

#Preview {
    ProviderProfilePopup(providerId: "mock-provider-id-1")
}