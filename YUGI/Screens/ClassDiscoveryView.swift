import SwiftUI

// MARK: - Shared Components

struct YUGICategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? Color(hex: "#BC6C5C") : .white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    isSelected ? Color.white : Color.white.opacity(0.15)
                )
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .shadow(color: isSelected ? Color.black.opacity(0.1) : Color.clear, radius: 4, x: 0, y: 2)
        }
    }
}

struct YUGISearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.8))
                .font(.system(size: 16, weight: .medium))
            TextField("Search classes...", text: $text)
                .textFieldStyle(.plain)
                .autocapitalization(.none)
                .foregroundColor(.white)
                .accentColor(.white)
                .tint(.white)
                .font(.system(size: 16))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.15))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Main View

struct ClassDiscoveryView: View {
    @StateObject private var viewModel: ClassDiscoveryViewModel
    @StateObject private var aiService = HybridAIService()
    @State private var selectedClassForBooking: Class?
    @State private var showingBookingSheet = false
    @State private var showingAIAnalysis = false
    @State private var selectedClassForAnalysis: Class?
    @State private var animateCards = false
    @State private var shouldNavigateToProviderDashboard = false
    @State private var shouldNavigateToParentDashboard = false
    @StateObject private var apiService = APIService.shared
    
    init(bookingService: BookingService) {
        self._viewModel = StateObject(wrappedValue: ClassDiscoveryViewModel(
            bookingService: bookingService
        ))
    }
    
