import Foundation

// MARK: - Response Models

struct VenueEnrichmentParking: Decodable {
    let totalSpaces: Int?
    let carParkNames: [String]?
    let type: String?
    let blueBadgeBays: Int?
    let parentBays: Int?
    let costInfo: String?
    let ticketless: Bool?
    let evCharging: Bool?
}

struct VenueEnrichmentBabyChanging: Decodable {
    let available: Bool?
    let location: String?
    let details: String?
}

struct VenueEnrichmentPramAccess: Decodable {
    let stepFreeAccess: Bool?
    let liftAvailable: Bool?
    let details: String?
}

struct VenueEnrichmentPublicTransport: Decodable {
    let nearestStation: String?
    let walkingTime: String?
    let busRoutes: [String]?
}

struct VenueEnrichedData: Decodable {
    let parking: VenueEnrichmentParking?
    let babyChanging: VenueEnrichmentBabyChanging?
    let pramAccess: VenueEnrichmentPramAccess?
    let publicTransport: VenueEnrichmentPublicTransport?
    let additionalNotes: String?
}

struct VenueEnrichmentResponse: Decodable {
    let placeId: String
    let venueName: String
    let enrichedData: VenueEnrichedData
    let sources: [String]
    let confidence: String
    let cachedAt: String?

    /// Whether this response contains any meaningful enrichment data.
    var hasData: Bool {
        let p  = enrichedData.parking
        let b  = enrichedData.babyChanging
        let pr = enrichedData.pramAccess
        let t  = enrichedData.publicTransport
        return p?.totalSpaces != nil
            || p?.carParkNames?.isEmpty == false
            || b?.available != nil
            || pr?.stepFreeAccess != nil
            || t?.nearestStation != nil
            || enrichedData.additionalNotes != nil
    }

    /// Short badges for discovery cards — e.g. ["1,900 spaces", "Baby changing", "Step-free"].
    var discoveryBadges: [String] {
        var badges: [String] = []
        if let spaces = enrichedData.parking?.totalSpaces, spaces > 0 {
            let formatted = spaces >= 1000
                ? "\(spaces / 1000),\(String(format: "%03d", spaces % 1000)) spaces"
                : "\(spaces) spaces"
            badges.append(formatted)
        }
        if enrichedData.babyChanging?.available == true { badges.append("Baby changing") }
        if enrichedData.pramAccess?.stepFreeAccess == true { badges.append("Step-free") }
        if enrichedData.parking?.parentBays != nil { badges.append("Parent & child bays") }
        if enrichedData.parking?.blueBadgeBays != nil { badges.append("Blue Badge bays") }
        return badges
    }

    /// Detailed parking string for venue check / class detail screens.
    var parkingDescription: String? {
        guard let p = enrichedData.parking else { return nil }
        var parts: [String] = []
        if let names = p.carParkNames, !names.isEmpty { parts.append(names.joined(separator: " · ")) }
        if let spaces = p.totalSpaces {
            let fmt = spaces >= 1000
                ? "\(spaces / 1000),\(String(format: "%03d", spaces % 1000)) spaces total"
                : "\(spaces) spaces total"
            parts.append(fmt)
        }
        if let type = p.type, type != "null" { parts.append("\(type.capitalized) parking") }
        if let bb = p.blueBadgeBays { parts.append("\(bb) Blue Badge bay\(bb == 1 ? "" : "s")") }
        if let pb = p.parentBays    { parts.append("\(pb) parent & child bay\(pb == 1 ? "" : "s")") }
        if let cost = p.costInfo    { parts.append(cost) }
        if p.ticketless == true     { parts.append("Ticketless/ANPR") }
        if p.evCharging == true     { parts.append("EV charging") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Data source label shown to users.
    var sourceLabel: String {
        confidence == "parent_verified" ? "Verified by parents" : "Detailed info"
    }
}

// MARK: - Service

final class VenueEnrichmentService {
    static let shared = VenueEnrichmentService()

    private static let baseURL = "https://yugi-production.up.railway.app"

    private var inFlight: Set<String> = []
    private let lock = NSLock()

    private init() {}

    // MARK: - Public API

    /// Fetch web-enriched venue data asynchronously.
    /// Safe to call from anywhere — deduplicates concurrent requests for the same placeId.
    /// Always calls `completion` on the main thread. Returns `nil` on any failure.
    func fetchEnrichment(
        placeId: String,
        venueName: String,
        completion: @escaping (VenueEnrichmentResponse?) -> Void
    ) {
        lock.lock()
        guard !inFlight.contains(placeId) else { lock.unlock(); return }
        inFlight.insert(placeId)
        lock.unlock()

        guard var components = URLComponents(string: "\(Self.baseURL)/api/venues/\(placeId)/enrichment") else {
            deliver(placeId: placeId, result: nil, completion: completion)
            return
        }
        components.queryItems = [URLQueryItem(name: "venueName", value: venueName)]

        guard let url = components.url else {
            deliver(placeId: placeId, result: nil, completion: completion)
            return
        }

        EventTracker.shared.trackVenueEnrichmentRequested(placeId: placeId, venueName: venueName)

        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self else { return }
            if let error {
                print("VenueEnrichmentService: failed for \(placeId): \(error.localizedDescription)")
                self.deliver(placeId: placeId, result: nil, completion: completion)
                return
            }
            guard let data else {
                self.deliver(placeId: placeId, result: nil, completion: completion)
                return
            }
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            if let result = try? decoder.decode(VenueEnrichmentResponse.self, from: data) {
                print("VenueEnrichmentService: enrichment received for \(venueName), hasData=\(result.hasData)")
                self.deliver(placeId: placeId, result: result, completion: completion)
            } else {
                print("VenueEnrichmentService: decode failed for \(placeId)")
                self.deliver(placeId: placeId, result: nil, completion: completion)
            }
        }.resume()
    }

    private func deliver(
        placeId: String,
        result: VenueEnrichmentResponse?,
        completion: @escaping (VenueEnrichmentResponse?) -> Void
    ) {
        lock.lock(); inFlight.remove(placeId); lock.unlock()
        DispatchQueue.main.async { completion(result) }
    }
}
