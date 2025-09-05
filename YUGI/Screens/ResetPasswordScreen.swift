import SwiftUI

struct ResetPasswordScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiService = APIService.shared
    
    let resetToken: String
    
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isShowingPassword = false
    @State private var isShowingConfirmPassword = false
    @State private var isLoading = false
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var shouldNavigateToAuth = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Text("Set New Password")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.yugiGray)
                    
                    Text("Enter your new password below")
                        .font(.system(size: 17))
                        .foregroundColor(.yugiGray.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 48)
                
                // Password Fields
                VStack(spacing: 20) {
                    // New Password
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New Password")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        HStack {
                            if isShowingPassword {
                                YUGITextField(
                                    text: $newPassword,
                                    placeholder: "Enter your new password",
                                    icon: "lock.fill"
                                )
                            } else {
                                YUGISecureField(
                                    placeholder: "Enter your new password",
                                    text: $newPassword
                                )
                            }
                            
                            Button(action: {
                                isShowingPassword.toggle()
                            }) {
                                Image(systemName: isShowingPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(.yugiGray.opacity(0.6))
                            }
                        }
                    }
                    
                    // Confirm Password
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        HStack {
                            if isShowingConfirmPassword {
                                YUGITextField(
                                    text: $confirmPassword,
                                    placeholder: "Confirm your new password",
                                    icon: "lock.fill"
                                )
                            } else {
                                YUGISecureField(
                                    placeholder: "Confirm your new password",
                                    text: $confirmPassword
                                )
                            }
                            
                            Button(action: {
                                isShowingConfirmPassword.toggle()
                            }) {
                                Image(systemName: isShowingConfirmPassword ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(.yugiGray.opacity(0.6))
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Password Requirements
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password Requirements:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.yugiGray)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        PasswordRequirementRow(
                            text: "At least 8 characters",
                            isMet: newPassword.count >= 8
                        )
                        PasswordRequirementRow(
                            text: "Contains a number",
                            isMet: newPassword.rangeOfCharacter(from: .decimalDigits) != nil
                        )
                        PasswordRequirementRow(
                            text: "Contains a letter",
                            isMet: newPassword.rangeOfCharacter(from: .letters) != nil
                        )
                    }
                }
                .padding(.horizontal)
                
                // Reset Password Button
                Button(action: resetPassword) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                        }
                        
                        Text(isLoading ? "Resetting..." : "Reset Password")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
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
                .padding(.horizontal)
                .disabled(isLoading || !isPasswordValid || !isPasswordConfirmed)
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
        }
        .alert("Success", isPresented: $showingSuccess) {
            Button("OK") {
                shouldNavigateToAuth = true
            }
        } message: {
            Text("Your password has been reset successfully! You can now sign in with your new password.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $shouldNavigateToAuth) {
            AuthScreen()
        }
    }
    
    // MARK: - Computed Properties
    
    private var isPasswordValid: Bool {
        return newPassword.count >= 8 &&
               newPassword.rangeOfCharacter(from: .decimalDigits) != nil &&
               newPassword.rangeOfCharacter(from: .letters) != nil
    }
    
    private var isPasswordConfirmed: Bool {
        return !confirmPassword.isEmpty && newPassword == confirmPassword
    }
    
    // MARK: - Helper Methods
    
    private func resetPassword() {
        guard isPasswordValid else {
            errorMessage = "Please ensure your password meets all requirements"
            showingError = true
            return
        }
        
        guard isPasswordConfirmed else {
            errorMessage = "Passwords do not match"
            showingError = true
            return
        }
        
        isLoading = true
        
        apiService.resetPassword(token: resetToken, newPassword: newPassword)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case let .failure(error) = completion {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                },
                receiveValue: { response in
                    showingSuccess = true
                }
            )
            .store(in: &apiService.cancellables)
    }
}

// MARK: - Password Requirement Row

struct PasswordRequirementRow: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundColor(isMet ? .green : .yugiGray.opacity(0.5))
            
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(isMet ? .yugiGray : .yugiGray.opacity(0.6))
        }
    }
}

#Preview {
    NavigationStack {
        ResetPasswordScreen(resetToken: "sample-token")
    }
}
