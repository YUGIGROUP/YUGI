//
//  PostVisitFeedbackScreen.swift
//  YUGI
//

import SwiftUI

struct PostVisitFeedbackScreen: View {
    let bookingId: String
    let className: String

    @Environment(\.dismiss) private var dismiss

    @State private var attended: Bool? = nil
    @State private var rating: Int = 0
    @State private var babyChangingAccurate: Bool? = nil
    @State private var pramAccessAccurate: Bool? = nil
    @State private var parkingAccurate: Bool? = nil
    @State private var comments: String = ""
    @State private var isSubmitting = false
    @State private var isSubmitted = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                if isSubmitted {
                    submittedView
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            attendedSection

                            if attended == true {
                                ratingSection
                                accessibilitySection
                                commentsSection
                                submitButton
                            } else if attended == false {
                                didNotAttendSection
                                commentsSection
                                submitButton
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("How was it?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") {
                        EventTracker.shared.trackFeedbackSkipped(bookingId: bookingId)
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Sections

    private var attendedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Did you attend \(className)?")
                .font(.headline)

            HStack(spacing: 12) {
                attendanceButton(label: "Yes", value: true)
                attendanceButton(label: "No", value: false)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func attendanceButton(label: String, value: Bool) -> some View {
        Button {
            attended = value
        } label: {
            Text(label)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(attended == value ? Color.accentColor : Color(.tertiarySystemFill))
                .foregroundColor(attended == value ? .white : .primary)
                .cornerRadius(10)
        }
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How was it?")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        rating = star
                    } label: {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundColor(star <= rating ? .yellow : .secondary)
                    }
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var accessibilitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Was it as described?")
                .font(.headline)

            accuracyRow(
                label: "Baby changing available",
                icon: "figure.and.child.holdinghands",
                value: $babyChangingAccurate
            )
            Divider()
            accuracyRow(
                label: "Pram access",
                icon: "figure.roll",
                value: $pramAccessAccurate
            )
            Divider()
            accuracyRow(
                label: "Parking",
                icon: "car.fill",
                value: $parkingAccurate
            )
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func accuracyRow(label: String, icon: String, value: Binding<Bool?>) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
            Spacer()
            HStack(spacing: 8) {
                triStateButton(label: "Yes", target: true,  binding: value)
                triStateButton(label: "No",  target: false, binding: value)
                triStateButton(label: "N/A", target: nil,   binding: value)
            }
        }
    }

    private func triStateButton(label: String, target: Bool?, binding: Binding<Bool?>) -> some View {
        let isSelected = binding.wrappedValue == target
        return Button {
            binding.wrappedValue = target
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
    }

    private var didNotAttendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sorry to hear that!")
                .font(.headline)
            Text("Would you like to tell us why? (optional)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Anything else? (optional)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextEditor(text: $comments)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color(.tertiarySystemFill))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var submitButton: some View {
        VStack(spacing: 8) {
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
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isSubmitting || attended == nil)
        }
    }

    private var submittedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)

            Text("Thanks for your feedback!")
                .font(.title2.weight(.semibold))

            Text("Your input helps other parents find the best classes.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Done") { dismiss() }
                .padding(.top, 8)
        }
        .padding()
    }

    // MARK: - Submission

    private func submitFeedback() {
        guard let attended = attended else { return }
        isSubmitting = true
        errorMessage = nil

        var body: [String: Any] = [
            "bookingId": bookingId,
            "attended":  attended,
        ]
        if attended {
            if rating > 0 { body["rating"] = rating }
            if let v = babyChangingAccurate { body["babyChangingAccurate"] = v }
            if let v = pramAccessAccurate   { body["pramAccessAccurate"] = v }
            if let v = parkingAccurate      { body["parkingAccurate"] = v }
        }
        if !comments.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["comments"] = comments
        }

        guard let url = URL(string: "https://yugi-production.up.railway.app/api/feedback") else { return }
        guard let authToken = UserDefaults.standard.string(forKey: "authToken") else {
            errorMessage = "Please log in to submit feedback."
            isSubmitting = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [self] _, response, error in
            DispatchQueue.main.async {
                self.isSubmitting = false
                if let error = error {
                    self.errorMessage = "Something went wrong. Please try again."
                    print("Feedback submission error: \(error.localizedDescription)")
                    return
                }
                guard let http = response as? HTTPURLResponse else { return }
                if http.statusCode == 201 || http.statusCode == 409 {
                    EventTracker.shared.trackFeedbackSubmitted(
                        bookingId: self.bookingId,
                        attended: attended,
                        rating: self.rating > 0 ? self.rating : nil
                    )
                    self.isSubmitted = true
                } else {
                    self.errorMessage = "Failed to submit. Please try again."
                }
            }
        }.resume()
    }
}
