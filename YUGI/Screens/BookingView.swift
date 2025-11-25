import SwiftUI
import PassKit
import Combine

struct BookingView: View {
    let classItem: Class
    let viewModel: ClassDiscoveryViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var baseParticipants = 2 // 1 adult + 1 child (base booking)
    @State private var requirements = ""
    @State private var selectedPaymentMethod: PaymentMethod = .applePay
    @State private var selectedSavedCard: UserPaymentMethod?
    @State private var isProcessing = false
    @State private var error: Error?
    @State private var showingConfirmation = false
    @State private var showingErrorAlert = false
    @State private var showingPaymentSheet = false
    @State private var selectedChildren: [Child] = []
    @State private var shouldNavigateToParentDashboard = false
    @State private var shouldNavigateToProviderDashboard = false // New state for provider navigation
    @State private var isProviderUser = false // State variable for provider status
    @StateObject private var notificationService = NotificationService.shared
    
    private var apiService = APIService.shared
    @StateObject private var sharedPaymentService = SharedPaymentService.shared
    
    // Public initializer
    init(classItem: Class, viewModel: ClassDiscoveryViewModel) {
        self.classItem = classItem
        self.viewModel = viewModel
    }
    
    private var totalParticipants: Int {
        baseParticipants
    }
    
    private var availableChildren: [Child] {
        // Get children from current user (parent children)
        let parentChildren = apiService.currentUser?.children ?? []
        
        // Get provider children from shared storage (if this is a provider booking)
        let providerChildren = ProviderChildrenService.shared.children
        
        // Combine both sets of children, avoiding duplicates
        var allChildren = parentChildren
        for providerChild in providerChildren {
            if !allChildren.contains(where: { $0.id == providerChild.id }) {
                allChildren.append(providerChild)
            }
        }
        
        return allChildren
    }
    
    private var totalPrice: Decimal {
        let base = classItem.pricing.amount // base price for 1 adult + 1 child
        let serviceFee: Decimal = 1.99
        return base + serviceFee
    }
    
    private var basePrice: Decimal {
        return classItem.pricing.amount
    }
    
    private var serviceFee: Decimal {
        1.99
    }
    
    // Debug information
    private var debugInfo: String {
        "Base: \(basePrice) | Service Fee: \(serviceFee) | Total: \(totalPrice)"
    }
    
    private var totalPriceText: String {
        // Use Decimal's string formatting
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "£"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(for: totalPrice as NSDecimalNumber) ?? "£--"
    }
    
    private func setupDefaultPaymentMethod() {
        // Check if user has saved payment methods
        if !sharedPaymentService.paymentMethods.isEmpty {
            // Find the default payment method
            if let defaultCard = sharedPaymentService.paymentMethods.first(where: { $0.isDefault }) {
                selectedPaymentMethod = .card
                selectedSavedCard = defaultCard
                print("🎯 BookingView: Auto-selected default card: \(defaultCard.lastFourDigits)")
            } else if let firstCard = sharedPaymentService.paymentMethods.first {
                selectedPaymentMethod = .card
                selectedSavedCard = firstCard
                print("🎯 BookingView: Auto-selected first available card: \(firstCard.lastFourDigits)")
            }
        } else {
            // No saved cards, keep Apple Pay as default
            selectedPaymentMethod = .applePay
            selectedSavedCard = nil
            print("🎯 BookingView: No saved cards, using Apple Pay as default")
        }
    }
    
