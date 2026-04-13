import SwiftUI
import Combine

struct IntakeResponsesScreen: View {
    let classId: String
    let className: String

    @State private var responses: [IntakeResponseData] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.yugiCream.ignoresSafeArea()

                Group {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.2)
                    } else if let error = errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 36))
                                .foregroundColor(Color.yugiGray.opacity(0.4))
                            Text(error)
                                .font(.system(size: 15))
                                .foregroundColor(Color.yugiGray.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    } else if responses.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "list.clipboard")
                                .font(.system(size: 48))
                                .foregroundColor(Color.yugiGray.opacity(0.3))
                            Text("No responses yet")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(Color.yugiGray.opacity(0.6))
                            Text("Responses will appear here once parents submit the intake form after booking.")
                                .font(.system(size: 13))
                                .foregroundColor(Color.yugiGray.opacity(0.45))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(responses, id: \.id) { response in
                                    ResponseCard(response: response)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Intake Responses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.yugiMocha, for: .navigationBar)
            .onAppear { Task { await loadResponses() } }
        }
    }

    @MainActor
    private func loadResponses() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await APIService.shared
                .fetchIntakeResponses(classId: classId)
                .async()
            responses = result.data ?? []
        } catch {
            errorMessage = "Could not load responses. Please try again."
        }
    }
}

// MARK: - Response Card

private struct ResponseCard: View {
    let response: IntakeResponseData
    @State private var isExpanded = false

    private var displayName: String {
        response.parentId.fullName ?? response.parentId.email ?? "Parent"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color.yugiGray)
                        Text("\(response.answers.count) answer\(response.answers.count == 1 ? "" : "s")")
                            .font(.system(size: 12))
                            .foregroundColor(Color.yugiGray.opacity(0.55))
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.yugiGray.opacity(0.4))
                }
                .padding()
            }
            .buttonStyle(.plain)

            // Answers
            if isExpanded {
                Divider().padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(response.answers, id: \.questionText) { answer in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(answer.questionText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.yugiGray.opacity(0.75))
                            Text(answer.answer.isEmpty ? "—" : answer.answer)
                                .font(.system(size: 14))
                                .foregroundColor(Color.yugiGray)
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}
