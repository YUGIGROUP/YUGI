import SwiftUI

struct LiveChatScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var messageText = ""
    @State private var messages: [ChatMessage] = []
    @State private var isTyping = false
    @State private var showingTypingIndicator = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat Header
                chatHeader
                
                // Messages
                messagesView
                
                // Input Area
                inputArea
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarHidden(true)
            .onAppear {
                startChat()
            }
        }
    }
    
    private var chatHeader: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text("Live Chat Support")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text("Online")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                Button(action: { /* End chat */ }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.yugiOrange, Color.yugiOrange.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            // Agent Info
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.yugiOrange.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Text("S")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.yugiOrange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sarah")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.yugiGray)
                    
                    Text("Customer Support Agent")
                        .font(.system(size: 12))
                        .foregroundColor(.yugiGray.opacity(0.7))
                }
                
                Spacer()
                
                if showingTypingIndicator {
                    HStack(spacing: 4) {
                        Text("typing")
                            .font(.system(size: 12))
                            .foregroundColor(.yugiGray.opacity(0.7))
                        
                        ChatTypingIndicator()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .onChange(of: messages.count) { oldCount, newCount in
                if let lastMessage = messages.last {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.yugiGray.opacity(0.2))
            
            HStack(spacing: 12) {
                TextField("Type a message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.yugiGray.opacity(0.3), lineWidth: 1)
                    )
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(messageText.isEmpty ? Color.yugiGray.opacity(0.3) : Color.yugiOrange)
                        )
                }
                .disabled(messageText.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.white)
        }
    }
    
    private func startChat() {
        // Add welcome message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let welcomeMessage = ChatMessage(
                id: UUID(),
                text: "Hi! I'm Sarah, your customer support agent. How can I help you today?",
                isFromUser: false,
                timestamp: Date()
            )
            messages.append(welcomeMessage)
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let userMessage = ChatMessage(
            id: UUID(),
            text: messageText,
            isFromUser: true,
            timestamp: Date()
        )
        
        messages.append(userMessage)
        let userText = messageText
        messageText = ""
        
        // Simulate agent response
        simulateAgentResponse(to: userText)
    }
    
    private func simulateAgentResponse(to userMessage: String) {
        showingTypingIndicator = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showingTypingIndicator = false
            
            let response = generateResponse(to: userMessage)
            let agentMessage = ChatMessage(
                id: UUID(),
                text: response,
                isFromUser: false,
                timestamp: Date()
            )
            
            messages.append(agentMessage)
        }
    }
    
    private func generateResponse(to message: String) -> String {
        let lowercased = message.lowercased()
        
        if lowercased.contains("booking") || lowercased.contains("book") {
            return "I can help you with booking issues! Could you tell me more about what you're experiencing? Are you having trouble finding a class, or is there an issue with the booking process?"
        } else if lowercased.contains("payment") || lowercased.contains("pay") || lowercased.contains("card") {
            return "I understand you're having payment issues. What specific problem are you encountering? Is it with adding a payment method, processing a payment, or something else?"
        } else if lowercased.contains("cancel") || lowercased.contains("refund") {
            return "For cancellations and refunds, you can cancel bookings up to 24 hours before the class starts through your bookings tab. Refunds are processed within 5-7 business days. Is there a specific booking you'd like to cancel?"
        } else if lowercased.contains("child") || lowercased.contains("children") {
            return "I can help you manage your children's profiles! You can add, edit, or remove children from your account in the Children tab. What would you like to do?"
        } else if lowercased.contains("class") || lowercased.contains("course") {
            return "I can help you find the right classes for your children! What type of activity are you looking for, and what age are your children? I can suggest some great options."
        } else {
            return "Thank you for your message! I'm here to help with any questions about YUGI. Could you provide a bit more detail about what you need assistance with?"
        }
    }
}

// MARK: - Supporting Views

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer(minLength: 60)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(message.text)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.yugiOrange)
                        )
                    
                    Text(formatTime(message.timestamp))
                        .font(.system(size: 12))
                        .foregroundColor(.yugiGray.opacity(0.7))
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.text)
                        .font(.system(size: 16))
                        .foregroundColor(.yugiGray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.yugiGray.opacity(0.2), lineWidth: 1)
                        )
                    
                    Text(formatTime(message.timestamp))
                        .font(.system(size: 12))
                        .foregroundColor(.yugiGray.opacity(0.7))
                }
                
                Spacer(minLength: 60)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ChatTypingIndicator: View {
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.yugiGray.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .offset(y: animationOffset)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animationOffset
                    )
            }
        }
        .onAppear {
            animationOffset = -5
        }
    }
}

// MARK: - Models

struct ChatMessage: Identifiable {
    let id: UUID
    let text: String
    let isFromUser: Bool
    let timestamp: Date
}

#Preview {
    LiveChatScreen()
} 