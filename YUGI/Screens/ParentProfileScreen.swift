import SwiftUI

struct ParentProfileScreen: View {
    let parentName: String
    @Environment(\.dismiss) private var dismiss
    @State private var fullName = "Sarah Johnson"
    @State private var email = "info@yugiapp.ai"
    @State private var phoneNumber = "+44 7123 456789"
    @State private var showingEditProfile = false
    @State private var showingNotifications = false
    @State private var showingTermsPrivacy = false
    @State private var showingPaymentMethods = false
    @StateObject private var notificationService = NotificationService.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeader
                    
                    // Account Information
                    accountSection
                    
                    // Payment & Billing
                    paymentSection
                    
                    // Preferences
                    preferencesSection
                    
                    // Support & Legal
                    supportSection
                }
                .padding(20)
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#BC6C5C"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Profile")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileScreen(
                    fullName: $fullName,
                    email: $email,
                    phoneNumber: $phoneNumber
                )
            }
            .sheet(isPresented: $showingNotifications) {
                NotificationsScreen()
            }
            .sheet(isPresented: $showingTermsPrivacy) {
                TermsPrivacyScreen()
            }
        }
    }
    
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Profile Image
            ZStack {
                Circle()
                    .fill(Color(hex: "#BC6C5C").opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Text(String(fullName.prefix(1)))
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(Color(hex: "#BC6C5C"))
            }
            
            VStack(spacing: 4) {
                Text(fullName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.yugiGray)
                
                Text("Parent Account")
                    .font(.system(size: 16))
                    .foregroundColor(.yugiGray.opacity(0.7))
            }
            
            Button(action: {
                showingEditProfile = true
            }) {
                Text("Edit Profile")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#BC6C5C"))
                    .cornerRadius(8)
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account Information")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.yugiGray)
            
            VStack(spacing: 12) {
                ProfileInfoRow(
                    icon: "person.fill",
                    title: "Full Name",
                    value: fullName
                )
                
                ProfileInfoRow(
                    icon: "envelope.fill",
                    title: "Email",
                    value: email
                )
                
                ProfileInfoRow(
                    icon: "phone.fill",
                    title: "Phone Number",
                    value: phoneNumber
                )
                
                ProfileInfoRow(
                    icon: "calendar",
                    title: "Member Since",
                    value: "January 2024"
                )
            }
        }
    }
    
    private var paymentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payment & Billing")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.yugiGray)
            
            VStack(spacing: 12) {
                ProfileInfoRow(
                    icon: "creditcard.fill",
                    title: "Payment Method",
                    value: "Credit Card (**** 1234)"
                )
                
                ProfileInfoRow(
                    icon: "calendar.badge.clock",
                    title: "Next Billing Date",
                    value: "March 15, 2024"
                )
                
                ProfileInfoRow(
                    icon: "chart.bar.fill",
                    title: "Billing History",
                    value: "View all"
                )
            }
        }
    }
    
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferences")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.yugiGray)
            
            VStack(spacing: 12) {
                ProfileActionRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    subtitle: "Manage your notification preferences",
                    badge: notificationService.unreadCount > 0 ? "\(notificationService.unreadCount)" : nil
                ) {
                    showingNotifications = true
                }
                
                ProfileActionRow(
                    icon: "location.fill",
                    title: "Location Services",
                    subtitle: "Manage location permissions",
                    badge: nil
                ) {
                    // Open location settings
                }
                
                ProfileActionRow(
                    icon: "lock.fill",
                    title: "Privacy Settings",
                    subtitle: "Manage your privacy preferences",
                    badge: nil
                ) {
                    // Open privacy settings
                }
            }
        }
    }
    
    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Support & Legal")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.yugiGray)
            
            VStack(spacing: 12) {
                ProfileActionRow(
                    icon: "message.fill",
                    title: "Contact Us",
                    subtitle: "Reach out to our support team",
                    badge: nil
                ) {
                    // Open contact form
                }
                
                ProfileActionRow(
                    icon: "questionmark.circle.fill",
                    title: "Help & Support",
                    subtitle: "Get help and find answers",
                    badge: nil
                ) {
                    // Open help center
                }
                
                ProfileActionRow(
                    icon: "doc.text.fill",
                    title: "Terms of Service",
                    subtitle: "Read our terms and conditions",
                    badge: nil
                ) {
                    showingTermsPrivacy = true
                }
                
                ProfileActionRow(
                    icon: "hand.raised.fill",
                    title: "Privacy Policy",
                    subtitle: "Read our privacy policy",
                    badge: nil
                ) {
                    // Open privacy policy
                }
            }
        }
    }
}

struct ProfileInfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(hex: "#BC6C5C"))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.yugiGray.opacity(0.7))
                
                Text(value)
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

struct ProfileActionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let badge: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "#BC6C5C"))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.yugiGray)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray.opacity(0.7))
                }
                
                Spacer()
                
                if let badge {
                    Text(badge)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .background(Color(hex: "#BC6C5C"))
                        .cornerRadius(4)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.yugiGray.opacity(0.5))
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EditProfileScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var fullName: String
    @Binding var email: String
    @Binding var phoneNumber: String
    @State private var tempFullName: String = ""
    @State private var tempEmail: String = ""
    @State private var tempPhoneNumber: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Edit Profile")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Update your personal information")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
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
                
                // Form
                ScrollView {
                    VStack(spacing: 24) {
                        // Full Name
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Full Name")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.yugiGray)
                            
                            YUGITextField(
                                text: $tempFullName,
                                placeholder: "Enter your full name",
                                icon: "person.fill"
                            )
                        }
                        
                        // Email
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Email Address")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.yugiGray)
                            
                            YUGITextField(
                                text: $tempEmail,
                                placeholder: "Enter your email address",
                                icon: "envelope.fill",
                                keyboardType: .emailAddress
                            )
                        }
                        
                        // Phone Number
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Phone Number")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.yugiGray)
                            
                            YUGITextField(
                                text: $tempPhoneNumber,
                                placeholder: "Enter your phone number",
                                icon: "phone.fill",
                                keyboardType: .phonePad
                            )
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(20)
                }
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#BC6C5C"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                tempFullName = fullName
                tempEmail = email
                tempPhoneNumber = phoneNumber
            }
        }
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
        
        // Update values
        fullName = tempFullName.trimmingCharacters(in: .whitespacesAndNewlines)
        email = tempEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        phoneNumber = tempPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Dismiss
        dismiss()
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
}

#Preview {
    ParentProfileScreen(parentName: "Sarah Johnson")
} 