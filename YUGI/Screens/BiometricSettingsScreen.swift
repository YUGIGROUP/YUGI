import SwiftUI

struct BiometricSettingsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var biometricService = BiometricAuthService.shared
    @State private var showingClearCredentialsAlert = false
    @State private var showingBiometricSetupAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Biometric Authentication")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Manage your Face ID & Touch ID settings")
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
                        // Biometric Status
                        biometricStatusSection
                        
                        // Remember Me Settings
                        rememberMeSection
                        
                        // Security Options
                        securitySection
                    }
                    .padding(20)
                }
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarHidden(true)
            .alert("Clear Saved Credentials", isPresented: $showingClearCredentialsAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    biometricService.clearSavedCredentials()
                }
            } message: {
                Text("This will remove your saved email and password. You'll need to enter them again next time you sign in.")
            }
            .alert("Biometric Setup", isPresented: $showingBiometricSetupAlert) {
                Button("OK") { }
            } message: {
                Text("To use \(biometricService.getBiometricTypeName()), please set it up in your device's Settings app under Face ID & Passcode or Touch ID & Passcode.")
            }
        }
    }
    
    // MARK: - Biometric Status Section
    
    private var biometricStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Biometric Authentication")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.yugiGray)
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: biometricService.getBiometricIcon())
                        .font(.system(size: 24))
                        .foregroundColor(biometricService.isBiometricAvailable ? Color(hex: "#BC6C5C") : .gray)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(biometricService.getBiometricTypeName())
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        Text(biometricService.isBiometricAvailable ? "Available" : "Not available")
                            .font(.system(size: 14))
                            .foregroundColor(biometricService.isBiometricAvailable ? .green : .red)
                    }
                    
                    Spacer()
                    
                    if biometricService.isBiometricAvailable {
                        Toggle("", isOn: Binding(
                            get: { biometricService.isBiometricEnabled() },
                            set: { newValue in
                                biometricService.setBiometricEnabled(newValue)
                                if newValue && !biometricService.isBiometricAvailable {
                                    showingBiometricSetupAlert = true
                                }
                            }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#BC6C5C")))
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                
                if !biometricService.isBiometricAvailable {
                    Text("\(biometricService.getBiometricTypeName()) is not available on this device or not set up.")
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray.opacity(0.7))
                        .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Remember Me Section
    
    private var rememberMeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Remember Me")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.yugiGray)
            
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "key.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Save Credentials")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        Text("Securely save your email and password")
                            .font(.system(size: 14))
                            .foregroundColor(.yugiGray.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $biometricService.isRememberMeEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#BC6C5C")))
                        .onChange(of: biometricService.isRememberMeEnabled) { _, newValue in
                            biometricService.setRememberMeEnabled(newValue)
                        }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                
                if biometricService.isRememberMeEnabled {
                    Button(action: {
                        showingClearCredentialsAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear Saved Credentials")
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    // MARK: - Security Section
    
    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Security Information")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.yugiGray)
            
            VStack(spacing: 12) {
                securityInfoRow(
                    icon: "lock.shield",
                    title: "Secure Storage",
                    description: "Credentials are stored securely using iOS Keychain"
                )
                
                securityInfoRow(
                    icon: "device.phone.portrait",
                    title: "Device Only",
                    description: "Credentials are only stored on this device"
                )
                
                securityInfoRow(
                    icon: "hand.raised",
                    title: "Privacy First",
                    description: "We never share your biometric data"
                )
            }
        }
    }
    
    private func securityInfoRow(icon: String, title: String, description: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "#BC6C5C"))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.yugiGray)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.yugiGray.opacity(0.7))
            }
            
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}

#Preview {
    BiometricSettingsScreen()
} 