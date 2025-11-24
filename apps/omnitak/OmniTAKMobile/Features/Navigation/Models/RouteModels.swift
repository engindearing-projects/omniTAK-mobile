//
//  RouteModels.swift
//  OmniTAKMobile
//
//  Data models for route planning and navigation
//

import Foundation
import CoreLocation
import SwiftUI
import MapKit

// MARK: - Route Status

/// Current status of a route
enum RouteStatus: String, Codable, CaseIterable {
    case planning = "Planning"
    case active = "Active"
    case completed = "Completed"
    case shared = "Shared"

    var icon: String {
        switch self {
        case .planning: return "pencil.circle"
        case .active: return "location.fill"
        case .completed: return "checkmark.circle.fill"
        case .shared: return "person.2.fill"
        }
    }

    var color: Color {
        switch self {
        case .planning: return .orange
        case .active: return .green
        case .completed: return .blue
        case .shared: return .purple
        }
    }
}

// MARK: - Route Waypoint

/// A single waypoint in a planned route
struct RouteWaypoint: Identifiable, Codable, Equatable {
    let id: UUID
    var latitude: Double
    var longitude: Double
    var name: String
    var order: Int
    var instruction: String?
    var distanceToNext: Double? // meters
    var timeToNext: TimeInterval? // seconds
    var altitude: Double?

    init(
        id: UUID = UUID(),
        coordinate: CLLocationCoordinate2D,
        name: String,
        order: Int,
        instruction: String? = nil,
        distanceToNext: Double? = nil,
        timeToNext: TimeInterval? = nil,
        altitude: Double? = nil
    ) {
        self.id = id
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.name = name
        self.order = order
        self.instruction = instruction
        self.distanceToNext = distanceToNext
        self.timeToNext = timeToNext
        self.altitude = altitude
    }

    /// Get CLLocationCoordinate2D
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Get CLLocation
    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    /// Formatted distance to next waypoint
    var formattedDistanceToNext: String {
        guard let distance = distanceToNext else { return "--" }
        return distance.formattedDistance
    }

    /// Formatted time to next waypoint
    var formattedTimeToNext: String {
        guard let time = timeToNext else { return "--" }
        let minutes = Int(time) / 60
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }

    static func == (lhs: RouteWaypoint, rhs: RouteWaypoint) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Route Segment

/// A segment of a route between two waypoints
struct RouteSegment: Codable, Identifiable {
    let id: UUID
    let startWaypointId: UUID
    let endWaypointId: UUID
    var pathLatitudes: [Double]
    var pathLongitudes: [Double]
    var distance: Double // meters
    var time: TimeInterval // seconds
    var instructions: [String]

    init(
        id: UUID = UUID(),
        startWaypointId: UUID,
        endWaypointId: UUID,
        path: [CLLocationCoordinate2D],
        distance: Double,
        time: TimeInterval,
        instructions: [String] = []
    ) {
        self.id = id
        self.startWaypointId = startWaypointId
        self.endWaypointId = endWaypointId
        self.pathLatitudes = path.map { $0.latitude }
        self.pathLongitudes = path.map { $0.longitude }
        self.distance = distance
        self.time = time
        self.instructions = instructions
    }

    /// Get path as CLLocationCoordinate2D array
    var path: [CLLocationCoordinate2D] {
        zip(pathLatitudes, pathLongitudes).map {
            CLLocationCoordinate2D(latitude: $0, longitude: $1)
        }
    }
}

// MARK: - Route

/// A complete planned route with multiple waypoints
struct Route: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var waypoints: [RouteWaypoint]
    var segments: [RouteSegment]
    var totalDistance: Double // meters
    var estimatedTime: TimeInterval // seconds
    var createdAt: Date
    var modifiedAt: Date
    var color: String // Hex color
    var status: RouteStatus
    var notes: String?
    var uid: String // CoT UID

