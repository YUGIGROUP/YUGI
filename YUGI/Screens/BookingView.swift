import SwiftUI
import PassKit

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
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#BC6C5C")
                    .ignoresSafeArea()
                
                VStack {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Class Details Card
                            ClassDetailsCard(classItem: classItem)
                            
                            // Booking Options Card
                            BookingOptionsCard(
                                participants: $baseParticipants,
                                requirements: $requirements,
                                basePrice: basePrice,
                                serviceFee: serviceFee,
                                totalPrice: totalPrice
                            )
                            
                            // Child Selection Card (only show if user has children)
                            if !availableChildren.isEmpty {
                                ChildSelectionCard(
                                    availableChildren: availableChildren,
                                    selectedChildren: $selectedChildren,
                                    totalParticipants: totalParticipants
                                )
                            }
                            
                            // Payment Methods Card
                            PaymentMethodsCard(
                                selectedMethod: $selectedPaymentMethod,
                                selectedSavedCard: $selectedSavedCard
                            )
                            
                            // Total and Book Button
                            TotalAndBookSection(
                                totalPrice: totalPrice,
                                isProcessing: isProcessing,
                                onBook: {
                                    print("🎯 BookingView: Proceed to Payment button tapped!")
                                    showingPaymentSheet = true
                                }
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                    }
                }
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
            .sheet(isPresented: $showingPaymentSheet) {
                PaymentSheet(
                    classItem: classItem,
                    participants: totalParticipants,
                    selectedChildren: selectedChildren,
                    requirements: requirements,
                    totalPrice: totalPrice,
                    paymentMethod: selectedPaymentMethod,
                    selectedSavedCard: selectedSavedCard,
                    onSuccess: { enhancedBooking in
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
                        let providerId = enhancedBooking.classInfo.provider.id.uuidString
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
                        
                        // Send payment notification to provider
                        ProviderNotificationService.shared.sendPaymentNotification(
                            providerId: providerId,
                            className: enhancedBooking.className,
                            amount: enhancedBooking.price,
                            parentName: parentName,
                            bookingId: bookingId
                        )
                        
                        // Add to Apple Wallet
                        addToAppleWallet(for: enhancedBooking.booking)
                        
                        // Store the enhanced booking for later notification
                        // We'll send the notification after the dashboard is loaded
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            NotificationCenter.default.post(name: .bookingCreated, object: enhancedBooking)
                            print("🎯 BookingView: Notification posted successfully!")
                        }
                        
                        showingConfirmation = true
                        showingPaymentSheet = false
                    },
                    onError: { error in
                        self.error = error
                        showingPaymentSheet = false
                    }
                )
            }
            .alert("Payment Error", isPresented: .constant(error != nil)) {
                Button("OK") {
                    error = nil
                }
            } message: {
                if let error = error as? BookingService.BookingError {
                    Text(error.message)
                } else {
                    Text("An unexpected error occurred")
                }
            }
            .alert("Booking Confirmed!", isPresented: $showingConfirmation) {
                Button(isProvider ? "View Dashboard" : "View My Bookings") {
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
                    
                    // Debug: Test the enum comparison
                    if let userType = currentUserType {
                        print("🎯 BookingView: DEBUG - User type raw value: '\(userType.rawValue)'")
                        print("🎯 BookingView: DEBUG - Comparing '\(userType.rawValue)' == 'provider': \(userType.rawValue == "provider")")
                        print("🎯 BookingView: DEBUG - Comparing userType == .provider: \(userType == .provider)")
                        print("🎯 BookingView: DEBUG - UserType.provider.rawValue: '\(UserType.provider.rawValue)'")
                    }
                    
                    // FIX: Add a small delay to allow user data to be updated, then make navigation decision
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Re-check the user type after the delay
                        let finalUserType = apiService.currentUser?.userType
                        let finalIsProvider = finalUserType == .provider
                        
                        print("🎯 BookingView: FINAL CHECK - finalUserType = \(finalUserType?.rawValue ?? "unknown")")
                        print("🎯 BookingView: FINAL CHECK - finalIsProvider = \(finalIsProvider)")
                        
                        if finalIsProvider {
                            print("🎯 BookingView: FINAL DECISION - Navigating to provider dashboard...")
                            shouldNavigateToProviderDashboard = true
                            print("🎯 BookingView: FINAL DECISION - shouldNavigateToProviderDashboard set to: \(shouldNavigateToProviderDashboard)")
                        } else {
                            print("🎯 BookingView: FINAL DECISION - Navigating to parent dashboard...")
                            shouldNavigateToParentDashboard = true
                            print("🎯 BookingView: FINAL DECISION - shouldNavigateToParentDashboard set to: \(shouldNavigateToParentDashboard)")
                        }
                    }
                }
            } message: {
                Text("Your booking has been confirmed and added to your Apple Wallet! We'll send you a confirmation email shortly.")
            }
            .fullScreenCover(isPresented: $shouldNavigateToParentDashboard) {
                let _ = print("🎯 BookingView: ParentDashboardScreen fullScreenCover triggered")
                let _ = print("🎯 BookingView: shouldNavigateToParentDashboard = \(shouldNavigateToParentDashboard)")
                let _ = print("🎯 BookingView: shouldNavigateToProviderDashboard = \(shouldNavigateToProviderDashboard)")
                ParentDashboardScreen(parentName: apiService.currentUser?.fullName ?? "Parent", initialTab: 0)
            }
            .fullScreenCover(isPresented: $shouldNavigateToProviderDashboard) {
                let _ = print("🎯 BookingView: ProviderDashboardScreen fullScreenCover triggered")
                let _ = print("🎯 BookingView: shouldNavigateToParentDashboard = \(shouldNavigateToParentDashboard)")
                let _ = print("🎯 BookingView: shouldNavigateToProviderDashboard = \(shouldNavigateToProviderDashboard)")
                ProviderDashboardScreen(businessName: apiService.currentUser?.businessName ?? "Provider")
            }
            .onAppear {
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
                print("🎯 BookingView: isProviderUser after setting: \(isProviderUser)")
            }
            .onReceive(apiService.$currentUser) { user in
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
                    
                    Text(classItem.provider.name)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "#BC6C5C").opacity(0.7))
                }
                
                Spacer()
            }
            
            // Details
            VStack(alignment: .leading, spacing: 12) {
                BookingDetailRow(icon: "calendar", text: formatSchedule(classItem.schedule))
                BookingDetailRow(icon: "mappin.circle", text: classItem.location.address.formatted)
                BookingDetailRow(icon: "car.fill", text: classItem.location.parkingInfo ?? "No parking info")
                BookingDetailRow(icon: "person.2.fill", text: classItem.location.babyChangingFacilities ?? "No changing facilities")
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
    
    private func formatSchedule(_ schedule: Schedule) -> String {
        let days = schedule.recurringDays.map { $0.shortName }.joined(separator: ", ")
        guard let timeSlot = schedule.timeSlots.first else {
            return days.isEmpty ? "" : days
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(days) at \(formatter.string(from: timeSlot.startTime))"
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
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#BC6C5C"))
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Color(hex: "#BC6C5C").opacity(0.8))
                .lineLimit(2)
            
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Payment Summary
                PaymentSummaryView(
                    classItem: classItem,
                    participants: participants,
                    selectedChildren: selectedChildren,
                    totalPrice: totalPrice,
                    selectedSavedCard: selectedSavedCard,
                    paymentMethod: paymentMethod
                )
                
                Spacer()
                
                // Payment Button
                PaymentButton(
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
                SummaryRow(title: "Provider", value: classItem.provider.name)
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
        
        // Log payment method details
        if let selectedCard = selectedSavedCard {
            print("🎯 StandardPaymentButton: Using saved card: \(selectedCard.type.displayName) ending in \(selectedCard.lastFourDigits)")
        } else {
            print("🎯 StandardPaymentButton: Using \(paymentMethod.displayName)")
        }
        
        // Simulate payment processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            print("🎯 StandardPaymentButton: Payment processing completed!")
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