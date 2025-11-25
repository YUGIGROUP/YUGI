import Foundation

enum OpenAIError: Error {
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse
    case rateLimitExceeded
    case contextLengthExceeded
    case unknownError(String)
    
    var userMessage: String {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key. Please check your configuration."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Received invalid response from the server."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .contextLengthExceeded:
            return "The conversation is too long. Please start a new chat."
        case .unknownError(let message):
            return "An error occurred: \(message)"
        }
    }
}

actor OpenAIService {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-3.5-turbo"
    
    // Usage tracking
    private var totalTokensUsed: Int = 0
    private var estimatedCost: Double = 0.0
    private let inputTokenCost = 0.0015 / 1000.0  // $0.0015 per 1K tokens
    private let outputTokenCost = 0.002 / 1000.0   // $0.002 per 1K tokens
    
    struct OpenAIMessage: Codable {
        let role: String
        let content: String
    }
    
    struct ChatRequest: Codable {
        let model: String
        let messages: [OpenAIMessage]
        let temperature: Double
        let max_tokens: Int
    }
    
    struct Usage: Codable {
        let prompt_tokens: Int
        let completion_tokens: Int
        let total_tokens: Int
    }
    
    struct ChatResponse: Codable {
        struct Choice: Codable {
            let message: OpenAIMessage
            let finish_reason: String
        }
        
        let choices: [Choice]
        let usage: Usage
    }
    
    init(apiKey: String) {
        self.apiKey = apiKey
        #if DEBUG
        print("OpenAIService initialized with key starting with: \(apiKey.prefix(7))...")
        #endif
    }
    
    nonisolated var usageStats: String {
        Task {
            let tokens = await totalTokensUsed
            let cost = await estimatedCost
            return "Total tokens used: \(tokens)\nEstimated cost: $\(String(format: "%.2f", cost))"
        }
        return "Loading usage stats..."
    }
    
    struct UsageReport {
        let totalTokens: Int
        let estimatedCost: Double
    }
    
    func getUsageReport() -> UsageReport {
        UsageReport(totalTokens: totalTokensUsed, estimatedCost: estimatedCost)
    }
    
    private func updateUsage(usage: Usage) {
        totalTokensUsed += usage.total_tokens
        let inputCost = Double(usage.prompt_tokens) * inputTokenCost
        let outputCost = Double(usage.completion_tokens) * outputTokenCost
        estimatedCost += inputCost + outputCost
        
        #if DEBUG
        print("""
        === Message Usage ===
        Input Tokens: \(usage.prompt_tokens)
        Output Tokens: \(usage.completion_tokens)
        Total Tokens: \(usage.total_tokens)
        Cost: $\(String(format: "%.4f", inputCost + outputCost))
        =================
        """)
        #endif
    }
    
    func sendMessage(_ messages: [OpenAIMessage]) async throws -> String {
        guard !apiKey.isEmpty else {
            print("❌ Error: API key is empty")
            throw OpenAIError.invalidAPIKey
        }
        
        guard apiKey.starts(with: "sk-") else {
            print("❌ Error: API key doesn't start with 'sk-'")
            throw OpenAIError.invalidAPIKey
        }
        
        let request = ChatRequest(
            model: model,
            messages: messages,
            temperature: 0.7,
            max_tokens: 1000
        )
        
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Error: Invalid response type")
                throw OpenAIError.invalidResponse
            }
            
            #if DEBUG
            print("📡 API Response Status Code: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
                print("❌ Error Response: \(errorBody)")
            }
            #endif
            
            switch httpResponse.statusCode {
            case 200:
                let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
                guard let message = chatResponse.choices.first?.message.content else {
                    throw OpenAIError.invalidResponse
                }
                
                // Update usage tracking
                updateUsage(usage: chatResponse.usage)
                
                return message
                
            case 401:
                print("❌ Authentication Error: Invalid API key")
                throw OpenAIError.invalidAPIKey
            case 429:
                print("❌ Rate Limit Error")
                throw OpenAIError.rateLimitExceeded
            case 400:
                let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Bad Request Error: \(errorString)")
                if errorString.contains("context length") {
                    throw OpenAIError.contextLengthExceeded
                }
                throw OpenAIError.unknownError(errorString)
            default:
                print("❌ Unknown Error: Status \(httpResponse.statusCode)")
                throw OpenAIError.unknownError("Status code: \(httpResponse.statusCode)")
            }
        } catch let error as OpenAIError {
            throw error
        } catch {
            print("❌ Network Error: \(error.localizedDescription)")
            throw OpenAIError.networkError(error)
        }
    }
} 