    // Apple Wallet functionality
    private func addToAppleWallet(for booking: Booking) {
        guard PKAddPassesViewController.canAddPasses() else {
            print("Apple Wallet is not available")
            return
        }
        
        // For now, we'll show a success message
        // In a real implementation, you would:
        // 1. Create a proper .pkpass file with all required certificates
        // 2. Use PKAddPassesViewController to add it to Apple Wallet
        print("Apple Wallet pass would be added for booking: \(booking.id)")
        
        // Show a success message
        DispatchQueue.main.async {
            // In a real app, this would present the PKAddPassesViewController
            // with a properly formatted .pkpass file
            print("Apple Wallet integration ready!")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Check if current user is a provider
    private var isProvider: Bool {
        return isProviderUser
    }
    
    // MARK: - View Components
    
    private var backgroundView: some View {
        Color(hex: "#BC6C5C")
            .ignoresSafeArea()
    }
    
    private var mainContentView: some View {
        VStack {
            ScrollView {
                VStack(spacing: 24) {
                    classDetailsSection
                    bookingOptionsSection
                    childSelectionSection
                    paymentMethodsSection
                    totalAndBookSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
    }
    
    private var classDetailsSection: some View {
        ClassDetailsCard(classItem: classItem)
    }
    
    private var bookingOptionsSection: some View {
        BookingOptionsCard(
            participants: $baseParticipants,
            requirements: $requirements,
            basePrice: basePrice,
            serviceFee: serviceFee,
            totalPrice: totalPrice
        )
    }
    
    private var childSelectionSection: some View {
        Group {
            if !availableChildren.isEmpty {
                ChildSelectionCard(
                    availableChildren: availableChildren,
                    selectedChildren: $selectedChildren,
                    totalParticipants: totalParticipants
                )
            }
        }
    }
    
    private var paymentMethodsSection: some View {
        PaymentMethodsCard(
            selectedMethod: $selectedPaymentMethod,
            selectedSavedCard: $selectedSavedCard
        )
    }
    
    private var totalAndBookSection: some View {
        TotalAndBookSection(
            totalPrice: totalPrice,
            isProcessing: isProcessing,
            onBook: {
                print("🎯 BookingView: Proceed to Payment button tapped!")
                showingPaymentSheet = true
            }
        )
    }
    
    private var contentView: some View {
        ZStack {
            backgroundView
            mainContentView
        }
    }
    
    private var paymentSheet: some View {
        PaymentSheet(
            classItem: classItem,
            participants: totalParticipants,
            selectedChildren: selectedChildren,
            requirements: requirements,
            totalPrice: totalPrice,
            paymentMethod: selectedPaymentMethod,
            selectedSavedCard: selectedSavedCard,
            onSuccess: handlePaymentSuccess,
            onError: handlePaymentError
        )
    }
    
    private func handlePaymentSuccess(_ enhancedBooking: EnhancedBooking) {
        print("🎯 BookingView: Payment successful!")
        print("🎯 BookingView: EnhancedBooking created with class: \(enhancedBooking.className)")
        print("🎯 BookingView: EnhancedBooking created with provider: \(enhancedBooking.providerName)")
        print("🎯 BookingView: EnhancedBooking created with price: \(enhancedBooking.price)")
        
        // Add booking to SharedBookingService so it appears in Children Bookings
        SharedBookingService.shared.addBooking(enhancedBooking)
        print("🎯 BookingView: Added booking to SharedBookingService for Children Bookings")
        
        // Send notifications
        notificationService.sendBookingNotification(for: enhancedBooking)
        notificationService.sendPaymentNotification(amount: enhancedBooking.price, className: enhancedBooking.className)
        
        // Send provider notifications
        let providerId = enhancedBooking.classInfo.provider
        let parentName = "Sarah Johnson" // In a real app, this would come from user data
        let bookingDate = enhancedBooking.booking.bookingDate
        let bookingId = enhancedBooking.booking.id.uuidString
        let participants = enhancedBooking.booking.numberOfParticipants
        
        // Send new booking notification to provider
        ProviderNotificationService.shared.sendNewBookingNotification(
            providerId: providerId,
            className: enhancedBooking.className,
            bookingDate: bookingDate,
            parentName: parentName,
            bookingId: bookingId,
            participants: participants
        )
        
        // Dismiss the payment sheet
        showingPaymentSheet = false
        
        // Show success confirmation alert
        showingConfirmation = true
    }
    
    private func handlePaymentError(_ error: Error) {
        print("❌ BookingView: Payment error occurred: \(error)")
        if let apiError = error as? APIError {
            print("❌ BookingView: APIError details: \(apiError.localizedDescription)")
        }
        self.error = error
        showingPaymentSheet = false
        showingErrorAlert = true
    }
    
    private func errorMessage(for error: Error?) -> String {
        guard let error = error else {
            return "An unexpected error occurred"
        }
        
        // Handle APIError
        if let apiError = error as? APIError {
            return apiError.localizedDescription
        }
        
        // Handle NSError
        if let nsError = error as NSError? {
            if let description = nsError.userInfo[NSLocalizedDescriptionKey] as? String {
                return description
            }
            return nsError.localizedDescription
        }
        
        // Handle BookingService.BookingError
        if let bookingError = error as? BookingService.BookingError {
            return bookingError.message
        }
        
        // Fallback
        return error.localizedDescription.isEmpty ? "An unexpected error occurred" : error.localizedDescription
    }
    
    private var navigationModifiers: some View {
        EmptyView()
            .navigationTitle("Book Class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color(hex: "#BC6C5C"), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#BC6C5C"))
                }
            }
    }
    
    var body: some View {
        navigationContent
            .sheet(isPresented: $showingPaymentSheet) {
                paymentSheet
            }
            .alert("Payment Error", isPresented: $showingErrorAlert) {
                Button("OK") {
                    error = nil
                    showingErrorAlert = false
                }
            } message: {
                Text(errorMessage(for: error))
            }
            .alert("Booking Confirmed!", isPresented: $showingConfirmation) {
                Button("OK") {
                    showingConfirmation = false
                    // Dismiss the booking view after showing success
                    dismiss()
                }
            } message: {
                Text("Your booking has been confirmed successfully! We'll send you a confirmation email shortly.")
            }
            .fullScreenCover(isPresented: $shouldNavigateToParentDashboard) {
                ParentDashboardScreen(parentName: apiService.currentUser?.fullName ?? "Parent", initialTab: 0)
            }
            .fullScreenCover(isPresented: $shouldNavigateToProviderDashboard) {
                ProviderDashboardScreen(businessName: apiService.currentUser?.businessName ?? "Provider")
            }
            .onAppear {
                setupBookingView()
            }
            .onReceive(apiService.$currentUser) { user in
                handleUserDataChange(user)
            }
            .onReceive(NotificationCenter.default.publisher(for: .childAdded)) { notification in
                handleChildAdded(notification)
            }
    }
    
    private var navigationContent: some View {
        NavigationStack {
            contentView
        }
        .navigationTitle("Book Class")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(hex: "#BC6C5C"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(Color(hex: "#BC6C5C"))
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleBookingConfirmation() {
        print("🎯 BookingView: Alert button tapped!")
        print("🎯 BookingView: isProvider = \(isProvider)")
        print("🎯 BookingView: isProviderUser = \(isProviderUser)")
        print("🎯 BookingView: Current user type = \(apiService.currentUser?.userType.rawValue ?? "unknown")")
        print("🎯 BookingView: Current user fullName = \(apiService.currentUser?.fullName ?? "unknown")")
        print("🎯 BookingView: Current user businessName = \(apiService.currentUser?.businessName ?? "unknown")")
        print("🎯 BookingView: Button text = \(isProvider ? "View Dashboard" : "View My Bookings")")
        
        // Force refresh the provider status right before navigation
        let currentUserType = apiService.currentUser?.userType
        let isCurrentlyProvider = currentUserType == .provider
        
        print("🎯 BookingView: Force refresh - currentUserType = \(currentUserType?.rawValue ?? "unknown")")
        print("🎯 BookingView: Force refresh - isCurrentlyProvider = \(isCurrentlyProvider)")
        print("🎯 BookingView: Force refresh - isProviderUser = \(isProviderUser)")
        print("🎯 BookingView: Force refresh - isProvider = \(isProvider)")
        
        // Use the force-refreshed provider status for navigation decision
        if isCurrentlyProvider {
            print("🎯 BookingView: FINAL DECISION - Navigating to provider dashboard...")
            shouldNavigateToProviderDashboard = true
            print("🎯 BookingView: FINAL DECISION - shouldNavigateToProviderDashboard set to: \(shouldNavigateToProviderDashboard)")
        } else {
            print("🎯 BookingView: FINAL DECISION - Navigating to parent dashboard...")
            shouldNavigateToParentDashboard = true
            print("🎯 BookingView: FINAL DECISION - shouldNavigateToParentDashboard set to: \(shouldNavigateToParentDashboard)")
        }
    }
    
    private func setupBookingView() {
        print("🎯 BookingView loaded for class: \(classItem.name)")
        print("🎯 BookingView: Available children count: \(availableChildren.count)")
        print("🎯 BookingView: Current user type: \(apiService.currentUser?.userType.rawValue ?? "unknown")")
        print("🎯 BookingView: Is provider: \(isProvider)")
        print("🎯 BookingView: Current user fullName: \(apiService.currentUser?.fullName ?? "unknown")")
        print("🎯 BookingView: Current user businessName: \(apiService.currentUser?.businessName ?? "unknown")")
        print("🎯 BookingView: apiService.isAuthenticated: \(apiService.isAuthenticated)")
        print("🎯 BookingView: apiService.authToken: \(apiService.authToken?.prefix(20) ?? "None")...")
        
        // Set initial provider status
        let initialProviderStatus = apiService.currentUser?.userType == .provider
        isProviderUser = initialProviderStatus
        print("🎯 BookingView: Initial provider status set to: \(initialProviderStatus)")
        
        // Auto-select default payment method
        setupDefaultPaymentMethod()
        print("🎯 BookingView: isProviderUser after setting: \(isProviderUser)")
    }
    
    private func handleUserDataChange(_ user: User?) {
        // Update provider status when user data changes
        let wasProvider = isProviderUser
        isProviderUser = user?.userType == .provider
        print("🎯 BookingView: User data changed - isProviderUser = \(isProviderUser)")
        print("🎯 BookingView: User type = \(user?.userType.rawValue ?? "unknown")")
        print("🎯 BookingView: User data changed - wasProvider = \(wasProvider), nowProvider = \(isProviderUser)")
        print("🎯 BookingView: User data changed - user?.userType == .provider = \(user?.userType == .provider)")
        
        // Test: Print the raw value comparison
        if let userType = user?.userType {
            print("🎯 BookingView: User type raw value: '\(userType.rawValue)'")
            print("🎯 BookingView: Comparing '\(userType.rawValue)' == 'provider': \(userType.rawValue == "provider")")
            print("🎯 BookingView: Comparing userType == .provider: \(userType == .provider)")
        }
    }
    
    private func handleChildAdded(_ notification: Notification) {
        print("🎯 BookingView: Received childAdded notification")
        if let newChild = notification.object as? Child {
            print("🎯 BookingView: New child added: \(newChild.name)")
            // The view will automatically update when availableChildren is re-evaluated
            // No need to force refresh - SwiftUI will handle this automatically
        }
    }
}

// MARK: - Supporting Views

struct ClassDetailsCard: View {
    let classItem: Class
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(classItem.name)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text(classItem.providerName ?? "Provider \(classItem.provider)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "#BC6C5C").opacity(0.7))
                }
                
                Spacer()
            }
            
            // Details
            VStack(alignment: .leading, spacing: 12) {
                BookingDetailRow(icon: "calendar", text: formatSchedule(classItem.schedule))
                BookingDetailRow(icon: "mappin.circle", text: classItem.location?.address.formatted ?? "Location TBD")
                BookingDetailRow(icon: "car.fill", text: classItem.location?.parkingInfo ?? "No parking info")
                BookingDetailRow(icon: "person.2.fill", text: classItem.location?.babyChangingFacilities ?? "No changing facilities")
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
    
    private func formatSchedule(_ schedule: Schedule) -> String {
        let days = schedule.formattedDays
        guard let timeSlot = schedule.timeSlots.first else {
            return days.isEmpty ? "" : days
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "\(days) \(formatter.string(from: timeSlot.startTime))"
    }
}

struct BookingOptionsCard: View {
    @Binding var participants: Int
    @Binding var requirements: String
    let basePrice: Decimal
    let serviceFee: Decimal
    let totalPrice: Decimal
    
    // Debug information
    private var debugInfo: String {
        "Base: \(basePrice) | Service Fee: \(serviceFee) | Total: \(totalPrice)"
    }
    
    private var totalPriceText: String {
        // Use Decimal's string formatting
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "£"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(for: totalPrice as NSDecimalNumber) ?? "£--"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Booking Options")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "#BC6C5C"))
            
            // Base Participants (1 Adult + 1 Child)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("1 Adult + 1 Child")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "#BC6C5C"))
                        
                        Text("Standard booking includes one adult and one child")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#BC6C5C").opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Text("Included")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
            }
            

            
            // Special Requirements
            VStack(alignment: .leading, spacing: 8) {
                Text("Special Requirements (Optional)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "#BC6C5C"))
                
                TextField("Any special needs or requests...", text: $requirements, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .foregroundColor(Color(hex: "#BC6C5C"))
            }
            
            // Price Summary
            VStack(spacing: 8) {
                HStack {
                    Text("Subtotal")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#BC6C5C").opacity(0.8))
                    
                    Spacer()
                    
                    Text(String(format: "£%.2f", NSDecimalNumber(decimal: basePrice).doubleValue))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#BC6C5C").opacity(0.8))
                }
                
                HStack {
                    Text("Service Fee")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#BC6C5C").opacity(0.8))
                    
                    Spacer()
                    
                    Text("£1.99")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#BC6C5C").opacity(0.8))
                }
                
                Divider()
                    .background(Color(hex: "#BC6C5C").opacity(0.3))
                
                HStack {
                    Text("Total")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Spacer()
                    
                    Text(totalPriceText)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                }
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

struct PaymentMethodsCard: View {
    @Binding var selectedMethod: PaymentMethod
    @Binding var selectedSavedCard: UserPaymentMethod?
    @StateObject private var sharedPaymentService = SharedPaymentService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payment Method")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "#BC6C5C"))
            
            VStack(spacing: 12) {
                // Show saved cards first
                if !sharedPaymentService.paymentMethods.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Saved Cards")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#BC6C5C").opacity(0.8))
                        
                        ForEach(sharedPaymentService.paymentMethods, id: \.id) { card in
                            SavedCardRow(
                                card: card,
                                isSelected: selectedSavedCard?.id == card.id
                            ) {
                                selectedSavedCard = card
                                selectedMethod = .card
                            }
                        }
                    }
                    
                    Divider()
                }
                
                // Show other payment methods
                ForEach(PaymentMethod.allCases, id: \.self) { method in
                    PaymentMethodRow(
                        method: method,
                        isSelected: selectedMethod == method && selectedSavedCard == nil
                    ) {
                        selectedMethod = method
                        selectedSavedCard = nil
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

struct SavedCardRow: View {
    let card: UserPaymentMethod
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Card icon
                Image(systemName: card.type.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(card.type.color)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(card.type.color.opacity(0.1))
                    )
                
                // Card details
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("•••• \(card.lastFourDigits)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "#BC6C5C"))
                        
                        if card.isDefault {
                            Text("DEFAULT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#BC6C5C"))
                                .cornerRadius(4)
                        }
                    }
                    
                    Text("Expires \(String(format: "%02d/%d", card.expiryMonth, card.expiryYear))")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(hex: "#BC6C5C").opacity(0.7))
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                } else {
                    Circle()
                        .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: "#BC6C5C").opacity(0.05) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color(hex: "#BC6C5C").opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PaymentMethodRow: View {
    let method: PaymentMethod
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: method.iconName)
                    .font(.system(size: 20))
                    .foregroundColor(method.iconColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(method.iconColor.opacity(0.1))
                    )
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(method.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text(method.description)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(hex: "#BC6C5C").opacity(0.7))
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                } else {
                    Circle()
                        .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: "#BC6C5C").opacity(0.05) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color(hex: "#BC6C5C").opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TotalAndBookSection: View {
    let totalPrice: Decimal
    let isProcessing: Bool
    let onBook: () -> Void
    
    private var totalPriceText: String {
        let number = NSDecimalNumber(decimal: totalPrice)
        return String(format: "£%.2f", number.doubleValue)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Total
            HStack {
                Text("Total Amount")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(totalPriceText)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.15))
            .cornerRadius(16)
            
            // Book Button
            Button(action: onBook) {
                HStack(spacing: 12) {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 18))
                    }
                    
                    Text(isProcessing ? "Processing..." : "Proceed to Payment")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.8)]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            }
            .disabled(isProcessing)
        }
    }
}

struct BookingDetailRow: View {
    let icon: String
    let text: String
    
    // Check if this is an address row (icon is mappin.circle)
    private var isAddress: Bool {
        icon == "mappin.circle"
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#BC6C5C"))
                .frame(width: 20)
                .padding(.top, 2) // Align icon with first line of text
            
            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color(hex: "#BC6C5C").opacity(0.8))
                .lineLimit(isAddress ? nil : 2) // No limit for addresses, 2 lines for others
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

// MARK: - Payment Method Enum

enum PaymentMethod: CaseIterable {
    case applePay
    case card
    
    var displayName: String {
        switch self {
        case .applePay: return "Apple Pay"
        case .card: return "Credit/Debit Card"
        }
    }
    
    var description: String {
        switch self {
        case .applePay: return "Fast and secure payment"
        case .card: return "Visa, Mastercard, Amex"
        }
    }
    
    var iconName: String {
        switch self {
        case .applePay: return "applelogo"
        case .card: return "creditcard.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .applePay: return .black
        case .card: return .blue
        }
    }
}

// MARK: - Payment Sheet

struct PaymentSheet: View {
    let classItem: Class
    let participants: Int
    let selectedChildren: [Child]
    let requirements: String
    let totalPrice: Decimal
    let paymentMethod: PaymentMethod
    let selectedSavedCard: UserPaymentMethod?
    let onSuccess: (EnhancedBooking) -> Void
    let onError: (Error) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var showingAddPaymentMethod = false
    @State private var newPaymentMethod: UserPaymentMethod?
    @StateObject private var sharedPaymentService = SharedPaymentService.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Payment Summary
                PaymentSummaryView(
                    classItem: classItem,
                    participants: participants,
                    selectedChildren: selectedChildren,
                    totalPrice: totalPrice,
                    selectedSavedCard: selectedSavedCard ?? newPaymentMethod,
                    paymentMethod: paymentMethod
                )
                
                Spacer()
                
                // Payment Button or Add Card Option
                if paymentMethod == .card && selectedSavedCard == nil && newPaymentMethod == nil {
                    // Show "Add New Card" button when no saved card is selected
                    VStack(spacing: 16) {
                        Button(action: {
                            showingAddPaymentMethod = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18))
                                Text("Add New Card")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(hex: "#BC6C5C"))
                            .cornerRadius(12)
                        }
                        
                        Text("Or use Apple Pay for faster checkout")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    // Show payment button for Apple Pay or when card is selected
                    PaymentButton(
                        paymentMethod: paymentMethod,
                        totalPrice: totalPrice,
                        classItem: classItem,
                        participants: participants,
                        selectedChildren: selectedChildren,
                        requirements: requirements,
                        selectedSavedCard: selectedSavedCard ?? newPaymentMethod,
                        isProcessing: $isProcessing,
                        onSuccess: onSuccess,
                        onError: onError
                    )
                }
            }
            .padding(24)
            .navigationTitle("Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddPaymentMethod) {
                AddPaymentMethodScreen { newCard in
                    newPaymentMethod = newCard
                    sharedPaymentService.addPaymentMethod(newCard)
                }
            }
        }
    }
}

