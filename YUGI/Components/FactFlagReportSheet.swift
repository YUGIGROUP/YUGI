import SwiftUI

struct FactFlagReportSheet: View {
    let placeId: String
    let venueName: String
    let factPath: String
    let factDisplayName: String
    let currentValue: String?

    @Environment(\.dismiss) private var dismiss

    private struct ReportOption: Identifiable {
        let id: Int
        let label: String
        let reportType: String   // matches backend enum
        let requiresComment: Bool
    }

    private let options: [ReportOption] = [
        ReportOption(id: 1, label: "This isn't right", reportType: "never_existed", requiresComment: false),
        ReportOption(id: 2, label: "This used to be true but isn't anymore", reportType: "no_longer_true", requiresComment: false),
        ReportOption(id: 3, label: "It's broken or out of service", reportType: "broken", requiresComment: false),
        ReportOption(id: 4, label: "Wrong location", reportType: "wrong_location", requiresComment: false),
        ReportOption(id: 5, label: "It's only sometimes available", reportType: "other", requiresComment: true),
        ReportOption(id: 6, label: "Something else", reportType: "other", requiresComment: true),
    ]

    @State private var selectedOptionId: Int? = nil
    @State private var comment: String = ""
    @State private var isSubmitting: Bool = false
    @State private var submitErrorMessage: String? = nil

    private var selectedOption: ReportOption? {
        guard let id = selectedOptionId else { return nil }
        return options.first { $0.id == id }
    }

    private var canSubmit: Bool {
        guard let opt = selectedOption else { return false }
        if opt.requiresComment && comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if isSubmitting { return false }
        return true
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header — venue + fact context
                    VStack(alignment: .leading, spacing: 6) {
                        Text(venueName)
                            .font(.system(size: 14))
                            .foregroundColor(Color.yugiBodyText)
                        Text(factDisplayName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color.yugiSoftBlack)
                        if let current = currentValue, !current.isEmpty {
                            Text("Currently shown: \(current)")
                                .font(.system(size: 13))
                                .foregroundColor(Color.yugiBodyText)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.bottom, 4)

                    Text("This generation of mums helping the next.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color.yugiDeepSage)
                        .padding(.bottom, 6)

                    Text("What's wrong?")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color.yugiSoftBlack)

                    // Options as radio rows
                    VStack(spacing: 0) {
                        ForEach(options) { opt in
                            Button(action: { selectedOptionId = opt.id }) {
                                HStack(alignment: .center, spacing: 12) {
                                    Image(systemName: selectedOptionId == opt.id ? "largecircle.fill.circle" : "circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(selectedOptionId == opt.id ? Color.yugiMocha : Color.yugiBorder)
                                    Text(opt.label)
                                        .font(.system(size: 15))
                                        .foregroundColor(Color.yugiSoftBlack)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            if opt.id != options.last?.id {
                                Divider().background(Color.yugiBorder)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .background(Color.yugiOat.opacity(0.5))
                    .cornerRadius(10)

                    // Comment field
                    if let opt = selectedOption {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(opt.requiresComment ? "Tell us more (required)" : "Tell us more (optional)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.yugiSoftBlack)
                            TextEditor(text: $comment)
                                .frame(minHeight: 80)
                                .padding(8)
                                .background(Color.yugiCloud)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.yugiBorder, lineWidth: 1)
                                )
                                .cornerRadius(8)
                        }
                    }

                    if let err = submitErrorMessage {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(Color.yugiError)
                    }
                }
                .padding(20)
            }
            .background(Color.yugiCloud.ignoresSafeArea())
            .navigationTitle("Help us correct this")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color.yugiBodyText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: submit) {
                        if isSubmitting {
                            ProgressView().tint(Color.yugiMocha)
                        } else {
                            Text("Submit").bold()
                        }
                    }
                    .disabled(!canSubmit)
                    .foregroundColor(canSubmit ? Color.yugiMocha : Color.yugiBorder)
                }
            }
        }
    }

    private func submit() {
        guard let opt = selectedOption else { return }
        isSubmitting = true
        submitErrorMessage = nil

        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        let commentToSend: String? = trimmed.isEmpty ? nil : trimmed

        VenueEnrichmentService.shared.submitFactReport(
            placeId: placeId,
            venueName: venueName,
            factPath: factPath,
            reportType: opt.reportType,
            comment: commentToSend
        ) { success in
            isSubmitting = false
            if success {
                dismiss()
            } else {
                submitErrorMessage = "Couldn't submit just now. Please try again."
            }
        }
    }
}

#Preview {
    FactFlagReportSheet(
        placeId: "test",
        venueName: "Bentall Centre",
        factPath: "parking.blueBadgeBays",
        factDisplayName: "Blue Badge bays",
        currentValue: "45 Blue Badge bays"
    )
}
