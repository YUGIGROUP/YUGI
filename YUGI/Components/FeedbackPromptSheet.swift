import SwiftUI
import UIKit

struct FeedbackPromptSheet: View {
    let prompt: PendingPrompt
    let onShareFeedback: () -> Void

    @Environment(\.dismiss) private var dismiss
    private let apiService = APIService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How was \(prompt.venueName)?")
                .font(.custom("Raleway-SemiBold", size: 22))
                .foregroundColor(Color.yugiSoftBlack)

            Text("30 seconds of feedback helps the next mum trust YUGI.")
                .font(.custom("Raleway-Regular", size: 15))
                .foregroundColor(Color.yugiBodyText)

            VStack(spacing: 12) {
                Button {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()

                    Task {
                        _ = await apiService.markPromptShown(placeId: prompt.placeId)
                        onShareFeedback()
                        dismiss()
                    }
                } label: {
                    Text("Share feedback")
                        .font(.custom("Raleway-SemiBold", size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.yugiMocha)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        _ = await apiService.markPromptShown(placeId: prompt.placeId)
                        dismiss()
                    }
                } label: {
                    Text("Maybe later")
                        .font(.custom("Raleway-Regular", size: 16))
                        .foregroundColor(Color.yugiSoftBlack.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.yugiCloud)
        .presentationDetents([.medium])
    }
}
