import SwiftUI

// MARK: - Message Type
struct Message: Identifiable {
    let id: UUID
    let content: String
    let isUser: Bool
    let timestamp: Date
    let isWelcomeMessage: Bool
    
    init(content: String, isUser: Bool, isWelcomeMessage: Bool = false) {
        self.id = UUID()
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
        self.isWelcomeMessage = isWelcomeMessage
    }
}

@MainActor
class AIViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var currentInput = ""
    @Published var isTyping = false
    @Published var error: String?
    @Published var selectedAgeGroup: AgeGroup?
    @Published var userName: String = ""
    @Published var shouldShowClassDiscovery = false
    @Published var usageReport: String = "Loading usage data..."
    
    let openAI: OpenAIService
    let locationService: LocationService
    let bookingService: BookingService
    
    // Make initialPrompt nonisolated
    nonisolated static func initialPrompt(userName: String) -> String {
        return "Hi \(userName)! I'm here to help you find the perfect classes for you and your little one. To get started, you can either:\n\n1. Use the quick buttons above to select an age group\n2. Or share your location to find classes near you"
    }
    
    enum AgeGroup: String, CaseIterable {
        case baby = "Baby (0-12 months)"
        case toddler = "Toddler (1-3 years)"
        case wellness = "Parent & Child Wellness"
        
        var prompt: String {
            switch self {
            case .baby:
                return "I'm looking for baby classes (0-12 months). Can you help me find activities like baby massage, sensory play, or music classes?"
            case .toddler:
                return "I need toddler classes (1-3 years). Can you suggest activities like movement, art, swimming, or playgroups?"
            case .wellness:
                return "I'm interested in parent and child wellness classes, like postnatal yoga or parent fitness with childcare. What's available?"
            }
        }
    }
    
    init(userName: String = "there") {
        self.openAI = OpenAIService(apiKey: AppConfig.openAIApiKey)
        self.locationService = LocationService()
        let calendarService = CalendarService()
        self.bookingService = BookingService(calendarService: calendarService)
        self.userName = userName
        // Add initial AI message
        messages.append(Message(content: Self.initialPrompt(userName: userName), isUser: false, isWelcomeMessage: true))
    }
    
    func selectAgeGroup(_ ageGroup: AgeGroup) {
        selectedAgeGroup = ageGroup
        currentInput = ageGroup.prompt
        sendMessage()
    }
    
    func shareLocation() {
        locationService.requestLocationPermission()
        messages.append(Message(content: "I'd like to find classes near me", isUser: true))
        shouldShowClassDiscovery = true
    }
    
    func sendMessage() {
        Task {
            await sendMessageAsync()
        }
    }
    
    private func sendMessageAsync() async {
        guard !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = Message(content: currentInput, isUser: true)
        messages.append(userMessage)
        
        // Clear input and show typing indicator
        currentInput = ""
        isTyping = true
        error = nil
        
        // Check if message is about location or finding nearby classes
        if userMessage.content.lowercased().contains("near") || 
           userMessage.content.lowercased().contains("location") ||
           userMessage.content.lowercased().contains("around") ||
           userMessage.content.lowercased().contains("nearby") {
            shareLocation()
            isTyping = false
            return
        }
        
        do {
            // Create system message
            let systemMessage = OpenAIService.Message(
                role: "system",
                content: AppConfig.aiSystemPrompt
            )
            
            // Convert conversation history to OpenAI format
            let historyMessages = messages.map { message in
                OpenAIService.Message(
                    role: message.isUser ? "user" : "assistant",
                    content: message.content
                )
            }
            
            // Combine messages
            var apiMessages = [systemMessage]
            apiMessages.append(contentsOf: historyMessages)
            
            // Get AI response
            let response = try await openAI.sendMessage(apiMessages)
            
            // Add AI response to messages
            messages.append(Message(content: response, isUser: false))
        } catch let error as OpenAIError {
            self.error = error.userMessage
        } catch {
            self.error = "An unexpected error occurred. Please try again."
        }
        
        isTyping = false
    }
    
    func updateUsageReport() async {
        let report = await openAI.getUsageReport()
        usageReport = """
        === OpenAI Usage Report ===
        Total Tokens Used: \(report.totalTokens)
        Estimated Cost: $\(String(format: "%.3f", report.estimatedCost))
        =========================
        """
    }
}

