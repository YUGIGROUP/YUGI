import SwiftUI

enum UserType: String, CaseIterable {
    case parent = "Parent"
    case provider = "Provider"
    case other = "Other"
}

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 1
    @State private var fullName = ""
    @State private var email = ""
    @State private var selectedUserType: UserType = .parent
    
    // Parent specific fields
    @State private var password = ""
    @State private var confirmPassword = ""
    
    // Provider specific fields
    @State private var mobileNumber = ""
    @State private var businessName = ""
    @State private var businessAddress = ""
    @State private var servicesDescription = ""
    @State private var selectedAgeGroups: Set<String> = []
    @State private var qualificationsURL: URL?
    @State private var dbsCertificateURL: URL?
    @State private var profileImageData: Data?
    @State private var bio = ""
    
    // Other specific fields
    @State private var appUsageDescription = ""
    @State private var wouldBookClasses = false
    
    // Form validation
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let ageGroups = ["0-3", "4-7", "8-11", "12-16"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress bar
                ProgressView(value: Double(currentStep), total: 3)
                    .tint(Color("Primary"))
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Tell us about yourself")
                .font(.title2)
                .bold()
            
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
            
            Picker("User Type", selection: $selectedUserType) {
                ForEach(UserType.allCases, id: \.self) { type in
                    Text(type.rawValue)
                        .tag(type)
                }
            }
            .pickerStyle(.segmented)
            
            VStack(alignment: .leading, spacing: 12) {
                switch selectedUserType {
                case .parent:
                    Text("As a parent, you'll be able to:")
                    bulletPoint("Browse and book children's classes")
                    bulletPoint("Manage your bookings")
                    bulletPoint("Track your children's activities")
                case .provider:
                    Text("As a provider, you'll be able to:")
                    bulletPoint("List your classes and services")
                    bulletPoint("Manage bookings and schedules")
                    bulletPoint("Connect with parents")
                case .other:
                    Text("Tell us more about how you'd like to use YUGI")
                }
            }
            .foregroundColor(.secondary)
        }
    }
    
    private var parentSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Set up your parent account")
                .font(.title2)
                .bold()
            
            VStack(alignment: .leading, spacing: 16) {
                YUGISecureField(
                    placeholder: "Password",
                    text: $password
                )
                
                YUGISecureField(
                    placeholder: "Confirm Password",
                    text: $confirmPassword
                )
            }
            
            YUGIButton(title: "Create Account") {
                validateAndSubmitParent()
            }
        }
    }
    
    private var providerSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Set up your provider account")
                .font(.title2)
                .bold()
            
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
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ageGroups, id: \.self) { age in
                            AgeGroupButton(
                                age: age,
                                isSelected: selectedAgeGroups.contains(age),
                                action: {
                                    if selectedAgeGroups.contains(age) {
                                        selectedAgeGroups.remove(age)
                                    } else {
                                        selectedAgeGroups.insert(age)
                                    }
                                }
                            )
                        }
                    }
                }
                
                YUGITextEditor(placeholder: "Describe your classes/services", text: $servicesDescription, minHeight: 100)
                
                YUGITextEditor(placeholder: "Write a friendly bio", text: $bio, minHeight: 100)
                
                DocumentUploadButton(
                    title: "Upload Qualifications",
                    systemImage: "doc.fill",
                    action: {
                        // Handle document upload
                    }
                )
                
                DocumentUploadButton(
                    title: "Upload DBS Certificate",
                    systemImage: "doc.fill",
                    action: {
                        // Handle document upload
                    }
                )
                
                ImageUploadButton(
                    title: "Upload Profile Picture/Logo",
                    systemImage: "photo.fill",
                    action: {
                        // Handle image upload
                    }
                )
            }
            
            YUGIButton(title: "Create Account") {
                validateAndSubmitProvider()
            }
        }
    }
    
    private var otherSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Tell us more")
                .font(.title2)
                .bold()
            
            VStack(alignment: .leading, spacing: 16) {
                YUGITextEditor(placeholder: "What would you use the app for?", text: $appUsageDescription, minHeight: 100)
                
                Toggle("Would you like to book classes for children you care for?", isOn: $wouldBookClasses)
                    .tint(Color("Primary"))
            }
            
            YUGIButton(title: "Continue") {
                validateAndSubmitOther()
            }
        }
    }
    
    private var navigationButtons: some View {
        HStack {
            if currentStep > 1 {
                YUGIButton(title: "Back", style: .secondary) {
                    withAnimation {
                        currentStep -= 1
                    }
                }
            }
            
            if currentStep < 3 {
                YUGIButton(title: "Next") {
                    validateAndProceed()
                }
            }
        }
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top) {
            Text("•")
            Text(text)
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
    }
    
    private func validateAndSubmitProvider() {
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
        // Handle provider signup
    }
    
    private func validateAndSubmitOther() {
        guard !appUsageDescription.isEmpty else {
            showError("Please tell us how you would use the app")
            return
        }
        // Handle other signup
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

struct AgeGroupButton: View {
    let age: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(age)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color("Primary") : Color.gray.opacity(0.1))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct DocumentUploadButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

struct ImageUploadButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
    }
}

#Preview {
    SignUpView()
} 