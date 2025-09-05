import SwiftUI
import Combine

public struct ProviderBookingsScreen: View {
    let businessName: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var sharedBookingService = SharedBookingService.shared
    @StateObject private var notificationService = NotificationService.shared
    @State private var selectedFilter: BookingFilter = .all
    @State private var showingSuccessMessage = false
    @State private var successMessage = ""
    @State private var showingEmailAlert = false
    
    private var apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init(businessName: String) {
        self.businessName = businessName
    }
    
    enum BookingFilter: String, CaseIterable {
        case all = "All"
        case upcoming = "Upcoming"
        case completed = "Completed"
        case cancelled = "Cancelled"
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Filter Tabs
                filterTabs
                
                // Bookings List
                ScrollView {
                    VStack(spacing: 20) {
                        bookingsList
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarHidden(true)
            .alert("Email App Not Available", isPresented: $showingEmailAlert) {
                Button("OK") { }
            } message: {
                Text("The email address has been copied to your clipboard. You can paste it into your email app to send a message to the parent.")
            }
            .overlay(
                // Success Message Overlay
                Group {
                    if showingSuccessMessage {
                        VStack {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(successMessage)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.8))
                            .cornerRadius(25)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 100)
                        .animation(.easeInOut(duration: 0.3), value: showingSuccessMessage)
                    }
                }
            )
            .onAppear {
                print("🎫 ProviderBookings: Screen appeared")
                print("🎫 ProviderBookings: Total bookings: \(sharedBookingService.bookings.count)")
                print("🎫 ProviderBookings: Enhanced bookings: \(sharedBookingService.enhancedBookings.count)")
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                
                Text("Bookings")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            // Quick Stats
            HStack(spacing: 16) {
                ProviderStatCard(
                    title: "Total",
                    value: "\(getFilteredBookings().count)",
                    icon: "calendar.badge.clock",
                    color: Color(hex: "#BC6C5C")
                )
                
                ProviderStatCard(
                    title: "This Week",
                    value: "\(getThisWeeksBookings().count)",
                    icon: "calendar",
                    color: Color(hex: "#BC6C5C").opacity(0.8)
                )
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(BookingFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.displayName,
                        isSelected: selectedFilter == filter,
                        action: {
                            selectedFilter = filter
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color.white)
    }
    
    private var bookingsList: some View {
        let filteredBookings = getFilteredBookings()
        
        return Group {
            if filteredBookings.isEmpty {
                ProviderBookingsEmptyStateView(
                    icon: "calendar.badge.exclamationmark",
                    title: getEmptyStateTitle(),
                    message: getEmptyStateMessage()
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(filteredBookings, id: \.id) { enhancedBooking in
                        ProviderBookingRow(
                            enhancedBooking: enhancedBooking
                        )
                    }
                }
            }
        }
    }
    
    private func getFilteredBookings() -> [EnhancedBooking] {
        let allEnhancedBookings = Array(sharedBookingService.enhancedBookings.values)
        
        // Filter bookings for this provider's classes
        let providerBookings = allEnhancedBookings.filter { enhancedBooking in
            // In a real app, you would check if the class belongs to this provider
            // For now, we'll show all bookings
            return true
        }
        
        // Apply filter
        switch selectedFilter {
        case .all:
            return providerBookings
        case .upcoming:
            return providerBookings.filter { $0.booking.status == .upcoming }
        case .completed:
            return providerBookings.filter { $0.booking.status == .completed }
        case .cancelled:
            return providerBookings.filter { $0.booking.status == .cancelled }
        }
    }
    
    private func getThisWeeksBookings() -> [EnhancedBooking] {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        
        return getFilteredBookings().filter { booking in
            booking.booking.bookingDate >= startOfWeek
        }
    }
    
    private func getEmptyStateTitle() -> String {
        switch selectedFilter {
        case .all: return "No Bookings"
        case .upcoming: return "No Upcoming Bookings"
        case .completed: return "No Completed Bookings"
        case .cancelled: return "No Cancelled Bookings"
        }
    }
    
    private func getEmptyStateMessage() -> String {
        switch selectedFilter {
        case .all: return "You don't have any bookings yet. They will appear here once parents start booking your classes."
        case .upcoming: return "No upcoming bookings found. Check back later for new bookings."
        case .completed: return "Completed bookings will appear here once classes are finished."
        case .cancelled: return "Cancelled bookings will appear here if any bookings are cancelled."
        }
    }
}

struct ProviderBookingRow: View {
    let enhancedBooking: EnhancedBooking
    @State private var showingEmailAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with class name and status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(enhancedBooking.className)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.yugiGray)
                    
                    Text(formatClassDate(enhancedBooking))
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray.opacity(0.7))
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
            
