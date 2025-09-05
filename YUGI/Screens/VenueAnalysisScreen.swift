import SwiftUI
import CoreLocation

struct VenueAnalysisScreen: View {
    let enhancedBooking: EnhancedBooking
    @Environment(\.dismiss) private var dismiss
    @State private var analysisData: VenueAnalysisData?
    @State private var isLoading = true
    
    private func openInAppleMaps() {
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Venue Analysis")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(enhancedBooking.classInfo.location.name)
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
    
    private func venueInfoSection(_ analysis: VenueAnalysisData) -> some View {
        AnalysisCard(title: "Venue Information") {
            VStack(alignment: .leading, spacing: 12) {
                AnalysisRow(icon: "mappin.circle", title: "Address", value: enhancedBooking.classInfo.location.address.formatted)
                AnalysisRow(icon: "location.circle", title: "Coordinates", value: String(format: "%.4f, %.4f", analysis.coordinates.latitude, analysis.coordinates.longitude))
                AnalysisRow(icon: "building.2", title: "Venue Type", value: analysis.venueType)
                AnalysisRow(icon: "person.3", title: "Capacity", value: "\(enhancedBooking.classInfo.maxCapacity) people")
            }
        }
    }
    
    private func accessibilitySection(_ analysis: VenueAnalysisData) -> some View {
        AnalysisCard(title: "Accessibility") {
            VStack(alignment: .leading, spacing: 12) {
                AnalysisRow(icon: "wheelchair", title: "Wheelchair Access", value: analysis.wheelchairAccess ? "Available" : "Limited")
                AnalysisRow(icon: "arrow.up.arrow.down", title: "Elevator Access", value: analysis.elevatorAccess ? "Available" : "Not available")
                AnalysisRow(icon: "arrow.up.right", title: "Ramp Access", value: analysis.rampAccess ? "Available" : "Not available")
                if let notes = enhancedBooking.classInfo.location.accessibilityNotes {
                    AnalysisRow(icon: "note.text", title: "Additional Notes", value: notes)
                }
            }
        }
    }
    
    private func safetySection(_ analysis: VenueAnalysisData) -> some View {
        AnalysisCard(title: "Safety & Security") {
            VStack(alignment: .leading, spacing: 12) {
                AnalysisRow(icon: "shield", title: "Security Rating", value: "\(analysis.securityRating)/10")
                AnalysisRow(icon: "camera", title: "CCTV Coverage", value: analysis.cctvCoverage ? "Available" : "Not available")
                AnalysisRow(icon: "person.2.circle", title: "Staff Presence", value: analysis.staffPresence ? "Regular" : "Limited")
                AnalysisRow(icon: "cross.case", title: "First Aid", value: analysis.firstAidAvailable ? "Available" : "Not available")
            }
        }
    }
    
    private func amenitiesSection(_ analysis: VenueAnalysisData) -> some View {
        AnalysisCard(title: "Amenities") {
            VStack(alignment: .leading, spacing: 12) {
                AnalysisRow(icon: "car", title: "Parking", value: enhancedBooking.classInfo.location.parkingInfo ?? "Not specified")
                AnalysisRow(icon: "person.3", title: "Baby Changing", value: enhancedBooking.classInfo.location.babyChangingFacilities ?? "Not specified")
                AnalysisRow(icon: "toilet", title: "Restrooms", value: analysis.restroomsAvailable ? "Available" : "Not available")
                AnalysisRow(icon: "wifi", title: "WiFi", value: analysis.wifiAvailable ? "Available" : "Not available")
            }
        }
    }
    
    private func recommendationsSection(_ analysis: VenueAnalysisData) -> some View {
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
        // Simulate AI venue check loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            analysisData = VenueAnalysisData(
                coordinates: enhancedBooking.classInfo.location.coordinates,
                venueType: "Community Center",
                wheelchairAccess: true,
                elevatorAccess: true,
                rampAccess: true,
                securityRating: 8,
                cctvCoverage: true,
                staffPresence: true,
                firstAidAvailable: true,
                restroomsAvailable: true,
                wifiAvailable: true,
                recommendations: [
                    "Arrive 10 minutes early to find parking",
                    "Bring your own water bottle as facilities may be limited",
                    "Consider bringing a change of clothes for children",
                    "Check with staff about any specific entry requirements"
                ]
            )
            isLoading = false
        }
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

struct VenueAnalysisData {
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
            classId: UUID(),
            userId: UUID(),
            status: .upcoming,
            bookingDate: Date(),
            numberOfParticipants: 1,
            selectedChildren: nil,
            specialRequirements: nil,
            attended: false
        ),
        classInfo: Class(
            id: UUID(),
            name: "Sample Class",
            description: "A sample class",
            category: .baby,
            provider: Provider(
                id: UUID(),
                name: "Sample Provider",
                description: "A sample provider",
                qualifications: [],
                contactEmail: "test@example.com",
                contactPhone: "1234567890",
                website: nil,
                rating: 4.5
            ),
            location: Location(
                id: UUID(),
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
                recurringDays: [.monday, .wednesday],
                timeSlots: [Schedule.TimeSlot(startTime: Date(), duration: 3600)],
                totalSessions: 10
            ),
            pricing: Pricing(amount: Decimal(25), currency: "GBP", type: .perSession, description: nil),
            maxCapacity: 15,
            currentEnrollment: 8,
            averageRating: 4.5,
            ageRange: "0-2 years",
            isFavorite: false
        )
    ))
}