    var body: some View {
        ZStack {
            Color(hex: "#BC6C5C")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                classListSection
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color(hex: "#BC6C5C"), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showingBookingSheet) {
            if let class_ = selectedClassForBooking {
                BookingView(classItem: class_, viewModel: viewModel)
                    .onAppear {
                        print("🔍 ClassDiscoveryView: Presenting BookingView for class: \(class_.name)")
                    }
            } else {
                VStack {
                    Text("Error: No class selected")
                        .foregroundColor(.red)
                        .font(.headline)
                    Text("Please try again")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    Button("Dismiss") {
                        showingBookingSheet = false
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding()
                .onAppear {
                    print("❌ ClassDiscoveryView: selectedClassForBooking is nil when presenting sheet!")
                }
            }
        }
        .sheet(isPresented: $showingAIAnalysis) {
            if let class_ = selectedClassForAnalysis {
                VStack {
                    Text("AI Venue Check for: \(class_.name)")
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding()
                    
                    if let location = class_.location {
                        AIAnalysisView(
                            aiService: aiService, 
                            location: location,
                            onUpdateLocation: { facilities in
                                // Update the class with AI data
                                updateClassWithAIData(class_, facilities: facilities)
                            },
                            onBookClass: {
                                // Dismiss AI Venue Check and show booking sheet
                                showingAIAnalysis = false
                                
                                // FIX: Ensure user is authenticated before showing booking sheet
                                if !apiService.isAuthenticated {
                                    print("🔐 ClassDiscoveryView: User not authenticated (AI flow), forcing authentication...")
                                    apiService.forceAuthenticateForTesting(userType: apiService.currentUser?.userType ?? .parent)
                                    
                                    // Wait for authentication to complete before showing booking sheet
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        print("🔐 ClassDiscoveryView: Authentication complete (AI flow), showing booking sheet...")
                                        selectedClassForBooking = class_
                                        showingBookingSheet = true
                                    }
                                } else {
                                    print("🔐 ClassDiscoveryView: User already authenticated (AI flow), showing booking sheet...")
                                    selectedClassForBooking = class_
                                    showingBookingSheet = true
                                }
                            }
                        )
                    } else {
                        Text("Location information not available for AI analysis")
                            .foregroundColor(.orange)
                            .padding()
                    }
                }
            } else {
                Text("Error: No class selected for analysis")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .onAppear {
                print("ClassDiscoveryView appeared")
                viewModel.startLocationUpdates()
                
                // Delay the animation to ensure classes are loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("Triggering animations in ClassDiscoveryView...")
                    withAnimation {
                        animateCards = true
                    }
                    print("Animations triggered, animateCards = \(animateCards)")
                }
            }
        .onChange(of: showingAIAnalysis) { oldValue, newValue in
            print("showingAIAnalysis changed from \(oldValue) to: \(newValue)")
            if newValue {
                print("AI Venue Check sheet is being presented")
                if let class_ = selectedClassForAnalysis {
                    print("Presenting AI Venue Check for class: \(class_.name)")
                } else {
                    print("ERROR: selectedClassForAnalysis is nil!")
                }
            }
        }
        .onChange(of: showingBookingSheet) { oldValue, newValue in
            print("showingBookingSheet changed from \(oldValue) to: \(newValue)")
            if newValue {
                print("Booking sheet is being presented")
                if let class_ = selectedClassForBooking {
                    print("Presenting booking for class: \(class_.name)")
                } else {
                    print("ERROR: selectedClassForBooking is nil!")
                }
            }
        }
    }
    
    private func updateClassWithAIData(_ class_: Class, facilities: VenueFacilities) {
        // Find and update the class in the view model
        if let index = viewModel.classes.firstIndex(where: { $0.id == class_.id }) {
            // Create updated location with AI data
            let updatedLocation = Location(
                id: class_.location?.id ?? "unknown-location",
                name: class_.location?.name ?? "Location TBD",
                address: class_.location?.address ?? Address(street: "TBD", city: "TBD", state: "TBD", postalCode: "TBD", country: "TBD"),
                coordinates: class_.location?.coordinates ?? Location.Coordinates(latitude: 51.5074, longitude: -0.1278),
                accessibilityNotes: facilities.accessibilityNotes,
                parkingInfo: facilities.parkingInfo,
                babyChangingFacilities: facilities.babyChangingFacilities
            )
            
            // Create updated class with new location
            let updatedClass = Class(
                id: class_.id,
                name: class_.name,
                description: class_.description,
                category: class_.category,
                provider: class_.provider, providerName: class_.providerName,
                location: updatedLocation,
                schedule: class_.schedule,
                pricing: class_.pricing,
                maxCapacity: class_.maxCapacity,
                currentEnrollment: class_.currentEnrollment,
                averageRating: class_.averageRating,
                ageRange: class_.ageRange,
                isFavorite: class_.isFavorite,
                isActive: class_.isActive
            )
            
            // Update the class in the view model using the index
            viewModel.classes[index] = updatedClass
            
            print("Updated class \(class_.name) with AI data")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Classes Near You")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(.white)
            Text("Discover amazing activities for your little one")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.9))
            
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                Text("Discover amazing classes for your child")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.15))
            .cornerRadius(20)
        }
        .padding(.top, 20)
        .padding(.bottom, 24)
        .offset(y: animateCards ? 0 : -30)
        .opacity(animateCards ? 1 : 0)
        .animation(.easeOut(duration: 0.6).delay(0.1), value: animateCards)
    }
    
    private var classListSection: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(Array(viewModel.filteredClasses.enumerated()), id: \.element.id) { index, classItem in
                    ClassCard(
                        classItem: classItem,
                        onBook: { selectedClass in
                            print("Book Now button pressed for class: \(selectedClass.name)")
                            
                            // Set the selected class first
                            selectedClassForBooking = selectedClass
                            print("🔍 ClassDiscoveryView: selectedClassForBooking set to: \(selectedClass.name)")
                            
                            // FIX: Ensure user is authenticated before showing booking sheet
                            if !apiService.isAuthenticated {
                                print("🔐 ClassDiscoveryView: User not authenticated, forcing authentication...")
                                apiService.forceAuthenticateForTesting(userType: apiService.currentUser?.userType ?? .parent)
                                
                                // Wait for authentication to complete before showing booking sheet
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    print("🔐 ClassDiscoveryView: Authentication complete, showing booking sheet...")
                                    print("🔍 ClassDiscoveryView: selectedClassForBooking before showing sheet: \(selectedClassForBooking?.name ?? "nil")")
                                    showingBookingSheet = true
                                }
                            } else {
                                print("🔐 ClassDiscoveryView: User already authenticated, showing booking sheet...")
                                print("🔍 ClassDiscoveryView: selectedClassForBooking before showing sheet: \(selectedClassForBooking?.name ?? "nil")")
                                showingBookingSheet = true
                            }
                        },
                        onAnalyze: { selectedClass in
                            print("AI Venue Check button tapped for class: \(selectedClass.name)")
                            selectedClassForAnalysis = selectedClass
                            print("selectedClassForAnalysis set to: \(selectedClassForAnalysis?.name ?? "nil")")
                            showingAIAnalysis = true
                            print("showingAIAnalysis set to: \(showingAIAnalysis)")
                        }
                    )
                    .offset(y: animateCards ? 0 : -100)
                    .opacity(animateCards ? 1 : 0)
                    .animation(.easeOut(duration: 0.8).delay(Double(index) * 0.2), value: animateCards)
                    .onAppear {
                        print("ClassCard \(index) appeared, animateCards = \(animateCards)")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(hex: "#BC6C5C"))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

// MARK: - Supporting Views

struct ClassList: View {
    let classes: [Class]
    let onBook: (Class) -> Void
    let onAnalyze: (Class) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ForEach(classes) { classItem in
                    ClassCard(
                        classItem: classItem,
                        onBook: onBook,
                        onAnalyze: onAnalyze
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }
}

struct ClassCard: View {
    let classItem: Class
    let onBook: (Class) -> Void
    let onAnalyze: (Class) -> Void
    @State private var showingProviderProfile = false
    
