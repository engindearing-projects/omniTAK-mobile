//
//  PointMarkerModels.swift
//  OmniTAKMobile
//
//  Point marker data models for hostile marking and point dropping
//

import Foundation
import CoreLocation
import SwiftUI
import MapKit

// MARK: - Point Marker

/// Represents a tactical point marker (Friendly/Hostile/Unknown/Neutral)
struct PointMarker: Identifiable, Codable, Equatable {
    // Core Identity
    let id: UUID
    var name: String
    var affiliation: MarkerAffiliation

    // Location Data
    let coordinate: CLLocationCoordinate2D
    var altitude: Double?  // Height Above Ellipsoid in meters

    // Metadata
    let timestamp: Date
    var modifiedAt: Date
    var remarks: String?
    var createdBy: String?

    // SALUTE Report (optional)
    var saluteReport: SALUTEReport?

    // TAK Integration
    var uid: String
    var cotType: String
    var iconName: String

    // Sharing
    var isBroadcast: Bool

    init(
        id: UUID = UUID(),
        name: String,
        affiliation: MarkerAffiliation,
        coordinate: CLLocationCoordinate2D,
        altitude: Double? = nil,
        remarks: String? = nil,
        saluteReport: SALUTEReport? = nil,
        createdBy: String? = nil,
        isBroadcast: Bool = false
    ) {
        self.id = id
        self.name = name
        self.affiliation = affiliation
        self.coordinate = coordinate
        self.altitude = altitude
        self.timestamp = Date()
        self.modifiedAt = Date()
        self.remarks = remarks
        self.saluteReport = saluteReport
        self.createdBy = createdBy
        self.uid = "marker-\(id.uuidString)"
        self.cotType = affiliation.cotType
        self.iconName = affiliation.iconName
        self.isBroadcast = isBroadcast
    }

    // MARK: - Codable Implementation

    enum CodingKeys: String, CodingKey {
        case id, name, affiliation, latitude, longitude, altitude
        case timestamp, modifiedAt, remarks, createdBy, saluteReport
        case uid, cotType, iconName, isBroadcast
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        affiliation = try container.decode(MarkerAffiliation.self, forKey: .affiliation)

        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)

        altitude = try container.decodeIfPresent(Double.self, forKey: .altitude)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        modifiedAt = try container.decode(Date.self, forKey: .modifiedAt)
        remarks = try container.decodeIfPresent(String.self, forKey: .remarks)
        createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
        saluteReport = try container.decodeIfPresent(SALUTEReport.self, forKey: .saluteReport)
        uid = try container.decode(String.self, forKey: .uid)
        cotType = try container.decode(String.self, forKey: .cotType)
        iconName = try container.decode(String.self, forKey: .iconName)
        isBroadcast = try container.decode(Bool.self, forKey: .isBroadcast)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(affiliation, forKey: .affiliation)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encodeIfPresent(altitude, forKey: .altitude)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(modifiedAt, forKey: .modifiedAt)
        try container.encodeIfPresent(remarks, forKey: .remarks)
        try container.encodeIfPresent(createdBy, forKey: .createdBy)
        try container.encodeIfPresent(saluteReport, forKey: .saluteReport)
        try container.encode(uid, forKey: .uid)
        try container.encode(cotType, forKey: .cotType)
        try container.encode(iconName, forKey: .iconName)
        try container.encode(isBroadcast, forKey: .isBroadcast)
    }

    // MARK: - Equatable

    static func == (lhs: PointMarker, rhs: PointMarker) -> Bool {
        lhs.id == rhs.id
    }

    // MARK: - Helper Methods

    /// Update the modified timestamp
    mutating func touch() {
        modifiedAt = Date()
    }

    /// Create a map annotation for this marker
    func createAnnotation() -> PointMarkerAnnotation {
        return PointMarkerAnnotation(marker: self)
    }

    /// Get MGRS coordinate string
    var mgrsString: String {
        // Simplified MGRS-like format
        let lat = abs(coordinate.latitude)
        let lon = abs(coordinate.longitude)
        let latDeg = Int(lat)
        let lonDeg = Int(lon)
        let latMin = Int((lat - Double(latDeg)) * 60)
        let lonMin = Int((lon - Double(lonDeg)) * 60)
        return "\(latDeg)\(latMin)N \(lonDeg)\(lonMin)W"
    }

    /// Get formatted timestamp
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ddHHmm'Z' MMM yy"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: timestamp).uppercased()
    }
}

// MARK: - Marker Affiliation

enum MarkerAffiliation: String, CaseIterable, Codable {
    case friendly = "Friendly"
    case hostile = "Hostile"
    case unknown = "Unknown"
    case neutral = "Neutral"

    var cotPrefix: String {
        switch self {
        case .friendly: return "a-f"
        case .hostile: return "a-h"
        case .unknown: return "a-u"
        case .neutral: return "a-n"
        }
    }

    var cotType: String {
        switch self {
        case .friendly: return "a-f-G-U-C"  // Ground Unit Combat
        case .hostile: return "a-h-G-U-C"   // Hostile Ground Unit Combat
        case .unknown: return "a-u-G"       // Unknown Ground
        case .neutral: return "a-n-G"       // Neutral Ground
        }
    }

