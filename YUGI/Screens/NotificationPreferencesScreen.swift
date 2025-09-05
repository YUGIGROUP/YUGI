import SwiftUI

struct NotificationPreferencesScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var notificationService = NotificationService.shared
    @State private var preferences: NotificationPreferences
    @State private var showingSaveSuccess = false
    
    init() {
        _preferences = State(initialValue: NotificationService.shared.preferences)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Notification Preferences")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Stay updated about your bookings and classes")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
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
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Master Toggle
                        masterToggleSection
                        
                        // Save Button
                        saveButton
                    }
                    .padding(20)
                }
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePreferences()
                    }
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                }
            }
            .alert("Preferences Saved", isPresented: $showingSaveSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your notification preferences have been updated successfully.")
            }
        }
    }
    
    private var masterToggleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notifications")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.yugiGray)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Notifications")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.yugiGray)
                    
                    Text("Receive notifications about bookings, payments, and class updates")
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray.opacity(0.7))
                }
                
                Spacer()
                
                Toggle("", isOn: $preferences.isEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#BC6C5C")))
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
    
    private var saveButton: some View {
        Button(action: savePreferences) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                
                Text("Save Preferences")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .padding(.top, 8)
    }
    
    private func savePreferences() {
        notificationService.updatePreferences(preferences)
        showingSaveSuccess = true
    }
}

#Preview {
    NotificationPreferencesScreen()
} 