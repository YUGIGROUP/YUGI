import SwiftUI
import Combine

// Shared booking service to persist data across dashboard instances
class SharedBookingService: ObservableObject {
    static let shared = SharedBookingService()
    
    @Published var bookings: [Booking] = []
    @Published var enhancedBookings: [UUID: EnhancedBooking] = [:]
    
    private let bookingsKey = "persisted_bookings"
    private let enhancedBookingsKey = "persisted_enhanced_bookings"
    private var autoCompletionTimer: Timer?
    
    private init() {
        // Clear any existing mock data from UserDefaults
        UserDefaults.standard.removeObject(forKey: bookingsKey)
        UserDefaults.standard.removeObject(forKey: enhancedBookingsKey)
        print("🔔 SharedBookingService: Cleared existing mock data from UserDefaults")
        
        loadBookings()
        
        // Update booking statuses based on current time
        updateBookingStatuses()
        
        // Start automatic completion timer
        startAutoCompletionTimer()
        
        // If no bookings exist, don't create mock data for real users
        // Mock data is only for testing purposes
        if bookings.isEmpty {
            print("🔔 SharedBookingService: No existing bookings found - starting with empty state")
        } else {
            print("🔔 SharedBookingService: Loaded \(bookings.count) existing bookings")
        }
    }
    
    deinit {
        stopAutoCompletionTimer()
    }
    
