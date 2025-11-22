import SwiftUI
import Combine

struct ProviderMyClassesScreen: View {
    let businessName: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ProviderMyClassesViewModel()
    @State private var selectedFilter: ClassFilter = .all
    @State private var showingEditClass = false
    @State private var showingCancelClass = false
    @State private var showingDeleteClass = false
    @State private var selectedClass: ProviderClass?
    
    enum ClassFilter: String, CaseIterable {
        case all = "All"
        case upcoming = "Upcoming"
        case completed = "Completed"
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Filter Tabs
                filterTabsView
                
                // Content
                contentView
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)


            .sheet(isPresented: $showingEditClass) {
                if let selectedClass = selectedClass {
                    ProviderClassEditScreen(classItem: selectedClass)
                }
            }
            .alert("Cancel Class", isPresented: $showingCancelClass) {
                Button("Cancel", role: .cancel) { }
                Button("Yes, Cancel Class", role: .destructive) {
                    if let selectedClass = selectedClass {
                        Task {
                            await viewModel.cancelClass(selectedClass)
                        }
                    }
                }
            } message: {
                if let selectedClass = selectedClass {
                    Text("Are you sure you want to cancel '\(selectedClass.name)'? This will notify all booked participants and may result in refunds.")
                }
            }
            .alert("Delete Class", isPresented: $showingDeleteClass) {
                Button("Cancel", role: .cancel) { }
                Button("Yes, Delete Class", role: .destructive) {
                    if let selectedClass = selectedClass {
                        Task {
                            await viewModel.deleteClass(selectedClass)
                        }
                    }
                }
            } message: {
                if let selectedClass = selectedClass {
                    Text("Are you sure you want to delete '\(selectedClass.name)'? This action cannot be undone.")
                }
            }
            .onAppear {
                print("📱 ProviderMyClassesScreen: Screen appeared")
                Task {
                    await viewModel.loadClasses()
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Text("My Classes")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text("Manage your class listings and bookings")
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
    }
    
    private var filterTabsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ClassFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.displayName,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color.yugiCream)
    }
    
    private var contentView: some View {
        Group {
            if viewModel.isLoading {
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#BC6C5C")))
                        .padding(.top, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else if viewModel.filteredClasses(selectedFilter).isEmpty {
                ScrollView {
                    emptyStateView
                        .padding(.top, 20)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.filteredClasses(selectedFilter), id: \.id) { classItem in
                            ProviderClassManagementCard(
                                classItem: classItem,
                                onEdit: {
                                    selectedClass = classItem
                                    showingEditClass = true
                                },
                                onCancel: {
                                    selectedClass = classItem
                                    showingCancelClass = true
                                },
                                onDelete: {
                                    selectedClass = classItem
                                    showingDeleteClass = true
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "#BC6C5C").opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Classes Yet")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.yugiGray)
                
                Text("Start by creating your first class to connect with families in your area.")
                    .font(.system(size: 16))
                    .foregroundColor(.yugiGray.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            

        }
        .padding()
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .yugiGray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color(hex: "#BC6C5C") : Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
        }
        .buttonStyle(.plain)
    }
}

struct ProviderClassManagementCard: View {
    let classItem: ProviderClass
    let onEdit: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(classItem.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.yugiGray)
                    
                    Text(classItem.category.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                }
                
                Spacer()
                
                // Status Badge
                ProviderStatusBadge(status: classItem.status)
            }
            
            // Class Details
            VStack(alignment: .leading, spacing: 8) {
                ProviderDetailRow(icon: "calendar", text: formatSchedule())
                ProviderDetailRow(icon: "location.fill", text: classItem.location)
                ProviderDetailRow(icon: "person.3.fill", text: "\(classItem.currentBookings)/\(classItem.maxCapacity) booked")
                ProviderDetailRow(icon: "creditcard.fill", text: classItem.isFree ? "Free" : "£\(String(format: "%.2f", classItem.price))")
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                // Edit Button
                Button(action: onEdit) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                        Text("Edit")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#BC6C5C"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#BC6C5C").opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Cancel Button (only if has bookings)
                if classItem.currentBookings > 0 {
                    Button(action: onCancel) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 12))
                            Text("Cancel")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                
                // Delete Button (only if no bookings)
                if classItem.currentBookings == 0 {
                    Button(action: onDelete) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 12))
                            Text("Delete")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
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
    }
    
    private func formatSchedule() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        if let nextSession = classItem.nextSession {
            return formatter.string(from: nextSession)
        } else {
            return "No upcoming sessions"
        }
    }
}

