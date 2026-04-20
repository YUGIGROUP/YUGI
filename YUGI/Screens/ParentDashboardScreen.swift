import SwiftUI
import Combine

// MARK: - SharedBookingService

class SharedBookingService: ObservableObject {
    static let shared = SharedBookingService()

    @Published var bookings: [Booking] = []
    @Published var enhancedBookings: [UUID: EnhancedBooking] = [:]

    private let bookingsKey         = "persisted_bookings"
    private let enhancedBookingsKey = "persisted_enhanced_bookings"
    private var autoCompletionTimer: Timer?

    private init() {
        UserDefaults.standard.removeObject(forKey: bookingsKey)
        UserDefaults.standard.removeObject(forKey: enhancedBookingsKey)
        loadBookings()
        updateBookingStatuses()
        startAutoCompletionTimer()
        if bookings.isEmpty {
            print("🔔 SharedBookingService: No existing bookings found - starting with empty state")
        } else {
            print("🔔 SharedBookingService: Loaded \(bookings.count) existing bookings")
        }
    }

    deinit { stopAutoCompletionTimer() }

    private func startAutoCompletionTimer() {
        autoCompletionTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.updateBookingStatuses()
        }
    }

    private func stopAutoCompletionTimer() {
        autoCompletionTimer?.invalidate()
        autoCompletionTimer = nil
    }

    func updateBookingStatuses() {
        let now = Date()
        var hasChanges = false

        for i in 0..<bookings.count {
            let booking = bookings[i]
            guard booking.status == .upcoming else { continue }

            var classDuration: TimeInterval = 60 * 60
            if let enhanced = enhancedBookings[booking.id],
               let slot = enhanced.classInfo.schedule.timeSlots.first {
                classDuration = slot.duration
            }

            if now >= booking.bookingDate.addingTimeInterval(classDuration) {
                let completed = Booking(
                    id: booking.id, classId: booking.classId, userId: booking.userId,
                    status: ClassStatus.completed, bookingDate: booking.bookingDate,
                    numberOfParticipants: booking.numberOfParticipants,
                    selectedChildren: booking.selectedChildren,
                    specialRequirements: booking.specialRequirements,
                    attended: true, calendar: booking.calendar
                )
                bookings[i] = completed
                hasChanges = true

                if let enhanced = enhancedBookings[booking.id] {
                    let updated = EnhancedBooking(booking: completed, classInfo: enhanced.classInfo)
                    enhancedBookings[booking.id] = updated
                    sendCompletionNotification(for: updated)
                    sendProviderCompletionNotification(for: updated)
                }
            }
        }

        if hasChanges { saveBookings() }
    }

    private func sendCompletionNotification(for eb: EnhancedBooking) {
        NotificationService.shared.addNotification(UserNotification(
            title: "Class Completed",
            message: "Your class '\(eb.className)' has been automatically marked as completed.",
            type: .booking, actionType: .viewBooking,
            actionData: ["bookingId": eb.booking.id.uuidString]
        ))
    }

    private func sendProviderCompletionNotification(for eb: EnhancedBooking) {
        NotificationService.shared.addNotification(UserNotification(
            title: "Class Auto-Completed",
            message: "The class '\(eb.className)' has been automatically marked as completed.",
            type: .booking, actionType: .viewBooking,
            actionData: ["bookingId": eb.booking.id.uuidString]
        ))
    }

    func addBooking(_ enhancedBooking: EnhancedBooking) {
        bookings.append(enhancedBooking.booking)
        enhancedBookings[enhancedBooking.booking.id] = enhancedBooking
        saveBookings()
    }

    func saveBookings() {
        if let data = try? JSONEncoder().encode(bookings) {
            UserDefaults.standard.set(data, forKey: bookingsKey)
        }
        if let data = try? JSONEncoder().encode(enhancedBookings) {
            UserDefaults.standard.set(data, forKey: enhancedBookingsKey)
        }
    }

    private func loadBookings() {
        if let data = UserDefaults.standard.data(forKey: bookingsKey),
           let decoded = try? JSONDecoder().decode([Booking].self, from: data) {
            bookings = decoded
        }
        if let data = UserDefaults.standard.data(forKey: enhancedBookingsKey),
           let decoded = try? JSONDecoder().decode([UUID: EnhancedBooking].self, from: data) {
            enhancedBookings = decoded
        }
    }
}

// MARK: - ParentDashboardScreen

struct ParentDashboardScreen: View {
    public init(parentName: String, initialTab: Int = 0) {
        self.parentName = parentName
        self.initialTab = initialTab
        self.selectedTab = initialTab
    }

    let parentName: String
    let initialTab: Int
    @State private var selectedTab: Int

