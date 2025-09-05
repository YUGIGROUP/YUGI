import SwiftUI

struct ForgotPasswordScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var apiService = APIService.shared
    
    @State private var email = ""
    @State private var isLoading = false
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Text("Reset Password")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.yugiGray)
                    
                    Text("Enter your email address and we'll send you a link to reset your password")
                        .font(.system(size: 17))
                        .foregroundColor(.yugiGray.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 48)
                
                // Email Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email Address")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.yugiGray)
                    
                    YUGITextField(
                        text: $email,
                        placeholder: "Enter your email address",
                        icon: "envelope.fill",
                        keyboardType: .emailAddress
                    )
                }
                .padding(.horizontal)
                
                // Send Reset Link Button
                Button(action: sendResetLink) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 18))
                        }
                        
                        Text(isLoading ? "Sending..." : "Send Reset Link")
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
                .disabled(isLoading || email.isEmpty)
                
                // Back to Sign In
                Button("Back to Sign In") {
                    dismiss()
                }
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "#BC6C5C"))
                .fontWeight(.medium)
                .padding(.top, 16)
            }
        }
        .background(Color.yugiCream.ignoresSafeArea())
        .navigationBarHidden(true)
        .alert("Success", isPresented: $showingSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text(successMessage)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Helper Methods
    
    private func sendResetLink() {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email address"
            showingError = true
            return
        }
        
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address"
            showingError = true
            return
        }
        
        isLoading = true
        
        apiService.forgotPassword(email: email)
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
                    successMessage = "Password reset link sent! Please check your email and follow the instructions to reset your password."
                    showingSuccess = true
                }
            )
            .store(in: &apiService.cancellables)
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordScreen()
    }
}
