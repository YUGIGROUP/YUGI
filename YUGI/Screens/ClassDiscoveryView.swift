import SwiftUI

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Shared Components

struct YUGICategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .yugiMocha : .white)
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
                .yugiMocha(.white)
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

    // MARK: - Smart Search (Foundation Models / Apple Intelligence)
    @State private var smartQuery = ""
    @State private var isSmartSearching = false
    @State private var aiFilters: ParsedSearchFilters? = nil
    @State private var aiSearchAvailable = false
    @State private var smartSearchTask: Task<Void, Never>? = nil
    @StateObject private var apiService = APIService.shared
    
    init(bookingService: BookingService) {
        self._viewModel = StateObject(wrappedValue: ClassDiscoveryViewModel(
            bookingService: bookingService
        ))
    }
    
    var body: some View {
        ZStack {
            .yugiMocha
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                classListSection
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(.yugiMocha, for: .navigationBar)
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
        .task { checkAIAvailability() }
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
                isActive: class_.isActive,
                doability: class_.doability, venueAccessibility: class_.venueAccessibility, intakeQuestions: nil, googlePlaceId: nil
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
                smartSearchBar
                ForEach(Array(displayedClasses.enumerated()), id: \.element.id) { index, classItem in
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
        .background(.yugiMocha)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

    // MARK: - Smart Search helpers

    private var displayedClasses: [Class] {
        guard let filters = aiFilters else { return viewModel.filteredClasses }
        return viewModel.filteredClasses.filter { c in
            if let cat = filters.category?.lowercased(), !cat.isEmpty {
                let catMatch = c.category.rawValue.lowercased().contains(cat)
                    || c.name.lowercased().contains(cat)
                    || c.description.lowercased().contains(cat)
                if !catMatch { return false }
            }
            if let loc = filters.locationHint?.lowercased(), !loc.isEmpty {
                let addr = ((c.location?.address.city ?? "") + " " + (c.location?.name ?? "")).lowercased()
                if !addr.contains(loc) { return false }
            }
            return true
        }
    }

    @ViewBuilder
    private var smartSearchBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                YUGISearchBar(text: $smartQuery)
                    .onChange(of: smartQuery) { _, q in scheduleSmartSearch(q) }

                if aiSearchAvailable {
                    VStack(spacing: 2) {
                        if isSmartSearching {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.55)
                                .tint(.white)
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        Text("AI")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .frame(width: 32)
                }
            }

            if let filters = aiFilters {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.8))
                    Text(aiFilterSummary(filters))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    Button("Clear") { aiFilters = nil; smartQuery = "" }
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func checkAIAvailability() {
        if #available(iOS 26, macOS 26, *) {
            #if canImport(FoundationModels)
            let av = SystemLanguageModel.default.availability
            if case .available = av { aiSearchAvailable = true }
            #endif
        }
    }

    private func scheduleSmartSearch(_ query: String) {
        smartSearchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            aiFilters = nil
            return
        }
        smartSearchTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { isSmartSearching = true }
            let filters = await SmartSearchServiceWrapper.shared.parseQuery(query)
            await MainActor.run {
                isSmartSearching = false
                aiFilters = filters
                if filters != nil {
                    EventTracker.shared.trackSmartSearchUsed(query: query)
                }
            }
        }
    }

    private func aiFilterSummary(_ f: ParsedSearchFilters) -> String {
        var parts: [String] = []
        if let c = f.category { parts.append(c) }
        if let l = f.locationHint { parts.append("near \(l)") }
        if f.needsParking { parts.append("parking") }
        if f.needsBabyChanging { parts.append("baby changing") }
        if f.needsStepFreeAccess { parts.append("step-free") }
        return parts.isEmpty ? "Smart filters active" : parts.joined(separator: " · ")
    }


// MARK: - Doability Components

struct DoabilityBadge: View {
    let score: Int
    
    private var label: String {
        switch score {
        case 80...100: return "Easy outing"
        case 60..<80: return "Doable"
        default: return "Plan ahead"
        }
    }
    
    private var backgroundColor: Color {
        switch score {
        case 80...100: return Color.green
        case 60..<80: return Color.orange
        default: return Color.red
        }
    }
    
    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .clipShape(Capsule())
    }
}

struct DoabilityReasonsView: View {
    let doability: DoabilityInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Score header
            HStack(spacing: 8) {
                Text("Doability Score")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                DoabilityBadge(score: doability.score)
            }
            
            // Reasons with checkmarks
            if !doability.reasons.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Why this works")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    ForEach(doability.reasons, id: \.self) { reason in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                            Text(reason)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            
            // Friction warnings with icons
            if !doability.frictionWarnings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Things to consider")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    ForEach(doability.frictionWarnings, id: \.text) { warning in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: iconForSeverity(warning.severity))
                                .font(.system(size: 14))
                                .foregroundColor(colorForSeverity(warning.severity))
                            Text(warning.text)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func iconForSeverity(_ severity: String) -> String {
        switch severity.lowercased() {
        case "high": return "exclamationmark.triangle.fill"
        case "medium": return "exclamationmark.circle.fill"
        default: return "info.circle.fill"
        }
    }
    
    private func colorForSeverity(_ severity: String) -> Color {
        switch severity.lowercased() {
        case "high": return .red
        case "medium": return .orange
        default: return .blue
        }
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
    @State private var enrichment: VenueEnrichmentResponse? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            cardHeader
            cardContent
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .onAppear {
            guard enrichment == nil, let loc = classItem.location else { return }
            let slug = "\(loc.name)-\(loc.address.city)"
                .lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .joined(separator: "-")
            let placeId = classItem.googlePlaceId ?? "yugi-\(slug)"
            VenueEnrichmentService.shared.fetchEnrichment(
                placeId: placeId,
                venueName: loc.name
            ) { self.enrichment = $0 }
        }
        .sheet(isPresented: $showingProviderProfile) {
            ProviderProfilePopup(providerId: classItem.provider)
        }
    }
    
