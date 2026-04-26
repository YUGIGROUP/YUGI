import Foundation
import MapKit
import UIKit
import CoreLocation

// MARK: - MapsApp

enum MapsApp: String, CaseIterable, Identifiable {
    case apple, googleMaps, waze, citymapper

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apple: return "Apple Maps"
        case .googleMaps: return "Google Maps"
        case .waze: return "Waze"
        case .citymapper: return "Citymapper"
        }
    }
}

// MARK: - MapsLauncher

enum MapsLauncher {
    /// Presents the iOS native chooser for opening a venue in maps apps.
    /// Available apps: Apple Maps, Google Maps, Waze, Citymapper.
    static func availableApps() -> [MapsApp] {
        var apps: [MapsApp] = [.apple]
        if let url = URL(string: "comgooglemaps://"), UIApplication.shared.canOpenURL(url) {
            apps.append(.googleMaps)
        }
        if let url = URL(string: "waze://"), UIApplication.shared.canOpenURL(url) {
            apps.append(.waze)
        }
        if let url = URL(string: "citymapper://"), UIApplication.shared.canOpenURL(url) {
            apps.append(.citymapper)
        }
        return apps
    }

    static func open(_ app: MapsApp, venueName: String, address: String?, coordinates: CLLocationCoordinate2D?) {
        switch app {
        case .apple: openAppleMaps(venueName: venueName, address: address, coordinates: coordinates)
        case .googleMaps: openGoogleMaps(venueName: venueName, address: address, coordinates: coordinates)
        case .waze: openWaze(venueName: venueName, address: address, coordinates: coordinates)
        case .citymapper: openCitymapper(venueName: venueName, address: address, coordinates: coordinates)
        }
    }

    // MARK: - Convenience: model → launcher params (keeps CLLocationCoordinate2D out of views)

    static func open(_ app: MapsApp, forClass classItem: Class) {
        let venueName = classItem.location?.name ?? "Location TBD"
        let address: String? = {
            guard let f = classItem.location?.address.formatted else { return nil }
            let t = f.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }()
        let coordinates: CLLocationCoordinate2D? = classItem.location.map {
            CLLocationCoordinate2D(latitude: $0.coordinates.latitude, longitude: $0.coordinates.longitude)
        }
        open(app, venueName: venueName, address: address, coordinates: coordinates)
    }

    static func open(_ app: MapsApp, forBooking booking: EnhancedBooking) {
        open(app, forClass: booking.classInfo)
    }

    static func open(_ app: MapsApp, forVenueAnalysis data: VenueAnalysisAPIData) {
        let address: String? = {
            if let f = data.formattedAddress, !f.trimmingCharacters(in: .whitespaces).isEmpty {
                return f.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let parts = [data.address.street, data.address.city].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            let joined = parts.joined(separator: ", ")
            return joined.isEmpty ? nil : joined
        }()
        let coordinates: CLLocationCoordinate2D? = data.coordinates.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        open(app, venueName: data.venueName, address: address, coordinates: coordinates)
    }

    // MARK: - Per-app (private)

    /// Apple Maps — uses MKMapItem when coordinates are available, otherwise https://maps.apple.com search.
    private static func openAppleMaps(venueName: String, address: String?, coordinates: CLLocationCoordinate2D?) {
        if let coordinates = coordinates {
            let placemark = MKPlacemark(coordinate: coordinates)
            let item = MKMapItem(placemark: placemark)
            item.name = venueName
            item.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
            ])
            return
        }
        guard let url = appleMapsSearchURL(venueName: venueName, address: address) else { return }
        UIApplication.shared.open(url)
    }

    private static func openGoogleMaps(venueName: String, address: String?, coordinates: CLLocationCoordinate2D?) {
        let urlString: String
        if let c = coordinates {
            urlString = "comgooglemaps://?daddr=\(c.latitude),\(c.longitude)&directionsmode=driving"
        } else if let query = encodedQuery(venueName: venueName, address: address) {
            urlString = "comgooglemaps://?daddr=\(query)&directionsmode=driving"
        } else {
            return
        }
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private static func openWaze(venueName: String, address: String?, coordinates: CLLocationCoordinate2D?) {
        let urlString: String
        if let c = coordinates {
            urlString = "waze://?ll=\(c.latitude),\(c.longitude)&navigate=yes"
        } else if let query = encodedQuery(venueName: venueName, address: address) {
            urlString = "waze://?q=\(query)&navigate=yes"
        } else {
            return
        }
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private static func openCitymapper(venueName: String, address: String?, coordinates: CLLocationCoordinate2D?) {
        guard let c = coordinates else {
            openAppleMaps(venueName: venueName, address: address, coordinates: nil)
            return
        }
        let nameQuery = venueName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "citymapper://directions?endcoord=\(c.latitude),\(c.longitude)&endname=\(nameQuery)"
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - URL helpers

    private static func appleMapsSearchURL(venueName: String, address: String?) -> URL? {
        guard let query = encodedQuery(venueName: venueName, address: address) else { return nil }
        return URL(string: "https://maps.apple.com/?q=\(query)")
    }

    private static func encodedQuery(venueName: String, address: String?) -> String? {
        let raw: String
        if let address = address, !address.isEmpty {
            raw = "\(venueName), \(address)"
        } else {
            raw = venueName
        }
        return raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
    }
}
