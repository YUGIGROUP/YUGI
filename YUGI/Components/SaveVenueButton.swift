import SwiftUI
import UIKit

struct SaveVenueButton: View {
    @Binding var isSaved: Bool
    let onToggle: (_ targetSavedState: Bool) async -> Bool

    @State private var isProcessing = false

    var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 8) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 13, weight: .semibold))
                Text(isSaved ? "Saved" : "Save")
                    .font(.custom("Raleway-Regular", size: 14))
            }
            .foregroundColor(Color.yugiSoftBlack)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSaved ? Color.yugiSage : Color.yugiCloud)
            .overlay(
                Capsule()
                    .stroke(Color.yugiSage, lineWidth: isSaved ? 0 : 1.5)
            )
            .clipShape(Capsule())
            .opacity(isProcessing ? 0.75 : 1.0)
        }
        .disabled(isProcessing)
        .buttonStyle(.plain)
        .accessibilityLabel(isSaved ? "Saved venue" : "Save venue")
    }

    private func handleTap() {
        let previous = isSaved
        let target = !previous

        if target {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        isSaved = target
        isProcessing = true

        Task {
            let success = await onToggle(target)
            await MainActor.run {
                if !success {
                    isSaved = previous
                }
                isProcessing = false
            }
        }
    }
}

#Preview {
    StatefulPreviewWrapper(false) { value in
        SaveVenueButton(isSaved: value) { _ in true }
            .padding()
            .background(Color.yugiCloud)
    }
}

private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State var value: Value
    var content: (Binding<Value>) -> Content

    init(_ value: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: value)
        self.content = content
    }

    var body: some View {
        content($value)
    }
}