struct PaymentSummaryView: View {
    let classItem: Class
    let participants: Int
    let selectedChildren: [Child]
    let totalPrice: Decimal
    let selectedSavedCard: UserPaymentMethod?
    let paymentMethod: PaymentMethod
    
    private var totalPriceText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "£"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(for: totalPrice as NSDecimalNumber) ?? "£--"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payment Summary")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(hex: "#BC6C5C"))
            
            VStack(spacing: 12) {
                SummaryRow(title: "Class", value: classItem.name)
                SummaryRow(title: "Provider", value: classItem.providerName ?? "Provider \(classItem.provider)")
                SummaryRow(title: "Participants", value: "\(participants)")
                
                // Show selected children if any
                if !selectedChildren.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selected Children")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#BC6C5C").opacity(0.8))
                        
                        ForEach(selectedChildren, id: \.id) { child in
                            Text("• \(child.name) (\(child.age) years old)")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "#BC6C5C").opacity(0.7))
                        }
                    }
                }
                
                SummaryRow(title: "Price per person", value: "£\(NSDecimalNumber(decimal: classItem.pricing.amount).intValue)")
                SummaryRow(title: "Service fee", value: "£1.99")
                
                Divider()
                
                // Payment Method
                if let selectedCard = selectedSavedCard {
                    SummaryRow(title: "Payment Method", value: "\(selectedCard.type.displayName) •••• \(selectedCard.lastFourDigits)")
                } else {
                    SummaryRow(title: "Payment Method", value: paymentMethod.displayName)
                }
                
                TotalSummaryRow(title: "Total", value: totalPriceText)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

