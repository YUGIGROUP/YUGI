import Foundation
import CoreLocation
import Combine

@MainActor
class ClassDiscoveryViewModel: ObservableObject {
    private let locationService: LocationService
    private let bookingService: BookingService
    
    @Published var searchText = ""
    @Published var selectedCategory: ClassCategory?
    @Published var classes: [Class] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    init(locationService: LocationService, bookingService: BookingService) {
        self.locationService = locationService
        self.bookingService = bookingService
    }
    
    var filteredClasses: [Class] {
        classes.filter { classItem in
            let matchesSearch = searchText.isEmpty || 
                classItem.name.localizedCaseInsensitiveContains(searchText) ||
                classItem.description.localizedCaseInsensitiveContains(searchText)
            
            let matchesCategory = selectedCategory == nil || classItem.category == selectedCategory
            
            return matchesSearch && matchesCategory
        }
    }
    
    func startLocationUpdates() {
        Task {
            locationService.requestLocationPermission()
            
            // Wait for location updates
            for await _ in NotificationCenter.default.notifications(named: .locationDidUpdate) {
                if let location = locationService.currentLocation {
                    await updateClasses(near: location)
                }
            }
        }
    }
    
    private func updateClasses(near location: CLLocation) async {
        isLoading = true
        defer { isLoading = false }
        
        // Simulated delay for demo purposes
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Mock data - in a real app, this would fetch from an API
        classes = [
            Class(
                id: UUID(),
                name: "Baby Sensory Adventure",
                description: "A journey of discovery through light, sound, and touch.",
                category: .baby,
                provider: Provider(
                    id: UUID(),
                    name: "Sensory World",
                    description: "Specialists in early development",
                    qualifications: ["Early Years Development"],
                    contactEmail: "info@sensoryworld.com",
                    contactPhone: "020 1234 5678",
                    website: "www.sensoryworld.com",
                    rating: 4.8
                ),
                location: Location(
                    id: UUID(),
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
                    parkingInfo: "Free parking available"
                ),
                schedule: Schedule(
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(7776000), // 90 days
                    recurringDays: [.monday, .wednesday, .friday],
                    timeSlots: [
                        Schedule.TimeSlot(
                            startTime: Calendar.current.date(from: DateComponents(hour: 10))!,
                            duration: 3600
                        )
                    ],
                    totalSessions: 36
                ),
                pricing: Pricing(
                    amount: 15.0,
                    currency: "GBP",
                    type: .perSession,
                    description: "Pay as you go"
                ),
                maxCapacity: 12,
                currentEnrollment: 8,
                averageRating: 4.8,
                ageRange: "0-12 months",
                isFavorite: false
            )
        ]
    }
    
    func toggleFavorite(for classId: UUID) {
        if let index = classes.firstIndex(where: { $0.id == classId }) {
            classes[index].isFavorite.toggle()
        }
    }
    
    func bookClass(_ classItem: Class, participants: Int, requirements: String?) async throws -> Booking {
        try await bookingService.bookClass(classItem, participants: participants, requirements: requirements)
    }
} 