    private func startAutoCompletionTimer() {
        // Check for classes to complete every minute
        autoCompletionTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.updateBookingStatuses()
        }
        print("🔔 SharedBookingService: Auto-completion timer started")
    }
    
    private func stopAutoCompletionTimer() {
        autoCompletionTimer?.invalidate()
        autoCompletionTimer = nil
        print("🔔 SharedBookingService: Auto-completion timer stopped")
    }
    
    func updateBookingStatuses() {
        let now = Date()
        var hasChanges = false
        
        for i in 0..<bookings.count {
            let booking = bookings[i]
            
            // Only process upcoming bookings
            guard booking.status == .upcoming else { continue }
            
            // Get class duration from enhanced booking if available
            var classDuration: TimeInterval = 60 * 60 // Default 60 minutes
            
            if let enhancedBooking = enhancedBookings[booking.id] {
                // Use the actual class duration from the schedule
                if let firstTimeSlot = enhancedBooking.classInfo.schedule.timeSlots.first {
                    classDuration = firstTimeSlot.duration
                }
            }
            
            let classEndTime = booking.bookingDate.addingTimeInterval(classDuration)
            
            // Check if class has ended
            if now >= classEndTime {
                // Create a new booking with completed status
                let completedBooking = Booking(
                    id: booking.id,
                    classId: booking.classId,
                    userId: booking.userId,
                    status: .completed,
                    bookingDate: booking.bookingDate,
                    numberOfParticipants: booking.numberOfParticipants,
                    selectedChildren: booking.selectedChildren,
                    specialRequirements: booking.specialRequirements,
                    attended: true,
                    calendar: booking.calendar
                )
                
                bookings[i] = completedBooking
                hasChanges = true
                
                print("🔔 SharedBookingService: Auto-completed booking \(booking.id)")
                print("🔔 SharedBookingService: Class started at \(booking.bookingDate)")
                print("🔔 SharedBookingService: Class ended at \(classEndTime)")
                print("🔔 SharedBookingService: Class duration: \(classDuration / 60) minutes")
                
                // Update corresponding enhanced booking
                if let enhancedBooking = enhancedBookings[booking.id] {
                    let updatedEnhancedBooking = EnhancedBooking(
                        booking: completedBooking,
                        classInfo: enhancedBooking.classInfo
                    )
                    enhancedBookings[booking.id] = updatedEnhancedBooking
                    
                    // Send completion notification to parent
                    sendCompletionNotification(for: updatedEnhancedBooking)
                    
                    // Send completion notification to provider
                    sendProviderCompletionNotification(for: updatedEnhancedBooking)
                }
            }
        }
        
        if hasChanges {
            saveBookings()
            print("🔔 SharedBookingService: Saved updated booking statuses")
        }
    }
    
    private func sendCompletionNotification(for enhancedBooking: EnhancedBooking) {
        let notification = UserNotification(
            title: "Class Completed",
            message: "Your class '\(enhancedBooking.className)' has been automatically marked as completed.",
            type: .booking,
            actionType: .viewBooking,
            actionData: ["bookingId": enhancedBooking.booking.id.uuidString]
        )
        NotificationService.shared.addNotification(notification)
        print("🔔 SharedBookingService: Sent completion notification to parent")
    }
    
    private func sendProviderCompletionNotification(for enhancedBooking: EnhancedBooking) {
        let notification = UserNotification(
            title: "Class Auto-Completed",
            message: "The class '\(enhancedBooking.className)' has been automatically marked as completed.",
            type: .booking,
            actionType: .viewBooking,
            actionData: ["bookingId": enhancedBooking.booking.id.uuidString]
        )
        NotificationService.shared.addNotification(notification)
        print("🔔 SharedBookingService: Sent auto-completion notification to provider")
    }
    
    func addBooking(_ enhancedBooking: EnhancedBooking) {
        bookings.append(enhancedBooking.booking)
        enhancedBookings[enhancedBooking.booking.id] = enhancedBooking
        saveBookings()
        print("🔔 SharedBookingService: Added new booking \(enhancedBooking.booking.id)")
        print("🔔 SharedBookingService: Total bookings now: \(bookings.count)")
        print("🔔 SharedBookingService: Enhanced bookings now: \(enhancedBookings.count)")
    }
    
    private func createInitialBookings() {
        // Create mock provider children for testing (matching the ones in ProviderDashboardScreen)
        let providerChild1 = Child(id: "provider_child_1", name: "Emma", age: 2, dateOfBirth: Date().addingTimeInterval(-365 * 2 * 24 * 60 * 60))
        let providerChild2 = Child(id: "provider_child_2", name: "Liam", age: 3, dateOfBirth: Date().addingTimeInterval(-365 * 3 * 24 * 60 * 60))
        let providerChild3 = Child(id: "provider_child_3", name: "Ava", age: 2, dateOfBirth: Date().addingTimeInterval(-365 * 2 * 24 * 60 * 60))
        
        // Create mock class for testing
        let mockClass = Class(
            id: UUID(),
            name: "Baby Sensory Adventure",
            description: "A fun sensory experience for babies",
            category: .baby,
            provider: Provider(
                id: UUID(),
                name: "Little Learners",
                description: "Professional early years education provider",
                qualifications: ["Early Years Teacher", "DBS Checked"],
                contactEmail: "info@littlelearners.com",
                contactPhone: "+44 123 456 7890",
                website: "https://littlelearners.com",
                rating: 4.8
            ),
            location: Location(
                id: UUID(),
                name: "Community Center",
                address: Address(
                    street: "123 Main St",
                    city: "London",
                    state: "England",
                    postalCode: "SW1A 1AA",
                    country: "UK"
                ),
                coordinates: Location.Coordinates(latitude: 51.5074, longitude: -0.1278),
                accessibilityNotes: "Wheelchair accessible",
                parkingInfo: "Free parking available",
                babyChangingFacilities: "Available in main hall"
            ),
            schedule: Schedule(
                startDate: Date(),
                endDate: Date().addingTimeInterval(86400 * 30), // 30 days from now
                recurringDays: [.monday, .wednesday, .friday],
                timeSlots: [
                    Schedule.TimeSlot(
                        startTime: {
                            let calendar = Calendar.current
                            var futureDate = calendar.date(byAdding: .day, value: 2, to: Date()) ?? Date()
                            
                            // Set to 10:00 AM for a child-friendly time
                            futureDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: futureDate) ?? futureDate
                            
                            print("📅 Creating Baby Sensory Adventure class with date: \(futureDate)")
                            return futureDate
                        }(),
                        duration: 3600 // 1 hour
                    )
                ],
                totalSessions: 12
            ),
            pricing: Pricing(
                amount: Decimal(15.00),
                currency: "GBP",
                type: .perSession,
                description: "Per session"
            ),
            maxCapacity: 10,
            currentEnrollment: 5,
            averageRating: 4.8,
            ageRange: "0-2 years",
            isFavorite: false
        )
        
        bookings = [
            Booking(
                id: UUID(),
                classId: UUID(),
                userId: UUID(),
                status: .upcoming,
                bookingDate: {
                    let calendar = Calendar.current
                    var futureDate = calendar.date(byAdding: .day, value: 2, to: Date()) ?? Date()
                    
                    // Set to 10:00 AM for a child-friendly time
                    futureDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: futureDate) ?? futureDate
                    
                    print("📅 Creating booking with date: \(futureDate)")
                    return futureDate
                }(),
                numberOfParticipants: 1,
                selectedChildren: nil,
                specialRequirements: nil,
                attended: false
            ),
            Booking(
                id: UUID(),
                classId: UUID(),
                userId: UUID(),
                status: .upcoming,
                bookingDate: {
                    let calendar = Calendar.current
                    var futureDate = calendar.date(byAdding: .day, value: 4, to: Date()) ?? Date()
                    
                    // Set to 2:00 PM for a child-friendly time
                    futureDate = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: futureDate) ?? futureDate
                    
                    print("📅 Creating booking with date: \(futureDate)")
                    return futureDate
                }(),
                numberOfParticipants: 2,
                selectedChildren: nil,
                specialRequirements: nil,
                attended: false
            ),
            Booking(
                id: UUID(),
                classId: UUID(),
                userId: UUID(),
                status: .completed,
                bookingDate: Date().addingTimeInterval(-86400),
                numberOfParticipants: 2,
                selectedChildren: nil,
                specialRequirements: "Allergy: nuts",
                attended: true
            ),
            // Add provider children bookings for testing
            Booking(
                id: UUID(),
                classId: mockClass.id,
                userId: UUID(),
                status: .upcoming,
                bookingDate: Date().addingTimeInterval(86400), // Tomorrow
                numberOfParticipants: 2,
                selectedChildren: [providerChild1, providerChild2],
                specialRequirements: "Emma loves music",
                attended: false
            ),
            Booking(
                id: UUID(),
                classId: mockClass.id,
                userId: UUID(),
                status: .completed,
                bookingDate: Date().addingTimeInterval(-86400 * 7), // Last week
                numberOfParticipants: 1,
                selectedChildren: [providerChild1],
                specialRequirements: nil,
                attended: true
            ),
            Booking(
                id: UUID(),
                classId: mockClass.id,
                userId: UUID(),
                status: .upcoming,
                bookingDate: Date().addingTimeInterval(86400 * 3), // 3 days from now
                numberOfParticipants: 1,
                selectedChildren: [providerChild3],
                specialRequirements: "Ava needs extra attention",
                attended: false
            )
        ]
        
        // Create enhanced bookings for the provider children bookings
        let enhancedBooking1 = EnhancedBooking(
            booking: bookings[3], // The upcoming booking with Emma and Liam
            classInfo: mockClass
        )
        let enhancedBooking2 = EnhancedBooking(
            booking: bookings[4], // The completed booking with Emma
            classInfo: mockClass
        )
        let enhancedBooking3 = EnhancedBooking(
            booking: bookings[5], // The upcoming booking with Ava
            classInfo: mockClass
        )
        
        enhancedBookings[bookings[3].id] = enhancedBooking1
        enhancedBookings[bookings[4].id] = enhancedBooking2
        enhancedBookings[bookings[5].id] = enhancedBooking3
        
        saveBookings()
    }
    
    func saveBookings() {
        // Save bookings to UserDefaults
        if let encoded = try? JSONEncoder().encode(bookings) {
            UserDefaults.standard.set(encoded, forKey: bookingsKey)
        }
        
        // Save enhanced bookings to UserDefaults
        if let encoded = try? JSONEncoder().encode(enhancedBookings) {
            UserDefaults.standard.set(encoded, forKey: enhancedBookingsKey)
        }
    }
    
    private func loadBookings() {
        // Load bookings from UserDefaults
        if let data = UserDefaults.standard.data(forKey: bookingsKey),
           let decoded = try? JSONDecoder().decode([Booking].self, from: data) {
            bookings = decoded
        }
        
        // Load enhanced bookings from UserDefaults
        if let data = UserDefaults.standard.data(forKey: enhancedBookingsKey),
           let decoded = try? JSONDecoder().decode([UUID: EnhancedBooking].self, from: data) {
            enhancedBookings = decoded
        }
    }
}

