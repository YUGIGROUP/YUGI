import SwiftUI
import Combine

// MARK: - Provider Notification Models

struct ProviderNotification: Identifiable, Codable {
    let id: UUID
    let providerId: String
    let title: String
    let message: String
    let type: ProviderNotificationType
    let date: Date
    let isRead: Bool
    let actionType: ProviderNotificationActionType?
    let actionData: [String: String]?
    
    init(
        id: UUID = UUID(),
        providerId: String,
        title: String,
        message: String,
        type: ProviderNotificationType,
        date: Date = Date(),
        isRead: Bool = false,
        actionType: ProviderNotificationActionType? = nil,
        actionData: [String: String]? = nil
    ) {
        self.id = id
        self.providerId = providerId
        self.title = title
        self.message = message
        self.type = type
        self.date = date
        self.isRead = isRead
        self.actionType = actionType
        self.actionData = actionData
    }
}

enum ProviderNotificationType: String, CaseIterable, Codable {
    case bookingCancelled = "bookingCancelled"
    case newBooking = "newBooking"
    case paymentReceived = "paymentReceived"
    case classUpdate = "classUpdate"
    case system = "system"
    case verification = "verification"
    
    var displayName: String {
        switch self {
        case .bookingCancelled: return "Booking Cancelled"
        case .newBooking: return "New Booking"
        case .paymentReceived: return "Payment Received"
        case .classUpdate: return "Class Update"
        case .system: return "System"
        case .verification: return "Verification"
        }
    }
    
    var icon: String {
        switch self {
        case .bookingCancelled: return "xmark.circle"
        case .newBooking: return "calendar.badge.plus"
        case .paymentReceived: return "creditcard"
        case .classUpdate: return "book"
        case .system: return "gear"
        case .verification: return "checkmark.shield"
        }
    }
    
    var color: Color {
        switch self {
        case .bookingCancelled: return .red
        case .newBooking: return .green
        case .paymentReceived: return .blue
        case .classUpdate: return .orange
        case .system: return .gray
        case .verification: return .purple
        }
    }
}

enum ProviderNotificationActionType: String, CaseIterable, Codable {
    case viewBooking = "viewBooking"
    case viewClass = "viewClass"
    case viewPayment = "viewPayment"
    case contactParent = "contactParent"
    case updateClass = "updateClass"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .viewBooking: return "View Booking"
        case .viewClass: return "View Class"
        case .viewPayment: return "View Payment"
        case .contactParent: return "Contact Parent"
        case .updateClass: return "Update Class"
        case .none: return "None"
        }
    }
}

// MARK: - Provider Notification Preferences

struct ProviderNotificationPreferences: Codable {
    var isEnabled: Bool = true
    var bookingNotifications: Bool = true
    var paymentNotifications: Bool = true
    var systemNotifications: Bool = true
    var verificationNotifications: Bool = true
    
    var emailNotifications: Bool = true
    var pushNotifications: Bool = true
    var inAppNotifications: Bool = true
    var smsNotifications: Bool = false
    
    var quietHoursEnabled: Bool = false
    var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
}

// MARK: - Provider Notification Service

class ProviderNotificationService: ObservableObject {
    static let shared = ProviderNotificationService()
    
    @Published var notifications: [ProviderNotification] = []
    @Published var preferences: ProviderNotificationPreferences
    @Published var unreadCount: Int = 0
    
    private let notificationsKey = "persisted_provider_notifications"
    private let preferencesKey = "provider_notification_preferences"
    
    private init() {
        // Load preferences
        if let data = UserDefaults.standard.data(forKey: preferencesKey),
           let decoded = try? JSONDecoder().decode(ProviderNotificationPreferences.self, from: data) {
            preferences = decoded
        } else {
            preferences = ProviderNotificationPreferences()
        }
        
        // Load notifications
        loadNotifications()
        
        // Create sample notifications if none exist
        if notifications.isEmpty {
            createSampleNotifications()
        }
        
        updateUnreadCount()
    }
    
    // MARK: - Notification Management
    
