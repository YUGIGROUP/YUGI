import SwiftUI

struct StatusRow: View {
    let icon: String
    let title: String
    let status: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.body)
            
            Spacer()
            
            Text(status)
                .font(.body)
                .foregroundColor(color)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        StatusRow(
            icon: "location.fill",
            title: "Location Services",
            status: "Enabled",
            color: .green
        )
        
        StatusRow(
            icon: "checkmark.shield.fill",
            title: "Permission Status",
            status: "When In Use",
            color: .orange
        )
    }
    .padding()
}
