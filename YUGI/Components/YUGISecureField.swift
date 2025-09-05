import SwiftUI

struct YUGISecureField: View {
    let placeholder: String
    @Binding var text: String
    @State private var isSecured = true
    
    var body: some View {
        HStack {
            if isSecured {
                SecureField(placeholder, text: $text)
                    .foregroundColor(.yugiGray)
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(.yugiGray)
            }
            
            Button(action: {
                isSecured.toggle()
            }) {
                Image(systemName: isSecured ? "eye.fill" : "eye.slash.fill")
                    .foregroundColor(Color(hex: "#BC6C5C"))
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
    }
} 