    func addNotification(_ notification: ProviderNotification) {
        notifications.insert(notification, at: 0)
        saveNotifications()
        updateUnreadCount()
        
        // Send external notifications if enabled
        if preferences.isEnabled {
            sendExternalNotifications(for: notification)
        }
    }
    
    func markAsRead(_ notification: ProviderNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index] = ProviderNotification(
                id: notification.id,
                providerId: notification.providerId,
                title: notification.title,
                message: notification.message,
                type: notification.type,
                date: notification.date,
                isRead: true,
                actionType: notification.actionType,
                actionData: notification.actionData
            )
            saveNotifications()
            updateUnreadCount()
        }
    }
    
    func markAllAsRead() {
        notifications = notifications.map { notification in
            ProviderNotification(
                id: notification.id,
                providerId: notification.providerId,
                title: notification.title,
                message: notification.message,
                type: notification.type,
                date: notification.date,
                isRead: true,
                actionType: notification.actionType,
                actionData: notification.actionData
            )
        }
        saveNotifications()
        updateUnreadCount()
    }
    
    func deleteNotification(_ notification: ProviderNotification) {
        notifications.removeAll { $0.id == notification.id }
        saveNotifications()
        updateUnreadCount()
    }
    
    func clearAllNotifications() {
        notifications.removeAll()
        saveNotifications()
        updateUnreadCount()
    }
    
    func updatePreferences(_ newPreferences: ProviderNotificationPreferences) {
        preferences = newPreferences
        if let encoded = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(encoded, forKey: preferencesKey)
        }
    }
    
    // MARK: - Automatic Notification Methods
    
    func sendBookingCancellationNotification(
        providerId: String,
        className: String,
        bookingDate: Date,
        parentName: String,
        bookingId: String
    ) {
        guard preferences.isEnabled && preferences.bookingNotifications else { return }
        
        let notification = ProviderNotification(
            providerId: providerId,
            title: "Booking Cancelled",
            message: "\(parentName) has cancelled their booking for '\(className)' on \(formatDate(bookingDate)).",
            type: .bookingCancelled,
            actionType: .viewBooking,
            actionData: [
                "bookingId": bookingId,
                "className": className,
                "parentName": parentName
            ]
        )
        
        addNotification(notification)
    }
    
    func sendNewBookingNotification(
        providerId: String,
        className: String,
        bookingDate: Date,
        parentName: String,
        bookingId: String,
        participants: Int
    ) {
        guard preferences.isEnabled && preferences.bookingNotifications else { return }
        
        let notification = ProviderNotification(
            providerId: providerId,
            title: "New Booking",
            message: "\(parentName) has booked '\(className)' for \(participants) participant(s) on \(formatDate(bookingDate)).",
            type: .newBooking,
            actionType: .viewBooking,
            actionData: [
                "bookingId": bookingId,
                "className": className,
                "parentName": parentName,
                "participants": "\(participants)"
            ]
        )
        
        addNotification(notification)
    }
    
    func sendPaymentNotification(
        providerId: String,
        className: String,
        amount: Decimal,
        parentName: String,
        bookingId: String
    ) {
        guard preferences.isEnabled && preferences.paymentNotifications else { return }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "£"
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "£0.00"
        
        let notification = ProviderNotification(
            providerId: providerId,
            title: "Payment Received",
            message: "Payment of \(amountString) received from \(parentName) for '\(className)'.",
            type: .paymentReceived,
            actionType: .viewPayment,
            actionData: [
                "bookingId": bookingId,
                "className": className,
                "parentName": parentName,
                "amount": amountString
            ]
        )
        
        addNotification(notification)
    }
    
    // MARK: - External Notification Methods
    
    private func sendExternalNotifications(for notification: ProviderNotification) {
        // Send email notification
        if preferences.emailNotifications {
            sendEmailNotification(for: notification)
        }
        
        // Send push notification
        if preferences.pushNotifications {
            sendPushNotification(for: notification)
        }
        
        // Send SMS notification (for urgent notifications)
        if preferences.smsNotifications && isUrgentNotification(notification) {
            sendSMSNotification(for: notification)
        }
    }
    
    private func sendEmailNotification(for notification: ProviderNotification) {
        // In a real app, this would call your backend API to send an email
        print("📧 Sending email notification to provider \(notification.providerId):")
        print("   Subject: \(notification.title)")
        print("   Message: \(notification.message)")
        print("   Type: \(notification.type.displayName)")
        
        // Example API call:
        // apiService.sendProviderEmailNotification(
        //     providerId: notification.providerId,
        //     subject: notification.title,
        //     message: notification.message,
        //     type: notification.type.rawValue
        // )
    }
    
    private func sendPushNotification(for notification: ProviderNotification) {
        // In a real app, this would call your backend API to send a push notification
        print("📱 Sending push notification to provider \(notification.providerId):")
        print("   Title: \(notification.title)")
        print("   Body: \(notification.message)")
        print("   Type: \(notification.type.displayName)")
        
        // Example API call:
        // apiService.sendProviderPushNotification(
        //     providerId: notification.providerId,
        //     title: notification.title,
        //     body: notification.message,
        //     data: notification.actionData
        // )
    }
    
    private func sendSMSNotification(for notification: ProviderNotification) {
        // In a real app, this would call your backend API to send an SMS
        print("📱 Sending SMS notification to provider \(notification.providerId):")
        print("   Message: \(notification.message)")
        print("   Type: \(notification.type.displayName)")
        
        // Example API call:
        // apiService.sendProviderSMSNotification(
        //     providerId: notification.providerId,
        //     message: notification.message
        // )
    }
    
    private func isUrgentNotification(_ notification: ProviderNotification) -> Bool {
        // Define which notification types are urgent enough for SMS
        return notification.type == .bookingCancelled || notification.type == .newBooking
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d 'at' h:mm a"
        return formatter.string(from: date)
    }
    
    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }
    
    private func saveNotifications() {
        if let encoded = try? JSONEncoder().encode(notifications) {
            UserDefaults.standard.set(encoded, forKey: notificationsKey)
        }
    }
    
    private func loadNotifications() {
        if let data = UserDefaults.standard.data(forKey: notificationsKey),
           let decoded = try? JSONDecoder().decode([ProviderNotification].self, from: data) {
            notifications = decoded
        }
    }
    
    private func createSampleNotifications() {
        let sampleNotifications = [
            ProviderNotification(
                providerId: "provider1",
                title: "New Booking",
                message: "Sarah Johnson has booked 'Toddler Music & Movement' for 2 participant(s) on Jul 10 at 10:00 AM.",
                type: .newBooking,
                date: Date().addingTimeInterval(-3600),
                actionType: .viewBooking,
                actionData: ["bookingId": "123", "className": "Toddler Music & Movement", "parentName": "Sarah Johnson"]
            ),
            ProviderNotification(
                providerId: "provider1",
                title: "Payment Received",
                message: "Payment of £49.98 received from Sarah Johnson for 'Toddler Music & Movement'.",
                type: .paymentReceived,
                date: Date().addingTimeInterval(-7200),
                actionType: .viewPayment,
                actionData: ["bookingId": "123", "className": "Toddler Music & Movement", "parentName": "Sarah Johnson", "amount": "£49.98"]
            ),
            ProviderNotification(
                providerId: "provider1",
                title: "Booking Cancelled",
                message: "Michael Smith has cancelled their booking for 'Art & Craft Workshop' on Jul 12 at 2:00 PM.",
                type: .bookingCancelled,
                date: Date().addingTimeInterval(-10800),
                actionType: .viewBooking,
                actionData: ["bookingId": "456", "className": "Art & Craft Workshop", "parentName": "Michael Smith"]
            ),
            ProviderNotification(
                providerId: "provider1",
                title: "Account Verified",
                message: "Congratulations! Your provider account has been verified and is now active.",
                type: .verification,
                date: Date().addingTimeInterval(-14400),
                actionType: ProviderNotificationActionType.none
            )
        ]
        
        notifications = sampleNotifications
        saveNotifications()
    }
} 