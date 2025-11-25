import SwiftUI

struct ViewHistoryScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedStatus: ClassStatus? = nil
    @State private var showingFilters = false
    
    // Sample data - in a real app this would come from an API
    @State private var bookings: [Booking] = [
        Booking(
            id: UUID(),
            classId: "mock-class-id-1",
            userId: UUID(),
            status: ClassStatus.completed,
            bookingDate: Date().addingTimeInterval(-86400 * 30), // 30 days ago
            numberOfParticipants: 2,
            selectedChildren: nil,
            specialRequirements: "Allergy: nuts",
            attended: true
        ),
        Booking(
            id: UUID(),
            classId: "mock-class-id-1",
            userId: UUID(),
            status: ClassStatus.completed,
            bookingDate: Date().addingTimeInterval(-86400 * 60), // 60 days ago
            numberOfParticipants: 1,
            selectedChildren: nil,
            specialRequirements: nil,
            attended: true
        ),
        Booking(
            id: UUID(),
            classId: "mock-class-id-1",
            userId: UUID(),
            status: ClassStatus.completed,
            bookingDate: Date().addingTimeInterval(-86400 * 90), // 90 days ago
            numberOfParticipants: 3,
            selectedChildren: nil,
            specialRequirements: "Wheelchair accessible",
            attended: true
        ),
        Booking(
            id: UUID(),
            classId: "mock-class-id-1",
            userId: UUID(),
            status: ClassStatus.cancelled,
            bookingDate: Date().addingTimeInterval(-86400 * 45), // 45 days ago
            numberOfParticipants: 1,
            selectedChildren: nil,
            specialRequirements: nil,
            attended: false
        ),
        Booking(
            id: UUID(),
            classId: "mock-class-id-1",
            userId: UUID(),
            status: ClassStatus.completed,
            bookingDate: Date().addingTimeInterval(-86400 * 120), // 120 days ago
            numberOfParticipants: 2,
            selectedChildren: nil,
            specialRequirements: "Extra attention needed",
            attended: true
        ),
        Booking(
            id: UUID(),
            classId: "mock-class-id-1",
            userId: UUID(),
            status: ClassStatus.completed,
            bookingDate: Date().addingTimeInterval(-86400 * 150), // 150 days ago
            numberOfParticipants: 1,
            selectedChildren: nil,
            specialRequirements: nil,
            attended: true
        )
    ]
    
    private var filteredBookings: [Booking] {
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        
        return bookings.filter { booking in
            // Filter by date (last 6 months)
            let isWithinSixMonths = booking.bookingDate >= sixMonthsAgo
            
            // Filter by search text
            let matchesSearch = searchText.isEmpty || 
                "Class Name".localizedCaseInsensitiveContains(searchText) ||
                "Provider Name".localizedCaseInsensitiveContains(searchText)
            
            // Filter by status
            let matchesStatus = selectedStatus == nil || booking.status == selectedStatus
            
            return isWithinSixMonths && matchesSearch && matchesStatus
        }.sorted { $0.bookingDate > $1.bookingDate } // Most recent first
    }
    
    private var stats: (total: Int, completed: Int, cancelled: Int, totalSpent: Double) {
        let total = filteredBookings.count
        let completed = filteredBookings.filter { $0.status == ClassStatus.completed }.count
        let cancelled = filteredBookings.filter { $0.status == ClassStatus.cancelled }.count
        let totalSpent = Double(completed) * 25.0 // Assuming £25 per class
        
        return (total, completed, cancelled, totalSpent)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.yugiOrange
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    headerSection
                    
                    // Stats Cards
                    statsSection
                    
                    // Search and Filters
                    searchAndFiltersSection
                    
                    // Bookings List
                    bookingsListSection
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingFilters = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                FilterSheet(
                    selectedStatus: $selectedStatus,
                    onApply: {
                        showingFilters = false
                    }
                )
            }
            .onAppear {
                setupNotificationListeners()
            }
            .onDisappear {
                removeNotificationListeners()
            }
        }
    }
    
    // MARK: - Notification Handling
    
    private func setupNotificationListeners() {
        NotificationCenter.default.addObserver(
            forName: .bookingCreated,
            object: nil,
            queue: .main
        ) { notification in
            if let booking = notification.object as? Booking {
                handleNewBooking(booking)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .bookingCompleted,
            object: nil,
            queue: .main
        ) { notification in
            if let booking = notification.object as? Booking {
                handleBookingCompleted(booking)
            }
        }
    }
    
    private func removeNotificationListeners() {
        NotificationCenter.default.removeObserver(self, name: .bookingCreated, object: nil)
        NotificationCenter.default.removeObserver(self, name: .bookingCompleted, object: nil)
    }
    
    private func handleNewBooking(_ booking: Booking) {
        // Add new booking to the list if it's within the last 6 months
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        if booking.bookingDate >= sixMonthsAgo {
            bookings.append(booking)
            // Sort by date (most recent first)
            bookings.sort { $0.bookingDate > $1.bookingDate }
        }
    }
    
    private func handleBookingCompleted(_ booking: Booking) {
        // Update existing booking status to completed
        if let index = bookings.firstIndex(where: { $0.id == booking.id }) {
            bookings[index].status = .completed
            bookings[index].attended = true
        }
    }
    
    // MARK: - Testing Functions (Remove in production)
    
    private func simulateBookingCompletion() {
        // Simulate a booking being completed
        let completedBooking = Booking(
            id: UUID(),
            classId: "mock-class-id-1",
            userId: UUID(),
            status: .completed,
            bookingDate: Date(),
            numberOfParticipants: 2,
            selectedChildren: nil,
            specialRequirements: "Test completion",
            attended: true
        )
        
        // Post notification to simulate booking completion
        NotificationCenter.default.post(name: .bookingCompleted, object: completedBooking)
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Booking History")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Your classes from the past 6 months")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Test button - remove in production
                Button("Test Complete") {
                    simulateBookingCompletion()
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.2))
                .cornerRadius(8)
            }
        }
        .padding(.top)
        .padding(.horizontal)
    }
    
    private var statsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Total Bookings",
                value: "\(stats.total)",
                icon: "calendar.badge.clock",
                color: .white
            )
            
            StatCard(
                title: "Completed",
                value: "\(stats.completed)",
                icon: "checkmark.circle.fill",
                color: .white
            )
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
    
    private var searchAndFiltersSection: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.yugiGray.opacity(0.6))
                
                TextField("Search classes or providers...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.yugiGray.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            
            // Active Filters
            if selectedStatus != nil {
                HStack {
                    Text("Filtered by: \(selectedStatus?.displayName ?? "")")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.yugiOrange)
                    
                    Spacer()
                    
                    Button("Clear") {
                        selectedStatus = nil
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.yugiGray)
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
    
    private var bookingsListSection: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if filteredBookings.isEmpty {
                    EmptyHistoryView(searchText: searchText, selectedStatus: selectedStatus)
                } else {
                    ForEach(filteredBookings, id: \.id) { booking in
                        HistoryBookingCard(booking: booking)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.yugiGray)
                
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.yugiGray.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct HistoryBookingCard: View {
    let booking: Booking
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Class Name") // Placeholder - would be actual class name
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.yugiGray)
                    
                    Text("Provider Name") // Placeholder - would be actual provider name
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray.opacity(0.7))
                }
                
                Spacer()
                
                // Use a custom status badge for booking status
                Text(booking.status.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(booking.status.backgroundColor)
                    .cornerRadius(12)
            }
            
            // Details
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatDate(booking.bookingDate))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.yugiGray)
                    
                    Text("\(booking.numberOfParticipants) participants")
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("£25.00") // Placeholder price
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.yugiOrange)
                    
                    Text("Booking #\(String(booking.id.uuidString.prefix(8)))")
                        .font(.system(size: 12))
                        .foregroundColor(.yugiGray.opacity(0.7))
                }
            }
            
            // Special Requirements
            if let requirements = booking.specialRequirements {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yugiOrange)
                    
                    Text(requirements)
                        .font(.system(size: 12))
                        .foregroundColor(.yugiGray.opacity(0.8))
                    
                    Spacer()
                }
            }
            
            // Attendance
            HStack {
                Image(systemName: booking.attended ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(booking.attended ? .green : .red)
                
                Text(booking.attended ? "Attended" : "Did not attend")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(booking.attended ? .green : .red)
                
                Spacer()
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d, yyyy"
        return formatter.string(from: date)
    }
}

