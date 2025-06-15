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
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(style == .primary ? Color("Primary") : Color.white.opacity(0.2))
                .foregroundColor(.white)
                .cornerRadius(10)
        }
    }
}

#Preview("YUGI Buttons") {
    ZStack {
        Color.yugiOrange
            .ignoresSafeArea()
        
        VStack(spacing: 20) {
            YUGIButton(title: "Primary Button", action: {})
            YUGIButton(title: "Secondary Button", style: .secondary, action: {})
        }
        .padding()
    }
} 