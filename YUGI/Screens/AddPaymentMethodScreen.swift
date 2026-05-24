import SwiftUI
import StripePaymentSheet
import StripePayments

/// Lets a parent add a card. Card collection is handled entirely by
/// Stripe's PaymentSheet (a native UI provided by the Stripe iOS SDK).
/// YUGI never sees the card number, CVV, or any sensitive card data —
/// Stripe tokenises everything and attaches the saved payment method
/// to the parent's Stripe Customer record.
struct AddPaymentMethodScreen: View {
    @Environment(\.dismiss) private var dismiss

    // PaymentSheet lifecycle (StripePaymentSheet — not YUGI's booking PaymentSheet view)
    @State private var stripePaymentSheet: StripePaymentSheet.PaymentSheet?
    @State private var isPreparingSheet = false
    @State private var isPresentingSheet = false
    @State private var setupErrorMessage: String?
    @State private var successMessage: String?

    // Animation
    @State private var showHeader = false
    @State private var showBody = false
    @State private var showAction = false

    /// Called once a card has been successfully saved to Stripe. The
    /// caller is expected to refresh its payment methods list via
    /// SharedPaymentService.shared.fetchPaymentMethods().
    let onPaymentMethodAdded: () -> Void

    var body: some View {
        ZStack {
            Color.yugiCloud.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Header
                HStack(spacing: 6) {
                    Button(action: { dismiss() }) {
                        Text("‹")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                    }
                    Text("Add a card")
                        .font(.custom("Raleway-Medium", size: 18))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(Color.yugiMocha.ignoresSafeArea(edges: .top))
                .opacity(showHeader ? 1 : 0)
                .offset(y: showHeader ? 0 : 12)
                .animation(.easeOut(duration: 0.6), value: showHeader)

                // MARK: Body
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.yugiOat)
                                    .frame(width: 72, height: 72)
                                Image(systemName: "creditcard")
                                    .font(.system(size: 30, weight: .light))
                                    .foregroundColor(Color.yugiMocha)
                            }
                            Text("Save a card for faster bookings")
                                .font(.custom("Raleway-Medium", size: 18))
                                .foregroundColor(Color.yugiSoftBlack)
                                .multilineTextAlignment(.center)
                            Text("Your card will be saved securely by Stripe so you can book classes without typing it in every time.")
                                .font(.custom("Raleway-Regular", size: 14))
                                .foregroundColor(Color.yugiBodyText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                        .padding(.top, 48)

                        if let errorMessage = setupErrorMessage {
                            errorBanner(errorMessage)
                                .padding(.horizontal, 20)
                        }

                        if let successMessage = successMessage {
                            successBanner(successMessage)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 16)
                }
                .opacity(showBody ? 1 : 0)
                .offset(y: showBody ? 0 : 12)
                .animation(.easeOut(duration: 0.6), value: showBody)

                // MARK: Sticky action area
                VStack(spacing: 10) {
                    Button(action: presentPaymentSheet) {
                        Group {
                            if isPreparingSheet {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Add card")
                                    .font(.custom("Raleway-Medium", size: 15))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.yugiMocha)
                        .clipShape(Capsule())
                    }
                    .disabled(isPreparingSheet)

                    Text("Cards are processed and stored securely by Stripe. YUGI never sees your card details.")
                        .font(.custom("Raleway-Regular", size: 11))
                        .foregroundColor(Color.yugiBodyText)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .opacity(showAction ? 1 : 0)
                .offset(y: showAction ? 0 : 12)
                .animation(.easeOut(duration: 0.6), value: showAction)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .paymentSheet(
            isPresented: $isPresentingSheet,
            paymentSheet: stripePaymentSheet ?? StripePaymentSheet.PaymentSheet(
                paymentIntentClientSecret: "",
                configuration: .init()
            ),
            onCompletion: handlePaymentSheetCompletion
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { showHeader = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) { showBody   = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { showAction = true }
        }
    }

    // MARK: - Banners

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color.yugiMocha)
            Text(message)
                .font(.custom("Raleway-Regular", size: 13))
                .foregroundColor(Color.yugiSoftBlack)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.yugiMocha.opacity(0.3), lineWidth: 1))
        .cornerRadius(10)
    }

    private func successBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(message)
                .font(.custom("Raleway-Regular", size: 13))
                .foregroundColor(Color.yugiSoftBlack)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.3), lineWidth: 1))
        .cornerRadius(10)
    }

    // MARK: - PaymentSheet flow

    /// Fetches a SetupIntent client secret from the backend, builds a
    /// PaymentSheet, and presents it. PaymentSheet is the Stripe-provided
    /// secure card collection UI.
    private func presentPaymentSheet() {
        guard !isPreparingSheet else { return }
        isPreparingSheet = true
        setupErrorMessage = nil
        successMessage = nil

        Task {
            do {
                // Fetch SetupIntent and ephemeral key in parallel — they're
                // independent calls and both required before we can build PaymentSheet.
                async let setupTask = fetchSetupIntent()
                async let keyTask = fetchEphemeralKey()
                let setup = try await setupTask
                let key = try await keyTask

                var configuration = StripePaymentSheet.PaymentSheet.Configuration()
                configuration.merchantDisplayName = "YUGI"
                configuration.customer = .init(
                    id: key.customerId,
                    ephemeralKeySecret: key.ephemeralKey
                )
                configuration.allowsDelayedPaymentMethods = false
                configuration.returnURL = "yugi://stripe-return"

                let sheet = StripePaymentSheet.PaymentSheet(
                    setupIntentClientSecret: setup.clientSecret,
                    configuration: configuration
                )

                await MainActor.run {
                    self.stripePaymentSheet = sheet
                    self.isPreparingSheet = false
                    self.isPresentingSheet = true
                }
            } catch {
                await MainActor.run {
                    self.isPreparingSheet = false
                    self.setupErrorMessage = "Couldn't start card setup. \(error.localizedDescription)"
                }
            }
        }
    }

    private func handlePaymentSheetCompletion(_ result: StripePaymentSheet.PaymentSheetResult) {
        switch result {
        case .completed:
            successMessage = "Card saved. You can now use it at checkout."
            onPaymentMethodAdded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                dismiss()
            }
        case .canceled:
            // User backed out of PaymentSheet — not an error, just no-op
            break
        case .failed(let error):
            setupErrorMessage = "Couldn't save your card. \(error.localizedDescription)"
        }
    }

    // MARK: - Backend

    private struct SetupIntentResponse: Decodable {
        let clientSecret: String
        let customerId: String
    }

    private func fetchSetupIntent() async throws -> SetupIntentResponse {
        guard let url = URL(string: "\(APIConfig.baseURL)/parent-payments/setup-intent") else {
            throw URLError(.badURL)
        }
        guard let token = APIService.shared.authToken else {
            throw URLError(.userAuthenticationRequired)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(SetupIntentResponse.self, from: data)
    }

    private struct EphemeralKeyResponse: Decodable {
        let ephemeralKey: String
        let customerId: String
    }

    /// Fetches a short-lived Stripe ephemeral key for the parent's Stripe
    /// Customer. Required by PaymentSheet so it can attach newly saved
    /// cards to the customer record (rather than creating orphaned ones).
    /// The ephemeral key must match the Stripe API version the iOS SDK
    /// is built against — we read that off the SDK at call time.
    private func fetchEphemeralKey() async throws -> EphemeralKeyResponse {
        guard let url = URL(string: "\(APIConfig.baseURL)/parent-payments/ephemeral-key") else {
            throw URLError(.badURL)
        }
        guard let token = APIService.shared.authToken else {
            throw URLError(.userAuthenticationRequired)
        }

        let body = ["stripeVersion": STPAPIClient.apiVersion]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(EphemeralKeyResponse.self, from: data)
    }
}

#Preview {
    AddPaymentMethodScreen { }
}
