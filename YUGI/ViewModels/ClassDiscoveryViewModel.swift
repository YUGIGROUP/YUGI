import Foundation
import Combine

@MainActor
class ClassDiscoveryViewModel: ObservableObject {
    private let bookingService: BookingService
    private let newClassStorage = NewClassStorage.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var searchText = ""
    @Published var selectedCategory: ClassCategory?
    @Published var classes: [Class] = []
    @Published var isLoading = false
    @Published var error: Error?

    
    init(bookingService: BookingService) {
        self.bookingService = bookingService
    }
    
    var filteredClasses: [Class] {
        let filtered = classes.filter { classItem in
            let matchesSearch = searchText.isEmpty || 
                classItem.name.localizedCaseInsensitiveContains(searchText) ||
                classItem.description.localizedCaseInsensitiveContains(searchText)
            
            let matchesCategory = selectedCategory == nil || classItem.category == selectedCategory
            
            return matchesSearch && matchesCategory
        }
        

        
        return filtered
    }
    

    
    func startLocationUpdates() {
        Task {
            // Load sample classes immediately for demo purposes
            loadClasses()
        }
    }
    
    private func loadClasses() {
        isLoading = true
        
        // Fetch real classes from the backend API
        APIService.shared.fetchClasses()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case let .failure(error) = completion {
                        self?.error = error
                        print("❌ ClassDiscoveryViewModel: Failed to fetch classes: \(error)")
                    }
                },
                receiveValue: { [weak self] response in
                    self?.isLoading = false
                    self?.error = nil
                    print("✅ ClassDiscoveryViewModel: Successfully fetched \(response.data.count) classes from API")
                    
                    // Convert newly created classes from shared storage to Class format
                    let newClasses = self?.newClassStorage.newClasses.map { providerClass in
                        Class(
                            id: "new-class-\(providerClass.id)", // Use provider class ID for the Class model
                            name: providerClass.name,
                            description: providerClass.description,
                            category: providerClass.category,
                            provider: "new-provider-\(providerClass.id)", providerName: "Provider \(providerClass.id)",
                            location: Location(
                                id: "new-location-\(providerClass.id)",
                                name: providerClass.location,
                                address: Address(
                                    street: providerClass.location,
                                    city: "London",
                                    state: "England",
                                    postalCode: "SW1A 1AA",
                                    country: "United Kingdom"
                                ),
                                coordinates: Location.Coordinates(latitude: 51.5074, longitude: -0.1278),
                                accessibilityNotes: nil,
                                parkingInfo: nil,
                                babyChangingFacilities: nil
                            ),
                            schedule: Schedule(
                                startDate: providerClass.nextSession ?? Date(),
                                endDate: Date().addingTimeInterval(7776000),
                                recurringDays: ["monday"], // Default to Monday
                                timeSlots: [
                                    Schedule.TimeSlot(
                                        startTime: Calendar.current.date(from: DateComponents(hour: 10))!,
                                        duration: 3600
                                    )
                                ],
                                totalSessions: 1
                            ),
                            pricing: Pricing(
                                amount: Decimal(providerClass.price),
                                currency: "GBP",
                                type: .perSession,
                                description: providerClass.isFree ? "Free" : "Pay as you go"
                            ),
                            maxCapacity: providerClass.maxCapacity,
                            currentEnrollment: providerClass.currentBookings,
                            averageRating: 5.0, // New classes get 5-star rating
                            ageRange: "0-3 years", // Default age range
                            isFavorite: false,
                            isActive: true
                        )
                    } ?? []
                    
                    // Combine API classes with newly created classes
                    // Put new classes first so they appear at the top
                    self?.classes = newClasses + response.data
                    
                    print("🔍 ClassDiscoveryViewModel: Loaded \(newClasses.count) new classes + \(response.data.count) API classes = \(newClasses.count + response.data.count) total")
                }
            )
            .store(in: &cancellables)
    }
    

    
    
    func updateClass(_ updatedClass: Class) {
        if let index = classes.firstIndex(where: { $0.id == updatedClass.id }) {
            classes[index] = updatedClass
        }
    }
    
    func bookClass(_ classItem: Class, participants: Int, requirements: String?) async throws -> Booking {
        try await bookingService.bookClass(classItem, participants: participants, requirements: requirements)
    }
} 