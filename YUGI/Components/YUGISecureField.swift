import SwiftUI

struct YUGISecureField: View {
    let placeholder: String
    @Binding var text: String
    @State private var isSecured = true
    
    var body: some View {
        HStack {
            if isSecured {
                SecureField(placeholder, text: $text)
                    .foregroundColor(Color.yugiGray)
            } else {
                TextField(placeholder, text: $text)
                    .foregroundColor(Color.yugiGray)
            }
            
            Button(action: {
                isSecured.toggle()
            }) {
                Image(systemName: isSecured ? "eye.fill" : "eye.slash.fill")
                    .foregroundColor(Color.yugiMocha)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
    }
} 