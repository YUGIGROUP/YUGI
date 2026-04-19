import SwiftUI
import Combine

// MARK: - ViewModel

class ContactFormViewModel: ObservableObject {
    @Published var message        = ""
    @Published var isSubmitting   = false
    @Published var showingSuccess = false
    @Published var error: String?
    @Published var showingError   = false

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

    @State private var showHeader  = false
    @State private var showHeading = false
    @State private var showBox     = false
    @State private var showButton  = false

    private var canSend: Bool {
        !viewModel.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color.yugiMocha.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                // MARK: Nav header
                HStack(spacing: 6) {
                    Button(action: { dismiss() }) {
                        Text("‹")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                    }
                    Text("Contact support")
                        .font(.custom("Raleway-Medium", size: 18))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .opacity(showHeader ? 1 : 0)
                .offset(y: showHeader ? 0 : 12)
                .animation(.easeOut(duration: 0.6), value: showHeader)

                // MARK: Heading
                Text("We're here\nto help")
                    .font(.custom("Raleway-Medium", size: 26))
                    .foregroundColor(.white)
                    .lineSpacing(-2)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .opacity(showHeading ? 1 : 0)
                    .offset(y: showHeading ? 0 : 12)
                    .animation(.easeOut(duration: 0.6), value: showHeading)

                // MARK: Message box
                ZStack(alignment: .topLeading) {
                    if viewModel.message.isEmpty {
                        Text("Tell us what's on your mind and we'll get back to you.")
                            .font(.custom("Raleway-Regular", size: 15))
                            .foregroundColor(.white.opacity(0.55))
                            .lineSpacing(9)
                            .padding(22)
                    }
                    TextEditor(text: $viewModel.message)
                        .font(.custom("Raleway-Regular", size: 15))
                        .foregroundColor(.white)
                        .lineSpacing(9)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .padding(16)
                }
                .frame(minHeight: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .opacity(showBox ? 1 : 0)
                .offset(y: showBox ? 0 : 12)
                .animation(.easeOut(duration: 0.6), value: showBox)

                Spacer()

                // MARK: Send button
                Button(action: { viewModel.submitForm() }) {
                    Group {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.yugiMocha))
                        } else {
                            Text("Send message")
                                .font(.custom("Raleway-Medium", size: 15))
                                .foregroundColor(Color.yugiMocha)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                .disabled(viewModel.isSubmitting || !canSend)
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .opacity(showButton ? (canSend ? 1.0 : 0.5) : 0)
                .offset(y: showButton ? 0 : 12)
                .animation(.easeOut(duration: 0.6), value: showButton)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { showHeader  = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { showHeading = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { showBox     = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) { showButton  = true }
        }
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

#Preview {
    ContactFormScreen()
}
