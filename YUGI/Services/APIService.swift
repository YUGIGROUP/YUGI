import Foundation
import Combine
import FirebaseAuth

// MARK: - API Environment Configuration
enum APIEnvironment {
    case development
    case production
    
    static var current: APIEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
}

// MARK: - API Configuration
struct APIConfig {
    static var baseURL: String {
        switch APIEnvironment.current {
        case .development:
            #if targetEnvironment(simulator)
            // iOS Simulator can only access localhost
            return "http://localhost:3001/api"
            #else
            // Physical device can access local network IP
            return "http://192.168.1.72:3001/api"
            #endif
        case .production:
            return "https://yugi-production.up.railway.app/api"
        }
    }
    
    static let timeout: TimeInterval = 30
    static let useMockMode = false // Set to false to use real backend
    
    // Debug logging
    static func logBaseURL() {
        print("🔗 APIConfig: Using base URL: \(baseURL)")
        print("🔗 APIConfig: Environment: \(APIEnvironment.current)")
        #if targetEnvironment(simulator)
        print("🔗 APIConfig: Running on iOS Simulator")
        print("🔗 APIConfig: Simulator will connect to: \(baseURL)")
        #else
        print("🔗 APIConfig: Running on physical device")
        print("🔗 APIConfig: Device will connect to: \(baseURL)")
        #endif
        
        // Test network connectivity
        testNetworkConnectivity()
        
        // Additional debugging info
        print("🔗 APIConfig: Current timestamp: \(Date())")
        print("🔗 APIConfig: Bundle identifier: \(Bundle.main.bundleIdentifier ?? "Unknown")")
    }
    
    // Test network connectivity to help debug connection issues
    private static func testNetworkConnectivity() {
        let testURL = "\(baseURL)/health"
        print("🔗 APIConfig: Testing connectivity to: \(testURL)")
        
        guard let url = URL(string: testURL) else {
            print("❌ APIConfig: Invalid test URL")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ APIConfig: Network test failed: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse {
                print("✅ APIConfig: Network test successful - Status: \(httpResponse.statusCode)")
            } else {
                print("❌ APIConfig: Network test failed - No response")
            }
        }
        task.resume()
    }
}

// MARK: - API Errors
enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case networkError(Error)
    case serverError(String)
    case unauthorized
    case forbidden
    case notFound
    case validationError([String])
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL. Please check your connection settings."
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .unauthorized:
            return "Unauthorized access"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .validationError(let errors):
            return "Validation errors: \(errors.joined(separator: ", "))"
        }
    }
}

// MARK: - API Response Models
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let message: String?
    let data: T?
    let errors: [String]?
    let pagination: PaginationInfo?
}

struct PaginationInfo: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let pages: Int
}





// MARK: - API Service
class APIService: ObservableObject, @unchecked Sendable {
    static let shared = APIService()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User? {
        didSet {
            if let user = currentUser {
                // Save user to UserDefaults
                if let encoded = try? JSONEncoder().encode(user) {
                    UserDefaults.standard.set(encoded, forKey: "currentUser")
                    print("🔐 APIService: Saved user to UserDefaults: \(user.fullName)")
                }
            } else {
                // Remove user from UserDefaults
                UserDefaults.standard.removeObject(forKey: "currentUser")
                print("🔐 APIService: Removed user from UserDefaults")
            }
        }
    }
    
    var authToken: String? {
        get { 
            let token = UserDefaults.standard.string(forKey: "authToken")
            print("🔐 APIService: Loading auth token from UserDefaults: \(token?.prefix(20) ?? "None")...")
            return token
        }
        set { 
            UserDefaults.standard.set(newValue, forKey: "authToken")
            print("🔐 APIService: Saved auth token to UserDefaults: \(newValue?.prefix(20) ?? "None")...")
        }
    }
    
    private init() {
        print("🔐 APIService: Initializing...")
        APIConfig.logBaseURL()
        
        // Clear any mock authentication data first
        clearMockAuthenticationData()
        
        // For development/testing, you can uncomment this line to clear cached data on app start
        // clearCachedData()
        
        // Load currentUser from UserDefaults if it exists
        if let userData = UserDefaults.standard.data(forKey: "currentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            print("🔐 APIService: Found existing user data: \(user.fullName) (\(user.userType.rawValue))")
            self.currentUser = user
            self.isAuthenticated = true
        }
        
        // Check if user is already authenticated
        if authToken != nil {
            print("🔐 APIService: Found existing auth token, fetching current user...")
            fetchCurrentUser()
        } else {
            print("🔐 APIService: No auth token found, user not authenticated")
        }
    }
    
