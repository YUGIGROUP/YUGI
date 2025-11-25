import SwiftUI

// Simple provider-specific view model
@MainActor
class ProviderClassDiscoveryViewModel: ObservableObject {
    @Published var classes: [Class] = []
    @Published var isLoading = false
    
    func loadClasses() async {
        isLoading = true
        defer { isLoading = false }
        
        // Simulated delay for demo purposes
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Mock data - in a real app, this would fetch from an API
        classes = [
            Class(
                id: "mock-class-1",
                name: "Baby Sensory Adventure",
                description: "A journey of discovery through light, sound, and touch.",
                category: .baby,
                provider: "mock-provider-1", providerName: "Provider 1",
                location: Location(
                    id: "mock-location-1",
                    name: "Sensory World Studio",
                    address: Address(
                        street: "123 High Street",
                        city: "Richmond",
                        state: "London",
                        postalCode: "TW9 1AA",
                        country: "UK"
                    ),
                    coordinates: Location.Coordinates(latitude: 51.4613, longitude: -0.3037),
                    accessibilityNotes: "Ground floor access, changing facilities available",
                    parkingInfo: "Free parking available on-site",
                    babyChangingFacilities: "Dedicated changing room with changing table"
                ),
                schedule: Schedule(
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(7776000),
                    recurringDays: ["monday", "wednesday", "friday"],
                    timeSlots: [
                        Schedule.TimeSlot(
                            startTime: Calendar.current.date(from: DateComponents(hour: 10))!,
                            duration: 3600
                        )
                    ],
                    totalSessions: 36
                ),
                pricing: Pricing(
                    amount: Decimal(15.0),
                    currency: "GBP",
                    type: .perSession,
                    description: "Pay as you go"
                ),
                maxCapacity: 12,
                currentEnrollment: 8,
                averageRating: 4.8,
                ageRange: "0-12 months",
                isFavorite: false,
                isActive: true
            ),
            Class(
                id: "mock-class-2",
                name: "Toddler Music & Movement",
                description: "Fun and engaging music sessions for toddlers to develop rhythm and coordination.",
                category: .toddler,
                provider: "mock-provider-2", providerName: "Provider 2",
                location: Location(
                    id: "mock-location-2",
                    name: "Music Studio",
                    address: Address(
                        street: "456 Church Road",
                        city: "Richmond",
                        state: "London",
                        postalCode: "TW10 5LR",
                        country: "UK"
                    ),
                    coordinates: Location.Coordinates(latitude: 51.4589, longitude: -0.3037),
                    accessibilityNotes: "First floor, lift available",
                    parkingInfo: "Street parking available (pay & display)",
                    babyChangingFacilities: "Baby changing table in accessible toilet"
                ),
                schedule: Schedule(
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(7776000),
                    recurringDays: ["tuesday", "thursday"],
                    timeSlots: [
                        Schedule.TimeSlot(
                            startTime: Calendar.current.date(from: DateComponents(hour: 11))!,
                            duration: 3600
                        )
                    ],
                    totalSessions: 24
                ),
                pricing: Pricing(
                    amount: Decimal(12.0),
                    currency: "GBP",
                    type: .perSession,
                    description: "Pay as you go"
                ),
                maxCapacity: 15,
                currentEnrollment: 12,
                averageRating: 4.6,
                ageRange: "1-3 years",
                isFavorite: true,
                isActive: true
            ),
            Class(
                id: "mock-class-3",
                name: "Parent & Baby Yoga",
                description: "Gentle yoga sessions for parents and babies to bond and relax together.",
                category: .wellness,
                provider: "mock-provider-3", providerName: "Provider 3",
                location: Location(
                    id: "mock-location-3",
                    name: "Wellness Centre",
                    address: Address(
                        street: "789 Station Road",
                        city: "Richmond",
                        state: "London",
                        postalCode: "TW9 3QT",
                        country: "UK"
                    ),
                    coordinates: Location.Coordinates(latitude: 51.4637, longitude: -0.3017),
                    accessibilityNotes: "Ground floor, accessible entrance",
                    parkingInfo: "Free parking on site",
                    babyChangingFacilities: "Private changing room with changing table and sink"
                ),
                schedule: Schedule(
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(7776000),
                    recurringDays: ["saturday"],
                    timeSlots: [
                        Schedule.TimeSlot(
                            startTime: Calendar.current.date(from: DateComponents(hour: 10))!,
                            duration: 3600
                        )
                    ],
                    totalSessions: 12
                ),
                pricing: Pricing(
                    amount: Decimal(18.0),
                    currency: "GBP",
                    type: .perSession,
                    description: "Pay as you go"
                ),
                maxCapacity: 10,
                currentEnrollment: 7,
                averageRating: 4.9,
                ageRange: "0-12 months",
                isFavorite: false,
                isActive: true
            )
        ]
    }
}

struct ProviderClassDiscoveryScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ProviderClassDiscoveryViewModel()
    @State private var selectedCategory: ClassCategory? = nil
    @State private var showingFilters = false
    @State private var searchText = ""
    @State private var animateHeader = false
    @State private var animateCards = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with provider context
            headerView
            
            // Category filter
            categoryFilterView
            
            // Content
            contentView
        }
        .background(Color.yugiCream.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    dismiss()
                }
                .foregroundColor(.white)
            }
        }
        .sheet(isPresented: $showingFilters) {
            ProviderClassFiltersSheet()
        }
        .onAppear {
            print("ProviderClassDiscoveryScreen appeared")
            // Start header and filter animations immediately
            withAnimation {
                animateHeader = true
            }
            print("Header animation triggered")
            
            // Load classes and then animate the cards
            Task {
                print("Starting to load classes...")
                await viewModel.loadClasses()
                print("Classes loaded: \(viewModel.classes.count) classes")
                
                // Trigger card animations after classes are loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("Triggering card animations...")
                    withAnimation {
                        animateCards = true
                    }
                    print("Card animation triggered, animateCards = \(animateCards)")
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Discover Classes")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("See what other providers are offering")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                Button {
                    showingFilters = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.7))
                
                TextField("Search classes, providers, or locations", text: $searchText)
                    .foregroundColor(.white)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding(12)
            .background(Color.white.opacity(0.2))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(hex: "#BC6C5C"))
        .offset(y: animateHeader ? 0 : -30)
        .opacity(animateHeader ? 1 : 0)
        .animation(.easeOut(duration: 0.6).delay(0.1), value: animateHeader)
    }
    
    private var categoryFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                CategoryButton(
                    title: "All",
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )
                
                ForEach(ClassCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        title: category.displayName,
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.yugiCream)
        .offset(y: animateHeader ? 0 : -30)
        .opacity(animateHeader ? 1 : 0)
        .animation(.easeOut(duration: 0.6).delay(0.2), value: animateHeader)
    }
    
    private var contentView: some View {
        Group {
            if viewModel.isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#BC6C5C")))
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(Array(filteredClasses.enumerated()), id: \.element.id) { index, classItem in
                            ProviderClassCard(classItem: classItem)
                                .offset(y: animateCards ? 0 : -100)
                                .opacity(animateCards ? 1 : 0)
                                .animation(.easeOut(duration: 0.8).delay(Double(index) * 0.2), value: animateCards)
                                .onAppear {
                                    print("Card \(index) appeared, animateCards = \(animateCards)")
                                }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private var filteredClasses: [Class] {
        var filtered = viewModel.classes
        
        // Filter by category
        if let selectedCategory = selectedCategory {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { classItem in
                classItem.name.localizedCaseInsensitiveContains(searchText) ||
                "Provider \(classItem.provider)".localizedCaseInsensitiveContains(searchText) ||
                classItem.location?.name.localizedCaseInsensitiveContains(searchText) == true ||
                classItem.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
}

struct ProviderClassCard: View {
    let classItem: Class
    @State private var showingDetails = false
    @State private var showingProviderProfile = false
    
    var body: some View {
        VStack(spacing: 12) {
            Button {
                showingDetails = true
            } label: {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(classItem.name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.yugiGray)
                            .multilineTextAlignment(.leading)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(classItem.providerName ?? "Provider \(classItem.provider)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#BC6C5C"))
                            
                            Button(action: {
                                showingProviderProfile = true
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.circle")
                                        .font(.system(size: 12))
                                    Text("View Provider Profile")
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
                    }
                    
                    Spacer()
                }
                
                // Description
                Text(classItem.description)
                    .font(.system(size: 14))
                    .foregroundColor(.yugiGray.opacity(0.8))
                    .lineLimit(2)
                
                // Provider insights
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#BC6C5C"))
                        
                        Text("Provider Insights")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.yugiGray)
                    }
                    
                    HStack(spacing: 16) {
                        InsightBadge(
                            icon: "graduationcap.fill",
                            text: "Provider qualifications"
                        )
                        
                        InsightBadge(
                            icon: "person.3.fill",
                            text: "\(classItem.currentEnrollment)/\(classItem.maxCapacity) enrolled"
                        )
                    }
                }
                
                // Location and pricing
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.yugiGray.opacity(0.6))
                        
                        Text(classItem.location?.name ?? "Location TBD")
                            .font(.system(size: 12))
                            .foregroundColor(.yugiGray.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Text("£\(NSDecimalNumber(decimal: classItem.pricing.amount).intValue)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingDetails) {
            ProviderClassDetailSheet(classItem: classItem)
        }
        .sheet(isPresented: $showingProviderProfile) {
            ProviderProfilePopup(providerId: classItem.provider)
        }
    }
}

struct InsightBadge: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Color(hex: "#BC6C5C"))
            
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.yugiGray.opacity(0.8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: "#BC6C5C").opacity(0.1))
        .cornerRadius(8)
    }
}

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color(hex: "#BC6C5C") : Color.white)
                .foregroundColor(isSelected ? .white : .yugiGray)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : Color.yugiGray.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct ProviderClassFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Filters")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.yugiGray)
                
                Text("Filter options coming soon!")
                    .font(.system(size: 16))
                    .foregroundColor(.yugiGray.opacity(0.8))
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding()
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#BC6C5C"))
                }
            }
        }
    }
}

