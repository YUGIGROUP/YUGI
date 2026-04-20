import SwiftUI

struct NotificationsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationService = NotificationService.shared
    @State private var selectedTab = 0
    @State private var showingPreferences = false
    @State private var showingClearConfirmation = false
    @State private var selectedNotification: UserNotification?

    // Animation
    @State private var showHeader  = false
    @State private var showTabs    = false
    @State private var showContent = false

    var body: some View {
        ZStack {
            Color.yugiCloud.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Nav header
                HStack(spacing: 6) {
                    Button(action: { dismiss() }) {
                        Text("‹")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                    }
                    Text("Notifications")
                        .font(.custom("Raleway-Medium", size: 18))
                        .foregroundColor(.white)
                    Spacer()
                    if !notificationService.notifications.isEmpty {
                        Button(action: { showingClearConfirmation = true }) {
                            Image(systemName: "trash")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                        }
                        .padding(.trailing, 12)
                    }
                    Button(action: { showingPreferences = true }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                .background(Color.yugiMocha.ignoresSafeArea(edges: .top))
                .opacity(showHeader ? 1 : 0)
                .offset(y: showHeader ? 0 : 12)
                .animation(.easeOut(duration: 0.6), value: showHeader)

                // MARK: Tabs
                VStack(spacing: 0) {
                    HStack(spacing: 24) {
                        notificationTabLabel(title: "All", isSelected: selectedTab == 0) {
                            selectedTab = 0
                        }
                        notificationTabLabel(title: "Unread", isSelected: selectedTab == 1) {
                            selectedTab = 1
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Rectangle()
                        .fill(Color.yugiOat)
                        .frame(height: 0.5)
                        .padding(.top, 0)
                }
                .opacity(showTabs ? 1 : 0)
                .offset(y: showTabs ? 0 : 12)
                .animation(.easeOut(duration: 0.6), value: showTabs)

                // MARK: Content
                Group {
                    if notificationService.notifications.isEmpty || (selectedTab == 1 && notificationService.notifications.filter { !$0.isRead }.isEmpty) {
                        emptyStateView
                    } else {
                        notificationListView
                    }
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 12)
                .animation(.easeOut(duration: 0.6), value: showContent)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { showHeader  = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { showTabs    = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) { showContent = true }
        }
        .sheet(isPresented: $showingPreferences) {
            NotificationPreferencesScreen()
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

    @ViewBuilder
    private func notificationTabLabel(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(title)
                    .font(isSelected ? .custom("Raleway-Medium", size: 14) : .custom("Raleway-Regular", size: 14))
                    .foregroundColor(isSelected ? Color.yugiSoftBlack : Color.yugiBodyText)
                    .padding(.bottom, 12)

                Rectangle()
                    .fill(isSelected ? Color.yugiMocha : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            RoundedRectangle(cornerRadius: 18)
                .fill(Color.yugiOat)
                .frame(width: 72, height: 72)
                .overlay(
                    Image(systemName: "bell")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(Color.yugiMocha)
                )

            VStack(spacing: 6) {
                Text("All caught up")
                    .font(.custom("Raleway-Medium", size: 20))
                    .foregroundColor(Color.yugiSoftBlack)
                    .tracking(-0.3)

                Text("New bookings and reminders will appear here.")
                    .font(.custom("Raleway-Regular", size: 14))
                    .foregroundColor(Color.yugiBodyText)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 240)
            }

            Spacer()
        }
    }

    private var notificationListView: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(filteredNotifications) { notification in
                    StyledNotificationRow(
                        notification: notification,
                        onTap: { handleNotificationTap(notification) },
                        onDelete: { notificationService.deleteNotification(notification) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    private var filteredNotifications: [UserNotification] {
        switch selectedTab {
        case 1:  return notificationService.notifications.filter { !$0.isRead }
        default: return notificationService.notifications
        }
    }

    private func handleNotificationTap(_ notification: UserNotification) {
        if !notification.isRead {
            notificationService.markAsRead(notification)
        }
        if let actionType = notification.actionType {
            switch actionType {
            case .viewBooking:     print("Navigate to booking: \(notification.actionData?["bookingId"] ?? "")")
            case .viewClass:       print("Navigate to class: \(notification.actionData?["classId"] ?? "")")
            case .viewPayment:     print("Navigate to payment: \(notification.actionData?["paymentId"] ?? "")")
            case .bookClass:       print("Navigate to book class with promo: \(notification.actionData?["promoCode"] ?? "")")
            case .contactProvider: print("Navigate to contact provider")
            case .contactSupport:  print("Navigate to contact support")
            case .none:            break
            }
        }
    }
}

// MARK: - Styled Notification Row

struct StyledNotificationRow: View {
    let notification: UserNotification
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirmation = false

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 0) {
                if !notification.isRead {
                    Circle()
                        .fill(Color.yugiMocha)
                        .frame(width: 6, height: 6)
                        .padding(.top, 5)
                        .padding(.trailing, 10)
                } else {
                    Spacer().frame(width: 16)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .top) {
                        Text(notification.title)
                            .font(.custom("Raleway-Medium", size: 14))
                            .foregroundColor(Color.yugiSoftBlack)
                            .lineLimit(1)
                        Spacer()
                        Text(formatDate(notification.date))
                            .font(.custom("Raleway-Regular", size: 11))
                            .foregroundColor(Color.yugiBodyText)
                    }

                    Text(notification.message)
                        .font(.custom("Raleway-Regular", size: 13))
                        .foregroundColor(Color.yugiBodyText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .padding(.top, 2)
                }

                Button(action: { showingDeleteConfirmation = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13))
                        .foregroundColor(Color.yugiBodyText.opacity(0.5))
                }
                .padding(.leading, 10)
                .padding(.top, 2)
            }
            .padding(14)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.yugiOat, lineWidth: 1))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .alert("Delete Notification", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { onDelete() }
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
    NotificationsScreen()
}