    // MARK: - Generic Request Method
    private func request<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: [String: Any]? = nil,
        requiresAuth: Bool = true
    ) -> AnyPublisher<T, APIError> {
        
        let fullURL = "\(APIConfig.baseURL)\(endpoint)"
        print("🔗 APIService: Making request to: \(fullURL)")
        print("🔗 APIService: Method: \(method.rawValue)")
        print("🔗 APIService: Requires auth: \(requiresAuth)")
        
        guard let url = URL(string: fullURL) else {
            print("❌ APIService: Invalid URL: \(fullURL)")
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = APIConfig.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth {
            if let token = authToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                print("🔐 APIService: Added Authorization header with token: \(token.prefix(20))...")
            } else {
                print("❌ APIService: Auth required but no token available")
                return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
            }
        }
        
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            print("🔗 APIService: Request body: \(body)")
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.networkError(NSError(domain: "", code: -1))
                }
                
                print("🔗 APIService: Response status: \(httpResponse.statusCode)")
                print("🔗 APIService: Response headers: \(httpResponse.allHeaderFields)")
                
                // Log raw response for debugging
                print("DEBUG API: Raw response: \(String(data: data, encoding: .utf8) ?? "nil")")
                
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                case 401:
                    print("❌ APIService: Unauthorized (401) - clearing token")
                    DispatchQueue.main.async { [weak self] in
                        self?.authToken = nil
                        self?.isAuthenticated = false
                    }
                    throw APIError.unauthorized
                case 403:
                    throw APIError.forbidden
                case 404:
                    throw APIError.notFound
                default:
                    // Try to parse error message from response
                    if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
                        throw APIError.serverError(errorResponse.message ?? "Server error")
                    }
                    throw APIError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            .decode(type: T.self, decoder: {
                let decoder = JSONDecoder()
                
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)
                    
                    // Create formatters inside the closure to avoid Sendable warnings
                    let iso8601Formatter = ISO8601DateFormatter()
                    
                    let formatter1 = DateFormatter()
                    formatter1.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                    formatter1.timeZone = TimeZone(abbreviation: "UTC")
                    
                    let formatter2 = DateFormatter()
                    formatter2.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                    formatter2.timeZone = TimeZone(abbreviation: "UTC")
                    
                    let formatter3 = DateFormatter()
                    formatter3.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                    formatter3.timeZone = TimeZone(abbreviation: "UTC")
                    
                    // Try multiple date formatters
                    if let date = iso8601Formatter.date(from: dateString) {
                        return date
                    }
                    if let date = formatter1.date(from: dateString) {
                        return date
                    }
                    if let date = formatter2.date(from: dateString) {
                        return date
                    }
                    if let date = formatter3.date(from: dateString) {
                        return date
                    }
                    
                    // If none work, throw a descriptive error
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Date string '\(dateString)' does not match any expected format"
                    )
                }
                
                return decoder
            }())
            .mapError { error in
                print("❌ APIService: Request failed with error: \(error)")
                
                // Enhanced logging for decoding errors
                if let decodingError = error as? DecodingError {
                    print("🔍 APIService: Decoding error details:")
                    switch decodingError {
                    case .dataCorrupted(let context):
                        print("🔍 APIService: Data corrupted at path: \(context.codingPath)")
                        print("🔍 APIService: Debug description: \(context.debugDescription)")
                        if let underlyingError = context.underlyingError {
                            print("🔍 APIService: Underlying error: \(underlyingError)")
                        }
                    case .keyNotFound(let key, let context):
                        print("🔍 APIService: Key '\(key)' not found at path: \(context.codingPath)")
                        print("🔍 APIService: Debug description: \(context.debugDescription)")
                    case .typeMismatch(let type, let context):
                        print("🔍 APIService: Type mismatch for type '\(type)' at path: \(context.codingPath)")
                        print("🔍 APIService: Debug description: \(context.debugDescription)")
                    case .valueNotFound(let type, let context):
                        print("🔍 APIService: Value of type '\(type)' not found at path: \(context.codingPath)")
                        print("🔍 APIService: Debug description: \(context.debugDescription)")
                    @unknown default:
                        print("🔍 APIService: Unknown decoding error: \(decodingError)")
                    }
                    return APIError.decodingError
                }
                
                if let apiError = error as? APIError {
                    return apiError
                }
                return APIError.networkError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Authentication
    func signup(email: String, password: String, fullName: String, userType: UserType, phoneNumber: String? = nil, businessName: String? = nil, businessAddress: String? = nil, bio: String? = nil, profileImage: String? = nil) -> AnyPublisher<AuthResponse, APIError> {
        print("🔐 APIService: Attempting signup for email: \(email), userType: \(userType.rawValue)")
        
        if APIConfig.useMockMode {
            return mockSignup(email: email, password: password, fullName: fullName, userType: userType, phoneNumber: phoneNumber, businessName: businessName, businessAddress: businessAddress)
        }
        
        // Get Firebase UID from current Firebase user
        let firebaseUid = Auth.auth().currentUser?.uid ?? "temp_\(Date().timeIntervalSince1970)_\(UUID().uuidString)"
        
        var body: [String: Any] = [
            "email": email,
            "fullName": fullName,
            "userType": userType.rawValue,
            "firebaseUid": firebaseUid
        ]
        
        if let phoneNumber = phoneNumber {
            body["phoneNumber"] = phoneNumber
        }
        
        if let profileImage = profileImage {
            body["profileImage"] = profileImage
            print("🔐 APIService: Including profile image in signup request")
        }
        
        if userType == .provider {
            guard let businessName = businessName, let businessAddress = businessAddress else {
                return Fail(error: APIError.validationError(["Business name and address required for providers"])).eraseToAnyPublisher()
            }
            
            var businessInfo: [String: Any] = [
                "businessName": businessName,
                "address": businessAddress
            ]
            
            if let bio = bio {
                businessInfo["description"] = bio
            }
            
            body["businessInfo"] = businessInfo
        }
        
        return request(endpoint: "/auth/signup", method: .POST, body: body, requiresAuth: false)
            .handleEvents(receiveOutput: { [weak self] response in
                print("🔐 APIService: Signup successful!")
                print("🔐 APIService: Received token: \(response.token.prefix(20))...")
                print("🔐 APIService: User type: \(response.user.userType.rawValue)")
                print("🔐 APIService: User email: \(response.user.email)")
                print("🔐 APIService: User fullName: \(response.user.fullName)")
                print("🔐 APIService: User phoneNumber: \(response.user.phoneNumber ?? "nil")")
                
                // Update UI properties on main thread
                DispatchQueue.main.async { [weak self] in
                    // Clear any existing user data first to ensure fresh data
                    UserDefaults.standard.removeObject(forKey: "currentUser")
                    print("🔐 APIService: Cleared existing user data from UserDefaults")
                    
                    self?.authToken = response.token
                    self?.isAuthenticated = true
                    self?.currentUser = response.user
                    print("🔐 APIService: Signup complete - Token saved, user authenticated")
                    print("🔐 APIService: Current user set - Email: \(response.user.email), Name: \(response.user.fullName)")
                    
                    // Fetch fresh user data from backend to ensure we have all fields
                    self?.fetchCurrentUser()
                }
            })
            .eraseToAnyPublisher()
    }
    
    func signOut() {
        print("🔐 APIService: Signing out user...")
        self.currentUser = nil
        self.authToken = nil
        self.isAuthenticated = false
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "authToken")
        
        // Clear business profile data to prevent showing wrong user's data
        UserDefaults.standard.removeObject(forKey: "providerBusinessName")
        UserDefaults.standard.removeObject(forKey: "providerBusinessDescription")
        UserDefaults.standard.removeObject(forKey: "providerBusinessServices")
        UserDefaults.standard.removeObject(forKey: "providerContactEmail")
        UserDefaults.standard.removeObject(forKey: "providerContactPhone")
        UserDefaults.standard.removeObject(forKey: "providerWebsite")
        UserDefaults.standard.removeObject(forKey: "providerBusinessAddress")
        UserDefaults.standard.removeObject(forKey: "providerDBSCertificate")
        UserDefaults.standard.removeObject(forKey: "providerQualifications")
        
        print("🔐 APIService: User signed out successfully")
    }
    
    func login(email: String, password: String) -> AnyPublisher<AuthResponse, APIError> {
        print("🔐 APIService: Attempting login for email: \(email)")
        
        if APIConfig.useMockMode {
            return mockLogin(email: email, password: password)
        }
        
        // Get Firebase UID from current Firebase user
        let firebaseUid = Auth.auth().currentUser?.uid ?? "temp_\(Date().timeIntervalSince1970)_\(UUID().uuidString)"
        
        let body = [
            "email": email,
            "firebaseUid": firebaseUid
        ]
        
        return request(endpoint: "/auth/login", method: .POST, body: body, requiresAuth: false)
            .handleEvents(receiveOutput: { [weak self] response in
                print("🔐 APIService: Login successful!")
                print("🔐 APIService: Received token: \(response.token.prefix(20))...")
                print("🔐 APIService: User type: \(response.user.userType.rawValue)")
                
                // Update UI properties on main thread
                DispatchQueue.main.async { [weak self] in
                    // Clear any existing user data first to ensure fresh data
                    UserDefaults.standard.removeObject(forKey: "currentUser")
                    print("🔐 APIService: Cleared existing user data from UserDefaults")
                    
                    // Clear business profile data to prevent showing wrong user's data
                    UserDefaults.standard.removeObject(forKey: "providerBusinessName")
                    UserDefaults.standard.removeObject(forKey: "providerBusinessDescription")
                    UserDefaults.standard.removeObject(forKey: "providerBusinessServices")
                    UserDefaults.standard.removeObject(forKey: "providerContactEmail")
                    UserDefaults.standard.removeObject(forKey: "providerContactPhone")
                    UserDefaults.standard.removeObject(forKey: "providerWebsite")
                    UserDefaults.standard.removeObject(forKey: "providerBusinessAddress")
                    print("🔐 APIService: Cleared business profile data from UserDefaults")
                    
                    self?.authToken = response.token
                    self?.isAuthenticated = true
                    self?.currentUser = response.user
                    print("🔐 APIService: Login complete - Token saved, user authenticated")
                    print("🔐 APIService: Authentication state updated - isAuthenticated: \(self?.isAuthenticated ?? false)")
                    
                    // Reload business profile data from the new user
                    if response.user.userType == .provider {
                        ProviderBusinessService.shared.fetchBusinessInfoFromServer()
                    }
                }
            })
            .eraseToAnyPublisher()
    }
    
    func logout() {
        print("🔐 APIService: Logging out user...")
        print("🔐 APIService: Previous auth token: \(authToken?.prefix(20) ?? "None")...")
        print("🔐 APIService: Previous user: \(currentUser?.fullName ?? "None")")
        
        authToken = nil
        isAuthenticated = false
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "authToken")
        print("🔐 APIService: Logout complete - Token and user data cleared from UserDefaults")
        print("🔐 APIService: Logout complete - isAuthenticated: \(isAuthenticated)")
    }
    
    func clearCachedData() {
        print("🔐 APIService: Clearing cached user data...")
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "authToken")
        currentUser = nil
        authToken = nil
        isAuthenticated = false
        print("🔐 APIService: Cached data cleared")
    }
    
    // MARK: - Password Reset
    
    func forgotPassword(email: String) -> AnyPublisher<APIResponse<EmptyResponse>, APIError> {
        print("🔐 APIService: Requesting password reset for email: \(email)")
        
        if APIConfig.useMockMode {
            return mockForgotPassword(email: email)
        }
        
        let body = ["email": email]
        
        return request(endpoint: "/auth/forgot-password", method: .POST, body: body, requiresAuth: false)
            .eraseToAnyPublisher()
    }
    
    func resetPassword(token: String, newPassword: String) -> AnyPublisher<APIResponse<EmptyResponse>, APIError> {
        print("🔐 APIService: Resetting password with token: \(String(token.prefix(10)))...")
        
        if APIConfig.useMockMode {
            return mockResetPassword(token: token, newPassword: newPassword)
        }
        
        let body = [
            "token": token,
            "newPassword": newPassword
        ]
        
        return request(endpoint: "/auth/reset-password", method: .POST, body: body, requiresAuth: false)
            .eraseToAnyPublisher()
    }
    
    func fetchCurrentUser() {
        print("🔐 APIService: Fetching current user...")
        print("🔐 APIService: Current auth token: \(authToken?.prefix(20) ?? "None")...")
        
        if APIConfig.useMockMode {
            mockFetchCurrentUser()
            return
        }
        
        request(endpoint: "/auth/me")
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case let .failure(error) = completion {
                        print("🔐 APIService: Failed to fetch current user: \(error)")
                        if case .unauthorized = error {
                            print("🔐 APIService: Unauthorized error, clearing token and setting isAuthenticated to false")
                            self?.authToken = nil
                            self?.isAuthenticated = false
                        }
                    }
                },
                receiveValue: { [weak self] (response: UserResponse) in
                    print("🔐 APIService: Successfully fetched current user: \(response.data.fullName)")
                    print("🔐 APIService: User email: \(response.data.email)")
                    print("🔐 APIService: User type: \(response.data.userType.rawValue)")
                    self?.currentUser = response.data
                    self?.isAuthenticated = true
                    print("🔐 APIService: Current user updated - isAuthenticated: \(self?.isAuthenticated ?? false)")
                    
                    // Reload business profile data for providers
                    if response.data.userType == .provider {
                        ProviderBusinessService.shared.fetchBusinessInfoFromServer()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Mock Authentication (for testing without backend)
    private func mockLogin(email: String, password: String) -> AnyPublisher<AuthResponse, APIError> {
        print("🔐 APIService: Mock login for email: \(email)")
        
        // Simulate network delay
        return Future<AuthResponse, APIError> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: DispatchWorkItem {
                let mockUser = User(
                    id: UUID().uuidString,
                    email: email,
                    fullName: "Sarah Johnson",
                    phoneNumber: "+44 123 456 7890",
                    profileImage: "https://images.unsplash.com/photo-1494790108755-2616b612b786?w=150&h=150&fit=crop&crop=face",
                    userType: .parent,
                    businessName: nil,
                    businessAddress: nil,
                    children: []
                )
                
                let mockToken = "mock_jwt_token_for_testing_\(UUID().uuidString)"
                let response = AuthResponse(token: mockToken, user: mockUser)
                
                print("🔐 APIService: Mock login successful! Token: \(String(mockToken.prefix(20)))...")
                print("🔐 APIService: User type: \(mockUser.userType.rawValue)")
                
                self.authToken = mockToken
                self.isAuthenticated = true
                self.currentUser = mockUser
                
                print("🔐 APIService: Authentication state updated - isAuthenticated: \(self.isAuthenticated)")
                
                promise(.success(response))
            })
        }
        .eraseToAnyPublisher()
    }
    
    private func mockSignup(email: String, password: String, fullName: String, userType: UserType, phoneNumber: String? = nil, businessName: String? = nil, businessAddress: String? = nil) -> AnyPublisher<AuthResponse, APIError> {
        print("🔐 APIService: Mock signup for email: \(email), userType: \(userType.rawValue)")
        
        return Future<AuthResponse, APIError> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: DispatchWorkItem {
                let mockUser = User(
                    id: UUID().uuidString,
                    email: email,
                    fullName: fullName,
                    phoneNumber: phoneNumber ?? "+44 123 456 7890",
                    profileImage: "https://picsum.photos/150/150",
                    userType: userType,
                    businessName: businessName,
                    businessAddress: businessAddress,
                    children: []
                )
                
                let mockToken = "mock_jwt_token_for_testing_\(UUID().uuidString)"
                let response = AuthResponse(token: mockToken, user: mockUser)
                
                print("🔐 APIService: Mock signup successful! Token: \(String(mockToken.prefix(20)))...")
                print("🔐 APIService: User type: \(mockUser.userType.rawValue)")
                print("🔐 APIService: Profile image: \(mockUser.profileImage ?? "nil")")
                
                self.authToken = mockToken
                self.isAuthenticated = true
                self.currentUser = mockUser
                
                print("🔐 APIService: Authentication state updated - isAuthenticated: \(self.isAuthenticated)")
                
                promise(.success(response))
            })
        }
        .eraseToAnyPublisher()
    }
    
    private func mockAddChild(name: String, age: Int, dateOfBirth: Date? = nil) -> AnyPublisher<ChildrenResponse, APIError> {
        print("🔐 APIService: Mock adding child - name: \(name), age: \(age)")
        print("🔐 APIService: Current auth token: \(authToken?.prefix(20) ?? "None")...")
        print("🔐 APIService: Is authenticated: \(isAuthenticated)")
        
        return Future<ChildrenResponse, APIError> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: DispatchWorkItem {
                let newChild = Child(
                    childId: UUID().uuidString,
                    childName: name,
                    childAge: age,
                    childDateOfBirth: dateOfBirth
                )
                
                // Create a new user with updated children array
                if let currentUser = self.currentUser {
                    var updatedChildren = currentUser.children ?? []
                    updatedChildren.append(newChild)
                    // Note: This is a simplified approach - in production you'd want to update the existing user object
                    let updatedUser = User(
                        id: currentUser.id,
                        email: currentUser.email,
                        fullName: currentUser.fullName,
                        phoneNumber: currentUser.phoneNumber ?? "",
                        profileImage: currentUser.profileImage,
                        userType: currentUser.userType,
                        businessName: currentUser.businessName,
                        businessAddress: currentUser.businessAddress,
                        children: updatedChildren
                    )
                    self.currentUser = updatedUser
                }
                
                let response = ChildrenResponse(data: [newChild])
                print("🔐 APIService: Mock child added successfully!")
                
                promise(.success(response))
            })
        }
        .eraseToAnyPublisher()
    }
    
    private func mockEditChild(childId: String, name: String, age: Int, dateOfBirth: Date? = nil) -> AnyPublisher<ChildrenResponse, APIError> {
        print("🔐 APIService: Mock editing child - id: \(childId), name: \(name), age: \(age)")
        print("🔐 APIService: Current auth token: \(authToken?.prefix(20) ?? "None")...")
        print("🔐 APIService: Is authenticated: \(isAuthenticated)")
        
        return Future<ChildrenResponse, APIError> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: DispatchWorkItem {
                let updatedChild = Child(
                    childId: childId,
                    childName: name,
                    childAge: age,
                    childDateOfBirth: dateOfBirth
                )
                
                // Update the child in the current user's children array
                if let currentUser = self.currentUser {
                    var updatedChildren = currentUser.children ?? []
                    if let index = updatedChildren.firstIndex(where: { $0.id == childId }) {
                        updatedChildren[index] = updatedChild
                    }
                    
                    let updatedUser = User(
                        id: currentUser.id,
                        email: currentUser.email,
                        fullName: currentUser.fullName,
                        phoneNumber: currentUser.phoneNumber ?? "",
                        profileImage: currentUser.profileImage,
                        userType: currentUser.userType,
                        businessName: currentUser.businessName,
                        businessAddress: currentUser.businessAddress,
                        children: updatedChildren
                    )
                    self.currentUser = updatedUser
                }
                
                let response = ChildrenResponse(data: [updatedChild])
                print("🔐 APIService: Mock child edited successfully!")
                
                promise(.success(response))
            })
        }
        .eraseToAnyPublisher()
    }
    
    private func mockDeleteChild(childId: String) -> AnyPublisher<EmptyResponse, APIError> {
        print("🔐 APIService: Mock deleting child - id: \(childId)")
        print("🔐 APIService: Current auth token: \(authToken?.prefix(20) ?? "None")...")
        print("🔐 APIService: Is authenticated: \(isAuthenticated)")
        
        return Future<EmptyResponse, APIError> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: DispatchWorkItem {
                // Remove the child from the current user's children array
                if let currentUser = self.currentUser {
                    var updatedChildren = currentUser.children ?? []
                    updatedChildren.removeAll { $0.id == childId }
                    
                    let updatedUser = User(
                        id: currentUser.id,
                        email: currentUser.email,
                        fullName: currentUser.fullName,
                        phoneNumber: currentUser.phoneNumber ?? "",
                        profileImage: currentUser.profileImage,
                        userType: currentUser.userType,
                        businessName: currentUser.businessName,
                        businessAddress: currentUser.businessAddress,
                        children: updatedChildren
                    )
                    self.currentUser = updatedUser
                }
                
                let response = EmptyResponse()
                print("🔐 APIService: Mock child deleted successfully!")
                
                promise(.success(response))
            })
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Mock Password Reset
    
    private func mockForgotPassword(email: String) -> AnyPublisher<APIResponse<EmptyResponse>, APIError> {
        print("🔐 APIService: Mock forgot password for email: \(email)")
        
        return Future<APIResponse<EmptyResponse>, APIError> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: DispatchWorkItem {
                print("🔐 APIService: Mock password reset email sent successfully")
                let response = APIResponse<EmptyResponse>(
                    success: true,
                    message: "Password reset email sent successfully",
                    data: nil,
                    errors: nil,
                    pagination: nil
                )
                promise(.success(response))
            })
        }
        .eraseToAnyPublisher()
    }
    
    private func mockResetPassword(token: String, newPassword: String) -> AnyPublisher<APIResponse<EmptyResponse>, APIError> {
        print("🔐 APIService: Mock reset password with token: \(String(token.prefix(10)))...")
        
        return Future<APIResponse<EmptyResponse>, APIError> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: DispatchWorkItem {
                print("🔐 APIService: Mock password reset successful")
                let response = APIResponse<EmptyResponse>(
                    success: true,
                    message: "Password reset successfully",
                    data: nil,
                    errors: nil,
                    pagination: nil
                )
                promise(.success(response))
            })
        }
        .eraseToAnyPublisher()
    }
    
    private func mockFetchCurrentUser() {
        print("🔐 APIService: Mock fetching current user...")
        print("🔐 APIService: Current auth token: \(authToken?.prefix(20) ?? "None")...")
        
        // If we already have user data, don't override it
        if let existingUser = currentUser {
            print("🔐 APIService: User data already exists: \(existingUser.fullName) (\(existingUser.userType.rawValue))")
            self.isAuthenticated = true
            print("🔐 APIService: Current user updated - isAuthenticated: \(self.isAuthenticated)")
            return
        }
        
        // Only create mock user data if we don't have any
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: DispatchWorkItem {
            if self.currentUser == nil {
                print("🔐 APIService: No user data found, creating mock user...")
                // Create a default mock user (this should rarely happen in production)
                let mockUser = User(
                    id: UUID().uuidString,
                    email: "info@yugiapp.ai",
                    fullName: "Mock User",
                    phoneNumber: "+44 123 456 7890",
                    profileImage: nil,
                    userType: .parent,
                    businessName: nil,
                    businessAddress: nil,
                    children: []
                )
                self.currentUser = mockUser
                self.isAuthenticated = true
                print("🔐 APIService: Mock user created: \(mockUser.fullName)")
                print("🔐 APIService: Current user updated - isAuthenticated: \(self.isAuthenticated)")
            }
        })
    }
    
    private func mockUpdateProfile(fullName: String? = nil, email: String? = nil, phoneNumber: String? = nil, profileImage: String? = nil) -> AnyPublisher<UserResponse, APIError> {
        print("🔐 APIService: Mock updating profile...")
        print("🔐 APIService: Current auth token: \(authToken?.prefix(20) ?? "None")...")
        print("🔐 APIService: Is authenticated: \(isAuthenticated)")
        
        return Future<UserResponse, APIError> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: DispatchWorkItem {
                // Update the current user with new data
                if let currentUser = self.currentUser {
                    let updatedUser = User(
                        id: currentUser.id,
                        email: email ?? currentUser.email,
                        fullName: fullName ?? currentUser.fullName,
                        phoneNumber: phoneNumber ?? currentUser.phoneNumber ?? "",
                        profileImage: profileImage ?? currentUser.profileImage,
                        userType: currentUser.userType,
                        businessName: currentUser.businessName,
                        businessAddress: currentUser.businessAddress,
                        children: currentUser.children ?? []
                    )
                    
                    self.currentUser = updatedUser
                    let response = UserResponse(data: updatedUser)
                    
                    print("🔐 APIService: Mock profile updated successfully!")
                    print("🔐 APIService: New fullName: \(updatedUser.fullName)")
                    print("🔐 APIService: New phoneNumber: \(updatedUser.phoneNumber ?? "nil")")
                    
                    promise(.success(response))
                } else {
                    print("🔐 APIService: Mock profile update failed - no current user")
                    promise(.failure(APIError.networkError(NSError(domain: "MockError", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"]))))
                }
            })
        }
        .eraseToAnyPublisher()
    }
    
    private func mockFetchMyClasses(status: String? = nil, page: Int = 1) -> AnyPublisher<ClassesResponse, APIError> {
        print("🔐 APIService: Mock fetchMyClasses called")
        
        // Return empty classes since we're using real backend
        let response = ClassesResponse(data: [], pagination: nil)
        
        return Future { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: DispatchWorkItem {
                print("🔐 APIService: Mock fetchMyClasses returning 0 classes")
                promise(.success(response))
            })
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Classes
    func fetchClasses(category: String? = nil, search: String? = nil, minPrice: Double? = nil, maxPrice: Double? = nil, page: Int = 1) -> AnyPublisher<ClassesResponse, APIError> {
        var queryItems: [String] = []
        
        if let category = category {
            queryItems.append("category=\(category)")
        }
        if let search = search {
            queryItems.append("search=\(search)")
        }
        
        let queryString = queryItems.isEmpty ? "" : "?\(queryItems.joined(separator: "&"))"
        return request(endpoint: "/classes\(queryString)", requiresAuth: false)
    }
    
    func fetchRecommendedClasses(latitude: Double, longitude: Double, category: String? = nil) -> AnyPublisher<ClassesResponse, APIError> {
        var queryItems = [
            "recommend=true",
            "latitude=\(latitude)",
            "longitude=\(longitude)"
        ]
        if let category = category {
            queryItems.append("category=\(category)")
        }
        let queryString = "?\(queryItems.joined(separator: "&"))"
        let fullURL = "\(APIConfig.baseURL)/classes\(queryString)"
        print("DEBUG API: Calling URL: \(fullURL)")
        print("DEBUG API: Auth token exists: \(authToken != nil)")
        return request(endpoint: "/classes\(queryString)", requiresAuth: true)
    }
    
    func fetchClass(id: String) -> AnyPublisher<ClassResponse, APIError> {
        return request(endpoint: "/classes/\(id)", requiresAuth: false)
    }
    
    func createClass(classData: ClassCreationData) -> AnyPublisher<ClassResponse, APIError> {
        print("🔐 APIService: Creating class - name: \(classData.className)")
        print("🔐 APIService: Current auth token: \(authToken?.prefix(20) ?? "None")...")
        print("🔐 APIService: Is authenticated: \(isAuthenticated)")
        
        if APIConfig.useMockMode {
            return mockCreateClass(classData: classData)
        }
        
        var body = classData.toDictionary()
        
        // Add provider ID from current user
        if let currentUser = currentUser, currentUser.userType == .provider {
            body["providerId"] = currentUser.id
        }
        
        return request(endpoint: "/classes", method: .POST, body: body)
    }
    
    func updateClass(id: String, updates: [String: Any]) -> AnyPublisher<ClassResponse, APIError> {
        return request(endpoint: "/classes/\(id)", method: .PUT, body: updates)
    }
    
    func publishClass(id: String) -> AnyPublisher<ClassResponse, APIError> {
        return request(endpoint: "/classes/\(id)/publish", method: .POST)
    }
    
    func unpublishClass(id: String) -> AnyPublisher<ClassResponse, APIError> {
        return request(endpoint: "/classes/\(id)/unpublish", method: .POST)
    }
    
    func deleteClass(id: String) -> AnyPublisher<EmptyResponse, APIError> {
        return request(endpoint: "/classes/\(id)", method: .DELETE)
    }
    
    func fetchMyClasses(status: String? = nil, page: Int = 1) -> AnyPublisher<ClassesResponse, APIError> {
        if APIConfig.useMockMode {
            return mockFetchMyClasses(status: status, page: page)
        }
        
        guard currentUser != nil else {
            return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
        }
        
        var queryItems = ["page=\(page)"]
        if let status = status {
            queryItems.append("status=\(status)")
        }
        let queryString = "?\(queryItems.joined(separator: "&"))"
        return request(endpoint: "/classes/provider/my-classes\(queryString)")
    }
    
    func cancelClass(classId: String, reason: String? = nil) -> AnyPublisher<ClassResponse, APIError> {
        var body: [String: Any] = [:]
        if let reason = reason {
            body["reason"] = reason
        }
        return request(endpoint: "/classes/\(classId)/cancel", method: .PUT, body: body)
    }
    
    func updateClassStatus(classId: String, status: String) -> AnyPublisher<ClassResponse, APIError> {
        let body = ["status": status]
        return request(endpoint: "/classes/\(classId)/status", method: .PUT, body: body)
    }
    
    func analyzeVenue(venueName: String, address: Address) -> AnyPublisher<VenueAnalysisResponse, APIError> {
        let body: [String: Any] = [
            "venueName": venueName,
            "address": [
                "street": address.street,
                "city": address.city,
                "state": address.state,
                "postalCode": address.postalCode,
                "country": address.country
            ]
        ]
        return request(endpoint: "/classes/venues/analyze", method: .POST, body: body)
    }

    func fetchVenueAnalysis(venueName: String, location: String) -> AnyPublisher<VenueAnalysisResponse, APIError> {
        let parts = location.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        // Detect UK postcode: e.g. "TW9 1DN", "SW1A 2AA", "EC1A 1BB"
        let postcodePattern = "^[A-Z]{1,2}[0-9][0-9A-Z]?\\s*[0-9][A-Z]{2}$"
        let postcodeRegex = try? NSRegularExpression(pattern: postcodePattern, options: .caseInsensitive)
        func isPostcode(_ s: String) -> Bool {
            guard let re = postcodeRegex else { return false }
            return re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
        }

        var street = ""
        var city = ""
        var postalCode = ""

        switch parts.count {
        case 1:
            // Single token — postcode or city name
            if isPostcode(parts[0]) { postalCode = parts[0] } else { city = parts[0] }
        case 2:
            // "Street, City" / "City, Postcode" / "Postcode, City"
            if isPostcode(parts[0]) {
                postalCode = parts[0]; city = parts[1]
            } else if isPostcode(parts[1]) {
                city = parts[0]; postalCode = parts[1]
            } else {
                street = parts[0]; city = parts[1]
            }
        default:
            // 3+ parts: first = street, last = postcode (if it looks like one), middle = city
            street = parts[0]
            let last = parts[parts.count - 1]
            if isPostcode(last) {
                postalCode = last
                city = parts[1..<(parts.count - 1)].joined(separator: ", ")
            } else {
                city = parts[1...].joined(separator: ", ")
            }
        }

        let body: [String: Any] = [
            "venueName": venueName,
            "address": [
                "street": street,
                "city": city,
                "state": "",
                "postalCode": postalCode,
                "country": "UK"
            ]
        ]
        return request(endpoint: "/classes/venues/analyze", method: .POST, body: body)
    }

    // MARK: - Saved Venues

    func saveVenue(placeId: String, venueName: String) async -> Bool {
        guard let token = authToken,
              let url = URL(string: "\(APIConfig.baseURL)/saved-venues") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.POST.rawValue
        request.timeoutInterval = APIConfig.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let payload: [String: Any] = [
            "placeId": placeId,
            "venueName": venueName
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200...299).contains(httpResponse.statusCode)
        } catch {
            print("APIService: saveVenue failed for \(placeId): \(error.localizedDescription)")
            return false
        }
    }

    func unsaveVenue(placeId: String) async -> Bool {
        guard let token = authToken,
              let url = URL(string: "\(APIConfig.baseURL)/saved-venues/\(placeId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? placeId)") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.DELETE.rawValue
        request.timeoutInterval = APIConfig.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200...299).contains(httpResponse.statusCode)
        } catch {
            print("APIService: unsaveVenue failed for \(placeId): \(error.localizedDescription)")
            return false
        }
    }

    func isVenueSaved(placeId: String) async -> (saved: Bool, savedAt: Date?) {
        guard let token = authToken,
              let url = URL(string: "\(APIConfig.baseURL)/saved-venues/\(placeId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? placeId)") else {
            return (false, nil)
        }

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.GET.rawValue
        request.timeoutInterval = APIConfig.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return (false, nil)
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(SavedVenueStatusResponse.self, from: data)
            return (payload.saved, payload.savedAt)
        } catch {
            print("APIService: isVenueSaved failed for \(placeId): \(error.localizedDescription)")
            return (false, nil)
        }
    }

    func getPendingPrompt() async -> PendingPrompt? {
        guard let token = authToken,
              let url = URL(string: "\(APIConfig.baseURL)/saved-venues/pending-prompt") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.GET.rawValue
        request.timeoutInterval = APIConfig.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(PendingPromptResponse.self, from: data)
            return payload.pending ? payload.savedVenue : nil
        } catch {
            print("APIService: getPendingPrompt failed: \(error.localizedDescription)")
            return nil
        }
    }

    func markPromptShown(placeId: String) async -> Bool {
        guard let token = authToken,
              let encodedPlaceId = placeId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(APIConfig.baseURL)/saved-venues/\(encodedPlaceId)/mark-prompt-shown") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.POST.rawValue
        request.timeoutInterval = APIConfig.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200...299).contains(httpResponse.statusCode)
        } catch {
            print("APIService: markPromptShown failed for \(placeId): \(error.localizedDescription)")
            return false
        }
    }

    func markNotVisited(placeId: String) async -> Bool {
        guard let token = authToken,
              let encodedPlaceId = placeId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(APIConfig.baseURL)/saved-venues/\(encodedPlaceId)/mark-not-visited") else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.POST.rawValue
        request.timeoutInterval = APIConfig.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200...299).contains(httpResponse.statusCode)
        } catch {
            print("APIService: markNotVisited failed for \(placeId): \(error.localizedDescription)")
            return false
        }
    }

    func submitVenueFeedback(
        placeId: String,
        venueName: String,
        source: String = "save_prompt",
        facts: [VenueFactSubmission],
        overallComment: String? = nil
    ) async -> Bool {
        guard let token = authToken,
              let encodedPlaceId = placeId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "\(APIConfig.baseURL)/venues/\(encodedPlaceId)/feedback") else {
            return false
        }

        struct VenueFeedbackPayload: Encodable {
            let venueName: String
            let source: String
            let facts: [VenueFactSubmission]
            let overallComment: String?
        }

        let payload = VenueFeedbackPayload(
            venueName: venueName,
            source: source,
            facts: facts,
            overallComment: overallComment
        )

        guard let data = try? JSONEncoder().encode(payload) else {
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.POST.rawValue
        request.timeoutInterval = APIConfig.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = data

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return http.statusCode == 200 || http.statusCode == 201
        } catch {
            print("APIService: submitVenueFeedback failed for \(placeId): \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - AI Class Generation

    struct GeneratedClassListing: Codable {
        let className: String
        let category: String
        let description: String
        let ageRange: String
        let price: Double
        let isFree: Bool
        let duration: Int
        let whatToBring: String
        let specialRequirements: String
        // Venue fields are optional — Claude may omit or snake_case them
        let venueName: String?
        let city: String?
        let postalCode: String?
        let streetAddress: String?
    }

    // MARK: - Intake

    func submitIntakeResponse(bookingId: String, classId: String, answers: [[String: String]]) -> AnyPublisher<APIResponse<IntakeResponseData>, APIError> {
        let body: [String: Any] = ["bookingId": bookingId, "classId": classId, "answers": answers]
        return request(endpoint: "/intake", method: .POST, body: body)
    }

    func fetchIntakeResponses(classId: String) -> AnyPublisher<APIResponse<[IntakeResponseData]>, APIError> {
        return request(endpoint: "/intake/class/\(classId)")
    }

    func fetchIntakeResponse(bookingId: String) -> AnyPublisher<APIResponse<IntakeResponseData>, APIError> {
        return request(endpoint: "/intake/booking/\(bookingId)")
    }

    func generateClassListing(prompt: String) async throws -> GeneratedClassListing {
        guard let token = authToken else { throw APIError.unauthorized }
        guard let url = URL(string: "\(APIConfig.baseURL)/classes/generate") else { throw APIError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 30

        let body: [String: String] = ["prompt": prompt]
        urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError("AI generation failed")
        }

        struct Wrapper: Codable { let data: GeneratedClassListing }
        // Use convertFromSnakeCase so both venueName and venue_name work
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let wrapper = try decoder.decode(Wrapper.self, from: data)
        return wrapper.data
    }

    // MARK: - Bookings
    func createBooking(classId: String, children: [Child], sessionDate: Date, sessionTime: String, specialRequests: String? = nil) -> AnyPublisher<(BookingResponse, String), APIError> {
        guard let currentUser = currentUser else {
            return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
        }
        
        let dateFormatter = ISO8601DateFormatter()
        var body: [String: Any] = [
            "parentId": currentUser.id,
            "classId": classId,
            "children": children.map { ["name": $0.name, "age": $0.age] },
            "numberOfChildren": children.count,
            "sessionDate": dateFormatter.string(from: sessionDate),
            "sessionTime": sessionTime
        ]
        
        if let specialRequests = specialRequests {
            body["specialRequests"] = specialRequests
        }
        
        let fullURL = "\(APIConfig.baseURL)/bookings"
        guard let url = URL(string: fullURL) else {
            return Fail(error: APIError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = APIConfig.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
        }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        print("🔗 APIService: Making booking request to: \(fullURL)")
        print("🔗 APIService: Request body: \(body)")
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> (BookingResponse, String) in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.networkError(NSError(domain: "", code: -1))
                }
                
                print("🔗 APIService: Booking response status: \(httpResponse.statusCode)")
                
                // Log raw response for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("🔍 APIService: Raw booking response: \(jsonString)")
                }
                
                // Handle error responses first
                switch httpResponse.statusCode {
                case 200...299:
                    // Extract MongoDB ObjectId from raw JSON before decoding (only for success responses)
                    var mongoObjectId: String?
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            print("🔍 APIService: Parsed JSON keys: \(json.keys)")
                            
                            if let dataDict = json["data"] as? [String: Any] {
                                print("🔍 APIService: Data dict keys: \(dataDict.keys)")
                                
                                if let id = dataDict["_id"] as? String {
                                    mongoObjectId = id
                                    print("💳 APIService: Extracted MongoDB ObjectId from raw JSON: \(id)")
                                } else {
                                    print("❌ APIService: _id not found in data dict or not a string. _id value: \(String(describing: dataDict["_id"]))")
                                }
                            } else {
                                print("❌ APIService: 'data' key not found or not a dictionary")
                            }
                        }
                    } catch {
                        print("❌ APIService: Failed to parse JSON: \(error)")
                    }
                    
                    guard let objectId = mongoObjectId else {
                        print("❌ APIService: Failed to extract MongoDB ObjectId from response")
                        throw APIError.decodingError
                    }
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .custom { decoder in
                        let container = try decoder.singleValueContainer()
                        let dateString = try container.decode(String.self)
                        let formatter = ISO8601DateFormatter()
                        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        if let date = formatter.date(from: dateString) {
                            return date
                        }
                        formatter.formatOptions = [.withInternetDateTime]
                        if let date = formatter.date(from: dateString) {
                            return date
                        }
                        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(dateString)")
                    }
                    let bookingResponse = try decoder.decode(BookingResponse.self, from: data)
                    return (bookingResponse, objectId)
                case 400:
                    // Handle validation errors and business logic errors (like "Class is full")
                    // Try to extract error message from response
                    var errorMessage = "Bad request"
                    do {
                        // Try parsing as simple message object
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let message = json["message"] as? String {
                            errorMessage = message
                        } else if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
                            errorMessage = errorResponse.message ?? "Bad request"
                        }
                    } catch {
                        print("⚠️ APIService: Could not parse error message from 400 response")
                    }
                    print("❌ APIService: Booking failed: \(errorMessage)")
                    throw APIError.serverError(errorMessage)
                case 401:
                    throw APIError.unauthorized
                case 403:
                    throw APIError.forbidden
                case 404:
                    throw APIError.notFound
                default:
                    if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
                        throw APIError.serverError(errorResponse.message ?? "Server error")
                    }
                    throw APIError.serverError("HTTP \(httpResponse.statusCode)")
                }
            }
            .mapError { error -> APIError in
                if let apiError = error as? APIError {
                    return apiError
                }
                return APIError.networkError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func fetchBookings(status: String? = nil, page: Int = 1) -> AnyPublisher<BookingsResponse, APIError> {
        guard let currentUser = currentUser else {
            return Fail(error: APIError.unauthorized).eraseToAnyPublisher()
        }
        
        var queryItems = ["userId=\(currentUser.id)", "userType=\(currentUser.userType.rawValue)"]
        if let status = status {
            queryItems.append("status=\(status)")
        }
        let queryString = "?\(queryItems.joined(separator: "&"))"
        return request(endpoint: "/bookings\(queryString)")
    }
    
    func fetchBooking(id: String) -> AnyPublisher<BookingResponse, APIError> {
        return request(endpoint: "/bookings/\(id)")
    }
    
    func cancelBooking(id: String, reason: String? = nil) -> AnyPublisher<BookingResponse, APIError> {
        var body: [String: Any] = [:]
        if let reason = reason {
            body["reason"] = reason
        }
        return request(endpoint: "/bookings/\(id)/cancel", method: .PUT, body: body)
    }
    
    func completeBooking(id: String) -> AnyPublisher<BookingResponse, APIError> {
        return request(endpoint: "/bookings/\(id)/complete", method: .PUT)
    }
    
    func confirmBooking(id: String) -> AnyPublisher<BookingResponse, APIError> {
        return request(endpoint: "/bookings/\(id)/confirm", method: .PUT)
    }
    
    // MARK: - Payments
    func createPaymentIntent(bookingId: String) -> AnyPublisher<PaymentIntentResponse, APIError> {
        print("💳 APIService: Creating payment intent for booking: \(bookingId)")
        let body = ["bookingId": bookingId]
        return request(endpoint: "/payments/create-payment-intent", method: .POST, body: body)
            .handleEvents(receiveOutput: { response in
                print("✅ APIService: Payment intent created successfully")
                print("💳 APIService: Payment intent ID: \(response.paymentIntentId)")
                print("💳 APIService: Client secret: \(response.clientSecret.prefix(20))...")
            }, receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ APIService: Failed to create payment intent: \(error)")
                }
            })
            .eraseToAnyPublisher()
    }
    
    func confirmPayment(paymentIntentId: String, bookingId: String) -> AnyPublisher<BookingResponse, APIError> {
        print("💳 APIService: Confirming payment")
        print("💳 APIService: Payment intent ID: \(paymentIntentId)")
        print("💳 APIService: Booking ID: \(bookingId)")
        let body = [
            "paymentIntentId": paymentIntentId,
            "bookingId": bookingId
        ]
        return request(endpoint: "/payments/confirm-payment", method: .POST, body: body)
            .handleEvents(receiveOutput: { response in
                print("✅ APIService: Payment confirmed successfully")
                print("💳 APIService: Booking ID: \(response.data.id)")
            }, receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ APIService: Failed to confirm payment: \(error)")
                    print("❌ APIService: APIError type: \(error)")
                    print("❌ APIService: APIError description: \(error.localizedDescription)")
                }
            })
            .eraseToAnyPublisher()
    }
    
    // MARK: - Provider Specific
    func fetchProviderDashboard() -> AnyPublisher<ProviderDashboardResponse, APIError> {
        return request(endpoint: "/providers/dashboard")
    }
    
    func updateBusinessInfo(businessName: String? = nil, businessAddress: String? = nil, phoneNumber: String? = nil, bio: String? = nil, services: String? = nil) -> AnyPublisher<UserResponse, APIError> {
        var body: [String: Any] = [:]
        if let businessName = businessName {
            body["businessName"] = businessName
        }
        if let businessAddress = businessAddress {
            body["businessAddress"] = businessAddress
        }
        if let phoneNumber = phoneNumber {
            body["phoneNumber"] = phoneNumber
        }
        if let bio = bio {
            body["bio"] = bio
        }
        if let services = services {
            body["services"] = services
        }
        
        print("🔍 APIService - updateBusinessInfo called with body: \(body)")
        return request(endpoint: "/providers/business-info", method: .PUT, body: body)
    }
    
    func fetchVerificationStatus() -> AnyPublisher<VerificationStatusResponse, APIError> {
        return request(endpoint: "/providers/verification-status")
    }
    
    func requestVerification() -> AnyPublisher<VerificationStatusResponse, APIError> {
        return request(endpoint: "/providers/request-verification", method: .POST)
    }
    
    func fetchAnalytics(period: Int = 30) -> AnyPublisher<AnalyticsResponse, APIError> {
        return request(endpoint: "/providers/analytics?period=\(period)")
    }
    
    // MARK: - Provider Information
    func fetchProviderInfo(providerId: String) -> AnyPublisher<ProviderInfoResponse, APIError> {
        return request(endpoint: "/users/provider/\(providerId)", method: .GET)
    }
    
    // MARK: - User Profile
    func updateProfile(fullName: String? = nil, email: String? = nil, phoneNumber: String? = nil, profileImage: String? = nil) -> AnyPublisher<UserResponse, APIError> {
        print("🔐 APIService: Updating profile - fullName: \(fullName ?? "nil"), email: \(email ?? "nil"), phoneNumber: \(phoneNumber ?? "nil")")
        print("🔐 APIService: Current auth token: \(authToken?.prefix(20) ?? "None")...")
        print("🔐 APIService: Is authenticated: \(isAuthenticated)")
        
        if APIConfig.useMockMode {
            return mockUpdateProfile(fullName: fullName, email: email, phoneNumber: phoneNumber, profileImage: profileImage)
        }
        
        var body: [String: Any] = [:]
        if let fullName = fullName {
            body["fullName"] = fullName
        }
        if let email = email {
            body["email"] = email
        }
        if let phoneNumber = phoneNumber {
            body["phoneNumber"] = phoneNumber
        }
        if let profileImage = profileImage {
            body["profileImage"] = profileImage
        }
        return request(endpoint: "/users/profile", method: .PUT, body: body)
    }
    
    func addChild(name: String, age: Int, dateOfBirth: Date? = nil) -> AnyPublisher<ChildrenResponse, APIError> {
        print("🔐 APIService: Adding child - name: \(name), age: \(age)")
        print("🔐 APIService: Current auth token: \(authToken?.prefix(20) ?? "None")...")
        print("🔐 APIService: Is authenticated: \(isAuthenticated)")
        
        if APIConfig.useMockMode {
            return mockAddChild(name: name, age: age, dateOfBirth: dateOfBirth)
        }
        
        var body: [String: Any] = [
            "name": name,
            "age": age
        ]
        if let dateOfBirth = dateOfBirth {
            let formatter = ISO8601DateFormatter()
            body["dateOfBirth"] = formatter.string(from: dateOfBirth)
        }
        return request(endpoint: "/users/children", method: .POST, body: body)
            .handleEvents(receiveOutput: { [weak self] _ in
                // Refresh current user data after adding a child to get updated children list
                print("🔐 APIService: Child added successfully, refreshing current user data...")
                self?.fetchCurrentUser()
            })
            .eraseToAnyPublisher()
    }
    
    func editChild(childId: String, name: String, age: Int, dateOfBirth: Date? = nil) -> AnyPublisher<ChildrenResponse, APIError> {
        print("🔐 APIService: Editing child - id: \(childId), name: \(name), age: \(age)")
        print("🔐 APIService: Current auth token: \(authToken?.prefix(20) ?? "None")...")
        print("🔐 APIService: Is authenticated: \(isAuthenticated)")
        
        if APIConfig.useMockMode {
            return mockEditChild(childId: childId, name: name, age: age, dateOfBirth: dateOfBirth)
        }
        
        var body: [String: Any] = [
            "name": name,
            "age": age
        ]
        if let dateOfBirth = dateOfBirth {
            let formatter = ISO8601DateFormatter()
            body["dateOfBirth"] = formatter.string(from: dateOfBirth)
        }
        return request(endpoint: "/users/children/\(childId)", method: .PUT, body: body)
            .handleEvents(receiveOutput: { [weak self] _ in
                // Refresh current user data after editing a child to get updated children list
                print("🔐 APIService: Child edited successfully, refreshing current user data...")
                self?.fetchCurrentUser()
            })
            .eraseToAnyPublisher()
    }
    
    func deleteChild(childId: String) -> AnyPublisher<EmptyResponse, APIError> {
        print("🔐 APIService: Deleting child - id: \(childId)")
        print("🔐 APIService: Current auth token: \(authToken?.prefix(20) ?? "None")...")
        print("🔐 APIService: Is authenticated: \(isAuthenticated)")
        
        if APIConfig.useMockMode {
            return mockDeleteChild(childId: childId)
        }
        
        return request(endpoint: "/users/children/\(childId)", method: .DELETE)
            .handleEvents(receiveOutput: { [weak self] _ in
                // Refresh current user data after deleting a child to get updated children list
                print("🔐 APIService: Child deleted successfully, refreshing current user data...")
                self?.fetchCurrentUser()
            })
            .eraseToAnyPublisher()
    }
    
    // MARK: - Testing Helper
    func forceAuthenticateForTesting(userType: UserType = .parent) {
        print("🔐 APIService: Force authenticating for testing with userType: \(userType.rawValue)...")
        
        let mockUser: User
        
        if userType == .provider {
            mockUser = User(
                id: UUID().uuidString,
                email: "info@yugiapp.ai",
                fullName: "Provider User",
                phoneNumber: "+44 123 456 7890",
                profileImage: "https://picsum.photos/150/150",
                userType: .provider,
                businessName: "Test Business",
                businessAddress: "123 Test Street, London",
                children: []
            )
        } else {
            mockUser = User(
                id: UUID().uuidString,
                email: "info@yugiapp.ai",
                fullName: "Sarah Johnson",
                phoneNumber: "+44 123 456 7890",
                profileImage: "https://picsum.photos/150/150",
                userType: .parent,
                businessName: nil,
                businessAddress: nil,
                children: []
            )
        }
        
        let mockToken = "mock_jwt_token_for_testing_\(UUID().uuidString)"
        self.authToken = mockToken
        self.isAuthenticated = true
        self.currentUser = mockUser
        
        print("🔐 APIService: Force authentication complete")
        print("🔐 APIService: isAuthenticated = \(isAuthenticated)")
        print("🔐 APIService: authToken = \(authToken?.prefix(20) ?? "None")...")
        print("🔐 APIService: currentUser = \(currentUser?.fullName ?? "None")")
        print("🔐 APIService: userType = \(currentUser?.userType.rawValue ?? "None")")
    }
    
    // MARK: - Temporary Testing Helper (Remove after testing)
    func clearUserDefaultsForTesting() {
        print("🔐 APIService: Clearing UserDefaults for testing...")
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "currentUser")
        self.authToken = nil
        self.isAuthenticated = false
        self.currentUser = nil
        print("🔐 APIService: UserDefaults cleared")
    }
    
    // MARK: - Clear All App Data (for testing)
    func clearAllAppData() {
        print("🔐 APIService: Clearing all app data...")
        
        // Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        
        // Clear specific keys
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "currentUser")
        UserDefaults.standard.removeObject(forKey: "providerDBSCertificate")
        UserDefaults.standard.removeObject(forKey: "providerDBSUploaded")
        UserDefaults.standard.removeObject(forKey: "providerQualifications")
        UserDefaults.standard.removeObject(forKey: "providerQualificationsUploaded")
        
        // Reset service state
        self.authToken = nil
        self.isAuthenticated = false
        self.currentUser = nil
        
        print("🔐 APIService: All app data cleared")
    }
    
    // MARK: - Clear Mock Authentication Data
    func clearMockAuthenticationData() {
        print("🔐 APIService: Clearing mock authentication data...")
        
        // Check if current token is a mock token
        if let token = authToken, token.hasPrefix("mock") {
            print("🔐 APIService: Found mock token, clearing authentication data")
            UserDefaults.standard.removeObject(forKey: "authToken")
            UserDefaults.standard.removeObject(forKey: "currentUser")
            self.authToken = nil
            self.isAuthenticated = false
            self.currentUser = nil
            print("🔐 APIService: Mock authentication data cleared")
        } else {
            print("🔐 APIService: No mock token found, keeping current authentication")
        }
    }
    

    
    // MARK: - Generic Request Method (Public)
    
    func makeRequest<T: Codable>(
        endpoint: String,
        method: HTTPMethod = .GET,
        body: [String: Any]? = nil,
        queryParams: [String: String]? = nil,
        requiresAuth: Bool = true
    ) async throws -> APIResponse<T> {
        var fullEndpoint = endpoint
        
        // Add query parameters if provided
        if let queryParams = queryParams, !queryParams.isEmpty {
            let queryString = queryParams.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            fullEndpoint = "\(endpoint)?\(queryString)"
        }
        
        let fullURL = "\(APIConfig.baseURL)\(fullEndpoint)"
        print("🔗 APIService: Making request to: \(fullURL)")
        print("🔗 APIService: Method: \(method.rawValue)")
        print("🔗 APIService: Requires auth: \(requiresAuth)")
        
        guard let url = URL(string: fullURL) else {
            print("❌ APIService: Invalid URL: \(fullURL)")
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = APIConfig.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if requiresAuth {
            if let token = authToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                print("🔐 APIService: Added Authorization header with token: \(token.prefix(20))...")
            } else {
                print("❌ APIService: Auth required but no token available")
                throw APIError.unauthorized
            }
        }
        
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            print("🔗 APIService: Request body: \(body)")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "", code: -1))
        }
        
        print("🔗 APIService: Response status: \(httpResponse.statusCode)")
        print("🔗 APIService: Response headers: \(httpResponse.allHeaderFields)")
        
        // Log raw response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🔍 APIService: Raw JSON response: \(jsonString)")
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decoder = JSONDecoder()
                
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateString = try container.decode(String.self)
                    
                    // Create formatters inside the closure to avoid Sendable warnings
                    let iso8601Formatter = ISO8601DateFormatter()
                    
                    let formatter1 = DateFormatter()
                    formatter1.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
                    formatter1.timeZone = TimeZone(abbreviation: "UTC")
                    
                    let formatter2 = DateFormatter()
                    formatter2.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                    formatter2.timeZone = TimeZone(abbreviation: "UTC")
                    
                    let formatter3 = DateFormatter()
                    formatter3.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                    formatter3.timeZone = TimeZone(abbreviation: "UTC")
                    
                    // Try ISO8601 first
                    if let date = iso8601Formatter.date(from: dateString) {
                        return date
                    }
                    
                    // Try custom formatters
                    if let date = formatter1.date(from: dateString) {
                        return date
                    }
                    
                    if let date = formatter2.date(from: dateString) {
                        return date
                    }
                    
                    if let date = formatter3.date(from: dateString) {
                        return date
                    }
                    
                    // Try parsing as timestamp
                    if let timestamp = Double(dateString) {
                        return Date(timeIntervalSince1970: timestamp)
                    }
                    
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date string \(dateString)")
                }
                
                let result = try decoder.decode(APIResponse<T>.self, from: data)
                return result
            } catch {
                print("❌ APIService: Decoding error: \(error)")
                throw APIError.decodingError
            }
        case 401:
            print("❌ APIService: Unauthorized (401) - clearing token")
            // Since class is @MainActor, we can directly update properties
            self.authToken = nil
            self.isAuthenticated = false
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        default:
            // Try to parse error message from response
            if let errorResponse = try? JSONDecoder().decode(APIResponse<String>.self, from: data) {
                throw APIError.serverError(errorResponse.message ?? "Server error")
            }
            throw APIError.serverError("HTTP \(httpResponse.statusCode)")
        }
    }
    
    // MARK: - Private Properties
    var cancellables = Set<AnyCancellable>()
    
    // MARK: - Class Management
    
    func getProviderClasses() -> AnyPublisher<ClassesResponse, APIError> {
        print("🔐 APIService: Getting provider classes")
        print("🔐 APIService: Current auth token: \(authToken?.prefix(20) ?? "None")...")
        print("🔐 APIService: Is authenticated: \(isAuthenticated)")
        
        if APIConfig.useMockMode {
            return mockGetProviderClasses()
        }
        
        return request(endpoint: "/classes/provider/my-classes?page=1", method: .GET)
    }
    
    // MARK: - Mock Class Methods
    
    private func mockCreateClass(classData: ClassCreationData) -> AnyPublisher<ClassResponse, APIError> {
        print("🔐 APIService: Mock creating class...")
        
        return Future<ClassResponse, APIError> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let mockClass = Class(
                    id: "mock-class-\(UUID().uuidString)",
                    name: classData.className,
                    description: classData.description,
                    category: classData.category,
                    provider: "mock-provider-\(UUID().uuidString)", providerName: "Mock Provider",
                    location: Location(
                        id: "mock-location-\(UUID().uuidString)",
                        name: classData.location,
                        address: Address(
                            street: classData.location,
                            city: "London",
                            state: "England",
                            postalCode: "SW1A 1AA",
                            country: "United Kingdom"
                        ),
                        coordinates: Location.Coordinates(latitude: 51.5074, longitude: -0.1278),
                        accessibilityNotes: nil,
                        parkingInfo: nil,
                        babyChangingFacilities: nil
                    ),
                    schedule: Schedule(
                        startDate: Date(),
                        endDate: Date().addingTimeInterval(86400 * 30), // 30 days
                        recurringDays: ["monday"],
                        timeSlots: classData.timeSlots.map { slot in
                            Schedule.TimeSlot(
                                startTime: slot.startTime,
                                duration: TimeInterval(classData.duration * 60)
                            )
                        },
                        totalSessions: 10
                    ),
                    pricing: Pricing(
                        amount: Decimal(classData.price),
                        currency: "GBP",
                        type: .perSession,
                        description: nil
                    ),
                    maxCapacity: classData.maxCapacity,
                    currentEnrollment: 0,
                    averageRating: 0.0,
                    ageRange: classData.ageRange,
                    isFavorite: false,
                    isActive: true,
                    doability: nil, venueAccessibility: nil, intakeQuestions: nil, googlePlaceId: nil
                )
                
                let response = ClassResponse(data: mockClass)
                promise(.success(response))
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func mockGetProviderClasses() -> AnyPublisher<ClassesResponse, APIError> {
        print("🔐 APIService: Mock getting provider classes...")
        
        return Future<ClassesResponse, APIError> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let mockClasses: [Class] = [] // Empty for now
                let response = ClassesResponse(data: mockClasses, pagination: nil)
                promise(.success(response))
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - HTTP Method
enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
}

// MARK: - Response Models
struct AuthResponse: Codable {
    let token: String
    let user: User
    
    // Regular initializer for creating instances in code
    init(token: String, user: User) {
        self.token = token
        self.user = user
    }
    
    // Handle both wrapped and unwrapped response formats
    enum CodingKeys: String, CodingKey {
        case token, user, success, message
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle wrapped response format: {"success":true,"message":"...","token":"...","user":{...}}
        if container.contains(.success) {
            // Wrapped format - ignore success and message, decode token and user
            self.token = try container.decode(String.self, forKey: .token)
            self.user = try container.decode(User.self, forKey: .user)
        } else {
            // Unwrapped format: {"token":"...","user":{...}}
            self.token = try container.decode(String.self, forKey: .token)
            self.user = try container.decode(User.self, forKey: .user)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(token, forKey: .token)
        try container.encode(user, forKey: .user)
    }
}

struct UserResponse: Codable {
    let data: User
}

struct ClassesResponse: Codable {
    let data: [Class]
    let pagination: PaginationInfo?
}

struct ClassResponse: Codable {
    let data: Class
}

struct VenueAnalysisResponse: Codable {
    let data: VenueAnalysisAPIData
}

struct SavedVenueStatusResponse: Codable {
    let saved: Bool
    let savedAt: Date?
}

struct PendingPrompt: Codable {
    let placeId: String
    let venueName: String
    let savedAt: Date
}

struct PendingPromptResponse: Codable {
    let pending: Bool
    let savedVenue: PendingPrompt?
}

struct VenueFactSubmission: Encodable {
    let factPath: String
    let agreed: Bool
    let comment: String?
}

struct VenueAnalysisAPIData: Codable {
    let venueName: String
    let placeId: String?
    let address: Address
    let coordinates: VenueCoordinates?
    let parkingInfo: String
    let babyChangingFacilities: String
    let accessibilityNotes: String?
    let venueAccessibility: VenueAccessibility?
    let formattedAddress: String?
    let source: String
    let lastUpdated: String
      enum CodingKeys: String, CodingKey {
        case venueName
        case placeId
        case address
        case coordinates
        case parkingInfo
        case babyChangingFacilities
        case accessibilityNotes
        case venueAccessibility
        case formattedAddress
        case source
        case lastUpdated
    }
    
    struct VenueCoordinates: Codable {
        let latitude: Double
        let longitude: Double
    }
}

struct BookingsResponse: Codable {
    let data: [Booking]
    let pagination: PaginationInfo?
}

struct BookingResponse: Codable {
    let data: Booking
}

struct PaymentIntentResponse: Codable {
    let clientSecret: String
    let paymentIntentId: String
}

struct ProviderDashboardResponse: Codable {
    let data: ProviderDashboardData
}

struct ProviderDashboardData: Codable {
    let stats: APIProviderStats
    let recentBookings: [Booking]
    let verificationStatus: String
}

struct APIProviderStats: Codable {
    let totalClasses: Int
    let publishedClasses: Int
    let totalBookings: Int
    let totalRevenue: Double
}

struct ProviderInfoResponse: Codable {
    let success: Bool
    let data: ProviderInfo
}

struct ProviderInfo: Codable {
    let id: String
    let fullName: String?
    let businessName: String?
    let businessAddress: String?
    let phoneNumber: String?
    let email: String
    let profileImage: String?
    let qualifications: String?
    let dbsCertificate: String?
    let verificationStatus: String?
    let bio: String?
    let services: String?
    let createdAt: String
}

struct VerificationStatusResponse: Codable {
    let data: VerificationStatusData
}

struct VerificationStatusData: Codable {
    let verificationStatus: String
    let qualifications: String?
    let dbsCertificate: String?
    let businessName: String?
    let businessAddress: String?
}

struct AnalyticsResponse: Codable {
    let data: AnalyticsData
}

struct AnalyticsData: Codable {
    let period: Int
    let bookings: BookingStats
    let revenue: Double
    let averageRating: Double
    let totalClasses: Int
}

struct BookingStats: Codable {
    let total: Int
    let confirmed: Int
    let completed: Int
    let cancelled: Int
}

struct ChildrenResponse: Codable {
    let data: [Child]
}


struct EmptyResponse: Codable {}

struct IntakeAnswerData: Codable {
    let questionText: String
    let answerType: String
    let answer: String
}

struct ParentInfo: Codable {
    let id: String
    let email: String?
    let fullName: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case email, fullName
    }
}

struct IntakeResponseData: Codable {
    let id: String
    let bookingId: String
    let classId: String
    let parentId: ParentInfo
    let providerId: String
    let answers: [IntakeAnswerData]
    let submittedAt: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case bookingId, classId, parentId, providerId, answers, submittedAt
    }
}

