import SwiftUI

struct WelcomeScreen: View {
    @State private var isButtonVisible = false
    @State private var shouldNavigate = false
    @State private var buttonOffset: CGFloat = UIScreen.main.bounds.width
    
    // Animation states for cascade effect
    @State private var yOffset: CGFloat = -200
    @State private var letterOpacity: [Double] = [0, 0, 0, 0]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background Image - TRUE FULL SCREEN (contains logo and text)
                Image("welcome-background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                // Overlay for better button readability (optional)
                Color.black.opacity(0.2)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                // Vertical YUGI Text on Left Side - Individual positioning with cascade animation
                Text("Y")
                    .font(.custom("Futura", size: 120))
                    .foregroundColor(Color(hex: "#E8E5DB"))
                    .position(x: 80, y: geometry.size.height * 0.15)
                    .offset(y: yOffset)
                    .opacity(letterOpacity[0])
                
                Text("U")
                    .font(.custom("Futura", size: 120))
                    .foregroundColor(Color(hex: "#E8E5DB"))
                    .position(x: 80, y: geometry.size.height * 0.35)
                    .offset(y: yOffset)
                    .opacity(letterOpacity[1])
                
                Text("G")
                    .font(.custom("Futura", size: 120))
                    .foregroundColor(Color(hex: "#E8E5DB"))
                    .position(x: 80, y: geometry.size.height * 0.55)
                    .offset(y: yOffset)
                    .opacity(letterOpacity[2])
                
                Text("I")
                    .font(.custom("Futura", size: 120))
                    .foregroundColor(Color(hex: "#E8E5DB"))
                    .position(x: 80, y: geometry.size.height * 0.75)
                    .offset(y: yOffset)
                    .opacity(letterOpacity[3])
                
                // Only the Get Started Button
                VStack {
                    Spacer()
                    
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
        }
        .ignoresSafeArea(.all, edges: .all)
        .navigationDestination(isPresented: $shouldNavigate) {
            AuthScreen()
        }
        .onAppear {
            // Cascade animation for letters
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.2)) {
                yOffset = 0
                letterOpacity[0] = 1
            }
            
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.4)) {
                letterOpacity[1] = 1
            }
            
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.6)) {
                letterOpacity[2] = 1
            }
            
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.8)) {
                letterOpacity[3] = 1
            }
            
            // Button animation after letters finish
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(1.2)) {
                isButtonVisible = true
            }
        }
    }
}

#Preview("Welcome Flow") {
    WelcomeScreen()
} 