struct ParentDashboardScreen: View {
    public init(parentName: String, initialTab: Int = 0) {
        self.parentName = parentName
        self.initialTab = initialTab
        self.selectedTab = initialTab
    }
    let parentName: String
    let initialTab: Int
    @State private var selectedTab: Int
    @State private var showingAddChild = false
    @State private var showingEditChild = false
    @State private var childToEdit: Child? = nil
    @State private var showingProfile = false
    @State private var shouldNavigateToClassDiscovery = false
    @State private var shouldNavigateToViewHistory = false
    @State private var showingSuccessMessage = false
    @State private var successMessage = ""
    @State private var children: [Child] = []
    @State private var isLoadingChildren = false
    @State private var childrenError: String? = nil
    @State private var showingPersonalInformation = false
    @State private var showingNotifications = false
    @State private var showingTermsPrivacy = false

    @State private var showingPaymentMethods = false
    @State private var shouldSignOut = false
    @State private var showingBiometricSettings = false
    @State private var showingClassBookings = false
    @State private var showingRefundPolicy = false
    @State private var showingCancelConfirmation = false
    @State private var bookingToCancel: EnhancedBooking? = nil
    @State private var showingContactForm = false
    @State private var selectedBookingForAnalysis: EnhancedBooking? = nil
    
    // Use shared booking service instead of local state
    @StateObject private var sharedBookingService = SharedBookingService.shared
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var biometricService = BiometricAuthService.shared
    
    private var apiService = APIService.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Tab Selector
                tabSelector
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    bookingsTab
                        .tag(0)
                    
                    childrenTab
                        .tag(1)
                    