    // Home feed cascade animation
    @State private var showGreeting   = false
    @State private var showSearch     = false
    @State private var showNextUp     = false
    @State private var showVenueCheck = false
    @State private var showForYou     = false
    @State private var showNearYou    = false
    @State private var showCategories = false

    // Home navigation
    @State private var showingVenueCheckSheet  = false
    @State private var showingClassSearchSheet = false
    @State private var showingBookingsSheet    = false

    // Children tab state
    @State private var showingAddChild       = false
    @State private var showingEditChild      = false
    @State private var childToEdit: Child?   = nil
    @State private var children: [Child]     = []
    @State private var isLoadingChildren     = false
    @State private var childrenError: String? = nil
    @State private var showingSuccessMessage = false
    @State private var successMessage        = ""

    // Profile tab navigation
    @State private var showingPersonalInformation = false
    @State private var showingNotifications       = false
    @State private var showingTermsPrivacy        = false
    @State private var showingPaymentMethods      = false
    @State private var showingContactForm         = false
    @State private var shouldSignOut              = false
    @State private var showingCancelConfirmation  = false
    @State private var bookingToCancel: EnhancedBooking?  = nil
    @State private var selectedBookingForAnalysis: EnhancedBooking? = nil

    @StateObject private var sharedBookingService = SharedBookingService.shared
    @StateObject private var notificationService  = NotificationService.shared
    @StateObject private var biometricService     = BiometricAuthService.shared
    private var apiService = APIService.shared

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                homeTab
                    .tabItem { Label("Home",     systemImage: "house.fill") }
                    .tag(0)
                childrenTab
                    .tabItem { Label("Children", systemImage: "person.2.fill") }
                    .tag(1)
                profileTab
                    .tabItem { Label("Profile",  systemImage: "person.circle.fill") }
                    .tag(2)
            }
            .tint(Color.yugiMocha)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                configureTabBar()
                fetchChildrenFromBackend()
            }
            // MARK: Sheets
            .sheet(isPresented: $showingVenueCheckSheet)  { VenueCheckScreen() }
            .sheet(isPresented: $showingClassSearchSheet) { ClassSearchView() }
            .sheet(isPresented: $showingBookingsSheet)    { ClassBookingsScreen() }
            .sheet(isPresented: $showingAddChild) {
                AddChildScreen { newChild in
                    guard apiService.isAuthenticated, apiService.authToken != nil else {
                        successMessage = "Please log in to add a child"
                        showingSuccessMessage = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showingSuccessMessage = false }
                        return
                    }
                    isLoadingChildren = true
                    apiService.addChild(name: newChild.name, age: newChild.age, dateOfBirth: newChild.dateOfBirth)
                        .receive(on: DispatchQueue.main)
                        .sink(receiveCompletion: { completion in
                            isLoadingChildren = false
                            if case let .failure(error) = completion {
                                successMessage = "Failed to add child: \(error.localizedDescription)"
                                showingSuccessMessage = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showingSuccessMessage = false }
                            }
                        }, receiveValue: { response in
                            self.children = response.data
                            NotificationCenter.default.post(name: .childAdded, object: response.data.last)
                            if let added = response.data.last {
                                successMessage = "\(added.name) has been added successfully!"
                                showingSuccessMessage = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showingSuccessMessage = false }
                            }
                        })
                        .store(in: &apiService.cancellables)
                }
            }
            .sheet(isPresented: $showingEditChild) {
                if let child = childToEdit {
                    AddChildScreen(childToEdit: child, onSave: { updatedChild in
                        guard apiService.isAuthenticated, apiService.authToken != nil else {
                            successMessage = "Please log in to edit a child"
                            showingSuccessMessage = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showingSuccessMessage = false }
                            return
                        }
                        isLoadingChildren = true
                        apiService.editChild(childId: updatedChild.id ?? "", name: updatedChild.name, age: updatedChild.age, dateOfBirth: updatedChild.dateOfBirth)
                            .receive(on: DispatchQueue.main)
                            .sink(receiveCompletion: { completion in
                                isLoadingChildren = false
                                if case let .failure(error) = completion {
                                    successMessage = "Failed to edit child: \(error.localizedDescription)"
                                    showingSuccessMessage = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showingSuccessMessage = false }
                                }
                            }, receiveValue: { response in
                                self.children = response.data
                                NotificationCenter.default.post(name: .childUpdated, object: response.data.last)
                                if let updated = response.data.last {
                                    successMessage = "\(updated.name) has been updated successfully!"
                                    showingSuccessMessage = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showingSuccessMessage = false }
                                }
                            })
                            .store(in: &apiService.cancellables)
                    }, onDelete: { childId in
                        guard apiService.isAuthenticated, apiService.authToken != nil else {
                            successMessage = "Please log in to delete a child"
                            showingSuccessMessage = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showingSuccessMessage = false }
                            return
                        }
                        isLoadingChildren = true
                        apiService.deleteChild(childId: childId)
                            .receive(on: DispatchQueue.main)
                            .sink(receiveCompletion: { completion in
                                isLoadingChildren = false
                                if case let .failure(error) = completion {
                                    successMessage = "Failed to delete child: \(error.localizedDescription)"
                                    showingSuccessMessage = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showingSuccessMessage = false }
                                }
                            }, receiveValue: { _ in
                                self.children.removeAll { $0.id == childId }
                                NotificationCenter.default.post(name: .childDeleted, object: childId)
                                successMessage = "Child has been deleted successfully!"
                                showingSuccessMessage = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) { showingSuccessMessage = false }
                            })
                            .store(in: &apiService.cancellables)
                    })
                }
            }
            .sheet(isPresented: $showingPersonalInformation) { PersonalInformationScreen() }
            .sheet(isPresented: $showingNotifications)       { NotificationsScreen() }
            .sheet(isPresented: $showingTermsPrivacy)        { TermsPrivacyScreen(isReadOnly: true) }
            .sheet(isPresented: $showingPaymentMethods)      { PaymentMethodsScreen() }
            .sheet(isPresented: $showingContactForm)         { ContactFormScreen() }
            .sheet(item: $selectedBookingForAnalysis)        { eb in VenueAnalysisScreen(enhancedBooking: eb) }
            .alert("Cancel Booking", isPresented: $showingCancelConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Yes, Cancel Booking", role: .destructive) {
                    if let b = bookingToCancel { cancelBooking(b) }
                }
            } message: {
                if let b = bookingToCancel { Text(getRefundInfo(for: b)) }
            }
            .navigationDestination(isPresented: $shouldSignOut) {
                AuthScreen().navigationBarBackButtonHidden()
            }
            .onReceive(NotificationCenter.default.publisher(for: .bookingCreated)) { note in
                if let eb = note.object as? EnhancedBooking {
                    sharedBookingService.addBooking(eb)
                    DispatchQueue.main.async { sharedBookingService.objectWillChange.send() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .childAdded)) { note in
                if let child = note.object as? Child,
                   !children.contains(where: { $0.id == child.id }) {
                    children.append(child)
                }
            }
            .onReceive(apiService.$currentUser) { user in
                isLoadingChildren = false
                if let user = user { self.children = user.children ?? [] }
            }
            .overlay(successMessageOverlay)
        }
    }

    // MARK: - Helpers

    private func configureTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        UITabBar.appearance().standardAppearance   = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private var successMessageOverlay: some View {
        Group {
            if showingSuccessMessage {
                VStack {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text(successMessage)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(25)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 100)
                .animation(.easeInOut(duration: 0.3), value: showingSuccessMessage)
            }
        }
    }

    private func fetchChildrenFromBackend() {
        isLoadingChildren = true
        if let user = apiService.currentUser {
            self.children = user.children ?? []
        } else {
            self.children = []
        }
        isLoadingChildren = false
        apiService.fetchCurrentUser()
    }

    private func getRefundInfo(for booking: EnhancedBooking) -> String {
        let hours = Calendar.current.dateComponents([.hour], from: Date(), to: booking.bookingDate).hour ?? 0
        if hours >= 24 { return "You will receive a full refund minus the booking fee (£1.99)." }
        else if hours > 0 { return "Cancellation within 24 hours: No refund available." }
        else { return "This class has already taken place." }
    }

    private func cancelBooking(_ booking: EnhancedBooking) {
        var updated = booking.booking
        updated.status = .cancelled
        sharedBookingService.enhancedBookings[booking.booking.id] = EnhancedBooking(booking: updated, classInfo: booking.classInfo)
        if let idx = sharedBookingService.bookings.firstIndex(where: { $0.id == booking.booking.id }) {
            sharedBookingService.bookings[idx] = updated
        }
        sharedBookingService.saveBookings()
        notificationService.addNotification(UserNotification(
            title: "Booking Cancelled",
            message: "Your booking for '\(booking.className)' has been cancelled successfully.",
            type: .booking, actionType: .viewBooking,
            actionData: ["bookingId": booking.booking.id.uuidString]
        ))
        ProviderNotificationService.shared.sendBookingCancellationNotification(
            providerId: booking.classInfo.provider,
            className: booking.className,
            bookingDate: booking.booking.bookingDate,
            parentName: apiService.currentUser?.fullName ?? "Unknown User",
            bookingId: booking.booking.id.uuidString
        )
        bookingToCancel = nil
        showingCancelConfirmation = false
    }
}

