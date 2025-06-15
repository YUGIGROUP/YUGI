import Foundation
import CoreLocation
import Combine

class LocationService: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var lastKnownRegion: String?
    @Published var error: LocationError?
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    enum LocationError: Error {
        case unauthorized
        case unableToGetLocation
        case geocodingFailed
        
        var message: String {
            switch self {
            case .unauthorized:
                return "Please enable location services to find classes near you"
            case .unableToGetLocation:
                return "Unable to determine your location"
            case .geocodingFailed:
                return "Unable to determine your region"
            }
        }
    }
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    func getRegionName(for location: CLLocation) async throws -> String {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first,
                  let locality = placemark.locality ?? placemark.administrativeArea else {
                throw LocationError.geocodingFailed
            }
            return locality
        } catch {
            throw LocationError.geocodingFailed
        }
    }
    
    func calculateDistance(from location: CLLocation, to classLocation: Location) -> CLLocationDistance {
        return location.distance(from: classLocation.coordinates.clLocation)
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        case .denied, .restricted:
            error = .unauthorized
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        
        // Post notification for location update
        NotificationCenter.default.post(name: .locationDidUpdate, object: nil)
        
        Task {
            do {
                let region = try await getRegionName(for: location)
                await MainActor.run {
                    self.lastKnownRegion = region
                }
            } catch {
                await MainActor.run {
                    self.error = .geocodingFailed
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.error = .unableToGetLocation
    }
} 