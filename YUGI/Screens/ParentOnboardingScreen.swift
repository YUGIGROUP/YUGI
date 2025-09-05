import SwiftUI

struct ParentOnboardingScreen: View {
    let parentName: String
    @State private var showingParentDashboard = false
    @State private var bubbleAnimation = false
    @State private var animateOptions = [false]
    @State private var animateHeader = false
    @State private var animateWelcomeText = false

    var body: some View {
        ZStack {
            // Background gradient with new color
            LinearGradient(gradient: Gradient(colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.85)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            // Subtle techy overlays
            GeometryReader { geometry in
                ZStack {
                    // Bubble 1 - Top left to bottom right
                    Circle()
                        .fill(Color.white.opacity(0.07))
                        .frame(width: 120, height: 120)
                        .blur(radius: 1.5)
                        .offset(x: bubbleAnimation ? geometry.size.width * 0.3 : -geometry.size.width * 0.2, 
                                y: bubbleAnimation ? geometry.size.height * 0.8 : -geometry.size.height * 0.1)
                        .animation(Animation.easeInOut(duration: 8).repeatForever(autoreverses: true), value: bubbleAnimation)
                    
                    // Bubble 2 - Top right to bottom left
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 160, height: 160)
                        .blur(radius: 1.5)
                        .offset(x: bubbleAnimation ? -geometry.size.width * 0.3 : geometry.size.width * 0.2, 
                                y: bubbleAnimation ? geometry.size.height * 0.7 : -geometry.size.height * 0.15)
                        .animation(Animation.easeInOut(duration: 10).repeatForever(autoreverses: true).delay(2), value: bubbleAnimation)
                    
                    // Bubble 3 - Center to edges
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 200, height: 200)
                        .blur(radius: 1.5)
                        .offset(x: bubbleAnimation ? geometry.size.width * 0.4 : -geometry.size.width * 0.4, 
                                y: bubbleAnimation ? -geometry.size.height * 0.2 : geometry.size.height * 0.6)
                        .animation(Animation.easeInOut(duration: 12).repeatForever(autoreverses: true).delay(1), value: bubbleAnimation)
                    
                    // Bubble 4 - Bottom to top
                    Circle()
                        .fill(Color.white.opacity(0.04))
                        .frame(width: 140, height: 140)
                        .blur(radius: 1.5)
                        .offset(x: bubbleAnimation ? geometry.size.width * 0.25 : -geometry.size.width * 0.25, 
                                y: bubbleAnimation ? -geometry.size.height * 0.3 : geometry.size.height * 0.9)
                        .animation(Animation.easeInOut(duration: 9).repeatForever(autoreverses: true).delay(3), value: bubbleAnimation)
                    
                    // Bubble 5 - Diagonal movement
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 180, height: 180)
                        .blur(radius: 1.5)
                        .offset(x: bubbleAnimation ? -geometry.size.width * 0.35 : geometry.size.width * 0.35, 
                                y: bubbleAnimation ? geometry.size.height * 0.5 : -geometry.size.height * 0.4)
                        .animation(Animation.easeInOut(duration: 11).repeatForever(autoreverses: true).delay(1.5), value: bubbleAnimation)
                    
                    // Bubble 6 - Small floating bubble
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 100, height: 100)
                        .blur(radius: 1.5)
                        .offset(x: bubbleAnimation ? geometry.size.width * 0.15 : -geometry.size.width * 0.15, 
                                y: bubbleAnimation ? -geometry.size.height * 0.1 : geometry.size.height * 0.8)
                        .animation(Animation.easeInOut(duration: 7).repeatForever(autoreverses: true).delay(0.5), value: bubbleAnimation)
                }
            }
            
            VStack(spacing: 0) {
                headerSection
                
                VStack(spacing: 24) {
                    welcomeSection
                    optionsSection
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        
        .fullScreenCover(isPresented: $showingParentDashboard) {
            ParentDashboardScreen(parentName: parentName, initialTab: 0)
        }
        .onAppear {
            // Start bubble animation
            bubbleAnimation = true
            
            // Cascade-down animation for header
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                    animateHeader = true
                }
            }
            
            // Cascade-down animation for welcome text
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                    animateWelcomeText = true
                }
            }
            
            // Slide-in animation for the option card
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                    animateOptions[0] = true
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text("Welcome to YUGI")
                .font(.bellotaTextLight(size: 42))
                .foregroundColor(.white)
                .offset(y: animateHeader ? 0 : -50)
                .opacity(animateHeader ? 1 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.8), value: animateHeader)
        }
        .padding(.top, 60)
        .padding(.bottom, 36)
    }
    
    private var welcomeSection: some View {
        VStack(spacing: 10) {
            Text("Your account is ready. Finish your account setup to browse and book classes.")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .offset(y: animateWelcomeText ? 0 : -30)
                .opacity(animateWelcomeText ? 1 : 0)
                .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: animateWelcomeText)
        }
    }
    
    private var optionsSection: some View {
        VStack(spacing: 24) {
            OnboardingOptionCard(
                icon: "",
                title: "Finish Account Setup",
                subtitle: "Add your children and complete your profile",
                description: "",
                color: .white,
                chevronColor: .white,
                glass: true,
                offsetX: animateOptions[0] ? 0 : -UIScreen.main.bounds.width,
                delay: 0.1,
                action: {
                    showingParentDashboard = true
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.top, -60)
    }
}

// MARK: - Supporting Views

struct OnboardingOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let description: String
    let color: Color
    let chevronColor: Color
    let glass: Bool
    let offsetX: CGFloat
    let delay: Double
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    if !icon.isEmpty {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 56, height: 56)
                            Image(systemName: icon)
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                }
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .lineSpacing(2)
            }
            .padding(20)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .offset(x: offsetX)
            .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(delay), value: offsetX)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Glassmorphism BlurView
struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

#Preview {
    ParentOnboardingScreen(parentName: "Sarah Johnson")
} 