struct AIInteractionScreen: View {
    @StateObject private var viewModel: AIViewModel
    @State private var showingUsageReport = false
    
    init(userName: String = "there") {
        _viewModel = StateObject(wrappedValue: AIViewModel(userName: userName))
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.yugiOrange
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                QuickActionsBar(viewModel: viewModel)
                MessagesView(viewModel: viewModel)
                InputBar(viewModel: viewModel)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Find Classes")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.yugiOrange, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await viewModel.updateUsageReport()
                        showingUsageReport = true
                    }
                }) {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $viewModel.shouldShowClassDiscovery) {
            ClassDiscoveryView(
                locationService: viewModel.locationService,
                bookingService: viewModel.bookingService
            )
        }
        .alert("Usage Report", isPresented: $showingUsageReport) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.usageReport)
        }
    }
}

// MARK: - Quick Actions Bar
private struct QuickActionsBar: View {
    @ObservedObject var viewModel: AIViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AIViewModel.AgeGroup.allCases, id: \.self) { ageGroup in
                    QuickActionButton(
                        title: ageGroup.rawValue,
                        isSelected: viewModel.selectedAgeGroup == ageGroup
                    ) {
                        viewModel.selectAgeGroup(ageGroup)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color.yugiOrange.opacity(0.8))
    }
}

// MARK: - Messages View
private struct MessagesView: View {
    @ObservedObject var viewModel: AIViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if let firstMessage = viewModel.messages.first,
                       firstMessage.isWelcomeMessage {
                        WelcomeMessage(content: firstMessage.content)
                    }
                    
                    ForEach(Array(viewModel.messages.dropFirst())) { message in
                        if message.isUser {
                            MessageBubble(message: message)
                                .id(message.id)
                        } else {
                            AIResponseBubble(message: message)
                                .id(message.id)
                        }
                    }
                    
                    if viewModel.isTyping {
                        TypingIndicator()
                    }
                    
                    if let error = viewModel.error {
                        ErrorView(message: error)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .onChange(of: viewModel.messages.count) { oldCount, newCount in
                    withAnimation {
                        proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Welcome Message
private struct WelcomeMessage: View {
    let content: String
    
    var body: some View {
        Text(content)
            .font(.roboto(size: 18))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding()
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Input Bar
private struct InputBar: View {
    @ObservedObject var viewModel: AIViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white)
            HStack(spacing: 12) {
                TextField("Ask about classes or share your location...", text: $viewModel.currentInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.roboto(size: 16))
                    .disabled(viewModel.isTyping)
                    .foregroundColor(.yugiOrange)
                
                SendButton(viewModel: viewModel)
            }
            .padding()
        }
        .background(Color.yugiOrange)
    }
}

// MARK: - Send Button
private struct SendButton: View {
    @ObservedObject var viewModel: AIViewModel
    
    var body: some View {
        Button(action: viewModel.sendMessage) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.white)
        }
        .disabled(
            viewModel.isTyping ||
            viewModel.currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
    }
}

struct QuickActionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.roboto(size: 14))
                .foregroundColor(isSelected ? .yugiOrange : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.white : Color.white.opacity(0.2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

struct AIResponseBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(message.content)
                    .font(.roboto(size: 16))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                Text(message.timestamp, style: .time)
                    .font(.robotoThin(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
    }
}

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isUser { Spacer() }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.roboto(size: 16))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                Text(message.timestamp, style: .time)
                    .font(.robotoThin(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            if !message.isUser { Spacer() }
        }
    }
}

struct ErrorView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .font(.roboto(size: 14))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.red.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct TypingIndicator: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)
                    .offset(y: animationOffset)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(0.2 * Double(index)),
                        value: animationOffset
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onAppear {
            animationOffset = -5
        }
    }
} 