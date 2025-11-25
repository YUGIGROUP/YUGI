import SwiftUI
import CoreLocation
import Combine

struct VenueAnalysisScreen: View {
    let enhancedBooking: EnhancedBooking
    @Environment(\.dismiss) private var dismiss
    @State private var analysisData: VenueAnalysisUIData?
    @State private var venueApiData: VenueAnalysisAPIData?
    @State private var isLoading = true
    
    private func openInAppleMaps() {
        let coordinates = enhancedBooking.classInfo.location?.coordinates ?? Location.Coordinates(latitude: 51.5074, longitude: -0.1278)
        let venueName = enhancedBooking.classInfo.location?.name ?? "Location TBD"
        
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
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Venue Analysis")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(enhancedBooking.classInfo.location?.name ?? "Location TBD")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        openInAppleMaps()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "map")
                                .font(.system(size: 16))
                            Text("Maps")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
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
            
            // Content
            ScrollView {
                LazyVStack(spacing: 20) {
                    if isLoading {
                        loadingView
                    } else if let analysis = analysisData {
                        venueInfoSection(analysis)
                        accessibilitySection(analysis)
                        safetySection(analysis)
                        amenitiesSection(analysis)
                        recommendationsSection(analysis)
                    } else {
                        errorView
                    }
                }
                .padding(20)
            }
        }
        .background(Color(hex: "#BC6C5C").ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            loadVenueAnalysis()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            
            Text("Analyzing venue...")
                .font(.system(size: 16))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.6))
            
            Text("Unable to load venue analysis")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
            
            Text("Please try again later")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private func venueInfoSection(_ analysis: VenueAnalysisUIData) -> some View {
        AnalysisCard(title: "Venue Information") {
            VStack(alignment: .leading, spacing: 12) {
                AnalysisRow(icon: "mappin.circle", title: "Address", value: enhancedBooking.classInfo.location?.address.formatted ?? "Location TBD")
                AnalysisRow(icon: "location.circle", title: "Coordinates", value: String(format: "%.4f, %.4f", analysis.coordinates.latitude, analysis.coordinates.longitude))
                AnalysisRow(icon: "building.2", title: "Venue Type", value: analysis.venueType)
                AnalysisRow(icon: "person.3", title: "Capacity", value: "\(enhancedBooking.classInfo.maxCapacity) people")
            }
        }
    }
    
    private func accessibilitySection(_ analysis: VenueAnalysisUIData) -> some View {
        AnalysisCard(title: "Accessibility") {
            VStack(alignment: .leading, spacing: 12) {
                AnalysisRow(icon: "wheelchair", title: "Wheelchair Access", value: analysis.wheelchairAccess ? "Available" : "Limited")
                AnalysisRow(icon: "arrow.up.arrow.down", title: "Elevator Access", value: analysis.elevatorAccess ? "Available" : "Not available")
                AnalysisRow(icon: "arrow.up.right", title: "Ramp Access", value: analysis.rampAccess ? "Available" : "Not available")
                if let notes = enhancedBooking.classInfo.location?.accessibilityNotes {
                    AnalysisRow(icon: "note.text", title: "Additional Notes", value: notes)
                }
            }
        }
    }
    
    private func safetySection(_ analysis: VenueAnalysisUIData) -> some View {
        AnalysisCard(title: "Safety & Security") {
            VStack(alignment: .leading, spacing: 12) {
                AnalysisRow(icon: "shield", title: "Security Rating", value: "\(analysis.securityRating)/10")
                AnalysisRow(icon: "camera", title: "CCTV Coverage", value: analysis.cctvCoverage ? "Available" : "Not available")
                AnalysisRow(icon: "person.2.circle", title: "Staff Presence", value: analysis.staffPresence ? "Regular" : "Limited")
                AnalysisRow(icon: "cross.case", title: "First Aid", value: analysis.firstAidAvailable ? "Available" : "Not available")
            }
        }
    }
    
    private func amenitiesSection(_ analysis: VenueAnalysisUIData) -> some View {
        AnalysisCard(title: "Amenities") {
            VStack(alignment: .leading, spacing: 12) {
                // Use real venue data from API response if available, otherwise fallback to class location data
                let parkingInfo = venueApiData?.parkingInfo ?? enhancedBooking.classInfo.location?.parkingInfo ?? "Not specified"
                let babyChangingInfo = venueApiData?.babyChangingFacilities ?? enhancedBooking.classInfo.location?.babyChangingFacilities ?? "Not specified"
                
                AnalysisRow(icon: "car", title: "Parking", value: parkingInfo)
                AnalysisRow(icon: "person.3", title: "Baby Changing", value: babyChangingInfo)
                AnalysisRow(icon: "toilet", title: "Restrooms", value: analysis.restroomsAvailable ? "Available" : "Not available")
                AnalysisRow(icon: "wifi", title: "WiFi", value: analysis.wifiAvailable ? "Available" : "Not available")
            }
        }
    }
    
    private func recommendationsSection(_ analysis: VenueAnalysisUIData) -> some View {
        AnalysisCard(title: "AI Recommendations") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(analysis.recommendations, id: \.self) { recommendation in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#BC6C5C"))
                            .frame(width: 16)
                        
                        Text(recommendation)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    private func loadVenueAnalysis() {
        guard let location = enhancedBooking.classInfo.location else {
            isLoading = false
            return
        }
        
        let apiService = APIService.shared
        
        Task {
            do {
                let response = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<VenueAnalysisResponse, Error>) in
                    apiService.analyzeVenue(venueName: location.name, address: location.address)
                        .sink(
                            receiveCompletion: { completion in
                                if case .failure(let error) = completion {
                                    continuation.resume(throwing: error)
                                }
                            },
                            receiveValue: { response in
                                continuation.resume(returning: response)
                            }
                        )
                        .store(in: &apiService.cancellables)
                }
                
                // Convert API response to VenueAnalysisData
                let venueData = response.data
                let coordinates = venueData.coordinates.map { Location.Coordinates(latitude: $0.latitude, longitude: $0.longitude) } 
                    ?? enhancedBooking.classInfo.location?.coordinates 
                    ?? Location.Coordinates(latitude: 51.5074, longitude: -0.1278)
                
                await MainActor.run {
                    // Store the API response data for use in the UI
                    venueApiData = venueData
                    
                    analysisData = VenueAnalysisUIData(
                        coordinates: coordinates,
                        venueType: determineVenueType(from: location.name),
                        wheelchairAccess: venueData.accessibilityNotes?.lowercased().contains("wheelchair") ?? false,
                        elevatorAccess: venueData.accessibilityNotes?.lowercased().contains("elevator") ?? false,
                        rampAccess: venueData.accessibilityNotes?.lowercased().contains("ramp") ?? false,
                        securityRating: 8, // Default, could be enhanced with more data
                        cctvCoverage: true, // Default
                        staffPresence: true, // Default
                        firstAidAvailable: true, // Default
                        restroomsAvailable: true, // Default
                        wifiAvailable: true, // Default
                        recommendations: generateRecommendations(from: venueData)
                    )
                    isLoading = false
                }
            } catch {
                print("❌ Failed to load venue analysis: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func determineVenueType(from venueName: String) -> String {
        let name = venueName.lowercased()
        if name.contains("theatre") || name.contains("theater") {
            return "Theatre"
        } else if name.contains("community") || name.contains("centre") || name.contains("center") {
            return "Community Center"
        } else if name.contains("library") {
            return "Library"
        } else if name.contains("museum") {
            return "Museum"
        } else if name.contains("hall") {
            return "Hall"
        } else if name.contains("park") {
            return "Park"
        } else {
            return "Venue"
        }
    }
    
    private func generateRecommendations(from venueData: VenueAnalysisAPIData) -> [String] {
        var recommendations: [String] = []
        
        if venueData.parkingInfo.lowercased().contains("street") || venueData.parkingInfo.lowercased().contains("limited") {
            recommendations.append("Arrive 10 minutes early to find parking")
        }
        
        if venueData.babyChangingFacilities.lowercased().contains("portable") {
            recommendations.append("Consider bringing portable changing facilities")
        }
        
        if let accessibilityNotes = venueData.accessibilityNotes, accessibilityNotes.lowercased().contains("limited") {
            recommendations.append("Contact venue ahead of time for accessibility requirements")
        }
        
        if recommendations.isEmpty {
            recommendations.append("Check with venue staff about any specific requirements")
        }
        
        return recommendations
    }
}

struct AnalysisCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            content
        }
        .padding(16)
        .background(Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white, lineWidth: 1)
        )
    }
}

