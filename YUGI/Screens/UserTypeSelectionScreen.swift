import SwiftUI

struct UserTypeSelectionScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedUserType: UserType = .parent
    @State private var shouldNavigateToParentDashboard = false
    @State private var shouldNavigateToProviderDashboard = false
    @State private var shouldDismissAndNavigate = false
    
    @StateObject private var apiService = APIService.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerSection
                userTypeSelectionSection
                Spacer()
                continueButton
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationTitle("Choose User Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.yugiOrange, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .navigationDestination(isPresented: $shouldNavigateToParentDashboard) {
                ParentDashboardScreen(parentName: "New User", initialTab: 0)
            }
            .navigationDestination(isPresented: $shouldNavigateToProviderDashboard) {
                ProviderDashboardScreen(businessName: "New Provider")
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("Welcome to YUGI!")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.yugiGray)
            
            Text("How will you use YUGI?")
                .font(.system(size: 17))
                .foregroundColor(.yugiGray.opacity(0.8))
        }
        .padding(.top, 48)
        .padding(.horizontal)
    }
    
    private var userTypeSelectionSection: some View {
        VStack(spacing: 20) {
            ForEach(UserType.allCases, id: \.self) { type in
                userTypeButton(for: type)
            }
        }
        .padding(.horizontal)
        .padding(.top, 32)
    }
    
    private func userTypeButton(for type: UserType) -> some View {
        Button {
            selectedUserType = type
        } label: {
            HStack(spacing: 16) {
                Image(systemName: selectedUserType == type ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(selectedUserType == type ? .yugiOrange : .yugiGray.opacity(0.6))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.yugiGray)
                    Text(type.description)
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray.opacity(0.7))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedUserType == type ? Color.yugiOrange : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var continueButton: some View {
        Button(action: continueToDashboard) {
            HStack {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.yugiOrange)
            )
        }
        .padding(.horizontal)
        .padding(.bottom, 32)
    }
    
    private func continueToDashboard() {
        // Simulate authentication for the selected user type
        apiService.forceAuthenticateForTesting(userType: selectedUserType)
        
        // Dismiss the sheet - the parent view will handle navigation based on the authenticated user
        dismiss()
    }
}

#Preview("User Type Selection Screen") {
    UserTypeSelectionScreen()
} 