import SwiftUI

// MARK: - Notification Models

struct UserNotification: Identifiable, Codable {
    let id: UUID
    let title: String
    let message: String
    let type: NotificationType
    let date: Date
    let isRead: Bool
    let actionType: NotificationActionType?
    let actionData: [String: String]?
    
    init(
        id: UUID = UUID(),
        title: String,
        message: String,
        type: NotificationType,
        date: Date = Date(),
        isRead: Bool = false,
        actionType: NotificationActionType? = nil,
        actionData: [String: String]? = nil
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.type = type
        self.date = date
        self.isRead = isRead
        self.actionType = actionType
        self.actionData = actionData
    }
}

enum NotificationType: String, CaseIterable, Codable {
    case booking = "booking"
    case payment = "payment"
    case reminder = "reminder"
    case system = "system"
    case promotion = "promotion"
    case classUpdate = "classUpdate"
    case providerUpdate = "providerUpdate"
    
    var displayName: String {
        switch self {
        case .booking: return "Booking"
        case .payment: return "Payment"
        case .reminder: return "Reminder"
        case .system: return "System"
        case .promotion: return "Promotion"
        case .classUpdate: return "Class Update"
        case .providerUpdate: return "Provider Update"
        }
    }
    
    var icon: String {
        switch self {
        case .booking: return "calendar.badge.clock"
        case .payment: return "creditcard"
        case .reminder: return "bell"
        case .system: return "gear"
        case .promotion: return "tag"
        case .classUpdate: return "book"
        case .providerUpdate: return "building.2"
        }
    }
    
    var color: Color {
        switch self {
        case .booking: return .blue
        case .payment: return .green
        case .reminder: return .orange
        case .system: return .gray
        case .promotion: return .purple
        case .classUpdate: return .indigo
        case .providerUpdate: return .teal
        }
    }
}

enum NotificationActionType: String, CaseIterable, Codable {
    case viewBooking = "viewBooking"
    case viewClass = "viewClass"
    case viewPayment = "viewPayment"
    case bookClass = "bookClass"
    case contactProvider = "contactProvider"
    case contactSupport = "contactSupport"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .viewBooking: return "View Booking"
        case .viewClass: return "View Class"
        case .viewPayment: return "View Payment"
        case .bookClass: return "Book Class"
        case .contactProvider: return "Contact Provider"
        case .contactSupport: return "Contact Support"
        case .none: return "None"
        }
    }
}

// MARK: - Notification Preferences

struct NotificationPreferences: Codable {
    var isEnabled: Bool = true
    var bookingNotifications: Bool = true
    var paymentNotifications: Bool = true
    var reminderNotifications: Bool = true
    var systemNotifications: Bool = true
    var promotionNotifications: Bool = false
    var classUpdateNotifications: Bool = true
    var providerUpdateNotifications: Bool = true
    
    var reminderTime: Int = 60 // minutes before class
    var quietHoursEnabled: Bool = false
    var quietHoursStart: Date = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? Date()
    var quietHoursEnd: Date = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    
    var emailNotifications: Bool = true
    var pushNotifications: Bool = true
    var inAppNotifications: Bool = true
}

// MARK: - Notification Service

class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published var notifications: [UserNotification] = []
    @Published var preferences: NotificationPreferences
    @Published var unreadCount: Int = 0
    
    private let notificationsKey = "persisted_notifications"
    private let preferencesKey = "notification_preferences"
    
    private init() {
        // Clear any existing mock data from UserDefaults for new users
        UserDefaults.standard.removeObject(forKey: notificationsKey)
        print("🔔 NotificationService: Cleared existing mock data from UserDefaults")
        
        // Load preferences
        if let data = UserDefaults.standard.data(forKey: preferencesKey),
           let decoded = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            preferences = decoded
        } else {
            preferences = NotificationPreferences()
        }
        
        // Load notifications
        loadNotifications()
        
        // Start with empty notifications for new users
        // No initial mock data - users should receive real notifications
        updateUnreadCount()
    }
    
    func addNotification(_ notification: UserNotification) {
        notifications.insert(notification, at: 0)
        saveNotifications()
        updateUnreadCount()
    }
    
    func markAsRead(_ notification: UserNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index] = UserNotification(
                id: notification.id,
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
            UserNotification(
                id: notification.id,
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
    
    func deleteNotification(_ notification: UserNotification) {
        notifications.removeAll { $0.id == notification.id }
        saveNotifications()
        updateUnreadCount()
    }
    
    func clearAllNotifications() {
        notifications.removeAll()
        saveNotifications()
        updateUnreadCount()
    }
    
    func updatePreferences(_ newPreferences: NotificationPreferences) {
        preferences = newPreferences
        if let encoded = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(encoded, forKey: preferencesKey)
        }
    }
    
    // MARK: - Automatic Notification Methods
    
    func sendBookingNotification(for enhancedBooking: EnhancedBooking) {
        guard preferences.isEnabled else { return }
        
        let notification = UserNotification(
            title: "Booking Confirmed",
            message: "Your booking for '\(enhancedBooking.className)' has been confirmed for \(formatDate(enhancedBooking.booking.bookingDate)).",
            type: .booking,
            actionType: .viewBooking,
            actionData: ["bookingId": enhancedBooking.booking.id.uuidString]
        )
        
        addNotification(notification)
    }
    
    func sendPaymentNotification(amount: Decimal, className: String) {
        guard preferences.isEnabled else { return }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "£"
        let amountString = formatter.string(from: amount as NSDecimalNumber) ?? "£0.00"
        
        let notification = UserNotification(
            title: "Payment Successful",
            message: "Payment of \(amountString) for '\(className)' has been processed successfully.",
            type: .payment,
            actionType: .viewPayment,
            actionData: ["className": className]
        )
        
        addNotification(notification)
    }
    
    func sendClassUpdateNotification(className: String, updateMessage: String) {
        guard preferences.isEnabled else { return }
        
        let notification = UserNotification(
            title: "Class Update",
            message: "Update for '\(className)': \(updateMessage)",
            type: .classUpdate,
            actionType: .viewClass,
            actionData: ["className": className]
        )
        
        addNotification(notification)
    }
    
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
           let decoded = try? JSONDecoder().decode([UserNotification].self, from: data) {
            notifications = decoded
        }
    }
    

} 