import SwiftUI

struct YUGITextEditor: View {
    let placeholder: String
    @Binding var text: String
    let minHeight: CGFloat
    
    init(placeholder: String, text: Binding<String>, minHeight: CGFloat) {
        self.placeholder = placeholder
        self._text = text
        self.minHeight = minHeight
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .frame(minHeight: minHeight)
                .padding(6)
            
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .allowsHitTesting(false)
            }
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)
    }
} 