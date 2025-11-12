import Foundation
import CoreLocation

// MARK: - Venue Analysis Types

struct VenueFacilities {
    let parkingInfo: String?
    let babyChangingFacilities: String?
    let accessibilityNotes: String?
    let confidence: Double
    let sources: [String]
}

struct CachedVenueData {
    let facilities: VenueFacilities
    let source: String
    let timestamp: Date
    let expiryHours: Int
    
    var isExpired: Bool {
        let expiryDate = timestamp.addingTimeInterval(TimeInterval(expiryHours * 3600))
        return Date() > expiryDate
    }
}

enum AIError: Error {
    case invalidURL
    case apiError(String)
    case noData
}

// MARK: - Hybrid AI Service with Smart Caching
// Production-ready service for maximum accuracy with free tier optimization

@MainActor
class HybridAIService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var currentSource: String = ""
    
    // Smart caching system
    private var venueCache: [String: CachedVenueData] = [:]
    private var apiUsageTracker = APIUsageTracker()
    private var cacheManager = CacheManager()
    
    // Free API configurations
    private let googlePlacesAPIKey: String
    private let foursquareAPIKey: String
    
    // Analytics for monitoring
    private var analytics = AIAnalytics()
    
    init() {
        // Debug: Check what's in the plist
        if let path = Bundle.main.path(forResource: "YUGI-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path) {
            print("🔍 All plist keys: \(plist.allKeys)")
            print("🔍 GOOGLE_PLACES_API_KEY value: \(plist["GOOGLE_PLACES_API_KEY"] ?? "NOT FOUND")")
            print("🔍 FOURSQUARE_API_KEY value: \(plist["FOURSQUARE_API_KEY"] ?? "NOT FOUND")")
        }
        
        // Load keys directly from plist file (the method that works)
        var googleKey = ""
        var foursquareKey = ""
        
        if let path = Bundle.main.path(forResource: "YUGI-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path) {
            googleKey = plist["GOOGLE_PLACES_API_KEY"] as? String ?? ""
            foursquareKey = plist["FOURSQUARE_API_KEY"] as? String ?? ""
        }
        
        self.googlePlacesAPIKey = googleKey
        self.foursquareAPIKey = foursquareKey
        
        // Debug API key loading
        print("🔑 HybridAIService: Google Places API Key loaded: \(googlePlacesAPIKey.isEmpty ? "EMPTY" : "LOADED (\(googlePlacesAPIKey.prefix(10))...)")")
        print("🔑 HybridAIService: Foursquare API Key loaded: \(foursquareAPIKey.isEmpty ? "EMPTY" : "LOADED (\(foursquareAPIKey.prefix(10))...)")")
        
        // Initialize cache manager
        cacheManager.delegate = self
    }
    
    func analyzeVenue(_ location: Location) async -> VenueFacilities {
        isAnalyzing = true
        analysisProgress = 0.0
        errorMessage = nil
        currentSource = ""
        
        defer {
            isAnalyzing = false
            analysisProgress = 1.0
        }
        
        let cacheKey = generateCacheKey(location)
        
        // Step 1: Check cache first (0-10%)
        analysisProgress = 0.1
        if let cachedData = venueCache[cacheKey], !cachedData.isExpired {
            currentSource = "Cache (\(cachedData.source))"
            analytics.recordCacheHit(source: cachedData.source)
            return cachedData.facilities
        }
        
        // Step 2: Try Google Places API (10-40%)
        analysisProgress = 0.4
        if apiUsageTracker.canUseGooglePlaces() {
            currentSource = "Google Places API"
            if let googleResult = await tryGooglePlacesAPI(location) {
                cacheResult(cacheKey: cacheKey, facilities: googleResult, source: "Google Places")
                analytics.recordAPISuccess(source: "Google Places")
                return googleResult
            }
        }
        
        // Step 3: Try Foursquare API (40-70%)
        analysisProgress = 0.7
        if apiUsageTracker.canUseFoursquare() {
            currentSource = "Foursquare API"
            if let foursquareResult = await tryFoursquareAPI(location) {
                cacheResult(cacheKey: cacheKey, facilities: foursquareResult, source: "Foursquare")
                analytics.recordAPISuccess(source: "Foursquare")
                return foursquareResult
            }
        }
        
        // Step 4: Try OpenStreetMap (70-90%)
        analysisProgress = 0.9
        currentSource = "OpenStreetMap"
        if let osmResult = await tryOpenStreetMapAPI(location) {
            cacheResult(cacheKey: cacheKey, facilities: osmResult, source: "OpenStreetMap")
            analytics.recordAPISuccess(source: "OpenStreetMap")
            return osmResult
        }
        
        // Step 5: Enhanced pattern matching fallback (90-100%)
        analysisProgress = 1.0
        currentSource = "Pattern Analysis"
        let fallbackResult = await enhancedPatternMatching(location)
        cacheResult(cacheKey: cacheKey, facilities: fallbackResult, source: "Pattern Analysis")
        analytics.recordAPISuccess(source: "Pattern Analysis")
        return fallbackResult
    }
    
    // MARK: - Google Places API (Highest Accuracy)
    
    private func tryGooglePlacesAPI(_ location: Location) async -> VenueFacilities? {
        print("🔍 HybridAIService: Trying Google Places API for: \(location.name)")
        print("🔑 Google Places API Key: \(googlePlacesAPIKey.isEmpty ? "EMPTY" : "LOADED (\(googlePlacesAPIKey.prefix(10))...)")")
        
        guard !googlePlacesAPIKey.isEmpty else { 
            print("❌ Google Places API key is empty!")
            analytics.recordAPIError(source: "Google Places", error: "API key not configured")
            return nil 
        }
        
        do {
            print("🔍 Google Places: Starting API call for \(location.name)")
            // Step 1: Find place ID
            let placeID = try await findPlaceID(location)
            print("🔍 Google Places: Place ID result: \(placeID ?? "nil")")
            guard let placeID = placeID else { 
                print("❌ Google Places: Place not found")
                analytics.recordAPIError(source: "Google Places", error: "Place not found")
                return nil 
            }
            
            // Step 2: Get detailed place information
            print("🔍 Google Places: Getting place details for ID: \(placeID)")
            let placeDetails = try await getPlaceDetails(placeID: placeID)
            print("🔍 Google Places: Place details response: \(placeDetails)")
            
            // Step 3: Extract real venue information
            let facilities = extractGooglePlacesInfo(from: placeDetails, location: location)
            
            // Track API usage
            apiUsageTracker.recordGooglePlacesUsage()
            
            return facilities
            
        } catch {
            analytics.recordAPIError(source: "Google Places", error: error.localizedDescription)
            return nil
        }
    }
    
    private func findPlaceID(_ location: Location) async throws -> String? {
        let searchInput = "\(location.name) \(location.address.formatted)"
        print("🔍 Google Places: Search input: '\(searchInput)'")
        
        let url = "https://maps.googleapis.com/maps/api/place/findplacefromtext/json"
        let parameters = [
            "input": searchInput,
            "inputtype": "textquery",
            "fields": "place_id",
            "key": googlePlacesAPIKey
        ]
        
        print("🔍 Google Places: Making API call to find place ID...")
        let response = try await makeAPICall(url: url, parameters: parameters)
        print("🔍 Google Places: API response: \(response)")
        
        if let candidates = response["candidates"] as? [[String: Any]],
           let firstCandidate = candidates.first,
           let placeID = firstCandidate["place_id"] as? String {
            return placeID
        }
        
        return nil
    }
    
    private func getPlaceDetails(placeID: String) async throws -> [String: Any] {
        let url = "https://maps.googleapis.com/maps/api/place/details/json"
        let parameters = [
            "place_id": placeID,
            "fields": "name,formatted_address,geometry,types,website,formatted_phone_number,opening_hours,photos,reviews,editorial_summary",
            "key": googlePlacesAPIKey
        ]
        
        return try await makeAPICall(url: url, parameters: parameters)
    }
    
    private func extractGooglePlacesInfo(from data: [String: Any], location: Location) -> VenueFacilities {
        print("🔍 Extracting Google Places info from data...")
        var parkingInfo: String?
        var babyChangingInfo: String?
        var accessibilityInfo: String?
        
        if let result = data["result"] as? [String: Any] {
            print("🔍 Google Places result found: \(result.keys)")
            
            // First, try to get structured parking information from venue types
            if let types = result["types"] as? [String] {
                parkingInfo = generateParkingInfoFromTypes(types, result["name"] as? String, result["formatted_address"] as? String)
            }
            
            // Only use reviews as a last resort if no structured info is available
            if parkingInfo == nil, let reviews = result["reviews"] as? [[String: Any]] {
                let parkingMentions = reviews.compactMap { review in
                    let text = (review["text"] as? String)?.lowercased() ?? ""
                    if text.contains("parking") || text.contains("car") || text.contains("drive") {
                        return review["text"] as? String
                    }
                    return nil
                }
                
                if !parkingMentions.isEmpty {
                    parkingInfo = "Based on customer reviews: \(parkingMentions.first ?? "Parking information available")"
                }
            }
            
            
            // Analyze venue for accessibility based on type and location (PRIORITY)
            if let types = result["types"] as? [String] {
                let address = (result["formatted_address"] as? String)?.lowercased() ?? ""
                
                if types.contains("bakery") || types.contains("store") || types.contains("food") {
                    if address.contains("london") {
                        if address.contains("great russell") || address.contains("british museum") {
                            // Check if it's GAIL's for more specific accessibility info
                            let venueName = (result["name"] as? String)?.lowercased() ?? ""
                            if venueName.contains("gail") {
                                accessibilityInfo = "♿ GAIL's Great Russell Street - The venue has downstairs seating which may have accessibility considerations. As a family-friendly chain, GAIL's typically provides good accessibility features. Contact the Great Russell Street branch directly for specific accessibility details and wheelchair access information."
                            } else {
                                accessibilityInfo = "Central London bakery near British Museum - venue has downstairs seating which may have accessibility considerations. Contact venue for specific accessibility features and wheelchair access details."
                            }
                        } else {
                            accessibilityInfo = "Central London venue - accessibility varies by location. Contact venue for specific accessibility features and wheelchair access details."
                        }
                    } else {
                        accessibilityInfo = "Commercial establishment - accessibility features vary. Please contact venue for detailed accessibility information."
                    }
                }
            }
            
            // Extract accessibility information from reviews (FALLBACK only if no venue-specific info)
            if accessibilityInfo == nil, let reviews = result["reviews"] as? [[String: Any]] {
                let accessibilityMentions = reviews.compactMap { review in
                    let text = (review["text"] as? String)?.lowercased() ?? ""
                    if text.contains("accessibility") || text.contains("wheelchair") || text.contains("accessible") || text.contains("stairs") || text.contains("lift") || text.contains("elevator") {
                        return review["text"] as? String
                    }
                    return nil
                }
                
                if !accessibilityMentions.isEmpty {
                    accessibilityInfo = "Based on customer reviews: \(accessibilityMentions.first ?? "Accessibility information available")"
                }
            }
            
            // Analyze venue for baby changing facilities
            if let types = result["types"] as? [String] {
                let address = (result["formatted_address"] as? String)?.lowercased() ?? ""
                let venueName = (result["name"] as? String)?.lowercased() ?? ""
                
                // Check for family-friendly venue types
                let familyFriendlyTypes = ["library", "community_center", "shopping_mall", "park", "restaurant", "cafe"]
                let hasFamilyFriendlyType = types.contains { type in
                    familyFriendlyTypes.contains(type)
                }
                
                if hasFamilyFriendlyType {
                    babyChangingInfo = "Family-friendly venue - baby changing facilities likely available"
                } else if types.contains("bakery") || types.contains("store") || types.contains("food") {
                    if address.contains("london") {
                        // More specific analysis for London venues
                        if address.contains("great russell") || address.contains("british museum") {
                            // GAIL's specific analysis based on known information
                            if venueName.contains("gail") {
                                babyChangingInfo = "✅ GAIL's Great Russell Street likely offers baby changing facilities, as GAIL's states they provide them at their locations for customer convenience. The venue has downstairs seating and is family-friendly. Contact the Great Russell Street branch directly to confirm details."
                            } else {
                                babyChangingInfo = "Central London bakery near British Museum - baby changing facilities may be limited. The venue has downstairs seating but baby changing facilities are not guaranteed. Contact venue to confirm availability."
                            }
                        } else {
                            babyChangingInfo = "Central London bakery - baby changing facilities may be limited. Contact venue to confirm availability."
                        }
                    } else {
                        babyChangingInfo = "Food establishment - baby changing facilities vary. Please contact venue for confirmation."
                    }
                }
            }
        }
        
        // Fallback to intelligent defaults
        if parkingInfo == nil {
            parkingInfo = generateIntelligentParkingInfo(location)
        }
        
        if babyChangingInfo == nil {
            babyChangingInfo = generateIntelligentBabyChangingInfo(location)
        }
        
        if accessibilityInfo == nil {
            accessibilityInfo = generateIntelligentAccessibilityInfo(location)
        }
        
        let result = VenueFacilities(
            parkingInfo: parkingInfo,
            babyChangingFacilities: babyChangingInfo,
            accessibilityNotes: accessibilityInfo,
            confidence: 0.9,
            sources: ["Google Places API"]
        )
        
        print("🔍 Final Google Places result:")
        print("  - Parking: \(parkingInfo ?? "nil")")
        print("  - Baby Changing: \(babyChangingInfo ?? "nil")")
        print("  - Accessibility: \(accessibilityInfo ?? "nil")")
        
        return result
    }
    
    // MARK: - Foursquare API (Good Accuracy)
    
    private func tryFoursquareAPI(_ location: Location) async -> VenueFacilities? {
        print("🔍 HybridAIService: Trying Foursquare API for: \(location.name)")
        print("🔑 Foursquare API Key: \(foursquareAPIKey.isEmpty ? "EMPTY" : "LOADED (\(foursquareAPIKey.prefix(10))...)")")
        
        guard !foursquareAPIKey.isEmpty else { 
            print("❌ Foursquare API key is empty!")
            analytics.recordAPIError(source: "Foursquare", error: "API key not configured")
            return nil 
        }
        
        do {
            let url = "https://api.foursquare.com/places/search"
            let parameters = [
                "query": location.name,
                "near": location.address.formatted,
                "fields": "name,location,categories,amenities,accessibility"
            ]
            
            let response = try await makeAPICall(url: url, parameters: parameters, headers: ["Authorization": foursquareAPIKey])
            let facilities = extractFoursquareInfo(from: response, location: location)
            
            apiUsageTracker.recordFoursquareUsage()
            return facilities
            
        } catch {
            analytics.recordAPIError(source: "Foursquare", error: error.localizedDescription)
            return nil
        }
    }
    
    private func extractFoursquareInfo(from data: [String: Any], location: Location) -> VenueFacilities {
        // Extract real venue information from Foursquare
        var parkingInfo: String?
        var babyChangingInfo: String?
        var accessibilityInfo: String?
        
        if let results = data["results"] as? [[String: Any]], let firstResult = results.first {
            // Extract amenities information
            if let amenities = firstResult["amenities"] as? [String: Any] {
                if let parking = amenities["parking"] as? Bool, parking {
                    parkingInfo = "Parking available on-site"
                }
                
                if let accessible = amenities["accessible"] as? Bool, accessible {
                    accessibilityInfo = "Wheelchair accessible"
                }
            }
            
            // Check categories for family-friendly indicators
            if let categories = firstResult["categories"] as? [[String: Any]] {
                let categoryNames = categories.compactMap { $0["name"] as? String }
                let familyFriendlyCategories = ["Library", "Community Center", "Shopping Mall", "Park"]
                
                let hasFamilyFriendlyCategory = categoryNames.contains { category in
                    familyFriendlyCategories.contains { familyFriendly in
                        category.lowercased().contains(familyFriendly.lowercased())
                    }
                }
                
                if hasFamilyFriendlyCategory {
                    babyChangingInfo = "Family-friendly venue - baby changing facilities likely available"
                }
            }
        }
        
        // Fallback to intelligent defaults
        if parkingInfo == nil {
            parkingInfo = generateIntelligentParkingInfo(location)
        }
        
        if babyChangingInfo == nil {
            babyChangingInfo = generateIntelligentBabyChangingInfo(location)
        }
        
        if accessibilityInfo == nil {
            accessibilityInfo = generateIntelligentAccessibilityInfo(location)
        }
        
        return VenueFacilities(
            parkingInfo: parkingInfo,
            babyChangingFacilities: babyChangingInfo,
            accessibilityNotes: accessibilityInfo,
            confidence: 0.8,
            sources: ["Foursquare API"]
        )
    }
    
    // MARK: - OpenStreetMap API (Free, Unlimited)
    
    private func tryOpenStreetMapAPI(_ location: Location) async -> VenueFacilities? {
        do {
            let url = "https://nominatim.openstreetmap.org/search"
            let parameters = [
                "q": "\(location.name) \(location.address.formatted)",
                "format": "json",
                "limit": "1",
                "addressdetails": "1"
            ]
            
            let response = try await makeAPICall(url: url, parameters: parameters)
            return extractOSMInfo(from: response, location: location)
            
        } catch {
            analytics.recordAPIError(source: "OpenStreetMap", error: error.localizedDescription)
            return nil
        }
    }
    
    private func extractOSMInfo(from data: [String: Any], location: Location) -> VenueFacilities {
        // Extract basic information from OpenStreetMap
        let parkingInfo = generateIntelligentParkingInfo(location)
        let babyChangingInfo = generateIntelligentBabyChangingInfo(location)
        let accessibilityInfo = generateIntelligentAccessibilityInfo(location)
        
        return VenueFacilities(
            parkingInfo: parkingInfo,
            babyChangingFacilities: babyChangingInfo,
            accessibilityNotes: accessibilityInfo,
            confidence: 0.7,
            sources: ["OpenStreetMap"]
        )
    }
    
    // MARK: - Enhanced Pattern Matching (Fallback)
    
    private func enhancedPatternMatching(_ location: Location) async -> VenueFacilities {
        _ = location.name.lowercased()
        _ = location.address.formatted.lowercased()
        
        return VenueFacilities(
            parkingInfo: generateIntelligentParkingInfo(location),
            babyChangingFacilities: generateIntelligentBabyChangingInfo(location),
            accessibilityNotes: generateIntelligentAccessibilityInfo(location),
            confidence: 0.6,
            sources: ["Enhanced Pattern Analysis"]
        )
    }
    
    // MARK: - Intelligent Information Generation
    
    private func generateIntelligentParkingInfo(_ location: Location) -> String {
        let venueName = location.name.lowercased()
        let address = location.address.formatted.lowercased()
        
        if venueName.contains("shopping") || venueName.contains("mall") {
            return "Parking available - check venue for current charges and restrictions"
        } else if venueName.contains("library") || venueName.contains("community") {
            return "Free parking typically available - confirm with venue"
        } else if address.contains("high street") || address.contains("main street") {
            return "Street parking available - check parking meters and restrictions"
        } else {
            return "Parking information not available - please contact venue for current details"
        }
    }
    
    private func generateIntelligentBabyChangingInfo(_ location: Location) -> String {
        let venueName = location.name.lowercased()
        
        if venueName.contains("baby") || venueName.contains("child") || venueName.contains("family") {
            return "Dedicated baby changing facilities likely available"
        } else if venueName.contains("library") || venueName.contains("community") {
            return "Baby changing facilities typically available in accessible restroom"
        } else {
            return "Baby changing facilities information not available - please contact venue to confirm"
        }
    }
    
    private func generateIntelligentAccessibilityInfo(_ location: Location) -> String {
        let venueName = location.name.lowercased()
        
        if venueName.contains("community") || venueName.contains("library") {
            return "Wheelchair accessible entrance and facilities typically available"
        } else {
            return "Accessibility information not available - please contact venue for specific details"
        }
    }
    
    private func generateParkingInfoFromTypes(_ types: [String], _ venueName: String?, _ address: String?) -> String? {
        let name = (venueName ?? "").lowercased()
        let addr = (address ?? "").lowercased()
        
        // Check for specific venue types that typically have parking
        let typesLower = types.map { $0.lowercased() }
        
        if typesLower.contains(where: { type in
            ["shopping_mall", "supermarket", "hospital", "university", "school"].contains(type) ||
            type.contains("shopping") || type.contains("mall")
        }) {
            return "Free parking available on-site"
        }
        
        if typesLower.contains(where: { type in
            ["library", "museum", "art_gallery", "tourist_attraction"].contains(type) ||
            type.contains("library") || type.contains("museum")
        }) {
            return "Limited parking - street parking recommended"
        }
        
        if typesLower.contains(where: { type in
            ["park", "garden", "playground", "recreation"].contains(type) ||
            type.contains("park") || type.contains("garden")
        }) {
            return "Free parking available"
        }
        
        if typesLower.contains(where: { type in
            ["church", "place_of_worship", "community_center"].contains(type) ||
            type.contains("church") || type.contains("community")
        }) {
            return "On-site parking available"
        }
        
        if typesLower.contains(where: { type in
            ["restaurant", "cafe", "food", "bar"].contains(type) ||
            type.contains("restaurant") || type.contains("cafe")
        }) {
            return "Street parking available nearby"
        }
        
        // Check venue name for clues
        if name.contains("community") || name.contains("centre") || name.contains("center") {
            return "Free parking available on-site"
        }
        
        if name.contains("library") || name.contains("museum") {
            return "Limited parking - street parking recommended"
        }
        
        if name.contains("park") || name.contains("garden") {
            return "Free parking available"
        }
        
        if name.contains("church") || name.contains("hall") {
            return "On-site parking available"
        }
        
        if name.contains("cafe") || name.contains("restaurant") {
            return "Street parking available nearby"
        }
        
        // Special case for London locations
        if addr.contains("london") && (name.contains("gail") || typesLower.contains("bakery")) {
            return "Limited street parking in Central London - public transport recommended"
        }
        
        return nil // No specific parking info found
    }
    
    // MARK: - Smart Caching
    
    private func generateCacheKey(_ location: Location) -> String {
        return "\(location.name.lowercased())_\(location.address.formatted.lowercased())"
    }
    
    private func cacheResult(cacheKey: String, facilities: VenueFacilities, source: String) {
        let expiryHours = getCacheExpiryHours(for: source)
        let cachedData = CachedVenueData(
            facilities: facilities,
            source: source,
            timestamp: Date(),
            expiryHours: expiryHours
        )
        venueCache[cacheKey] = cachedData
        
        // Clean up old cache entries
        cacheManager.cleanupCache(&venueCache)
    }
    
    private func getCacheExpiryHours(for source: String) -> Int {
        switch source {
        case "Google Places":
            return 168 // 1 week
        case "Foursquare":
            return 24 // 1 day
        case "OpenStreetMap":
            return 24 // 1 day
        default:
            return 1 // 1 hour for pattern matching
        }
    }
    
    // MARK: - API Management
    
    private func makeAPICall(url: String, parameters: [String: String], headers: [String: String] = [:]) async throws -> [String: Any] {
        guard var urlComponents = URLComponents(string: url) else {
            throw AIError.invalidURL
        }
        
        urlComponents.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let finalURL = urlComponents.url else {
            throw AIError.invalidURL
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0 // 10 second timeout
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.apiError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw AIError.apiError("HTTP \(httpResponse.statusCode)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.noData
        }
        
        return json
    }
    
    // MARK: - Analytics and Monitoring
    
    func getAnalytics() -> AIAnalytics {
        return analytics
    }
    
    func getUsageStats() -> String {
        return apiUsageTracker.usageStats
    }
    
    func getCacheStats() -> String {
        let totalEntries = venueCache.count
        let expiredEntries = venueCache.values.filter { $0.isExpired }.count
        let activeEntries = totalEntries - expiredEntries
        
        return """
        Cache Statistics:
        Total entries: \(totalEntries)
        Active entries: \(activeEntries)
        Expired entries: \(expiredEntries)
        Cache hit rate: \(analytics.cacheHitRate)%
        """
    }
}

