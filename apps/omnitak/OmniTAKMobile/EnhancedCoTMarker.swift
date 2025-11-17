//
//  EnhancedCoTMarker.swift
//  OmniTAKTest
//
//  Enhanced CoT marker model with full TAK data support
//

import Foundation
import CoreLocation
import SwiftUI

// MARK: - Enhanced CoT Marker

struct EnhancedCoTMarker: Identifiable, Equatable {
    // Core Identity
    let id: UUID
    let uid: String
    let type: String
    let timestamp: Date

    // Location Data
    let coordinate: CLLocationCoordinate2D
    let altitude: Double          // hae (Height Above Ellipsoid) in meters
    let ce: Double               // Circular Error in meters
    let le: Double               // Linear Error in meters

    // Unit Details
    let callsign: String
    let team: String?
    let affiliation: UnitAffiliation
    let unitType: UnitType

    // Movement Data
    let speed: Double?           // m/s
    let course: Double?          // degrees

    // Additional Details
    let remarks: String?
    let battery: Int?
    let device: String?
    let platform: String?

    // History tracking
    var lastUpdate: Date
    var positionHistory: [CoTPosition]

    // MARK: - Computed Properties

    var speedKmh: Double? {
        speed.map { $0 * 3.6 }
    }

    var speedMph: Double? {
        speed.map { $0 * 2.237 }
    }

    var altitudeFeet: Double {
        altitude * 3.28084
    }

    var altitudeMeters: Double {
        altitude
    }

    var ageInSeconds: TimeInterval {
        Date().timeIntervalSince(lastUpdate)
    }

    var isStale: Bool {
        ageInSeconds > 900 // 15 minutes
    }

    // MARK: - Equatable

    static func == (lhs: EnhancedCoTMarker, rhs: EnhancedCoTMarker) -> Bool {
        lhs.id == rhs.id && lhs.uid == rhs.uid
    }
}

// MARK: - Unit Affiliation

enum UnitAffiliation: String, CaseIterable {
    case friendly = "a-f"
    case hostile = "a-h"
    case neutral = "a-n"
    case unknown = "a-u"
    case assumedFriend = "a-a"
    case suspect = "a-s"

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
    static func from(cotType: String) -> UnitAffiliation {
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

// MARK: - Unit Type

enum UnitType: String, CaseIterable {
    case infantry = "G-E-V"
    case groundVehicle = "G-E-V-C"
    case aircraft = "A"
    case rotaryWing = "A-M-H"
    case fixedWing = "A-M-F"
    case uav = "A-M-F-Q"
    case naval = "S"
    case installation = "G-I"
    case sensor = "G-E-S"
    case generic = "unknown"

    var iconName: String {
        switch self {
        case .infantry:
            return "person.fill"
        case .groundVehicle:
            return "car.fill"
        case .aircraft:
            return "airplane"
        case .rotaryWing:
            return "helicopter"
        case .fixedWing:
            return "airplane"
        case .uav:
            return "airplane.circle"
        case .naval:
            return "ferry.fill"
        case .installation:
            return "building.2.fill"
        case .sensor:
            return "sensor.fill"
        case .generic:
            return "mappin.circle.fill"
        }
    }

    var displayName: String {
        switch self {
        case .infantry:
            return "Infantry"
        case .groundVehicle:
            return "Ground Vehicle"
        case .aircraft:
            return "Aircraft"
        case .rotaryWing:
            return "Helicopter"
        case .fixedWing:
            return "Fixed Wing"
        case .uav:
            return "UAV/Drone"
        case .naval:
            return "Naval"
        case .installation:
            return "Installation"
        case .sensor:
            return "Sensor"
        case .generic:
            return "Generic"
        }
    }

    // Parse from CoT type string (e.g., "a-f-G-E-V-C")
    static func from(cotType: String) -> UnitType {
        let upper = cotType.uppercased()

        // Check specific patterns first (most specific to least)
        if upper.contains("A-M-F-Q") { return .uav }
        if upper.contains("A-M-H") { return .rotaryWing }
        if upper.contains("A-M-F") { return .fixedWing }
        if upper.contains("-A-") { return .aircraft }
        if upper.contains("G-E-V-C") { return .groundVehicle }
        if upper.contains("G-E-V") { return .infantry }
        if upper.contains("G-I") { return .installation }
        if upper.contains("G-E-S") { return .sensor }
        if upper.contains("-S-") { return .naval }

        return .generic
    }
}

// MARK: - CoT Position History

struct CoTPosition: Identifiable, Equatable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let altitude: Double
    let timestamp: Date
    let speed: Double?
    let course: Double?

    static func == (lhs: CoTPosition, rhs: CoTPosition) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Helper Extensions

extension EnhancedCoTMarker {
    /// Calculate distance from a given location
    func distance(from location: CLLocation) -> Double {
        let markerLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return location.distance(from: markerLocation)
    }

    /// Calculate bearing from a given location
    func bearing(from location: CLLocation) -> Double {
        let lat1 = location.coordinate.latitude * .pi / 180
        let lon1 = location.coordinate.longitude * .pi / 180
        let lat2 = coordinate.latitude * .pi / 180
        let lon2 = coordinate.longitude * .pi / 180

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)
        let degreesBearing = radiansBearing * 180 / .pi

        return (degreesBearing + 360).truncatingRemainder(dividingBy: 360)
    }
}
