//
//  YUGIApp.swift
//  YUGI
//
//  Created by EVA PARMAR on 29/05/2025.
//

import SwiftUI
import Firebase

@main
struct YUGIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        FirebaseApp.configure()
        _ = LocationService.shared
        _ = EventTracker.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .environmentObject(FeedbackCoordinator.shared)
                .task {
                    // Small delay so auth state can settle before we hit the API
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    FeedbackCoordinator.shared.fetchAndShowPendingFeedback()
                }
                .sheet(item: Binding(
                    get: { FeedbackCoordinator.shared.pendingFeedback },
                    set: { FeedbackCoordinator.shared.pendingFeedback = $0 }
                )) { context in
                    PostVisitFeedbackScreen(
                        bookingId: context.bookingId,
                        className: context.className
                    )
                }
        }
    }
}
