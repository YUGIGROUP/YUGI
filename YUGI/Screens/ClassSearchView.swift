import SwiftUI
import Combine

struct ClassSearchView: View {
    @State private var location = ""
    @State private var selectedCategory: ClassCategory?
    @State private var selectedDays: Set<WeekDay> = []
    @State private var showResults = false
    
    // Add state for real classes
    @State private var classes: [Class] = []
    @State private var isLoading = false
    @State private var error: Error?
    @State private var cancellables = Set<AnyCancellable>()
    
    // AI and Booking states
    @State private var showingAIAnalysis = false
    @State private var selectedClassForAnalysis: Class?
    @State private var showingBookingSheet = false
    @State private var selectedClassForBooking: Class?
    @StateObject private var aiService = HybridAIService()

    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(hex: "#BC6C5C")
                    .ignoresSafeArea()
                
                if showResults {
                    searchResultsView
                } else {
                    searchFormView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if showResults {
                        Button("Back") {
                            showResults = false
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingBookingSheet) {
                if let class_ = selectedClassForBooking {
                    BookingView(classItem: class_, viewModel: ClassDiscoveryViewModel(bookingService: BookingService(calendarService: CalendarService())))
                        .onAppear {
                            print("🔍 ClassSearchView: Presenting BookingView for class: \(class_.name)")
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
                        print("❌ ClassSearchView: selectedClassForBooking is nil when presenting sheet!")
                        print("❌ ClassSearchView: showingBookingSheet is: \(showingBookingSheet)")
                    }
                }
            }
            .onChange(of: showingBookingSheet) { oldValue, newValue in
                print("📅 showingBookingSheet changed from \(oldValue) to: \(newValue)")
                if newValue {
                    print("📅 Booking sheet is being presented")
                    print("📅 selectedClassForBooking: \(selectedClassForBooking?.name ?? "nil")")
                } else {
                    print("📅 Booking sheet is being dismissed")
                }
            }
            .sheet(isPresented: $showingAIAnalysis) {
                if let class_ = selectedClassForAnalysis {
                    VStack {
                        Text("AI Venue Check for: \(class_.name)")
                            .font(.headline)
                            .foregroundColor(.black)
                            .padding()
                        
                        if let location = class_.location, 
                           !location.name.isEmpty || 
                           !location.address.street.isEmpty || 
                           (location.coordinates.latitude != 0 && location.coordinates.longitude != 0) {
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
                                    selectedClassForBooking = class_
                                    showingBookingSheet = true
                                }
                            )
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "location.slash")
                                    .font(.system(size: 48))
                                    .foregroundColor(.orange)
                                
                                Text("Location Information Missing")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                
                                Text("This class doesn't have location details yet. The provider needs to add venue information before AI analysis can be performed.")
                                    .font(.body)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                
                                Button("Close") {
                                    showingAIAnalysis = false
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color(hex: "#BC6C5C"))
                                .cornerRadius(8)
                            }
                            .padding()
                        }
                    }
                    .onAppear {
                        print("🧠 AI Analysis sheet is being presented")
                        print("🧠 selectedClassForAnalysis: \(selectedClassForAnalysis?.name ?? "nil")")
                    }
                } else {
                    Text("Error: No class selected for analysis")
                        .foregroundColor(.red)
                        .padding()
                        .onAppear {
                            print("🧠 AI Analysis sheet is being presented")
                            print("🧠 selectedClassForAnalysis: \(selectedClassForAnalysis?.name ?? "nil")")
                        }
                }
            }
            .onChange(of: showingAIAnalysis) { oldValue, newValue in
                print("🧠 showingAIAnalysis changed from \(oldValue) to: \(newValue)")
                if newValue {
                    print("🧠 AI Analysis sheet is being presented")
                    print("🧠 selectedClassForAnalysis: \(selectedClassForAnalysis?.name ?? "nil")")
                } else {
                    print("🧠 AI Analysis sheet is being dismissed")
                }
            }
        }
    }
    
    // MARK: - Search Form View
    private var searchFormView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Text("Find Your Perfect Class")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text("Discover amazing activities for your child")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Location Input
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("LOCATION")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .tracking(1.5)
                        
                        Text("Where are you looking?")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.leading, 4)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 20)
                        
                        ZStack(alignment: .leading) {
                            if location.isEmpty {
                                Text("Enter your location")
                                    .foregroundColor(.white.opacity(0.5))
                                    .font(.system(size: 16))
                            }
                            
                            TextField("", text: $location)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        
                        if !location.isEmpty {
                            Button(action: {
                                location = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.7))
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.15))
                    )
                }
                
                // Category Picker
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("CATEGORY")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .tracking(1.5)
                        
                        Text("What type of activity?")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.leading, 4)
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(ClassCategory.allCases, id: \.self) { category in
                                Button(action: {
                                    selectedCategory = selectedCategory == category ? nil : category
                                }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: category.iconName)
                                            .font(.system(size: 24))
                                            .foregroundColor(selectedCategory == category ? Color(hex: "#BC6C5C") : .white)
                                        
                                        Text(category.displayName)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(selectedCategory == category ? Color(hex: "#BC6C5C") : .white)
                                            .multilineTextAlignment(.center)
                                    }
                                    .frame(width: 80, height: 80)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedCategory == category ? Color.white : Color.white.opacity(0.15))
                                    )
                                }
                                .accessibilityLabel(category.displayName)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                
                // Days Picker
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("AVAILABLE DAYS")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .tracking(1.5)
                        
                        Text("Select all that apply")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.leading, 4)
                    }
                    
                    HStack(spacing: 12) {
                        ForEach([WeekDay.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday], id: \.self) { day in
                            Button(action: {
                                if selectedDays.contains(day) {
                                    selectedDays.remove(day)
                                } else {
                                    selectedDays.insert(day)
                                }
                            }) {
                                VStack(spacing: 4) {
                                    Text(day.shortName.prefix(1))
                                        .font(.system(size: 16, weight: .medium))
                                        .frame(width: 32, height: 32)
                                        .foregroundColor(selectedDays.contains(day) ? Color(hex: "#BC6C5C") : .white)
                                        .background(
                                            Circle()
                                                .fill(selectedDays.contains(day) ? Color.white : Color.white.opacity(0.15))
                                        )
                                }
                            }
                            .accessibilityLabel(day.shortName)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if selectedDays.isEmpty {
                        Text("Any day")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 4)
                    } else {
                        Text(selectedDays.map { $0.shortName }.joined(separator: ", "))
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, 4)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                
                // Search Button
                Button {
                    print("🔍 ClassSearchView: Search button tapped - fetching classes")
                    searchClasses()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18))
                        Text("DISCOVER CLASSES")
                            .tracking(1)
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "#BC6C5C"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    )
                }
                .disabled(location.isEmpty)
                .opacity(location.isEmpty ? 0.6 : 1)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
    
    // MARK: - Search Results View
    private var searchResultsView: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Text("Search Results")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                
                Text("Location: \(location)")
                    .foregroundColor(.white.opacity(0.8))
                
                if let category = selectedCategory {
                    Text("Category: \(category.displayName)")
                        .foregroundColor(.white.opacity(0.8))
                }
                
                if !selectedDays.isEmpty {
                    Text("Days: \(selectedDays.map { $0.shortName }.joined(separator: ", "))")
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Classes List
            if isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Loading classes...")
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if classes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("No classes found")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text("Try adjusting your search criteria")
                        .foregroundColor(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(classes) { classItem in
                            ClassSearchResultCard(
                                classItem: classItem,
                                onBook: { selectedClass in
                                    print("📅 Book button tapped for class: \(selectedClass.name)")
                                    print("📅 Setting selectedClassForBooking to: \(selectedClass.name)")
                                    selectedClassForBooking = selectedClass
                                    print("📅 selectedClassForBooking is now: \(selectedClassForBooking?.name ?? "nil")")
                                    print("📅 Setting showingBookingSheet to true")
                                    showingBookingSheet = true
                                    print("📅 showingBookingSheet is now: \(showingBookingSheet)")
                                },
                                onAnalyze: { selectedClass in
                                    print("🧠 AI Venue Check button tapped for class: \(selectedClass.name)")
                                    print("🧠 Setting selectedClassForAnalysis to: \(selectedClass.name)")
                                    selectedClassForAnalysis = selectedClass
                                    print("🧠 selectedClassForAnalysis is now: \(selectedClassForAnalysis?.name ?? "nil")")
                                    print("🧠 Setting showingAIAnalysis to true")
                                    showingAIAnalysis = true
                                    print("🧠 showingAIAnalysis is now: \(showingAIAnalysis)")
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
    }
    
    // MARK: - Search Function
    private func searchClasses() {
        isLoading = true
        error = nil
        
        APIService.shared.fetchClasses()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case let .failure(error) = completion {
                        self.error = error
                        print("❌ ClassSearchView: Failed to load classes: \(error)")
                    }
                },
                receiveValue: { response in
                    isLoading = false
                    error = nil
                    classes = response.data
                    showResults = true
                    print("✅ ClassSearchView: Loaded \(response.data.count) classes")
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Helper Functions
    private func updateClassWithAIData(_ classItem: Class, facilities: VenueFacilities) {
        print("🤖 Updating class \(classItem.name) with AI data:")
        print("   - Accessibility Notes: \(facilities.accessibilityNotes ?? "None")")
        print("   - Parking Info: \(facilities.parkingInfo ?? "None")")
        print("   - Baby Changing Facilities: \(facilities.babyChangingFacilities ?? "None")")
        
        // TODO: Implement AI data update functionality
        // This would typically update the class in the backend with the AI-analyzed facilities
        // For now, we just log the data that would be used to update the class
    }
}

// MARK: - Class Search Result Card
struct ClassSearchResultCard: View {
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
                    .foregroundColor(.yugiGray.opacity(0.7))
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
        }
    }
}


#Preview {
    ClassSearchView()
} 