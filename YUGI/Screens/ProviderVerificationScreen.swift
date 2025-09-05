import SwiftUI

struct ProviderVerificationScreen: View {
    let businessName: String
    @State private var isAnimating = false
    @State private var shouldNavigateToDashboard = false
    
    var body: some View {
        ZStack {
                // Background
                Color(hex: "#BC6C5C")
                    .ignoresSafeArea()
                
                // Animated background elements
                GeometryReader { geometry in
                    ZStack {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: CGFloat.random(in: 80...150))
                                .position(
                                    x: CGFloat.random(in: 0...geometry.size.width),
                                    y: CGFloat.random(in: 0...geometry.size.height)
                                )
                                .animation(
                                    Animation.easeInOut(duration: Double.random(in: 3...5))
                                        .repeatForever(autoreverses: true)
                                        .delay(Double.random(in: 0...2)),
                                    value: isAnimating
                                )
                        }
                    }
                }
                
                // Content
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer(minLength: 60)
                        
                        // Success Icon
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                                .scaleEffect(isAnimating ? 1.1 : 1.0)
                                .animation(
                                    Animation.easeInOut(duration: 1.5)
                                        .repeatForever(autoreverses: true),
                                    value: isAnimating
                                )
                        }
                        
                        // Main Content
                        VStack(spacing: 24) {
                            Text("Application Submitted!")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            VStack(spacing: 16) {
                                Text("Thank you for applying to join YUGI, \(businessName)!")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                Text("We're excited to have you on board and are currently reviewing your application.")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.center)
                            }
                            
                            // Verification Steps
                            VStack(alignment: .leading, spacing: 16) {
                                Text("What happens next?")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    VerificationStep(
                                        icon: "doc.text.magnifyingglass",
                                        title: "Document Review",
                                        description: "We'll verify your qualifications and DBS certificate"
                                    )
                                    
                                    VerificationStep(
                                        icon: "clock.badge.checkmark",
                                        title: "Background Check",
                                        description: "Standard safety checks for children's activities"
                                    )
                                    
                                    VerificationStep(
                                        icon: "envelope.badge",
                                        title: "Email Notification",
                                        description: "You'll receive an email once verified (2-3 business days)"
                                    )
                                    
                                    VerificationStep(
                                        icon: "doc.text",
                                        title: "Terms & Conditions",
                                        description: "Sign YUGI's Terms & Conditions (found in your dashboard)"
                                    )
                                }
                            }
                            .padding(20)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(16)
                        }
                        
                        Spacer(minLength: 40)
                        
                        // Action Buttons
                        VStack(spacing: 16) {
                            YUGIButton(
                                title: "Go to Dashboard",
                                style: .secondary,
                                action: {
                                    shouldNavigateToDashboard = true
                                }
                            )
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                }
            .fullScreenCover(isPresented: $shouldNavigateToDashboard) {
                ProviderDashboardScreen(businessName: businessName)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8)) {
                    isAnimating = true
                }
            }
        }
    }
}

struct VerificationStep: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
        }
    }
}

#Preview {
    ProviderVerificationScreen(businessName: "Little Musicians")
} 