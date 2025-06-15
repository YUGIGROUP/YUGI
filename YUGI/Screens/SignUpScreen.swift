import SwiftUI
import PhotosUI

struct SignUpScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 1
    @State private var fullName = ""
    @State private var email = ""
    @State private var selectedUserType: UserType = .parent
    @State private var shouldShowWelcome = false
    
    // Parent specific fields
    @State private var password = ""
    @State private var confirmPassword = ""
    
    // Provider specific fields
    @State private var mobileNumber = ""
    @State private var businessName = ""
    @State private var businessAddress = ""
    @State private var servicesDescription = ""
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
    
    // Other specific fields
    @State private var appUsageDescription = ""
    @State private var wouldBookClasses = false
    @State private var otherSubStep = 1
    @State private var otherPassword = ""
    @State private var otherConfirmPassword = ""
    
    // Form validation
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let ageGroups = ["0-3", "4-7", "8-11", "12-16"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress bar
                ProgressView(value: Double(currentStep), total: 3)
                    .tint(Color.yugiOrange)
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
                            case .other:
                                otherSection
                            }
                        }
                        
                        navigationButtons
                    }
                    .padding()
                }
            }
            .navigationTitle("Sign Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.yugiOrange, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Sign Up")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .background(Color.yugiOrange.ignoresSafeArea())
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
            .navigationDestination(isPresented: $shouldShowWelcome) {
                WelcomeUserScreen(userName: fullName)
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
                                Text(type.rawValue)
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
                                .foregroundColor(selectedAgeGroups.contains(age) ? .yugiOrange : .white)
                                .cornerRadius(20)
                        }
                    }
                }
            }
            
            YUGITextEditor(placeholder: "Describe your classes/services", text: $servicesDescription, minHeight: 100)
            
            YUGITextEditor(placeholder: "Write a friendly bio", text: $bio, minHeight: 100)
            
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
            
            Text("Please upload your qualifications and DBS certificate")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
            
            VStack(spacing: 20) {
                // Profile Image
                VStack(alignment: .leading, spacing: 8) {
                    Text("Profile Picture")
                        .foregroundColor(.white)
                    
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
                    Text("Qualifications")
                        .foregroundColor(.white)
                    
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
                    Text("DBS Certificate")
                        .foregroundColor(.white)
                    
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
    
    private var otherSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Tell us more")
                .font(.title2)
                .bold()
                .foregroundColor(.white)
            
            if otherSubStep == 1 {
                otherBasicInfoSection
            } else {
                otherPasswordSection
            }
        }
    }
    
    private var otherBasicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            YUGITextEditor(placeholder: "What would you use the app for?", text: $appUsageDescription, minHeight: 100)
            
            Toggle("Would you like to book classes for children you care for?", isOn: $wouldBookClasses)
                .tint(.white)
                .foregroundColor(.white)
            
            Spacer()
            
            YUGIButton(
                title: "Next",
                style: .secondary,
                action: validateAndProceedOther
            )
        }
    }
    
    private var otherPasswordSection: some View {
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
                    text: $otherPassword
                )
                
                YUGISecureField(
                    placeholder: "Confirm Password",
                    text: $otherConfirmPassword
                )
                
                Text("Password must be at least 8 characters")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
            
            YUGIButton(
                title: "Create Account",
                style: .secondary,
                action: validateAndSubmitOther
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
        // Handle parent signup
        shouldShowWelcome = true
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
        guard !servicesDescription.isEmpty else {
            showError("Please describe your services")
            return
        }
        guard !bio.isEmpty else {
            showError("Please write a bio")
            return
        }
        
        withAnimation {
            providerSubStep = 2
        }
    }
    
    private func validateAndProceedToPassword() {
        guard qualificationsImage != nil else {
            showError("Please upload your qualifications")
            return
        }
        guard dbsCertificateImage != nil else {
            showError("Please upload your DBS certificate")
            return
        }
        
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
        // Handle provider signup
        shouldShowWelcome = true
    }
    
    private func validateAndProceedOther() {
        guard !appUsageDescription.isEmpty else {
            showError("Please tell us how you would use the app")
            return
        }
        
        withAnimation {
            otherSubStep = 2
        }
    }
    
    private func validateAndSubmitOther() {
        guard otherPassword.count >= 8 else {
            showError("Password must be at least 8 characters")
            return
        }
        guard otherPassword == otherConfirmPassword else {
            showError("Passwords do not match")
            return
        }
        // Handle other signup
        shouldShowWelcome = true
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

extension UserType {
    var description: String {
        switch self {
        case .parent:
            return "Book and manage classes for your children"
        case .provider:
            return "List and manage your classes and services"
        case .other:
            return "Tell us how you'd like to use YUGI"
        }
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