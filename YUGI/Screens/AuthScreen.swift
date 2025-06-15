import SwiftUI

struct AuthScreen: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isShowingPassword = false
    @State private var isLoading = false
    
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
                }
                .padding(.horizontal)
                
                // Sign In Button
                YUGIButton(
                    title: "Sign In",
                    action: {
                        isLoading = true
                        // Add authentication logic here
                    }
                )
                .padding(.horizontal)
                
                // Divider
                HStack {
                    Rectangle()
                        .fill(Color.yugiGray.opacity(0.2))
                        .frame(height: 1)
                    
                    Text("or")
                        .font(.system(size: 15))
                        .foregroundColor(.yugiGray.opacity(0.6))
                    
                    Rectangle()
                        .fill(Color.yugiGray.opacity(0.2))
                        .frame(height: 1)
                }
                .padding(.horizontal)
                
                // Social Sign In Buttons
                VStack(spacing: 16) {
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "apple.logo")
                                .imageScale(.medium)
                            Text("Continue with Apple")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.yugiGray)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.yugiGray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    
                    Button(action: {}) {
                        HStack {
                            Image(systemName: "g.circle.fill")
                                .imageScale(.medium)
                            Text("Continue with Google")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.yugiGray)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.yugiGray.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal)
                
                // Sign Up Link
                HStack {
                    Text("Don't have an account?")
                        .foregroundColor(.yugiGray.opacity(0.8))
                    NavigationLink("Sign Up", destination: SignUpScreen())
                        .foregroundColor(.yugiOrange)
                        .fontWeight(.semibold)
                }
                .font(.system(size: 15))
                .padding(.top)
            }
        }
        .background(Color.yugiCream.ignoresSafeArea())
    }
}

#Preview("Auth Screen") {
    NavigationStack {
        AuthScreen()
    }
} 