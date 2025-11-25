import SwiftUI

struct ClassBookingsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var sharedBookingService = SharedBookingService.shared
    @State private var selectedFilter: BookingFilter = .all
    @State private var showingCancelConfirmation = false
    @State private var bookingToCancel: EnhancedBooking? = nil
    @State private var showingRefundPolicy = false
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
                    Text("My Bookings")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Manage your class bookings")
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
                
                // Filter Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(BookingFilter.allCases, id: \.self) { filter in
                            FilterButton(
                                title: filter.displayName,
                                isSelected: selectedFilter == filter
                            ) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedFilter = filter
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 16)
                .background(Color.clear)
                
                // Bookings List
                ScrollView {
                    LazyVStack(spacing: 16) {
                        let filteredBookings = getFilteredBookings()
                        
                        if filteredBookings.isEmpty {
                            EmptyBookingsView(filter: selectedFilter)
                        } else {
                            ForEach(filteredBookings, id: \.booking.id) { enhancedBooking in
                                BookingDetailCard(
                                    enhancedBooking: enhancedBooking,
                                    onCancel: {
                                        bookingToCancel = enhancedBooking
                                        showingCancelConfirmation = true
                                    },
                                    onViewAnalysis: {
                                        selectedBookingForAnalysis = enhancedBooking
                                    }
                                )
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .background(Color(hex: "#BC6C5C").ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(item: $selectedBookingForAnalysis) { enhancedBooking in
                VenueAnalysisScreen(enhancedBooking: enhancedBooking)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refund Policy") {
                        showingRefundPolicy = true
                    }
                    .foregroundColor(.white)
                }
            }
            .alert("Cancel Booking", isPresented: $showingCancelConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Yes, Cancel Booking", role: .destructive) {
                    if let booking = bookingToCancel {
                        cancelBooking(booking)
                    }
                }
            } message: {
                if let booking = bookingToCancel {
                    let refundInfo = getRefundInfo(for: booking)
                    Text("Are you sure you want to cancel '\(booking.className)'?\n\n\(refundInfo)")
                }
            }
            .sheet(isPresented: $showingRefundPolicy) {
                RefundPolicyScreen()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getFilteredBookings() -> [EnhancedBooking] {
        let allBookings = Array(sharedBookingService.enhancedBookings.values)
        
        switch selectedFilter {
        case .all:
            return allBookings.sorted { $0.booking.bookingDate > $1.booking.bookingDate }
        case .upcoming:
            return allBookings.filter { $0.booking.status == .upcoming }
                .sorted { $0.booking.bookingDate < $1.booking.bookingDate }
        case .completed:
            return allBookings.filter { $0.booking.status == .completed }
                .sorted { $0.booking.bookingDate > $1.booking.bookingDate }
        case .cancelled:
            return allBookings.filter { $0.booking.status == .cancelled }
                .sorted { $0.booking.bookingDate > $1.booking.bookingDate }
        }
    }
    
    private func getRefundInfo(for booking: EnhancedBooking) -> String {
        let hoursUntilClass = Calendar.current.dateComponents([.hour], from: Date(), to: booking.booking.bookingDate).hour ?? 0
        
        if hoursUntilClass >= 24 {
            return "You will receive a full refund minus the booking fee (£1.99)."
        } else if hoursUntilClass > 0 {
            return "Cancellation within 24 hours: No refund available."
        } else {
            return "This class has already taken place."
        }
    }
    
    private func cancelBooking(_ booking: EnhancedBooking) {
        // Update booking status to cancelled
        var updatedBooking = booking.booking
        updatedBooking.status = .cancelled
        
        // Update in shared service
        sharedBookingService.enhancedBookings[booking.booking.id] = EnhancedBooking(
            booking: updatedBooking,
            classInfo: booking.classInfo
        )
        
        // In a real app, you would also call the API to cancel the booking
        print("Booking cancelled: \(booking.booking.id)")
        
        // Show success message or handle refund process
        // For now, we'll just update the UI
    }
}

// MARK: - Supporting Views

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white, lineWidth: 1)
                        )
                )
        }
    }
}

struct BookingDetailCard: View {
    let enhancedBooking: EnhancedBooking
    let onCancel: () -> Void
    let onViewAnalysis: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(enhancedBooking.className)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(enhancedBooking.providerName)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Text(enhancedBooking.booking.status.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(enhancedBooking.booking.status.backgroundColor)
                    .cornerRadius(6)
            }
            
