import Foundation

// FoundationModels is available from iOS 26 / macOS 26 onwards (Apple Intelligence).
// All Foundation Models types are wrapped in canImport + @available guards
// so the app compiles and runs correctly on older devices and OS versions.

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Structured output type

@available(iOS 26, macOS 26, *)
@Generable
struct SmartSearchFilters {
    @Guide(description: "Class category, e.g. Baby, Music, Sensory, Yoga, Swimming, Dance. Null if not specified.")
    let category: String?

    @Guide(description: "Age range as a human-readable string, e.g. '0-6 months', '1-2 years'. Null if not specified.")
    let ageRange: String?

    @Guide(description: "Type of activity, e.g. calm, active, sensory, creative, educational. Null if not specified.")
    let activityType: String?

    @Guide(description: "True only if the parent explicitly mentions parking, a car, or driving.")
    let needsParking: Bool

    @Guide(description: "True only if the parent explicitly mentions baby changing or nappy facilities.")
    let needsBabyChanging: Bool

    @Guide(description: "True only if the parent explicitly mentions step-free, wheelchair, lift, or pram access.")
    let needsStepFreeAccess: Bool

    @Guide(description: "Location hint extracted from the query, e.g. 'Kingston', 'Richmond'. Null if not mentioned.")
    let locationHint: String?
}

// MARK: - Service

@available(iOS 26, macOS 26, *)
final class SmartSearchService {
    static let shared = SmartSearchService()
    private init() {}

    private let instructions = """
        You are a search assistant for YUGI, an app that helps parents discover baby and toddler classes.
        Parse the parent's natural language query into structured search filters.
        Class categories: Music, Art, Sport, Dance, Language, STEM, Sensory, Swimming, Gymnastics, Drama, Cooking, Nature, Yoga, Baby, Wellness.
        Be conservative — only set Bool flags to true when the parent clearly mentions them.
        Set string fields to null when not specified rather than guessing.
        """

    /// Parse a natural language query into structured filters.
    /// Returns nil if the model is unavailable or the request fails.
    func parseQuery(_ query: String) async -> SmartSearchFilters? {
        let availability = SystemLanguageModel.default.availability
        guard case .available = availability else {
            print("SmartSearchService: Foundation Models unavailable, using text fallback")
            return nil
        }

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(
                to: "Parse this search query: \(query)",
                generating: SmartSearchFilters.self
            )
            return response.content
        } catch {
            print("SmartSearchService: generation failed — \(error.localizedDescription)")
            return nil
        }
    }
}

#endif // canImport(FoundationModels)

// MARK: - Availability wrapper

/// A platform-safe wrapper the view calls without worrying about iOS version.
/// On iOS 26+ with Apple Intelligence enabled, uses Foundation Models.
/// On older devices, returns nil so the caller falls back to basic text search.
@MainActor
final class SmartSearchServiceWrapper {
    static let shared = SmartSearchServiceWrapper()
    private init() {}

    /// Parse a natural language query.
    /// Returns nil when AI is unavailable — the caller should use basic substring matching.
    func parseQuery(_ query: String) async -> ParsedSearchFilters? {
        if #available(iOS 26, macOS 26, *) {
            #if canImport(FoundationModels)
            guard let filters = await SmartSearchService.shared.parseQuery(query) else {
                return nil
            }
            return ParsedSearchFilters(
                category: filters.category,
                ageRange: filters.ageRange,
                activityType: filters.activityType,
                needsParking: filters.needsParking,
                needsBabyChanging: filters.needsBabyChanging,
                needsStepFreeAccess: filters.needsStepFreeAccess,
                locationHint: filters.locationHint
            )
            #endif
        }
        return nil
    }
}

/// Platform-agnostic filter result used by ClassDiscoveryView regardless of iOS version.
struct ParsedSearchFilters {
    let category: String?
    let ageRange: String?
    let activityType: String?
    let needsParking: Bool
    let needsBabyChanging: Bool
    let needsStepFreeAccess: Bool
    let locationHint: String?
}

// MARK: - Filter application

extension ParsedSearchFilters {
    /// Apply structured AI filters to a list of classes.
    func apply(to classes: [YugiClass], enrichments: [String: VenueEnrichmentResponse]) -> [YugiClass] {
        classes.filter { yugiClass in
            // Category filter
            if let cat = category?.lowercased(), !cat.isEmpty {
                let classCategory = yugiClass.category.lowercased()
                let className = yugiClass.name.lowercased()
                let classDesc = yugiClass.description.lowercased()
                guard classCategory.contains(cat) || className.contains(cat) || classDesc.contains(cat) else {
                    return false
                }
            }

            // Location hint filter
            if let loc = locationHint?.lowercased(), !loc.isEmpty {
                let venueAddr = (yugiClass.venueAddress ?? "").lowercased()
                let venueName = (yugiClass.venueName ?? "").lowercased()
                guard venueAddr.contains(loc) || venueName.contains(loc) else {
                    return false
                }
            }

            // Enrichment-based filters
            if needsParking || needsBabyChanging || needsStepFreeAccess {
                guard let placeId = yugiClass.venuePlaceId,
                      let enrichment = enrichments[placeId] else {
                    // No enrichment data — give benefit of the doubt
                    return true
                }
                if needsParking {
                    let hasParking = (enrichment.enrichedData.parking?.totalSpaces ?? 0) > 0
                        || enrichment.enrichedData.parking?.carParkNames?.isEmpty == false
                    if !hasParking { return false }
                }
                if needsBabyChanging {
                    guard enrichment.enrichedData.babyChanging?.available == true else { return false }
                }
                if needsStepFreeAccess {
                    guard enrichment.enrichedData.pramAccess?.stepFreeAccess == true else { return false }
                }
            }

            return true
        }
    }
}
