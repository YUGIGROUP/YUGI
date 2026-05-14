import SwiftUI
import UIKit

struct VenueFeedbackScreen: View {
    let placeId: String
    let venueName: String

    @Environment(\.dismiss) private var dismiss

    @State private var currentCard: Int
    @State private var selectedFactPath = "pramAccess.stepFreeAccess"
    @State private var selectedFactQuestion = "Was it easy to get in with a pram?"
    @State private var selectedAgreement: Bool? = nil
    @State private var comments = ""
    @State private var didInitializeFactSelection = false

    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    @State private var hasSubmitted = false

    private let totalCards = 3

    private let factPool: [(path: String, question: String)] = [
        ("babyChanging.available", "Was baby changing available?"),
        ("pramAccess.stepFreeAccess", "Was it easy to get in with a pram?"),
        ("accessibility.accessibleRestroom", "Was the accessible restroom available?"),
        ("parking.costInfo", "Was the parking info accurate?")
    ]

    init(placeId: String, venueName: String, startAtCard: Int = 0) {
        self.placeId = placeId
        self.venueName = venueName
        _currentCard = State(initialValue: startAtCard)
    }

    var body: some View {
        ZStack {
            Color.yugiCloud.ignoresSafeArea()

            if hasSubmitted {
                thankYouView
                    .transition(.opacity)
            } else if currentCard == 0 {
                visitGateCard
            } else {
                VStack(spacing: 0) {
                    progressHeader
                    cardView
                        .id(currentCard)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
                .gesture(
                    DragGesture(minimumDistance: 40)
                        .onEnded { value in
                            if value.translation.width > 60, currentCard > 0 {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentCard -= 1
                                }
                            } else if value.translation.width < -60 {
                                advanceIfAnswered()
                            }
                        }
                )
            }
        }
        .animation(.easeInOut(duration: 0.35), value: currentCard)
        .animation(.easeInOut(duration: 0.35), value: hasSubmitted)
        .onAppear {
            guard !didInitializeFactSelection else { return }
            didInitializeFactSelection = true
            selectFactQuestionOnce()
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.custom("Raleway-Regular", size: 15))
                        .foregroundColor(Color.yugiBodyText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(currentCard + 1) of \(totalCards)")
                    .font(.custom("Raleway-SemiBold", size: 12))
                    .foregroundColor(Color.yugiBodyText)
                    .frame(maxWidth: .infinity, alignment: .center)

                Spacer()
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)

            HStack(spacing: 5) {
                ForEach(0..<totalCards, id: \.self) { i in
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

    private var visitGateCard: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.custom("Raleway-Regular", size: 15))
                        .foregroundColor(Color.yugiBodyText)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()

            VStack(spacing: 36) {
                Text("Did you make it to\n\(venueName)?")
                    .font(.custom("Raleway-SemiBold", size: 28))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.yugiSoftBlack)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
                    .padding(.horizontal, 28)

                VStack(spacing: 12) {
                    Button {
                        withAnimation { currentCard = 1 }
                    } label: {
                        Text("Yes, I went!")
                            .font(.custom("Raleway-SemiBold", size: 16))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(Color.yugiMocha)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .buttonStyle(.plain)

                    Button {
                        dismiss()
                    } label: {
                        Text("No, I didn't make it")
                            .font(.custom("Raleway-Regular", size: 16))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .foregroundColor(Color.yugiBodyText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
            }

            Spacer()
            Spacer()
        }
    }

    @ViewBuilder
    private var cardView: some View {
        switch currentCard {
        case 1:
            factQuestionCard
        case 2:
            commentsCard
        default:
            EmptyView()
        }
    }

    private var factQuestionCard: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 36) {
                Text(selectedFactQuestion)
                    .font(.custom("Raleway-SemiBold", size: 28))
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color.yugiSoftBlack)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(nil)
                    .padding(.horizontal, 28)

                VStack(spacing: 12) {
                    triButton("Yes", agreement: true)
                    triButton("No", agreement: false)
                    didntCheckButton
                }
                .padding(.horizontal, 24)
            }

            Spacer()
            Spacer()
        }
    }

    private func triButton(_ label: String, agreement: Bool) -> some View {
        let selected = selectedAgreement == agreement
        return Button {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            selectedAgreement = agreement
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    currentCard = 2
                }
            }
        } label: {
            Text(label)
                .font(.custom("Raleway-SemiBold", size: 16))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(selected ? Color.yugiMocha.opacity(0.10) : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(selected ? Color.yugiMocha : Color.yugiBorder, lineWidth: selected ? 2 : 1)
                )
                .foregroundColor(selected ? Color.yugiMocha : Color.yugiSoftBlack)
        }
        .buttonStyle(.plain)
    }

    private var didntCheckButton: some View {
        let selected = selectedAgreement == nil
        return Button {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            selectedAgreement = nil
            withAnimation {
                currentCard = 2
            }
        } label: {
            Text("Didn't check")
                .font(.custom("Raleway-SemiBold", size: 16))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(selected ? Color.yugiMocha.opacity(0.10) : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(selected ? Color.yugiMocha : Color.yugiBorder, lineWidth: selected ? 2 : 1)
                )
                .foregroundColor(selected ? Color.yugiMocha : Color.yugiSoftBlack)
        }
        .buttonStyle(.plain)
    }

    private var commentsCard: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                VStack(spacing: 6) {
                    Text("Anything else worth knowing?")
                        .font(.custom("Raleway-SemiBold", size: 28))
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color.yugiSoftBlack)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                    Text("Help the next mum trust YUGI. Share anything other parents might find useful.")
                        .font(.custom("Raleway-Regular", size: 15))
                        .foregroundColor(Color.yugiBodyText)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)

                ZStack(alignment: .topLeading) {
                    if comments.isEmpty {
                        Text("Optional")
                            .font(.custom("Raleway-Regular", size: 14))
                            .foregroundColor(Color(.placeholderText))
                            .padding(.top, 14)
                            .padding(.leading, 13)
                    }
                    TextEditor(text: $comments)
                        .frame(height: 130)
                        .padding(4)
                        .font(.custom("Raleway-Regular", size: 16))
                }
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yugiBorder, lineWidth: 1)
                )
                .cornerRadius(12)
                .padding(.horizontal, 24)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.custom("Raleway-Regular", size: 13))
                        .foregroundColor(Color.yugiError)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 8) {
                    Button {
                        Task {
                            await submitFeedback(sendComment: true)
                        }
                    } label: {
                        Group {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Text("Share feedback")
                                    .font(.custom("Raleway-SemiBold", size: 16))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Color.yugiMocha)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)

                    Button {
                        Task {
                            await submitFeedback(sendComment: false)
                        }
                    } label: {
                        Text("Skip")
                            .font(.custom("Raleway-Regular", size: 16))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .foregroundColor(Color.yugiBodyText)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)
                }
                .padding(.horizontal, 24)
            }

            Spacer()
        }
    }

    private var thankYouView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 68))
                .foregroundColor(.green)

            Text("Thanks — you've helped the next mum")
                .font(.custom("Raleway-SemiBold", size: 24))
                .multilineTextAlignment(.center)
                .foregroundColor(Color.yugiSoftBlack)
                .padding(.horizontal, 32)
        }
    }

    private func advanceIfAnswered() {
        switch currentCard {
        case 1:
            withAnimation { currentCard = 2 }
        default:
            break
        }
    }

    private func selectFactQuestionOnce() {
        let defaultFact = factPool.first { $0.path == "pramAccess.stepFreeAccess" } ?? factPool[1]
        selectedFactPath = defaultFact.path
        selectedFactQuestion = defaultFact.question

        VenueEnrichmentService.shared.fetchEnrichment(
            placeId: placeId,
            venueName: venueName
        ) { enrichment in
            guard let enrichment else { return }

            var claimedFactPaths = Set<String>()

            if let factSummary = enrichment.enrichedData.parentVerification?.factSummary {
                for key in factSummary.keys {
                    claimedFactPaths.insert(key)
                }
            }

            if enrichment.enrichedData.babyChanging?.available != nil {
                claimedFactPaths.insert("babyChanging.available")
            }
            if enrichment.enrichedData.pramAccess?.stepFreeAccess != nil {
                claimedFactPaths.insert("pramAccess.stepFreeAccess")
            }
            if let cost = enrichment.enrichedData.parking?.costInfo,
               !cost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                claimedFactPaths.insert("parking.costInfo")
            }

            let eligible = factPool.filter { claimedFactPaths.contains($0.path) }
            let chosen = eligible.randomElement() ?? defaultFact
            selectedFactPath = chosen.path
            selectedFactQuestion = chosen.question
        }
    }

    @MainActor
    private func submitFeedback(sendComment: Bool) async {
        guard !isSubmitting else { return }

        let trimmed = comments.trimmingCharacters(in: .whitespacesAndNewlines)
        let outgoingComment = sendComment && !trimmed.isEmpty ? trimmed : nil

        var facts: [VenueFactSubmission] = []
        if let selectedAgreement {
            facts.append(
                VenueFactSubmission(
                    factPath: selectedFactPath,
                    agreed: selectedAgreement,
                    comment: nil
                )
            )
        }

        // If parent skipped fact + left no comment, treat as frictionless done (no POST).
        if facts.isEmpty && outgoingComment == nil {
            dismiss()
            return
        }

        isSubmitting = true
        errorMessage = nil

        let success = await APIService.shared.submitVenueFeedback(
            placeId: placeId,
            venueName: venueName,
            facts: facts,
            overallComment: outgoingComment
        )

        isSubmitting = false

        if success {
            withAnimation {
                hasSubmitted = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                dismiss()
            }
        } else {
            errorMessage = "Couldn't submit right now. Please try again."
        }
    }
}