            // Class Details
            VStack(alignment: .leading, spacing: 8) {
                ClassBookingDetailRow(icon: "calendar", text: formatDate(enhancedBooking.booking.bookingDate))
                ClassBookingDetailRow(icon: "clock", text: formatTime(enhancedBooking.booking.bookingDate))
                ClassBookingDetailRow(icon: "person.2", text: "\(enhancedBooking.booking.numberOfParticipants) participants")
                ClassBookingDetailRow(icon: "poundsign.circle", text: "£\(String(format: "%.2f", NSDecimalNumber(decimal: enhancedBooking.price).doubleValue))")
                
                // Venue address with Maps button
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#BC6C5C"))
                            .frame(width: 16)
                        
                        Text(enhancedBooking.classInfo.location?.address.formatted ?? "Location TBD")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    
                    // Maps button - more prominent
                    Button(action: {
                        print("🗺️ ClassBookingsScreen: Maps button tapped for venue: \(enhancedBooking.classInfo.location?.name ?? "Location TBD")")
                        print("🗺️ ClassBookingsScreen: Venue address: \(enhancedBooking.classInfo.location?.address.formatted ?? "Location TBD")")
                        print("🗺️ ClassBookingsScreen: Coordinates: \(enhancedBooking.classInfo.location?.coordinates.latitude ?? 51.5074), \(enhancedBooking.classInfo.location?.coordinates.longitude ?? -0.1278)")
                        openInAppleMaps()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "map")
                                .font(.system(size: 14))
                            Text("View in Maps")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "#BC6C5C"))
                        .cornerRadius(8)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            
            // Special Requirements
            if let requirements = enhancedBooking.booking.specialRequirements, !requirements.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Special Requirements")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(requirements)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 1)
                )
            }
            
            // Action Buttons
            if enhancedBooking.booking.status == .upcoming {
                HStack(spacing: 12) {
                    Button("Venue Analysis") {
                        onViewAnalysis()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white, lineWidth: 1)
                    )
                    
                    Spacer()
                    
                    Button("Cancel Booking") {
                        onCancel()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    )
                }
            }
        }
        .padding(16)
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 1)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func openInAppleMaps() {
        let coordinates = enhancedBooking.classInfo.location?.coordinates ?? Location.Coordinates(latitude: 51.5074, longitude: -0.1278)
        let venueName = enhancedBooking.classInfo.location?.name ?? "Location TBD"
        
        print("🗺️ Attempting to open Apple Maps for venue: \(venueName)")
        print("🗺️ Coordinates: \(coordinates.latitude), \(coordinates.longitude)")
        
        // URL encode the venue name
        guard let encodedVenueName = venueName.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed),
              let url = URL(string: "maps://?q=\(encodedVenueName)&ll=\(coordinates.latitude),\(coordinates.longitude)") else {
            print("❌ Error: Could not create Apple Maps URL for venue: \(venueName)")
            return
        }
        
        print("🗺️ Created URL: \(url)")
        
        // Check if Apple Maps can be opened
        let canOpen = UIApplication.shared.canOpenURL(url)
        print("🗺️ Can open Apple Maps URL: \(canOpen)")
        
        // Open Apple Maps
        if canOpen {
            UIApplication.shared.open(url) { success in
                if success {
                    print("🗺️ Successfully opened Apple Maps for venue: \(venueName)")
                } else {
                    print("❌ Failed to open Apple Maps for venue: \(venueName)")
                }
            }
        } else {
            print("❌ Apple Maps is not available on this device")
            // Fallback: Try to open in Safari with Google Maps
            let googleMapsURL = "https://maps.google.com/?q=\(encodedVenueName)&ll=\(coordinates.latitude),\(coordinates.longitude)"
            print("🗺️ Trying Google Maps fallback: \(googleMapsURL)")
            if let googleURL = URL(string: googleMapsURL) {
                UIApplication.shared.open(googleURL) { success in
                    if success {
                        print("🗺️ Successfully opened Google Maps for venue: \(venueName)")
                    } else {
                        print("❌ Failed to open Google Maps for venue: \(venueName)")
                    }
                }
            }
        }
    }
}

struct ClassBookingDetailRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#BC6C5C"))
                .frame(width: 16)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white)
            
            Spacer()
        }
    }
}

struct EmptyBookingsView: View {
    let filter: ClassBookingsScreen.BookingFilter
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: getEmptyIcon())
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
            
            VStack(spacing: 8) {
                Text(getEmptyTitle())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(getEmptyMessage())
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 1)
        )
    }
    
    private func getEmptyIcon() -> String {
        switch filter {
        case .all: return "calendar.badge.plus"
        case .upcoming: return "calendar.badge.clock"
        case .completed: return "checkmark.circle"
        case .cancelled: return "xmark.circle"
        }
    }
    
    private func getEmptyTitle() -> String {
        switch filter {
        case .all: return "No Bookings Yet"
        case .upcoming: return "No Upcoming Classes"
        case .completed: return "No Completed Classes"
        case .cancelled: return "No Cancelled Classes"
        }
    }
    
    private func getEmptyMessage() -> String {
        switch filter {
        case .all: return "Start exploring classes and make your first booking!"
        case .upcoming: return "You don't have any upcoming classes scheduled."
        case .completed: return "You haven't completed any classes yet."
        case .cancelled: return "You haven't cancelled any classes."
        }
    }
}

#Preview {
    ClassBookingsScreen()
} 