struct SummaryRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color(hex: "#BC6C5C").opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#BC6C5C"))
        }
    }
}

struct TotalSummaryRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#BC6C5C"))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "#BC6C5C"))
        }
    }
}

struct PaymentButton: View {
    let paymentMethod: PaymentMethod
    let totalPrice: Decimal
    let classItem: Class
    let participants: Int
    let selectedChildren: [Child]
    let requirements: String
    let selectedSavedCard: UserPaymentMethod?
    @Binding var isProcessing: Bool
    let onSuccess: (EnhancedBooking) -> Void
    let onError: (Error) -> Void
    
    private var totalPriceText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "£"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(for: totalPrice as NSDecimalNumber) ?? "£--"
    }
    
    var body: some View {
        VStack(spacing: 16) {
            if paymentMethod == .applePay {
                ApplePayButton(
                    totalPrice: totalPrice,
                    classItem: classItem,
                    participants: participants,
                    selectedChildren: selectedChildren,
                    requirements: requirements,
                    selectedSavedCard: selectedSavedCard,
                    isProcessing: $isProcessing,
                    onSuccess: onSuccess,
                    onError: onError
                )
            } else {
                StandardPaymentButton(
                    paymentMethod: paymentMethod,
                    totalPrice: totalPrice,
                    classItem: classItem,
                    participants: participants,
                    selectedChildren: selectedChildren,
                    requirements: requirements,
                    selectedSavedCard: selectedSavedCard,
                    isProcessing: $isProcessing,
                    onSuccess: onSuccess,
                    onError: onError
                )
            }
        }
    }
}

