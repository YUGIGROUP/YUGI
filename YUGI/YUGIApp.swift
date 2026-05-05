import SwiftUI
import Firebase

@main
struct YUGIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var feedbackCoordinator = FeedbackCoordinator.shared
    @StateObject private var promptManager = FeedbackPromptManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasScheduledPromptCheckThisLaunch = false

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
                .sheet(isPresented: $promptManager.isShowingPrompt, onDismiss: {
                    promptManager.dismissPrompt()
                }) {
                    if let prompt = promptManager.pendingPrompt {
                        FeedbackPromptSheet(
                            prompt: prompt,
                            onShareFeedback: {
                                print("TODO: open feedback carousel")
                                promptManager.dismissPrompt()
                            }
                        )
                        .presentationDragIndicator(.visible)
                    }
                }
                .onChange(of: scenePhase) { newPhase in
                    guard newPhase == .active, !hasScheduledPromptCheckThisLaunch else { return }
                    hasScheduledPromptCheckThisLaunch = true

                    Task {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        await promptManager.checkForPendingPrompt()
                    }
                }
        }
    }
}
