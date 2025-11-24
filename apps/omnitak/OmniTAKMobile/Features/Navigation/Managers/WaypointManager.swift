//
//  WaypointManager.swift
//  OmniTAKMobile
//
//  Manages waypoint CRUD operations and persistence
//

import Foundation
import Combine
import CoreLocation
import MapKit

// MARK: - Waypoint Manager

/// Centralized manager for waypoint operations
class WaypointManager: ObservableObject {
    // Published properties
    @Published var waypoints: [Waypoint] = []
    @Published var routes: [WaypointRoute] = []
    @Published var selectedWaypoint: Waypoint?

    // Persistence
    private let persistence: WaypointPersistence
    private var cancellables = Set<AnyCancellable>()

    // Singleton instance
    static let shared = WaypointManager()

    init(persistence: WaypointPersistence = WaypointPersistence()) {
        self.persistence = persistence
        loadAllWaypoints()
        loadAllRoutes()
    }

    // MARK: - Waypoint CRUD Operations

    /// Create a new waypoint
    func createWaypoint(
        name: String,
        coordinate: CLLocationCoordinate2D,
        altitude: Double? = nil,
        remarks: String? = nil,
        icon: WaypointIcon = .waypoint,
        color: WaypointColor = .blue,
        createdBy: String? = nil
    ) -> Waypoint {
        let waypoint = Waypoint(
            name: name,
            remarks: remarks,
            coordinate: coordinate,
            altitude: altitude,
            icon: icon,
            color: color,
            createdBy: createdBy
        )

        waypoints.append(waypoint)
        saveWaypoints()

        #if DEBUG
        print("📍 Created waypoint: \(name) at (\(coordinate.latitude), \(coordinate.longitude))")
        #endif
        return waypoint
    }

    /// Get waypoint by ID
    func getWaypoint(id: UUID) -> Waypoint? {
        return waypoints.first { $0.id == id }
    }

    /// Get waypoint by UID
    func getWaypoint(uid: String) -> Waypoint? {
        return waypoints.first { $0.uid == uid }
    }

    /// Update an existing waypoint
    func updateWaypoint(_ waypoint: Waypoint) {
        if let index = waypoints.firstIndex(where: { $0.id == waypoint.id }) {
            var updatedWaypoint = waypoint
            updatedWaypoint.touch()
            waypoints[index] = updatedWaypoint
            saveWaypoints()
            #if DEBUG
            print("✏️ Updated waypoint: \(waypoint.name)")
            #endif
        }
    }

    /// Delete a waypoint
    func deleteWaypoint(_ waypoint: Waypoint) {
        waypoints.removeAll { $0.id == waypoint.id }

        // Remove from any routes
        for index in routes.indices {
            routes[index].removeWaypoint(waypoint.id)
        }

        saveWaypoints()
        saveRoutes()
        #if DEBUG
        print("🗑️ Deleted waypoint: \(waypoint.name)")
        #endif
    }

    /// Delete waypoint by ID
    func deleteWaypoint(id: UUID) {
        if let waypoint = getWaypoint(id: id) {
            deleteWaypoint(waypoint)
        }
    }

    /// Delete all waypoints
    func deleteAllWaypoints() {
        waypoints.removeAll()
        routes.removeAll()
        saveWaypoints()
        saveRoutes()
        #if DEBUG
        print("🗑️ Deleted all waypoints and routes")
        #endif
    }

    /// Get waypoints sorted by distance from a location
    func waypointsSortedByDistance(from location: CLLocation) -> [Waypoint] {
        return waypoints.sorted { waypoint1, waypoint2 in
            let loc1 = CLLocation(latitude: waypoint1.coordinate.latitude,
                                longitude: waypoint1.coordinate.longitude)
            let loc2 = CLLocation(latitude: waypoint2.coordinate.latitude,
                                longitude: waypoint2.coordinate.longitude)

            return location.distance(from: loc1) < location.distance(from: loc2)
        }
    }

    /// Get waypoints within a radius
    func waypointsNear(location: CLLocation, radius: CLLocationDistance) -> [Waypoint] {
        return waypoints.filter { waypoint in
            let waypointLocation = CLLocation(
                latitude: waypoint.coordinate.latitude,
                longitude: waypoint.coordinate.longitude
            )
            return location.distance(from: waypointLocation) <= radius
        }
    }

