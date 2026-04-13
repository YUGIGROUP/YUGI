import SwiftUI

struct AIClassGeneratorScreen: View {
    let businessName: String
    let onGenerated: (ClassCreationData) -> Void
    let onSkip: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var aiPrompt = ""
    @State private var isGenerating = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.yugiCream.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 32) {
                            // Header
                            VStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 48))
                                    .foregroundColor(.yugiMocha)

                                Text("Create your listing")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.yugiGray)

                                Text("Describe your class and we'll create your listing for you")
                                    .font(.system(size: 16))
                                    .foregroundColor(.yugiGray.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 40)
                            .padding(.horizontal)

                            // Input area
                            VStack(alignment: .leading, spacing: 12) {
                                TextField(
                                    "e.g. Baby sensory, Polka Theatre Wimbledon, Tuesdays 10am, £15, ages 0-12 months",
                                    text: $aiPrompt,
                                    axis: .vertical
                                )
                                .lineLimit(6, reservesSpace: true)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(.yugiMocha.opacity(0.35), lineWidth: 1.5)
                                )
                                .font(.system(size: 15))

                                if let error = errorMessage {
                                    Text(error)
                                        .font(.system(size: 13))
                                        .foregroundColor(.red.opacity(0.8))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 24)
                    }

                    // Bottom buttons
                    VStack(spacing: 12) {
                        Button {
                            Task { await generate() }
                        } label: {
                            HStack(spacing: 8) {
                                if isGenerating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.9)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(isGenerating ? "Generating..." : "Generate with AI")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                aiPrompt.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? .yugiMocha.opacity(0.4)
                                    : .yugiMocha
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(aiPrompt.trimmingCharacters(in: .whitespaces).isEmpty || isGenerating)

                        Button {
                            onSkip()
                        } label: {
                            Text("Skip and create listing manually")
                                .font(.system(size: 14))
                                .foregroundColor(.yugiGray.opacity(0.55))
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
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.yugiGray.opacity(0.6))
                    }
                }
            }
        }
    }

    @MainActor
    private func generate() async {
        let trimmed = aiPrompt.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        errorMessage = nil
        isGenerating = true
        defer { isGenerating = false }

        do {
            // Step 1: AI generates class details from the prompt
            let result = try await APIService.shared.generateClassListing(prompt: trimmed)
            var data = ClassCreationData()
            data.className = result.className
            data.description = result.description
            data.ageRange = result.ageRange
            data.price = result.price
            data.isFree = result.isFree
            data.duration = result.duration
            data.whatToBring = result.whatToBring
            data.specialRequirements = result.specialRequirements
            data.venueName = result.venueName ?? ""
            data.city = result.city ?? ""
            data.postalCode = result.postalCode ?? ""
            data.streetAddress = result.streetAddress ?? ""
            if let matched = ClassCategory(aiString: result.category) {
                data.category = matched
            }

            // Step 2: If AI returned a venue name, look it up via Google Places
            let venueName = data.venueName
            let locationHint = [data.city, data.postalCode]
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
            if !venueName.isEmpty {
                if let venueData = try? await APIService.shared
                    .fetchVenueAnalysis(venueName: venueName, location: locationHint.isEmpty ? venueName : locationHint)
                    .async() {
                    let addr = venueData.data.address
                    if !addr.street.isEmpty { data.streetAddress = addr.street }
                    if !addr.postalCode.isEmpty { data.postalCode = addr.postalCode }
                    if !addr.city.isEmpty { data.city = addr.city }
                    if let coords = venueData.data.coordinates {
                        data.latitude = coords.latitude
                        data.longitude = coords.longitude
                    }
                    if !venueData.data.venueName.isEmpty { data.venueName = venueData.data.venueName }
                }
            }

            onGenerated(data)
        } catch {
            errorMessage = "Could not generate listing. Please check your connection and try again."
        }
    }
}
