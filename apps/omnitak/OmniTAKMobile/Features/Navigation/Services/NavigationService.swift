//
//  NavigationService.swift
//  OmniTAKMobile
//
//  Navigation and compass service for waypoint navigation
//

import Foundation
import CoreLocation
import Combine
import MapKit

// MARK: - Navigation Service

/// Service for calculating navigation data and managing compass heading
class NavigationService: NSObject, ObservableObject {
    // Published properties
    @Published var navigationState: NavigationState = .initial
    @Published var compassData: CompassData = .initial
    @Published var currentLocation: CLLocation?
    @Published var isCompassAvailable: Bool = false

    // Location and heading managers
    private let locationManager = CLLocationManager()
    private var headingUpdateTimer: Timer?

    // Navigation calculations
    private var speedSamples: [Double] = []
    private let maxSpeedSamples = 10

    // Singleton instance
    static let shared = NavigationService()

    override init() {
        super.init()
        setupLocationManager()
    }

    // MARK: - Setup

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5.0  // Update every 5 meters

        // Request authorization
        locationManager.requestWhenInUseAuthorization()

        // Check if compass is available
        isCompassAvailable = CLLocationManager.headingAvailable()
    }

    // MARK: - Location Updates

    func startLocationUpdates() {
        locationManager.startUpdatingLocation()
        #if DEBUG
        print("📍 Started location updates")
        #endif
    }

    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        #if DEBUG
        print("📍 Stopped location updates")
        #endif
    }

    // MARK: - Compass/Heading Updates

    func startHeadingUpdates() {
        guard isCompassAvailable else {
            #if DEBUG
            print("⚠️ Compass not available on this device")
            #endif
            return
        }

        locationManager.startUpdatingHeading()
        #if DEBUG
        print("🧭 Started compass updates")
        #endif
    }

    func stopHeadingUpdates() {
        locationManager.stopUpdatingHeading()
        #if DEBUG
        print("🧭 Stopped compass updates")
        #endif
    }

    // MARK: - Navigation Control

    /// Start navigating to a waypoint
    func startNavigation(to waypoint: Waypoint) {
        navigationState.isNavigating = true
        navigationState.targetWaypoint = waypoint
        navigationState.averageSpeed = nil
        speedSamples.removeAll()

        // Start location and heading updates
        startLocationUpdates()
        startHeadingUpdates()

        // Update navigation data if we already have a location
        if let location = currentLocation {
            updateNavigationData(location: location)
        }

        #if DEBUG
        print("🎯 Started navigation to: \(waypoint.name)")
        #endif
    }

    /// Stop navigation
    func stopNavigation() {
        navigationState = .initial
        speedSamples.removeAll()

        // Keep location updates running but can optionally stop heading
        stopHeadingUpdates()

        #if DEBUG
        print("⏹️ Stopped navigation")
        #endif
    }

    /// Toggle navigation to waypoint
    func toggleNavigation(to waypoint: Waypoint) {
        if navigationState.isNavigating && navigationState.targetWaypoint?.id == waypoint.id {
            stopNavigation()
        } else {
            startNavigation(to: waypoint)
        }
    }

    // MARK: - Navigation Calculations

    private func updateNavigationData(location: CLLocation) {
        guard navigationState.isNavigating,
              let targetWaypoint = navigationState.targetWaypoint else {
            return
        }

        // Calculate distance
        let targetLocation = CLLocation(
            latitude: targetWaypoint.coordinate.latitude,
            longitude: targetWaypoint.coordinate.longitude
        )
        navigationState.currentDistance = location.distance(from: targetLocation)

        // Calculate bearing
        navigationState.currentBearing = calculateBearing(
            from: location.coordinate,
            to: targetWaypoint.coordinate
        )

        // Update average speed
        if location.speed >= 0 {  // Speed is valid
            speedSamples.append(location.speed)
            if speedSamples.count > maxSpeedSamples {
                speedSamples.removeFirst()
            }
            navigationState.averageSpeed = speedSamples.reduce(0, +) / Double(speedSamples.count)
        }

        // Update ETA
        navigationState.updateETA()
    }

    /// Calculate bearing from one coordinate to another
    func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)
        let degreesBearing = radiansBearing * 180 / .pi

        return (degreesBearing + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Calculate distance between two coordinates
    func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDistance {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation)
    }

    /// Calculate relative bearing (bearing to target relative to current heading)
    func calculateRelativeBearing() -> Double? {
        guard let currentHeading = compassData.displayHeading,
              let targetBearing = navigationState.currentBearing else {
            return nil
        }

        var relativeBearing = targetBearing - currentHeading
        if relativeBearing < -180 {
            relativeBearing += 360
        } else if relativeBearing > 180 {
            relativeBearing -= 360
        }

        return relativeBearing
    }

    // MARK: - Utility Methods

    /// Get formatted distance string
    func formattedDistance() -> String {
        guard let distance = navigationState.currentDistance else {
            return "---"
        }
        return distance.formattedDistance
    }

    /// Get formatted bearing string
    func formattedBearing() -> String {
        guard let bearing = navigationState.currentBearing else {
            return "---"
        }
        return String(format: "%.0f°", bearing)
    }

    /// Get formatted ETA string
    func formattedETA() -> String {
        guard let eta = navigationState.estimatedTimeOfArrival else {
            return "---"
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: eta)
    }

    /// Get formatted speed string
    func formattedSpeed() -> String {
        guard let speed = navigationState.averageSpeed else {
            return "---"
        }

        let kmh = speed * 3.6
        return String(format: "%.1f km/h", kmh)
    }

    /// Check if we've arrived at the target waypoint
    func hasArrivedAtTarget(threshold: CLLocationDistance = 10.0) -> Bool {
        guard let distance = navigationState.currentDistance else {
            return false
        }
        return distance <= threshold
    }

    // MARK: - Compass Rose Calculations

    /// Get rotation angle for compass needle (pointing to target)
    func compassNeedleRotation() -> Double {
        guard let targetBearing = navigationState.currentBearing,
              let heading = compassData.displayHeading else {
            return 0
        }

        // Calculate relative angle
        return targetBearing - heading
    }

    /// Get rotation angle for compass rose (rotating background)
    func compassRoseRotation() -> Double {
        guard let heading = compassData.displayHeading else {
            return 0
        }

        // Compass rose rotates opposite to heading
        return -heading
    }
}

