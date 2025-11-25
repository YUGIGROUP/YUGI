import SwiftUI

struct ProviderClassSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedCategory: ClassCategory? = nil
    @State private var selectedLocation = ""
    @State private var showingFilters = false
    @State private var showingBookingSheet = false
    @State private var selectedClass: Class? = nil
    
    // Mock data - in a real app this would come from an API
    @State private var classes: [Class] = [
        Class(
            id: "mock-class-id-1",
            name: "Baby Sensory Adventure",
            description: "A journey of discovery through light, sound, and touch.",
            category: .baby,
            provider: "mock-location-id-1", providerName: "Sensory World Studio",
            location: Location(
                id: "mock-location-id-1",
                name: "Sensory World Studio",
                address: Address(
                    street: "123 Sensory Street",
                    city: "London",
                    state: "England",
                    postalCode: "SW1A 1AA",
                    country: "United Kingdom"
                ),
                coordinates: Location.Coordinates(latitude: 51.5074, longitude: -0.1278),
                accessibilityNotes: "Wheelchair accessible",
                parkingInfo: "Free parking available",
                babyChangingFacilities: "Available on site"
            ),
            schedule: Schedule(
                startDate: Date().addingTimeInterval(86400),
                endDate: Date().addingTimeInterval(86400 + 3600),
                recurringDays: ["monday", "wednesday", "friday"],
                timeSlots: [
                    Schedule.TimeSlot(startTime: Date().addingTimeInterval(86400), duration: 3600)
                ],
                totalSessions: 12
            ),
            pricing: Pricing(amount: 15.0, currency: "GBP", type: .perSession, description: "Per session"),
            maxCapacity: 10,
            currentEnrollment: 8,
            averageRating: 4.8,
            ageRange: "0-12 months",
            isFavorite: false,
            isActive: true
        ),
        Class(
            id: "mock-class-id-2",
            name: "Toddler Music Time",
            description: "Interactive music and movement for active toddlers.",
            category: .toddler,
            provider: "mock-location-id-1", providerName: "Sensory World Studio",
            location: Location(
                id: "mock-location-id-1",
                name: "Music Studio London",
                address: Address(
                    street: "456 Music Lane",
                    city: "London",
                    state: "England",
                    postalCode: "W1A 1AA",
                    country: "United Kingdom"
                ),
                coordinates: Location.Coordinates(latitude: 51.5074, longitude: -0.1278),
                accessibilityNotes: "Ground floor access",
                parkingInfo: "Street parking",
                babyChangingFacilities: "Available"
            ),
            schedule: Schedule(
                startDate: Date().addingTimeInterval(172800),
                endDate: Date().addingTimeInterval(172800 + 3600),
                recurringDays: ["tuesday", "thursday"],
                timeSlots: [
                    Schedule.TimeSlot(startTime: Date().addingTimeInterval(172800), duration: 3600)
                ],
                totalSessions: 8
            ),
            pricing: Pricing(amount: 12.0, currency: "GBP", type: .perSession, description: "Per session"),
            maxCapacity: 8,
            currentEnrollment: 6,
            averageRating: 4.6,
            ageRange: "1-3 years",
            isFavorite: false,
            isActive: true
        ),
        Class(
            id: "mock-class-id-3",
            name: "Parent & Baby Yoga",
            description: "Gentle yoga poses and breathing exercises for babies and parents.",
            category: .wellness,
            provider: "mock-location-id-1", providerName: "Sensory World Studio",
            location: Location(
                id: "mock-location-id-1",
                name: "Wellness Studio",
                address: Address(
                    street: "789 Wellness Way",
                    city: "London",
                    state: "England",
                    postalCode: "E1A 1AA",
                    country: "United Kingdom"
                ),
                coordinates: Location.Coordinates(latitude: 51.5074, longitude: -0.1278),
                accessibilityNotes: "Fully accessible",
                parkingInfo: "Free parking",
                babyChangingFacilities: "Available"
            ),
            schedule: Schedule(
                startDate: Date().addingTimeInterval(259200),
                endDate: Date().addingTimeInterval(259200 + 3600),
                recurringDays: ["saturday"],
                timeSlots: [
                    Schedule.TimeSlot(startTime: Date().addingTimeInterval(259200), duration: 3600)
                ],
                totalSessions: 6
            ),
            pricing: Pricing(amount: 18.0, currency: "GBP", type: .perSession, description: "Per session"),
            maxCapacity: 6,
            currentEnrollment: 4,
            averageRating: 4.9,
            ageRange: "0-18 months",
            isFavorite: false,
            isActive: true
        )
    ]
    
    private var filteredClasses: [Class] {
        classes.filter { classItem in
            let matchesSearch = searchText.isEmpty || 
                classItem.name.localizedCaseInsensitiveContains(searchText) ||
                "Provider \(classItem.provider)".localizedCaseInsensitiveContains(searchText)
            
            let matchesCategory = selectedCategory == nil || classItem.category == selectedCategory
            
            let matchesLocation = selectedLocation.isEmpty || 
                classItem.location?.name.localizedCaseInsensitiveContains(selectedLocation) == true ||
                classItem.location?.address.city.localizedCaseInsensitiveContains(selectedLocation) == true
            
            return matchesSearch && matchesCategory && matchesLocation
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                // Search and Filters
                searchAndFiltersSection
                
                // Classes List
                classesListSection
            }
            .background(Color.yugiCream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#BC6C5C"))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingFilters = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(Color(hex: "#BC6C5C"))
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                ProviderFilterSheet(
                    selectedCategory: $selectedCategory,
                    selectedLocation: $selectedLocation,
                    onApply: {
                        showingFilters = false
                    }
                )
            }
            .sheet(isPresented: $showingBookingSheet) {
                if let selectedClass = selectedClass {
                    ProviderBookingSheet(classItem: selectedClass)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("Browse Classes")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text("Discover and book classes from other providers")
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
    
    private var searchAndFiltersSection: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.yugiGray.opacity(0.6))
                
                TextField("Search classes or providers...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.yugiGray.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            
            // Active Filters
            if selectedCategory != nil || !selectedLocation.isEmpty {
                HStack {
                    Text("Filtered by: \(filterDescription)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                    
                    Spacer()
                    
                    Button("Clear") {
                        selectedCategory = nil
                        selectedLocation = ""
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.yugiGray)
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal)
        .padding(.top, 20)
    }
    
    private var classesListSection: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if filteredClasses.isEmpty {
                    EmptySearchView(searchText: searchText, selectedCategory: selectedCategory)
                } else {
                    ForEach(filteredClasses, id: \.id) { classItem in
                        ProviderSearchClassCard(
                            classItem: classItem,
                            onBook: {
                                selectedClass = classItem
                                showingBookingSheet = true
                            }
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }
    
    private var filterDescription: String {
        var filters: [String] = []
        if let category = selectedCategory {
            filters.append(category.displayName)
        }
        if !selectedLocation.isEmpty {
            filters.append("Location: \(selectedLocation)")
        }
        return filters.joined(separator: ", ")
    }
}

// MARK: - Supporting Views

struct ProviderSearchClassCard: View {
    let classItem: Class
    let onBook: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            }
            
            // Description
            Text(classItem.description)
                .font(.system(size: 14))
                .foregroundColor(.yugiGray.opacity(0.8))
                .lineLimit(2)
            
            // Provider Info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("by \(classItem.providerName ?? "Provider \(classItem.provider)")")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.yugiGray)
                    
                    Text(classItem.location?.name ?? "Location TBD")
                        .font(.system(size: 12))
                        .foregroundColor(.yugiGray.opacity(0.7))
                }
                
                Spacer()
                
                // Price
                Text("£\(String(format: "%.2f", Double(truncating: classItem.pricing.amount as NSDecimalNumber)))")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "#BC6C5C"))
            }
            
            // Schedule and Capacity
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatSchedule())
                        .font(.system(size: 12))
                        .foregroundColor(.yugiGray.opacity(0.7))
                    
                    Text("\(classItem.currentEnrollment)/\(classItem.maxCapacity) booked")
                        .font(.system(size: 12))
                        .foregroundColor(.yugiGray.opacity(0.7))
                }
                
                Spacer()
                
                // Book Button
                Button(action: onBook) {
                    Text(classItem.isAvailable ? "Book Now" : "Full")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(classItem.isAvailable ? Color(hex: "#BC6C5C") : Color.gray)
                        )
                }
                .disabled(!classItem.isAvailable)
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private func formatSchedule() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        formatter.timeStyle = .short
        return formatter.string(from: classItem.schedule.startDate)
    }
}