    init(
        id: UUID = UUID(),
        name: String,
        waypoints: [RouteWaypoint] = [],
        segments: [RouteSegment] = [],
        totalDistance: Double = 0,
        estimatedTime: TimeInterval = 0,
        createdAt: Date = Date(),
        color: String = "#FFFC00",
        status: RouteStatus = .planning,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name.isEmpty ? "Route \(Route.dateFormatter.string(from: createdAt))" : name
        self.waypoints = waypoints
        self.segments = segments
        self.totalDistance = totalDistance
        self.estimatedTime = estimatedTime
        self.createdAt = createdAt
        self.modifiedAt = createdAt
        self.color = color
        self.status = status
        self.notes = notes
        self.uid = "route-\(id.uuidString)"
    }

    // MARK: - Static Properties

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    // MARK: - Formatted Properties

    var formattedDistance: String {
        totalDistance.formattedDistance
    }

    var formattedTime: String {
        let hours = Int(estimatedTime) / 3600
        let minutes = (Int(estimatedTime) % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%d min", minutes)
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    var waypointCount: Int {
        waypoints.count
    }

    // MARK: - SwiftUI Color

    var swiftUIColor: Color {
        Color(hex: color)
    }

    var uiColor: UIColor {
        UIColor(Color(hex: color))
    }

    // MARK: - Bounding Region

    var boundingRegion: MKCoordinateRegion? {
        guard !waypoints.isEmpty else { return nil }

        var minLat = waypoints[0].latitude
        var maxLat = waypoints[0].latitude
        var minLon = waypoints[0].longitude
        var maxLon = waypoints[0].longitude

        for waypoint in waypoints {
            minLat = min(minLat, waypoint.latitude)
            maxLat = max(maxLat, waypoint.latitude)
            minLon = min(minLon, waypoint.longitude)
            maxLon = max(maxLon, waypoint.longitude)
        }

        // Also consider segment paths
        for segment in segments {
            for lat in segment.pathLatitudes {
                minLat = min(minLat, lat)
                maxLat = max(maxLat, lat)
            }
            for lon in segment.pathLongitudes {
                minLon = min(minLon, lon)
                maxLon = max(maxLon, lon)
            }
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3,
            longitudeDelta: (maxLon - minLon) * 1.3
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Waypoint Management

    mutating func addWaypoint(_ waypoint: RouteWaypoint) {
        var newWaypoint = waypoint
        newWaypoint.order = waypoints.count
        waypoints.append(newWaypoint)
        modifiedAt = Date()
    }

    mutating func removeWaypoint(at index: Int) {
        guard index < waypoints.count else { return }
        waypoints.remove(at: index)
        // Reorder remaining waypoints
        for i in 0..<waypoints.count {
            waypoints[i].order = i
        }
        modifiedAt = Date()
    }

    mutating func moveWaypoint(from source: IndexSet, to destination: Int) {
        waypoints.move(fromOffsets: source, toOffset: destination)
        // Update order
        for i in 0..<waypoints.count {
            waypoints[i].order = i
        }
        modifiedAt = Date()
    }

    mutating func updateWaypoint(_ waypoint: RouteWaypoint) {
        if let index = waypoints.firstIndex(where: { $0.id == waypoint.id }) {
            waypoints[index] = waypoint
            modifiedAt = Date()
        }
    }

    // MARK: - Route Calculation Helpers

    /// Get all coordinates along the complete route (including segment paths)
    var allCoordinates: [CLLocationCoordinate2D] {
        var coords: [CLLocationCoordinate2D] = []

        if segments.isEmpty {
            // Just use waypoint coordinates
            coords = waypoints.sorted { $0.order < $1.order }.map { $0.coordinate }
        } else {
            // Use detailed segment paths
            for segment in segments {
                coords.append(contentsOf: segment.path)
            }
        }

        return coords
    }

    /// Recalculate totals from segments
    mutating func recalculateTotals() {
        totalDistance = segments.reduce(0) { $0 + $1.distance }
        estimatedTime = segments.reduce(0) { $0 + $1.time }

        // Update waypoint distances/times
        for i in 0..<waypoints.count - 1 {
            if let segment = segments.first(where: { $0.startWaypointId == waypoints[i].id }) {
                waypoints[i].distanceToNext = segment.distance
                waypoints[i].timeToNext = segment.time
            }
        }
    }

    // MARK: - Equatable

    static func == (lhs: Route, rhs: Route) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Route Color Presets

enum RouteColorPreset: String, CaseIterable {
    case yellow = "#FFFC00"
    case red = "#FF0000"
    case green = "#00FF00"
    case blue = "#0000FF"
    case orange = "#FF8800"
    case purple = "#8800FF"
    case cyan = "#00FFFF"
    case magenta = "#FF00FF"
    case lime = "#88FF00"
    case pink = "#FF88FF"

    var displayName: String {
        switch self {
        case .yellow: return "Yellow"
        case .red: return "Red"
        case .green: return "Green"
        case .blue: return "Blue"
        case .orange: return "Orange"
        case .purple: return "Purple"
        case .cyan: return "Cyan"
        case .magenta: return "Magenta"
        case .lime: return "Lime"
        case .pink: return "Pink"
        }
    }

    var swiftUIColor: Color {
        Color(hex: rawValue)
    }
}

// MARK: - Route Progress

/// Tracks progress along an active route
struct RouteProgress: Equatable {
    var currentWaypointIndex: Int = 0
    var distanceToNextWaypoint: Double = 0 // meters
    var timeToNextWaypoint: TimeInterval = 0 // seconds
    var distanceRemaining: Double = 0 // meters
    var timeRemaining: TimeInterval = 0 // seconds
    var percentComplete: Double = 0 // 0-100
    var currentInstruction: String = ""
    var eta: Date?

    var formattedDistanceToNext: String {
        distanceToNextWaypoint.formattedDistance
    }

    var formattedTimeToNext: String {
        let minutes = Int(timeToNextWaypoint) / 60
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }

    var formattedDistanceRemaining: String {
        distanceRemaining.formattedDistance
    }

    var formattedTimeRemaining: String {
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%d min", minutes)
        }
    }

    var formattedETA: String {
        guard let eta = eta else { return "--:--" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: eta)
    }
}

// MARK: - Route Annotation

/// Map annotation for route waypoints
class RouteWaypointAnnotation: NSObject, MKAnnotation {
    let waypoint: RouteWaypoint
    let routeColor: UIColor
    let isStart: Bool
    let isEnd: Bool

    var coordinate: CLLocationCoordinate2D {
        waypoint.coordinate
    }

    var title: String? {
        waypoint.name
    }

    var subtitle: String? {
        if let instruction = waypoint.instruction {
            return instruction
        }
        if let distance = waypoint.distanceToNext {
            return "Next: \(distance.formattedDistance)"
        }
        return nil
    }

    init(waypoint: RouteWaypoint, routeColor: UIColor, isStart: Bool = false, isEnd: Bool = false) {
        self.waypoint = waypoint
        self.routeColor = routeColor
        self.isStart = isStart
        self.isEnd = isEnd
        super.init()
    }
}

// MARK: - Transport Type

/// Mode of transport for route calculation
enum TransportType: String, CaseIterable, Codable {
    case automobile = "Automobile"
    case walking = "Walking"
    case transit = "Transit"
    case any = "Any"

    var mkTransportType: MKDirectionsTransportType {
        switch self {
        case .automobile: return .automobile
        case .walking: return .walking
        case .transit: return .transit
        case .any: return .any
        }
    }

    var icon: String {
        switch self {
        case .automobile: return "car.fill"
        case .walking: return "figure.walk"
        case .transit: return "bus.fill"
        case .any: return "arrow.triangle.turn.up.right.diamond.fill"
        }
    }

    var displayName: String {
        rawValue
    }
}
