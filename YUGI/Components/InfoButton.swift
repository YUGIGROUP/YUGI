import SwiftUI

struct InfoButton: View {
    let title: String
    let message: String
    @State private var showInfo = false
    
    var body: some View {
        Button(action: {
            showInfo = true
        }) {
            Image(systemName: "info.circle")
                .font(.system(size: 16))
                .foregroundColor(.yugiGray)
        }
        .alert(title, isPresented: $showInfo) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text(message)
        }
    }
}

struct InfoButtonWithSheet: View {
    let title: String
    let message: String
    @State private var showInfo = false
    
    var body: some View {
        Button(action: {
            showInfo = true
        }) {
            Image(systemName: "info.circle")
                .font(.system(size: 16))
                .foregroundColor(.yugiGray)
        }
        .sheet(isPresented: $showInfo) {
            InfoSheetView(title: title, message: message)
        }
    }
}

struct InfoSheetView: View {
    let title: String
    let message: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding(20)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            Text("Siblings")
            InfoButton(
                title: "Sibling Tickets",
                message: "Sibling tickets allow 2 children to attend for the price of 1. Perfect for families with multiple children who want to participate together."
            )
        }
        
        HStack {
            Text("Individual Tickets")
            InfoButtonWithSheet(
                title: "Individual Tickets",
                message: "Individual tickets are for single children. Each child needs their own ticket to attend the class."
            )
        }
    }
    .padding()
}