struct EmptySearchView: View {
    let searchText: String
    let selectedCategory: ClassCategory?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.yugiGray.opacity(0.3))
            
            VStack(spacing: 8) {
                Text("No classes found")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.yugiGray)
                
                if !searchText.isEmpty || selectedCategory != nil {
                    Text("Try adjusting your search or filters")
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray.opacity(0.7))
                        .multilineTextAlignment(.center)
                } else {
                    Text("No classes are currently available")
                        .font(.system(size: 14))
                        .foregroundColor(.yugiGray.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

struct ProviderFilterSheet: View {
    @Binding var selectedCategory: ClassCategory?
    @Binding var selectedLocation: String
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Filter Classes")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.yugiGray)
                
                VStack(alignment: .leading, spacing: 16) {
                    // Category Filter
                    Text("Category")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.yugiGray)
                    
                    VStack(spacing: 12) {
                        ForEach(ClassCategory.allCases, id: \.self) { category in
                            Button {
                                if selectedCategory == category {
                                    selectedCategory = nil
                                } else {
                                    selectedCategory = category
                                }
                            } label: {
                                HStack {
                                    Text(category.displayName)
                                        .font(.system(size: 16))
                                        .foregroundColor(.yugiGray)
                                    
                                    Spacer()
                                    
                                    if selectedCategory == category {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color(hex: "#BC6C5C"))
                                    } else {
                                        Circle()
                                            .stroke(Color.yugiGray.opacity(0.3), lineWidth: 2)
                                            .frame(width: 20, height: 20)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedCategory == category ? Color(hex: "#BC6C5C").opacity(0.05) : Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedCategory == category ? Color(hex: "#BC6C5C").opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // Location Filter
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        TextField("Enter city or location", text: $selectedLocation)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
                
                Spacer()
                
                Button("Apply Filters") {
                    onApply()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color(hex: "#BC6C5C"))
                .cornerRadius(12)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.yugiGray)
                }
            }
        }
    }
}

struct ProviderBookingSheet: View {
    let classItem: Class
    @Environment(\.dismiss) private var dismiss
    @State private var numberOfParticipants = 1
    @State private var specialRequirements = ""
    @State private var isBooking = false
    @State private var showingSuccessAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Class Info
                VStack(alignment: .leading, spacing: 12) {
                    Text(classItem.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.yugiGray)
                    
                    Text("by \(classItem.providerName ?? "Provider \(classItem.provider)")")
                        .font(.system(size: 16))
                        .foregroundColor(.yugiGray.opacity(0.8))
                    
                    Text("£\(String(format: "%.2f", Double(truncating: classItem.pricing.amount as NSDecimalNumber))) per session")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Color(hex: "#BC6C5C"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Booking Details
                VStack(alignment: .leading, spacing: 16) {
                    Text("Booking Details")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.yugiGray)
                    
                    // Number of Participants
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Number of Participants")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        Stepper(value: $numberOfParticipants, in: 1...5) {
                            HStack {
                                Text("\(numberOfParticipants) participant\(numberOfParticipants == 1 ? "" : "s")")
                                    .font(.system(size: 16))
                                    .foregroundColor(.yugiGray)
                                Spacer()
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(hex: "#BC6C5C").opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // Special Requirements
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Special Requirements (Optional)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yugiGray)
                        
                        TextField("Any special needs or requests...", text: $specialRequirements, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                    }
                }
                
                Spacer()
                
                // Book Button
                Button(action: bookClass) {
                    HStack {
                        if isBooking {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 18))
                        }
                        
                        Text(isBooking ? "Booking..." : "Book Class")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(hex: "#BC6C5C"))
                    .cornerRadius(12)
                }
                .disabled(isBooking)
                .buttonStyle(.plain)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.yugiGray)
                }
            }
            .alert("Booking Successful!", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("You have successfully booked '\(classItem.name)'. You will receive a confirmation email shortly.")
            }
        }
    }
    
    private func bookClass() {
        isBooking = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isBooking = false
            showingSuccessAlert = true
        }
    }
}

#Preview {
    ProviderClassSearchView()
} 