struct ApplePayButton: View {
    let totalPrice: Decimal
    let classItem: Class
    let participants: Int
    let selectedChildren: [Child]
    let requirements: String
    let selectedSavedCard: UserPaymentMethod?
    @Binding var isProcessing: Bool
    let onSuccess: (EnhancedBooking) -> Void
    let onError: (Error) -> Void
    
    private var totalPriceText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "£"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(for: totalPrice as NSDecimalNumber) ?? "£--"
    }
    
    var body: some View {
        Button {
            processApplePay()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "applelogo")
                    .font(.system(size: 18))
                Text("Pay \(totalPriceText)")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.black)
            .cornerRadius(16)
        }
        .disabled(isProcessing)
    }
    
    private func processApplePay() {
        print("🎯 ApplePayButton: Starting Apple Pay processing...")
        isProcessing = true
        
        // Log payment method details
        if let selectedCard = selectedSavedCard {
            print("🎯 ApplePayButton: Using saved card: \(selectedCard.type.displayName) ending in \(selectedCard.lastFourDigits)")
        } else {
            print("🎯 ApplePayButton: Using Apple Pay")
        }
        
        // Simulate Apple Pay processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            print("🎯 ApplePayButton: Apple Pay processing completed!")
            isProcessing = false
            let booking = Booking(
                id: UUID(),
                classId: classItem.id,
                userId: UUID(), // TODO: Get from auth service
                status: .upcoming,
                bookingDate: Date().addingTimeInterval(86400), // Tomorrow
                numberOfParticipants: participants,
                selectedChildren: selectedChildren.isEmpty ? nil : selectedChildren,
                specialRequirements: requirements.isEmpty ? nil : requirements,
                attended: false
            )
            
            let enhancedBooking = EnhancedBooking(booking: booking, classInfo: classItem)
            
            // Call the success callback instead of handling notifications here
            onSuccess(enhancedBooking)
        }
    }
}

