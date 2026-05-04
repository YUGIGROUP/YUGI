import SwiftUI

struct FactFlagButton: View {
    let placeId: String
    let venueName: String
    let factPath: String           // e.g. "parking.blueBadgeBays"
    let factDisplayName: String    // human-readable, e.g. "Blue Badge bays"
    let currentValue: String?      // optional: a short summary of what the venue card currently claims, e.g. "45 Blue Badge bays". Shown in the report sheet so the parent knows what they're correcting. Pass nil to omit.

    @State private var showReportSheet = false

    var body: some View {
        Button(action: { showReportSheet = true }) {
            Image(systemName: "pencil")
                .font(.system(size: 14))
                .foregroundColor(Color.yugiBodyText)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Help us correct this")
        .sheet(isPresented: $showReportSheet) {
            FactFlagReportSheet(
                placeId: placeId,
                venueName: venueName,
                factPath: factPath,
                factDisplayName: factDisplayName,
                currentValue: currentValue
            )
        }
    }
}

#Preview {
    HStack {
        Text("Blue Badge bays")
        FactFlagButton(
            placeId: "test",
            venueName: "Bentall Centre",
            factPath: "parking.blueBadgeBays",
            factDisplayName: "Blue Badge bays",
            currentValue: "45 Blue Badge bays"
        )
    }
    .padding()
}
