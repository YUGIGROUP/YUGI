import SwiftUI

struct YUGITextEditor: View {
    let placeholder: String
    @Binding var text: String
    let minHeight: CGFloat
    let maxCharacters: Int?
    
    init(placeholder: String, text: Binding<String>, minHeight: CGFloat, maxCharacters: Int? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.minHeight = minHeight
        self.maxCharacters = maxCharacters
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: Binding(
                get: { text },
                set: { newValue in
                    if let maxChars = maxCharacters {
                        text = String(newValue.prefix(maxChars))
                    } else {
                        text = newValue
                    }
                }
            ))
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
        .background(Color.white)
        .cornerRadius(10)
    }
} 