import Foundation
import Combine

@MainActor
class BookingService: ObservableObject {
    @Published var userBookings: [Booking] = []
    @Published var favoriteClasses: Set<String> = []
    @Published var error: BookingError?
    
    private let calendarService: CalendarService
    private let apiService = APIService.shared
    
    enum BookingError: Error {
        case classFull
        case alreadyBooked
        case invalidClass
        case bookingFailed
        case calendarError(CalendarService.CalendarError)
        
        var message: String {
            switch self {
            case .classFull:
                return "This class is currently full"
            case .alreadyBooked:
                return "You have already booked this class"
            case .invalidClass:
                return "This class is no longer available"
            case .bookingFailed:
                return "Unable to complete booking"
            case .calendarError(let error):
                return error.message
            }
        }
    }
    
    init(calendarService: CalendarService) {
        self.calendarService = calendarService
    }
    
    func bookClass(_ classItem: Class, participants: Int = 1, selectedChildren: [Child]? = nil, requirements: String? = nil) async throws -> Booking {
        // Validate booking
        guard classItem.isAvailable else {
            throw BookingError.classFull
        }
        
        // Check if already booked
        if userBookings.contains(where: { $0.classId == classItem.id }) {
            throw BookingError.alreadyBooked
        }
        
        // Get user ID from auth service
        let userId: UUID
        if let currentUser = apiService.currentUser,
           let userUUID = UUID(uuidString: currentUser.id) {
            userId = userUUID
        } else {
            // Fallback: generate UUID from user ID string if conversion fails
            // This ensures we always have a valid UUID
            userId = UUID(uuidString: apiService.currentUser?.id ?? "") ?? UUID()
        }
        
        // Create booking
        let booking = Booking(
            id: UUID(),
            classId: classItem.id,
            userId: userId,
            status: .upcoming,
            bookingDate: Date(),
            numberOfParticipants: participants,
            selectedChildren: selectedChildren,
            specialRequirements: requirements,
            attended: false
        )
        
        do {
            // Add to calendar
            let eventId = try await calendarService.addClassToCalendar(classItem, booking: booking)
            
            // Create updated booking with calendar info
            let updatedBooking = Booking(
                id: booking.id,
                classId: booking.classId,
                userId: booking.userId,
                status: booking.status,
                bookingDate: booking.bookingDate,
                numberOfParticipants: booking.numberOfParticipants,
                selectedChildren: booking.selectedChildren,
                specialRequirements: booking.specialRequirements,
                attended: booking.attended,
                calendar: Booking.Calendar(eventId: eventId, reminderSet: true)
            )
            
            // Add to user's bookings
            userBookings.append(updatedBooking)
            
            return updatedBooking
        } catch let error as CalendarService.CalendarError {
            throw BookingError.calendarError(error)
        } catch {
            throw BookingError.bookingFailed
        }
    }
    
    func cancelBooking(_ booking: Booking) async throws {
        guard let index = userBookings.firstIndex(where: { $0.id == booking.id }) else {
            return
        }
        
        // Remove from calendar if needed
        if let eventId = booking.calendar?.eventId {
            try calendarService.removeClassFromCalendar(eventId: eventId)
        }
        
        // Remove from bookings
        userBookings.remove(at: index)
    }
    
    func toggleFavorite(for classId: String) {
        if favoriteClasses.contains(classId) {
            favoriteClasses.remove(classId)
        } else {
            favoriteClasses.insert(classId)
        }
    }
    
    func isFavorite(_ classId: String) -> Bool {
        favoriteClasses.contains(classId)
    }
    
    // MARK: - Reviews
    
    func submitReview(for classId: String, rating: Int, comment: String?) async throws -> Review {
        // Validate user attended the class
        guard let booking = userBookings.first(where: { $0.classId == classId }),
              booking.attended else {
            throw BookingError.invalidClass
        }
        
        let review = Review(
            id: UUID(),
            classId: classId,
            userId: booking.userId,
            rating: rating,
            comment: comment,
            date: Date(),
            verified: true
        )
        
        // Save review to backend
        // Note: Backend endpoint for reviews needs to be implemented
        // When ready, uncomment and implement:
        /*
        do {
            let reviewData: [String: Any] = [
                "classId": classId,
                "rating": rating,
                "comment": comment ?? "",
                "date": ISO8601DateFormatter().string(from: Date())
            ]
            
            let _ = try await apiService.request(
                endpoint: "/reviews",
                method: .POST,
                body: reviewData
            )
        } catch {
            print("⚠️ Failed to save review to backend: \(error)")
            // Continue anyway - review is created locally
        }
        */
        
        return review
    }
} 