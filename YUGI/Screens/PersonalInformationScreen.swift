import SwiftUI
import PhotosUI

struct PersonalInformationScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiService = APIService.shared

    // User data from API service
    @State private var fullName     = ""
    @State private var email        = ""
    @State private var phoneNumber  = ""
    @State private var profileImage: UIImage?

    // Edit mode state
    @State private var isEditing        = false
    @State private var tempFullName     = ""
    @State private var tempEmail        = ""
    @State private var tempPhoneNumber  = ""
    @State private var tempProfileImage: UIImage?

    // UI state
    @State private var showingImagePicker    = false
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var showingError          = false
    @State private var errorMessage          = ""
    @State private var showingSuccess        = false
    @State private var successMessage        = ""
    @State private var isLoading             = false
    @State private var trackingEnabled       = ConsentManager.shared.hasConsented()

    // Animation
    @State private var showHeader      = false
    @State private var showIdentity    = false
    @State private var showDetails     = false
    @State private var showPreferences = false

    var body: some View {
        ZStack {
            Color.yugiCloud.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Nav header
                HStack(spacing: 6) {
                    Button(action: { dismiss() }) {
                        Text("‹")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                    }
                    Text("Personal information")
                        .font(.custom("Raleway-Medium", size: 18))
                        .foregroundColor(.white)
                    Spacer()
                    if !isEditing {
                        Button(action: startEditing) {
                            Text("Edit")
                                .font(.custom("Raleway-Medium", size: 14))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(Color.yugiMocha.ignoresSafeArea(edges: .top))
                .opacity(showHeader ? 1 : 0)
                .offset(y: showHeader ? 0 : 12)
                .animation(.easeOut(duration: 0.6), value: showHeader)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Identity block
                        identityBlock
                            .opacity(showIdentity ? 1 : 0)
                            .offset(y: showIdentity ? 0 : 12)
                            .animation(.easeOut(duration: 0.6), value: showIdentity)

                        // Details card
                        detailsCard
                            .padding(.horizontal, 20)
                            .opacity(showDetails ? 1 : 0)
                            .offset(y: showDetails ? 0 : 12)
                            .animation(.easeOut(duration: 0.6), value: showDetails)

                        // Preferences
                        preferencesSection
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                            .opacity(showPreferences ? 1 : 0)
                            .offset(y: showPreferences ? 0 : 12)
                            .animation(.easeOut(duration: 0.6), value: showPreferences)

                        if isEditing {
                            saveCancelButtons
                                .padding(.horizontal, 20)
                                .padding(.top, 24)
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { showHeader      = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { showIdentity    = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) { showDetails     = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) { showPreferences = true }
            loadUserData()
        }
        .onReceive(apiService.$currentUser) { user in
            if let user = user {
                print("🔐 PersonalInformation: Current user updated: \(user.fullName)")
                fullName    = user.fullName
                email       = user.email
                phoneNumber = user.phoneNumber ?? ""
                if let profileImageString = user.profileImage,
                   let imageData = Data(base64Encoded: profileImageString),
                   let image = UIImage(data: imageData) {
                    profileImage = image
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {}
        } message: { Text(errorMessage) }
        .alert("Success", isPresented: $showingSuccess) {
            Button("OK") {}
        } message: { Text(successMessage) }
        .photosPicker(isPresented: $showingImagePicker, selection: $selectedImageItem, matching: .images)
        .onChange(of: selectedImageItem) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        if isEditing { tempProfileImage = image } else { profileImage = image }
                    }
                }
            }
        }
    }

    // MARK: - Identity Block

    private var identityBlock: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 36)

            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color.yugiOat)
                    .frame(width: 72, height: 72)
                    .overlay {
                        if let image = isEditing ? tempProfileImage : profileImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .clipShape(Circle())
                        } else {
                            Text(String(fullName.prefix(1).uppercased()))
                                .font(.custom("Raleway-Medium", size: 26))
                                .foregroundColor(Color.yugiMocha)
                        }
                    }

                if isEditing {
                    Button(action: { showingImagePicker = true }) {
                        Circle()
                            .fill(Color.yugiMocha)
                            .frame(width: 22, height: 22)
                            .overlay(
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.white)
                            )
                    }
                    .offset(x: 2, y: 2)
                }
            }

            Spacer().frame(height: 14)

            Text(fullName.isEmpty ? "Your name" : fullName)
                .font(.custom("Raleway-Medium", size: 20))
                .foregroundColor(Color.yugiSoftBlack)
                .tracking(-0.3)

            Spacer().frame(height: 4)

            Text("\(getUserTypeDisplay()) · member since \(formatMemberSinceDate())")
                .font(.custom("Raleway-Regular", size: 13))
                .foregroundColor(Color.yugiBodyText)

            Spacer().frame(height: 24)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(spacing: 0) {
            detailRow(label: "NAME",  value: fullName,    editField: $tempFullName,    keyboardType: .default)
            Divider().padding(.horizontal, 18)
            detailRow(label: "EMAIL", value: email,       editField: $tempEmail,       keyboardType: .emailAddress)
            Divider().padding(.horizontal, 18)
            detailRow(label: "PHONE", value: phoneNumber, editField: $tempPhoneNumber, keyboardType: .phonePad)
        }
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.yugiOat, lineWidth: 1))
        .cornerRadius(16)
    }

    @ViewBuilder
    private func detailRow(label: String, value: String, editField: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.custom("Raleway-Medium", size: 11))
                    .foregroundColor(Color.yugiBodyText)
                    .kerning(0.4)
                if isEditing {
                    TextField(value.isEmpty ? "Not added" : "", text: editField)
                        .font(.custom("Raleway-Regular", size: 15))
                        .foregroundColor(Color.yugiSoftBlack)
                        .keyboardType(keyboardType)
                } else {
                    Text(value.isEmpty ? "Not added" : value)
                        .font(.custom("Raleway-Regular", size: 15))
                        .foregroundColor(value.isEmpty ? Color.yugiBodyText.opacity(0.5) : Color.yugiSoftBlack)
                }
            }
            Spacer()
            if !isEditing {
                Text("›")
                    .font(.system(size: 18))
                    .foregroundColor(Color.yugiMocha)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PREFERENCES")
                .font(.custom("Raleway-Medium", size: 11))
                .foregroundColor(Color.yugiBodyText)
                .kerning(0.5)
                .padding(.leading, 4)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Personalised recommendations")
                        .font(.custom("Raleway-Regular", size: 15))
                        .foregroundColor(Color.yugiSoftBlack)
                    Text("We'll tailor suggestions to your family")
                        .font(.custom("Raleway-Regular", size: 12))
                        .foregroundColor(Color.yugiBodyText)
                }
                Spacer()
                Toggle("", isOn: $trackingEnabled)
                    .labelsHidden()
                    .tint(Color.yugiMocha)
                    .onChange(of: trackingEnabled) { _, newValue in
                        if newValue { ConsentManager.shared.grantConsent() }
                        else        { ConsentManager.shared.revokeConsent() }
                    }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.yugiOat, lineWidth: 1))
            .cornerRadius(16)
        }
    }

    // MARK: - Save / Cancel Buttons (preserved logic, restyled)

    private var saveCancelButtons: some View {
        VStack(spacing: 12) {
            Button(action: saveChanges) {
                Group {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("Save changes")
                            .font(.custom("Raleway-Medium", size: 15))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.yugiMocha)
                .clipShape(Capsule())
            }
            .disabled(isLoading)

            Button(action: cancelEditing) {
                Text("Cancel")
                    .font(.custom("Raleway-Medium", size: 15))
                    .foregroundColor(Color.yugiBodyText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .overlay(Capsule().stroke(Color.yugiOat, lineWidth: 1))
                    .clipShape(Capsule())
            }
            .disabled(isLoading)
        }
    }

    // MARK: - Helper Methods (preserved)

    private func loadUserData() {
        if apiService.currentUser == nil {
            if apiService.isAuthenticated {
                print("🔐 PersonalInformation: No current user but authenticated, fetching...")
                apiService.fetchCurrentUser()
            } else {
                print("🔐 PersonalInformation: User not authenticated and no current user")
                showError("Please sign in to view your personal information.")
                return
            }
        }
        guard let user = apiService.currentUser else {
            print("🔐 PersonalInformation: Unable to load user data - no user available")
            showError("Unable to load user data. Please sign in and try again.")
            return
        }
        print("🔐 PersonalInformation: Loading user data for: \(user.fullName)")
        fullName    = user.fullName
        email       = user.email
        phoneNumber = user.phoneNumber ?? ""
        if let profileImageString = user.profileImage,
           let imageData = Data(base64Encoded: profileImageString),
           let image = UIImage(data: imageData) {
            profileImage = image
            print("🔐 PersonalInformation: Profile image loaded from backend")
        } else {
            profileImage = nil
            print("🔐 PersonalInformation: No profile image available")
        }
        print("🔐 PersonalInformation: User data loaded successfully")
        print("🔐 PersonalInformation: Full Name: \(fullName)")
        print("🔐 PersonalInformation: Email: \(email)")
        print("🔐 PersonalInformation: Phone: \(phoneNumber)")
    }

    private func startEditing() {
        tempFullName     = fullName
        tempEmail        = email
        tempPhoneNumber  = phoneNumber
        tempProfileImage = profileImage
        isEditing        = true
    }

    private func cancelEditing() {
        isEditing        = false
        tempFullName     = ""
        tempEmail        = ""
        tempPhoneNumber  = ""
        tempProfileImage = nil
    }

    private func saveChanges() {
        guard !tempFullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError("Please enter your full name")
            return
        }
        guard isValidEmail(tempEmail) else {
            showError("Please enter a valid email address")
            return
        }
        isLoading = true
        var profileImageString: String? = nil
        if let image = tempProfileImage {
            profileImageString = ImageCompressor.compressProfileImage(image)
        }
        apiService.updateProfile(
            fullName:     tempFullName.trimmingCharacters(in: .whitespacesAndNewlines),
            email:        tempEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            phoneNumber:  tempPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            profileImage: profileImageString
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                isLoading = false
                if case let .failure(error) = completion {
                    showError("Failed to update profile: \(error.localizedDescription)")
                }
            },
            receiveValue: { _ in
                fullName    = tempFullName.trimmingCharacters(in: .whitespacesAndNewlines)
                email       = tempEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                phoneNumber = tempPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
                if tempProfileImage != nil { profileImage = tempProfileImage }
                isEditing = false
                showSuccess("Profile updated successfully")
                apiService.fetchCurrentUser()
            }
        )
        .store(in: &apiService.cancellables)
    }

    private func formatMemberSinceDate() -> String {
        guard let user = apiService.currentUser else { return "recently" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: user.createdAt)
    }

    private func getUserTypeDisplay() -> String {
        guard let user = apiService.currentUser else { return "Member" }
        switch user.userType {
        case .parent:   return "Parent"
        case .provider: return "Provider"
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
