import Foundation
import Combine

// MARK: - Models

struct SupportMessage: Codable {
    let id: UUID
    let userId: String?
    let category: ContactCategory
    let message: String
    let timestamp: Date
    let userEmail: String?
    let userName: String?
    
    init(category: ContactCategory, message: String, userEmail: String? = nil, userName: String? = nil) {
        self.id = UUID()
        self.userId = APIService.shared.currentUser?.id
        self.category = category
        self.message = message
        self.timestamp = Date()
        self.userEmail = userEmail
        self.userName = userName
    }
}

struct SupportResponse: Codable {
    let success: Bool
    let message: String
    let ticketId: String?
    let estimatedResponseTime: String?
}

// MARK: - Support Service

class SupportService: ObservableObject {
    static let shared = SupportService()
    
    private let baseURL = "https://api.yugi.com/support" // Mock URL
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Public Methods
    
    func sendSupportMessage(_ supportMessage: SupportMessage) -> AnyPublisher<SupportResponse, Error> {
        // Simulate network delay
        return Future<SupportResponse, Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                // Simulate successful API response
                let response = SupportResponse(
                    success: true,
                    message: "Your support message has been received successfully.",
                    ticketId: "TKT-\(Int.random(in: 10000...99999))",
                    estimatedResponseTime: "24 hours"
                )
                promise(.success(response))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func getSupportHistory() -> AnyPublisher<[SupportMessage], Error> {
        // Simulate fetching support history
        return Future<[SupportMessage], Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let mockHistory = [
                    SupportMessage(
                        category: .booking,
                        message: "I'm having trouble booking a class for my child",
                        userEmail: "user@example.com",
                        userName: "John Doe"
                    ),
                    SupportMessage(
                        category: .payment,
                        message: "My payment was declined, can you help?",
                        userEmail: "user@example.com",
                        userName: "John Doe"
                    )
                ]
                promise(.success(mockHistory))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Mock Admin Methods (for demonstration)
    
    func getAdminSupportMessages() -> AnyPublisher<[SupportMessage], Error> {
        // This would be used by admin dashboard
        return Future<[SupportMessage], Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let mockMessages = [
                    SupportMessage(
                        category: .general,
                        message: "I can't find the class I'm looking for",
                        userEmail: "parent1@example.com",
                        userName: "Sarah Johnson"
                    ),
                    SupportMessage(
                        category: .technical,
                        message: "The app keeps crashing when I try to book",
                        userEmail: "parent2@example.com",
                        userName: "Mike Smith"
                    ),
                    SupportMessage(
                        category: .booking,
                        message: "I need to cancel my booking for tomorrow",
                        userEmail: "parent3@example.com",
                        userName: "Emma Wilson"
                    ),
                    SupportMessage(
                        category: .payment,
                        message: "I was charged twice for the same class",
                        userEmail: "parent4@example.com",
                        userName: "David Brown"
                    )
                ]
                promise(.success(mockMessages))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func markMessageAsResolved(_ messageId: UUID) -> AnyPublisher<Bool, Error> {
        // Simulate marking a message as resolved
        return Future<Bool, Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                promise(.success(true))
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Admin Dashboard View Model

class AdminSupportViewModel: ObservableObject {
    @Published var supportMessages: [SupportMessage] = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let supportService = SupportService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadSupportMessages() {
        isLoading = true
        error = nil
        
        supportService.getAdminSupportMessages()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    self.isLoading = false
                    if case let .failure(error) = completion {
                        self.error = error.localizedDescription
                    }
                },
                receiveValue: { messages in
                    self.supportMessages = messages
                }
            )
            .store(in: &cancellables)
    }
    
    func resolveMessage(_ messageId: UUID) {
        supportService.markMessageAsResolved(messageId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        self.error = error.localizedDescription
                    }
                },
                receiveValue: { success in
                    if success {
                        // Remove from list or mark as resolved
                        self.supportMessages.removeAll { $0.id == messageId }
                    }
                }
            )
            .store(in: &cancellables)
    }
} 