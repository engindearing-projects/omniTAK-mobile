//
//  GeofenceModels.swift
//  OmniTAKMobile
//
//  Data models for geofencing system
//

import Foundation
import CoreLocation
import SwiftUI

// MARK: - Geofence Type

enum GeofenceType: String, Codable, CaseIterable {
    case circle = "Circle"
    case polygon = "Polygon"

    var icon: String {
        switch self {
        case .circle: return "circle"
        case .polygon: return "pentagon"
        }
    }

    var displayName: String {
        rawValue
    }
}

// MARK: - Geofence Event Type

enum GeofenceEventType: String, Codable {
    case entry = "Entry"
    case exit = "Exit"
    case dwell = "Dwell"

    var icon: String {
        switch self {
        case .entry: return "arrow.down.right.circle.fill"
        case .exit: return "arrow.up.left.circle.fill"
        case .dwell: return "clock.fill"
        }
    }

    var color: Color {
        switch self {
        case .entry: return .yellow
        case .exit: return .red
        case .dwell: return .orange
        }
    }
}

// MARK: - Geofence Status

enum GeofenceStatus: String, Codable {
    case inactive = "Inactive"
    case active = "Active"
    case triggered = "Triggered"
    case monitoring = "Monitoring"
}

// MARK: - Geofence Color

enum GeofenceColor: String, CaseIterable, Codable {
    case red = "Red"
    case blue = "Blue"
    case green = "Green"
    case yellow = "Yellow"
    case orange = "Orange"
    case purple = "Purple"
    case cyan = "Cyan"

    var uiColor: UIColor {
        switch self {
        case .red: return .systemRed
        case .blue: return .systemBlue
        case .green: return .systemGreen
        case .yellow: return .systemYellow
        case .orange: return .systemOrange
        case .purple: return .systemPurple
        case .cyan: return .systemCyan
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
        }
    }

    var hexColor: String {
        switch self {
        case .red: return "#FF0000"
        case .blue: return "#0000FF"
        case .green: return "#00FF00"
        case .yellow: return "#FFFF00"
        case .orange: return "#FFA500"
        case .purple: return "#800080"
        case .cyan: return "#00FFFF"
        }
    }
}

// MARK: - Geofence