struct StandardPaymentButton: View {
    let paymentMethod: PaymentMethod
    let totalPrice: Decimal
    let classItem: Class
    let participants: Int
    let selectedChildren: [Child]
    let requirements: String
    let selectedSavedCard: UserPaymentMethod?
    @Binding var isProcessing: Bool
    let onSuccess: (EnhancedBooking) -> Void
    let onError: (Error) -> Void
    
    @State private var cancellables = Set<AnyCancellable>()
    
    private var totalPriceText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "£"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(for: totalPrice as NSDecimalNumber) ?? "£--"
    }
    
    var body: some View {
        Button {
            processPayment()
        } label: {
            HStack(spacing: 12) {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: paymentMethod.iconName)
                        .font(.system(size: 18))
                }
                
                Text(isProcessing ? "Processing..." : "Pay \(totalPriceText)")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
        }
        .disabled(isProcessing)
    }
    
    private func processPayment() {
        print("🎯 StandardPaymentButton: Starting payment processing...")
        isProcessing = true
        
        // Validate that at least one child is selected
        guard !selectedChildren.isEmpty else {
            print("❌ StandardPaymentButton: No children selected")
            isProcessing = false
            onError(NSError(domain: "BookingError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Please select at least one child to book this class."]))
            return
        }
        
        // Log payment method details
        if let selectedCard = selectedSavedCard {
            print("🎯 StandardPaymentButton: Using saved card: \(selectedCard.type.displayName) ending in \(selectedCard.lastFourDigits)")
        } else {
            print("🎯 StandardPaymentButton: Using \(paymentMethod.displayName)")
        }
        
        print("💳 StandardPaymentButton: Booking for \(selectedChildren.count) child(ren): \(selectedChildren.map { $0.name }.joined(separator: ", "))")
        
        // Step 1: Create booking via backend
        let sessionDate = Date().addingTimeInterval(86400) // Tomorrow
        let apiService = APIService.shared
        
        // Get session time from first time slot (format as HH:mm)
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.timeZone = TimeZone(identifier: "UTC")
        
        let sessionTimeString: String
        if let firstTimeSlot = classItem.schedule.timeSlots.first {
            sessionTimeString = timeFormatter.string(from: firstTimeSlot.startTime)
            print("💳 StandardPaymentButton: Extracted session time: \(sessionTimeString) from timeSlot: \(firstTimeSlot.startTime)")
        } else {
            // Default to 10:00 if no time found
            sessionTimeString = "10:00"
            print("⚠️ StandardPaymentButton: No time slot found, using default: \(sessionTimeString)")
        }
        
        apiService.createBooking(
            classId: classItem.id,
            children: selectedChildren,
            sessionDate: sessionDate,
            sessionTime: sessionTimeString,
            specialRequests: requirements.isEmpty ? nil : requirements
        )
        .flatMap { (bookingResponse, mongoObjectId) -> AnyPublisher<(PaymentIntentResponse, String), APIError> in
            // Use the MongoDB ObjectId extracted from raw JSON
            print("💳 StandardPaymentButton: Booking created with MongoDB ObjectId: \(mongoObjectId)")
            
            // Step 2: Create payment intent
            return apiService.createPaymentIntent(bookingId: mongoObjectId)
                .map { paymentIntentResponse -> (PaymentIntentResponse, String) in
                    print("💳 StandardPaymentButton: Payment intent created: \(paymentIntentResponse.paymentIntentId)")
                    return (paymentIntentResponse, mongoObjectId)
                }
                .eraseToAnyPublisher()
        }
        .flatMap { (paymentIntentResponse, bookingId) -> AnyPublisher<BookingResponse, APIError> in
            // Step 3: Confirm payment (this will process the payment and trigger webhooks)
            // For now, we're using the backend to confirm since Stripe SDK isn't integrated
            // In production, you'd use Stripe SDK here to collect card details
            return apiService.confirmPayment(
                paymentIntentId: paymentIntentResponse.paymentIntentId,
                bookingId: bookingId
            )
        }
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completion in
                isProcessing = false
                if case .failure(let error) = completion {
                    print("❌ StandardPaymentButton: Payment failed: \(error)")
                    onError(error)
                }
            },
            receiveValue: { bookingResponse in
                print("✅ StandardPaymentButton: Payment confirmed!")
                let booking = bookingResponse.data
                let enhancedBooking = EnhancedBooking(booking: booking, classInfo: classItem)
                onSuccess(enhancedBooking)
            }
        )
        .store(in: &cancellables)
    }
}

