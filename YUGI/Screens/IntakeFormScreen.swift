import SwiftUI
import Combine

struct IntakeFormScreen: View {
    let classItem: Class
    let bookingId: String
    let onCompleted: () -> Void
    let onSkip: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var answers: [String: String] = [:]
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    @State private var showingSuccess = false

    private var questions: [IntakeQuestion] {
        classItem.intakeQuestions ?? []
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.yugiCream.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header
                            VStack(spacing: 8) {
                                Image(systemName: "list.clipboard.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(Color(hex: "#BC6C5C"))
                                Text("A few quick questions")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.yugiGray)
                                Text("\(classItem.name) — \(classItem.providerName ?? "Your provider") needs a bit more info")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray.opacity(0.65))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 24)
                            .padding(.horizontal)

                            // Questions
                            ForEach(questions) { question in
                                QuestionCard(
                                    question: question,
                                    answer: Binding(
                                        get: { answers[question.id] ?? "" },
                                        set: { answers[question.id] = $0 }
                                    )
                                )
                                .padding(.horizontal)
                            }

                            if let error = errorMessage {
                                Text(error)
                                    .font(.system(size: 13))
                                    .foregroundColor(.red.opacity(0.8))
                                    .padding(.horizontal)
                            }

                            Spacer(minLength: 24)
                        }
                    }

                    // Bottom buttons
                    VStack(spacing: 10) {
                        Button {
                            Task { await submit() }
                        } label: {
                            HStack(spacing: 8) {
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.9)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                }
                                Text(isSubmitting ? "Submitting..." : "Submit answers")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(canSubmit ? Color(hex: "#BC6C5C") : Color(hex: "#BC6C5C").opacity(0.4))
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(!canSubmit || isSubmitting)

                        Button {
                            onSkip()
                        } label: {
                            Text("Skip for now")
                                .font(.system(size: 14))
                                .foregroundColor(.yugiGray.opacity(0.5))
                        }
                        .padding(.bottom, 8)
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .background(Color.yugiCream)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { onSkip() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.yugiGray.opacity(0.6))
                    }
                }
            }
        }
    }

    private var canSubmit: Bool {
        for question in questions where question.isRequired {
            let ans = answers[question.id]?.trimmingCharacters(in: .whitespaces) ?? ""
            if ans.isEmpty { return false }
        }
        return true
    }

    @MainActor
    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        let payload: [[String: String]] = questions.map { q in
            [
                "questionText": q.questionText,
                "answerType": q.answerType.rawValue,
                "answer": answers[q.id]?.trimmingCharacters(in: .whitespaces) ?? ""
            ]
        }

        do {
            _ = try await APIService.shared
                .submitIntakeResponse(bookingId: bookingId, classId: classItem.id, answers: payload)
                .async()
            onCompleted()
        } catch {
            errorMessage = "Could not submit. Please check your connection and try again."
        }
    }
}

// MARK: - Question Card

private struct QuestionCard: View {
    let question: IntakeQuestion
    @Binding var answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 4) {
                Text(question.questionText)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.yugiGray)
                if question.isRequired {
                    Text("*")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                }
            }

            switch question.answerType {
            case .freeText:
                TextField("Your answer", text: $answer, axis: .vertical)
                    .lineLimit(3, reservesSpace: false)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1))
                    .font(.system(size: 14))

            case .multipleChoice:
                VStack(spacing: 8) {
                    ForEach(question.options, id: \.self) { option in
                        Button {
                            answer = option
                        } label: {
                            HStack {
                                Image(systemName: answer == option ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(answer == option ? Color(hex: "#BC6C5C") : .yugiGray.opacity(0.4))
                                Text(option)
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray)
                                Spacer()
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        answer == option ? Color(hex: "#BC6C5C") : Color(hex: "#BC6C5C").opacity(0.2),
                                        lineWidth: answer == option ? 1.5 : 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.6))
        .cornerRadius(14)
    }
}
