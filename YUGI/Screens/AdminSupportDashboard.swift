import SwiftUI

struct AdminSupportDashboard: View {
    @StateObject private var viewModel = AdminSupportViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Support Dashboard")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Manage support messages from parents")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.yugiOrange, Color.yugiOrange.opacity(0.8)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        if viewModel.isLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Loading support messages...")
                                    .font(.system(size: 16))
                                    .foregroundColor(.yugiGray)
                            }
                            .padding(.vertical, 40)
                        } else if let error = viewModel.error {
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.red)
                                Text("Error loading messages")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.yugiGray)
                                Text(error)
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 40)
                        } else if viewModel.supportMessages.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.green)
                                Text("No pending messages")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.yugiGray)
                                Text("All support messages have been resolved")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yugiGray.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 40)
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.supportMessages, id: \.id) { message in
                                    SupportMessageCard(
                                        message: message,
                                        onResolve: {
                                            viewModel.resolveMessage(message.id)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.yugiOrange, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        viewModel.loadSupportMessages()
                    }
                    .foregroundColor(.white)
                }
            }
            .onAppear {
                viewModel.loadSupportMessages()
            }
        }
    }
}

// MARK: - Supporting Views

struct SupportMessageCard: View {
    let message: SupportMessage
    let onResolve: () -> Void
    @State private var showingDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.userName ?? "Anonymous")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.yugiGray)
                    
                    Text(message.userEmail ?? "No email provided")
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray.opacity(0.7))
                }
                
                Spacer()
                
                CategoryBadge(category: message.category)
            }
            
            Text(message.message)
                .font(.system(size: 14))
                .foregroundColor(.yugiGray)
                .lineLimit(3)
            
            HStack {
                Text(formatDate(message.timestamp))
                    .font(.system(size: 12))
                    .foregroundColor(.yugiGray.opacity(0.6))
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("View Details") {
                        showingDetails = true
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.yugiOrange)
                    
                    Button("Resolve") {
                        onResolve()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.green)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showingDetails) {
            SupportMessageDetailView(message: message)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct CategoryBadge: View {
    let category: ContactCategory
    
    var body: some View {
        Text(category.displayName.replacingOccurrences(of: "\n", with: " "))
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(category.color)
            .cornerRadius(8)
    }
}

struct SupportMessageDetailView: View {
    let message: SupportMessage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // User Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("From")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.yugiGray)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(message.userName ?? "Anonymous")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.yugiGray)
                            
                            if let email = message.userEmail {
                                Text(email)
                                    .font(.system(size: 16))
                                    .foregroundColor(.yugiOrange)
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    
                    // Category
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Category")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.yugiGray)
                        
                        CategoryBadge(category: message.category)
                            .padding(16)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    
                    // Message
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Message")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.yugiGray)
                        
                        Text(message.message)
                            .font(.system(size: 16))
                            .foregroundColor(.yugiGray)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    
                    // Timestamp
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Received")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.yugiGray)
                        
                        Text(formatDate(message.timestamp))
                            .font(.system(size: 16))
                            .foregroundColor(.yugiGray)
                            .padding(16)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(20)
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationTitle("Message Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    AdminSupportDashboard()
} 