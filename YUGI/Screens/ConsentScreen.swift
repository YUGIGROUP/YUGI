import SwiftUI

struct ConsentScreen: View {
    let onDismiss: () -> Void
    @State private var showingPrivacyPolicy = false

    var body: some View {
        ZStack {
            Color.yugiCream.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Accent bar
                    LinearGradient(
                        colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 6)

                    VStack(spacing: 32) {
                        // Icon + title
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "#BC6C5C").opacity(0.1))
                                    .frame(width: 96, height: 96)
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(Color(hex: "#BC6C5C"))
                            }
                            .padding(.top, 40)

                            Text("Help us improve YUGI for you")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.yugiGray)
                                .multilineTextAlignment(.center)
                        }

                        // Explanation
                        Text("YUGI can learn from how you use the app to give you better recommendations. This includes which classes you view, what you search for, and your general area when browsing. This data stays within YUGI and is never shared with third parties or advertisers.")
                            .font(.system(size: 16))
                            .foregroundColor(.yugiGray.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 8)

                        // What we use
                        VStack(alignment: .leading, spacing: 14) {
                            ConsentTrackingItem(icon: "eye.fill",         text: "Classes and providers you view")
                            ConsentTrackingItem(icon: "magnifyingglass",  text: "What you search for")
                            ConsentTrackingItem(icon: "location.fill",    text: "Your general area when browsing")
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)

                        // Buttons — equal size and equal visual weight (no dark patterns)
                        VStack(spacing: 12) {
                            Button(action: {
                                ConsentManager.shared.grantConsent()
                                onDismiss()
                            }) {
                                Text("Yes, personalise my experience")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        LinearGradient(
                                            colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.85)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: {
                                ConsentManager.shared.revokeConsent()
                                onDismiss()
                            }) {
                                Text("No thanks")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(Color(hex: "#BC6C5C"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(hex: "#BC6C5C"), lineWidth: 1.5)
                                    )
                                    .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        // Privacy policy link
                        Button(action: { showingPrivacyPolicy = true }) {
                            Text("Read our full Privacy Policy")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                                .underline()
                        }
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .sheet(isPresented: $showingPrivacyPolicy) {
            TermsPrivacyScreen()
        }
    }
}

private struct ConsentTrackingItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "#BC6C5C"))
                .frame(width: 22)
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.yugiGray)
            Spacer()
        }
    }
}
