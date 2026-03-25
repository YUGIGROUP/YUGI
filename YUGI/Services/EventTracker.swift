import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Private types

private struct TrackedEvent: Encodable {
    let eventType: String
    let classId: String?
    let metadata: [String: AnyCodable]
    let timestamp: String
    let sessionId: String
    let parentLocation: CoordPayload?
    let venueLocation: CoordPayload?
}

private struct CoordPayload: Encodable {
    let latitude: Double
    let longitude: Double
}

private struct AnyCodable: Encodable {
    private let value: Any

    init(_ value: Any) { self.value = value }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as String:           try container.encode(v)
        case let v as Int:              try container.encode(v)
        case let v as Double:           try container.encode(v)
        case let v as Bool:             try container.encode(v)
        case let v as [String]:         try container.encode(v)
        case let v as [String: String]: try container.encode(v.mapValues { AnyCodable($0) })
        default:                        try container.encode(String(describing: value))
        }
    }
}

// MARK: - EventTracker

final class EventTracker {
    static let shared = EventTracker()

    private let sessionId: String = UUID().uuidString
    private var queue: [TrackedEvent] = []
    private let lock = NSLock()
    private var flushTimer: Timer?

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private init() {
        startFlushTimer()
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        #endif
    }

    // MARK: - Timer & flush

    private func startFlushTimer() {
        flushTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.flush()
        }
    }

    @objc private func appWillResignActive() {
        flush()
    }

    private func flush() {
        lock.lock()
        guard !queue.isEmpty else { lock.unlock(); return }
        let batch = queue
        queue.removeAll()
        lock.unlock()
        sendBatch(batch)
    }

    private func sendBatch(_ events: [TrackedEvent]) {
        // APIConfig.baseURL already includes /api, e.g. "https://yugi-production.up.railway.app/api"
        guard let url = URL(string: "\(APIConfig.baseURL)/events/batch") else { return }
        guard let token = UserDefaults.standard.string(forKey: "authToken") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body = ["events": events]
        guard let data = try? JSONEncoder().encode(body) else { return }
        request.httpBody = data

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("EventTracker: batch send failed: \(error.localizedDescription)")
            } else if let http = response as? HTTPURLResponse, http.statusCode != 201 {
                print("EventTracker: batch returned \(http.statusCode)")
            }
        }.resume()
    }

    // MARK: - Enqueue

    private func enqueue(
        eventType: String,
        classId: String? = nil,
        metadata: [String: AnyCodable] = [:],
        venueLocation: CoordPayload? = nil
    ) {
        guard ConsentManager.shared.hasConsented() else { return }

        let loc = LocationService.shared
        let parentLocation = CoordPayload(latitude: loc.latitude, longitude: loc.longitude)

        let event = TrackedEvent(
            eventType: eventType,
            classId: classId,
            metadata: metadata,
            timestamp: Self.isoFormatter.string(from: Date()),
            sessionId: sessionId,
            parentLocation: parentLocation,
            venueLocation: venueLocation
        )

        lock.lock()
        queue.append(event)
        lock.unlock()
    }

    // MARK: - Public track methods

    func trackClassViewed(classId: String, className: String, venueLocation: (lat: Double, lng: Double)? = nil) {
        enqueue(
            eventType: "class_viewed",
            classId: classId,
            metadata: ["className": AnyCodable(className)],
            venueLocation: venueLocation.map { CoordPayload(latitude: $0.lat, longitude: $0.lng) }
        )
    }

    func trackSearch(query: String, filters: [String: String]? = nil) {
        var meta: [String: AnyCodable] = ["query": AnyCodable(query)]
        if let filters = filters { meta["filters"] = AnyCodable(filters) }
        enqueue(eventType: "class_searched", metadata: meta)
    }

    func trackBookingStarted(classId: String) {
        enqueue(eventType: "booking_started", classId: classId)
    }

    func trackBookingCompleted(classId: String, bookingId: String) {
        enqueue(
            eventType: "booking_completed",
            classId: classId,
            metadata: ["bookingId": AnyCodable(bookingId)]
        )
    }

    func trackBookingCancelled(classId: String, reason: String? = nil) {
        var meta: [String: AnyCodable] = [:]
        if let reason = reason { meta["reason"] = AnyCodable(reason) }
        enqueue(eventType: "booking_cancelled", classId: classId, metadata: meta)
    }

    func trackVenueChecked(venueName: String, location: String, venueLocation: (lat: Double, lng: Double)? = nil) {
        enqueue(
            eventType: "venue_checked",
            metadata: [
                "venueName": AnyCodable(venueName),
                "location":  AnyCodable(location),
            ],
            venueLocation: venueLocation.map { CoordPayload(latitude: $0.lat, longitude: $0.lng) }
        )
    }

    func trackFilterUsed(filterType: String, value: String) {
        enqueue(
            eventType: "filter_used",
            metadata: ["filterType": AnyCodable(filterType), "value": AnyCodable(value)]
        )
    }

    func trackDoabilityWarningSeen(classId: String, warnings: [String]) {
        enqueue(
            eventType: "doability_warning_seen",
            classId: classId,
            metadata: ["warnings": AnyCodable(warnings)]
        )
    }
}