    var body: some View {
        VStack(spacing: 0) {
            cardHeader
            cardContent
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .sheet(isPresented: $showingProviderProfile) {
            ProviderProfilePopup(providerId: classItem.provider)
        }
    }
    
    private var cardHeader: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#BC6C5C").opacity(0.8), Color(hex: "#BC6C5C").opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 120)
                .overlay(
                    VStack {
                        Image(systemName: "figure.and.child.holdinghands")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.9))
                        Text(classItem.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                )
            
        }
    }
    
    private var cardContent: some View {
        VStack(spacing: 16) {
            providerAndRatingSection
            ClassCardDetails(classItem: classItem)
            actionButtonsSection
        }
        .padding(20)
    }
    
    private var providerAndRatingSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(classItem.providerName ?? "Provider \(classItem.provider)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.yugiGray)
                
                Button(action: {
                    showingProviderProfile = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 12))
                        Text("View Profile")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#BC6C5C"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#BC6C5C").opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("£\(NSDecimalNumber(decimal: classItem.pricing.amount).intValue)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "#BC6C5C"))
                
                Text("per session")
                    .font(.system(size: 12))
                    .foregroundColor(.yugiGray.opacity(0.8))
            }
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Maps Row
            HStack(spacing: 12) {
                Button(action: {
                    openInAppleMaps()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "map")
                            .font(.system(size: 14))
                        Text("View in Maps")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#BC6C5C"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#BC6C5C").opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            
            // AI Venue Check Row
            HStack(spacing: 12) {
                Button(action: {
                    onAnalyze(classItem)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 14))
                        Text("AI Venue Check")
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundColor(Color(hex: "#BC6C5C"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#BC6C5C").opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            
            // Book Now Button (Full Width)
            Button(action: {
                onBook(classItem)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 14))
                    Text("Book Now")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(hex: "#BC6C5C"))
                .cornerRadius(10)
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func openInAppleMaps() {
        let coordinates = classItem.location?.coordinates ?? Location.Coordinates(latitude: 51.5074, longitude: -0.1278)
        let venueName = classItem.location?.name ?? "Location TBD"
        
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


struct ClassCardDetails: View {
    let classItem: Class
    @State private var isDescriptionExpanded = false
    
    private var parkingText: String {
        classItem.location?.parkingInfo ?? "No parking info"
    }
    
    private var babyChangingText: String {
        classItem.location?.babyChangingFacilities ?? "No changing facilities"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Age Range Badge
            if !classItem.ageRange.isEmpty && classItem.ageRange != "All ages" {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12))
                        Text(classItem.ageRange)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#BC6C5C"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#BC6C5C").opacity(0.1))
                    .cornerRadius(8)
                    
                    Spacer()
                }
            }
            
            // Description with expand/collapse
            if !classItem.description.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(classItem.description)
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray.opacity(0.8))
                        .lineLimit(isDescriptionExpanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if classItem.description.count > 100 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isDescriptionExpanded.toggle()
                            }
                        }) {
                            Text(isDescriptionExpanded ? "Read less" : "Read more")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 4)
            }
            
            // Divider
            Divider()
                .background(Color.yugiGray.opacity(0.2))
            
            // Class Details
            VStack(alignment: .leading, spacing: 12) {
                ClassDetailRow(icon: "calendar", text: formatSchedule(classItem.schedule))
                ClassDetailRow(icon: "mappin.circle", text: classItem.location?.address.formatted ?? "Location TBD")
                ClassDetailRow(icon: "car.fill", text: parkingText)
                ClassDetailRow(icon: "baby", text: babyChangingText)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.02))
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

struct ClassCardButton: View {
    let classItem: Class
    let onBook: (Class) -> Void
    
    private var buttonBackground: LinearGradient {
        if classItem.isAvailable {
            return LinearGradient(
                gradient: Gradient(colors: [Color(hex: "#BC6C5C"), Color(hex: "#BC6C5C").opacity(0.8)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [Color.gray.opacity(0.6), Color.gray.opacity(0.4)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    private var buttonText: String {
        classItem.isAvailable ? "Book Now" : "Class Full"
    }
    
    var body: some View {
        Button {
            onBook(classItem)
        } label: {
            HStack {
                Text(buttonText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                if classItem.isAvailable {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(buttonBackground)
            .cornerRadius(0)
        }
        .disabled(!classItem.isAvailable)
    }
}

struct ClassDetailRow: View {
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
                .foregroundColor(.yugiGray.opacity(0.8))
                .lineLimit(isAddress ? nil : 2) // No limit for addresses, 2 lines for others
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(.white.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No classes found")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Try adjusting your search or filters")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

struct LocationErrorView: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.white.opacity(0.7))
            
            VStack(spacing: 8) {
                Text("Location Required")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            Button("Enable Location", action: retry)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "#BC6C5C"))
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(Color.white)
                .cornerRadius(25)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.1), radius: 16, x: 0, y: 8)
        .padding(24)
    }
}