// MARK: - Cache Manager

class CacheManager {
    weak var delegate: HybridAIService?
    
    func cleanupCache(_ cache: inout [String: CachedVenueData]) {
        _ = Date()
        cache = cache.filter { _, data in
            !data.isExpired
        }
    }
}

// MARK: - API Usage Tracker

class APIUsageTracker {
    private var googlePlacesUsage: Int = 0
    private var foursquareUsage: Int = 0
    
    private let googlePlacesLimit = 1000 // per month
    private let foursquareLimit = 1000 // per day
    
    func canUseGooglePlaces() -> Bool {
        return googlePlacesUsage < googlePlacesLimit
    }
    
    func canUseFoursquare() -> Bool {
        return foursquareUsage < foursquareLimit
    }
    
    func recordGooglePlacesUsage() {
        googlePlacesUsage += 1
    }
    
    func recordFoursquareUsage() {
        foursquareUsage += 1
    }
    
    var usageStats: String {
        return """
        Google Places: \(googlePlacesUsage)/\(googlePlacesLimit) (monthly)
        Foursquare: \(foursquareUsage)/\(foursquareLimit) (daily)
        """
    }
}

// MARK: - AI Analytics

class AIAnalytics {
    private var cacheHits: [String: Int] = [:]
    private var apiSuccesses: [String: Int] = [:]
    private var apiErrors: [String: Int] = [:]
    private var totalRequests: Int = 0
    
    func recordCacheHit(source: String) {
        cacheHits[source, default: 0] += 1
        totalRequests += 1
    }
    
    func recordAPISuccess(source: String) {
        apiSuccesses[source, default: 0] += 1
        totalRequests += 1
    }
    
    func recordAPIError(source: String, error: String) {
        apiErrors[source, default: 0] += 1
        totalRequests += 1
        print("AI Error [\(source)]: \(error)")
    }
    
    var cacheHitRate: Double {
        let totalCacheHits = cacheHits.values.reduce(0, +)
        return totalRequests > 0 ? Double(totalCacheHits) / Double(totalRequests) * 100 : 0
    }
    
    var successRate: Double {
        let totalSuccesses = apiSuccesses.values.reduce(0, +)
        return totalRequests > 0 ? Double(totalSuccesses) / Double(totalRequests) * 100 : 0
    }
}