struct ProviderClassDetailSheet: View {
    let classItem: Class
    @Environment(\.dismiss) private var dismiss
    
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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(classItem.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.yugiGray)
                        
                        Text("by Provider \(classItem.provider)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(hex: "#BC6C5C"))
                    }
                    
                    // Description
                    Text(classItem.description)
                        .font(.system(size: 16))
                        .foregroundColor(.yugiGray.opacity(0.8))
                    
                    // Provider details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Provider Details")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.yugiGray)
                        
                        VStack(spacing: 12) {
                            DetailRow(
                                icon: "graduationcap.fill",
                                title: "Qualifications",
                                value: "Provider qualifications"
                            )
                            
                            DetailRow(
                                icon: "person.3.fill",
                                title: "Enrollment",
                                value: "\(classItem.currentEnrollment)/\(classItem.maxCapacity) children"
                            )
                            
                            DetailRow(
                                icon: "location.fill",
                                title: "Location",
                                value: classItem.location?.name ?? "Location TBD"
                            )
                            
                            Button(action: {
                                openInAppleMaps()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "map")
                                        .font(.system(size: 16))
                                        .foregroundColor(Color(hex: "#BC6C5C"))
                                    
                                    Text("View in Apple Maps")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(Color(hex: "#BC6C5C"))
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(hex: "#BC6C5C"))
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color(hex: "#BC6C5C").opacity(0.1))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            
                            DetailRow(
                                icon: "creditcard.fill",
                                title: "Price",
                                value: "£\(NSDecimalNumber(decimal: classItem.pricing.amount).intValue) per session"
                            )
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#BC6C5C"))
                }
            }
        }
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#BC6C5C"))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.yugiGray)
                
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(.yugiGray.opacity(0.8))
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(8)
    }
}

#Preview {
    ProviderClassDiscoveryScreen()
}