    private var cardHeader: some View {
        ZStack(alignment: .topTrailing) {
            if let doability = classItem.doability {
                DoabilityBadge(score: doability.score)
                    .padding(12)
                    .zIndex(1)
            }
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.yugiMocha.opacity(0.8), .yugiMocha.opacity(0.6)],
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
            ClassCardDetails(classItem: classItem, enrichment: enrichment)
            actionButtonsSection
            // Enrichment badges — appear async when data arrives, never block card render
            if let badges = enrichment?.discoveryBadges, !badges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(badges, id: \.self) { badge in
                            Text(badge)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.yugiMocha)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(.yugiMocha.opacity(0.1))
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.yugiMocha.opacity(0.25), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
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
                    .foregroundColor(.yugiMocha)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.yugiMocha.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("£\(NSDecimalNumber(decimal: classItem.pricing.amount).intValue)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.yugiMocha)
                
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
                    .foregroundColor(.yugiMocha)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.yugiMocha.opacity(0.1))
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
                    .foregroundColor(.yugiMocha)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.yugiMocha.opacity(0.1))
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
                .background(.yugiMocha)
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
    var enrichment: VenueEnrichmentResponse? = nil
    @State private var isDescriptionExpanded = false
    
    private var parkingText: String {
        enrichment?.parkingDescription ?? classItem.location?.parkingInfo ?? "No parking info"
    }
    
    private var babyChangingText: String {
        if let bc = enrichment?.enrichedData.babyChanging {
            if bc.available == true {
                let loc = bc.location.map { " (\($0))" } ?? ""
                return "Baby changing available\(loc)"
            } else if bc.available == false {
                return "No baby changing confirmed"
            }
        }
        return classItem.location?.babyChangingFacilities ?? "No changing facilities"
    }
    
    private var weatherIcon: String {
        let forecast = classItem.venueAccessibility?.weatherForecast?.lowercased() ?? ""
        if forecast.contains("rain") || forecast.contains("drizzle") || forecast.contains("shower") {
            return "cloud.rain.fill"
        } else if forecast.contains("snow") {
            return "cloud.snow.fill"
        } else if forecast.contains("cloud") || forecast.contains("overcast") {
            return "cloud.fill"
        } else if forecast.contains("clear") || forecast.contains("sunny") {
            return "sun.max.fill"
        }
        return "cloud.fill"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Doability section (for class detail)
            if let doability = classItem.doability {
                DoabilityReasonsView(doability: doability)
            }
            
            // Age Range Badge
            if !classItem.ageRange.isEmpty && classItem.ageRange != "All ages" {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 12))
                        Text(classItem.ageRange)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.yugiMocha)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.yugiMocha.opacity(0.1))
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
                    
                    // Show "Read more" if description is longer than ~60 characters (likely to span 2+ lines)
                    // or if it contains newlines
                    let shouldShowExpandButton = classItem.description.count > 60 || 
                                                 classItem.description.contains("\n") ||
                                                 classItem.description.contains("\r")
                    
                    if shouldShowExpandButton {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isDescriptionExpanded.toggle()
                            }
                        }) {
                            Text(isDescriptionExpanded ? "Read less" : "Read more")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.yugiMocha)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 4)
            }
            
            // Divider
            Divider()
                .background(Color.yugiGray.opacity(0.2))
            
            // Weather forecast chip (if available)
            if let forecast = classItem.venueAccessibility?.weatherForecast {
                HStack(spacing: 6) {
                    Image(systemName: weatherIcon)
                        .font(.system(size: 12))
                        .foregroundColor(forecast.lowercased().contains("rain") ? Color(hex: "#5B8DB8") : Color(hex: "#E8A045"))
                    Text(forecast)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.yugiGray)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "#F5F5F0"))
                .cornerRadius(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Class Details
            VStack(alignment: .leading, spacing: 12) {
                ClassDetailRow(icon: "calendar", text: formatSchedule(classItem.schedule))
                ClassDetailRow(icon: "mappin.circle", text: classItem.location?.address.formatted ?? "Location TBD")
                ClassDetailRow(icon: "car.fill", text: parkingText)
                ClassDetailRow(icon: "person.2.fill", text: babyChangingText)
                if enrichment?.hasData == true {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 10)).foregroundColor(.yugiMocha.opacity(0.7))
                        Text(enrichment!.sourceLabel)
                            .font(.system(size: 11)).foregroundColor(.yugiMocha.opacity(0.7))
                    }
                }
                
                // Nearest transit stations
                if let stations = classItem.venueAccessibility?.nearestStations, !stations.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(stations, id: \.name) { station in
                            HStack(spacing: 6) {
                                Image(systemName: station.type == "tube" ? "tram.fill" : station.type == "rail" ? "train.side.front.car" : "bus.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.yugiMocha)
                                    .frame(width: 16)
                                if let dist = station.distance {
                                    Text("\(station.name) (\(dist)m)")
                                } else {
                                    Text(station.name)
                                }
                            }
                            .font(.system(size: 13))
                            .foregroundColor(.yugiGray)
                        }
                    }
                }
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
                gradient: Gradient(colors: [.yugiMocha, .yugiMocha.opacity(0.8)]),
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
                .foregroundColor(.yugiMocha)
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
                .foregroundColor(.yugiMocha)
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