                    profileTab
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .background(Color(hex: "#BC6C5C").ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddChild) {
                AddChildScreen { newChild in
                    // Check authentication first
                    print("🔐 ParentDashboard: Authentication check before adding child")
                    print("🔐 ParentDashboard: apiService.isAuthenticated = \(apiService.isAuthenticated)")
                    print("🔐 ParentDashboard: apiService.authToken = \(apiService.authToken?.prefix(20) ?? "None")...")
                    print("🔐 ParentDashboard: apiService.currentUser = \(apiService.currentUser?.fullName ?? "None")")
                    print("🔐 ParentDashboard: APIConfig.useMockMode = \(APIConfig.useMockMode)")
                    
                    guard apiService.isAuthenticated, apiService.authToken != nil else {
                        print("🔐 ParentDashboard: Authentication check FAILED")
                        childrenError = "You must be logged in to add a child"
                        successMessage = "Please log in to add a child"
                        showingSuccessMessage = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            showingSuccessMessage = false
                        }
                        return
                    }
                    
                    print("🔐 ParentDashboard: Authentication check PASSED")
                    
                    // Add child via backend
                    isLoadingChildren = true
                    childrenError = nil
                    
                    print("Adding child: \(newChild.name), age: \(newChild.age)")
                    print("Current auth token: \(apiService.authToken ?? "No token")")
                    print("Is authenticated: \(apiService.isAuthenticated)")
                    
                    apiService.addChild(name: newChild.name, age: newChild.age, dateOfBirth: newChild.dateOfBirth)
                        .receive(on: DispatchQueue.main)
                        .sink(receiveCompletion: { completion in
                            isLoadingChildren = false
                            if case let .failure(error) = completion {
                                childrenError = error.localizedDescription
                                print("Add child error: \(error)")
                                
                                // Show error message
                                successMessage = "Failed to add child: \(error.localizedDescription)"
                                showingSuccessMessage = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    showingSuccessMessage = false
                                }
                            }
                        }, receiveValue: { response in
                            print("Successfully added child, response: \(response)")
                            self.children = response.data
                            // Post notification for app-wide updates
                            NotificationCenter.default.post(name: .childAdded, object: response.data.last)
                            // Show success message
                            if let added = response.data.last {
                                successMessage = "\(added.name) has been added successfully!"
                                showingSuccessMessage = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    showingSuccessMessage = false
                                }
                            }
                        })
                        .store(in: &apiService.cancellables)
                }
            }
            .sheet(isPresented: $showingEditChild) {
                if let child = childToEdit {
                    AddChildScreen(childToEdit: child, onSave: { updatedChild in
                        // Check authentication first
                        print("🔐 ParentDashboard: Authentication check before editing child")
                        print("🔐 ParentDashboard: apiService.isAuthenticated = \(apiService.isAuthenticated)")
                        print("🔐 ParentDashboard: apiService.authToken = \(apiService.authToken?.prefix(20) ?? "None")...")
                        
                        guard apiService.isAuthenticated, apiService.authToken != nil else {
                            print("🔐 ParentDashboard: Authentication check FAILED")
                            childrenError = "You must be logged in to edit a child"
                            successMessage = "Please log in to edit a child"
                            showingSuccessMessage = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                showingSuccessMessage = false
                            }
                            return
                        }
                        
                        print("🔐 ParentDashboard: Authentication check PASSED")
                        
                        // Edit child via backend
                        isLoadingChildren = true
                        childrenError = nil
                        
                        print("Editing child: \(updatedChild.name), age: \(updatedChild.age)")
                        
                        apiService.editChild(childId: updatedChild.id ?? "", name: updatedChild.name, age: updatedChild.age, dateOfBirth: updatedChild.dateOfBirth)
                            .receive(on: DispatchQueue.main)
                            .sink(receiveCompletion: { completion in
                                isLoadingChildren = false
                                if case let .failure(error) = completion {
                                    childrenError = error.localizedDescription
                                    print("Edit child error: \(error)")
                                    
                                    // Show error message
                                    successMessage = "Failed to edit child: \(error.localizedDescription)"
                                    showingSuccessMessage = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        showingSuccessMessage = false
                                    }
                                }
                            }, receiveValue: { response in
                                print("Successfully edited child, response: \(response)")
                                self.children = response.data
                                // Post notification for app-wide updates
                                NotificationCenter.default.post(name: .childUpdated, object: response.data.last)
                                // Show success message
                                if let updated = response.data.last {
                                    successMessage = "\(updated.name) has been updated successfully!"
                                    showingSuccessMessage = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        showingSuccessMessage = false
                                    }
                                }
                            })
                            .store(in: &apiService.cancellables)
                    }, onDelete: { childId in
                        // Check authentication first
                        print("🔐 ParentDashboard: Authentication check before deleting child")
                        print("🔐 ParentDashboard: apiService.isAuthenticated = \(apiService.isAuthenticated)")
                        print("🔐 ParentDashboard: apiService.authToken = \(apiService.authToken?.prefix(20) ?? "None")...")
                        
                        guard apiService.isAuthenticated, apiService.authToken != nil else {
                            print("🔐 ParentDashboard: Authentication check FAILED")
                            childrenError = "You must be logged in to delete a child"
                            successMessage = "Please log in to delete a child"
                            showingSuccessMessage = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                showingSuccessMessage = false
                            }
                            return
                        }
                        
                        print("🔐 ParentDashboard: Authentication check PASSED")
                        
                        // Delete child via backend
                        isLoadingChildren = true
                        childrenError = nil
                        
                        print("Deleting child with ID: \(childId)")
                        
                        apiService.deleteChild(childId: childId)
                            .receive(on: DispatchQueue.main)
                            .sink(receiveCompletion: { completion in
                                isLoadingChildren = false
                                if case let .failure(error) = completion {
                                    childrenError = error.localizedDescription
                                    print("Delete child error: \(error)")
                                    
                                    // Show error message
                                    successMessage = "Failed to delete child: \(error.localizedDescription)"
                                    showingSuccessMessage = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                        showingSuccessMessage = false
                                    }
                                }
                            }, receiveValue: { _ in
                                print("Successfully deleted child")
                                // Remove the child from the local array
                                self.children.removeAll { $0.id == childId }
                                // Post notification for app-wide updates
                                NotificationCenter.default.post(name: .childDeleted, object: childId)
                                // Show success message
                                successMessage = "Child has been deleted successfully!"
                                showingSuccessMessage = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    showingSuccessMessage = false
                                }
                            })
                            .store(in: &apiService.cancellables)
                    })
                }
            }
            .sheet(isPresented: $showingPersonalInformation) {
                PersonalInformationScreen()
            }
            .sheet(isPresented: $showingNotifications) {
                NotificationsScreen()
            }
            .sheet(isPresented: $showingTermsPrivacy) {
                TermsPrivacyScreen(isReadOnly: true)
            }

            .sheet(isPresented: $showingPaymentMethods) {
                PaymentMethodsScreen()
            }
            .sheet(isPresented: $showingBiometricSettings) {
                BiometricSettingsScreen()
            }
            .sheet(isPresented: $showingContactForm) {
                ContactFormScreen()
            }
            .sheet(isPresented: $showingClassBookings) {
                ClassBookingsScreen()
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
            .onAppear {
                print("🔐 ParentDashboard: Dashboard appeared")
                print("🔐 ParentDashboard: Current auth state - isAuthenticated: \(apiService.isAuthenticated)")
                print("🔐 ParentDashboard: Current auth token: \(apiService.authToken?.prefix(20) ?? "None")...")
                print("🔐 ParentDashboard: Initial tab: \(initialTab)")
                print("🔐 ParentDashboard: Current bookings count: \(sharedBookingService.bookings.count)")
                print("🔐 ParentDashboard: Enhanced bookings count: \(sharedBookingService.enhancedBookings.count)")
                print("🔐 ParentDashboard: Dashboard is ready to receive notifications!")
                
                // No longer creating mock enhanced bookings - only real bookings will be shown
                print("🔐 ParentDashboard: Starting with clean booking state")
                
                // Force authentication for testing if not already authenticated
                if !apiService.isAuthenticated {
                    print("🔐 ParentDashboard: Not authenticated, but not forcing authentication to avoid conflicts")
                    // Removed automatic authentication to prevent overriding provider authentication
                }
                
                fetchChildrenFromBackend()
                // Don't call refreshBookings() here as it might reset the bookings
            }
            .onReceive(NotificationCenter.default.publisher(for: .bookingCreated)) { notification in
                print("🔔 ParentDashboard: Received bookingCreated notification")
                print("🔔 ParentDashboard: Notification object type: \(type(of: notification.object))")
                print("🔔 ParentDashboard: Notification object: \(notification.object ?? "nil")")
                
                if let enhancedBooking = notification.object as? EnhancedBooking {
                    print("🔔 ParentDashboard: Successfully cast to EnhancedBooking")
                    print("🔔 ParentDashboard: Booking ID: \(enhancedBooking.booking.id)")
                    print("🔔 ParentDashboard: Class Name: \(enhancedBooking.className)")
                    print("🔔 ParentDashboard: Provider Name: \(enhancedBooking.providerName)")
                    print("🔔 ParentDashboard: Price: \(enhancedBooking.price)")
                    
                    // Add the new booking to the shared service
                    sharedBookingService.addBooking(enhancedBooking)
                    
                    print("🔔 ParentDashboard: New booking added to shared service: \(enhancedBooking.booking.id)")
                    print("🔔 ParentDashboard: Total bookings now: \(sharedBookingService.bookings.count)")
                    print("🔔 ParentDashboard: Enhanced bookings stored: \(sharedBookingService.enhancedBookings.count)")
                    print("🔔 ParentDashboard: Enhanced booking for this booking: \(sharedBookingService.enhancedBookings[enhancedBooking.booking.id] != nil)")
                    
                    // Force UI update
                    DispatchQueue.main.async {
                        print("🔔 ParentDashboard: Forcing UI update...")
                        // This will trigger a view update
                        self.sharedBookingService.objectWillChange.send()
                    }
                } else {
                    print("🔔 ParentDashboard: Failed to cast notification object to EnhancedBooking")
                    print("🔔 ParentDashboard: Object is: \(notification.object ?? "nil")")
                }
                // Don't call refreshBookings() here as it might interfere with the enhanced booking data
            }
            .onReceive(NotificationCenter.default.publisher(for: .childAdded)) { notification in
                if let newChild = notification.object as? Child {
                    // Ensure the child is in our list (in case it was added elsewhere)
                    if !children.contains(where: { $0.id == newChild.id }) {
                        children.append(newChild)
                        print("Child added from notification: \(newChild.name)")
                    }
                }
            }
            .onReceive(apiService.$currentUser) { user in
                isLoadingChildren = false
                if let user = user {
                    self.children = user.children ?? []
                }
            }
            .sheet(isPresented: $shouldNavigateToClassDiscovery) {
                ClassSearchView()
            }
            .navigationDestination(isPresented: $shouldNavigateToViewHistory) {
                ViewHistoryScreen()
            }
            .sheet(item: $selectedBookingForAnalysis) { enhancedBooking in
                VenueAnalysisScreen(enhancedBooking: enhancedBooking)
            }
            .navigationDestination(isPresented: $shouldSignOut) {
                AuthScreen()
                    .navigationBarBackButtonHidden()
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
        }
    }
    
    private func refreshBookings() {
        // In a real app, this would fetch from the API
        // For now, we'll simulate a refresh by checking if there are any new bookings
        // This could be enhanced with a proper API call to fetch updated bookings
        print("Refreshing bookings for parent dashboard - Total bookings: \(sharedBookingService.bookings.count)")
        
        // No longer creating mock enhanced bookings - only real bookings will be shown
        print("📋 refreshBookings: Only real bookings will be displayed")
    }
    
    private func getRefundInfo(for booking: EnhancedBooking) -> String {
        let hoursUntilClass = Calendar.current.dateComponents([.hour], from: Date(), to: booking.bookingDate).hour ?? 0
        
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
        
        // Also update the base booking in the bookings array
        if let index = sharedBookingService.bookings.firstIndex(where: { $0.id == booking.booking.id }) {
            sharedBookingService.bookings[index] = updatedBooking
        }
        
        // Save the updated bookings
        sharedBookingService.saveBookings()
        
        // Send cancellation notification to user
        let cancellationNotification = UserNotification(
            title: "Booking Cancelled",
            message: "Your booking for '\(booking.className)' has been cancelled successfully.",
            type: .booking,
            actionType: .viewBooking,
            actionData: ["bookingId": booking.booking.id.uuidString]
        )
        notificationService.addNotification(cancellationNotification)
        
        // Send cancellation notification to provider
        let providerId = booking.classInfo.provider.id.uuidString
        let parentName = apiService.currentUser?.fullName ?? "Unknown User"
        let bookingDate = booking.booking.bookingDate
        let bookingId = booking.booking.id.uuidString
        
        ProviderNotificationService.shared.sendBookingCancellationNotification(
            providerId: providerId,
            className: booking.className,
            bookingDate: bookingDate,
            parentName: parentName,
            bookingId: bookingId
        )
        
        // Reset the cancel confirmation state
        bookingToCancel = nil
        showingCancelConfirmation = false
        
        print("✅ Booking cancelled successfully")
        print("📧 Provider notification sent to: \(providerId)")
        print("📱 User notification sent")
    }
    
    private func formatBookingDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome back,")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text(apiService.currentUser?.fullName ?? parentName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
            }
            
            // Quick Stats
            HStack(spacing: 16) {
                ParentStatCard(
                    title: "Current Bookings",
                    value: "\(sharedBookingService.bookings.filter { $0.status == .upcoming }.count)",
                    icon: "calendar.badge.clock",
                    color: .white
                )
                
                ParentStatCard(
                    title: "Total Children",
                    value: "\(children.count)",
                    icon: "person.2.fill",
                    color: .white
                )
            }
        }
        .padding(20)
        .background(Color(hex: "#BC6C5C"))
    }
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            TabButton(
                title: "Bookings",
                isSelected: selectedTab == 0,
                action: { withAnimation { selectedTab = 0 } }
            )
            
            TabButton(
                title: "Children",
                isSelected: selectedTab == 1,
                action: { withAnimation { selectedTab = 1 } }
            )
            
            TabButton(
                title: "Profile",
                isSelected: selectedTab == 2,
                action: { withAnimation { selectedTab = 2 } }
            )
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
    }
    
    private var bookingsTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Latest Upcoming Booking
                let upcomingBookings = sharedBookingService.bookings.filter { $0.status == .upcoming }
                let _ = print("📋 BookingsTab: Total bookings: \(sharedBookingService.bookings.count)")
                let _ = print("📋 BookingsTab: Upcoming bookings: \(upcomingBookings.count)")
                let _ = print("📋 BookingsTab: Enhanced bookings stored: \(sharedBookingService.enhancedBookings.count)")
                let _ = print("📋 BookingsTab: All booking IDs: \(sharedBookingService.bookings.map { $0.id })")
                let _ = print("📋 BookingsTab: All enhanced booking IDs: \(Array(sharedBookingService.enhancedBookings.keys))")
                
                if !upcomingBookings.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Latest Upcoming Booking")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        // Show only the most recent upcoming booking
                        if let latestBooking = upcomingBookings.sorted(by: { $0.bookingDate > $1.bookingDate }).first {
                            let enhancedBooking = sharedBookingService.enhancedBookings[latestBooking.id]
                            let _ = print("📋 BookingsTab: Displaying latest booking: \(latestBooking.id)")
                            let _ = print("📋 BookingsTab: Enhanced booking for this booking: \(enhancedBooking != nil)")
                            if let enhanced = enhancedBooking {
                                let _ = print("📋 BookingsTab: Class name: \(enhanced.className)")
                                let _ = print("📋 BookingsTab: Provider name: \(enhanced.providerName)")
                            }
                            BookingCard(
                                booking: latestBooking, 
                                enhancedBooking: enhancedBooking,
                                onCancel: {
                                    if let enhanced = enhancedBooking {
                                        bookingToCancel = enhanced
                                        showingCancelConfirmation = true
                                    }
                                },
                                onVenueAnalysis: {
                                    print("🎫 BookingCard: Venue Analysis button tapped")
                                    if let enhanced = enhancedBooking {
                                        print("🎫 BookingCard: Enhanced booking found, setting selectedBookingForAnalysis")
                                        selectedBookingForAnalysis = enhanced
                                        print("🎫 BookingCard: selectedBookingForAnalysis set to: \(enhanced.className)")
                                    } else {
                                        print("🎫 BookingCard: No enhanced booking available")
                                    }
                                }
                            )
                        }
                    }
                } else {
                    let _ = print("📋 BookingsTab: No upcoming bookings to display")
                }
                

                
                // Quick Actions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Quick Actions")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 16) {
                        ParentQuickActionButton(
                            title: "Find Classes",
                            icon: "magnifyingglass",
                            color: Color(hex: "#BC6C5C")
                        ) {
                            print("🔍 ParentDashboard: Find Classes button tapped")
                            print("🔍 ParentDashboard: Setting shouldNavigateToClassDiscovery = true")
                            shouldNavigateToClassDiscovery = true
                            print("🔍 ParentDashboard: shouldNavigateToClassDiscovery is now: \(shouldNavigateToClassDiscovery)")
                        }
                        
                        ParentQuickActionButton(
                            title: "View All Bookings",
                            icon: "calendar.badge.clock",
                            color: .yugiGray
                        ) {
                            showingClassBookings = true
                        }
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
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white, lineWidth: 1)
                            )
                        }
                    }
                    if isLoadingChildren {
                        HStack {
                            ProgressView()
                            Text("Loading children...")
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 20)
                    } else if let error = childrenError {
                        Text(error)
                            .foregroundColor(.red)
                            .padding(.vertical, 20)
                    } else if children.isEmpty {
                        ParentEmptyStateView(
                            icon: "person.2.fill",
                            title: "No Children Added",
                            message: "Add your children to start booking classes for them"
                        ) {
                            showingAddChild = true
                        }
                    } else {
                        ForEach(children, id: \.id) { child in
                            ChildCard(child: child) {
                                // Edit child - TODO: Implement edit functionality
                                print("Edit child: \(child.name)")
                                childToEdit = child
                                showingEditChild = true
                            }
                        }
                        
                        // Add a subtle hint that more children can be added
                        if children.count > 0 {
                            HStack {
                                Spacer()
                                Text("Tap + to add another child")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(.top, 8)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }
    
    private var profileTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Account
                VStack(alignment: .leading, spacing: 16) {
                                            Text("Account")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    
                    VStack(spacing: 12) {
                        ProfileRow(
                            icon: "person.fill",
                            title: "Personal Information",
                            subtitle: "Update your details",
                            badge: nil
                        ) {
                            showingPersonalInformation = true
                        }
                        
                        ProfileRow(
                            icon: "creditcard.fill",
                            title: "Payment Method",
                            subtitle: "Manage your payment methods",
                            badge: nil
                        ) {
                            showingPaymentMethods = true
                        }
                    }
                }
                
                // Settings
                VStack(alignment: .leading, spacing: 16) {
                    Text("Settings")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    VStack(spacing: 12) {
                        ProfileRow(
                            icon: "bell.fill",
                            title: "Notifications",
                            subtitle: "Manage your preferences",
                            badge: notificationService.unreadCount > 0 ? "\(notificationService.unreadCount)" : nil
                        ) {
                            showingNotifications = true
                        }
                        

                        
                        ProfileRow(
                            icon: "faceid",
                            title: "Biometric Authentication",
                            subtitle: "Face ID & Touch ID settings",
                            badge: nil
                        ) {
                            showingBiometricSettings = true
                        }
                    }
                }
                
                // Support
                VStack(alignment: .leading, spacing: 16) {
                    Text("Support")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    VStack(spacing: 12) {
                        ProfileRow(
                            icon: "message.fill",
                            title: "Contact Us",
                            subtitle: "Reach out to our support team",
                            badge: nil
                        ) {
                            showingContactForm = true
                        }
                        
                        ProfileRow(
                            icon: "doc.text.fill",
                            title: "Terms of Service",
                            subtitle: "Read our terms and conditions",
                            badge: nil
                        ) {
                            showingTermsPrivacy = true
                        }
                    }
                }
                
                // Sign Out
                VStack(spacing: 16) {
                    Button(action: {
                        // Clear authentication state
                        apiService.logout()
                        
                        // Clear shared services data
                        sharedBookingService.bookings.removeAll()
                        sharedBookingService.enhancedBookings.removeAll()
                        
                        // Clear notification service
                        notificationService.clearAllNotifications()
                        
                        // Clear payment service
                        SharedPaymentService.shared.paymentMethods.removeAll()
                        
                        // Clear biometric credentials and settings
                        biometricService.clearSavedCredentials()
                        biometricService.setRememberMeEnabled(false)
                        biometricService.setBiometricEnabled(false)
                        
                        // Navigate back to auth screen
                        shouldSignOut = true
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.9))
                            
                            Text("Sign Out")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 20)
            }
            .padding(20)
        }
    }
    
    // MARK: - Backend Integration
    private func fetchChildrenFromBackend() {
        print("🔐 ParentDashboard: Fetching children from backend...")
        print("🔐 ParentDashboard: Auth state before fetch - isAuthenticated: \(apiService.isAuthenticated)")
        isLoadingChildren = true
        childrenError = nil
        
        // Fetch children from the backend API
        // For now, we'll use the children from the current user data
        // In a real app, this would be a separate API call to fetch children
        if let currentUser = apiService.currentUser {
            self.children = currentUser.children ?? []
            print("🔐 ParentDashboard: Loaded \(self.children.count) children from current user")
        } else {
            print("🔐 ParentDashboard: No current user found, children will be empty")
            self.children = []
        }
        
        self.isLoadingChildren = false
        
        // Also fetch from API service to ensure we have the latest data
        apiService.fetchCurrentUser()
        // The fetchCurrentUser method sets apiService.currentUser
        // We'll observe currentUser and update children accordingly
    }
    
    // Create mock class data for existing bookings
    private func createMockEnhancedBookings() {
        print("📋 createMockEnhancedBookings: Starting...")
        print("📋 createMockEnhancedBookings: Total bookings: \(sharedBookingService.bookings.count)")
        print("📋 createMockEnhancedBookings: Existing enhanced bookings: \(sharedBookingService.enhancedBookings.count)")
        
        // Clear existing enhanced bookings to ensure fresh data with updated dates
        sharedBookingService.enhancedBookings.removeAll()
        print("📋 createMockEnhancedBookings: Cleared existing enhanced bookings")
        let mockClasses: [Class] = []
        
        // Create EnhancedBookings for all bookings to ensure venue analysis works
        var mockClassIndex = 0
        for booking in sharedBookingService.bookings {
                if mockClassIndex < mockClasses.count {
                    // Use existing mock classes for the first few bookings
                    let mockClass = mockClasses[mockClassIndex]
                    let enhancedBooking = EnhancedBooking(booking: booking, classInfo: mockClass)
                    sharedBookingService.enhancedBookings[booking.id] = enhancedBooking
                    print("📋 createMockEnhancedBookings: Created enhanced booking for \(booking.id) with class \(mockClass.name)")
                    mockClassIndex += 1
                } else {
                    // For additional bookings (like new ones from discovery), create a generic enhanced booking
                    let genericClass = Class(
                        id: booking.classId,
                        name: "Booked Class",
                        description: "A class you've booked",
                        category: .wellness,
                        provider: Provider(
                            id: UUID(),
                            name: "Class Provider",
                            description: "Provider of your booked class",
                            qualifications: ["Certified Instructor"],
                            contactEmail: "info@provider.com",
                            contactPhone: "+44 20 0000 0000",
                            website: nil,
                            rating: 4.5
                        ),
                        location: Location(
                            id: UUID(),
                            name: "Class Location",
                            address: Address(
                                street: "Class Street",
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
                            startDate: Date(),
                            endDate: Date().addingTimeInterval(86400 * 30),
                            recurringDays: [.monday],
                            timeSlots: [Schedule.TimeSlot(startTime: {
                                let calendar = Calendar.current
                                var futureDate = calendar.date(byAdding: .day, value: 5, to: Date()) ?? Date()
                                
                                // Set to 1:30 PM for a child-friendly time
                                futureDate = calendar.date(bySettingHour: 13, minute: 30, second: 0, of: futureDate) ?? futureDate
                                
                                print("📅 Creating generic class with date: \(futureDate)")
                                return futureDate
                            }(), duration: 3600)],
                            totalSessions: 1
                        ),
                        pricing: Pricing(amount: 20.0, currency: "GBP", type: .perSession, description: "Per session"),
                        maxCapacity: 10,
                        currentEnrollment: 5,
                        averageRating: 4.5,
                        ageRange: "0-5 years",
                        isFavorite: false
                    )
                    let enhancedBooking = EnhancedBooking(booking: booking, classInfo: genericClass)
                    sharedBookingService.enhancedBookings[booking.id] = enhancedBooking
                    print("📋 createMockEnhancedBookings: Created generic enhanced booking for \(booking.id)")
                }
        }
        
        print("📋 createMockEnhancedBookings: Finished!")
        print("📋 createMockEnhancedBookings: Final enhanced bookings count: \(sharedBookingService.enhancedBookings.count)")
        print("📋 createMockEnhancedBookings: All enhanced booking IDs: \(sharedBookingService.enhancedBookings.keys.map { $0 })")
    }
}

