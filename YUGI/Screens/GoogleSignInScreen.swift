import SwiftUI

struct GoogleSignInScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
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
                            Image(systemName: "g.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.yugiGray)
                            Text("Sign in with Google")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.yugiGray)
                        }
                        
                        Text("Enter your Google account credentials")
                            .font(.system(size: 17))
                            .foregroundColor(.yugiGray.opacity(0.8))
                    }
                    .padding(.top, 48)
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        // Email Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Email")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.yugiGray)
                            
                            TextField("Enter your email", text: $email)
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
                    Button(action: signInWithGoogle) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isLoading ? "Signing In..." : "Sign In with Google")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red)
                        )
                    }
                    .padding(.horizontal)
                    .disabled(isLoading)
                    
                    // Help Links
                    VStack(spacing: 12) {
                        Button("Forgot password?") {
                            // Open Google's password reset page
                            if let url = URL(string: "https://accounts.google.com/signin/recovery") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.yugiOrange)
                        
                        Button("Create a Google Account") {
                            // Open Google account creation page
                            if let url = URL(string: "https://accounts.google.com/signup") {
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
                ParentDashboardScreen(parentName: "Google User")
            }
            .alert("Authentication Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Authentication Methods
    
    private func signInWithGoogle() {
        guard !email.isEmpty && !password.isEmpty else {
            errorMessage = "Please enter both email and password."
            showingError = true
            return
        }
        
        isLoading = true
        
        // Simulate Google Sign In API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isLoading = false
            
            // For demo purposes, simulate successful authentication
            // In a real app, this would call Google's authentication API
            print("🔐 Google Sign In: Authenticating with email: \(email)")
            
            // Save credentials if "Remember Me" is enabled
            if biometricService.isRememberMeEnabled {
                biometricService.saveCredentials(email: email, password: password)
            }
            
            // Navigate to dashboard
            shouldNavigateToDashboard = true
        }
    }
}

#Preview("Google Sign In Screen") {
    GoogleSignInScreen()
} 