// MARK: - Extensions
extension ClassCreationData {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "tier": tier.rawValue,
            "name": className,
            "description": description,
            "category": category.rawValue,
            "isFree": isFree,
            "price": price,
            "adultsPaySame": adultsPaySame,
            "adultPrice": adultPrice,
            "adultsFree": adultsFree,
            "individualChildSpots": individualChildSpots.rawValue,
            "siblingPairs": siblingPairs.rawValue,
            "siblingPrice": siblingPrice,
            "maxCapacity": maxCapacity,
            "duration": duration,
            "ageRange": ageRange,
            "classDates": classDates.map { formatDate($0.date) },
            "timeSlots": timeSlots.map { [
                "startTime": formatTime($0.startTime),
                "endTime": formatTime(Calendar.current.date(byAdding: .minute, value: duration, to: $0.startTime) ?? $0.startTime)
            ] }
        ]
        
        // Add structured location data
        if !venueName.isEmpty || !streetAddress.isEmpty || !city.isEmpty || !postalCode.isEmpty || latitude != 0.0 || longitude != 0.0 {
            var locationData: [String: Any] = [:]
            
            if !venueName.isEmpty {
                locationData["name"] = venueName
            }
            
            var addressData: [String: Any] = [:]
            if !streetAddress.isEmpty {
                addressData["street"] = streetAddress
            }
            if !city.isEmpty {
                addressData["city"] = city
            }
            if !postalCode.isEmpty {
                addressData["postalCode"] = postalCode
            }
            addressData["country"] = "United Kingdom" // Default country
            
            if !addressData.isEmpty {
                locationData["address"] = addressData
            }
            
            if latitude != 0.0 && longitude != 0.0 {
                locationData["coordinates"] = [
                    "latitude": latitude,
                    "longitude": longitude
                ]
            }
            
            if !locationData.isEmpty {
                dict["location"] = locationData
            }
        }
        
        if !whatToBring.isEmpty {
            dict["whatToBring"] = whatToBring
        }
        if !specialRequirements.isEmpty {
            dict["specialRequirements"] = specialRequirements
        }
        if !intakeQuestions.isEmpty {
            dict["intakeQuestions"] = intakeQuestions.map { q in
                var qDict: [String: Any] = [
                    "questionText": q.questionText,
                    "answerType": q.answerType.rawValue,
                    "isRequired": q.isRequired
                ]
                if !q.options.isEmpty {
                    qDict["options"] = q.options
                }
                return qDict
            }
        }
        
        return dict
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
} 
