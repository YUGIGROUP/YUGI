import SwiftUI
import Combine

// MARK: - ViewModel

class ContactFormViewModel: ObservableObject {
    @Published var message      = ""
    @Published var isSubmitting = false
    @Published var showingSuccess = false
    @Published var error: String?
    @Published var showingError = false

    private let supportService = SupportService.shared
    private var cancellables   = Set<AnyCancellable>()

    func submitForm() {
        isSubmitting = true
        error        = nil

        supportService.sendMessage(message)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self else { return }
                    self.isSubmitting = false
                    if case let .failure(err) = completion {
                        self.error        = err.localizedDescription
                        self.showingError = true
                    }
                },
                receiveValue: { [weak self] response in
                    guard let self else { return }
                    if response.success {
                        self.showingSuccess = true
                    } else {
                        self.error        = response.message
                        self.showingError = true
                    }
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - View

struct ContactFormScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ContactFormViewModel()

    private var canSend: Bool {
        !viewModel.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 4) {
                    Text("Contact Support")
                        .font(.custom("Raleway-SemiBold", size: 22))
                        .foregroundColor(.white)

                    Text("Send us a message and we'll get back to you as soon as possible")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)
                .padding(.bottom, 20)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(Color.yugiMocha)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 0,
                                                  bottomTrailingRadius: 0, topTrailingRadius: 16))

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Message field
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Message")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color.yugiGray)

                            TextField("Please provide details about your issue...",
                                      text: $viewModel.message, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(5...10)
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        }

                        // Send button
                        Button(action: { viewModel.submitForm() }) {
                            HStack(spacing: 10) {
                                if viewModel.isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 17))
                                }
                                Text(viewModel.isSubmitting ? "Sending..." : "Send Message")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.yugiMocha)
                            .cornerRadius(12)
                        }
                        .disabled(viewModel.isSubmitting || !canSend)
                        .opacity(canSend ? 1.0 : 0.5)
                    }
                    .padding(20)
                }
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarHidden(true)
            .alert("Message Sent", isPresented: $viewModel.showingSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("We'll get back to you as soon as possible.")
            }
            .alert("Couldn't Send Message", isPresented: $viewModel.showingError) {
                Button("OK") { viewModel.showingError = false }
            } message: {
                if let error = viewModel.error {
                    Text(error)
                }
            }
        }
    }
}

#Preview {
    ContactFormScreen()
}
