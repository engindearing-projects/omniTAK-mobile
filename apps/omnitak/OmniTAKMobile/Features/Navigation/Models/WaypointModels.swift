//
//  WaypointModels.swift
//  OmniTAKMobile
//
//  Waypoint data models for navigation and point-of-interest management
//

import Foundation
import CoreLocation
import SwiftUI
import MapKit

// MARK: - Waypoint

/// Represents a navigational waypoint or point of interest
struct Waypoint: Identifiable, Codable, Equatable {
    // Core Identity
    let id: UUID
    var name: String
    var remarks: String?

    // Location Data
    let coordinate: CLLocationCoordinate2D
    var altitude: Double?  // Height Above Ellipsoid in meters

    // Visual Appearance
    var icon: WaypointIcon
    var color: WaypointColor

    // Metadata
    let createdAt: Date
    var modifiedAt: Date
    var createdBy: String?  // User/callsign who created it

    // Navigation
    var isNavigationTarget: Bool

    // TAK Integration
    var uid: String  // Unique identifier for CoT messages
    var cotType: String  // CoT event type (e.g., "b-m-p-w" for waypoint)

    init(
        id: UUID = UUID(),
        name: String,
        remarks: String? = nil,
        coordinate: CLLocationCoordinate2D,
        altitude: Double? = nil,
        icon: WaypointIcon = .waypoint,
        color: WaypointColor = .blue,
        createdBy: String? = nil,
        isNavigationTarget: Bool = false
    ) {
        self.id = id
        self.name = name
        self.remarks = remarks
        self.coordinate = coordinate
        self.altitude = altitude
        self.icon = icon
        self.color = color
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.createdBy = createdBy
        self.isNavigationTarget = isNavigationTarget
        self.uid = "waypoint-\(id.uuidString)"
        self.cotType = "b-m-p-w"  // Waypoint marker
    }

    // MARK: - Codable Implementation

    enum CodingKeys: String, CodingKey {
        case id, name, remarks, latitude, longitude, altitude
        case icon, color, createdAt, modifiedAt, createdBy
        case isNavigationTarget, uid, cotType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        remarks = try container.decodeIfPresent(String.self, forKey: .remarks)

        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)

        altitude = try container.decodeIfPresent(Double.self, forKey: .altitude)
        icon = try container.decode(WaypointIcon.self, forKey: .icon)
        color = try container.decode(WaypointColor.self, forKey: .color)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
        createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
        isNavigationTarget = try container.decode(Bool.self, forKey: .isNavigationTarget)
        uid = try container.decode(String.self, forKey: .uid)
        cotType = try container.decode(String.self, forKey: .cotType)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(remarks, forKey: .remarks)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encodeIfPresent(altitude, forKey: .altitude)
        try container.encode(icon, forKey: .icon)
        try container.encode(color, forKey: .color)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)
        try container.encodeIfPresent(createdBy, forKey: .createdBy)
        try container.encode(isNavigationTarget, forKey: .isNavigationTarget)
        try container.encode(uid, forKey: .uid)
        try container.encode(cotType, forKey: .cotType)
    }

    // MARK: - Equatable

    static func == (lhs: Waypoint, rhs: Waypoint) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Helper Methods

    /// Update the modified timestamp
    mutating func touch() {
        modifiedAt = Date()
    }

    /// Create a map annotation for this waypoint
    func createAnnotation() -> WaypointAnnotation {
        return WaypointAnnotation(waypoint: self)
    }
}

// MARK: - Waypoint Icon

enum WaypointIcon: String, CaseIterable, Codable {
    case waypoint = "mappin.circle.fill"
    case flag = "flag.fill"
    case star = "star.fill"
    case house = "house.fill"
    case building = "building.2.fill"
    case tent = "tent.fill"
    case car = "car.fill"
    case airplane = "airplane"
    case helicopter = "helicopter"
    case ferry = "ferry.fill"
    case target = "target"
    case crosshairs = "scope"
    case checkpoint = "checkmark.circle.fill"
    case warning = "exclamationmark.triangle.fill"
    case medical = "cross.circle.fill"
    case fuel = "fuelpump.fill"
    case food = "fork.knife"
    case camera = "camera.fill"
    case binoculars = "binoculars.fill"

    var displayName: String {
        switch self {
        case .waypoint: return "Waypoint"
        case .flag: return "Flag"
        case .star: return "Star"
        case .house: return "House"
        case .building: return "Building"
        case .tent: return "Camp"
        case .car: return "Vehicle"
        case .airplane: return "Airplane"
        case .helicopter: return "Helicopter"
        case .ferry: return "Boat"
        case .target: return "Target"
        case .crosshairs: return "Crosshairs"
        case .checkpoint: return "Checkpoint"
        case .warning: return "Warning"
        case .medical: return "Medical"
        case .fuel: return "Fuel"
        case .food: return "Food"
        case .camera: return "Photo"
        case .binoculars: return "Observation"
        }
    }

    /// Get corresponding CoT icon type
    var cotIconType: String {
        switch self {
        case .waypoint: return "waypoint"
        case .flag: return "flag"
        case .star: return "star"
        case .house: return "house"
        case .building: return "building"
        case .tent: return "camp"
        case .car: return "vehicle"
        case .airplane: return "aircraft"
        case .helicopter: return "rotorcraft"
        case .ferry: return "boat"
        case .target: return "target"
        case .crosshairs: return "aim_point"
        case .checkpoint: return "checkpoint"
        case .warning: return "warning"
        case .medical: return "medical"
        case .fuel: return "fuel"
        case .food: return "food"
        case .camera: return "camera"
        case .binoculars: return "observation"
        }
    }
}