    var color: Color {
        switch self {
        case .friendly: return .cyan
        case .hostile: return .red
        case .unknown: return .yellow
        case .neutral: return .green
        }
    }

    var uiColor: UIColor {
        switch self {
        case .friendly: return .systemCyan
        case .hostile: return .systemRed
        case .unknown: return .systemYellow
        case .neutral: return .systemGreen
        }
    }

    var hexColor: String {
        switch self {
        case .friendly: return "FF00FFFF"  // Cyan
        case .hostile: return "FFFF0000"   // Red
        case .unknown: return "FFFFFF00"   // Yellow
        case .neutral: return "FF00FF00"   // Green
        }
    }

    var iconName: String {
        switch self {
        case .friendly: return "shield.fill"
        case .hostile: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle.fill"
        case .neutral: return "circle.fill"
        }
    }

    var displayName: String {
        rawValue
    }

    var shortCode: String {
        switch self {
        case .friendly: return "FRD"
        case .hostile: return "HOS"
        case .unknown: return "UNK"
        case .neutral: return "NEU"
        }
    }
}

// MARK: - SALUTE Report

/// SALUTE report structure (Size, Activity, Location, Unit, Time, Equipment)
struct SALUTEReport: Codable, Equatable {
    var size: String        // Squad, Platoon, Company, Battalion, etc.
    var activity: String    // Moving, Stationary, Attacking, Defending, etc.
    var location: String    // MGRS or descriptive location
    var unit: String        // Infantry, Armor, Artillery, etc.
    var time: Date          // Time of observation
    var equipment: String   // Weapons, vehicles, equipment observed

    init(
        size: String = "",
        activity: String = "",
        location: String = "",
        unit: String = "",
        time: Date = Date(),
        equipment: String = ""
    ) {
        self.size = size
        self.activity = activity
        self.location = location
        self.unit = unit
        self.time = time
        self.equipment = equipment
    }

    /// Generate formatted SALUTE report text
    var formattedReport: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "ddHHmm'Z' MMM yy"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let timeStr = dateFormatter.string(from: time).uppercased()

        return """
        SALUTE REPORT
        ==============
        SIZE: \(size)
        ACTIVITY: \(activity)
        LOCATION: \(location)
        UNIT: \(unit)
        TIME: \(timeStr)
        EQUIPMENT: \(equipment)
        """
    }

    /// Generate single-line summary
    var summary: String {
        "\(size) \(unit) - \(activity)"
    }
}

// MARK: - SALUTE Options

enum SALUTESize: String, CaseIterable {
    case individual = "Individual"
    case fireteam = "Fire Team (2-4)"
    case squad = "Squad (9-13)"
    case platoon = "Platoon (16-44)"
    case company = "Company (60-200)"
    case battalion = "Battalion (300-1000)"
    case regiment = "Regiment (1000-3000)"
    case brigade = "Brigade (3000-5000)"
    case division = "Division (10000-15000)"
    case unknown = "Unknown"
}

enum SALUTEActivity: String, CaseIterable {
    case stationary = "Stationary"
    case movingNorth = "Moving North"
    case movingSouth = "Moving South"
    case movingEast = "Moving East"
    case movingWest = "Moving West"
    case attacking = "Attacking"
    case defending = "Defending"
    case withdrawing = "Withdrawing"
    case reconnoitering = "Reconnoitering"
    case establishing = "Establishing Position"
    case patrolling = "Patrolling"
    case unknown = "Unknown"
}

enum SALUTEUnit: String, CaseIterable {
    case infantry = "Infantry"
    case armor = "Armor"
    case artillery = "Artillery"
    case cavalry = "Cavalry"
    case airDefense = "Air Defense"
    case engineer = "Engineer"
    case signal = "Signal"
    case medical = "Medical"
    case logistics = "Logistics"
    case specialForces = "Special Forces"
    case militia = "Militia"
    case irregular = "Irregular Forces"
    case unknown = "Unknown"
}

// MARK: - Point Marker Annotation

/// Map annotation for displaying point markers
class PointMarkerAnnotation: NSObject, MKAnnotation {
    let marker: PointMarker

    var coordinate: CLLocationCoordinate2D {
        marker.coordinate
    }

    var title: String? {
        marker.name
    }

    var subtitle: String? {
        "\(marker.affiliation.displayName) - \(marker.formattedTimestamp)"
    }

    init(marker: PointMarker) {
        self.marker = marker
        super.init()
    }
}

// MARK: - Point Dropper State

/// State for point dropping mode
enum PointDropperState: Equatable {
    case idle
    case selecting          // Selecting affiliation
    case placing            // Ready to place marker
    case editing(PointMarker)  // Editing existing marker
    case viewingSALUTE(PointMarker)  // Viewing/editing SALUTE report
}

// MARK: - Point Dropper Event

/// Events for point dropper interactions
enum PointDropperEvent {
    case markerCreated(PointMarker)
    case markerUpdated(PointMarker)
    case markerDeleted(PointMarker)
    case markerBroadcast(PointMarker)
    case saluteReportGenerated(PointMarker)
}