struct ProviderDetailRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.yugiGray.opacity(0.6))
                .frame(width: 16)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.yugiGray.opacity(0.8))
            
            Spacer()
        }
    }
}

struct ProviderStatusBadge: View {
    let status: ClassStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.backgroundColor)
            .cornerRadius(6)
    }
}

// MARK: - View Model

@MainActor
class ProviderMyClassesViewModel: ObservableObject {
    @Published var classes: [ProviderClass] = []
    @Published var isLoading = false
    var cancellables = Set<AnyCancellable>()
    
    private let apiService = APIService.shared
    private let newClassStorage = NewClassStorage.shared
    
    func loadClasses() async {
        isLoading = true
        defer { isLoading = false }
        
        print("🔄 ProviderMyClassesViewModel: Loading classes...")
        
        do {
            let response: ClassesResponse = try await withCheckedThrowingContinuation { continuation in
                apiService.fetchMyClasses()
                    .sink(
                        receiveCompletion: { completion in
                            switch completion {
                            case .finished:
                                print("✅ ProviderMyClassesViewModel: API call completed successfully")
                                break
                            case .failure(let error):
                                print("❌ ProviderMyClassesViewModel: API call failed with error: \(error)")
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { response in
                            print("📦 ProviderMyClassesViewModel: Received \(response.data.count) classes from API")
                            continuation.resume(returning: response)
                        }
                    )
                    .store(in: &cancellables)
            }
            
            // Convert API classes to ProviderClass format
            let apiClasses = response.data.map { classData in
                ProviderClass(
                    id: classData.id,
                    name: classData.name,
                    description: classData.description,
                    category: classData.category,
                    price: Double(truncating: classData.pricing.amount as NSDecimalNumber),
                    isFree: classData.pricing.amount == 0,
                    maxCapacity: classData.maxCapacity,
                    currentBookings: classData.currentEnrollment,
                    isPublished: true, // Assuming published if it's in the API response
                    status: ClassStatus.upcoming, // Default status
                    location: classData.location?.name ?? "Location TBD",
                    nextSession: classData.schedule.startDate,
                    createdAt: Date() // Default to current date since it's not in the model
                )
            }
            
            // Combine API classes with newly created classes
            classes = newClassStorage.newClasses + apiClasses
            
            print("✅ ProviderMyClassesViewModel: Successfully loaded \(classes.count) classes total")
            print("📋 ProviderMyClassesViewModel: Classes list: \(classes.map { $0.name })")
            
            // Add test bookings for Baby Sensory Adventure class
            await addTestBookings()
            
        } catch {
            print("❌ ProviderMyClassesViewModel: Error loading classes: \(error)")
            print("🔄 ProviderMyClassesViewModel: Falling back to mock data...")
            // Fallback to mock data + new classes
            classes = newClassStorage.newClasses + loadMockData()
            
            // Add test bookings for mock data too
            await addTestBookings()
        }
    }
    
    func addNewClass(_ classData: ClassCreationData) {
        print("➕ ProviderMyClassesViewModel: Adding new class: \(classData.className)")
        
        // Add to shared storage
        newClassStorage.addNewClass(classData)
        
        // Add to current list
        let newClass = ProviderClass(
            id: UUID().uuidString,
            name: classData.className,
            description: classData.description,
            category: classData.category,
            price: classData.price,
            isFree: classData.isFree,
            maxCapacity: classData.maxCapacity,
            currentBookings: 0,
            isPublished: true,
            status: ClassStatus.upcoming,
            location: classData.location.isEmpty ? "Location TBD" : classData.location,
            nextSession: classData.classDates.first?.date,
            createdAt: Date()
        )
        
        // Add to the beginning of the list
        classes.insert(newClass, at: 0)
        
        print("✅ ProviderMyClassesViewModel: Added new class. Total classes: \(classes.count)")
        print("📋 ProviderMyClassesViewModel: Classes list: \(classes.map { $0.name })")
    }
    
    private func loadMockData() -> [ProviderClass] {
        return [
            ProviderClass(
                id: UUID().uuidString,
                name: "Baby Sensory Adventure",
                description: "A journey of discovery through light, sound, and touch.",
                category: ClassCategory.baby,
                price: 15.0,
                isFree: false,
                maxCapacity: 10,
                currentBookings: 8,
                isPublished: true,
                status: ClassStatus.upcoming,
                location: "Sensory World Studio",
                nextSession: Date().addingTimeInterval(86400), // Tomorrow
                createdAt: Date()
            ),
            ProviderClass(
                id: UUID().uuidString,
                name: "Toddler Music Time",
                description: "Interactive music and movement for active toddlers.",
                category: ClassCategory.toddler,
                price: 12.0,
                isFree: false,
                maxCapacity: 8,
                currentBookings: 0,
                isPublished: false,
                status: ClassStatus.draft,
                location: "Music Studio",
                nextSession: nil,
                createdAt: Date().addingTimeInterval(-86400) // Yesterday
            ),
            ProviderClass(
                id: UUID().uuidString,
                name: "Free Baby Yoga",
                description: "Gentle yoga poses and breathing exercises for babies and parents.",
                category: ClassCategory.baby,
                price: 0.0,
                isFree: true,
                maxCapacity: 6,
                currentBookings: 3,
                isPublished: true,
                status: ClassStatus.upcoming,
                location: "Community Center",
                nextSession: Date().addingTimeInterval(172800), // Day after tomorrow
                createdAt: Date().addingTimeInterval(-172800) // 2 days ago
            )
        ]
    }
    
    func filteredClasses(_ filter: ProviderMyClassesScreen.ClassFilter) -> [ProviderClass] {
        switch filter {
        case .all:
            return classes
        case .upcoming:
            return classes.filter { $0.status == ClassStatus.upcoming }
        case .completed:
            return classes.filter { $0.status == ClassStatus.completed }
        }
    }
    
    func cancelClass(_ classItem: ProviderClass) async {
        print("Cancelling class: \(classItem.name)")
        
        let apiService = APIService.shared
        
        // Call API to cancel class
        do {
            let _: ClassResponse = try await withCheckedThrowingContinuation { continuation in
                apiService.cancelClass(classId: classItem.id)
                    .sink(
                        receiveCompletion: { completion in
                            switch completion {
                            case .finished:
                                break
                            case .failure(let error):
                                print("❌ Failed to cancel class via API: \(error)")
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { response in
                            print("✅ Class cancelled successfully via API")
                            continuation.resume(returning: response)
                        }
                    )
                    .store(in: &cancellables)
            }
            
            // Reload classes to get updated data from backend
            await loadClasses()
        } catch {
            print("❌ Failed to cancel class: \(error)")
            // Update local state even if API call fails
            if let index = classes.firstIndex(where: { $0.id == classItem.id }) {
                classes[index].status = ClassStatus.cancelled
            }
        }

        // Find all bookings for this class
        let bookingsToCancel = SharedBookingService.shared.bookings.filter { $0.classId == classItem.id && $0.status == .upcoming }
        print("Found \(bookingsToCancel.count) bookings to cancel for class \(classItem.name)")

        for booking in bookingsToCancel {
            // Update booking status
            if let idx = SharedBookingService.shared.bookings.firstIndex(where: { $0.id == booking.id }) {
                SharedBookingService.shared.bookings[idx].status = .cancelled
            }
            if let enhanced = SharedBookingService.shared.enhancedBookings[booking.id] {
                var updatedBooking = enhanced.booking
                updatedBooking.status = .cancelled
                SharedBookingService.shared.enhancedBookings[booking.id] = EnhancedBooking(booking: updatedBooking, classInfo: enhanced.classInfo)
            }

            // Process refund immediately
            await processRefund(for: booking, classItem: classItem)

            // Send in-app notification to parent
            let notification = UserNotification(
                title: "Class Cancelled",
                message: "Your booking for '\(classItem.name)' has been cancelled by the provider. You will receive a full refund.",
                type: .booking,
                actionType: .viewBooking,
                actionData: ["bookingId": booking.id.uuidString]
            )
            NotificationService.shared.addNotification(notification)

            // Simulate sending email to parent (since we don't have email lookup)
            print("📧 Simulated sending cancellation email to userId: \(booking.userId)")
            let subject = "Class Cancellation Notice - \(classItem.name)"
            let body = """
Dear Parent,

We regret to inform you that your upcoming class '\(classItem.name)' has been cancelled.

Class Details:
- Class: \(classItem.name)
- Date: \(booking.bookingDate)

Your refund has been processed automatically.

Refund Details:
- Refund Amount: £\(String(format: "%.2f", classItem.price * Double(booking.numberOfParticipants) - 1.99))
- Service Fee: £1.99 (non-refundable)

Refund Timeline:
• Processed: Immediately
• Bank Transfer: 3-5 business days
• Credit Card: 5-10 business days
• Debit Card: 3-5 business days

You will receive the funds in your original payment method.

If you have any questions, please contact us.

Best regards,
YUGI Team
"""
            print("Subject: \(subject)\nBody:\n\(body)")
        }
        SharedBookingService.shared.saveBookings()
    }
    
    private func processRefund(for booking: Booking, classItem: ProviderClass) async {
        print("💰 Processing refund for booking: \(booking.id)")
        
        // Calculate refund amount (full amount minus service fee)
        let totalAmount = classItem.price * Double(booking.numberOfParticipants)
        let serviceFee = 1.99
        let refundAmount = totalAmount - serviceFee
        
        print("💰 Refund Details:")
        print("   - Total paid: £\(String(format: "%.2f", totalAmount))")
        print("   - Service fee: £\(String(format: "%.2f", serviceFee))")
        print("   - Refund amount: £\(String(format: "%.2f", refundAmount))")
        
        // Simulate Stripe refund processing
        do {
            // In a real app, this would call Stripe's refund API
            print("💳 Initiating Stripe refund...")
            
            // Simulate API call delay
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            print("✅ Refund processed successfully!")
            print("📧 Sending refund confirmation email...")
            
            // Send refund confirmation notification
            let refundNotification = UserNotification(
                title: "Refund Processed",
                message: "Your refund of £\(String(format: "%.2f", refundAmount)) for '\(classItem.name)' has been processed.",
                type: .payment,
                actionType: .viewPayment,
                actionData: ["refundAmount": String(format: "%.2f", refundAmount)]
            )
            NotificationService.shared.addNotification(refundNotification)
            
            // Simulate refund confirmation email
            let refundEmailSubject = "Refund Processed - \(classItem.name)"
            let refundEmailBody = """
Dear Parent,

Your refund has been processed successfully.

Refund Details:
- Class: \(classItem.name)
- Refund Amount: £\(String(format: "%.2f", refundAmount))
- Service Fee: £\(String(format: "%.2f", serviceFee)) (non-refundable)
- Transaction Date: \(Date().formatted())

Refund Timeline:
• Processed: Immediately
• Bank Transfer: 3-5 business days
• Credit Card: 5-10 business days
• Debit Card: 3-5 business days

You will receive the funds in your original payment method.

If you have any questions, please contact our support team.

Best regards,
YUGI Team
"""
            print("📧 Refund confirmation email:")
            print("Subject: \(refundEmailSubject)")
            print("Body:\n\(refundEmailBody)")
            
        } catch {
            print("❌ Refund processing failed: \(error)")
            
            // Send failure notification
            let failureNotification = UserNotification(
                title: "Refund Processing Delayed",
                message: "We're experiencing a delay processing your refund. Please contact support if you don't receive it within 48 hours.",
                type: .payment,
                actionType: .contactSupport,
                actionData: [:]
            )
            NotificationService.shared.addNotification(failureNotification)
        }
    }
    
    func deleteClass(_ classItem: ProviderClass) async {
        print("Deleting class: \(classItem.name)")
        
        let apiService = APIService.shared
        
        // Call API to delete class
        do {
            let _: EmptyResponse = try await withCheckedThrowingContinuation { continuation in
                apiService.deleteClass(id: classItem.id)
                    .sink(
                        receiveCompletion: { completion in
                            switch completion {
                            case .finished:
                                break
                            case .failure(let error):
                                print("❌ Failed to delete class via API: \(error)")
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { response in
                            print("✅ Class deleted successfully via API")
                            continuation.resume(returning: response)
                        }
                    )
                    .store(in: &cancellables)
            }
            
            // Reload classes to get updated data from backend
            await loadClasses()
        } catch {
            print("❌ Failed to delete class: \(error)")
            // Update local state even if API call fails
            classes.removeAll { $0.id == classItem.id }
        }
    }
    
    private func addTestBookings() async {
        // Find the Baby Sensory Adventure class
        if let babySensoryClass = classes.first(where: { $0.name == "Baby Sensory Adventure" }) {
            print("🎯 Adding test booking for Baby Sensory Adventure class")
            
            // Create a test booking for the next session
            let bookingDate = babySensoryClass.nextSession?.addingTimeInterval(3600) ?? Date().addingTimeInterval(86400) // 1 hour from now or tomorrow
            
            let booking = Booking(
                id: UUID(),
                classId: babySensoryClass.id,
                userId: UUID(),
                status: .upcoming,
                bookingDate: bookingDate,
                numberOfParticipants: 2,
                selectedChildren: [
                    Child(childId: "test_child_1", childName: "Emma", childAge: 2, childDateOfBirth: nil),
                    Child(childId: "test_child_2", childName: "Liam", childAge: 3, childDateOfBirth: nil)
                ],
                specialRequirements: "Test booking for cancellation testing",
                attended: false
            )
            
            // Create a mock Class for the EnhancedBooking
            let mockClass = Class(
                id: babySensoryClass.id,
                name: babySensoryClass.name,
                description: babySensoryClass.description,
                category: babySensoryClass.category,
                provider: "mock-provider-id-1", providerName: "Mock Provider",
                location: Location(
                    id: "mock-location-id-1",
                    name: babySensoryClass.location,
                    address: Address(
                        street: "123 Test Street",
                        city: "London",
                        state: "England",
                        postalCode: "SW1A 1AA",
                        country: "UK"
                    ),
                    coordinates: Location.Coordinates(latitude: 51.5074, longitude: -0.1278),
                    accessibilityNotes: nil,
                    parkingInfo: nil,
                    babyChangingFacilities: nil
                ),
                schedule: Schedule(
                    startDate: bookingDate,
                    endDate: bookingDate.addingTimeInterval(3600),
                    recurringDays: ["monday"],
                    timeSlots: [Schedule.TimeSlot(startTime: bookingDate, duration: 3600)],
                    totalSessions: 1
                ),
                pricing: Pricing(amount: Decimal(babySensoryClass.price), currency: "GBP", type: .perSession, description: "Per session"),
                maxCapacity: babySensoryClass.maxCapacity,
                currentEnrollment: 1,
                averageRating: 4.5,
                ageRange: "0-2 years",
                isFavorite: false
            )
            
            let enhancedBooking = EnhancedBooking(booking: booking, classInfo: mockClass)
            
            // Add to shared booking service
            SharedBookingService.shared.addBooking(enhancedBooking)
            
            print("✅ Test booking added successfully")
            print("📋 Booking ID: \(booking.id)")
            print("📋 Class: \(babySensoryClass.name)")
            print("📋 Date: \(bookingDate)")
            print("📋 Participants: \(booking.numberOfParticipants)")
            
            // Simulate sending in-app notification for the booking
            let notification = UserNotification(
                title: "New Booking",
                message: "You have a new booking for '\(babySensoryClass.name)' on \(bookingDate.formatted()).",
                type: .booking,
                actionType: .viewBooking,
                actionData: ["bookingId": booking.id.uuidString]
            )
            NotificationService.shared.addNotification(notification)

            // Simulate sending email to parent
            print("📧 Simulated sending new booking email to userId: \(booking.userId)")
            let subject = "New Booking for \(babySensoryClass.name)"
            let body = """
Dear Parent,

You have successfully booked '\(babySensoryClass.name)' for \(bookingDate.formatted()).

Class Details:
- Class: \(babySensoryClass.name)
- Date: \(bookingDate.formatted())
- Location: \(babySensoryClass.location)

You will receive a confirmation email shortly.

If you have any questions, please contact us.

Best regards,
YUGI Team
"""
            print("Subject: \(subject)\nBody:\n\(body)")
        } else {
            print("⚠️ Baby Sensory Adventure class not found for test booking")
        }
    }
}

// MARK: - Models

#Preview {
    ProviderMyClassesScreen(businessName: "Little Learners")
} 