// MARK: - Home Tab

private extension ParentDashboardScreen {

    // MARK: Home feed entry point

    var homeTab: some View {
        ZStack {
            Color.yugiCloud.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    greetingBar
                    VStack(spacing: 0) {
                        searchBarView
                        nextUpSection
                        venueCheckHeroCard
                        forYouSection
                        nearYouSection
                        browseByAgeSection
                    }
                }
            }
        }
        .onAppear  { startHomeAnimation() }
        .onDisappear { resetHomeAnimation() }
    }

    func startHomeAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { showGreeting   = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { showSearch     = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { showNextUp     = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.44) { showVenueCheck = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) { showForYou     = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.68) { showNearYou    = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.80) { showCategories = true }
    }

    func resetHomeAnimation() {
        showGreeting = false; showSearch = false; showNextUp = false
        showVenueCheck = false; showForYou = false; showNearYou = false
        showCategories = false
    }

    var greetingText: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Good morning" }
        else if h < 18 { return "Good afternoon" }
        else { return "Good evening" }
    }

    var firstName: String {
        let full = apiService.currentUser?.fullName ?? parentName
        return full.components(separatedBy: " ").first ?? full
    }

    // MARK: 1. Greeting bar

    var greetingBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(greetingText)
                .font(.custom("Raleway-Regular", size: 13))
                .foregroundColor(.white.opacity(0.75))
                .padding(.bottom, 4)
            Text(firstName)
                .font(.custom("Raleway-Medium", size: 26))
                .foregroundColor(.white)
                .tracking(-0.3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 28)
        .background(Color.yugiMocha.ignoresSafeArea(edges: .top))
        .opacity(showGreeting ? 1 : 0)
        .offset(y: showGreeting ? 0 : 12)
        .animation(.easeOut(duration: 0.6), value: showGreeting)
    }

    // MARK: 2. Search bar (straddles Mocha/Cloud boundary)

    var searchBarView: some View {
        Button(action: { showingClassSearchSheet = true }) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(Color.yugiMocha)
                Text("Search classes, venues, or providers")
                    .font(.custom("Raleway-Regular", size: 15))
                    .foregroundColor(Color.yugiBodyText.opacity(0.7))
                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.yugiOat, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 20)
        .padding(.top, -14)
        .padding(.bottom, 24)
        .opacity(showSearch ? 1 : 0)
        .offset(y: showSearch ? 0 : 12)
        .animation(.easeOut(duration: 0.6), value: showSearch)
    }

    // MARK: 3. Next Up section

    var nextUpBooking: EnhancedBooking? {
        sharedBookingService.bookings
            .filter { $0.status == .upcoming }
            .sorted { $0.bookingDate < $1.bookingDate }
            .first
            .flatMap { sharedBookingService.enhancedBookings[$0.id] }
    }

    var nextUpSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("NEXT UP")
                .font(.custom("Raleway-Medium", size: 11))
                .foregroundColor(Color.yugiBodyText)
                .tracking(0.5)
                .padding(.leading, 4)
                .padding(.bottom, 10)

            if let eb = nextUpBooking {
                nextUpCard(for: eb)
            } else {
                onboardingCard
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .opacity(showNextUp ? 1 : 0)
        .offset(y: showNextUp ? 0 : 12)
        .animation(.easeOut(duration: 0.6), value: showNextUp)
    }

    func nextUpCard(for eb: EnhancedBooking) -> some View {
        Button(action: { showingBookingsSheet = true }) {
            HStack(spacing: 14) {
                // Date column
                VStack(spacing: 0) {
                    Text(dayAbbrev(eb.booking.bookingDate))
                        .font(.custom("Raleway-Medium", size: 11))
                        .foregroundColor(Color.yugiMocha)
                        .tracking(0.3)
                    Text(dayNumber(eb.booking.bookingDate))
                        .font(.custom("Raleway-Medium", size: 22))
                        .foregroundColor(Color.yugiSoftBlack)
                        .padding(.vertical, 2)
                    Text(timeStr(eb.booking.bookingDate))
                        .font(.custom("Raleway-Regular", size: 11))
                        .foregroundColor(Color.yugiBodyText)
                }
                .frame(width: 48)

                // Divider
                Rectangle()
                    .fill(Color.yugiOat)
                    .frame(width: 0.5, height: 44)

                // Class details
                VStack(alignment: .leading, spacing: 3) {
                    Text(eb.className)
                        .font(.custom("Raleway-Medium", size: 15))
                        .foregroundColor(Color.yugiSoftBlack)
                        .lineLimit(1)
                    Text(eb.classInfo.location?.name ?? eb.providerName)
                        .font(.custom("Raleway-Regular", size: 12))
                        .foregroundColor(Color.yugiBodyText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 18))
                    .foregroundColor(Color.yugiMocha)
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.yugiOat, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }

    var onboardingCard: some View {
        VStack(spacing: 0) {
            // Top Oat band
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.yugiSage)
                        .frame(width: 52, height: 52)
                    Image(systemName: "star.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color.yugiDeepSage)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Let YUGI help")
                        .font(.custom("Raleway-Medium", size: 16))
                        .foregroundColor(Color.yugiSoftBlack)
                    Text("Tailored picks from your first tap")
                        .font(.custom("Raleway-Regular", size: 13))
                        .foregroundColor(Color.yugiBodyText)
                }
                Spacer()
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 20)
            .background(Color.yugiOat)

            // Lower section
            VStack(alignment: .leading, spacing: 14) {
                Text("Tell us about your children and where you are, and we'll curate classes that fit your week.")
                    .font(.custom("Raleway-Regular", size: 13))
                    .foregroundColor(Color.yugiBodyText)
                    .lineSpacing(13 * 0.55)

                Button(action: { showingClassSearchSheet = true }) {
                    Text("Find my first class")
                        .font(.custom("Raleway-Medium", size: 14))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.yugiMocha)
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
            .background(Color.white)
        }
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.yugiOat, lineWidth: 1))
    }

    // MARK: 4. Venue Check hero card

    var venueCheckHeroCard: some View {
        Button(action: { showingVenueCheckSheet = true }) {
            ZStack(alignment: .topLeading) {
                // Gradient background
                LinearGradient(
                    colors: [Color.yugiDeepSage, Color.yugiSage],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Decorative circles (non-interactive)
                GeometryReader { geo in
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 120, height: 120)
                        .position(x: geo.size.width + 20, y: -20)
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 80, height: 80)
                        .position(x: geo.size.width - 30, y: geo.size.height - 10)
                }
                .allowsHitTesting(false)

                // Content
                VStack(alignment: .leading, spacing: 0) {
                    Text("PARENT MOBILITY INTELLIGENCE")
                        .font(.custom("Raleway-Medium", size: 10))
                        .foregroundColor(.white)
                        .tracking(0.6)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(Color.white.opacity(0.25))
                        .clipShape(Capsule())
                        .padding(.bottom, 14)

                    Text("Going somewhere new\nwith your little one?")
                        .font(.custom("Raleway-Medium", size: 22))
                        .foregroundColor(.white)
                        .tracking(-0.3)
                        .lineSpacing(6)
                        .padding(.bottom, 6)

                    Text("Check accessibility, parking, and baby-changing before you go.")
                        .font(.custom("Raleway-Regular", size: 13))
                        .foregroundColor(.white.opacity(0.85))
                        .lineSpacing(7)
                        .frame(maxWidth: 260, alignment: .leading)
                        .padding(.bottom, 16)

                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 14))
                            .foregroundColor(Color.yugiDeepSage)
                        Text("Check a venue")
                            .font(.custom("Raleway-Medium", size: 14))
                            .foregroundColor(Color.yugiDeepSage)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                .padding(.top, 22)
                .padding(.bottom, 22)
                .padding(.horizontal, 20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .opacity(showVenueCheck ? 1 : 0)
        .offset(y: showVenueCheck ? 0 : 12)
        .animation(.easeOut(duration: 0.6), value: showVenueCheck)
    }

    // MARK: 5. For You section

    // TODO: Replace with real recommended-classes API response
    var sampleClasses: [SampleClassItem] {[
        SampleClassItem(title: "Baby Sensory",  location: "Clapham",   distance: "0.4mi", price: "£12", pramOK: true,  color: Color.yugiDustyBlush),
        SampleClassItem(title: "Toddler Yoga",  location: "Earlsfield",distance: "0.8mi", price: "£10", pramOK: false, color: Color.yugiSage),
        SampleClassItem(title: "Messy Play",    location: "Balham",    distance: "1.2mi", price: "£14", pramOK: true,  color: Color.yugiOat),
        SampleClassItem(title: "Storytime Fun", location: "Streatham", distance: "1.5mi", price: "£8",  pramOK: false, color: Color.yugiDustyBlush),
        SampleClassItem(title: "Music Makers",  location: "Wimbledon", distance: "2.1mi", price: "£15", pramOK: true,  color: Color.yugiSage),
    ]}

    var forYouSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Row header
            HStack {
                Text("FOR YOU")
                    .font(.custom("Raleway-Medium", size: 11))
                    .foregroundColor(Color.yugiBodyText)
                    .tracking(0.5)
                    .padding(.leading, 4)
                Spacer()
                Button(action: { showingClassSearchSheet = true }) {
                    Text("See all ›")
                        .font(.custom("Raleway-Medium", size: 13))
                        .foregroundColor(Color.yugiMocha)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            // Horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(sampleClasses) { item in
                        // TODO: Wire to ClassDetailScreen once real data is wired
                        Button(action: { showingClassSearchSheet = true }) {
                            forYouCard(item)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 24)
        .opacity(showForYou ? 1 : 0)
        .offset(y: showForYou ? 0 : 12)
        .animation(.easeOut(duration: 0.6), value: showForYou)
    }

    func forYouCard(_ item: SampleClassItem) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image placeholder
            Rectangle()
                .fill(item.color)
                .frame(height: 90)

            // Content
            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .font(.custom("Raleway-Medium", size: 13))
                    .foregroundColor(Color.yugiSoftBlack)
                    .lineLimit(1)
                    .padding(.bottom, 4)

                Text("\(item.location) · \(item.distance)")
                    .font(.custom("Raleway-Regular", size: 11))
                    .foregroundColor(Color.yugiBodyText)
                    .padding(.bottom, 8)

                HStack {
                    Text(item.price)
                        .font(.custom("Raleway-Medium", size: 13))
                        .foregroundColor(Color.yugiSoftBlack)
                    Spacer()
                    if item.pramOK {
                        Text("PRAM OK")
                            .font(.custom("Raleway-Medium", size: 10))
                            .foregroundColor(Color.yugiDeepSage)
                            .tracking(0.3)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 7)
                            .background(Color.yugiSage)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(12)
        }
        .frame(width: 180)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.yugiOat, lineWidth: 1))
        .clipped()
    }

    // MARK: 6. Near You section

    var nearYouSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("NEAR YOU")
                    .font(.custom("Raleway-Medium", size: 11))
                    .foregroundColor(Color.yugiBodyText)
                    .tracking(0.5)
                    .padding(.leading, 4)
                Spacer()
                // TODO: Navigate to map screen when one exists
                Button(action: { showingClassSearchSheet = true }) {
                    Text("See map ›")
                        .font(.custom("Raleway-Medium", size: 13))
                        .foregroundColor(Color.yugiMocha)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            // Map preview card
            // TODO: Replace Color.yugiOat placeholder with lightweight MapKit snapshot when performance-validated
            Button(action: { showingClassSearchSheet = true }) {
                ZStack(alignment: .bottomLeading) {
                    // Oat background with subtle diagonal-stripe overlay
                    ZStack {
                        Color.yugiOat
                        DiagonalStripesShape()
                            .fill(Color.white.opacity(0.3))
                    }

                    // Decorative pin dots
                    Circle()
                        .fill(Color.yugiMocha)
                        .frame(width: 12, height: 12)
                        .shadow(color: Color.yugiMocha.opacity(0.25), radius: 4)
                        .position(x: 60, y: 40)
                    Circle()
                        .fill(Color.yugiMocha)
                        .frame(width: 12, height: 12)
                        .shadow(color: Color.yugiMocha.opacity(0.25), radius: 4)
                        .position(x: 140, y: 80)
                    Circle()
                        .fill(Color.yugiMocha)
                        .frame(width: 12, height: 12)
                        .shadow(color: Color.yugiMocha.opacity(0.25), radius: 4)
                        .position(x: 230, y: 55)

                    // Bottom-left label pill
                    // TODO: Replace "12" with dynamic count from nearby classes service
                    Text("12 classes within 2mi")
                        .font(.custom("Raleway-Medium", size: 12))
                        .foregroundColor(Color.yugiSoftBlack)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .padding(12)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .frame(height: 140)
            .cornerRadius(16)
            .clipped()
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 20)
        .opacity(showNearYou ? 1 : 0)
        .offset(y: showNearYou ? 0 : 12)
        .animation(.easeOut(duration: 0.6), value: showNearYou)
    }

    // MARK: 7. Browse by Age section

    var browseByAgeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BROWSE BY AGE")
                .font(.custom("Raleway-Medium", size: 11))
                .foregroundColor(Color.yugiBodyText)
                .tracking(0.5)
                .padding(.leading, 4)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ClassCategory.allCases, id: \.self) { cat in
                        Button(action: { showingClassSearchSheet = true }) {
                            ageCategoryTile(cat)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 32)
        .opacity(showCategories ? 1 : 0)
        .offset(y: showCategories ? 0 : 12)
        .animation(.easeOut(duration: 0.6), value: showCategories)
    }

    func ageCategoryTile(_ category: ClassCategory) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.yugiOat)
                    .frame(width: 32, height: 32)
                Image(systemName: category.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(Color.yugiMocha)
            }
            Text(category.displayName)
                .font(.custom("Raleway-Medium", size: 12))
                .foregroundColor(Color.yugiSoftBlack)
                .multilineTextAlignment(.center)
        }
        .frame(width: 90)
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background(Color.white)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.yugiOat, lineWidth: 1))
    }

    // MARK: Date helpers

    func dayAbbrev(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f.string(from: date).uppercased()
    }
    func dayNumber(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: date)
    }
    func timeStr(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
    }
}