// MARK: - CLLocationManagerDelegate

extension NavigationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        currentLocation = location

        // Update navigation data if we're navigating
        if navigationState.isNavigating {
            updateNavigationData(location: location)

            // Check if we've arrived
            if hasArrivedAtTarget() {
                #if DEBUG
                print("✅ Arrived at waypoint: \(navigationState.targetWaypoint?.name ?? "Unknown")")
                #endif
                // Could trigger a notification here
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        compassData.magneticHeading = newHeading.magneticHeading
        compassData.trueHeading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : nil
        compassData.headingAccuracy = newHeading.headingAccuracy
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ Location manager error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            #if DEBUG
            print("✅ Location authorization granted")
            #endif
            startLocationUpdates()
        case .denied, .restricted:
            print("❌ Location authorization denied")
        case .notDetermined:
            #if DEBUG
            print("⏳ Location authorization not determined")
            #endif
        @unknown default:
            break
        }
    }
}

// MARK: - Navigation Helper Extensions

extension NavigationService {
    /// Get waypoint distance from current location
    func distance(to waypoint: Waypoint) -> CLLocationDistance? {
        guard let location = currentLocation else { return nil }

        let waypointLocation = CLLocation(
            latitude: waypoint.coordinate.latitude,
            longitude: waypoint.coordinate.longitude
        )

        return location.distance(from: waypointLocation)
    }

    /// Get bearing to waypoint from current location
    func bearing(to waypoint: Waypoint) -> Double? {
        guard let location = currentLocation else { return nil }

        return calculateBearing(
            from: location.coordinate,
            to: waypoint.coordinate
        )
    }

    /// Get formatted distance to waypoint
    func formattedDistance(to waypoint: Waypoint) -> String {
        guard let distance = distance(to: waypoint) else {
            return "---"
        }
        return distance.formattedDistance
    }

    /// Get formatted bearing to waypoint
    func formattedBearing(to waypoint: Waypoint) -> String {
        guard let bearing = bearing(to: waypoint) else {
            return "---"
        }
        return String(format: "%.0f°", bearing)
    }
}

// MARK: - Navigation Alerts

extension NavigationService {
    /// Configuration for arrival alert
    struct ArrivalAlertConfig {
        var enabled: Bool = true
        var threshold: CLLocationDistance = 10.0  // meters
        var soundEnabled: Bool = true
    }

    private static var arrivalAlertConfig = ArrivalAlertConfig()

    static func configureArrivalAlert(enabled: Bool, threshold: CLLocationDistance, soundEnabled: Bool) {
        arrivalAlertConfig = ArrivalAlertConfig(
            enabled: enabled,
            threshold: threshold,
            soundEnabled: soundEnabled
        )
    }
}
