import SwiftUI
import Firebase

@main
struct YUGIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var feedbackCoordinator = FeedbackCoordinator.shared

    init() {
        FirebaseApp.configure()
        _ = LocationService.shared
        _ = EventTracker.shared
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
        }
    }
}
