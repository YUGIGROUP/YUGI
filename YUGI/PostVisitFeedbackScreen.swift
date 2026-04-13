//
//  PostVisitFeedbackScreen.swift
//  YUGI
//

import SwiftUI

// MARK: - Tri-state answer for accessibility questions

private enum TriAnswer: Equatable {
    case yes, no, didntCheck

    var boolValue: Bool? {
        switch self {
        case .yes:       return true
        case .no:        return false
        case .didntCheck: return nil
        }
    }
}

// MARK: - Main View

struct PostVisitFeedbackScreen: View {
    let bookingId: String
    let className: String

    @Environment(\.dismiss) private var dismiss

    // Card index: 0 = attendance gate, 1–5 = feedback carousel
    @State private var currentCard = 0

    // Answers
    @State private var babyChanging: TriAnswer? = nil
    @State private var pramAccess:   TriAnswer? = nil
    @State private var parking:      TriAnswer? = nil
    @State private var rating = 0
    @State private var comments = ""

    // Flow control
    @State private var showNotAttended = false
    @State private var isSubmitting    = false
    @State private var hasSubmitted    = false
    @State private var errorMessage: String? = nil

    private let totalCards = 5

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            if showNotAttended {
                notAttendedView
                    .transition(.opacity)
            } else if hasSubmitted {
                thankYouView
                    .transition(.opacity)
            } else if currentCard == 0 {
                attendanceCard
            } else {
                VStack(spacing: 0) {
                    progressHeader
                    feedbackCardView
                        .id(currentCard)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal:   .move(edge: .leading).combined(with: .opacity)
                        ))
                }
                .gesture(
                    DragGesture(minimumDistance: 40)
                        .onEnded { v in
                            // Swipe right = go back, swipe left = advance (when answer given)
                            if v.translation.width > 60, currentCard > 1 {
                                withAnimation(.easeInOut(duration: 0.3)) { currentCard -= 1 }
                            } else if v.translation.width < -60 {
                                advanceIfAnswered()
                            }
                        }
                )
            }
        }
        .animation(.easeInOut(duration: 0.35), value: currentCard)
        .animation(.easeInOut(duration: 0.35), value: showNotAttended)
        .animation(.easeInOut(duration: 0.35), value: hasSubmitted)
        .onDisappear {
            // If dismissed without submitting, mark as skipped so it won't reappear
            if !hasSubmitted {
                FeedbackCoordinator.shared.skipFeedback(bookingId: bookingId)
            }
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    FeedbackCoordinator.shared.skipFeedback(bookingId: bookingId)
                    dismiss()
                } label: {
                    Text("Not now")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("\(currentCard) of \(totalCards)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)

                Spacer()

                // Balance the "Not now" button so counter is centred
                Text("Not now")
                    .font(.subheadline)
                    .foregroundColor(.clear)
            }
            .padding(.horizontal, 20)

            // Progress dots
            HStack(spacing: 5) {
                ForEach(1...totalCards, id: \.self) { i in
                    Capsule()
                        .fill(i <= currentCard ? Color.yugiMocha : Color(.systemGray5))
                        .frame(width: i == currentCard ? 22 : 8, height: 6)
                        .animation(.spring(response: 0.3), value: currentCard)
                }
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Card 0: Attendance Gate

    private var attendanceCard: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    FeedbackCoordinator.shared.skipFeedback(bookingId: bookingId)
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            VStack(spacing: 36) {
                Text("Did you make it to\n\(className)?")
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                VStack(spacing: 12) {
                    Button {
                        withAnimation { currentCard = 1 }
                    } label: {
                        Text("Yes, I was there!")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(Color.yugiMocha)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }

                    Button {
                        withAnimation { showNotAttended = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            dismiss()
                        }
                    } label: {
                        Text("No, I couldn't make it")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Cards 1–5 Router

    @ViewBuilder
    private var feedbackCardView: some View {
        switch currentCard {
        case 1:
            triStateCard(
                question: "Help the next mum out —\nwas there baby changing?",
                binding: $babyChanging,
                onNext: { withAnimation { currentCard = 2 } }
            )
        case 2:
            triStateCard(
                question: "Was it easy to get in\nwith a pram?",
                binding: $pramAccess,
                onNext: { withAnimation { currentCard = 3 } }
            )
        case 3:
            triStateCard(
                question: "Was parking\nas described?",
                binding: $parking,
                onNext: { withAnimation { currentCard = 4 } }
            )
        case 4:
            ratingCard
        case 5:
            commentsCard
        default:
            EmptyView()
        }
    }

    // MARK: - Tri-state Card (cards 1–3)

        private func triStateCard(
            question: String,
            binding: Binding<TriAnswer?>,
            onNext: @escaping () -> Void
        ) -> some View {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 36) {
                    Text(question)
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)

                    VStack(spacing: 12) {
                        triButton("Yes",          answer: .yes,        binding: binding)
                        triButton("No",           answer: .no,         binding: binding)
                        triButton("Didn't check", answer: .didntCheck, binding: binding)
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()
                Spacer()
            }
        }

        private func triButton(_ label: String, answer: TriAnswer, binding: Binding<TriAnswer?>) -> some View {
            let selected = binding.wrappedValue == answer
            return Button {
                binding.wrappedValue = answer
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    advanceIfAnswered()
                }
            } label: {
                Text(label)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(selected ? Color.yugiMocha.opacity(0.10) : Color(.systemGray6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(selected ? Color.yugiMocha : Color.clear, lineWidth: 2)
                    )
                    .foregroundColor(selected ? Color.yugiMocha : .primary)
            }
        }
    // MARK: - Card 4: Star Rating

        private var ratingCard: some View {
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 40) {
                    Text("How would you rate it?")
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)

                    HStack(spacing: 14) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                rating = star
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    withAnimation { currentCard = 5 }
                                }
                            } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.system(size: 46))
                                    .foregroundColor(star <= rating ? Color.yugiMocha : Color(.systemGray4))
                            }
                        }
                    }
                }

                Spacer()
                Spacer()
            }
        }

    // MARK: - Card 5: Comments + Submit

    private var commentsCard: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    Text("Anything else mums\nshould know?")
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text("Optional")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 28)

                ZStack(alignment: .topLeading) {
                    if comments.isEmpty {
                        Text("e.g. The lift was out of order")
                            .foregroundColor(Color(.placeholderText))
                            .padding(EdgeInsets(top: 13, leading: 9, bottom: 0, trailing: 9))
                    }
                    TextEditor(text: $comments)
                        .frame(height: 110)
                        .padding(4)
                }
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 24)

                VStack(spacing: 6) {
                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button {
                        submitFeedback()
                    } label: {
                        Group {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Text("Submit")
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Color.yugiMocha)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .disabled(isSubmitting)
                    .padding(.horizontal, 24)
                }
            }

            Spacer()
        }
    }

    // MARK: - Not Attended Screen

    private var notAttendedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundColor(Color.yugiMocha)

            Text("No worries!")
                .font(.title2.weight(.bold))

            Text("We hope you make it next time")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Thank You Screen

    private var thankYouView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 68))
                .foregroundColor(.green)

            Text("Thanks!")
                .font(.title.weight(.bold))

            Text("You're helping mums find the best outings")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Helpers

    /// Advance to the next card only if the current question has been answered.
    private func advanceIfAnswered() {
        switch currentCard {
        case 1 where babyChanging != nil: withAnimation { currentCard = 2 }
        case 2 where pramAccess   != nil: withAnimation { currentCard = 3 }
        case 3 where parking      != nil: withAnimation { currentCard = 4 }
        case 4 where rating       > 0:    withAnimation { currentCard = 5 }
        default: break
        }
    }

    // MARK: - Submission

    private func submitFeedback() {
        isSubmitting = true
        errorMessage = nil

        var body: [String: Any] = [
            "bookingId": bookingId,
            "attended":  true,
        ]

        if let v = babyChanging { body["babyChangingAccurate"] = v.boolValue as Any }
        if let v = pramAccess   { body["pramAccessAccurate"]   = v.boolValue as Any }
        if let v = parking      { body["parkingAccurate"]      = v.boolValue as Any }
        if rating > 0           { body["rating"] = rating }

        let trimmed = comments.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { body["comments"] = trimmed }

        guard let url = URL(string: "https://yugi-production.up.railway.app/api/feedback") else { return }
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            errorMessage = "Please log in to submit feedback."
            isSubmitting = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json",  forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)",   forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                self.isSubmitting = false

                if error != nil {
                    self.errorMessage = "Something went wrong. Please try again."
                    return
                }

                guard let http = response as? HTTPURLResponse else { return }

                if http.statusCode == 201 || http.statusCode == 409 {
                    EventTracker.shared.trackFeedbackSubmitted(
                        bookingId: self.bookingId,
                        attended:  true,
                        rating:    self.rating > 0 ? self.rating : nil
                    )
                    withAnimation { self.hasSubmitted = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.dismiss()
                    }
                } else {
                    self.errorMessage = "Failed to submit. Please try again."
                }
            }
        }.resume()
    }
}
