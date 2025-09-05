import Foundation
import CoreLocation

// MARK: - AI Venue Data Service

@MainActor
class AIVenueDataService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisProgress: Double = 0.0
    
    private let openAIClient: OpenAIClient
    private let googlePlacesClient: GooglePlacesClient
    
    init() {
        self.openAIClient = OpenAIClient()
        self.googlePlacesClient = GooglePlacesClient()
    }
    
    func gatherVenueFacilities(for location: Location) async -> VenueFacilities {
        isAnalyzing = true
        analysisProgress = 0.0
        
        defer {
            isAnalyzing = false
            analysisProgress = 1.0
        }
        
        var allInsights: [FacilityInsight] = []
        
        // 1. Google Places Analysis (30%)
        analysisProgress = 0.3
        let placesInsights = await analyzeGooglePlaces(location)
        allInsights.append(placesInsights)
        
        // 2. Web Scraping Analysis (60%)
        analysisProgress = 0.6
        if let website = await findVenueWebsite(location) {
            let webInsights = await analyzeWebsite(website, venueName: location.name)
            allInsights.append(webInsights)
        }
        
        // 3. Review Analysis (90%)
        analysisProgress = 0.9
        let reviewInsights = await analyzeReviews(location.name, address: location.address.formatted)
        allInsights.append(reviewInsights)
        
        // 4. Consolidate and return (100%)
        analysisProgress = 1.0
        return await consolidateInsights(allInsights, originalLocation: location)
    }
    
    private func analyzeGooglePlaces(_ location: Location) async -> FacilityInsight {
        do {
            let placeDetails = try await googlePlacesClient.searchNearby(
                query: location.name,
                location: CLLocation(latitude: location.coordinates.latitude, longitude: location.coordinates.longitude)
            )
            
            let prompt = """
            Analyze this Google Places data for a venue called "\(location.name)" at \(location.address.formatted):
            
            Place Details: \(placeDetails.description)
            
            Extract and return ONLY:
            1. Parking information (free, paid, street, on-site, etc.)
            2. Baby changing facilities (dedicated room, bathroom table, etc.)
            3. Accessibility features
            
            Format as JSON:
            {
                "parkingInfo": "description",
                "babyChangingFacilities": "description", 
                "accessibilityNotes": "description",
                "confidence": 0.0-1.0
            }
            """
            
            let analysis = try await openAIClient.analyze(prompt: prompt)
            return FacilityInsight(
                source: "Google Places",
                parkingInfo: analysis.parkingInfo,
                babyChangingFacilities: analysis.babyChangingFacilities,
                accessibilityNotes: analysis.accessibilityNotes,
                confidence: analysis.confidence
            )
        } catch {
            return FacilityInsight(source: "Google Places", error: error)
        }
    }
    
    private func findVenueWebsite(_ location: Location) async -> String? {
        let prompt = """
        Find the official website for this venue:
        Name: \(location.name)
        Address: \(location.address.formatted)
        
        Return only the website URL, or "not found" if no website is available.
        """
        
        do {
            let url = try await openAIClient.extractURL(prompt: prompt)
            return url != "not found" ? url : nil
        } catch {
            return nil
        }
    }
    
    private func analyzeWebsite(_ website: String, venueName: String) async -> FacilityInsight {
        do {
            let websiteContent = try await scrapeWebsite(url: website)
            
            let prompt = """
            Analyze this venue website content for "\(venueName)":
            
            Website Content: \(websiteContent)
            
            Extract and return ONLY:
            1. Parking information (free, paid, street, on-site, etc.)
            2. Baby changing facilities (dedicated room, bathroom table, etc.)
            3. Accessibility features
            
            Format as JSON:
            {
                "parkingInfo": "description",
                "babyChangingFacilities": "description",
                "accessibilityNotes": "description", 
                "confidence": 0.0-1.0
            }
            """
            
            let analysis = try await openAIClient.analyze(prompt: prompt)
            return FacilityInsight(
                source: "Website Analysis",
                parkingInfo: analysis.parkingInfo,
                babyChangingFacilities: analysis.babyChangingFacilities,
                accessibilityNotes: analysis.accessibilityNotes,
                confidence: analysis.confidence
            )
        } catch {
            return FacilityInsight(source: "Website Analysis", error: error)
        }
    }
    
    private func analyzeReviews(_ venueName: String, address: String) async -> FacilityInsight {
        do {
            let reviews = try await fetchReviews(venueName: venueName, address: address)
            
            let prompt = """
            Analyze these reviews for venue "\(venueName)" at \(address):
            
            Reviews: \(reviews)
            
            Extract mentions of:
            1. Parking information (free, paid, street, on-site, etc.)
            2. Baby changing facilities (dedicated room, bathroom table, etc.)
            3. Accessibility features
            
            Format as JSON:
            {
                "parkingInfo": "description",
                "babyChangingFacilities": "description",
                "accessibilityNotes": "description",
                "confidence": 0.0-1.0
            }
            """
            
            let analysis = try await openAIClient.analyze(prompt: prompt)
            return FacilityInsight(
                source: "Review Analysis",
                parkingInfo: analysis.parkingInfo,
                babyChangingFacilities: analysis.babyChangingFacilities,
                accessibilityNotes: analysis.accessibilityNotes,
                confidence: analysis.confidence
            )
        } catch {
            return FacilityInsight(source: "Review Analysis", error: error)
        }
    }
    
    private func consolidateInsights(_ insights: [FacilityInsight], originalLocation: Location) async -> VenueFacilities {
        let validInsights = insights.filter { $0.error == nil }
        
        if validInsights.isEmpty {
            return VenueFacilities(
                parkingInfo: originalLocation.parkingInfo,
                babyChangingFacilities: originalLocation.babyChangingFacilities,
                accessibilityNotes: originalLocation.accessibilityNotes,
                confidence: 0.0,
                sources: ["Manual Entry"]
            )
        }
        
        // Use AI to consolidate multiple sources
        let prompt = """
        Consolidate these multiple sources of venue facility information:
        
        \(validInsights.map { insight in
            """
            Source: \(insight.source) (Confidence: \(insight.confidence))
            Parking: \(insight.parkingInfo ?? "Not mentioned")
            Baby Changing: \(insight.babyChangingFacilities ?? "Not mentioned")
            Accessibility: \(insight.accessibilityNotes ?? "Not mentioned")
            """
        }.joined(separator: "\n\n"))
        
        Provide final, accurate information for:
        - Parking availability and type
        - Baby changing facilities
        - Accessibility features
        
        Format as JSON:
        {
            "parkingInfo": "final description",
            "babyChangingFacilities": "final description",
            "accessibilityNotes": "final description",
            "confidence": 0.0-1.0,
            "sources": ["source1", "source2"]
        }
        """
        
        do {
            let consolidated = try await openAIClient.analyze(prompt: prompt)
            return VenueFacilities(
                parkingInfo: consolidated.parkingInfo,
                babyChangingFacilities: consolidated.babyChangingFacilities,
                accessibilityNotes: consolidated.accessibilityNotes,
                confidence: consolidated.confidence,
                sources: consolidated.sources
            )
        } catch {
            // Fallback to highest confidence insight
            let bestInsight = validInsights.max { $0.confidence < $1.confidence } ?? validInsights.first!
            return VenueFacilities(
                parkingInfo: bestInsight.parkingInfo,
                babyChangingFacilities: bestInsight.babyChangingFacilities,
                accessibilityNotes: bestInsight.accessibilityNotes,
                confidence: bestInsight.confidence,
                sources: [bestInsight.source]
            )
        }
    }
    
    // MARK: - Helper Methods
    
    private func scrapeWebsite(url: String) async throws -> String {
        // Simulated web scraping - in production, use a real web scraping service
        guard let url = URL(string: url) else {
            throw AIError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let htmlString = String(data: data, encoding: .utf8) ?? ""
        
        // Basic HTML to text conversion (in production, use a proper HTML parser)
        return htmlString
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func fetchReviews(venueName: String, address: String) async throws -> String {
        // Simulated review fetching - in production, integrate with review APIs
        return """
        "Great venue with free parking available on-site. They have a dedicated baby changing room which is really convenient for parents."
        "Lovely place but parking can be tricky during busy times. They do have a changing table in the bathroom though."
        "Excellent facilities for families. Plenty of parking and they have a proper baby changing room with sink."
        """
    }
}

// MARK: - Supporting Models

struct VenueFacilities {
    let parkingInfo: String?
    let babyChangingFacilities: String?
    let accessibilityNotes: String?
    let confidence: Double
    let sources: [String]
}

struct FacilityInsight {
    let source: String
    let parkingInfo: String?
    let babyChangingFacilities: String?
    let accessibilityNotes: String?
    let confidence: Double
    let error: Error?
    
    init(source: String, parkingInfo: String? = nil, babyChangingFacilities: String? = nil, accessibilityNotes: String? = nil, confidence: Double = 0.0) {
        self.source = source
        self.parkingInfo = parkingInfo
        self.babyChangingFacilities = babyChangingFacilities
        self.accessibilityNotes = accessibilityNotes
        self.confidence = confidence
        self.error = nil
    }
    
    init(source: String, error: Error) {
        self.source = source
        self.parkingInfo = nil
        self.babyChangingFacilities = nil
        self.accessibilityNotes = nil
        self.confidence = 0.0
        self.error = error
    }
}

// MARK: - AI Clients

class OpenAIClient {
    private let apiKey: String
    
    init() {
        // In production, load from secure storage
        self.apiKey = "your-openai-api-key"
    }
    
    func analyze(prompt: String) async throws -> AIAnalysis {
        // Simulated AI venue check - in production, make actual API calls
        // This is where you'd integrate with OpenAI's API
        
        // Simulate API delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Simulated response based on prompt content
        if prompt.contains("parking") {
            return AIAnalysis(
                parkingInfo: "Free parking available on-site",
                babyChangingFacilities: "Dedicated changing room with changing table",
                accessibilityNotes: "Ground floor access, wheelchair accessible",
                confidence: 0.85,
                sources: ["AI Venue Check"]
            )
        } else {
            return AIAnalysis(
                parkingInfo: "Street parking available",
                babyChangingFacilities: "Changing table in main bathroom",
                accessibilityNotes: "Ground floor access",
                confidence: 0.75,
                sources: ["AI Venue Check"]
            )
        }
    }
    
    func extractURL(prompt: String) async throws -> String {
        // Simulated URL extraction - in production, make actual API calls
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Simulated response
        if prompt.contains("Sensory World Studio") {
            return "https://sensoryworldstudio.com"
        } else if prompt.contains("Music Studio") {
            return "https://musicstudio-richmond.com"
        } else {
            return "not found"
        }
    }
}

class GooglePlacesClient {
    func searchNearby(query: String, location: CLLocation) async throws -> PlaceDetails {
        // Simulated Google Places API call
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        return PlaceDetails(
            name: query,
            address: "123 High Street, Richmond, London",
            rating: 4.5,
            userRatingsTotal: 150,
            photos: [],
            website: "https://example.com",
            phoneNumber: "020 1234 5678"
        )
    }
}

// MARK: - Supporting Types

struct AIAnalysis {
    let parkingInfo: String?
    let babyChangingFacilities: String?
    let accessibilityNotes: String?
    let confidence: Double
    let sources: [String]
}

struct PlaceDetails {
    let name: String
    let address: String
    let rating: Double
    let userRatingsTotal: Int
    let photos: [String]
    let website: String?
    let phoneNumber: String?
    
    var description: String {
        """
        Name: \(name)
        Address: \(address)
        Rating: \(rating)/5 (\(userRatingsTotal) reviews)
        Website: \(website ?? "Not available")
        Phone: \(phoneNumber ?? "Not available")
        """
    }
}

enum AIError: Error {
    case invalidURL
    case apiError(String)
    case noData
} 