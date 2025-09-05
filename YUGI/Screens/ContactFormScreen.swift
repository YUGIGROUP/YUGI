import SwiftUI
import Combine

class ContactFormViewModel: ObservableObject {
    @Published var message = ""
    @Published var selectedCategory: ContactCategory = .general
    @Published var isSubmitting = false
    @Published var showingSuccess = false
    @Published var error: String?
    @Published var showingError = false
    
    private let supportService = SupportService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func submitForm(userEmail: String?, userName: String?) {
        isSubmitting = true
        error = nil
        
        let supportMessage = SupportMessage(
            category: selectedCategory,
            message: message,
            userEmail: userEmail,
            userName: userName
        )
        
        supportService.sendSupportMessage(supportMessage)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    self.isSubmitting = false
                    if case let .failure(error) = completion {
                        self.error = error.localizedDescription
                        self.showingError = true
                    }
                },
                receiveValue: { [weak self] response in
                    guard let self = self else { return }
                    if response.success {
                        self.showingSuccess = true
                    } else {
                        self.error = response.message
                        self.showingError = true
                    }
                }
            )
            .store(in: &cancellables)
    }
}

struct ContactFormScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ContactFormViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Contact Support")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Send us a message and we'll get back to you as soon as possible")
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
                        // Category Selection
                        categorySection
                        
                        // Message Field
                        messageSection
                        
                        // Submit Button
                        submitButton
                    }
                    .padding(20)
                }
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarHidden(true)
            .alert("Message Sent", isPresented: $viewModel.showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for contacting us. We'll get back to you within 24 hours.")
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") {
                    viewModel.showingError = false
                }
            } message: {
                if let error = viewModel.error {
                    Text(error)
                }
            }
        }
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What can we help you with?")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.yugiGray)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(ContactCategory.allCases, id: \ .self) { category in
                    CategorySelectionCard(
                        category: category,
                        isSelected: viewModel.selectedCategory == category
                    ) {
                        viewModel.selectedCategory = category
                    }
                }
            }
        }
    }
    
    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Message")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.yugiGray)
            
            TextField("Please provide details about your issue...", text: $viewModel.message, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(5...10)
                .padding(16)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
    
    private var submitButton: some View {
        Button(action: {
            viewModel.submitForm(userEmail: APIService.shared.currentUser?.email, userName: APIService.shared.currentUser?.fullName)
        }) {
            HStack {
                if viewModel.isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18))
                }
                
                Text(viewModel.isSubmitting ? "Sending..." : "Send Message")
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
        .disabled(viewModel.isSubmitting || viewModel.message.isEmpty)
        .opacity((viewModel.message.isEmpty) ? 0.6 : 1.0)
        .padding(.top, 8)
    }
}

// MARK: - Supporting Views

struct CategorySelectionCard: View {
    let category: ContactCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : category.color)
                
                Text(category.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .yugiGray)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? category.color : Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : category.color.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Models

enum ContactCategory: String, CaseIterable, Codable {
    case general = "general"
    case booking = "booking"
    case payment = "payment"
    case technical = "technical"
    case feedback = "feedback"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .general: return "General\nInquiry"
        case .booking: return "Booking\nIssue"
        case .payment: return "Payment\nProblem"
        case .technical: return "Technical\nSupport"
        case .feedback: return "Feedback\n& Suggestions"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "questionmark.circle.fill"
        case .booking: return "calendar.badge.clock"
        case .payment: return "creditcard.fill"
        case .technical: return "wrench.and.screwdriver.fill"
        case .feedback: return "star.bubble.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .general: return .blue
        case .booking: return .green
        case .payment: return .orange
        case .technical: return .purple
        case .feedback: return .pink
        case .other: return .gray
        }
    }
}

#Preview {
    ContactFormScreen()
} 