            // Key Details Row
            HStack {
                // Parent Info
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sarah Johnson")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.yugiGray)
                    
                    Text("sarah.johnson@email.com")
                        .font(.system(size: 12))
                        .foregroundColor(.yugiGray.opacity(0.7))
                }
                
                Spacer()
                
                // Price
                Text("£\(NSDecimalNumber(decimal: enhancedBooking.price).doubleValue, specifier: "%.2f")")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#BC6C5C"))
            }
            
            // Participants and Contact
            HStack {
                Text("\(enhancedBooking.booking.numberOfParticipants) participants")
                    .font(.system(size: 14))
                    .foregroundColor(.yugiGray.opacity(0.8))
                
                Spacer()
                
                // Email button
                Button(action: {
                    let email = "sarah.johnson@email.com"
                    UIPasteboard.general.string = email
                    
                    if let url = URL(string: "mailto:\(email)") {
                        if UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url)
                        } else {
                            showingEmailAlert = true
                        }
                    }
                }) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                        .padding(6)
                        .background(Color(hex: "#BC6C5C").opacity(0.1))
                        .cornerRadius(6)
                }
            }
            
            // Special Requirements (only if present)
            if let requirements = enhancedBooking.booking.specialRequirements, !requirements.isEmpty {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text(requirements)
                        .font(.system(size: 12))
                        .foregroundColor(.yugiGray.opacity(0.8))
                        .lineLimit(2)
                    
                    Spacer()
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color(hex: "#BC6C5C").opacity(0.05))
                .cornerRadius(6)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#BC6C5C"), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .alert("Email App Not Available", isPresented: $showingEmailAlert) {
            Button("OK") { }
        } message: {
            Text("The email address has been copied to your clipboard. You can paste it into your email app to send a message to the parent.")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatClassDate(_ enhancedBooking: EnhancedBooking) -> String {
        print("🗓️ formatClassDate: Class name: \(enhancedBooking.className)")
        print("🗓️ formatClassDate: Time slots count: \(enhancedBooking.classInfo.schedule.timeSlots.count)")
        
        // Use the first time slot from the class schedule as the class date
        if let firstTimeSlot = enhancedBooking.classInfo.schedule.timeSlots.first {
            print("🗓️ formatClassDate: Raw time slot date: \(firstTimeSlot.startTime)")
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            let dateString = formatter.string(from: firstTimeSlot.startTime)
            
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            let timeString = timeFormatter.string(from: firstTimeSlot.startTime)
            
            let formattedDate = "\(dateString) at \(timeString)"
            print("🗓️ formatClassDate: Using class time slot: \(formattedDate)")
            return formattedDate
        } else {
            // Fallback to booking date if no time slots available
            print("🗓️ formatClassDate: No time slots found, using booking date")
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            let dateString = formatter.string(from: enhancedBooking.booking.bookingDate)
            
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            let timeString = timeFormatter.string(from: enhancedBooking.booking.bookingDate)
            
            let formattedDate = "\(dateString) at \(timeString)"
            print("🗓️ formatClassDate: Using booking date (fallback): \(formattedDate)")
            return formattedDate
        }
    }
    
    private func handleEmailFallback() {
        print("📧 Email app not available, copying email to clipboard: sarah.johnson@email.com")
        UIPasteboard.general.string = "sarah.johnson@email.com"
        DispatchQueue.main.async {
            print("📧 Setting showingEmailAlert to true")
            showingEmailAlert = true
        }
    }
}

struct ProviderBookingsEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
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
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

struct ProviderStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 1)
        )
    }
} 