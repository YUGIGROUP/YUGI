import SwiftUI

struct YUGITextField: View {
    let placeholder: String
    let icon: String?
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    
    init(text: Binding<String>, placeholder: String, icon: String? = nil, keyboardType: UIKeyboardType = .default) {
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.keyboardType = keyboardType
    }
    
    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(Color(hex: "#BC6C5C"))
                    .frame(width: 24)
            }
            
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .foregroundColor(.yugiGray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
    }
} 