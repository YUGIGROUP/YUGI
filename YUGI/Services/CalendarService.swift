import Foundation
import EventKit

class CalendarService: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var error: CalendarError?
    
    enum CalendarError: Error {
        case unauthorized
        case eventCreationFailed
        case reminderCreationFailed
        
        var message: String {
            switch self {
            case .unauthorized:
                return "Please allow calendar access to add class schedules"
            case .eventCreationFailed:
                return "Unable to add class to calendar"
            case .reminderCreationFailed:
                return "Unable to set reminder for class"
            }
        }
    }
    
    func requestAccess() async throws {
        if #available(iOS 17.0, *) {
            try await eventStore.requestFullAccessToEvents()
        } else {
            let granted = await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
            if !granted {
                throw CalendarError.unauthorized
            }
        }
        await MainActor.run {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        }
    }
    
    func addClassToCalendar(_ classItem: Class, booking: Booking) async throws -> String {
        guard let firstSession = classItem.schedule.timeSlots.first else {
            throw CalendarError.eventCreationFailed
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = classItem.name
        event.location = classItem.location.address.formatted
        event.notes = """
        Class Details:
        \(classItem.description)
        
        Provider: \(classItem.provider.name)
        Booking Reference: \(booking.id)
        """
        
        // Set up recurring events if needed
        if !classItem.schedule.recurringDays.isEmpty {
            let recurrenceRule = createRecurrenceRule(for: classItem.schedule)
            event.recurrenceRules = [recurrenceRule]
        }
        
        // Set event time
        event.startDate = firstSession.startTime
        event.endDate = firstSession.endTime
        
        // Add alarm
        let alarm = EKAlarm(relativeOffset: -3600) // 1 hour before
        event.addAlarm(alarm)
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            throw CalendarError.eventCreationFailed
        }
    }
    
    private func createRecurrenceRule(for schedule: Schedule) -> EKRecurrenceRule {
        let endDate = schedule.endDate
        
        let daysOfWeek = schedule.recurringDays.map { day in
            EKRecurrenceDayOfWeek(EKWeekday(rawValue: day.rawValue)!)
        }
        
        return EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 1,
            daysOfTheWeek: daysOfWeek,
            daysOfTheMonth: nil,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: EKRecurrenceEnd(end: endDate)
        )
    }
    
    func removeClassFromCalendar(eventId: String) throws {
        guard let event = eventStore.event(withIdentifier: eventId) else {
            return
        }
        
        do {
            try eventStore.remove(event, span: .thisEvent)
        } catch {
            throw CalendarError.eventCreationFailed
        }
    }
} 