// MARK: - Children Tab

private extension ParentDashboardScreen {
    var childrenTab: some View {
        ZStack {
            Color.yugiMocha.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("My Children")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: { showingAddChild = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill").font(.system(size: 20))
                                    Text("Add Child").font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 1))
                            }
                        }

                        if isLoadingChildren {
                            HStack {
                                ProgressView()
                                Text("Loading children...").foregroundColor(.white)
                            }
                            .padding(.vertical, 20)
                        } else if let err = childrenError {
                            Text(err).foregroundColor(.red).padding(.vertical, 20)
                        } else if children.isEmpty {
                            ParentEmptyStateView(
                                icon: "person.2.fill",
                                title: "No Children Added",
                                message: "Add your children to start booking classes for them"
                            ) { showingAddChild = true }
                        } else {
                            ForEach(children, id: \.id) { child in
                                ChildCard(child: child) {
                                    childToEdit = child
                                    showingEditChild = true
                                }
                            }
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
    }
}

// MARK: - Profile Tab

private extension ParentDashboardScreen {
    var profileTab: some View {
        ZStack {
            Color.yugiMocha.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Account")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        VStack(spacing: 12) {
                            ProfileRow(icon: "person.fill", title: "Personal Information",
                                       subtitle: "Update your details", badge: nil) {
                                showingPersonalInformation = true
                            }
                            ProfileRow(icon: "creditcard.fill", title: "Payment Method",
                                       subtitle: "Manage your payment methods", badge: nil) {
                                showingPaymentMethods = true
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Settings")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        VStack(spacing: 12) {
                            ProfileRow(
                                icon: "bell.fill", title: "Notifications",
                                subtitle: "Manage your preferences",
                                badge: notificationService.unreadCount > 0 ? "\(notificationService.unreadCount)" : nil
                            ) { showingNotifications = true }
                        }
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Support")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        VStack(spacing: 12) {
                            ProfileRow(icon: "message.fill", title: "Contact Us",
                                       subtitle: "Reach out to our support team", badge: nil) {
                                showingContactForm = true
                            }
                            ProfileRow(icon: "doc.text.fill", title: "Terms of Service",
                                       subtitle: "Read our terms and conditions", badge: nil) {
                                showingTermsPrivacy = true
                            }
                        }
                    }
                    VStack(spacing: 16) {
                        Button(action: {
                            apiService.logout()
                            sharedBookingService.bookings.removeAll()
                            sharedBookingService.enhancedBookings.removeAll()
                            notificationService.clearAllNotifications()
                            SharedPaymentService.shared.paymentMethods.removeAll()
                            biometricService.clearSavedCredentials()
                            biometricService.setRememberMeEnabled(false)
                            biometricService.setBiometricEnabled(false)
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
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2), lineWidth: 1))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.top, 20)
                }
                .padding(20)
            }
        }
    }
}