struct EmptyHistoryView: View {
    let searchText: String
    let selectedStatus: ClassStatus?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.yugiGray.opacity(0.3))
            
            VStack(spacing: 8) {
                Text("No bookings found")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.yugiGray)
                
                if !searchText.isEmpty || selectedStatus != nil {
                    Text("Try adjusting your search or filters")
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray.opacity(0.7))
                        .multilineTextAlignment(.center)
                } else {
                    Text("You haven't booked any classes in the past 6 months")
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

struct FilterSheet: View {
    @Binding var selectedStatus: ClassStatus?
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Filter Bookings")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.yugiGray)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Booking Status")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.yugiGray)
                    
                    VStack(spacing: 12) {
                        ForEach([ClassStatus.completed, .cancelled], id: \.self) { status in
                            Button {
                                if selectedStatus == status {
                                    selectedStatus = nil
                                } else {
                                    selectedStatus = status
                                }
                            } label: {
                                HStack {
                                    Text(status.displayName)
                                        .font(.system(size: 16))
                                        .foregroundColor(.yugiGray)
                                    
                                    Spacer()
                                    
                                    if selectedStatus == status {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.yugiOrange)
                                    } else {
                                        Circle()
                                            .stroke(Color.yugiGray.opacity(0.3), lineWidth: 2)
                                            .frame(width: 20, height: 20)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedStatus == status ? Color.yugiOrange.opacity(0.05) : Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedStatus == status ? Color.yugiOrange.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                Spacer()
                
                Button("Apply Filters") {
                    onApply()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.yugiOrange)
                .cornerRadius(12)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.yugiGray)
                }
            }
        }
    }
}

#Preview {
    ViewHistoryScreen()
} 