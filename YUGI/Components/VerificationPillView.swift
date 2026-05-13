import SwiftUI

struct VerificationPillView: View {
    let tier: String?
    let verificationStatus: String?

    @State private var showingSheet = false

    private var pillConfig: (label: String, bg: Color, fg: Color)? {
        guard verificationStatus == "verified" else { return nil }
        switch tier {
        case "community":
            return ("Community event", Color(hex: "#E8DDD5"), Color(hex: "#7A5C4A"))
        case "drop_off":
            return ("DBS verified", Color(hex: "#8B9E82"), Color(hex: "#1e3318"))
        default:
            return ("Verified provider", Color(hex: "#B7C4B1"), Color(hex: "#3A5A34"))
        }
    }

    private var explainerText: String? {
        guard verificationStatus == "verified" else { return nil }
        switch tier {
        case "community":
            return "This is a parent-organised meet-up. The host is a fellow parent, not a verified service provider. Parents are responsible for their own children at all times."
        case "drop_off":
            return "This provider has completed YUGI's strictest verification: an Enhanced DBS check with Children's Barred List, public liability insurance, qualifications, and Ofsted registration where required by law."
        default:
            return "This provider has been verified by YUGI. We've reviewed their public liability insurance before allowing them to list. Some providers also upload qualifications or DBS — when they do, you'll see a stronger badge."
        }
    }

    var body: some View {
        if let config = pillConfig {
            Button {
                showingSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .semibold))
                    Text(config.label)
                        .font(.custom("Raleway-Medium", size: 11))
                }
                .foregroundColor(config.fg)
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(config.bg)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingSheet) {
                if let text = explainerText {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            Text(text)
                                .font(.custom("Raleway-Regular", size: 15))
                                .foregroundColor(Color(hex: "#3A3836"))
                                .fixedSize(horizontal: false, vertical: true)

                            Button("Done") {
                                showingSheet = false
                            }
                            .font(.custom("Raleway-Medium", size: 16))
                            .foregroundColor(Color.yugiMocha)
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color.white)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                }
            }
        }
    }
}
