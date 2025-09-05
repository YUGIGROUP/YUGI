import SwiftUI

enum YUGIButtonStyle {
    case primary
    case secondary
}

struct YUGIButton: View {
    let title: String
    let style: YUGIButtonStyle
    let action: () -> Void
    
    init(title: String, style: YUGIButtonStyle = .primary, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Group {
                        if style == .primary {
                            // Transparent background with elegant border
                            Color.clear
                        } else {
                            // Transparent background for secondary style too
                            Color.clear
                        }
                    }
                )
                .foregroundColor(.white)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            style == .primary ? 
                            Color.white.opacity(0.3) : 
                            Color.white.opacity(0.3),
                            lineWidth: 1.5
                        )
                )
                .shadow(
                    color: style == .primary ? 
                    Color.black.opacity(0.1) : 
                    Color.black.opacity(0.1),
                    radius: 6,
                    x: 0,
                    y: 3
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview("YUGI Buttons") {
    ZStack {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: "#FFF5E9"),
                Color(hex: "#E8E5DB")
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack(spacing: 24) {
            YUGIButton(title: "Get Started", action: {})
            YUGIButton(title: "Learn More", style: .secondary, action: {})
        }
        .padding(.horizontal, 32)
    }
} 