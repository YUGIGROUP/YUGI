import SwiftUI
import Combine
import AuthenticationServices
import BetterSafariView

struct StripeConnectOnboardingScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = StripeConnectService.shared

    @State private var status: StripeConnectStatus?
    @State private var isLoadingStatus = true
    @State private var isLaunchingOnboarding = false
    @State private var errorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()

    // BetterSafariView drives the web auth session via this URL state.
    // When non-nil, the modifier launches the auth flow with this URL.
    @State private var authURL: URL?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.yugiCream.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        headerBar
                        contentCard
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                            .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .onAppear(perform: loadStatus)
            // BetterSafariView's web auth modifier — properly handles SwiftUI sheets.
            .webAuthenticationSession(item: $authURL) { url in
                WebAuthenticationSession(
                    url: url,
                    callbackURLScheme: "yugi"
                ) { callbackURL, error in
                    handleAuthCompletion(callbackURL: callbackURL, error: error)
                }
                .prefersEphemeralWebBrowserSession(false)
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Set up payouts")
                    .font(.custom("Raleway-Regular", size: 28))
                    .foregroundColor(.white)

                Text("Connect your bank so parents can book you")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .background(Color.yugiMocha)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentCard: some View {
        if isLoadingStatus {
            loadingCard
        } else if let status = status {
            switch status {
            case .notStarted:
                explainerCard(
                    title: "Get ready to receive payouts",
                    body: "YUGI uses Stripe to send money from parent bookings straight to your bank account. Setup takes about 5 minutes — you'll just need your bank details and some ID.",
                    buttonLabel: "Set up with Stripe"
                )
            case .inProgress:
                explainerCard(
                    title: "Finish your Stripe setup",
                    body: "You started setting up payouts but didn't finish. Pick up where you left off — it only takes a few more minutes.",
                    buttonLabel: "Continue setup"
                )
            case .restricted:
                explainerCard(
                    title: "Payouts on hold",
                    body: "Stripe needs a bit more information before you can receive payouts. Tap below to review what's outstanding.",
                    buttonLabel: "Review requirements"
                )
            case .active:
                successCard
            }
        } else if let errorMessage = errorMessage {
            errorCard(message: errorMessage)
        }
    }

    private var loadingCard: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .yugiMocha))
            Text("Checking your setup…")
                .font(.system(size: 14))
                .foregroundColor(.yugiSoftBlack.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(cardBackground)
    }

    private func explainerCard(title: String, body: String, buttonLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.yugiMocha.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.yugiMocha)
                }
                Text(title)
                    .font(.custom("Raleway-SemiBold", size: 20))
                    .foregroundColor(.yugiSoftBlack)
            }

            Text(body)
                .font(.system(size: 15))
                .foregroundColor(.yugiSoftBlack.opacity(0.75))
                .lineSpacing(4)

            Button(action: launchOnboarding) {
                HStack(spacing: 10) {
                    if isLaunchingOnboarding {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(isLaunchingOnboarding ? "Opening Stripe…" : buttonLabel)
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.yugiMocha)
                .cornerRadius(16)
                .shadow(color: Color.yugiMocha.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isLaunchingOnboarding)

            Text("You'll be taken to Stripe's secure site. We never see your bank details.")
                .font(.system(size: 12))
                .foregroundColor(.yugiSoftBlack.opacity(0.5))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .background(cardBackground)
    }

    private var successCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.yugiSage.opacity(0.2))
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.yugiDeepSage)
            }

            VStack(spacing: 8) {
                Text("Payouts active")
                    .font(.custom("Raleway-SemiBold", size: 22))
                    .foregroundColor(.yugiSoftBlack)

                Text("You're all set. Stripe will send payments to your bank account as parents book your classes.")
                    .font(.system(size: 15))
                    .foregroundColor(.yugiSoftBlack.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.yugiMocha)
                    .cornerRadius(16)
                    .shadow(color: Color.yugiMocha.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(24)
        .background(cardBackground)
    }

    private func errorCard(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.yugiError)

            Text("Something went wrong")
                .font(.custom("Raleway-SemiBold", size: 18))
                .foregroundColor(.yugiSoftBlack)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.yugiSoftBlack.opacity(0.7))
                .multilineTextAlignment(.center)

            Button(action: loadStatus) {
                Text("Try again")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.yugiMocha)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(Color.yugiMocha.opacity(0.1))
                    .cornerRadius(10)
            }
        }
        .padding(24)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.yugiMocha, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    // MARK: - Actions

    private func loadStatus() {
        isLoadingStatus = true
        errorMessage = nil

        service.checkStatus()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoadingStatus = false
                    if case .failure(let error) = completion {
                        errorMessage = "Couldn't check your Stripe setup. \(error.localizedDescription)"
                    }
                },
                receiveValue: { response in
                    status = StripeConnectStatus(from: response)
                }
            )
            .store(in: &cancellables)
    }

    private func launchOnboarding() {
        guard let status = status, !isLaunchingOnboarding else { return }
        isLaunchingOnboarding = true

        // .notStarted → /onboard creates a fresh account + link
        // anything else → /refresh-link regenerates a link for the existing account
        let linkPublisher: AnyPublisher<StripeOnboardingLinkResponse, Error> =
            status == .notStarted
                ? service.createOnboardingLink()
                : service.refreshOnboardingLink()

        linkPublisher
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        isLaunchingOnboarding = false
                        errorMessage = "Couldn't open Stripe. \(error.localizedDescription)"
                    }
                },
                receiveValue: { response in
                    guard let url = URL(string: response.url) else {
                        isLaunchingOnboarding = false
                        errorMessage = "Stripe returned an invalid link."
                        return
                    }
                    // Setting authURL triggers BetterSafariView's modifier to launch.
                    authURL = url
                }
            )
            .store(in: &cancellables)
    }

    private func handleAuthCompletion(callbackURL: URL?, error: Error?) {
        DispatchQueue.main.async {
            isLaunchingOnboarding = false
            authURL = nil

            if let error = error {
                let nsError = error as NSError
                // User cancelled — not actually an error from their perspective
                if nsError.domain == ASWebAuthenticationSessionErrorDomain,
                   nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                    return
                }
                errorMessage = "Stripe session ended unexpectedly. \(error.localizedDescription)"
                return
            }

            // On success (return OR refresh), re-check status and let the UI update
            loadStatus()
        }
    }
}
