import SwiftUI

struct ProviderNotificationsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationService = ProviderNotificationService.shared
    @State private var selectedTab = 0
    @State private var showingPreferences = false
    @State private var showingClearConfirmation = false
    @State private var selectedNotification: ProviderNotification?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notifications")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("\(notificationService.unreadCount) unread")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Spacer()
                        
                        // Action buttons
                        HStack(spacing: 12) {
                            Button(action: {
                                showingPreferences = true
                            }) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                            }
                            
                            if !notificationService.notifications.isEmpty {
                                Button(action: {
                                    showingClearConfirmation = true
                                }) {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.8)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // Tab Selector
                HStack(spacing: 0) {
                    ProviderNotificationTabButton(
                        title: "All",
                        isSelected: selectedTab == 0,
                        count: notificationService.notifications.count
                    ) {
                        selectedTab = 0
                    }
                    
                    ProviderNotificationTabButton(
                        title: "Unread",
                        isSelected: selectedTab == 1,
                        count: notificationService.unreadCount
                    ) {
                        selectedTab = 1
                    }
                }
                .background(Color.white)
                
                // Content
                if notificationService.notifications.isEmpty {
                    emptyStateView
                } else {
                    notificationListView
                }
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(hex: "#BC6C5C"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showingPreferences) {
                ProviderNotificationPreferencesScreen()
            }
            .alert("Clear All Notifications", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    notificationService.clearAllNotifications()
                }
            } message: {
                Text("Are you sure you want to clear all notifications? This action cannot be undone.")
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "bell.slash")
                .font(.system(size: 64))
                .foregroundColor(.yugiGray.opacity(0.3))
            
            VStack(spacing: 8) {
                Text("No Notifications")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.yugiGray)
                
                Text("You're all caught up! We'll notify you about bookings, payments, and important updates.")
                    .font(.system(size: 16))
                    .foregroundColor(.yugiGray.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
    
    private var notificationListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredNotifications) { notification in
                    ProviderNotificationRow(
                        notification: notification,
                        onTap: {
                            handleNotificationTap(notification)
                        },
                        onDelete: {
                            notificationService.deleteNotification(notification)
                        }
                    )
                    .onTapGesture {
                        handleNotificationTap(notification)
                    }
                }
            }
            .padding(.top, 8)
        }
    }
    
    private var filteredNotifications: [ProviderNotification] {
        switch selectedTab {
        case 0:
            return notificationService.notifications
        case 1:
            return notificationService.notifications.filter { !$0.isRead }
        default:
            return notificationService.notifications
        }
    }
    
    private func handleNotificationTap(_ notification: ProviderNotification) {
        // Mark as read if not already read
        if !notification.isRead {
            notificationService.markAsRead(notification)
        }
        
        // Handle action if available
        if let actionType = notification.actionType {
            switch actionType {
            case .viewBooking:
                // Navigate to booking details
                print("Navigate to booking: \(notification.actionData?["bookingId"] ?? "")")
            case .viewClass:
                // Navigate to class details
                print("Navigate to class: \(notification.actionData?["classId"] ?? "")")
            case .viewPayment:
                // Navigate to payment details
                print("Navigate to payment: \(notification.actionData?["paymentId"] ?? "")")
            case .contactParent:
                // Navigate to contact parent
                print("Navigate to contact parent: \(notification.actionData?["parentName"] ?? "")")
            case .updateClass:
                // Navigate to update class
                print("Navigate to update class: \(notification.actionData?["classId"] ?? "")")
            case .none:
                break
            }
        }
    }
}

// MARK: - Supporting Views

struct ProviderNotificationTabButton: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? Color(hex: "#BC6C5C") : .yugiGray)
                
                Text("\(count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? Color(hex: "#BC6C5C") : .yugiGray.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Rectangle()
                    .fill(isSelected ? Color(hex: "#BC6C5C").opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProviderNotificationRow: View {
    let notification: ProviderNotification
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Notification icon
                ZStack {
                    Circle()
                        .fill(notification.type.color.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: notification.type.icon)
                        .font(.system(size: 20))
                        .foregroundColor(notification.type.color)
                }
                
                // Notification content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.yugiGray)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if !notification.isRead {
                            Circle()
                                .fill(Color(hex: "#BC6C5C"))
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Text(notification.message)
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray.opacity(0.8))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text(formatDate(notification.date))
                            .font(.system(size: 12))
                            .foregroundColor(.yugiGray.opacity(0.6))
                        
                        Spacer()
                        
                        if let actionType = notification.actionType, actionType != .none {
                            Text(actionType.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                        }
                    }
                }
                
                // Delete button
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
                .opacity(0.6)
            }
            .padding(16)
            .background(
                Rectangle()
                    .fill(notification.isRead ? Color.white : Color(hex: "#BC6C5C").opacity(0.05))
            )
            
            Divider()
                .padding(.leading, 80)
        }
        .alert("Delete Notification", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this notification?")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    ProviderNotificationsScreen()
} 