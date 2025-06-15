import SwiftUI

struct WelcomeUserScreen: View {
    let userName: String
    @State private var isHelloVisible = false
    @State private var isNameVisible = false
    @State private var shouldNavigateToAI = false
    
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
                                    value: isHelloVisible
                                )
                        }
                    }
                }
                
                // Content
                VStack(spacing: 24) {
                    Text("Hello")
                        .font(.bellotaTextLight(size: 72))
                        .foregroundColor(.white)
                        .opacity(isHelloVisible ? 1 : 0)
                        .offset(y: isHelloVisible ? 0 : 20)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    Text(userName)
                        .font(.robotoThin(size: 50))
                        .foregroundColor(.white)
                        .opacity(isNameVisible ? 1 : 0)
                        .offset(y: isNameVisible ? 0 : 20)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 24)
            }
            .navigationDestination(isPresented: $shouldNavigateToAI) {
                AIInteractionScreen(userName: userName)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.8)) {
                    isHelloVisible = true
                }
                
                withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
                    isNameVisible = true
                }
                
                // Navigate to AI screen after animations
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    shouldNavigateToAI = true
                }
            }
        }
    }
}

#Preview {
    WelcomeUserScreen(userName: "Eva Parmar")
} 