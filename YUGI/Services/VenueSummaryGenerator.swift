import Foundation

// FoundationModels is available from iOS 26 / macOS 26 onwards (Apple Intelligence).
// All Foundation Models types are wrapped in canImport + @available guards.

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26, macOS 26, *)
final class VenueSummaryGenerator {
    static let shared = VenueSummaryGenerator()
    private init() {}

    private let instructions = """
        You are a friendly local guide writing short venue summaries for parents with babies and toddlers.
        Write in warm, conversational British English — as if a friend is texting a recommendation.
        Keep summaries to 2–4 sentences maximum. Focus on what matters most to parents:
        getting there with a pram, parking, baby facilities, and how close public transport is.
        Never use jargon. Never start with "This venue" or "The venue". Be specific and useful.
        If information is missing, don't mention it — only describe what you know.
        """

    /// Returns a streaming async sequence of text chunks building up the summary.
    /// Returns nil if Foundation Models is unavailable on this device.
    func summaryStream(for enrichment: VenueEnrichmentResponse) -> AsyncThrowingStream<String, Error>? {
        let availability = SystemLanguageModel.default.availability
        guard case .available = availability else {
            print("VenueSummaryGenerator: Foundation Models unavailable")
            return nil
        }

        let prompt = buildPrompt(from: enrichment)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let session = LanguageModelSession(instructions: self.instructions)
                    let stream = session.streamResponse(to: prompt)
                    for try await partial in stream {
                        continuation.yield(partial.text)
                    }
                    continuation.finish()
                } catch {
                    print("VenueSummaryGenerator: streaming failed — \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private

    private func buildPrompt(from enrichment: VenueEnrichmentResponse) -> String {
        var facts: [String] = []
        let data = enrichment.enrichedData

        if let parking = data.parking {
            if let spaces = parking.totalSpaces, spaces > 0 {
                let formatted = spaces >= 1000
                    ? "\(spaces / 1000),\(String(format: "%03d", spaces % 1000))"
                    : "\(spaces)"
                let names = parking.carParkNames?.joined(separator: " and ") ?? ""
                let nameStr = names.isEmpty ? "" : " (\(names))"
                facts.append("Parking: \(formatted) spaces\(nameStr).")
            }
            if let type = parking.type, type != "null" {
                facts.append("Parking type: \(type).")
            }
            if parking.ticketless == true { facts.append("Parking is ticketless (ANPR).") }
            if let cost = parking.costInfo { facts.append("Parking cost: \(cost).") }
            if let parent = parking.parentBays {
                facts.append("Parent and child bays: \(parent).")
            }
            if let blue = parking.blueBadgeBays {
                facts.append("Blue Badge bays: \(blue).")
            }
        }

        if let changing = data.babyChanging {
            if changing.available == true {
                var line = "Baby changing available"
                if let loc = changing.location { line += " – \(loc)" }
                if let detail = changing.details, !detail.isEmpty { line += ". \(detail)" }
                facts.append(line + ".")
            } else if changing.available == false {
                facts.append("No baby changing facilities.")
            }
        }

        if let pram = data.pramAccess {
            if pram.stepFreeAccess == true {
                var line = "Step-free access throughout"
                if pram.liftAvailable == true { line += " with lifts" }
                if let detail = pram.details, !detail.isEmpty { line += ". \(detail)" }
                facts.append(line + ".")
            } else if pram.stepFreeAccess == false {
                facts.append("Not fully step-free — stairs may be required.")
            }
        }

        if let transport = data.publicTransport {
            if let station = transport.nearestStation {
                var line = "\(station) station"
                if let walk = transport.walkingTime { line += " is \(walk) walk" }
                facts.append(line + ".")
            }
            if let buses = transport.busRoutes, !buses.isEmpty {
                facts.append("Bus routes: \(buses.joined(separator: ", ")).")
            }
        }

        if let notes = data.additionalNotes {
            facts.append(notes)
        }

        let factsText = facts.isEmpty
            ? "Limited information available for this venue."
            : facts.joined(separator: "\n")

        return """
            Write a friendly summary for parents visiting \(enrichment.venueName) with a baby or toddler.

            Known facts:
            \(factsText)
            """
    }
}

#endif // canImport(FoundationModels)

// MARK: - Availability wrapper

/// Platform-agnostic wrapper that the view calls without worrying about iOS version.
@MainActor
final class VenueSummaryGeneratorWrapper {
    static let shared = VenueSummaryGeneratorWrapper()
    private init() {}

    /// Returns a streaming async sequence building up the summary text,
    /// or nil if Foundation Models is unavailable (older device / AI disabled).
    func summaryStream(for enrichment: VenueEnrichmentResponse) -> AsyncThrowingStream<String, Error>? {
        if #available(iOS 26, macOS 26, *) {
            #if canImport(FoundationModels)
            return VenueSummaryGenerator.shared.summaryStream(for: enrichment)
            #endif
        }
        return nil
    }
}