    /// Search waypoints by name
    func searchWaypoints(query: String) -> [Waypoint] {
        guard !query.isEmpty else { return waypoints }

        return waypoints.filter { waypoint in
            waypoint.name.localizedCaseInsensitiveContains(query) ||
            (waypoint.remarks?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    // MARK: - Route CRUD Operations

    /// Create a new route
    func createRoute(name: String, color: WaypointColor = .blue) -> WaypointRoute {
        let route = WaypointRoute(name: name, color: color)
        routes.append(route)
        saveRoutes()
        #if DEBUG
        print("🛣️ Created route: \(name)")
        #endif
        return route
    }

    /// Get route by ID
    func getRoute(id: UUID) -> WaypointRoute? {
        return routes.first { $0.id == id }
    }

    /// Update a route
    func updateRoute(_ route: WaypointRoute) {
        if let index = routes.firstIndex(where: { $0.id == route.id }) {
            routes[index] = route
            saveRoutes()
            #if DEBUG
            print("✏️ Updated route: \(route.name)")
            #endif
        }
    }

    /// Delete a route
    func deleteRoute(_ route: WaypointRoute) {
        routes.removeAll { $0.id == route.id }
        saveRoutes()
        #if DEBUG
        print("🗑️ Deleted route: \(route.name)")
        #endif
    }

    /// Add waypoint to route
    func addWaypointToRoute(waypointId: UUID, routeId: UUID) {
        if let index = routes.firstIndex(where: { $0.id == routeId }) {
            routes[index].addWaypoint(waypointId)
            saveRoutes()
        }
    }

    /// Remove waypoint from route
    func removeWaypointFromRoute(waypointId: UUID, routeId: UUID) {
        if let index = routes.firstIndex(where: { $0.id == routeId }) {
            routes[index].removeWaypoint(waypointId)
            saveRoutes()
        }
    }

    /// Get waypoints for a route
    func getWaypointsForRoute(_ route: WaypointRoute) -> [Waypoint] {
        return route.waypoints.compactMap { waypointId in
            getWaypoint(id: waypointId)
        }
    }

    /// Create polyline overlay for a route
    func createRouteOverlay(_ route: WaypointRoute) -> MKPolyline? {
        let routeWaypoints = getWaypointsForRoute(route)
        guard routeWaypoints.count >= 2 else { return nil }

        let coordinates = routeWaypoints.map { $0.coordinate }
        return MKPolyline(coordinates: coordinates, count: coordinates.count)
    }

    // MARK: - Import/Export

    /// Import waypoint from CoT message
    func importFromCoT(uid: String, type: String, coordinate: CLLocationCoordinate2D,
                      callsign: String, altitude: Double? = nil, remarks: String? = nil) -> Waypoint? {
        // Check if waypoint already exists
        if let existing = getWaypoint(uid: uid) {
            var updated = existing
            updated.modifiedAt = Date()
            updateWaypoint(updated)
            return updated
        }

        // Create new waypoint
        var waypoint = Waypoint(
            name: callsign,
            remarks: remarks,
            coordinate: coordinate,
            altitude: altitude,
            icon: .waypoint,
            color: .blue
        )
        waypoint.uid = uid
        waypoint.cotType = type

        waypoints.append(waypoint)
        saveWaypoints()

        #if DEBUG
        print("📥 Imported waypoint from CoT: \(callsign)")
        #endif
        return waypoint
    }

    /// Export waypoint to CoT XML
    func exportToCoT(_ waypoint: Waypoint, staleTime: TimeInterval = 3600) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let now = Date()
        let stale = now.addingTimeInterval(staleTime)

        let lat = waypoint.coordinate.latitude
        let lon = waypoint.coordinate.longitude
        let hae = waypoint.altitude ?? 0.0

        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(waypoint.uid)" type="\(waypoint.cotType)" time="\(dateFormatter.string(from: now))" start="\(dateFormatter.string(from: now))" stale="\(dateFormatter.string(from: stale))">
            <point lat="\(lat)" lon="\(lon)" hae="\(hae)" ce="10.0" le="10.0"/>
            <detail>
                <contact callsign="\(waypoint.name)"/>
                <usericon iconsetpath="\(waypoint.icon.cotIconType)"/>
                <color value="\(waypoint.color.cotColorHex)"/>
        """

        if let remarks = waypoint.remarks {
            xml += "\n        <remarks>\(remarks)</remarks>"
        }

        xml += """

            </detail>
        </event>
        """

        return xml
    }

    // MARK: - Map Annotations

    /// Get all waypoint annotations for map display
    func getAllAnnotations() -> [WaypointAnnotation] {
        return waypoints.map { $0.createAnnotation() }
    }

    /// Get annotations for specific waypoints
    func getAnnotations(for waypointIds: [UUID]) -> [WaypointAnnotation] {
        return waypoints
            .filter { waypointIds.contains($0.id) }
            .map { $0.createAnnotation() }
    }

    // MARK: - Persistence

    private func loadAllWaypoints() {
        waypoints = persistence.loadWaypoints()
        #if DEBUG
        print("📂 Loaded \(waypoints.count) waypoints")
        #endif
    }

    private func saveWaypoints() {
        persistence.saveWaypoints(waypoints)
    }

    private func loadAllRoutes() {
        routes = persistence.loadRoutes()
        #if DEBUG
        print("📂 Loaded \(routes.count) routes")
        #endif
    }

    private func saveRoutes() {
        persistence.saveRoutes(routes)
    }

    // MARK: - Statistics

    var waypointCount: Int {
        waypoints.count
    }

    var routeCount: Int {
        routes.count
    }

    func waypointsByIcon() -> [WaypointIcon: Int] {
        var counts: [WaypointIcon: Int] = [:]
        for waypoint in waypoints {
            counts[waypoint.icon, default: 0] += 1
        }
        return counts
    }

    func waypointsByColor() -> [WaypointColor: Int] {
        var counts: [WaypointColor: Int] = [:]
        for waypoint in waypoints {
            counts[waypoint.color, default: 0] += 1
        }
        return counts
    }
}

// MARK: - Waypoint Persistence

/// Handles saving and loading waypoints using UserDefaults
class WaypointPersistence {
    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private let waypointsKey = "WaypointManager.waypoints"
    private let routesKey = "WaypointManager.routes"

    // MARK: - Waypoints

    func saveWaypoints(_ waypoints: [Waypoint]) {
        do {
            let data = try encoder.encode(waypoints)
            userDefaults.set(data, forKey: waypointsKey)
            #if DEBUG
            print("💾 Saved \(waypoints.count) waypoints to UserDefaults")
            #endif
        } catch {
            print("❌ Failed to save waypoints: \(error)")
        }
    }

    func loadWaypoints() -> [Waypoint] {
        guard let data = userDefaults.data(forKey: waypointsKey) else {
            return []
        }

        do {
            let waypoints = try decoder.decode([Waypoint].self, from: data)
            return waypoints
        } catch {
            print("❌ Failed to load waypoints: \(error)")
            return []
        }
    }

    // MARK: - Routes

    func saveRoutes(_ routes: [WaypointRoute]) {
        do {
            let data = try encoder.encode(routes)
            userDefaults.set(data, forKey: routesKey)
            #if DEBUG
            print("💾 Saved \(routes.count) routes to UserDefaults")
            #endif
        } catch {
            print("❌ Failed to save routes: \(error)")
        }
    }

    func loadRoutes() -> [WaypointRoute] {
        guard let data = userDefaults.data(forKey: routesKey) else {
            return []
        }

        do {
            let routes = try decoder.decode([WaypointRoute].self, from: data)
            return routes
        } catch {
            print("❌ Failed to load routes: \(error)")
            return []
        }
    }

    // MARK: - Clear All

    func clearAll() {
        userDefaults.removeObject(forKey: waypointsKey)
        userDefaults.removeObject(forKey: routesKey)
        #if DEBUG
        print("🗑️ Cleared all waypoint data from UserDefaults")
        #endif
    }
}
