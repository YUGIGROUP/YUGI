import SwiftUI
import PhotosUI

struct PersonalInformationScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiService = APIService.shared
    
    // User data from API service
    @State private var fullName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var profileImage: UIImage?
    
    // Edit mode state
    @State private var isEditing = false
    @State private var tempFullName = ""
    @State private var tempEmail = ""
    @State private var tempPhoneNumber = ""
    @State private var tempProfileImage: UIImage?
    
    // UI state
    @State private var showingImagePicker = false
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false
    @State private var successMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Personal Information")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Manage your account details")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    if !isEditing {
                        Button(action: startEditing) {
                            Text("Edit")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.8)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile Image Section
                        profileImageSection
                        
                        // Personal Details Section
                        personalDetailsSection
                        
                        // Account Information Section
                        accountInformationSection
                        
                        if isEditing {
                            // Save/Cancel Buttons
                            saveCancelButtons
                            
                            // Add some bottom spacing
                            Spacer(minLength: 40)
                        }
                    }
                    .padding(20)
                }
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showingSuccess) {
                Button("OK") {}
            } message: {
                Text(successMessage)
            }
            .photosPicker(isPresented: $showingImagePicker, selection: $selectedImageItem, matching: .images)
            .onChange(of: selectedImageItem) { oldValue, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            if isEditing {
                                tempProfileImage = image
                            } else {
                                profileImage = image
                            }
                        }
                    }
                }
            }
            .onAppear {
                loadUserData()
            }
            .onReceive(apiService.$currentUser) { user in
                if let user = user {
                    print("🔐 PersonalInformation: Current user updated: \(user.fullName)")
                    fullName = user.fullName
                    email = user.email
                    phoneNumber = user.phoneNumber ?? ""
                }
            }
        }
    }
    
    private var profileImageSection: some View {
        VStack(spacing: 16) {
            // Profile Image
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                if let image = isEditing ? tempProfileImage : profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    Text(String(fullName.prefix(1).uppercased()))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                }
                
                if isEditing {
                    // Edit overlay
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color(hex: "#BC6C5C"))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .frame(width: 120, height: 120)
                }
            }
            
            if isEditing {
                Button(action: {
                    showingImagePicker = true
                }) {
                    Text("Change Photo")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                }
            }
        }
    }
    
    private var personalDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Personal Details")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.yugiGray)
            
            VStack(spacing: 16) {
                // Full Name
                VStack(alignment: .leading, spacing: 8) {
                    Text("Full Name")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.yugiGray.opacity(0.8))
                    
                    if isEditing {
                        YUGITextField(
                            text: $tempFullName,
                            placeholder: "Enter your full name",
                            icon: "person.fill"
                        )
                    } else {
                        HStack {
                            Image(systemName: "person.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                                .frame(width: 24)
                            
                            Text(fullName.isEmpty ? "Not provided" : fullName)
                                .font(.system(size: 16))
                                .foregroundColor(fullName.isEmpty ? .yugiGray.opacity(0.6) : .yugiGray)
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                }
                
                // Email
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email Address")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.yugiGray.opacity(0.8))
                    
                    if isEditing {
                        YUGITextField(
                            text: $tempEmail,
                            placeholder: "Enter your email address",
                            icon: "envelope.fill",
                            keyboardType: .emailAddress
                        )
                    } else {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                                .frame(width: 24)
                            
                            Text(email.isEmpty ? "Not provided" : email)
                                .font(.system(size: 16))
                                .foregroundColor(email.isEmpty ? .yugiGray.opacity(0.6) : .yugiGray)
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                }
                
                // Phone Number
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone Number")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.yugiGray.opacity(0.8))
                    
                    if isEditing {
                        YUGITextField(
                            text: $tempPhoneNumber,
                            placeholder: "Enter your phone number",
                            icon: "phone.fill",
                            keyboardType: .phonePad
                        )
                    } else {
                        HStack {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                                .frame(width: 24)
                            
                            Text(phoneNumber.isEmpty ? "Not provided" : phoneNumber)
                                .font(.system(size: 16))
                                .foregroundColor(phoneNumber.isEmpty ? .yugiGray.opacity(0.6) : .yugiGray)
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                }
            }
        }
    }
    
    private var accountInformationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account Information")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.yugiGray)
            
            VStack(spacing: 12) {
                // Account Type
                HStack {
                    Image(systemName: "person.badge.key.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Account Type")
                            .font(.system(size: 14))
                            .foregroundColor(.yugiGray.opacity(0.7))
                        
                        Text(getUserTypeDisplay())
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                
                // Member Since
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Member Since")
                            .font(.system(size: 14))
                            .foregroundColor(.yugiGray.opacity(0.7))
                        
                        Text(formatMemberSinceDate())
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                

            }
        }
    }
    
    private var saveCancelButtons: some View {
        VStack(spacing: 16) {
            // Save Changes Button
            Button(action: saveChanges) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                    }
                    
                    Text("Save Changes")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .disabled(isLoading)
            
            // Cancel Button
            Button(action: cancelEditing) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                    
                    Text("Cancel")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.yugiGray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yugiGray.opacity(0.3), lineWidth: 1)
                )
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
            .disabled(isLoading)
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Helper Methods
    
    private func loadUserData() {
        // Ensure user is authenticated
        if !apiService.isAuthenticated {
            print("🔐 PersonalInformation: User not authenticated, forcing authentication for testing")
            // Use the current user type if available, otherwise default to parent
            let userType = apiService.currentUser?.userType ?? .parent
            apiService.forceAuthenticateForTesting(userType: userType)
        }
        
        // Fetch current user if not available
        if apiService.currentUser == nil {
            print("🔐 PersonalInformation: No current user, fetching...")
            apiService.fetchCurrentUser()
        }
        
        guard let user = apiService.currentUser else {
            print("🔐 PersonalInformation: Unable to load user data - no user available")
            showError("Unable to load user data. Please try again.")
            return
        }
        
        print("🔐 PersonalInformation: Loading user data for: \(user.fullName)")
        
        fullName = user.fullName
        email = user.email
        phoneNumber = user.phoneNumber ?? ""
        
        // Load profile image if available
        if let profileImageUrl = user.profileImage {
            // TODO: Load image from URL
            // For now, we'll use the placeholder
            print("🔐 PersonalInformation: Profile image URL available: \(profileImageUrl)")
        }
        
        print("🔐 PersonalInformation: User data loaded successfully")
        print("🔐 PersonalInformation: Full Name: \(fullName)")
        print("🔐 PersonalInformation: Email: \(email)")
        print("🔐 PersonalInformation: Phone: \(phoneNumber)")
    }
    
    private func startEditing() {
        tempFullName = fullName
        tempEmail = email
        tempPhoneNumber = phoneNumber
        tempProfileImage = profileImage
        isEditing = true
    }
    
    private func cancelEditing() {
        isEditing = false
        tempFullName = ""
        tempEmail = ""
        tempPhoneNumber = ""
        tempProfileImage = nil
    }
    
    private func saveChanges() {
        // Validation
        guard !tempFullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError("Please enter your full name")
            return
        }
        
        guard isValidEmail(tempEmail) else {
            showError("Please enter a valid email address")
            return
        }
        
        isLoading = true
        
        // Update user data
        apiService.updateProfile(
            fullName: tempFullName.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber: tempPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                isLoading = false
                if case let .failure(error) = completion {
                    showError("Failed to update profile: \(error.localizedDescription)")
                }
            },
            receiveValue: { response in
                // Update local state
                fullName = tempFullName.trimmingCharacters(in: .whitespacesAndNewlines)
                email = tempEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                phoneNumber = tempPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Update profile image if changed
                if tempProfileImage != nil {
                    profileImage = tempProfileImage
                }
                
                isEditing = false
                showSuccess("Profile updated successfully")
                
                // Refresh user data
                apiService.fetchCurrentUser()
            }
        )
        .store(in: &apiService.cancellables)
    }
    
    private func formatMemberSinceDate() -> String {
        guard let user = apiService.currentUser else { return "Unknown" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: user.createdAt)
    }
    
    private func getUserTypeDisplay() -> String {
        guard let user = apiService.currentUser else { return "Unknown" }
        
        switch user.userType {
        case .parent:
            return "Parent"
        case .provider:
            return "Provider"
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
    private func showSuccess(_ message: String) {
        successMessage = message
        showingSuccess = true
    }
}

#Preview {
    PersonalInformationScreen()
} 