// MARK: - Waypoint Color

enum WaypointColor: String, CaseIterable, Codable {
    case red = "Red"
    case blue = "Blue"
    case green = "Green"
    case yellow = "Yellow"
    case orange = "Orange"
    case purple = "Purple"
    case cyan = "Cyan"
    case white = "White"
    case pink = "Pink"
    case brown = "Brown"

    var uiColor: UIColor {
        switch self {
        case .red: return .systemRed
        case .blue: return .systemBlue
        case .green: return .systemGreen
        case .yellow: return .systemYellow
        case .orange: return .systemOrange
        case .purple: return .systemPurple
        case .cyan: return .systemCyan
        case .white: return .white
        case .pink: return .systemPink
        case .brown: return .systemBrown
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .red: return .red
        case .blue: return .blue
        case .green: return .green
        case .yellow: return .yellow
        case .orange: return .orange
        case .purple: return .purple
        case .cyan: return .cyan
        case .white: return .white
        case .pink: return .pink
        case .brown: return .brown
        }
    }

    /// Get ARGB hex color for CoT messages
    var cotColorHex: String {
        switch self {
        case .red: return "FFFF0000"
        case .blue: return "FF0000FF"
        case .green: return "FF00FF00"
        case .yellow: return "FFFFFF00"
        case .orange: return "FFFF8800"
        case .purple: return "FF800080"
        case .cyan: return "FF00FFFF"
        case .white: return "FFFFFFFF"
        case .pink: return "FFFF00FF"
        case .brown: return "FF8B4513"
        }
    }
}

// MARK: - Waypoint Annotation

/// Map annotation for displaying waypoints
class WaypointAnnotation: NSObject, MKAnnotation {
    let waypoint: Waypoint

    var coordinate: CLLocationCoordinate2D {
        waypoint.coordinate
    }

    var title: String? {
        waypoint.name
    }

    var subtitle: String? {
        waypoint.remarks
    }

    init(waypoint: Waypoint) {
        self.waypoint = waypoint
        super.init()
    }
}

// MARK: - Navigation State

/// Represents the current navigation state
struct NavigationState: Equatable {
    var isNavigating: Bool
    var targetWaypoint: Waypoint?
    var currentDistance: Double?  // meters
    var currentBearing: Double?   // degrees (0-360)
    var estimatedTimeOfArrival: Date?
    var averageSpeed: Double?     // m/s

    static let initial = NavigationState(
        isNavigating: false,
        targetWaypoint: nil,
        currentDistance: nil,
        currentBearing: nil,
        estimatedTimeOfArrival: nil,
        averageSpeed: nil
    )

    /// Calculate ETA based on current distance and average speed
    mutating func updateETA() {
        guard let distance = currentDistance,
              let speed = averageSpeed,
              speed > 0 else {
            estimatedTimeOfArrival = nil
            return
        }

        let timeInSeconds = distance / speed
        estimatedTimeOfArrival = Date().addingTimeInterval(timeInSeconds)
    }
}

// MARK: - Compass Data

/// Compass and heading information
struct CompassData: Equatable {
    var magneticHeading: Double?  // degrees (0-360)
    var trueHeading: Double?      // degrees (0-360)
    var headingAccuracy: Double?  // degrees

    static let initial = CompassData(
        magneticHeading: nil,
        trueHeading: nil,
        headingAccuracy: nil
    )

    var displayHeading: Double? {
        trueHeading ?? magneticHeading
    }

    var formattedHeading: String {
        guard let heading = displayHeading else { return "---" }
        return String(format: "%.0f°", heading)
    }

    /// Get cardinal direction for heading
    var cardinalDirection: String {
        guard let heading = displayHeading else { return "---" }

        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                         "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((heading + 11.25) / 22.5) % 16
        return directions[index]
    }
}

// MARK: - Distance Formatting Extensions

extension Double {
    /// Format distance in meters to human-readable string
    var formattedDistance: String {
        if self < 1000 {
            return String(format: "%.0f m", self)
        } else {
            return String(format: "%.2f km", self / 1000)
        }
    }

    /// Format distance in meters to feet
    var distanceInFeet: Double {
        self * 3.28084
    }

    /// Format distance in meters to miles
    var distanceInMiles: Double {
        self * 0.000621371
    }

    /// Format bearing to cardinal direction
    var cardinalDirection: String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                         "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((self + 11.25) / 22.5) % 16
        return directions[index]
    }
}

// MARK: - Waypoint Route

/// A collection of waypoints forming a route
struct WaypointRoute: Identifiable, Codable {
    let id: UUID
    var name: String
    var waypoints: [UUID]  // Waypoint IDs in order
    var color: WaypointColor
    let createdAt: Date
    var modifiedAt: Date

    init(id: UUID = UUID(), name: String, waypoints: [UUID] = [], color: WaypointColor = .blue) {
        self.id = id
        self.name = name
        self.waypoints = waypoints
        self.color = color
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    mutating func addWaypoint(_ waypointId: UUID) {
        waypoints.append(waypointId)
        modifiedAt = Date()
    }

    mutating func removeWaypoint(_ waypointId: UUID) {
        waypoints.removeAll { $0 == waypointId }
        modifiedAt = Date()
    }
}