// MARK: - Diagonal Stripes Shape (Near You card background)

private struct DiagonalStripesShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let stripeWidth: CGFloat = 12
        let gap: CGFloat = 12
        let total = stripeWidth + gap
        let count = Int((rect.width + rect.height) / total) + 2
        for i in 0...count {
            let x = CGFloat(i) * total - rect.height
            path.move(to: CGPoint(x: x, y: rect.height))
            path.addLine(to: CGPoint(x: x + stripeWidth, y: rect.height))
            path.addLine(to: CGPoint(x: x + stripeWidth + rect.height, y: 0))
            path.addLine(to: CGPoint(x: x + rect.height, y: 0))
            path.closeSubpath()
        }
        return path
    }
}

// MARK: - Sample Class Model

private struct SampleClassItem: Identifiable {
    let id    = UUID()
    let title:    String
    let location: String
    let distance: String
    let price:    String
    let pramOK:   Bool
    let color:    Color
}

// MARK: - Supporting Views (preserved from original)

struct BookingCard: View {
    let booking: Booking
    let enhancedBooking: EnhancedBooking?
    let onCancel: (() -> Void)?
    let onVenueAnalysis: (() -> Void)?

    init(booking: Booking, enhancedBooking: EnhancedBooking? = nil,
         onCancel: (() -> Void)? = nil, onVenueAnalysis: (() -> Void)? = nil) {
        self.booking = booking; self.enhancedBooking = enhancedBooking
        self.onCancel = onCancel; self.onVenueAnalysis = onVenueAnalysis
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(enhancedBooking?.className ?? "Class Name")
                    .font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                Text(enhancedBooking?.providerName ?? "Provider Name")
                    .font(.system(size: 14)).foregroundColor(.white.opacity(0.7))
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatDate(booking.bookingDate))
                        .font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                    Text(formatTime(booking.bookingDate))
                        .font(.system(size: 14)).foregroundColor(.white.opacity(0.7))
                    Text("\(booking.numberOfParticipants) participants")
                        .font(.system(size: 14)).foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                if let eb = enhancedBooking {
                    Text("£\(NSDecimalNumber(decimal: eb.price).doubleValue, specifier: "%.2f")")
                        .font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                }
            }
            if let eb = enhancedBooking {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle").font(.system(size: 14))
                        .foregroundColor(Color.yugiMocha).frame(width: 16)
                    Text(eb.classInfo.location?.address.formatted ?? "Location TBD")
                        .font(.system(size: 14)).foregroundColor(.white.opacity(0.8))
                    Spacer()
                }
                Button(action: { openInAppleMaps(enhancedBooking: eb) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "map").font(.system(size: 14))
                        Text("View in Maps").font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color.yugiMocha).cornerRadius(8)
                }
            }
            if booking.status == .upcoming {
                HStack {
                    Button("Venue Analysis") { onVenueAnalysis?() }
                        .font(.system(size: 14, weight: .medium)).foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 1))
                    Spacer()
                    Button("Cancel") { onCancel?() }
                        .font(.system(size: 14, weight: .medium)).foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.6), lineWidth: 1))
                }
            }
        }
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white, lineWidth: 1))
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"; return f.string(from: date)
    }
    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: date)
    }
    private func openInAppleMaps(enhancedBooking: EnhancedBooking) {
        let coords = enhancedBooking.classInfo.location?.coordinates ?? Location.Coordinates(latitude: 51.5074, longitude: -0.1278)
        let name = enhancedBooking.classInfo.location?.name ?? "Location TBD"
        guard let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "maps://?q=\(encoded)&ll=\(coords.latitude),\(coords.longitude)") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else if let gUrl = URL(string: "https://maps.google.com/?q=\(encoded)&ll=\(coords.latitude),\(coords.longitude)") {
            UIApplication.shared.open(gUrl, options: [:], completionHandler: nil)
        }
    }
}

