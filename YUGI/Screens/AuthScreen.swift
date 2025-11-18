import SwiftUI
import Combine

struct AuthScreen: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isShowingPassword = false
    @State private var isLoading = false
    @State private var shouldNavigateToParentDashboard = false
    @State private var shouldNavigateToProviderDashboard = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var shouldNavigateToSignUp = false
    @State private var shouldNavigateToForgotPassword = false
    
    @StateObject private var biometricService = BiometricAuthService.shared
    @StateObject private var apiService = APIService.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Text("Welcome Back")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.yugiGray)
                    
                    Text("Sign in to continue")
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
                            .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#BC6C5C")))
                            .onChange(of: biometricService.isRememberMeEnabled) { _, newValue in
                                biometricService.setRememberMeEnabled(newValue)
                            }
                        
                        Spacer()
                    }
                }
                .padding(.horizontal)
                
                // Sign In Button
                Button(action: signInWithCredentials) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isLoading ? "Signing In..." : "Sign In")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "#BC6C5C"))
                    )
                }
                .padding(.horizontal)
                .disabled(isLoading)
                
                // Forgot Password Link
                Button("Forgot Password?") {
                    shouldNavigateToForgotPassword = true
                }
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "#BC6C5C"))
                .fontWeight(.medium)
                .padding(.top, 8)
                
                // Sign Up Link
                HStack {
                    Text("Don't have an account?")
                        .foregroundColor(.yugiGray.opacity(0.8))
                    Button("Sign Up") {
                        shouldNavigateToSignUp = true
                    }
                    .foregroundColor(Color(hex: "#BC6C5C"))
                    .fontWeight(.semibold)
                }
                .font(.system(size: 15))
                .padding(.top, 4)
            }
        }
        .background(Color.yugiCream.ignoresSafeArea())
        .navigationDestination(isPresented: $shouldNavigateToParentDashboard) {
            ParentDashboardScreen(parentName: apiService.currentUser?.fullName ?? "Parent")
        }
        .navigationDestination(isPresented: $shouldNavigateToProviderDashboard) {
            ProviderDashboardScreen(businessName: apiService.currentUser?.businessName ?? "Provider")
        }
        .navigationDestination(isPresented: $shouldNavigateToForgotPassword) {
            ForgotPasswordScreen()
        }
        .sheet(isPresented: $shouldNavigateToSignUp) {
            SignUpScreen()
        }
        .alert("Authentication Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadSavedCredentials()
        }
    }
    
    // MARK: - Authentication Methods
    
    private func signInWithCredentials() {
        guard !email.isEmpty && !password.isEmpty else {
            errorMessage = "Please enter both email and password."
            showingError = true
            return
        }
        
        isLoading = true
        
        // First sign in with Firebase, then login to backend
        let firebaseAuth = FirebaseAuthService()
        firebaseAuth.signIn(email: email, password: password)
            .mapError { error -> APIError in
                // Convert Firebase error to APIError
                print("❌ AuthScreen: Firebase sign-in failed: \(error.localizedDescription)")
                return APIError.networkError(error)
            }
            .flatMap { _ -> AnyPublisher<AuthResponse, APIError> in
                // After Firebase sign-in succeeds, login to backend
                print("✅ AuthScreen: Firebase sign-in successful, logging into backend...")
                return self.apiService.login(email: self.email, password: self.password)
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case let .failure(error) = completion {
                        print("❌ AuthScreen: Sign-in failed: \(error.localizedDescription)")
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                },
                receiveValue: { response in
                    print("✅ AuthScreen: Sign-in successful for user: \(response.user.fullName)")
                    
                    // Save credentials if "Remember Me" is enabled
                    if biometricService.isRememberMeEnabled {
                        biometricService.saveCredentials(email: email, password: password)
                    }
                    
                    // Navigate to appropriate dashboard based on user type
                    if response.user.userType == .provider {
                        shouldNavigateToProviderDashboard = true
                    } else {
                        shouldNavigateToParentDashboard = true
                    }
                }
            )
            .store(in: &apiService.cancellables)
    }
    
    private func loadSavedCredentials() {
        if let credentials = biometricService.loadSavedCredentials() {
            email = credentials.email
            password = credentials.password
        }
    }
}

#Preview("Auth Screen") {
    NavigationStack {
        AuthScreen()
    }
} 
