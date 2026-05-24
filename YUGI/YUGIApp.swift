import SwiftUI
import Firebase
import StripePaymentSheet

struct VenueFeedbackContext: Identifiable {
    let id: String
    let placeId: String
    let venueName: String
    let startAtCard: Int

    init(placeId: String, venueName: String, startAtCard: Int = 0) {
        self.id = placeId
        self.placeId = placeId
        self.venueName = venueName
        self.startAtCard = startAtCard
    }
}

@main
struct YUGIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var feedbackCoordinator = FeedbackCoordinator.shared
    @StateObject private var promptManager = FeedbackPromptManager.shared
    @State private var venueFeedbackContext: VenueFeedbackContext?

    init() {
        FirebaseApp.configure()
        _ = LocationService.shared
        _ = EventTracker.shared

        // Stripe iOS SDK setup
        // TODO: Eva to paste the test publishable key here (pk_test_...)
        StripeAPI.defaultPublishableKey = ProcessInfo.processInfo.environment["STRIPE_PUBLISHABLE_KEY"]
            ?? ""
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .environmentObject(feedbackCoordinator)
                .sheet(item: $feedbackCoordinator.pendingFeedback) { context in
                    PostVisitFeedbackScreen(
                        bookingId: context.bookingId,
                        className: context.className
                    )
                }
                .sheet(isPresented: $promptManager.isShowingPrompt, onDismiss: {
                    promptManager.dismissPrompt()
                }) {
                    if let prompt = promptManager.pendingPrompt {
                        FeedbackPromptSheet(
                            prompt: prompt,
                            onShareFeedback: {
                                venueFeedbackContext = VenueFeedbackContext(
                                    placeId: prompt.placeId,
                                    venueName: prompt.venueName,
                                    startAtCard: 1
                                )
                                promptManager.dismissPrompt()
                            }
                        )
                        .presentationDragIndicator(.visible)
                    }
                }
                .sheet(item: $venueFeedbackContext) { context in
                    VenueFeedbackScreen(
                        placeId: context.placeId,
                        venueName: context.venueName,
                        startAtCard: context.startAtCard
                    )
                }
        }
    }
}