struct ChildCard: View {
    let child: Child
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.yugiMocha.opacity(0.1)).frame(width: 60, height: 60)
                Text(String(child.name.prefix(1)))
                    .font(.system(size: 24, weight: .bold)).foregroundColor(Color.yugiMocha)
            }
            Text(child.name)
                .font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer()
            Button(action: onEdit) {
                VStack(spacing: 4) {
                    Image(systemName: "pencil.circle.fill").font(.system(size: 24)).foregroundColor(.white)
                    Text("Edit").font(.system(size: 12, weight: .medium)).foregroundColor(.white)
                }
            }
        }
        .padding(16)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white, lineWidth: 1))
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
                Image(systemName: icon).font(.system(size: 20))
                    .foregroundColor(Color.yugiMocha).frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .medium)).foregroundColor(.white)
                    Text(subtitle).font(.system(size: 14)).foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                if let b = badge {
                    Text(b).font(.system(size: 12, weight: .medium)).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.white.opacity(0.2)).cornerRadius(12)
                }
                Image(systemName: "chevron.right").font(.system(size: 14)).foregroundColor(.white.opacity(0.5))
            }
            .padding()
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white, lineWidth: 1))
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
            Image(systemName: icon).font(.system(size: 48)).foregroundColor(Color.yugiGray.opacity(0.3))
            VStack(spacing: 8) {
                Text(title).font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                Text(message).font(.system(size: 14)).foregroundColor(.white.opacity(0.7)).multilineTextAlignment(.center)
            }
            Button(action: action) {
                Text("Add Child").font(.system(size: 16, weight: .medium)).foregroundColor(.white)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Color.yugiMocha).cornerRadius(8)
            }
        }
        .padding(32)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white, lineWidth: 1))
    }
}

// MARK: - Extensions

extension ClassStatus {
    var textColor: Color { .white }
}

extension Notification.Name {
    static let bookingCreated = Notification.Name("bookingCreated")
    static let bookingCompleted = Notification.Name("bookingCompleted")
    static let childAdded   = Notification.Name("childAdded")
    static let childUpdated = Notification.Name("childUpdated")
    static let childDeleted = Notification.Name("childDeleted")
}

#Preview {
    ParentDashboardScreen(parentName: "Sarah Johnson", initialTab: 0)
}