struct AnalysisRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#BC6C5C"))
                .frame(width: 16)
            
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct VenueAnalysisUIData {
    let coordinates: Location.Coordinates
    let venueType: String
    let wheelchairAccess: Bool
    let elevatorAccess: Bool
    let rampAccess: Bool
    let securityRating: Int
    let cctvCoverage: Bool
    let staffPresence: Bool
    let firstAidAvailable: Bool
    let restroomsAvailable: Bool
    let wifiAvailable: Bool
    let recommendations: [String]
}

#Preview {
    VenueAnalysisScreen(enhancedBooking: EnhancedBooking(
        booking: Booking(
            id: UUID(),
            classId: "mock-class-id-1",
            userId: UUID(),
            status: .upcoming,
            bookingDate: Date(),
            numberOfParticipants: 1,
            selectedChildren: nil,
            specialRequirements: nil,
            attended: false
        ),
        classInfo: Class(
            id: "mock-class-id-1",
            name: "Sample Class",
            description: "A sample class",
            category: .baby,
            provider: "mock-provider-id-1", providerName: "Sample Provider",
            location: Location(
                id: "mock-location-id-1",
                name: "Sample Venue",
                address: Address(
                    street: "123 Sample Street",
                    city: "Sample City",
                    state: "Sample State",
                    postalCode: "12345",
                    country: "UK"
                ),
                coordinates: Location.Coordinates(latitude: 51.5074, longitude: -0.1278),
                accessibilityNotes: "Wheelchair accessible",
                parkingInfo: "Free parking available",
                babyChangingFacilities: "Available in restrooms"
            ),
            schedule: Schedule(
                startDate: Date(),
                endDate: Date().addingTimeInterval(86400 * 30),
                recurringDays: ["monday", "wednesday"],
                timeSlots: [Schedule.TimeSlot(startTime: Date(), duration: 3600)],
                totalSessions: 10
            ),
            pricing: Pricing(amount: Decimal(25), currency: "GBP", type: .perSession, description: nil),
            maxCapacity: 15,
            currentEnrollment: 8,
            averageRating: 4.5,
            ageRange: "0-2 years",
            isFavorite: false,
            isActive: true
        )
    ))
}
