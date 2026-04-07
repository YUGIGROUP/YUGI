import SwiftUI
import Combine

#if canImport(FoundationModels)
import FoundationModels
#endif

struct VenueCheckScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var venueName: String = ""
    @State private var location: String = ""
    @State private var isLoading = false
    @State private var venueData: VenueAnalysisAPIData?
    @State private var errorMessage: String?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var enrichment: VenueEnrichmentResponse? = nil
    @State private var enrichmentLoading = false

    // MARK: - Venue Intelligence Summary (Foundation Models)
    @State private var summaryText = ""
    @State private var isSummaryStreaming = false
    @State private var summaryAvailable = false

    private let apiService = APIService.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Venue Check")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Text("Search any venue to check accessibility & logistics")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    // Search Form
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Venue Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            TextField("e.g. Nando's, Hyde Park, Costa Coffee", text: $venueName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .tint(.white)
                                .padding(14)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.35), lineWidth: 1))
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Location / Area")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                            TextField("e.g. Richmond, London", text: $location)
                                .textFieldStyle(.plain)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .tint(.white)
                                .padding(14)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.35), lineWidth: 1))
                        }

                        Button(action: searchVenue) {
                            HStack(spacing: 10) {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#BC6C5C")))
                                        .scaleEffect(0.9)
                                } else {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                Text(isLoading ? "Searching..." : "Search Venue")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(Color(hex: "#BC6C5C"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(12)
                        }
                        .disabled(venueName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                        .opacity(venueName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.6 : 1.0)
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Error state
                    if let errorMessage = errorMessage {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.yellow.opacity(0.4), lineWidth: 1))
                    }

                    // Results
                    if let data = venueData {
                        resultsView(data)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color(hex: "#BC6C5C").ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }

    // MARK: - Results View

    @ViewBuilder
    private func resultsView(_ data: VenueAnalysisAPIData) -> some View {
        let access = data.venueAccessibility
        VStack(spacing: 16) {
        // MARK: - YUGI Intelligence Summary (Apple Intelligence / Foundation Models)
        if summaryAvailable || isSummaryStreaming {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                    Text("YUGI Intelligence")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    if isSummaryStreaming {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.7)))
                            .scaleEffect(0.7)
                    }
                }

                if summaryText.isEmpty && isSummaryStreaming {
                    HStack(spacing: 6) {
                        ForEach([100, 70, 50], id: \.self) { w in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.25))
                                .frame(width: CGFloat(w), height: 11)
                        }
                    }
                } else if !summaryText.isEmpty {
                    Text(summaryText)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.12))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.25), lineWidth: 1))
        }

            // Venue header card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                    Text(data.venueName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                let displayAddress: String = {
                    if let formatted = data.formattedAddress, !formatted.trimmingCharacters(in: .whitespaces).isEmpty {
                        return formatted
                    }
                    let parts = [data.address.street, data.address.city].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    return parts.joined(separator: ", ")
                }()

                if !displayAddress.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.75))
                        Text(displayAddress)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                parentFriendlyScore(access)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3), lineWidth: 1))

            // Accessibility card
            venueCard(title: "Accessibility", systemImage: "figure.roll") {
                VStack(spacing: 10) {
                    accessibilityRow("Pram / Buggy Accessible Entrance", value: access?.pramAccessibleEntrance)
                    accessibilityRow("Accessible Restroom", value: access?.accessibleRestroom)
                    accessibilityRow("Accessible Seating", value: access?.accessibleSeating)
                    accessibilityRow("Accessible Parking", value: access?.accessibleParking)
                    accessibilityRow("Baby Changing", value: access?.hasBabyChanging ?? enrichment?.enrichedData.babyChanging?.available)
                }
            }

            // Parking card — enriched when available
            venueCard(title: "Parking", systemImage: "car.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    if enrichmentLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.7)))
                                .scaleEffect(0.8)
                            Text("Finding detailed info...")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    if let desc = enrichment?.parkingDescription {
                        Text(desc)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                        sourceLabel(enrichment!.sourceLabel)
                    } else {
                        if let parkingType = access?.parkingType {
                            HStack(spacing: 8) {
                                Image(systemName: "parkingsign.circle")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(width: 20)
                                Text(formatParkingType(parkingType))
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                            }
                        }
                        if !data.parkingInfo.isEmpty {
                            Text(data.parkingInfo)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if access?.parkingType == nil && data.parkingInfo.isEmpty && !enrichmentLoading {
                            Text("Parking information unavailable")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        if !enrichmentLoading { sourceLabel("Via Google") }
                    }
                }
            }

            // Enriched baby changing (shown when enrichment arrives with richer data)
            if let bc = enrichment?.enrichedData.babyChanging, bc.available != nil || bc.location != nil {
                venueCard(title: "Baby Changing", systemImage: "figure.and.child.holdinghands") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let avail = bc.available {
                            HStack(spacing: 8) {
                                Text(avail ? "✅" : "❌").font(.system(size: 16))
                                Text(avail ? "Available" : "Not available")
                                    .font(.system(size: 15)).foregroundColor(.white)
                            }
                        }
                        if let loc = bc.location {
                            Text("Location: \(loc)")
                                .font(.system(size: 14)).foregroundColor(.white.opacity(0.85))
                        }
                        if let details = bc.details {
                            Text(details)
                                .font(.system(size: 14)).foregroundColor(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        sourceLabel(enrichment!.sourceLabel)
                    }
                }
            }

            // Enriched pram / step-free access
            if let pr = enrichment?.enrichedData.pramAccess, pr.stepFreeAccess != nil || pr.liftAvailable != nil {
                venueCard(title: "Step-Free & Pram Access", systemImage: "figure.roll") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let step = pr.stepFreeAccess {
                            HStack(spacing: 8) {
                                Text(step ? "✅" : "❌").font(.system(size: 16))
                                Text(step ? "Step-free access confirmed" : "Step-free access not confirmed")
                                    .font(.system(size: 15)).foregroundColor(.white)
                            }
                        }
                        if let lift = pr.liftAvailable {
                            HStack(spacing: 8) {
                                Text(lift ? "✅" : "❌").font(.system(size: 16))
                                Text(lift ? "Lifts available" : "No lifts confirmed")
                                    .font(.system(size: 15)).foregroundColor(.white)
                            }
                        }
                        if let details = pr.details {
                            Text(details)
                                .font(.system(size: 14)).foregroundColor(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        sourceLabel(enrichment!.sourceLabel)
                    }
                }
            }

            // Enriched public transport
            if let pt = enrichment?.enrichedData.publicTransport,
               pt.nearestStation != nil || pt.busRoutes?.isEmpty == false {
                venueCard(title: "Public Transport", systemImage: "tram.fill") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let station = pt.nearestStation {
                            HStack(spacing: 8) {
                                Image(systemName: "train.side.front.car")
                                    .font(.system(size: 14)).foregroundColor(.white.opacity(0.8)).frame(width: 20)
                                Text(station + (pt.walkingTime.map { " — \($0) walk" } ?? ""))
                                    .font(.system(size: 15)).foregroundColor(.white)
                            }
                        }
                        if let routes = pt.busRoutes, !routes.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "bus.fill")
                                    .font(.system(size: 14)).foregroundColor(.white.opacity(0.8)).frame(width: 20)
                                Text("Bus routes: " + routes.joined(separator: ", "))
                                    .font(.system(size: 14)).foregroundColor(.white.opacity(0.85))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        sourceLabel(enrichment!.sourceLabel)
                    }
                }
            }

            // Additional parent-relevant notes from enrichment
            if let notes = enrichment?.enrichedData.additionalNotes {
                venueCard(title: "Also Worth Knowing", systemImage: "info.circle") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(notes)
                            .font(.system(size: 14)).foregroundColor(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                        sourceLabel(enrichment!.sourceLabel)
                    }
                }
            }

            // Nearest stations card
            if let stations = access?.nearestStations, !stations.isEmpty {
                venueCard(title: "Nearest Stations", systemImage: "tram.fill") {
                    VStack(spacing: 8) {
                        ForEach(stations, id: \.name) { station in
                            HStack(spacing: 8) {
                                Image(systemName: stationIcon(station.type))
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.8))
                                    .frame(width: 20)
                                Text(station.name)
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                Spacer()
                                if let dist = station.distance {
                                    Text(formatDistance(dist))
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                    }
                }
            }

            // Weather card
            if let weather = access?.weatherForecast, !weather.isEmpty {
                venueCard(title: "Weather Forecast", systemImage: "cloud.sun.fill") {
                    Text(weather)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func parentFriendlyScore(_ access: VenueAccessibility?) -> some View {
        let confirmedCount = [
            access?.pramAccessibleEntrance,
            access?.accessibleRestroom,
            access?.accessibleSeating,
            access?.accessibleParking,
            access?.hasBabyChanging
        ].compactMap { $0 }.filter { $0 }.count

        let fraction = Double(confirmedCount) / 5.0

        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Parent-Friendly Score")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Text("\(confirmedCount)/5")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(scoreColor(fraction))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(scoreColor(fraction))
                        .frame(width: geo.size.width * fraction, height: 8)
                }
            }
            .frame(height: 8)

            Text(scoreLabel(confirmedCount))
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.75))
        }
    }

    @ViewBuilder
    private func sourceLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white.opacity(0.55))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Color.white.opacity(0.12))
            .cornerRadius(4)
    }

    private func venueCard<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.3), lineWidth: 1))
    }

    private func accessibilityRow(_ label: String, value: Bool?) -> some View {
        HStack(spacing: 10) {
            Text(accessibilityEmoji(value))
                .font(.system(size: 18))
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.white)
            Spacer()
            Text(accessibilityStatusText(value))
                .font(.system(size: 13))
                .foregroundColor(accessibilityColor(value))
        }
    }

    // MARK: - Helpers

    private func accessibilityEmoji(_ value: Bool?) -> String {
        switch value {
        case true:  return "\u{2705}"
        case false: return "\u{274c}"
        default:    return "\u{2753}"
        }
    }

    private func accessibilityStatusText(_ value: Bool?) -> String {
        switch value {
        case true:  return "Confirmed"
        case false: return "Not available"
        default:    return "Unknown"
        }
    }

    private func accessibilityColor(_ value: Bool?) -> Color {
        switch value {
        case true:  return Color.green.opacity(0.9)
        case false: return Color.red.opacity(0.85)
        default:    return Color.white.opacity(0.45)
        }
    }

    private func scoreColor(_ fraction: Double) -> Color {
        if fraction >= 0.8 { return .green }
        if fraction >= 0.4 { return .yellow }
        return .orange
    }

    private func scoreLabel(_ count: Int) -> String {
        switch count {
        case 5:    return "Excellent — fully accessible"
        case 4:    return "Great — very parent-friendly"
        case 3:    return "Good — most features confirmed"
        case 2:    return "Fair — some accessibility features"
        case 1:    return "Limited accessibility confirmed"
        default:   return "Accessibility not confirmed"
        }
    }

    private func formatParkingType(_ type: String) -> String {
        switch type {
        case "free_lot":    return "Free parking lot"
        case "paid_lot":    return "Paid parking lot"
        case "free_street": return "Free street parking"
        case "paid_street": return "Paid street parking (check restrictions)"
        case "valet":       return "Valet parking"
        default:            return type.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private func stationIcon(_ type: String?) -> String {
        switch type {
        case "tube": return "tram.circle"
        case "rail": return "train.side.front.car"
        default:     return "bus"
        }
    }

    private func formatDistance(_ metres: Int) -> String {
        metres < 1000 ? "\(metres)m" : String(format: "%.1f km", Double(metres) / 1000.0)
    }

    // MARK: - API Call

    private static func syntheticPlaceId(name: String, loc: String) -> String {
        let slug = "\(name)-\(loc)"
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return "yugi-\(slug)"
    }

    private func searchVenue() {
        let name = venueName.trimmingCharacters(in: .whitespaces)
        let loc = location.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        venueData = nil
        enrichment = nil
        enrichmentLoading = false

        apiService.fetchVenueAnalysis(venueName: name, location: loc)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    isLoading = false
                    if case .failure(let error) = completion {
                        errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { response in
                    venueData = response.data
                    EventTracker.shared.trackVenueChecked(
                        venueName: name,
                        location: loc,
                        venueLocation: response.data.coordinates.map { (lat: $0.latitude, lng: $0.longitude) }
                    )
                    // Fetch enrichment async — never blocks UI
                    self.enrichmentLoading = true
                    VenueEnrichmentService.shared.fetchEnrichment(
                        placeId: Self.syntheticPlaceId(name: name, loc: loc),
                        venueName: name
                    ) { result in
                        self.enrichmentLoading = false
                        self.enrichment = result
                        if let result {
                            self.generateVenueSummary(result)
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
}

    // MARK: - Venue Intelligence Summary generation

    private func generateVenueSummary(_ enrichmentData: VenueEnrichmentResponse) {
        guard enrichmentData.hasData else { return }
        let isAIAvailable: Bool = {
            if #available(iOS 26, macOS 26, *) {
                #if canImport(FoundationModels)
                let av = SystemLanguageModel.default.availability
                if case .available = av { return true }
                #endif
            }
            return false
        }()
        guard isAIAvailable,
              let stream = VenueSummaryGeneratorWrapper.shared.summaryStream(for: enrichmentData) else { return }

        summaryAvailable = true
        isSummaryStreaming = true
        summaryText = ""

        Task { @MainActor in
            do {
                for try await chunk in stream {
                    summaryText = chunk
                }
                EventTracker.shared.trackVenueSummaryGenerated(venueName: venueName)
            } catch {
                if summaryText.isEmpty { summaryAvailable = false }
            }
            isSummaryStreaming = false
        }
    }


#Preview {
    VenueCheckScreen()
}
