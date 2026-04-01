//
//  AppDelegate.swift
//  YUGI
//

import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()
        return true
    }

    // MARK: - Permission + Registration

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("🔔 Notification auth error: \(error.localizedDescription)")
                return
            }
            guard granted else {
                print("🔔 Notification permission denied")
                return
            }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("🔔 APNs device token: \(tokenString)")
        sendDeviceTokenToBackend(tokenString)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("🔔 Failed to register for remote notifications: \(error.localizedDescription)")
    }

    // MARK: - Backend Registration

    private func sendDeviceTokenToBackend(_ token: String) {
        guard let url = URL(string: "https://yugi-production.up.railway.app/api/users/device-token") else { return }
        guard let authToken = UserDefaults.standard.string(forKey: "authToken") else {
            print("🔔 No auth token — skipping device token registration")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let body: [String: String] = ["token": token, "platform": "ios"]
        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }
        request.httpBody = data

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("🔔 Device token registration failed: \(error.localizedDescription)")
            } else if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                print("🔔 Device token registered successfully")
            }
        }.resume()
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let type = userInfo["type"] as? String, type == "post_visit_feedback",
           let bookingId = userInfo["bookingId"] as? String {
            let className = response.notification.request.content.body
            DispatchQueue.main.async {
                FeedbackCoordinator.shared.pendingFeedback = FeedbackContext(
                    bookingId: bookingId,
                    className: className
                )
            }
        }

        completionHandler()
    }
}
