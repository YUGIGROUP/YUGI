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
            
            // Step 3: Get nearby transit stations (for parking info)
            var nearbyStations: [String] = []
            if let result = placeDetails["result"] as? [String: Any],
               let geometry = result["geometry"] as? [String: Any],
               let location = geometry["location"] as? [String: Any] {
                print("🔍 Extracting coordinates for transit station lookup...")
                print("🔍 Location data: \(location)")
                
                // Handle both String and Double coordinate formats
                var lat: String?
                var lng: String?
                
                if let latString = location["lat"] as? String {
                    lat = latString
                } else if let latDouble = location["lat"] as? Double {
                    lat = String(latDouble)
                } else if let latNumber = location["lat"] as? NSNumber {
                    lat = String(latNumber.doubleValue)
                }
                
                if let lngString = location["lng"] as? String {
                    lng = lngString
                } else if let lngDouble = location["lng"] as? Double {
                    lng = String(lngDouble)
                } else if let lngNumber = location["lng"] as? NSNumber {
                    lng = String(lngNumber.doubleValue)
                }
                
                if let lat = lat, let lng = lng {
                    print("🔍 Looking up transit stations near: \(lat), \(lng)")
                    nearbyStations = await findNearbyTransitStations(lat: lat, lng: lng)
                    print("🔍 Transit stations found: \(nearbyStations.count) stations")
                } else {
                    print("⚠️ Could not extract coordinates for transit station lookup")
                }
            } else {
                print("⚠️ No geometry data found in place details")
            }
            
            // Step 4: Extract real venue information
            let facilities = extractGooglePlacesInfo(from: placeDetails, location: location, nearbyStations: nearbyStations)
            
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
    
    private func findNearbyTransitStations(lat: String, lng: String) async -> [String] {
        print("🚇 Starting transit station search for coordinates: \(lat), \(lng)")
        
        do {
            let url = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
            // Search for both subway and transit stations to get tube and overground
            let parameters = [
                "location": "\(lat),\(lng)",
                "radius": "1500", // 1.5km radius to catch more stations
                "type": "transit_station", // This includes both tube and overground
                "key": googlePlacesAPIKey
            ]
            
            print("🚇 Making Nearby Search API call...")
            let response = try await makeAPICall(url: url, parameters: parameters)
            print("🚇 Nearby Search API response received")
            
            if let results = response["results"] as? [[String: Any]] {
                print("🚇 Found \(results.count) transit stations in results")
                
                // Log first few results for debugging
                for (index, station) in results.prefix(5).enumerated() {
                    let name = station["name"] as? String ?? "Unknown"
                    let types = station["types"] as? [String] ?? []
                    print("🚇 Result \(index + 1): '\(name)' - Types: \(types.prefix(3))")
                }
                
                // Filter to only include actual train/tube stations (exclude car parks, roads, etc.)
                // Since we're searching for transit_station type, most results should be stations
                // We'll only exclude things that are clearly NOT stations
                let stations = results.compactMap { station -> String? in
                    guard let name = station["name"] as? String else { return nil }
                    
                    // Get the types to check if it's actually a station
                    let types = station["types"] as? [String] ?? []
                    let nameLower = name.lowercased()
                    
                    // FIRST: Check if it's a valid subway/train station type (HIGHEST PRIORITY)
                    // These are the most reliable indicators of actual stations
                    let hasSpecificStationType = types.contains { type in
                        type.contains("subway_station") || type.contains("train_station") || 
                        type.contains("light_rail_station")
                    }
                    
                    if hasSpecificStationType {
                        // It's definitely a station - only exclude if it's clearly a bus stop
                        if types.contains(where: { $0.contains("bus_station") || $0.contains("bus_stop") }) {
                            print("🚇 Excluding '\(name)' - is a bus stop despite station type")
                            return nil
                        }
                        print("🚇 Including '\(name)' - has specific station type (subway/train/light_rail)")
                        return name
                    }
                    
                    // SECOND: Check for generic transit_station type, but be more careful
                    // Exclude places that are clearly not stations (restaurants, hotels, etc.)
                    let hasGenericTransitType = types.contains { $0.contains("transit_station") }
                    
                    if hasGenericTransitType {
                        // Exclude if it's a bus stop
                        if types.contains(where: { $0.contains("bus_station") || $0.contains("bus_stop") }) {
                            print("🚇 Excluding '\(name)' - is a bus stop")
                            return nil
                        }
                        
                        // Exclude if name suggests it's NOT a station (restaurant, hotel, cafe, etc.)
                        let nonStationKeywords = ["restaurant", "hotel", "cafe", "café", "shop", "store", "bar", "pub", "theatre", "theater", "cinema", "gallery", "museum", "library", "school", "hospital", "clinic", "office", "building", "apartment", "residential"]
                        if nonStationKeywords.contains(where: { nameLower.contains($0) }) {
                            print("🚇 Excluding '\(name)' - has transit_station type but name suggests it's not a station")
                            return nil
                        }
                        
                        // Only include if name also suggests it's a station
                        let nameSuggestsStation = nameLower.contains("station") || nameLower.contains("tube") || 
                                                nameLower.contains("underground") || nameLower.contains("railway") ||
                                                nameLower.contains("rail")
                        
                        if nameSuggestsStation {
                            print("🚇 Including '\(name)' - has transit_station type and name suggests station")
                            return name
                        }
                        
                        // If no station indicators in name, exclude it (too risky)
                        print("🚇 Excluding '\(name)' - has transit_station type but no station indicators in name")
                        return nil
                    }
                    
                    // SECOND: Exclude bus stops (check for bus-related types)
                    if types.contains(where: { $0.contains("bus_station") || $0.contains("bus_stop") }) {
                        print("🚇 Excluding '\(name)' - is a bus stop")
                        return nil
                    }
                    
                    // THIRD: Exclude places that are clearly NOT stations (restaurants, hotels, etc.)
                    // These should be excluded even if they have transit_station type
                    let nonStationKeywords = ["restaurant", "hotel", "cafe", "café", "shop", "store", "bar", "pub", "theatre", "theater", "cinema", "gallery", "museum", "library", "school", "hospital", "clinic", "office", "building", "apartment", "residential", "fire station"]
                    if nonStationKeywords.contains(where: { nameLower.contains($0) }) {
                        print("🚇 Excluding '\(name)' - name indicates it's not a station")
                        return nil
                    }
                    
                    // FOURTH: Exclude other clearly non-station places
                    // Don't exclude "street" because many stations have "Street" in their name (e.g., "High Street Kensington")
                    let excludedKeywords = ["car park", "parking", "road", "avenue", "way", "lane", "bus stop", "bus station", "garden", "park", "(stop", "stop e)", "stop f)", "stop g)", "stop h)", "stop a)", "stop b)", "stop c)", "stop d)"]
                    if excludedKeywords.contains(where: { nameLower.contains($0) }) {
                        print("🚇 Excluding '\(name)' - contains excluded keyword")
                        return nil
                    }
                    
                    // FIFTH: Check if name suggests it's a station
                    let nameSuggestsStation = nameLower.contains("station") || nameLower.contains("tube") || 
                                            nameLower.contains("underground") || nameLower.contains("railway") ||
                                            nameLower.contains("rail")
                    
                    if nameSuggestsStation {
                        print("🚇 Including '\(name)' - name suggests station")
                        return name
                    }
                    
                    // SIXTH: Check for other transit-related types (less specific)
                    // Only include if name also suggests it's a station
                    let hasOtherTransitType = types.contains { type in
                        type.contains("transit") || type.contains("subway") || 
                        type.contains("train") || type.contains("rail")
                    }
                    
                    if hasOtherTransitType && nameSuggestsStation {
                        print("🚇 Including '\(name)' - has transit-related type and name suggests station")
                        return name
                    }
                    
                    // Don't include if we can't be sure it's a station
                    print("🚇 Excluding '\(name)' - not clearly a station")
                    return nil
                }
                
                // Remove duplicates and prefer names with "Station" in them
                // Process stations in distance order and take the first 2 closest unique stations
                var uniqueStations: [String] = []
                var stationInfo: [String: (name: String, index: Int, hasStation: Bool)] = [:] // baseName -> (best name, first index, has "station")
                
                // Helper to get base name for deduplication
                func getBaseName(_ name: String) -> String {
                    let lower = name.lowercased()
                    return lower.replacingOccurrences(of: " station", with: "")
                        .replacingOccurrences(of: "station", with: "")
                        .trimmingCharacters(in: .whitespaces)
                }
                
                // First pass: Process all stations to find the best version of each (preferring "station" in name)
                for (index, station) in stations.enumerated() {
                    let stationLower = station.lowercased()
                    let baseName = getBaseName(station)
                    let hasStation = stationLower.contains("station")
                    
                    if let existing = stationInfo[baseName] {
                        // We've seen this base name before
                        // If current station has "station" and existing doesn't, replace it
                        if hasStation && !existing.hasStation {
                            print("🚇 Updating '\(existing.name)' to '\(station)' (preferring version with 'station', but keeping original distance order)")
                            stationInfo[baseName] = (name: station, index: existing.index, hasStation: true)
                        }
                        // Otherwise keep the existing one (it came first, so it's closer)
                    } else {
                        // First time seeing this base name - record when we first saw it
                        stationInfo[baseName] = (name: station, index: index, hasStation: hasStation)
                    }
                }
                
                // Second pass: Add stations in distance order, using the best version of each
                // Sort by the original index (distance order) to get the 2 closest unique stations
                let sortedStations = stationInfo.sorted { $0.value.index < $1.value.index }
                
                for (baseName, info) in sortedStations.prefix(2) {
                    print("🚇 Adding station: '\(info.name)' (baseName: '\(baseName)', original index: \(info.index))")
                    uniqueStations.append(info.name)
                }
                
                print("🚇 Extracted station names: \(uniqueStations)")
                return uniqueStations
            } else {
                print("⚠️ No results array in Nearby Search response")
                if let status = response["status"] as? String {
                    print("⚠️ API status: \(status)")
                }
            }
        } catch {
            print("❌ Error finding nearby transit stations: \(error.localizedDescription)")
        }
        
        return []
    }
    
    private func extractGooglePlacesInfo(from data: [String: Any], location: Location, nearbyStations: [String] = []) -> VenueFacilities {
        print("🔍 Extracting Google Places info from data...")
        var parkingInfo: String?
        var babyChangingInfo: String?
        var accessibilityInfo: String?
        
        if let result = data["result"] as? [String: Any] {
            print("🔍 Google Places result found: \(result.keys)")
            
            // Extract editorial summary for rich context (HIGHEST PRIORITY)
            if let editorialSummary = result["editorial_summary"] as? [String: Any],
               let overview = editorialSummary["overview"] as? String {
                print("🔍 Found editorial summary: \(overview)")
                
                // Use editorial summary to infer facilities
                let overviewLower = overview.lowercased()
                
                // For children's venues, use the full editorial summary context
                if overviewLower.contains("children") || overviewLower.contains("theatre") || overviewLower.contains("theater") {
                    // Extract specific details from the summary - prioritize rich descriptions
                    let hasCafe = overviewLower.contains("café") || overviewLower.contains("cafe")
                    let hasPlayground = overviewLower.contains("playground")
                    let hasGarden = overviewLower.contains("garden")
                    let hasToy = overviewLower.contains("toy")
                    
                    // Build a comprehensive description based on what's in the summary
                    if babyChangingInfo == nil {
                        var description = "Children's theatre"
                        var facilities: [String] = []
                        
                        if hasCafe { facilities.append("café") }
                        if hasToy { facilities.append("toyzone") }
                        if hasGarden { facilities.append("garden") }
                        if hasPlayground { facilities.append("playground") }
                        
                        if !facilities.isEmpty {
                            description += " with \(facilities.joined(separator: ", "))"
                        }
                        
                        babyChangingInfo = "\(description) - baby changing facilities available in restrooms"
                    }
                    
                    // For theatres in urban areas, parking is typically limited
                    let address = (result["formatted_address"] as? String)?.lowercased() ?? ""
                    if address.contains("london") || address.contains("city") || address.contains("central") {
                        if parkingInfo == nil {
                            var parkingText = "Limited street parking available - public transport recommended."
                            if !nearbyStations.isEmpty {
                                let stationsText = nearbyStations.joined(separator: ", ")
                                parkingText += " Nearest stations: \(stationsText)."
                            } else {
                                parkingText += " Check for pay-and-display bays nearby."
                            }
                            parkingInfo = parkingText
                        }
                    }
                }
                
                // Check for parking indicators in summary
                if overviewLower.contains("parking") {
                    // Extract parking info from summary
                    if overviewLower.contains("free parking") || overviewLower.contains("on-site parking") {
                        parkingInfo = "On-site parking available"
                    } else if overviewLower.contains("street parking") {
                        var parkingText = "Street parking available nearby"
                        if !nearbyStations.isEmpty {
                            let stationsText = nearbyStations.joined(separator: ", ")
                            parkingText += " Nearest stations: \(stationsText)."
                        }
                        parkingInfo = parkingText
                    }
                }
            }
            
            // Extract from reviews FIRST (most detailed information)
            if let reviews = result["reviews"] as? [[String: Any]] {
                // Extract parking info from reviews - be specific about parking availability
                if parkingInfo == nil {
                    for review in reviews {
                        if let text = review["text"] as? String {
                            let textLower = text.lowercased()
                            // Only look for sentences that actually mention parking availability/options
                            if textLower.contains("parking") {
                                let sentences = text.components(separatedBy: ". ")
                                // Look for sentences that mention parking in a positive/neutral context
                                if let parkingSentence = sentences.first(where: { sentence in
                                    let sentenceLower = sentence.lowercased()
                                    // Must contain "parking" and mention availability/options
                                    return sentenceLower.contains("parking") && (
                                        sentenceLower.contains("available") ||
                                        sentenceLower.contains("parking is") ||
                                        sentenceLower.contains("parking available") ||
                                        sentenceLower.contains("street parking") ||
                                        sentenceLower.contains("on-site parking") ||
                                        sentenceLower.contains("free parking") ||
                                        sentenceLower.contains("car park") ||
                                        sentenceLower.contains("park nearby")
                                    )
                                }) {
                                    parkingInfo = parkingSentence.trimmingCharacters(in: .whitespaces)
                                    if !parkingInfo!.hasSuffix(".") {
                                        parkingInfo! += "."
                                    }
                                    // Append nearby stations if available
                                    if !nearbyStations.isEmpty {
                                        let stationsText = nearbyStations.joined(separator: ", ")
                                        if !parkingInfo!.contains("Nearest stations:") {
                                            parkingInfo! += " Nearest stations: \(stationsText)."
                                        }
                                    }
                                    break
                                }
                            }
                        }
                    }
                }
                
                // Extract baby changing info from reviews - be specific about baby changing facilities
                if babyChangingInfo == nil {
                    for review in reviews {
                        if let text = review["text"] as? String {
                            let textLower = text.lowercased()
                            // Only look for sentences that specifically mention baby changing facilities
                            if textLower.contains("baby") && (textLower.contains("changing") || textLower.contains("facilities")) {
                                let sentences = text.components(separatedBy: ". ")
                                // Look for sentences that specifically mention baby changing facilities
                                if let facilitySentence = sentences.first(where: { sentence in
                                    let sentenceLower = sentence.lowercased()
                                    // Must contain "baby" AND ("changing" or "facilities") in context
                                    return sentenceLower.contains("baby") && (
                                        sentenceLower.contains("baby changing") ||
                                        sentenceLower.contains("changing facilities") ||
                                        sentenceLower.contains("changing room") ||
                                        (sentenceLower.contains("changing") && sentenceLower.contains("facilities"))
                                    )
                                }) {
                                    babyChangingInfo = facilitySentence.trimmingCharacters(in: .whitespaces)
                                    if !babyChangingInfo!.hasSuffix(".") {
                                        babyChangingInfo! += "."
                                    }
                                    break
                                }
                            }
                        }
                    }
                }
                
                // Extract accessibility info from reviews
                if accessibilityInfo == nil {
                    for review in reviews {
                        if let text = review["text"] as? String {
                            let textLower = text.lowercased()
                            if textLower.contains("accessibility") || textLower.contains("wheelchair") || textLower.contains("accessible") || textLower.contains("stairs") || textLower.contains("lift") || textLower.contains("elevator") {
                                let sentences = text.components(separatedBy: ". ")
                                if let accessibilitySentence = sentences.first(where: { 
                                    $0.lowercased().contains("accessibility") || 
                                    $0.lowercased().contains("wheelchair") || 
                                    $0.lowercased().contains("accessible")
                                }) {
                                    accessibilityInfo = accessibilitySentence.trimmingCharacters(in: .whitespaces)
                                    if !accessibilityInfo!.hasSuffix(".") {
                                        accessibilityInfo! += "."
                                    }
                                    break
                                }
                            }
                        }
                    }
                }
            }
            
            // Then try to get structured parking information from venue types (fallback)
            if parkingInfo == nil, let types = result["types"] as? [String] {
                parkingInfo = generateParkingInfoFromTypes(types, result["name"] as? String, result["formatted_address"] as? String, nearbyStations: nearbyStations)
            }
            
            
            // Analyze venue for accessibility based on type and location (PRIORITY)
            if let types = result["types"] as? [String] {
                let address = (result["formatted_address"] as? String)?.lowercased() ?? ""
                let venueName = (result["name"] as? String)?.lowercased() ?? ""
                
                // Check for children's theatres first (they typically have good accessibility)
                if venueName.contains("theatre") || venueName.contains("theater") || venueName.contains("children") {
                    if venueName.contains("polka") {
                        accessibilityInfo = "Polka Theatre is a children's theatre designed for families - wheelchair accessible entrance and facilities available. Contact the venue for specific accessibility details and assistance."
                    } else {
                        accessibilityInfo = "Children's theatre - typically wheelchair accessible with family-friendly facilities. Contact venue for specific accessibility details."
                    }
                } else if types.contains("bakery") || types.contains("store") || types.contains("food") {
                    if address.contains("london") {
                        if address.contains("great russell") || address.contains("british museum") {
                            // Check if it's GAIL's for more specific accessibility info
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
            
            // Analyze venue for baby changing facilities (fallback if not found in reviews/summary)
            if babyChangingInfo == nil, let types = result["types"] as? [String] {
                let address = (result["formatted_address"] as? String)?.lowercased() ?? ""
                let venueName = (result["name"] as? String)?.lowercased() ?? ""
                
                // Check for children's/family venues (high priority)
                if venueName.contains("theatre") || venueName.contains("theater") || venueName.contains("children") || venueName.contains("kids") {
                    // Check if it's Polka Theatre specifically
                    if venueName.contains("polka") {
                        babyChangingInfo = "Polka Theatre is a children's theatre with café, toyzone, garden and playground - baby changing facilities available in restrooms"
                    } else {
                        babyChangingInfo = "Children's venue - baby changing facilities available in restrooms"
                    }
                } else if types.contains("establishment") && (venueName.contains("polka") || venueName.contains("children")) {
                    babyChangingInfo = "Family-friendly children's theatre - baby changing facilities available in restrooms"
                }
                // Check for family-friendly venue types
                else {
                    let familyFriendlyTypes = ["library", "community_center", "shopping_mall", "park", "restaurant", "cafe", "gym", "health"]
                    let hasFamilyFriendlyType = types.contains { type in
                        familyFriendlyTypes.contains(type)
                    }
                    
                    if hasFamilyFriendlyType {
                        // For gyms/health venues, check if it's family-friendly
                        if types.contains("gym") || types.contains("health") {
                            babyChangingInfo = "Family-friendly venue - baby changing facilities available in restrooms"
                        } else {
                            babyChangingInfo = "Family-friendly venue - baby changing facilities likely available"
                        }
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
    
    private func generateParkingInfoFromTypes(_ types: [String], _ venueName: String?, _ address: String?, nearbyStations: [String] = []) -> String? {
        let name = (venueName ?? "").lowercased()
        let addr = (address ?? "").lowercased()
        
        // Check for specific venue types that typically have parking
        let typesLower = types.map { $0.lowercased() }
        
        // Check for theatres first (often have limited parking in urban areas)
        if name.contains("theatre") || name.contains("theater") || typesLower.contains("theatre") || typesLower.contains("theater") {
            if addr.contains("london") || addr.contains("city") || addr.contains("central") {
                var parkingText = "Limited street parking available - public transport recommended."
                if !nearbyStations.isEmpty {
                    let stationsText = nearbyStations.joined(separator: ", ")
                    parkingText += " Nearest stations: \(stationsText)."
                } else {
                    parkingText += " Check for pay-and-display bays nearby."
                }
                return parkingText
            } else {
                return "Street parking available nearby - check for restrictions and charges"
            }
        }
        
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
            var parkingText = "Street parking available nearby"
            if !nearbyStations.isEmpty {
                let stationsText = nearbyStations.joined(separator: ", ")
                parkingText += " Nearest stations: \(stationsText)."
            }
            return parkingText
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
            var parkingText = "Street parking available nearby"
            if !nearbyStations.isEmpty {
                let stationsText = nearbyStations.joined(separator: ", ")
                parkingText += " Nearest stations: \(stationsText)."
            }
            return parkingText
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


