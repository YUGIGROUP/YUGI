import SwiftUI

struct AppleSignInScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var appleID = ""
    @State private var password = ""
    @State private var isShowingPassword = false
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var shouldNavigateToDashboard = false
    
    @StateObject private var apiService = APIService.shared
    @StateObject private var biometricService = BiometricAuthService.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 32))
                                .foregroundColor(.yugiGray)
                            Text("Sign in with Apple")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.yugiGray)
                        }
                        
                        Text("Enter your Apple ID credentials")
                            .font(.system(size: 17))
                            .foregroundColor(.yugiGray.opacity(0.8))
                    }
                    .padding(.top, 48)
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        // Apple ID Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Apple ID")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.yugiGray)
                            
                            TextField("Enter your Apple ID", text: $appleID)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.yugiGray)
                            
                            HStack {
                                if isShowingPassword {
                                    TextField("Enter your password", text: $password)
                                } else {
                                    SecureField("Enter your password", text: $password)
                                }
                                
                                Button(action: {
                                    isShowingPassword.toggle()
                                }) {
                                    Image(systemName: isShowingPassword ? "eye.slash.fill" : "eye.fill")
                                        .foregroundColor(.yugiGray.opacity(0.6))
                                }
                            }
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // Remember Me Toggle
                        HStack {
                            Toggle("Remember Me", isOn: $biometricService.isRememberMeEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .yugiOrange))
                                .onChange(of: biometricService.isRememberMeEnabled) { _, newValue in
                                    biometricService.setRememberMeEnabled(newValue)
                                }
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal)
                    
                    // Sign In Button
                    Button(action: signInWithApple) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isLoading ? "Signing In..." : "Sign In with Apple")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black)
                        )
                    }
                    .padding(.horizontal)
                    .disabled(isLoading)
                    
                    // Help Links
                    VStack(spacing: 12) {
                        Button("Forgot Apple ID or Password?") {
                            // Open Apple's password reset page
                            if let url = URL(string: "https://iforgot.apple.com") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.yugiOrange)
                        
                        Button("Don't have an Apple ID?") {
                            // Open Apple ID creation page
                            if let url = URL(string: "https://appleid.apple.com") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.yugiOrange)
                    }
                    .padding(.top)
                }
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.yugiCream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(.yugiOrange)
                }
            }
            .navigationDestination(isPresented: $shouldNavigateToDashboard) {
                ParentDashboardScreen(parentName: "Apple User")
            }
            .alert("Authentication Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Authentication Methods
    
    private func signInWithApple() {
        guard !appleID.isEmpty && !password.isEmpty else {
            errorMessage = "Please enter both Apple ID and password."
            showingError = true
            return
        }
        
        isLoading = true
        
        // Simulate Apple Sign In API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isLoading = false
            
            // For demo purposes, simulate successful authentication
            // In a real app, this would call Apple's authentication API
            print("🔐 Apple Sign In: Authenticating with Apple ID: \(appleID)")
            
            // Save credentials if "Remember Me" is enabled
            if biometricService.isRememberMeEnabled {
                biometricService.saveCredentials(email: appleID, password: password)
            }
            
            // Navigate to dashboard
            shouldNavigateToDashboard = true
        }
    }
}

#Preview("Apple Sign In Screen") {
    AppleSignInScreen()
} 