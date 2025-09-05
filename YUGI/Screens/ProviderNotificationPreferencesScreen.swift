import SwiftUI

struct ProviderNotificationPreferencesScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationService = ProviderNotificationService.shared
    @State private var preferences: ProviderNotificationPreferences
    
    init() {
        _preferences = State(initialValue: ProviderNotificationService.shared.preferences)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Master toggle
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notifications")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.yugiGray)
                                
                                Text("Enable all notifications")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $preferences.isEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#BC6C5C")))
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                    
                    if preferences.isEnabled {
                        // Notification types
                        VStack(spacing: 16) {
                            Text("Notification Types")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.yugiGray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(spacing: 0) {
                                NotificationTypeRow(
                                    title: "Booking Notifications",
                                    subtitle: "New bookings and cancellations",
                                    isOn: $preferences.bookingNotifications
                                )
                                
                                Divider()
                                    .padding(.leading, 16)
                                
                                NotificationTypeRow(
                                    title: "Payment Notifications",
                                    subtitle: "Payment confirmations and refunds",
                                    isOn: $preferences.paymentNotifications
                                )
                                
                                Divider()
                                    .padding(.leading, 16)
                                
                                NotificationTypeRow(
                                    title: "System Notifications",
                                    subtitle: "Account updates and maintenance",
                                    isOn: $preferences.systemNotifications
                                )
                                
                                Divider()
                                    .padding(.leading, 16)
                                
                                NotificationTypeRow(
                                    title: "Verification Notifications",
                                    subtitle: "Account verification and status updates",
                                    isOn: $preferences.verificationNotifications
                                )
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        }
                        
                        // Delivery methods
                        VStack(spacing: 16) {
                            Text("Delivery Methods")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.yugiGray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            VStack(spacing: 0) {
                                NotificationTypeRow(
                                    title: "In-App Notifications",
                                    subtitle: "Notifications within the app",
                                    isOn: $preferences.inAppNotifications
                                )
                                
                                Divider()
                                    .padding(.leading, 16)
                                
                                NotificationTypeRow(
                                    title: "Email Notifications",
                                    subtitle: "Receive notifications via email",
                                    isOn: $preferences.emailNotifications
                                )
                                
                                Divider()
                                    .padding(.leading, 16)
                                
                                NotificationTypeRow(
                                    title: "Push Notifications",
                                    subtitle: "Notifications on your device",
                                    isOn: $preferences.pushNotifications
                                )
                                
                                Divider()
                                    .padding(.leading, 16)
                                
                                NotificationTypeRow(
                                    title: "SMS Notifications",
                                    subtitle: "Text messages for urgent updates",
                                    isOn: $preferences.smsNotifications
                                )
                            }
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        }
                        
                        // Quiet hours
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Quiet Hours")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.yugiGray)
                                    
                                    Text("Pause notifications during specific hours")
                                        .font(.system(size: 14))
                                        .foregroundColor(.yugiGray.opacity(0.7))
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $preferences.quietHoursEnabled)
                                    .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#BC6C5C")))
                            }
                            .padding(16)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            
                            if preferences.quietHoursEnabled {
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("Start Time")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.yugiGray)
                                        
                                        Spacer()
                                        
                                        DatePicker("", selection: $preferences.quietHoursStart, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                    }
                                    
                                    HStack {
                                        Text("End Time")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(.yugiGray)
                                        
                                        Spacer()
                                        
                                        DatePicker("", selection: $preferences.quietHoursEnd, displayedComponents: .hourAndMinute)
                                            .labelsHidden()
                                    }
                                }
                                .padding(16)
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                            }
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(20)
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationTitle("Notification Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#BC6C5C"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        notificationService.updatePreferences(preferences)
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#BC6C5C"))
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct NotificationTypeRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.yugiGray)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.yugiGray.opacity(0.7))
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#BC6C5C")))
        }
        .padding(16)
    }
}

#Preview {
    ProviderNotificationPreferencesScreen()
} 