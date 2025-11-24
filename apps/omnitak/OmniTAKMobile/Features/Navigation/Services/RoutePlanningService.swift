//
//  RoutePlanningService.swift
//  OmniTAKMobile
//
//  Core service for route planning and navigation
//

import Foundation
import CoreLocation
import MapKit
import Combine

// MARK: - Route Planning Service

/// Core service for planning, calculating, and managing routes
class RoutePlanningService: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var activeRoute: Route?
    @Published var routes: [Route] = []
    @Published var isCalculating: Bool = false
    @Published var calculationProgress: Double = 0
    @Published var currentLocation: CLLocation?
    @Published var routeProgress: RouteProgress?
    @Published var isNavigating: Bool = false
    @Published var error: String?

    // MARK: - Private Properties

    private let locationManager = CLLocationManager()
    private let storageManager = RouteStorageManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var navigationTimer: Timer?

    // Singleton
    static let shared = RoutePlanningService()

    // MARK: - Configuration

    var transportType: TransportType = .automobile
    var preferredAverageSpeed: Double = 13.4 // m/s (about 30 mph or 48 km/h)

    // MARK: - Initialization

    override init() {
        super.init()
        setupLocationManager()
        loadRoutes()
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        locationManager.requestWhenInUseAuthorization()
    }

    private func loadRoutes() {
        routes = storageManager.loadRoutes()
    }

    // MARK: - Route Creation

    /// Create a new route from waypoints
    func createRoute(name: String, waypoints: [RouteWaypoint], color: String = "#FFFC00") -> Route {
        var route = Route(
            name: name,
            waypoints: waypoints,
            color: color
        )

        // Calculate straight-line distances as initial estimate
        calculateStraightLineDistances(for: &route)

        routes.insert(route, at: 0)
        storageManager.saveRoute(route)

        return route
    }

    /// Calculate straight-line distances between waypoints (fallback)
    private func calculateStraightLineDistances(for route: inout Route) {
        var totalDist: Double = 0
        var totalTime: TimeInterval = 0

        for i in 0..<route.waypoints.count - 1 {
            let loc1 = route.waypoints[i].clLocation
            let loc2 = route.waypoints[i + 1].clLocation
            let distance = loc1.distance(from: loc2)

            route.waypoints[i].distanceToNext = distance
            let time = distance / preferredAverageSpeed
            route.waypoints[i].timeToNext = time

            totalDist += distance
            totalTime += time
        }

        route.totalDistance = totalDist
        route.estimatedTime = totalTime
    }

    // MARK: - Route Calculation with Directions

    /// Calculate detailed route with turn-by-turn directions using MKDirections
    func calculateRouteDirections(for route: Route, completion: @escaping (Result<Route, Error>) -> Void) {
        guard route.waypoints.count >= 2 else {
            completion(.failure(RoutePlanningError.insufficientWaypoints))
            return
        }

        isCalculating = true
        calculationProgress = 0
        error = nil

        var updatedRoute = route
        updatedRoute.segments = []

        let totalSegments = route.waypoints.count - 1
        var completedSegments = 0
        var allSegments: [RouteSegment] = []

        // Calculate each segment
        for i in 0..<totalSegments {
            let startWaypoint = route.waypoints[i]
            let endWaypoint = route.waypoints[i + 1]

            calculateSegment(from: startWaypoint, to: endWaypoint) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let segment):
                    allSegments.append(segment)

                case .failure(let error):
                    print("Segment calculation failed: \(error). Using straight line.")
                    // Fallback to straight line
                    let straightLineSegment = self.createStraightLineSegment(from: startWaypoint, to: endWaypoint)
                    allSegments.append(straightLineSegment)
                }

                completedSegments += 1

                DispatchQueue.main.async {
                    self.calculationProgress = Double(completedSegments) / Double(totalSegments)

                    if completedSegments == totalSegments {
                        // Sort segments by waypoint order
                        allSegments.sort { seg1, seg2 in
                            let order1 = route.waypoints.first { $0.id == seg1.startWaypointId }?.order ?? 0
                            let order2 = route.waypoints.first { $0.id == seg2.startWaypointId }?.order ?? 0
                            return order1 < order2
                        }

                        updatedRoute.segments = allSegments
                        updatedRoute.recalculateTotals()

                        self.isCalculating = false

                        // Update stored route
                        if let index = self.routes.firstIndex(where: { $0.id == updatedRoute.id }) {
                            self.routes[index] = updatedRoute
                        }
                        self.storageManager.saveRoute(updatedRoute)

                        completion(.success(updatedRoute))
                    }
                }
            }
        }
    }

    /// Calculate a single segment between two waypoints
    private func calculateSegment(from start: RouteWaypoint, to end: RouteWaypoint, completion: @escaping (Result<RouteSegment, Error>) -> Void) {
        let request = MKDirections.Request()

        let startPlacemark = MKPlacemark(coordinate: start.coordinate)
        let endPlacemark = MKPlacemark(coordinate: end.coordinate)

        request.source = MKMapItem(placemark: startPlacemark)
        request.destination = MKMapItem(placemark: endPlacemark)
        request.transportType = transportType.mkTransportType
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)

        directions.calculate { response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let route = response?.routes.first else {
                completion(.failure(RoutePlanningError.noRouteFound))
                return
            }

            // Extract path coordinates
            let pointCount = route.polyline.pointCount
            var coordinates = [CLLocationCoordinate2D]()

            let points = route.polyline.points()
            for i in 0..<pointCount {
                let point = points[i]
                let coordinate = point.coordinate
                coordinates.append(coordinate)
            }

            // Extract instructions
            var instructions: [String] = []
            for step in route.steps {
                if !step.instructions.isEmpty {
                    instructions.append(step.instructions)
                }
            }

            let segment = RouteSegment(
                startWaypointId: start.id,
                endWaypointId: end.id,
                path: coordinates,
                distance: route.distance,
                time: route.expectedTravelTime,
                instructions: instructions
            )

            completion(.success(segment))
        }
    }

    /// Create straight-line segment (fallback)
    private func createStraightLineSegment(from start: RouteWaypoint, to end: RouteWaypoint) -> RouteSegment {
        let distance = start.clLocation.distance(from: end.clLocation)
        let time = distance / preferredAverageSpeed

        return RouteSegment(
            startWaypointId: start.id,
            endWaypointId: end.id,
            path: [start.coordinate, end.coordinate],
            distance: distance,
            time: time,
            instructions: ["Head toward \(end.name)"]
        )
    }

    // MARK: - Route Optimization

    /// Optimize waypoint order using nearest neighbor algorithm
    func optimizeWaypointOrder(for route: inout Route) {
        guard route.waypoints.count > 2 else { return }

        var unvisited = Array(route.waypoints.dropFirst().dropLast())
        var optimized: [RouteWaypoint] = [route.waypoints.first!]
        var current = route.waypoints.first!

        while !unvisited.isEmpty {
            var nearestIndex = 0
            var nearestDistance = Double.infinity

            for (index, waypoint) in unvisited.enumerated() {
                let distance = current.clLocation.distance(from: waypoint.clLocation)
                if distance < nearestDistance {
                    nearestDistance = distance
                    nearestIndex = index
                }
            }

            let nearest = unvisited.remove(at: nearestIndex)
            optimized.append(nearest)
            current = nearest
        }

        // Add back the last waypoint if it was different from first
        if route.waypoints.count > 1 {
            optimized.append(route.waypoints.last!)
        }

        // Update order
        for i in 0..<optimized.count {
            optimized[i].order = i
        }

        route.waypoints = optimized
        route.modifiedAt = Date()
        route.segments = [] // Clear segments, need recalculation

        calculateStraightLineDistances(for: &route)
    }

    // MARK: - Navigation

    /// Start navigating along a route
    func startNavigation(for route: Route) {
        guard route.waypoints.count >= 2 else {
            error = "Route must have at least 2 waypoints"
            return
        }

        var navRoute = route
        navRoute.status = .active

        activeRoute = navRoute
        isNavigating = true

        // Initialize progress
        routeProgress = RouteProgress(
            currentWaypointIndex: 0,
            distanceToNextWaypoint: 0,
            timeToNextWaypoint: 0,
            distanceRemaining: route.totalDistance,
            timeRemaining: route.estimatedTime,
            percentComplete: 0,
            currentInstruction: route.waypoints.first?.instruction ?? "Head to \(route.waypoints.first?.name ?? "first waypoint")"
        )

        // Start location updates
        locationManager.startUpdatingLocation()

        // Start navigation timer
        startNavigationTimer()

        // Update stored route
        if let index = routes.firstIndex(where: { $0.id == route.id }) {
            routes[index] = navRoute
            storageManager.saveRoute(navRoute)
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    /// Stop navigation
    func stopNavigation() {
        isNavigating = false

        if var route = activeRoute {
            route.status = .completed
            activeRoute = route

            if let index = routes.firstIndex(where: { $0.id == route.id }) {
                routes[index] = route
                storageManager.saveRoute(route)
            }
        }

        routeProgress = nil
        locationManager.stopUpdatingLocation()
        stopNavigationTimer()

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func startNavigationTimer() {
        navigationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateNavigationProgress()
        }
    }

    private func stopNavigationTimer() {
        navigationTimer?.invalidate()
        navigationTimer = nil
    }

    /// Update navigation progress based on current location
    private func updateNavigationProgress() {
        guard isNavigating,
              let route = activeRoute,
              let location = currentLocation,
              var progress = routeProgress else { return }

        let currentIndex = progress.currentWaypointIndex
        guard currentIndex < route.waypoints.count else {
            stopNavigation()
            return
        }

        let targetWaypoint = route.waypoints[currentIndex]
        let distanceToTarget = location.distance(from: targetWaypoint.clLocation)

        // Check if reached waypoint (within 20 meters)
        if distanceToTarget < 20 {
            // Haptic feedback for waypoint reached
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            // Move to next waypoint
            progress.currentWaypointIndex += 1

            if progress.currentWaypointIndex >= route.waypoints.count {
                // Route completed
                stopNavigation()
                return
            }
        }

        // Update distance to next
        if progress.currentWaypointIndex < route.waypoints.count {
            let nextWaypoint = route.waypoints[progress.currentWaypointIndex]
            progress.distanceToNextWaypoint = location.distance(from: nextWaypoint.clLocation)
            progress.timeToNextWaypoint = progress.distanceToNextWaypoint / preferredAverageSpeed

            progress.currentInstruction = nextWaypoint.instruction ?? "Continue to \(nextWaypoint.name)"
        }

        // Calculate remaining distance
        var remaining: Double = progress.distanceToNextWaypoint
        for i in (progress.currentWaypointIndex)..<(route.waypoints.count - 1) {
            if let dist = route.waypoints[i].distanceToNext {
                remaining += dist
            }
        }

        progress.distanceRemaining = remaining
        progress.timeRemaining = remaining / preferredAverageSpeed
        progress.eta = Date().addingTimeInterval(progress.timeRemaining)

        // Calculate percent complete
        if route.totalDistance > 0 {
            let traveled = route.totalDistance - remaining
            progress.percentComplete = (traveled / route.totalDistance) * 100
        }

        routeProgress = progress
    }

    // MARK: - Route Management

    /// Save a route
    func saveRoute(_ route: Route) {
        var updatedRoute = route
        updatedRoute.modifiedAt = Date()

        if let index = routes.firstIndex(where: { $0.id == route.id }) {
            routes[index] = updatedRoute
        } else {
            routes.insert(updatedRoute, at: 0)
        }

        storageManager.saveRoute(updatedRoute)
    }

    /// Delete a route
    func deleteRoute(_ route: Route) {
        routes.removeAll { $0.id == route.id }
        storageManager.deleteRoute(route)

        if activeRoute?.id == route.id {
            stopNavigation()
            activeRoute = nil
        }
    }

    /// Update route status
    func updateRouteStatus(_ route: Route, status: RouteStatus) {
        guard let index = routes.firstIndex(where: { $0.id == route.id }) else { return }

        var updatedRoute = route
        updatedRoute.status = status
        updatedRoute.modifiedAt = Date()
        routes[index] = updatedRoute

        storageManager.saveRoute(updatedRoute)

        if activeRoute?.id == route.id {
            activeRoute = updatedRoute
        }
    }

    /// Get route by ID
    func getRoute(by id: UUID) -> Route? {
        routes.first { $0.id == id }
    }
}

// MARK: - CLLocationManagerDelegate

extension RoutePlanningService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location

        if isNavigating {
            updateNavigationProgress()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        self.error = error.localizedDescription
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location authorized for route planning")
        case .denied, .restricted:
            error = "Location access denied"
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}

// MARK: - Route Planning Errors

enum RoutePlanningError: LocalizedError {
    case insufficientWaypoints
    case noRouteFound
    case calculationFailed
    case locationNotAvailable

    var errorDescription: String? {
        switch self {
        case .insufficientWaypoints:
            return "Route must have at least 2 waypoints"
        case .noRouteFound:
            return "No route found between waypoints"
        case .calculationFailed:
            return "Failed to calculate route"
        case .locationNotAvailable:
            return "Current location not available"
        }
    }
}