// MARK: - Child Selection Card

struct ChildSelectionCard: View {
    let availableChildren: [Child]
    @Binding var selectedChildren: [Child]
    let totalParticipants: Int
    
    // Calculate how many children can be selected (1 child for standard booking)
    private var maxChildrenAllowed: Int {
        1
    }
    
    // Check if we can select more children
    private var canSelectMore: Bool {
        selectedChildren.count < maxChildrenAllowed
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Select Children")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "#BC6C5C"))
            
            Text("Choose which children will attend this class")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#BC6C5C").opacity(0.7))
            
            VStack(spacing: 12) {
                ForEach(availableChildren, id: \.id) { child in
                    ChildSelectionRow(
                        child: child,
                        isSelected: selectedChildren.contains { $0.id == child.id },
                        isDisabled: false, // Always allow selection
                        onToggle: {
                            if selectedChildren.contains(where: { $0.id == child.id }) {
                                // Remove child if already selected
                                selectedChildren.removeAll { $0.id == child.id }
                            } else {
                                // Replace any existing selection with this child (only 1 child allowed)
                                selectedChildren.removeAll()
                                selectedChildren.append(child)
                            }
                        }
                    )
                }
            }
            
            // Show selection status
            HStack {
                Text("Selected: \(selectedChildren.count) of \(maxChildrenAllowed)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#BC6C5C"))
                
                Spacer()
                
                if selectedChildren.count == 1 {
                    Text("Child selected")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

struct ChildSelectionRow: View {
    let child: Child
    let isSelected: Bool
    let isDisabled: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: {
            onToggle()
        }) {
            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: "#BC6C5C") : Color(hex: "#BC6C5C").opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Text(String(child.name.prefix(1)))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isSelected ? .white : Color(hex: "#BC6C5C"))
                }
                
                // Child info
                VStack(alignment: .leading, spacing: 2) {
                    Text(child.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Text("\(child.age) years old")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#BC6C5C").opacity(0.7))
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                } else {
                    Circle()
                        .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: "#BC6C5C").opacity(0.1) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color(hex: "#BC6C5C").opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(false) // Never disable the button
        .onTapGesture {
            onToggle()
        }
    }
}

// MARK: - Apple Wallet Delegate

class AppleWalletDelegate: NSObject, PKAddPassesViewControllerDelegate {
    static let shared = AppleWalletDelegate()
    
    private override init() {
        super.init()
    }
    
    func addPassesViewControllerDidFinish(_ controller: PKAddPassesViewController) {
        controller.dismiss(animated: true) {
            print("Apple Wallet pass addition completed")
        }
    }
} 