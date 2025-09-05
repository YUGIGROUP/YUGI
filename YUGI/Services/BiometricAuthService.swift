import Foundation
import LocalAuthentication
import Security

class BiometricAuthService: ObservableObject {
    static let shared = BiometricAuthService()
    
    @Published var biometricType: LABiometryType = .none
    @Published var isBiometricAvailable = false
    @Published var isRememberMeEnabled = false
    
    private let biometricKey = "biometric_enabled"
    private let rememberMeKey = "remember_me_enabled"
    private let savedCredentialsKey = "saved_credentials"
    
    private init() {
        checkBiometricAvailability()
        loadRememberMeState()
    }
    
    // MARK: - Biometric Authentication
    
    func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        
        print("🔐 BiometricAuthService: Checking biometric availability...")
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
            isBiometricAvailable = true
            print("🔐 BiometricAuthService: Biometric authentication is available")
            print("🔐 BiometricAuthService: Biometric type: \(biometricType)")
        } else {
            biometricType = .none
            isBiometricAvailable = false
            print("🔐 BiometricAuthService: Biometric authentication not available")
            print("🔐 BiometricAuthService: Error: \(error?.localizedDescription ?? "Unknown error")")
            print("🔐 BiometricAuthService: Error code: \(error?.code ?? -1)")
            
            // Provide more specific error information
            if let error = error {
                switch error.code {
                case LAError.biometryNotAvailable.rawValue:
                    print("🔐 BiometricAuthService: Biometry not available on this device")
                case LAError.biometryNotEnrolled.rawValue:
                    print("🔐 BiometricAuthService: Biometry not enrolled - user needs to set up Face ID/Touch ID")
                case LAError.biometryLockout.rawValue:
                    print("🔐 BiometricAuthService: Biometry is locked out")
                case LAError.passcodeNotSet.rawValue:
                    print("🔐 BiometricAuthService: Passcode not set on device")
                default:
                    print("🔐 BiometricAuthService: Other error: \(error.localizedDescription)")
                }
            }
        }
        
        // For simulator testing, we can simulate biometric availability
        #if targetEnvironment(simulator)
        print("🔐 BiometricAuthService: Running in iOS Simulator")
        print("🔐 BiometricAuthService: Simulating Face ID availability for testing")
        biometricType = .faceID
        isBiometricAvailable = true
        #endif
    }
    
    func authenticateWithBiometrics() async -> Bool {
        let context = LAContext()
        let reason = "Sign in to YUGI"
        
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            return success
        } catch {
            print("Biometric authentication failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Remember Me Functionality
    
    func saveCredentials(email: String, password: String) {
        guard isRememberMeEnabled else { return }
        
        let credentials = SavedCredentials(email: email, password: password)
        
        do {
            let data = try JSONEncoder().encode(credentials)
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: savedCredentialsKey,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            
            // Delete existing credentials first
            SecItemDelete(query as CFDictionary)
            
            // Save new credentials
            let status = SecItemAdd(query as CFDictionary, nil)
            if status == errSecSuccess {
                print("Credentials saved successfully")
            } else {
                print("Failed to save credentials: \(status)")
            }
        } catch {
            print("Error encoding credentials: \(error)")
        }
    }
    
    func loadSavedCredentials() -> SavedCredentials? {
        guard isRememberMeEnabled else { return nil }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: savedCredentialsKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            do {
                let credentials = try JSONDecoder().decode(SavedCredentials.self, from: data)
                return credentials
            } catch {
                print("Error decoding credentials: \(error)")
                return nil
            }
        }
        
        return nil
    }
    
    func clearSavedCredentials() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: savedCredentialsKey
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess {
            print("Credentials cleared successfully")
        } else {
            print("Failed to clear credentials: \(status)")
        }
    }
    
    // MARK: - Settings Management
    
    func setRememberMeEnabled(_ enabled: Bool) {
        isRememberMeEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: rememberMeKey)
        
        if !enabled {
            clearSavedCredentials()
        }
    }
    
    func setBiometricEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: biometricKey)
    }
    
    func isBiometricEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: biometricKey)
    }
    
    private func loadRememberMeState() {
        isRememberMeEnabled = UserDefaults.standard.bool(forKey: rememberMeKey)
    }
    
    // MARK: - Helper Methods
    
    func getBiometricTypeName() -> String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "Biometric"
        @unknown default:
            return "Biometric"
        }
    }
    
    func getBiometricIcon() -> String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "eye.fill"
        case .none:
            return "person.crop.circle"
        @unknown default:
            return "person.crop.circle"
        }
    }
}

// MARK: - Models

struct SavedCredentials: Codable {
    let email: String
    let password: String
    let savedAt: Date
    
    init(email: String, password: String) {
        self.email = email
        self.password = password
        self.savedAt = Date()
    }
} 