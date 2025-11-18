import Foundation
import Firebase
import FirebaseAuth
import Combine

class FirebaseAuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    var cancellables = Set<AnyCancellable>()
    
    init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Auth State Listener
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                if let firebaseUser = user {
                    self?.isAuthenticated = true
                                           self?.currentUser = User(
                           id: firebaseUser.uid,
                           email: firebaseUser.email ?? "",
                           fullName: firebaseUser.displayName ?? "",
                           phoneNumber: firebaseUser.phoneNumber ?? "",
                           profileImage: firebaseUser.photoURL?.absoluteString,
                           userType: .parent, // Default, will be updated from backend
                           businessName: nil,
                           businessAddress: nil,
                           children: []
                       )
                } else {
                    self?.isAuthenticated = false
                    self?.currentUser = nil
                }
            }
        }
    }
    
    // MARK: - Sign Up
    func signUp(email: String, password: String, fullName: String, userType: UserType, phoneNumber: String? = nil, businessName: String? = nil, businessAddress: String? = nil, bio: String? = nil) -> AnyPublisher<AuthDataResult, Error> {
        isLoading = true
        errorMessage = nil
        
        return Future { [weak self] promise in
            // Clear any existing Firebase auth state before signup to avoid credential conflicts
            do {
                try Auth.auth().signOut()
                print("🔐 FirebaseAuthService: Cleared existing Firebase auth state before signup")
            } catch {
                print("🔐 FirebaseAuthService: No existing Firebase session to clear (this is OK)")
            }
            
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        print("❌ FirebaseAuthService: Signup error: \(error.localizedDescription)")
                        // Provide more helpful error messages
                        var errorMessage = error.localizedDescription
                        if let nsError = error as NSError? {
                            switch nsError.code {
                            case 17007: // Email already exists
                                errorMessage = "An account with this email already exists. Please sign in instead."
                            case 17008: // Invalid email
                                errorMessage = "Please enter a valid email address."
                            case 17026: // Weak password
                                errorMessage = "Password is too weak. Please use at least 8 characters."
                            default:
                                break
                            }
                        }
                        self?.errorMessage = errorMessage
                        promise(.failure(error))
                        return
                    }
                    
                    guard let result = result else {
                        let error = NSError(domain: "FirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No result from Firebase"])
                        self?.errorMessage = error.localizedDescription
                        promise(.failure(error))
                        return
                    }
                    
                    print("✅ FirebaseAuthService: Firebase user created successfully: \(result.user.uid)")
                    
                    // Update user profile
                    let changeRequest = result.user.createProfileChangeRequest()
                    changeRequest.displayName = fullName
                    
                    changeRequest.commitChanges { error in
                        if let error = error {
                            print("⚠️ FirebaseAuthService: Error updating profile: \(error)")
                            // Don't fail signup if profile update fails
                        } else {
                            print("✅ FirebaseAuthService: Profile updated successfully")
                        }
                        
                        // Create user in backend
                        self?.createUserInBackend(firebaseUser: result.user, fullName: fullName, userType: userType, phoneNumber: phoneNumber, businessName: businessName, businessAddress: businessAddress, bio: bio)
                        
                        promise(.success(result))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) -> AnyPublisher<AuthDataResult, Error> {
        isLoading = true
        errorMessage = nil
        
        return Future { [weak self] promise in
            // Clear any stale Firebase auth state before sign in
            // This helps avoid "malformed or expired credential" errors
            if let currentUser = Auth.auth().currentUser {
                do {
                    try Auth.auth().signOut()
                    print("🔐 FirebaseAuthService: Cleared existing Firebase session before sign in")
                } catch {
                    print("🔐 FirebaseAuthService: Error clearing Firebase session: \(error)")
                }
            }
            
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        print("❌ FirebaseAuthService: Sign-in error: \(error.localizedDescription)")
                        // Provide more helpful error messages
                        var errorMessage = error.localizedDescription
                        if let nsError = error as NSError? {
                            switch nsError.code {
                            case 17011: // User not found
                                errorMessage = "No account found with this email. Please sign up first."
                            case 17009: // Wrong password
                                errorMessage = "Incorrect password. Please try again."
                            case 17020: // Network error
                                errorMessage = "Network error. Please check your connection and try again."
                            case 17026: // Invalid credential
                                errorMessage = "Invalid credentials. Please check your email and password."
                            default:
                                // Check for malformed/expired credential error
                                if error.localizedDescription.contains("malformed") || error.localizedDescription.contains("expired") {
                                    errorMessage = "Authentication session expired. Please try signing in again."
                                }
                            }
                        }
                        self?.errorMessage = errorMessage
                        promise(.failure(error))
                        return
                    }
                    
                    guard let result = result else {
                        let error = NSError(domain: "FirebaseAuth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No result from Firebase"])
                        self?.errorMessage = error.localizedDescription
                        promise(.failure(error))
                        return
                    }
                    
                    print("✅ FirebaseAuthService: Sign-in successful: \(result.user.uid)")
                    
                    // Fetch user data from backend
                    self?.fetchUserFromBackend(firebaseUser: result.user)
                    
                    promise(.success(result))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Sign Out
    func signOut() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
            currentUser = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Password Reset
    func resetPassword(email: String) -> AnyPublisher<Void, Error> {
        isLoading = true
        errorMessage = nil
        
        return Future { [weak self] promise in
            Auth.auth().sendPasswordReset(withEmail: email) { error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = error.localizedDescription
                        promise(.failure(error))
                        return
                    }
                    
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Backend Integration
    private func createUserInBackend(firebaseUser: FirebaseAuth.User, fullName: String, userType: UserType, phoneNumber: String?, businessName: String?, businessAddress: String?, bio: String?) {
        let apiService = APIService.shared
        
        // Get Firebase ID token
        firebaseUser.getIDToken { token, error in
            if let error = error {
                print("Error getting ID token: \(error)")
                return
            }
            
            // Create user in backend with Firebase UID
            let _ = apiService.signup(
                email: firebaseUser.email ?? "",
                password: "", // Not needed for Firebase auth
                fullName: fullName,
                userType: userType,
                phoneNumber: phoneNumber,
                businessName: businessName,
                businessAddress: businessAddress,
                bio: bio
            )
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        print("User created in backend successfully")
                    case .failure(let error):
                        print("Error creating user in backend: \(error)")
                        // If user already exists, that's actually fine - just fetch the user
                        if error.localizedDescription.contains("already exists") || 
                           error.localizedDescription.contains("duplicate") {
                            print("User already exists, fetching user data...")
                            self.fetchUserFromBackend(firebaseUser: firebaseUser)
                        }
                    }
                },
                receiveValue: { authResponse in
                    print("Backend user creation completed")
                }
            )
            .store(in: &apiService.cancellables)
        }
    }
    
    private func fetchUserFromBackend(firebaseUser: FirebaseAuth.User) {
        let apiService = APIService.shared
        
        // Get Firebase ID token
        firebaseUser.getIDToken { token, error in
            if let error = error {
                print("Error getting ID token: \(error)")
                return
            }
            
            // Fetch user data from backend
            apiService.fetchCurrentUser()
        }
    }
}

// MARK: - User Model Extension
extension User {
    init(id: String, email: String, fullName: String, phoneNumber: String, profileImage: String?, userType: UserType, businessName: String?, businessAddress: String?, children: [Child]) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.phoneNumber = phoneNumber
        self.profileImage = profileImage
        self.userType = userType
        self.businessName = businessName
        self.businessAddress = businessAddress
        self.qualifications = nil
        self.dbsCertificate = nil
        self.bio = nil
        self.services = nil
        self.verificationStatus = "pending"
        self.children = children
        self.isActive = true
        self.isEmailVerified = false
        self.createdAt = Date()
        self.updatedAt = Date()
        self.location = nil
    }
}
