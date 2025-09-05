import SwiftUI

struct HelpSupportScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingContactForm = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Help & Support")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Get in touch with our support team")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.8)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Email Support Section
                        emailSupportSection
                    }
                    .padding(20)
                }
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbarBackground(.hidden, for: .navigationBar)

            .sheet(isPresented: $showingContactForm) {
                ContactFormScreen()
            }
        }
    }
    
    private var emailSupportSection: some View {
        VStack(spacing: 20) {
            // Support Icon
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#BC6C5C").opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                }
                
                VStack(spacing: 8) {
                    Text("Email Support")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.yugiGray)
                    
                    Text("Send us a message and we'll get back to you within 24 hours")
                        .font(.system(size: 16))
                        .foregroundColor(.yugiGray.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
            
            // Contact Form Button
            Button(action: {
                showingContactForm = true
            }) {
                HStack {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 18))
                    
                    Text("Send us a message")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
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
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#BC6C5C"), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    HelpSupportScreen()
} 