struct Geofence: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var type: GeofenceType
    var color: GeofenceColor
    var isActive: Bool
    var alertOnEntry: Bool
    var alertOnExit: Bool
    var dwellTimeThreshold: TimeInterval // in seconds, 0 = disabled
    var createdAt: Date
    var lastTriggeredAt: Date?

    // Circle-specific properties
    var center: CLLocationCoordinate2D?
    var radius: CLLocationDistance? // in meters

    // Polygon-specific properties
    var polygonCoordinates: [CLLocationCoordinate2D]?

    // User tracking
    var userInsideGeofence: Bool = false
    var entryTime: Date?
    var totalDwellTime: TimeInterval = 0

    init(
        id: UUID = UUID(),
        name: String,
        type: GeofenceType,
        color: GeofenceColor = .yellow,
        isActive: Bool = true,
        alertOnEntry: Bool = true,
        alertOnExit: Bool = true,
        dwellTimeThreshold: TimeInterval = 0,
        center: CLLocationCoordinate2D? = nil,
        radius: CLLocationDistance? = nil,
        polygonCoordinates: [CLLocationCoordinate2D]? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.color = color
        self.isActive = isActive
        self.alertOnEntry = alertOnEntry
        self.alertOnExit = alertOnExit
        self.dwellTimeThreshold = dwellTimeThreshold
        self.createdAt = Date()
        self.center = center
        self.radius = radius
        self.polygonCoordinates = polygonCoordinates
    }

    // MARK: - Point-in-Geofence Detection

    func containsPoint(_ point: CLLocationCoordinate2D) -> Bool {
        switch type {
        case .circle:
            return containsPointInCircle(point)
        case .polygon:
            return containsPointInPolygon(point)
        }
    }

    private func containsPointInCircle(_ point: CLLocationCoordinate2D) -> Bool {
        guard let center = center, let radius = radius else { return false }

        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let pointLocation = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let distance = centerLocation.distance(from: pointLocation)

        return distance <= radius
    }

    // Efficient Ray Casting Algorithm for point-in-polygon
    private func containsPointInPolygon(_ point: CLLocationCoordinate2D) -> Bool {
        guard let coordinates = polygonCoordinates, coordinates.count >= 3 else { return false }

        var inside = false
        let n = coordinates.count
        var j = n - 1

        for i in 0..<n {
            let xi = coordinates[i].longitude
            let yi = coordinates[i].latitude
            let xj = coordinates[j].longitude
            let yj = coordinates[j].latitude

            let intersect = ((yi > point.latitude) != (yj > point.latitude)) &&
                (point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi)

            if intersect {
                inside = !inside
            }
            j = i
        }

        return inside
    }

    // MARK: - Codable Conformance

    enum CodingKeys: String, CodingKey {
        case id, name, type, color, isActive, alertOnEntry, alertOnExit
        case dwellTimeThreshold, createdAt, lastTriggeredAt
        case centerLatitude, centerLongitude, radius
        case polygonPoints
        case userInsideGeofence, entryTime, totalDwellTime
    }

    struct CoordinatePair: Codable {
        let latitude: Double
        let longitude: Double
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(GeofenceType.self, forKey: .type)
        color = try container.decode(GeofenceColor.self, forKey: .color)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        alertOnEntry = try container.decode(Bool.self, forKey: .alertOnEntry)
        alertOnExit = try container.decode(Bool.self, forKey: .alertOnExit)
        dwellTimeThreshold = try container.decode(TimeInterval.self, forKey: .dwellTimeThreshold)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastTriggeredAt = try container.decodeIfPresent(Date.self, forKey: .lastTriggeredAt)

        // Circle properties
        if let lat = try container.decodeIfPresent(Double.self, forKey: .centerLatitude),
           let lon = try container.decodeIfPresent(Double.self, forKey: .centerLongitude) {
            center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        radius = try container.decodeIfPresent(CLLocationDistance.self, forKey: .radius)

        // Polygon properties
        if let points = try container.decodeIfPresent([CoordinatePair].self, forKey: .polygonPoints) {
            polygonCoordinates = points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }

        // User tracking
        userInsideGeofence = try container.decodeIfPresent(Bool.self, forKey: .userInsideGeofence) ?? false
        entryTime = try container.decodeIfPresent(Date.self, forKey: .entryTime)
        totalDwellTime = try container.decodeIfPresent(TimeInterval.self, forKey: .totalDwellTime) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(color, forKey: .color)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(alertOnEntry, forKey: .alertOnEntry)
        try container.encode(alertOnExit, forKey: .alertOnExit)
        try container.encode(dwellTimeThreshold, forKey: .dwellTimeThreshold)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(lastTriggeredAt, forKey: .lastTriggeredAt)

        // Circle properties
        try container.encodeIfPresent(center?.latitude, forKey: .centerLatitude)
        try container.encodeIfPresent(center?.longitude, forKey: .centerLongitude)
        try container.encodeIfPresent(radius, forKey: .radius)

        // Polygon properties
        if let coordinates = polygonCoordinates {
            let points = coordinates.map { CoordinatePair(latitude: $0.latitude, longitude: $0.longitude) }
            try container.encode(points, forKey: .polygonPoints)
        }

        // User tracking
        try container.encode(userInsideGeofence, forKey: .userInsideGeofence)
        try container.encodeIfPresent(entryTime, forKey: .entryTime)
        try container.encode(totalDwellTime, forKey: .totalDwellTime)
    }

    static func == (lhs: Geofence, rhs: Geofence) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Geofence Event

struct GeofenceEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let geofenceId: UUID
    let geofenceName: String
    let eventType: GeofenceEventType
    let timestamp: Date
    let coordinate: CLLocationCoordinate2D
    let userId: String
    let dwellDuration: TimeInterval? // Only for dwell events

    init(
        id: UUID = UUID(),
        geofenceId: UUID,
        geofenceName: String,
        eventType: GeofenceEventType,
        coordinate: CLLocationCoordinate2D,
        userId: String,
        dwellDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.geofenceId = geofenceId
        self.geofenceName = geofenceName
        self.eventType = eventType
        self.timestamp = Date()
        self.coordinate = coordinate
        self.userId = userId
        self.dwellDuration = dwellDuration
    }

    // Manual Equatable conformance (CLLocationCoordinate2D isn't Equatable)
    static func == (lhs: GeofenceEvent, rhs: GeofenceEvent) -> Bool {
        lhs.id == rhs.id &&
        lhs.geofenceId == rhs.geofenceId &&
        lhs.geofenceName == rhs.geofenceName &&
        lhs.eventType == rhs.eventType &&
        lhs.timestamp == rhs.timestamp &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.userId == rhs.userId &&
        lhs.dwellDuration == rhs.dwellDuration
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, geofenceId, geofenceName, eventType, timestamp
        case latitude, longitude, userId, dwellDuration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        geofenceId = try container.decode(UUID.self, forKey: .geofenceId)
        geofenceName = try container.decode(String.self, forKey: .geofenceName)
        eventType = try container.decode(GeofenceEventType.self, forKey: .eventType)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        userId = try container.decode(String.self, forKey: .userId)
        dwellDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .dwellDuration)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(geofenceId, forKey: .geofenceId)
        try container.encode(geofenceName, forKey: .geofenceName)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(dwellDuration, forKey: .dwellDuration)
    }
}

// MARK: - Geofence Alert

struct GeofenceAlert: Identifiable, Codable, Equatable {
    let id: UUID
    let geofenceId: UUID
    let geofenceName: String
    let eventType: GeofenceEventType
    let message: String
    let timestamp: Date
    var isRead: Bool
    var isDismissed: Bool

    init(
        id: UUID = UUID(),
        geofenceId: UUID,
        geofenceName: String,
        eventType: GeofenceEventType,
        message: String
    ) {
        self.id = id
        self.geofenceId = geofenceId
        self.geofenceName = geofenceName
        self.eventType = eventType
        self.message = message
        self.timestamp = Date()
        self.isRead = false
        self.isDismissed = false
    }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

// MARK: - Geofence Statistics

struct GeofenceStatistics {
    let totalEntries: Int
    let totalExits: Int
    let totalDwellTime: TimeInterval
    let averageDwellTime: TimeInterval
    let lastEvent: GeofenceEvent?
}

// MARK: - Shared Drawing from Existing System

struct GeofenceDrawingSource: Identifiable {
    let id: UUID
    let name: String
    let type: GeofenceType
    let center: CLLocationCoordinate2D?
    let radius: CLLocationDistance?
    let coordinates: [CLLocationCoordinate2D]?

    // Create from CircleDrawing
    static func fromCircle(_ circle: CircleDrawing) -> GeofenceDrawingSource {
        GeofenceDrawingSource(
            id: circle.id,
            name: circle.name,
            type: .circle,
            center: circle.center,
            radius: circle.radius,
            coordinates: nil
        )
    }

    // Create from PolygonDrawing
    static func fromPolygon(_ polygon: PolygonDrawing) -> GeofenceDrawingSource {
        GeofenceDrawingSource(
            id: polygon.id,
            name: polygon.name,
            type: .polygon,
            center: nil,
            radius: nil,
            coordinates: polygon.coordinates
        )
    }
}
