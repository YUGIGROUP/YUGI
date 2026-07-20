import SwiftUI

/// Redesigned, shared-capable class search result card (compact scan card).
///
/// Layout: name, provider + price, age/date chips, a swipeable/tappable venue
/// name + address line, a one-line doability row, a venue reassurance line, and an
/// action row (Full AI venue report + Book Now). The full doability detail
/// (`DoabilityReasonsView`) plus a "Getting there" block expand in place; both the
/// row and its badge toggle the same `isDoabilityExpanded` state.
///
/// Fetches its own venue enrichment on appear, mirroring `ClassCard`
/// (ClassDiscoveryView.swift). Weather and description are deliberately off the
/// scan view.
struct ClassResultCard: View {
    let classItem: Class
    let onBook: (Class) -> Void
    let onAnalyze: (Class) -> Void

    @State private var showingProviderProfile = false
    @State private var showingMapsChooser = false
    @State private var enrichment: VenueEnrichmentResponse? = nil
    @State private var isDoabilityExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            nameSection
            providerAndPriceSection
            chipsSection

            if let venue = venueLineText {
                venueLine(venue)
            }

            if let doability = classItem.doability {
                DoabilityRow(doability: doability, isExpanded: $isDoabilityExpanded)
            }

            if let reassurance = venueReassurance {
                venueReassuranceLine(reassurance)
            }

            if isDoabilityExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    if let doability = classItem.doability {
                        DoabilityReasonsView(doability: doability)
                    }
                    GettingThereBlock(classItem: classItem, enrichment: enrichment)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            actionButtonsSection
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .confirmationDialog("Open in Maps", isPresented: $showingMapsChooser, titleVisibility: .hidden) {
            ForEach(MapsLauncher.availableApps()) { app in
                Button(app.displayName) {
                    MapsLauncher.open(app, forClass: classItem)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .onAppear {
            guard enrichment == nil, let loc = classItem.location else { return }
            guard let placeId = classItem.googlePlaceId, !placeId.isEmpty else {
                print("ClassResultCard: skipping enrichment, no Google placeId on class \(classItem.id)")
                return
            }
            VenueEnrichmentService.shared.fetchEnrichment(
                placeId: placeId,
                venueName: loc.name,
                address: loc.address.formatted
            ) { self.enrichment = $0 }
        }
        .sheet(isPresented: $showingProviderProfile) {
            ProviderProfilePopup(providerId: classItem.provider)
        }
    }

    // MARK: - Name

    private var nameSection: some View {
        Text(classItem.name)
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(Color.yugiGray)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Provider + Price

    private var providerAndPriceSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(classItem.providerName ?? "Provider \(classItem.provider)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.yugiGray)

                Button(action: {
                    showingProviderProfile = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 12))
                        Text("View Profile")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(Color.yugiMocha)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.yugiMocha.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("£\(NSDecimalNumber(decimal: classItem.pricing.amount).intValue)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.yugiMocha)

                Text("per session")
                    .font(.system(size: 12))
                    .foregroundColor(Color.yugiGray.opacity(0.7))
            }
        }
    }

    // MARK: - Chips (age / date + first time slot)

    private var ageChip: String? {
        let age = classItem.ageRange
        return (!age.isEmpty && age != "All ages") ? age : nil
    }

    /// Date + first time slot, e.g. "Sat 10 Jan, 10:00". Falls back to the
    /// recurring-day abbreviations when no time slot is present.
    private var dateChip: String? {
        let days = classItem.schedule.formattedDays
        guard let slot = classItem.schedule.timeSlots.first else {
            return days.isEmpty ? nil : days
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM, HH:mm"
        return formatter.string(from: slot.startTime)
    }

    @ViewBuilder
    private var chipsSection: some View {
        let chips: [(String, String)] = [
            ageChip.map { ("person.2.fill", $0) },
            dateChip.map { ("calendar", $0) }
        ].compactMap { $0 }

        if !chips.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips, id: \.1) { chip in
                        HStack(spacing: 6) {
                            Image(systemName: chip.0)
                                .font(.system(size: 12))
                            Text(chip.1)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundColor(Color.yugiMocha)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.yugiSage.opacity(0.35))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Venue line (name + short address)

    /// Venue name + short address (street + postcode), degrading gracefully when
    /// any part is missing. When the recommendation payload carried a per-class
    /// distance, it's appended as "· 4.8 km". Returns nil only when nothing usable
    /// is present.
    private var venueLineText: String? {
        guard let loc = classItem.location else { return nil }
        var parts: [String] = []
        let name = loc.name.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { parts.append(name) }
        let street = loc.address.street.trimmingCharacters(in: .whitespaces)
        if !street.isEmpty { parts.append(street) }
        let postcode = loc.address.postalCode.trimmingCharacters(in: .whitespaces)
        if !postcode.isEmpty { parts.append(postcode) }
        var composed = parts.joined(separator: ", ")
        if let km = classItem.distanceKm {
            let distance = "\(String(format: "%.1f", km)) km"
            composed = composed.isEmpty ? distance : "\(composed) · \(distance)"
        }
        return composed.isEmpty ? nil : composed
    }

    private func venueLine(_ text: String) -> some View {
        // Horizontally scrollable so a long address can be swiped to read in full.
        // The plain tap gesture coexists with the scroll drag: it fires only when
        // the gesture isn't a drag, opening the same maps chooser as the actions.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 12))
                    .foregroundColor(Color.yugiGray.opacity(0.7))
                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(Color.yugiGray.opacity(0.8))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onTapGesture { showingMapsChooser = true }
    }

    // MARK: - Venue reassurance line

    /// One short reassurance line composed from enrichment when available.
    private var venueReassurance: String? {
        if enrichment?.hasData == true, let e = enrichment {
            if let badge = e.discoveryBadges.first {
                return "\(e.sourceLabel) · \(badge)"
            }
            return e.sourceLabel
        }
        // Light fallback from venue accessibility when no enrichment yet.
        if classItem.venueAccessibility?.hasBabyChanging == true {
            return "Baby changing available"
        }
        return nil
    }

    private func venueReassuranceLine(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 12))
                .foregroundColor(Color.yugiSage)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.yugiGray.opacity(0.9))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: { onAnalyze(classItem) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 14))
                        Text("Full AI venue report")
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundColor(Color.yugiMocha)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.yugiMocha.opacity(0.1))
                    .cornerRadius(8)
                }

                Spacer()
            }

            // Book Now — Mocha reserved for the primary CTA.
            Button(action: { onBook(classItem) }) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 14))
                    Text("Book Now")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.yugiMocha)
                .cornerRadius(10)
            }
        }
    }
}
