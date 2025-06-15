import SwiftUI

struct WelcomeScreen: View {
    @State private var isLogoVisible = false
    @State private var isTextVisible = false
    @State private var isButtonVisible = false
    @State private var shouldNavigate = false
    @State private var buttonOffset: CGFloat = UIScreen.main.bounds.width
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.yugiOrange
                    .ignoresSafeArea()
                
                // Animated background elements
                GeometryReader { geometry in
                    ZStack {
                        ForEach(0..<5) { index in
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: CGFloat.random(in: 100...200))
                                .position(
                                    x: CGFloat.random(in: 0...geometry.size.width),
                                    y: CGFloat.random(in: 0...geometry.size.height)
                                )
                                .animation(
                                    Animation.easeInOut(duration: Double.random(in: 2...4))
                                        .repeatForever(autoreverses: true)
                                        .delay(Double.random(in: 0...2)),
                                    value: isLogoVisible
                                )
                        }
                    }
                }
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Logo
                    Image("yugi-logo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .opacity(isLogoVisible ? 1 : 0)
                        .scaleEffect(isLogoVisible ? 1 : 0.5)
                    
                    // Welcome Text
                    VStack(spacing: 16) {
                        Text("Welcome")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Discover and book amazing classes\nfor you and your little ones")
                            .font(.system(size: 17))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                    }
                    .opacity(isTextVisible ? 1 : 0)
                    .offset(y: isTextVisible ? 0 : 20)
                    
                    Spacer()
                    
                    // Get Started Button
                    YUGIButton(
                        title: "Get Started",
                       
                        
                        action: {
                            shouldNavigate = true
                        }
                    )
                    .opacity(isButtonVisible ? 1 : 0)
                    .offset(x: isButtonVisible ? 0 : buttonOffset)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
            .navigationDestination(isPresented: $shouldNavigate) {
                AuthScreen()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isLogoVisible = true
            }
            
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                isTextVisible = true
            }
            
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.6)) {
                isButtonVisible = true
            }
        }
    }
}

#Preview("Welcome Flow") {
    WelcomeScreen()
} 
