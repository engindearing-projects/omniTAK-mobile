//
//  CoTFilterModel.swift
//  OmniTAKTest
//
//  Enhanced CoT filtering data models
//

import Foundation
import CoreLocation
import SwiftUI

// MARK: - CoT Affiliation Enum

enum CoTAffiliation: String, CaseIterable, Identifiable, Codable {
    case friendly = "a-f"
    case hostile = "a-h"
    case neutral = "a-n"
    case unknown = "a-u"
    case assumedFriend = "a-a"
    case suspect = "a-s"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .friendly: return "Friendly"
        case .hostile: return "Hostile"
        case .neutral: return "Neutral"
        case .unknown: return "Unknown"
        case .assumedFriend: return "Assumed Friend"
        case .suspect: return "Suspect"
        }
    }

    var color: Color {
        switch self {
        case .friendly, .assumedFriend:
            return .cyan
        case .hostile, .suspect:
            return .red
        case .neutral:
            return .green
        case .unknown:
            return .yellow
        }
    }

    var icon: String {
        switch self {
        case .friendly, .assumedFriend:
            return "shield.fill"
        case .hostile, .suspect:
            return "exclamationmark.triangle.fill"
        case .neutral:
            return "circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    // Parse from CoT type string (e.g., "a-f-G-E-V")
    static func from(cotType: String) -> CoTAffiliation {
        let components = cotType.split(separator: "-")
        guard components.count >= 2 else { return .unknown }

        let affiliationCode = String(components[1]).lowercased()
        switch affiliationCode {
        case "f": return .friendly
        case "h": return .hostile
        case "n": return .neutral
        case "u": return .unknown
        case "a": return .assumedFriend
        case "s": return .suspect
        default: return .unknown
        }
    }
}

// MARK: - CoT Category Enum

enum CoTCategory: String, CaseIterable, Identifiable, Codable {
    case ground = "ground"
    case air = "air"
    case maritime = "maritime"
    case subsurface = "subsurface"
    case installation = "installation"
    case sensor = "sensor"
    case equipment = "equipment"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ground: return "Ground"
        case .air: return "Air"
        case .maritime: return "Maritime"
        case .subsurface: return "Subsurface"
        case .installation: return "Installation"
        case .sensor: return "Sensor"
        case .equipment: return "Equipment"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .ground:
            return "car.fill"
        case .air:
            return "airplane"
        case .maritime:
            return "ferry.fill"
        case .subsurface:
            return "water.waves"
        case .installation:
            return "building.2.fill"
        case .sensor:
            return "sensor.fill"
        case .equipment:
            return "wrench.and.screwdriver.fill"
        case .other:
            return "mappin.circle.fill"
        }
    }

    // Parse from CoT type string (e.g., "a-f-G-E-V-C")
    static func from(cotType: String) -> CoTCategory {
        let upper = cotType.uppercased()

        // Check for specific patterns
        if upper.contains("-A-") {
            return .air
        } else if upper.contains("-S-") {
            return .maritime
        } else if upper.contains("-U-") {
            return .subsurface
        } else if upper.contains("G-I") {
            return .installation
        } else if upper.contains("G-E-S") {
            return .sensor
        } else if upper.contains("-G-") || upper.contains("G-E-V") {
            return .ground
        } else if upper.contains("G-E") {
            return .equipment
        }

        return .other
    }
}

// MARK: - Enriched CoT Event

struct EnrichedCoTEvent: Identifiable, Equatable {
    let id: UUID
    let uid: String
    let type: String
    let timestamp: Date

    // Location Data
    let coordinate: CLLocationCoordinate2D
    let altitude: Double
    let ce: Double
    let le: Double

    // Unit Details
    let callsign: String
    let team: String?
    let affiliation: CoTAffiliation
    let category: CoTCategory

    // Movement Data
    let speed: Double?
    let course: Double?

    // Calculated Fields (relative to user position)
    var distance: Double?        // meters from user
    var bearing: Double?         // degrees from user
    var age: TimeInterval        // seconds since last update

    // Additional Details
    let remarks: String?
    let battery: Int?
    let device: String?

    // MARK: - Computed Properties

    var distanceKm: Double? {
        distance.map { $0 / 1000.0 }
    }

    var distanceMiles: Double? {
        distance.map { $0 * 0.000621371 }
    }

    var distanceNauticalMiles: Double? {
        distance.map { $0 * 0.000539957 }
    }

    var speedKmh: Double? {
        speed.map { $0 * 3.6 }
    }

    var speedMph: Double? {
        speed.map { $0 * 2.237 }
    }

    var speedKnots: Double? {
        speed.map { $0 * 1.94384 }
    }

    var altitudeFeet: Double {
        altitude * 3.28084
    }

    var ageMinutes: Double {
        age / 60.0
    }

    var ageHours: Double {
        age / 3600.0
    }

    var isStale: Bool {
        age > 900 // 15 minutes
    }

    var formattedDistance: String {
        guard let dist = distance else { return "N/A" }

        if dist < 1000 {
            return String(format: "%.0f m", dist)
        } else {
            return String(format: "%.2f km", dist / 1000.0)
        }
    }

    var formattedBearing: String {
        guard let brg = bearing else { return "N/A" }
        return String(format: "%.0f°", brg)
    }

    var formattedAge: String {
        if age < 60 {
            return String(format: "%.0fs", age)
        } else if age < 3600 {
            return String(format: "%.0fm", age / 60)
        } else {
            return String(format: "%.1fh", age / 3600)
        }
    }

    var cardinalDirection: String {
        guard let brg = bearing else { return "N/A" }

        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((brg + 22.5) / 45.0) % 8
        return directions[index]
    }

    // MARK: - Initializer from CoTEvent

    init(from event: CoTEvent, userLocation: CLLocation?) {
        self.id = UUID()
        self.uid = event.uid
        self.type = event.type
        self.timestamp = event.time

        self.coordinate = CLLocationCoordinate2D(
            latitude: event.point.lat,
            longitude: event.point.lon
        )
        self.altitude = event.point.hae
        self.ce = event.point.ce
        self.le = event.point.le

        self.callsign = event.detail.callsign
        self.team = event.detail.team
        self.affiliation = CoTAffiliation.from(cotType: event.type)
        self.category = CoTCategory.from(cotType: event.type)

        self.speed = nil
        self.course = nil

        self.age = Date().timeIntervalSince(event.time)

        self.remarks = nil
        self.battery = nil
        self.device = nil

        // Calculate distance and bearing if user location available
        if let userLoc = userLocation {
            let eventLocation = CLLocation(
                latitude: event.point.lat,
                longitude: event.point.lon
            )
            self.distance = userLoc.distance(from: eventLocation)
            self.bearing = calculateBearing(from: userLoc.coordinate, to: coordinate)
        } else {
            self.distance = nil
            self.bearing = nil
        }
    }

    // MARK: - Equatable

    static func == (lhs: EnrichedCoTEvent, rhs: EnrichedCoTEvent) -> Bool {
        lhs.id == rhs.id && lhs.uid == rhs.uid
    }
}

// MARK: - Helper Functions

private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
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
