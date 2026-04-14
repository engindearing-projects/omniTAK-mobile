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

    // MARK: - Navigation State
    @Published var isMuted: Bool = false {
        didSet {
            voiceService.isMuted = isMuted
        }
    }
    @Published var currentSpeed: Double = 0 // m/s
    @Published var proximityAlert: ProximityAlert = .none

    // MARK: - Off-Route Detection (ATAK-style)
    @Published var isOffRoute: Bool = false
    @Published var offRouteDistance: Double = 0 // meters from route
    @Published var offRouteThreshold: Double = 150 // ATAK default: 150 meters
    @Published var autoRerouteEnabled: Bool = true

    // MARK: - Breadcrumb Trail (ATAK-style)
    @Published var breadcrumbTrail: [CLLocationCoordinate2D] = []
    @Published var breadcrumbEnabled: Bool = true
    @Published var totalTraveledDistance: Double = 0 // meters actually traveled
    private var lastBreadcrumbLocation: CLLocation?
    private let breadcrumbMinDistance: Double = 10 // Minimum meters between breadcrumb points

    // MARK: - Self-Healing Route (ATAK-style)
    @Published var selfHealingEnabled: Bool = true
    /// Callback for route overlay updates - called when navigation progress changes
    var onRouteOverlayUpdate: ((Route, CLLocationCoordinate2D, Int) -> Void)?

    // MARK: - Private Properties

    private let locationManager = CLLocationManager()
    private let storageManager = RouteStorageManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var navigationTimer: Timer?
    private let voiceService = NavigationVoiceService.shared

    // Track which proximity thresholds have been announced for current waypoint
    private var announcedApproachThresholds: Set<Int> = [] // 500m, 200m, 100m
    private var hasAnnouncedCurrentWaypoint: Bool = false

    // Off-route tracking
    private var hasAnnouncedOffRoute: Bool = false
    private var lastOffRouteTime: Date?

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
    func createRoute(
        name: String,
        waypoints: [RouteWaypoint],
        color: String = "#FFFC00",
        lineStyle: RouteLineStyle = .solid,
        lineOpacity: Double = 1.0,
        lineWidth: Double = 4.0,
        waypointIconStyle: WaypointIconStyle = .numbered,
        waypointPrefix: String = "",
        showDirectionArrows: Bool = false
    ) -> Route {
        var route = Route(
            name: name,
            waypoints: waypoints,
            color: color,
            lineStyle: lineStyle,
            lineOpacity: lineOpacity,
            lineWidth: lineWidth,
            waypointIconStyle: waypointIconStyle,
            waypointPrefix: waypointPrefix,
            showDirectionArrows: showDirectionArrows
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

        // Reset voice announcement tracking
        resetApproachAnnouncements()

        // Reset breadcrumb trail for new navigation
        resetBreadcrumbTrail()

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

        // ATAK-style voice announcement for navigation start
        voiceService.announceNavigationStart(
            routeName: route.name,
            totalCheckpoints: route.waypoints.count
        )
    }

    /// Skip to next waypoint
    func skipToNextWaypoint() {
        guard isNavigating,
              let route = activeRoute,
              var progress = routeProgress else { return }

        let nextIndex = progress.currentWaypointIndex + 1
        guard nextIndex < route.waypoints.count else {
            // Already at last waypoint
            return
        }

        progress.currentWaypointIndex = nextIndex
        let nextWaypoint = route.waypoints[nextIndex]
        progress.currentInstruction = nextWaypoint.instruction ?? "Continue to \(nextWaypoint.name)"

        routeProgress = progress

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Skip to previous waypoint
    func skipToPreviousWaypoint() {
        guard isNavigating,
              let route = activeRoute,
              var progress = routeProgress else { return }

        let prevIndex = progress.currentWaypointIndex - 1
        guard prevIndex >= 0 else {
            // Already at first waypoint
            return
        }

        progress.currentWaypointIndex = prevIndex
        let prevWaypoint = route.waypoints[prevIndex]
        progress.currentInstruction = prevWaypoint.instruction ?? "Continue to \(prevWaypoint.name)"

        routeProgress = progress

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    /// Toggle mute state
    func toggleMute() {
        isMuted.toggle()

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
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

    /// Update proximity alert based on distance to next waypoint
    private func updateProximityAlert(distance: Double, waypoint: RouteWaypoint) {
        let previousAlert = proximityAlert

        if distance < 20 {
            proximityAlert = .arrived
        } else if distance < 50 {
            proximityAlert = .imminent
        } else if distance < 200 {
            proximityAlert = .near
        } else if distance < 500 {
            proximityAlert = .approaching
        } else {
            proximityAlert = .far
        }

        // Trigger haptic feedback on alert level change
        if previousAlert != proximityAlert && proximityAlert != .far {
            let generator = UIImpactFeedbackGenerator(style: proximityAlert == .imminent ? .heavy : .light)
            generator.impactOccurred()
        }

        // ATAK-style voice announcements at proximity thresholds
        announceProximityThreshold(distance: distance, waypoint: waypoint)
    }

    /// Announce approach at specific distance thresholds (ATAK-style)
    private func announceProximityThreshold(distance: Double, waypoint: RouteWaypoint) {
        // Announce at 500m, 200m, 100m thresholds
        let thresholds: [(distance: Int, meters: Double)] = [
            (500, 500.0),
            (200, 200.0),
            (100, 100.0)
        ]

        for threshold in thresholds {
            if distance <= threshold.meters && !announcedApproachThresholds.contains(threshold.distance) {
                announcedApproachThresholds.insert(threshold.distance)

                // Use custom approach cue if available
                voiceService.announceApproaching(
                    waypointName: waypoint.name,
                    distance: distance,
                    customCue: waypoint.approachCue
                )
                break // Only announce one threshold at a time
            }
        }
    }

    /// Reset approach announcements for new waypoint
    private func resetApproachAnnouncements() {
        announcedApproachThresholds.removeAll()
        hasAnnouncedCurrentWaypoint = false
    }

    // MARK: - Breadcrumb Trail Recording

    /// Record a breadcrumb point during navigation
    private func recordBreadcrumb(location: CLLocation) {
        guard breadcrumbEnabled else { return }

        // Check minimum distance from last breadcrumb
        if let lastLocation = lastBreadcrumbLocation {
            let distance = location.distance(from: lastLocation)

            // Only add if moved minimum distance
            if distance < breadcrumbMinDistance {
                return
            }

            // Track total traveled distance
            totalTraveledDistance += distance
        }

        // Add breadcrumb point
        breadcrumbTrail.append(location.coordinate)
        lastBreadcrumbLocation = location
    }

    /// Reset breadcrumb trail for new navigation
    private func resetBreadcrumbTrail() {
        breadcrumbTrail.removeAll()
        lastBreadcrumbLocation = nil
        totalTraveledDistance = 0
    }

    /// Get distance difference (positive = saved distance, negative = extra distance)
    var distanceDifference: Double {
        guard let route = activeRoute else { return 0 }
        return route.totalDistance - totalTraveledDistance
    }

    /// Formatted distance difference string
    var formattedDistanceDifference: String {
        let diff = distanceDifference
        if abs(diff) < 50 {
            return "On track"
        } else if diff > 0 {
            return String(format: "%.0fm saved", diff)
        } else {
            return String(format: "%.0fm extra", abs(diff))
        }
    }

    // MARK: - Off-Route Detection (ATAK-style)

    /// Check if user is off-route and handle accordingly
    private func checkOffRouteStatus(location: CLLocation, route: Route) {
        // Calculate perpendicular distance to route polyline
        let distanceToRoute = calculateDistanceToRoute(location: location, route: route)
        offRouteDistance = distanceToRoute

        let wasOffRoute = isOffRoute
        isOffRoute = distanceToRoute > offRouteThreshold

        if isOffRoute && !wasOffRoute {
            // Just went off-route
            handleOffRoute(distance: distanceToRoute)
        } else if !isOffRoute && wasOffRoute {
            // Back on route
            handleBackOnRoute()
        }
    }

    /// Calculate perpendicular distance from location to nearest point on route
    private func calculateDistanceToRoute(location: CLLocation, route: Route) -> Double {
        let coordinates = route.allCoordinates
        guard coordinates.count >= 2 else {
            return 0
        }

        var minDistance = Double.greatestFiniteMagnitude

        // Check distance to each segment of the route
        for i in 0..<(coordinates.count - 1) {
            let segmentStart = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
            let segmentEnd = CLLocation(latitude: coordinates[i + 1].latitude, longitude: coordinates[i + 1].longitude)

            let distance = perpendicularDistance(
                from: location,
                toLineFrom: segmentStart,
                to: segmentEnd
            )

            minDistance = min(minDistance, distance)
        }

        return minDistance == Double.greatestFiniteMagnitude ? 0 : minDistance
    }

    /// Calculate perpendicular distance from point to line segment
    private func perpendicularDistance(from point: CLLocation, toLineFrom lineStart: CLLocation, to lineEnd: CLLocation) -> Double {
        let px = point.coordinate.latitude
        let py = point.coordinate.longitude
        let ax = lineStart.coordinate.latitude
        let ay = lineStart.coordinate.longitude
        let bx = lineEnd.coordinate.latitude
        let by = lineEnd.coordinate.longitude

        let dx = bx - ax
        let dy = by - ay

        // If line segment is actually a point
        if dx == 0 && dy == 0 {
            return point.distance(from: lineStart)
        }

        // Calculate parameter t for closest point on line
        let t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))

        // Find closest point on line segment
        let closestLat = ax + t * dx
        let closestLon = ay + t * dy
        let closestPoint = CLLocation(latitude: closestLat, longitude: closestLon)

        return point.distance(from: closestPoint)
    }

    /// Handle going off-route
    private func handleOffRoute(distance: Double) {
        // Announce off-route only once per off-route event
        if !hasAnnouncedOffRoute {
            hasAnnouncedOffRoute = true
            lastOffRouteTime = Date()

            // Voice announcement
            voiceService.announceOffRoute(distance: distance)

            // Haptic feedback - warning
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        }

        // Auto-reroute if enabled and been off-route for 10+ seconds
        if autoRerouteEnabled,
           let offRouteTime = lastOffRouteTime,
           Date().timeIntervalSince(offRouteTime) > 10 {
            recalculateRouteFromCurrentPosition()
        }
    }

    /// Handle getting back on route
    private func handleBackOnRoute() {
        hasAnnouncedOffRoute = false
        lastOffRouteTime = nil

        // Haptic feedback - success
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Recalculate route from current position to remaining waypoints
    func recalculateRouteFromCurrentPosition() {
        guard let location = currentLocation,
              let route = activeRoute,
              let progress = routeProgress else { return }

        // Get remaining waypoints starting from current target
        let remainingWaypoints = Array(route.waypoints[progress.currentWaypointIndex...])

        guard !remainingWaypoints.isEmpty else { return }

        // Create new waypoint for current location
        var newWaypoints = [RouteWaypoint(
            coordinate: location.coordinate,
            name: "Current Position",
            order: 0
        )]

        // Add remaining waypoints with updated order
        for (index, waypoint) in remainingWaypoints.enumerated() {
            var updatedWaypoint = waypoint
            updatedWaypoint.order = index + 1
            newWaypoints.append(updatedWaypoint)
        }

        // Create updated route
        var newRoute = route
        newRoute.waypoints = newWaypoints
        newRoute.segments = [] // Clear segments to trigger recalculation

        // Recalculate directions
        calculateRouteDirections(for: newRoute) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updatedRoute):
                    self?.activeRoute = updatedRoute
                    self?.hasAnnouncedOffRoute = false
                    self?.lastOffRouteTime = nil
                    self?.isOffRoute = false
                    self?.voiceService.announceRouteRecalculated()
                case .failure(let error):
                    self?.error = "Failed to recalculate route: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Update navigation progress based on current location
    private func updateNavigationProgress() {
        guard isNavigating,
              let route = activeRoute,
              let location = currentLocation,
              var progress = routeProgress else { return }

        // Update current speed
        currentSpeed = max(0, location.speed)

        // Record breadcrumb trail (ATAK-style)
        recordBreadcrumb(location: location)

        // Check off-route status (ATAK-style 150m default threshold)
        checkOffRouteStatus(location: location, route: route)

        let currentIndex = progress.currentWaypointIndex
        guard currentIndex < route.waypoints.count else {
            stopNavigation()
            return
        }

        let targetWaypoint = route.waypoints[currentIndex]

        // Calculate distance to target - use route path distance when available
        let distanceToTarget: Double
        if !route.segments.isEmpty {
            // Use route-aware distance calculation (accounts for road path)
            distanceToTarget = calculateDistanceAlongRoute(from: location, toWaypointIndex: currentIndex, route: route)
        } else {
            // Fallback to straight-line distance
            distanceToTarget = location.distance(from: targetWaypoint.clLocation)
        }

        // Update proximity alert based on distance
        updateProximityAlert(distance: distanceToTarget, waypoint: targetWaypoint)

        // Check if reached waypoint (within 30 meters for route-based, 20 for straight-line)
        let arrivalThreshold: Double = route.segments.isEmpty ? 20 : 30
        if distanceToTarget < arrivalThreshold {
            proximityAlert = .arrived
            // Haptic feedback for waypoint reached
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()

            // Voice announcement for waypoint arrival
            if !hasAnnouncedCurrentWaypoint {
                hasAnnouncedCurrentWaypoint = true

                let isLastWaypoint = currentIndex == route.waypoints.count - 1
                if isLastWaypoint {
                    // Final destination
                    voiceService.announceArrival(
                        waypointName: targetWaypoint.name,
                        customCue: targetWaypoint.arrivalCue
                    )
                } else {
                    // Checkpoint reached
                    voiceService.announceCheckpointReached(
                        waypointName: targetWaypoint.name,
                        checkpointNumber: currentIndex + 1,
                        totalCheckpoints: route.waypoints.count
                    )
                }
            }

            // Move to next waypoint
            progress.currentWaypointIndex += 1
            resetApproachAnnouncements() // Reset for next waypoint

            if progress.currentWaypointIndex >= route.waypoints.count {
                // Route completed
                voiceService.announceNavigationComplete(routeName: route.name)
                stopNavigation()
                return
            }
        }

        // Update distance to next waypoint
        if progress.currentWaypointIndex < route.waypoints.count {
            let nextWaypoint = route.waypoints[progress.currentWaypointIndex]

            // Use route path distance when segments are available
            if !route.segments.isEmpty {
                progress.distanceToNextWaypoint = calculateDistanceAlongRoute(from: location, toWaypointIndex: progress.currentWaypointIndex, route: route)
            } else {
                progress.distanceToNextWaypoint = location.distance(from: nextWaypoint.clLocation)
            }

            progress.timeToNextWaypoint = progress.distanceToNextWaypoint / preferredAverageSpeed
            progress.currentInstruction = nextWaypoint.instruction ?? "Continue to \(nextWaypoint.name)"
        }

        // Calculate remaining distance using segment distances (road distance)
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
            progress.percentComplete = max(0, min(100, (traveled / route.totalDistance) * 100))
        }

        routeProgress = progress

        // Trigger self-healing route overlay update
        if selfHealingEnabled, let currentCoord = currentLocation?.coordinate {
            onRouteOverlayUpdate?(route, currentCoord, progress.currentWaypointIndex)
        }
    }

    /// Calculate distance along the route path from current location to a waypoint
    /// This accounts for the actual road/path distance, not straight-line distance
    private func calculateDistanceAlongRoute(from location: CLLocation, toWaypointIndex waypointIndex: Int, route: Route) -> Double {
        guard waypointIndex < route.waypoints.count else { return 0 }

        let targetWaypoint = route.waypoints[waypointIndex]

        // If no segments, fallback to straight-line
        guard !route.segments.isEmpty else {
            return location.distance(from: targetWaypoint.clLocation)
        }

        // Find the closest point on the route to current location
        let allCoordinates = route.allCoordinates
        guard allCoordinates.count >= 2 else {
            return location.distance(from: targetWaypoint.clLocation)
        }

        // Find closest segment and point on route
        var closestDistance = Double.greatestFiniteMagnitude
        var closestSegmentIndex = 0
        var closestPointOnRoute: CLLocationCoordinate2D = allCoordinates[0]

        for i in 0..<(allCoordinates.count - 1) {
            let segmentStart = CLLocation(latitude: allCoordinates[i].latitude, longitude: allCoordinates[i].longitude)
            let segmentEnd = CLLocation(latitude: allCoordinates[i + 1].latitude, longitude: allCoordinates[i + 1].longitude)

            let (closestPoint, distance) = closestPointOnSegment(from: location, segmentStart: segmentStart, segmentEnd: segmentEnd)

            if distance < closestDistance {
                closestDistance = distance
                closestSegmentIndex = i
                closestPointOnRoute = closestPoint
            }
        }

        // Find the index of the target waypoint in allCoordinates
        var targetCoordIndex = allCoordinates.count - 1
        for (idx, coord) in allCoordinates.enumerated() {
            let coordLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            if coordLoc.distance(from: targetWaypoint.clLocation) < 10 {
                targetCoordIndex = idx
                break
            }
        }

        // If we're past the target, return straight-line distance to it
        if closestSegmentIndex >= targetCoordIndex {
            return location.distance(from: targetWaypoint.clLocation)
        }

        // Calculate distance along route from closest point to target
        var totalDistance: Double = 0

        // Distance from closest point to end of current segment
        let segmentEnd = CLLocation(latitude: allCoordinates[closestSegmentIndex + 1].latitude,
                                     longitude: allCoordinates[closestSegmentIndex + 1].longitude)
        let closestLoc = CLLocation(latitude: closestPointOnRoute.latitude, longitude: closestPointOnRoute.longitude)
        totalDistance += closestLoc.distance(from: segmentEnd)

        // Add distances for intermediate segments
        for i in (closestSegmentIndex + 1)..<targetCoordIndex {
            let start = CLLocation(latitude: allCoordinates[i].latitude, longitude: allCoordinates[i].longitude)
            let end = CLLocation(latitude: allCoordinates[i + 1].latitude, longitude: allCoordinates[i + 1].longitude)
            totalDistance += start.distance(from: end)
        }

        return totalDistance
    }

    /// Find the closest point on a line segment to a given location
    private func closestPointOnSegment(from point: CLLocation, segmentStart: CLLocation, segmentEnd: CLLocation) -> (CLLocationCoordinate2D, Double) {
        let px = point.coordinate.latitude
        let py = point.coordinate.longitude
        let ax = segmentStart.coordinate.latitude
        let ay = segmentStart.coordinate.longitude
        let bx = segmentEnd.coordinate.latitude
        let by = segmentEnd.coordinate.longitude

        let dx = bx - ax
        let dy = by - ay

        // If segment is a point
        if dx == 0 && dy == 0 {
            return (segmentStart.coordinate, point.distance(from: segmentStart))
        }

        // Calculate parameter t for closest point
        let t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))

        // Find closest point
        let closestLat = ax + t * dx
        let closestLon = ay + t * dy
        let closestCoord = CLLocationCoordinate2D(latitude: closestLat, longitude: closestLon)
        let closestLoc = CLLocation(latitude: closestLat, longitude: closestLon)

        return (closestCoord, point.distance(from: closestLoc))
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

// MARK: - Proximity Alert Level

enum ProximityAlert: String {
    case none = "none"
    case far = "far"           // > 500m - Green
    case approaching = "approaching"  // 200-500m - Flashing Green
    case near = "near"         // 50-200m - Flashing Yellow
    case imminent = "imminent" // < 50m - Flashing Red
    case arrived = "arrived"   // < 20m

    var color: String {
        switch self {
        case .none, .far: return "#00FF00" // Green
        case .approaching: return "#00FF00" // Green (flashing)
        case .near: return "#FFFF00" // Yellow (flashing)
        case .imminent: return "#FF0000" // Red (flashing)
        case .arrived: return "#00FF00" // Green
        }
    }

    var shouldFlash: Bool {
        switch self {
        case .approaching, .near, .imminent: return true
        default: return false
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
