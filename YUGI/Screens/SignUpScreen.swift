import SwiftUI
import PhotosUI
import Combine

struct SignUpScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var firebaseAuthService = FirebaseAuthService()
    @State private var currentStep = 1
    @State private var fullName = ""
    @State private var email = ""
    @State private var selectedUserType: UserType = .parent
    @State private var shouldShowWelcome = false
    @State private var shouldShowProviderVerification = false
    @State private var shouldShowProviderTerms = false
    @State private var shouldNavigateToParentOnboarding = false
    
    // Parent specific fields
    @State private var password = ""
    @State private var confirmPassword = ""
    
    // Provider specific fields
    @State private var mobileNumber = ""
    @State private var businessName = ""
    @State private var businessAddress = ""
    @State private var selectedAgeGroups: Set<String> = []
    @State private var bio = ""
    @State private var providerSubStep = 1
    @State private var qualificationsItem: PhotosPickerItem?
    @State private var qualificationsImage: UIImage?
    @State private var dbsCertificateItem: PhotosPickerItem?
    @State private var dbsCertificateImage: UIImage?
    @State private var profileImageItem: PhotosPickerItem?
    @State private var profileImage: UIImage?
    @State private var providerPassword = ""
    @State private var providerConfirmPassword = ""
    

    
    // Form validation
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let ageGroups = ["0-3", "4-7", "8-11", "12-16"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress bar
                ProgressView(value: Double(currentStep), total: 3)
                    .tint(Color(hex: "#BC6C5C"))
                    .padding()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Step 1: Basic Info
                        if currentStep == 1 {
                            basicInfoSection
                        }
                        // Step 2: User Type Selection
                        else if currentStep == 2 {
                            userTypeSection
                        }
                        // Step 3: Type Specific Fields
                        else if currentStep == 3 {
                            switch selectedUserType {
                            case .parent:
                                parentSection
                            case .provider:
                                providerSection
                            }
                        }
                        
                        navigationButtons
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .background(Color(hex: "#BC6C5C").ignoresSafeArea())
            .onChange(of: profileImageItem) { oldValue, newValue in
                if let item = newValue {
                    loadImage(from: item) { image in
                        profileImage = image
                    }
                }
            }
            .onChange(of: qualificationsItem) { oldValue, newValue in
                if let item = newValue {
                    loadImage(from: item) { image in
                        qualificationsImage = image
                    }
                }
            }
            .onChange(of: dbsCertificateItem) { oldValue, newValue in
                if let item = newValue {
                    loadImage(from: item) { image in
                        dbsCertificateImage = image
                    }
                }
            }
            .fullScreenCover(isPresented: $shouldShowWelcome) {
                WelcomeUserScreen(userName: fullName)
            }
            .fullScreenCover(isPresented: $shouldShowProviderTerms) {
                TermsPrivacyScreen(
                    isReadOnly: false,
                    onTermsAccepted: {
                        // After accepting terms, show verification screen
                        shouldShowProviderTerms = false
                        shouldShowProviderVerification = true
                    },
                    userType: .provider
                )
            }
            .fullScreenCover(isPresented: $shouldShowProviderVerification) {
                ProviderVerificationScreen(businessName: businessName)
            }
            .navigationDestination(isPresented: $shouldNavigateToParentOnboarding) {
                ParentOnboardingScreen(parentName: fullName)
                    .navigationBarBackButtonHidden()
            }
        }
    }
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Tell us about yourself")
                .font(.title2)
                .bold()
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 16) {
                YUGITextField(
                    text: $fullName,
                    placeholder: "Full Name",
                    icon: "person.fill"
                )
                
                YUGITextField(
                    text: $email,
                    placeholder: "Email Address",
                    icon: "envelope.fill",
                    keyboardType: .emailAddress
                )
            }
        }
    }
    
    private var userTypeSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("How will you use YUGI?")
                .font(.title2)
                .bold()
                .foregroundColor(.white)
            
            VStack(spacing: 16) {
                ForEach(UserType.allCases, id: \.self) { type in
                    Button {
                        selectedUserType = type
                    } label: {
                        HStack {
                            Image(systemName: selectedUserType == type ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedUserType == type ? .white : .white.opacity(0.7))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(type.displayName)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text(type.description)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedUserType == type ? Color.white : Color.white.opacity(0.3))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var parentSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Set up your parent account")
                .font(.title2)
                .bold()
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 16) {
                YUGISecureField(
                    placeholder: "Password",
                    text: $password
                )
                
                YUGISecureField(
                    placeholder: "Confirm Password",
                    text: $confirmPassword
                )
                
                Text("Password must be at least 8 characters")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }
            
            YUGIButton(
                title: "Create Account",
                style: .secondary,
                action: validateAndSubmitParent
            )
        }
    }
    
    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Set up your provider account")
                .font(.title2)
                .bold()
                .foregroundColor(.white)
            
            if providerSubStep == 1 {
                providerBasicInfoSection
            } else if providerSubStep == 2 {
                providerDocumentsSection
            } else {
                providerPasswordSection
            }
        }
    }
    
    private var providerBasicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            YUGITextField(
                text: $mobileNumber,
                placeholder: "Mobile Number",
                icon: "phone.fill",
                keyboardType: .phonePad
            )
            
            YUGITextField(
                text: $businessName,
                placeholder: "Business Name",
                icon: "building.2.fill"
            )
            
            YUGITextField(
                text: $businessAddress,
                placeholder: "Business Address",
                icon: "location.fill"
            )
            
            Text("Target Age Groups")
                .font(.headline)
                .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ageGroups, id: \.self) { age in
                        Button {
                            if selectedAgeGroups.contains(age) {
                                selectedAgeGroups.remove(age)
                            } else {
                                selectedAgeGroups.insert(age)
                            }
                        } label: {
                            Text(age)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedAgeGroups.contains(age) ? Color.white : Color.white.opacity(0.2))
                                .foregroundColor(selectedAgeGroups.contains(age) ? Color(hex: "#BC6C5C") : .white)
                                .cornerRadius(20)
                        }
                    }
                }
            }
            
            YUGITextEditor(
                placeholder: "Write a friendly bio that includes a description of your classes/services offered...",
                text: $bio,
                minHeight: 120,
                maxCharacters: 400
            )
            
            Text("\(bio.count)/400 characters")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .trailing)
            
            YUGIButton(
                title: "Next",
                style: .secondary,
                action: {
                    validateAndProceedProvider()
                }
            )
        }
    }
    
    private var providerDocumentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Required Documents")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Please upload your DBS certificate and profile picture. Qualifications are optional.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
            
            VStack(spacing: 20) {
                // Profile Image
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Profile Picture")
                            .foregroundColor(.white)
                        Text("(Required)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    PhotosPicker(selection: $profileImageItem, matching: .images) {
                        if let profileImage = profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                
                // Qualifications
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Qualifications")
                            .foregroundColor(.white)
                        Text("(Optional)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    PhotosPicker(selection: $qualificationsItem, matching: .images) {
                        HStack {
                            Image(systemName: "doc.fill")
                            Text(qualificationsImage != nil ? "Change Qualifications" : "Upload Qualifications")
                            if qualificationsImage != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                
                // DBS Certificate
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("DBS Certificate")
                            .foregroundColor(.white)
                        Text("(Required)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    PhotosPicker(selection: $dbsCertificateItem, matching: .images) {
                        HStack {
                            Image(systemName: "doc.fill")
                            Text(dbsCertificateImage != nil ? "Change DBS Certificate" : "Upload DBS Certificate")
                            if dbsCertificateImage != nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
            }
            
            Spacer()
            
            YUGIButton(
                title: "Next",
                style: .secondary,
                action: validateAndProceedToPassword
            )
        }
    }
    
    private var providerPasswordSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create your password")
                .font(.headline)
                .foregroundColor(.white)
            
            Text("Choose a strong password to secure your account")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
            
            VStack(alignment: .leading, spacing: 16) {
                YUGISecureField(
                    placeholder: "Password",
                    text: $providerPassword
                )
                
                YUGISecureField(
                    placeholder: "Confirm Password",
                    text: $providerConfirmPassword
                )
                
                Text("Password must be at least 8 characters")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
            
            YUGIButton(
                title: "Create Account",
                style: .secondary,
                action: validateAndSubmitProvider
            )
        }
    }
    

    
    private var navigationButtons: some View {
        HStack {
            if currentStep > 1 {
                YUGIButton(
                    title: "Back",
                    style: .secondary,
                    action: {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                )
            }
            
            if currentStep < 3 {
                YUGIButton(
                    title: "Next",
                    style: .secondary,
                    action: validateAndProceed
                )
            }
        }
    }
    
    private func validateAndProceed() {
        if currentStep == 1 {
            guard !fullName.isEmpty else {
                showError("Please enter your full name")
                return
            }
            guard isValidEmail(email) else {
                showError("Please enter a valid email address")
                return
            }
        }
        
        withAnimation {
            currentStep += 1
        }
    }
    
    private func validateAndSubmitParent() {
        guard password.count >= 8 else {
            showError("Password must be at least 8 characters")
            return
        }
        guard password == confirmPassword else {
            showError("Passwords do not match")
            return
        }
        
        // Create the user account through Firebase Auth first, then backend
        print("🔐 SignUpScreen: Creating parent account for \(email)")
        
        firebaseAuthService.signUp(
            email: email,
            password: password,
            fullName: fullName,
            userType: .parent,
            phoneNumber: nil
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    print("🔐 SignUpScreen: Parent signup failed: \(error)")
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            },
            receiveValue: { result in
                print("🔐 SignUpScreen: Firebase parent signup successful!")
                print("🔐 SignUpScreen: Firebase UID: \(result.user.uid)")
                
                // Handle parent signup - show welcome screen first
                self.shouldShowWelcome = true
            }
        )
        .store(in: &firebaseAuthService.cancellables)
    }
    
    private func validateAndProceedProvider() {
        guard !mobileNumber.isEmpty else {
            showError("Please enter your mobile number")
            return
        }
        guard !businessName.isEmpty else {
            showError("Please enter your business name")
            return
        }
        guard !businessAddress.isEmpty else {
            showError("Please enter your business address")
            return
        }
        guard !selectedAgeGroups.isEmpty else {
            showError("Please select at least one age group")
            return
        }
        guard !bio.isEmpty else {
            showError("Please write a bio")
            return
        }
        guard bio.count <= 400 else {
            showError("Bio must be 400 characters or less")
            return
        }
        
        withAnimation {
            providerSubStep = 2
        }
    }
    
    private func validateAndProceedToPassword() {
        guard profileImage != nil else {
            showError("Please upload your profile picture")
            return
        }
        guard dbsCertificateImage != nil else {
            showError("Please upload your DBS certificate")
            return
        }
        // Qualifications are now optional - no validation needed
        
        withAnimation {
            providerSubStep = 3
        }
    }
    
    private func validateAndSubmitProvider() {
        guard providerPassword.count >= 8 else {
            showError("Password must be at least 8 characters")
            return
        }
        guard providerPassword == providerConfirmPassword else {
            showError("Passwords do not match")
            return
        }
        
        // Save uploaded documents to UserDefaults
        if let dbsImage = dbsCertificateImage,
           let dbsData = dbsImage.jpegData(compressionQuality: 0.8) {
            UserDefaults.standard.set(dbsData, forKey: "providerDBSCertificate")
            UserDefaults.standard.set(true, forKey: "providerDBSUploaded")
        }
        
        if let qualificationsImage = qualificationsImage,
           let qualificationsData = qualificationsImage.jpegData(compressionQuality: 0.8) {
            UserDefaults.standard.set(qualificationsData, forKey: "providerQualifications")
            UserDefaults.standard.set(true, forKey: "providerQualificationsUploaded")
        }
        
        // Save business information to ProviderBusinessService
        ProviderBusinessService.shared.updateFromSignUp(
            businessName: businessName,
            businessAddress: businessAddress,
            contactEmail: email,
            contactPhone: mobileNumber,
            bio: bio
        )
        
        // Create the user account through Firebase Auth first, then backend
        print("🔐 SignUpScreen: Creating provider account for \(email)")
        
        firebaseAuthService.signUp(
            email: email,
            password: providerPassword,
            fullName: fullName,
            userType: .provider,
            phoneNumber: mobileNumber,
            businessName: businessName,
            businessAddress: businessAddress,
            bio: bio
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    print("🔐 SignUpScreen: Provider signup failed: \(error)")
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            },
            receiveValue: { result in
                print("🔐 SignUpScreen: Firebase provider signup successful!")
                print("🔐 SignUpScreen: Firebase UID: \(result.user.uid)")
                
                // Handle provider signup - show Terms & Conditions first, then verification screen
                self.shouldShowProviderTerms = true
            }
        )
        .store(in: &firebaseAuthService.cancellables)
    }
    

    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

#Preview {
    SignUpScreen()
}

// Add image loading extensions
extension SignUpScreen {
    private func loadImage(from item: PhotosPickerItem, completion: @escaping (UIImage?) -> Void) {
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                await MainActor.run {
                    completion(nil)
                }
                return
            }
            
            guard let image = UIImage(data: data) else {
                await MainActor.run {
                    completion(nil)
                }
                return
            }
            
            await MainActor.run {
                completion(image)
            }
        }
    }
} 