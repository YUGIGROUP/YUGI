import SwiftUI

/// Compact one-line doability row for the redesigned search result card.
/// Shows a deep-sage verdict badge and a chevron, and toggles the shared
/// `isExpanded` state (whole row and badge share one tap target).
struct DoabilityRow: View {
    let doability: DoabilityInfo
    @Binding var isExpanded: Bool

    /// Deep sage badge colour from the approved mockup (not in the theme palette).
    private let badgeColor = Color(hex: "8B9E82")

    /// Verdict label — mirrors the score→label mapping in `DoabilityBadge`
    /// (ClassDiscoveryView.swift) without reusing it, so the mockup's sage
    /// styling isn't overridden by that component's green/orange/red colours.
    private var verdict: String {
        switch doability.score {
        case 80...100: return "Easy outing"
        case 60..<80: return "Doable"
        default: return "Plan ahead"
        }
    }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            // Badge centred in the full row width; chevron overlaid at the trailing
            // edge so it doesn't shift the badge off-centre.
            Text(verdict)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(badgeColor)
                .clipShape(Capsule())
                .frame(maxWidth: .infinity)
                .overlay(alignment: .trailing) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.yugiGray.opacity(0.7))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.yugiSage)
                .cornerRadius(12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Doability: \(verdict). \(doability.reasons.first ?? "")")
        .accessibilityHint(isExpanded ? "Collapse details" : "Expand details")
    }
}
