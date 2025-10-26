import Foundation
import CoreLocation
import Combine

final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationProvider()

    @Published var lastLocation: CLLocation?
    @Published var status: CLAuthorizationStatus?

    private let manager = CLLocationManager()

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5     // Update alle 5 Meter
    }

    // MARK: - Starten / Stoppen
    func start() {
        let currentStatus = manager.authorizationStatus
        if currentStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if currentStatus == .authorizedWhenInUse || currentStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    // MARK: - Delegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        lastLocation = loc
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error.localizedDescription)
    }

    // MARK: - Zugriffshilfe für ChatFrame
    static var currentCoordinate: (lat: Double?, lon: Double?, acc: Double?) {
        guard let loc = shared.lastLocation else { return (nil, nil, nil) }
        return (loc.coordinate.latitude, loc.coordinate.longitude, loc.horizontalAccuracy)
    }
}
