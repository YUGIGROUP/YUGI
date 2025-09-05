import SwiftUI

struct ProviderChildrenBookingsScreen: View {
    let businessName: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var sharedBookingService = SharedBookingService.shared
    @StateObject private var providerChildrenService = ProviderChildrenService.shared
    @State private var selectedFilter: BookingFilter = .all
    @State private var showingCancelConfirmation = false
    @State private var bookingToCancel: EnhancedBooking? = nil
    @State private var showingRefundPolicy = false
    @State private var showingAddChild = false
    @State private var showingEditChild = false
    @State private var childToEdit: Child? = nil
    @State private var selectedTab = 0
    @State private var selectedBookingForAnalysis: EnhancedBooking? = nil
    
    enum BookingFilter: String, CaseIterable {
        case all = "All"
        case upcoming = "Upcoming"
        case completed = "Completed"
        case cancelled = "Cancelled"
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Children Bookings")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Classes booked for your children")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.8)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // Tab Selector
                HStack(spacing: 0) {
                    ProviderChildrenTabButton(
                        title: "Bookings",
                        isSelected: selectedTab == 0
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTab = 0
                        }
                    }
                    
                    ProviderChildrenTabButton(
                        title: "My Children",
                        isSelected: selectedTab == 1
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedTab = 1
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)
                .background(Color(hex: "#BC6C5C"))
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    // Bookings Tab
                    bookingsTab
                        .tag(0)
                    
                    // Children Management Tab
                    childrenTab
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .background(Color(hex: "#BC6C5C").ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)

            .alert("Cancel Booking", isPresented: $showingCancelConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Yes, Cancel", role: .destructive) {
                    if let booking = bookingToCancel {
                        cancelBooking(booking)
                    }
                }
            } message: {
                Text("Are you sure you want to cancel this booking? This action cannot be undone.")
            }
            .alert("Refund Policy", isPresented: $showingRefundPolicy) {
                Button("OK") { }
            } message: {
                Text("Cancellations made more than 24 hours before the class start time are eligible for a full refund. Cancellations made within 24 hours are non-refundable.")
            }
            .sheet(isPresented: $showingAddChild) {
                AddChildScreen { newChild in
                    providerChildrenService.addChild(newChild)
                    print("👶 ProviderChildrenBookings: Added child: \(newChild.name)")
                }
            }
            .sheet(isPresented: $showingEditChild) {
                if let childToEdit = childToEdit {
                    AddChildScreen(childToEdit: childToEdit) { updatedChild in
                        providerChildrenService.updateChild(updatedChild)
                        print("👶 ProviderChildrenBookings: Updated child: \(updatedChild.name)")
                    } onDelete: { childId in
                        providerChildrenService.removeChild(withId: childId)
                        print("👶 ProviderChildrenBookings: Deleted child with ID: \(childId)")
                    }
                }
            }
            .onAppear {
                print("🎫 ProviderChildrenBookings: Screen loaded")
                print("🎫 ProviderChildrenBookings: Total bookings: \(sharedBookingService.bookings.count)")
            }
            .navigationDestination(item: $selectedBookingForAnalysis) { enhancedBooking in
                VenueAnalysisScreen(enhancedBooking: enhancedBooking)
            }
        }
    }
    
    private var bookingsTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Latest Upcoming Booking
                let upcomingBookings = getFilteredBookings().filter { $0.booking.status == .upcoming }
                
                if !upcomingBookings.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Latest Upcoming Booking")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        // Show only the most recent upcoming booking
                        if let latestBooking = upcomingBookings.sorted(by: { $0.booking.bookingDate < $1.booking.bookingDate }).first {
                            BookingCard(
                                booking: latestBooking.booking, 
                                enhancedBooking: latestBooking,
                                onCancel: {
                                    bookingToCancel = latestBooking
                                    showingCancelConfirmation = true
                                },
                                onVenueAnalysis: {
                                    print("🎫 ProviderChildrenBookings: Venue Analysis button tapped")
                                    print("🎫 ProviderChildrenBookings: Enhanced booking found, setting selectedBookingForAnalysis")
                                    selectedBookingForAnalysis = latestBooking
                                }
                            )
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("No Upcoming Bookings")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Your children don't have any upcoming classes booked.")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(20)
        }
    }
    
    private var childrenTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Children List
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("My Children")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: {
                            showingAddChild = true
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                Text("Add Child")
                                    .font(.system(size: 16, weight: .medium))
                            }
                            .foregroundColor(Color(hex: "#BC6C5C"))
                        }
                    }
                    
                    if providerChildrenService.children.isEmpty {
                        ProviderChildrenEmptyStateView(
                            icon: "person.2.fill",
                            title: "No Children Added",
                            message: "Add your children to start booking classes for them"
                        ) {
                            showingAddChild = true
                        }
                    } else {
                        ForEach(providerChildrenService.children, id: \.id) { child in
                            ChildCard(child: child) {
                                childToEdit = child
                                showingEditChild = true
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }
    
    private func getFilteredBookings() -> [EnhancedBooking] {
        let allEnhancedBookings = Array(sharedBookingService.enhancedBookings.values)
        
        // Filter bookings for provider's children
        let childrenBookings = allEnhancedBookings.filter { enhancedBooking in
            // Check if any of the selected children belong to this provider
            if let selectedChildren = enhancedBooking.booking.selectedChildren {
                return selectedChildren.contains { child in
                    providerChildrenService.children.contains { $0.id == child.id }
                }
            }
            return false
        }
        
        // Apply filter
        switch selectedFilter {
        case .all:
            return childrenBookings
        case .upcoming:
            return childrenBookings.filter { $0.booking.status == .upcoming }
        case .completed:
            return childrenBookings.filter { $0.booking.status == .completed }
        case .cancelled:
            return childrenBookings.filter { $0.booking.status == .cancelled }
        }
    }
    
    private func cancelBooking(_ enhancedBooking: EnhancedBooking) {
        print("🎫 ProviderChildrenBookings: Cancelling booking \(enhancedBooking.booking.id)")
        
        // Update the booking status to cancelled
        var updatedBooking = enhancedBooking.booking
        updatedBooking.status = .cancelled
        
        // Create new enhanced booking with updated status
        let updatedEnhancedBooking = EnhancedBooking(booking: updatedBooking, classInfo: enhancedBooking.classInfo)
        
        // Update in shared service by removing old booking and adding updated one
        sharedBookingService.enhancedBookings.removeValue(forKey: enhancedBooking.booking.id)
        sharedBookingService.enhancedBookings[updatedBooking.id] = updatedEnhancedBooking
        
        // Also update the regular bookings array
        if let index = sharedBookingService.bookings.firstIndex(where: { $0.id == enhancedBooking.booking.id }) {
            sharedBookingService.bookings[index] = updatedBooking
        }
        
        // Show refund policy
        showingRefundPolicy = true
        
        print("🎫 ProviderChildrenBookings: Booking cancelled successfully")
    }
}

// MARK: - Supporting Views

struct ProviderChildrenTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.white.opacity(0.2) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

struct ProviderChildrenEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.yugiGray.opacity(0.3))
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.yugiGray)
                
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.yugiGray.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            Button(action: action) {
                Text("Add Child")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#BC6C5C"))
                    .cornerRadius(8)
            }
        }
        .padding(32)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct ProviderChildrenBookingCard: View {
    let enhancedBooking: EnhancedBooking
    let onCancel: () -> Void
    
    private var statusColor: Color {
        switch enhancedBooking.booking.status {
        case .pending: return .yellow
        case .upcoming: return .green
        case .completed: return .blue
        case .cancelled: return .red
        case .draft: return .gray
        case .inProgress: return .orange
        }
    }
    
    private var statusText: String {
        switch enhancedBooking.booking.status {
        case .pending: return "Pending"
        case .upcoming: return "Upcoming"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .draft: return "Draft"
        case .inProgress: return "In Progress"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(enhancedBooking.className)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text(enhancedBooking.providerName)
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("£\(NSDecimalNumber(decimal: enhancedBooking.price).doubleValue, specifier: "%.2f")")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text(formatDate(enhancedBooking.booking.bookingDate))
                        .font(.system(size: 12))
                        .foregroundColor(.yugiGray.opacity(0.7))
                }
            }
            
            // Status and Actions
            HStack {
                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor)
                    .cornerRadius(6)
                
                Spacer()
                
                if enhancedBooking.booking.status == .upcoming {
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
                }
            }
            
            // Special Requirements (if any)
            if let requirements = enhancedBooking.booking.specialRequirements, !requirements.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Special Requirements:")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.yugiGray)
                    
                    Text(requirements)
                        .font(.system(size: 13))
                        .foregroundColor(.yugiGray.opacity(0.8))
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color(hex: "#BC6C5C").opacity(0.05))
                .cornerRadius(6)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ProviderChildrenEmptyBookingsView: View {
    let filter: ProviderChildrenBookingsScreen.BookingFilter
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#BC6C5C").opacity(0.6))
            
            Text(emptyStateTitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.yugiGray)
                .multilineTextAlignment(.center)
            
            Text(emptyStateMessage)
                .font(.system(size: 14))
                .foregroundColor(.yugiGray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
    
    private var emptyStateTitle: String {
        switch filter {
        case .all: return "No Bookings Yet"
        case .upcoming: return "No Upcoming Bookings"
        case .completed: return "No Completed Bookings"
        case .cancelled: return "No Cancelled Bookings"
        }
    }
    
    private var emptyStateMessage: String {
        switch filter {
        case .all: return "When you book classes for your children, they'll appear here."
        case .upcoming: return "You don't have any upcoming bookings for your children."
        case .completed: return "Completed bookings will appear here once classes are finished."
        case .cancelled: return "Cancelled bookings will appear here."
        }
    }
} 

 