import SwiftUI

/// "Getting there" block for the redesigned search result card's expanded state:
/// address, parking, and the nearest two transit stations.
/// The station rendering is lifted verbatim from `ClassCardDetails`
/// (ClassDiscoveryView.swift), capped at the nearest two.
struct GettingThereBlock: View {
    let classItem: Class
    var enrichment: VenueEnrichmentResponse? = nil

    /// Parking fallback chain — mirrors `ClassCardDetails.parkingText`.
    private var parkingText: String {
        enrichment?.parkingDescription ?? classItem.location?.parkingInfo ?? "No parking info"
    }

    private var addressText: String {
        classItem.location?.address.formatted ?? "Location TBD"
    }

    /// Nearest two stations only.
    private var stations: [NearestStation] {
        Array((classItem.venueAccessibility?.nearestStations ?? []).prefix(2))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Getting there")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)

            ClassDetailRow(icon: "mappin.circle", text: addressText)
            ClassDetailRow(icon: "car.fill", text: parkingText)

            // Nearest transit stations (lifted from ClassCardDetails, capped at 2)
            if !stations.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(stations, id: \.name) { station in
                        HStack(spacing: 6) {
                            Image(systemName: station.type == "tube" ? "tram.fill" : station.type == "rail" ? "train.side.front.car" : "bus.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color.yugiMocha)
                                .frame(width: 16)
                            HStack(spacing: 4) {
                                if let dist = station.distance {
                                    Text("\(station.name) (\(dist)m)")
                                } else {
                                    Text(station.name)
                                }
                                if station.stepFreeAccess == "yes" {
                                    Image(systemName: "figure.roll")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color.yugiSage)
                                }
                            }
                        }
                        .font(.system(size: 13))
                        .foregroundColor(Color.yugiGray)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
