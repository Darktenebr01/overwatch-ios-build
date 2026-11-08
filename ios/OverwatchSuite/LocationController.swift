import Foundation
import CoreLocation

final class LocationController: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var homeRegion: CLCircularRegion?
    private var wantUpdates = false

    var onLocation: ((CLLocation) -> Void)?
    var onHomeExit: (() -> Void)?
    var onHomeEnter: (() -> Void)?
    var onAuthorizationChanged: ((CLAuthorizationStatus) -> Void)?
    var onError: ((String) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 40
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
    }

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }
    var isMonitoring: Bool { homeRegion != nil }

    func requestAlways() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestAlwaysAuthorization()
        }
    }

    func startLive() {
        wantUpdates = true
        requestAlways()
        guard manager.authorizationStatus == .authorizedAlways
                || manager.authorizationStatus == .authorizedWhenInUse else { return }
        manager.allowsBackgroundLocationUpdates = true
        manager.startUpdatingLocation()
    }

    func stopLive() {
        wantUpdates = false
        manager.stopUpdatingLocation()
    }

    func monitorHome(_ fence: Geofence?) {
        if let old = homeRegion {
            manager.stopMonitoring(for: old)
            homeRegion = nil
        }
        guard let fence else { return }
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: fence.lat, longitude: fence.lng),
            radius: max(fence.radiusM, 100),
            identifier: "workday-home"
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        homeRegion = region
        manager.startMonitoring(for: region)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthorizationChanged?(manager.authorizationStatus)
        if manager.authorizationStatus == .authorizedAlways {
            if let homeRegion { manager.startMonitoring(for: homeRegion) }
        }
        if wantUpdates,
           manager.authorizationStatus == .authorizedAlways
            || manager.authorizationStatus == .authorizedWhenInUse {
            manager.allowsBackgroundLocationUpdates = true
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            onLocation?(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier == "workday-home" else { return }
        onHomeEnter?()
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == "workday-home" else { return }
        onHomeExit?()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onError?(error.localizedDescription)
    }
}
