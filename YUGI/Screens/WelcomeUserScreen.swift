import SwiftUI

struct WelcomeUserScreen: View {
    let userName: String
    @Environment(\.dismiss) private var dismiss
    @State private var shouldNavigateToTermsAgreement = false
    
    // Animation states for welcome message
    @State private var welcomeOpacity: Double = 0
    @State private var welcomeOffset: CGFloat = 50
    
    // Extract first name from full name
    private var firstName: String {
        let components = userName.components(separatedBy: " ")
        return components.first ?? userName
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background Image - TRUE FULL SCREEN (contains all text)
                Image("welcome-background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                // Centered Welcome Message - Moved Higher
                VStack(spacing: 8) {
                    Text("Welcome")
                        .font(.system(size: 64, weight: .light, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(firstName)
                        .font(.system(size: 72, weight: .light, design: .rounded))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                }
                .opacity(welcomeOpacity)
                .offset(y: welcomeOffset)
                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.35) // Moved higher
            }
        }
        .ignoresSafeArea(.all, edges: .all)
        .fullScreenCover(isPresented: $shouldNavigateToTermsAgreement) {
            TermsAgreementScreen(parentName: userName)
        }
        .onAppear {
            // Beautiful fade-in animation for welcome message
            withAnimation(.easeOut(duration: 1.2).delay(0.3)) {
                welcomeOpacity = 1
                welcomeOffset = 0
            }
            
            // Navigate to Terms Agreement screen after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                shouldNavigateToTermsAgreement = true
            }
        }
    }
}

#Preview {
    WelcomeUserScreen(userName: "Eva Parmar")
}