// MARK: - Supporting Views

struct ParentStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.15))
        .cornerRadius(12)
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                
                Rectangle()
                    .fill(isSelected ? .white : Color.clear)
                    .frame(height: 3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

struct BookingCard: View {
    let booking: Booking
    let enhancedBooking: EnhancedBooking?
    let onCancel: (() -> Void)?
    let onVenueAnalysis: (() -> Void)?
    
    init(booking: Booking, enhancedBooking: EnhancedBooking? = nil, onCancel: (() -> Void)? = nil, onVenueAnalysis: (() -> Void)? = nil) {
        self.booking = booking
        self.enhancedBooking = enhancedBooking
        self.onCancel = onCancel
        self.onVenueAnalysis = onVenueAnalysis
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                // Class name and provider
                VStack(alignment: .leading, spacing: 4) {
                    let className = enhancedBooking?.className ?? "Class Name"
                    let providerName = enhancedBooking?.providerName ?? "Provider Name"
                    
                    let _ = print("🎫 BookingCard: Rendering booking \(booking.id)")
                    let _ = print("🎫 BookingCard: Enhanced booking available: \(enhancedBooking != nil)")
                    if let enhanced = enhancedBooking {
                        let _ = print("🎫 BookingCard: Class name: \(enhanced.className)")
                        let _ = print("🎫 BookingCard: Provider name: \(enhanced.providerName)")
                        let _ = print("🎫 BookingCard: Price: \(enhanced.price)")
                    }
                    
                    Text(className) // Use actual class name if available
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(providerName) // Use actual provider name if available
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Date, participants, price, and venue address
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(formatDate(booking.bookingDate))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            
                            Text(formatTime(booking.bookingDate))
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text("\(booking.numberOfParticipants) participants")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            if let enhancedBooking = enhancedBooking {
                                Text("£\(NSDecimalNumber(decimal: enhancedBooking.price).doubleValue, specifier: "%.2f")")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            } else {
                                Text("£25.00") // Placeholder price
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    // Venue address
                    if let enhancedBooking = enhancedBooking {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.circle")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "#BC6C5C"))
                                    .frame(width: 16)
                                
                                Text(enhancedBooking.classInfo.location.address.formatted)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.8))
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                            }
                            
                            // Maps button - more prominent
                            Button(action: {
                                print("🎫 BookingCard: Maps button tapped")
                                print("🎫 BookingCard: Venue name: \(enhancedBooking.classInfo.location.name)")
                                print("🎫 BookingCard: Venue address: \(enhancedBooking.classInfo.location.address.formatted)")
                                print("🎫 BookingCard: Coordinates: \(enhancedBooking.classInfo.location.coordinates.latitude), \(enhancedBooking.classInfo.location.coordinates.longitude)")
                                openInAppleMaps(enhancedBooking: enhancedBooking)
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
                            }
                        }
                        .onAppear {
                            print("🎫 BookingCard: Enhanced booking available for venue address section")
                            print("🎫 BookingCard: Venue name: \(enhancedBooking.classInfo.location.name)")
                            print("🎫 BookingCard: Venue address: \(enhancedBooking.classInfo.location.address.formatted)")
                        }
                    } else {
                        EmptyView()
                            .onAppear {
                                print("🎫 BookingCard: No enhanced booking available for venue address section")
                            }
                    }
                }
            }
            

            
            if booking.status == .upcoming {
                HStack {
                    Button("Venue Analysis") {
                        onVenueAnalysis?()
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
                    
                    Button("Cancel") {
                        onCancel?()
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
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func openInAppleMaps(enhancedBooking: EnhancedBooking) {
        let coordinates = enhancedBooking.classInfo.location.coordinates
        let venueName = enhancedBooking.classInfo.location.name
        
        print("🗺️ Attempting to open Apple Maps for venue: \(venueName)")
        print("🗺️ Coordinates: \(coordinates.latitude), \(coordinates.longitude)")
        
        // URL encode the venue name
        guard let encodedVenueName = venueName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
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

struct ChildCard: View {
    let child: Child
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color(hex: "#BC6C5C").opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Text(String(child.name.prefix(1)))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: "#BC6C5C"))
            }
            
            Text(child.name)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
            
            Button(action: onEdit) {
                VStack(spacing: 4) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                    
                    Text("Edit")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
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
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct ProfileRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let badge: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#BC6C5C"))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding()
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ParentQuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ParentEmptyStateView: View {
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
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
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
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 1)
        )
    }
}

// MARK: - Extensions

extension ClassStatus {
    var textColor: Color {
        switch self {
        case .draft: return .white
        case .pending: return .white
        case .upcoming: return .white
        case .inProgress: return .white
        case .completed: return .white
        case .cancelled: return .white
        }
    }
}

#Preview {
    ParentDashboardScreen(parentName: "Sarah Johnson", initialTab: 0)
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let bookingCreated = Notification.Name("bookingCreated")
    static let bookingCompleted = Notification.Name("bookingCompleted")
    static let childAdded = Notification.Name("childAdded")
    static let childUpdated = Notification.Name("childUpdated")
    static let childDeleted = Notification.Name("childDeleted")
} 