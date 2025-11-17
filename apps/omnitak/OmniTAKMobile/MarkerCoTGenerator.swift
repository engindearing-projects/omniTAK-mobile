//
//  MarkerCoTGenerator.swift
//  OmniTAKMobile
//
//  Generates CoT XML messages for point markers
//

import Foundation
import CoreLocation

// MARK: - Marker CoT Generator

/// Generates TAK-compatible CoT XML for point markers
class MarkerCoTGenerator {

    /// Generate CoT XML for a point marker
    static func generateCoT(for marker: PointMarker, staleTime: TimeInterval = 3600) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let now = Date()
        let stale = now.addingTimeInterval(staleTime)

        let lat = marker.coordinate.latitude
        let lon = marker.coordinate.longitude
        let hae = marker.altitude ?? 0.0

        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(marker.uid)" type="\(marker.cotType)" time="\(dateFormatter.string(from: now))" start="\(dateFormatter.string(from: now))" stale="\(dateFormatter.string(from: stale))" how="h-g-i-g-o">
            <point lat="\(lat)" lon="\(lon)" hae="\(hae)" ce="10.0" le="10.0"/>
            <detail>
                <contact callsign="\(escapeXML(marker.name))"/>
                <usericon iconsetpath="COT_MAPPING_SPOTMAP/\(marker.affiliation.rawValue.lowercased())_point"/>
                <color value="\(marker.affiliation.hexColor)"/>
                <affiliation value="\(marker.affiliation.rawValue)"/>
        """

        // Add remarks
        if let remarks = marker.remarks, !remarks.isEmpty {
            xml += "\n        <remarks>\(escapeXML(remarks))</remarks>"
        }

        // Add SALUTE report if present
        if let salute = marker.saluteReport {
            xml += generateSALUTEElement(salute)
        }

        // Add marker metadata
        xml += """

                <precisionlocation altsrc="GPS" geopointsrc="User"/>
                <status readiness="true"/>
                <_marker_>\(marker.affiliation.shortCode)</_marker_>
                <takv device="iPhone" platform="OmniTAK" os="iOS" version="1.0.0"/>
        """

        xml += """

            </detail>
        </event>
        """

        return xml
    }

    /// Generate SALUTE report as CoT XML elements
    private static func generateSALUTEElement(_ report: SALUTEReport) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "ddHHmm'Z' MMM yy"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        let timeStr = dateFormatter.string(from: report.time).uppercased()

        let saluteXML = """

                <__salute__>
                    <size>\(escapeXML(report.size))</size>
                    <activity>\(escapeXML(report.activity))</activity>
                    <location>\(escapeXML(report.location))</location>
                    <unit>\(escapeXML(report.unit))</unit>
                    <time>\(timeStr)</time>
                    <equipment>\(escapeXML(report.equipment))</equipment>
                </__salute__>
                <remarks>SALUTE: \(escapeXML(report.summary))</remarks>
        """

        return saluteXML
    }

    /// Generate a hostile point marker CoT
    static func generateHostileMarker(
        uid: String,
        name: String,
        coordinate: CLLocationCoordinate2D,
        altitude: Double = 0,
        remarks: String? = nil,
        staleTime: TimeInterval = 3600
    ) -> String {
        let marker = PointMarker(
            id: UUID(),
            name: name,
            affiliation: .hostile,
            coordinate: coordinate,
            altitude: altitude,
            remarks: remarks
        )

        return generateCoT(for: marker, staleTime: staleTime)
    }

    /// Generate a friendly point marker CoT
    static func generateFriendlyMarker(
        uid: String,
        name: String,
        coordinate: CLLocationCoordinate2D,
        altitude: Double = 0,
        remarks: String? = nil,
        staleTime: TimeInterval = 3600
    ) -> String {
        let marker = PointMarker(
            id: UUID(),
            name: name,
            affiliation: .friendly,
            coordinate: coordinate,
            altitude: altitude,
            remarks: remarks
        )

        return generateCoT(for: marker, staleTime: staleTime)
    }

    /// Generate spot report CoT (simplified SALUTE)
    static func generateSpotReport(
        uid: String,
        name: String,
        affiliation: MarkerAffiliation,
        coordinate: CLLocationCoordinate2D,
        size: String,
        activity: String,
        unit: String,
        equipment: String,
        staleTime: TimeInterval = 3600
    ) -> String {
        let report = SALUTEReport(
            size: size,
            activity: activity,
            location: formatMGRS(coordinate),
            unit: unit,
            time: Date(),
            equipment: equipment
        )

        let marker = PointMarker(
            id: UUID(),
            name: name,
            affiliation: affiliation,
            coordinate: coordinate,
            saluteReport: report
        )

        return generateCoT(for: marker, staleTime: staleTime)
    }

    /// Generate batch CoT messages for multiple markers
    static func generateBatchCoT(markers: [PointMarker], staleTime: TimeInterval = 3600) -> [String] {
        return markers.map { generateCoT(for: $0, staleTime: staleTime) }
    }

    // MARK: - Helper Methods

    /// Escape XML special characters
    private static func escapeXML(_ string: String) -> String {
        var result = string
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&apos;")
        return result
    }

    /// Format coordinate as MGRS-like string
    private static func formatMGRS(_ coordinate: CLLocationCoordinate2D) -> String {
        let lat = abs(coordinate.latitude)
        let lon = abs(coordinate.longitude)
        let latDeg = Int(lat)
        let lonDeg = Int(lon)
        let latMin = Int((lat - Double(latDeg)) * 60)
        let lonMin = Int((lon - Double(lonDeg)) * 60)
        let latSec = Int(((lat - Double(latDeg)) * 60 - Double(latMin)) * 60)
        let lonSec = Int(((lon - Double(lonDeg)) * 60 - Double(lonMin)) * 60)

        let latDir = coordinate.latitude >= 0 ? "N" : "S"
        let lonDir = coordinate.longitude >= 0 ? "E" : "W"

        return "\(latDeg)°\(latMin)'\(latSec)\"\(latDir) \(lonDeg)°\(lonMin)'\(lonSec)\"\(lonDir)"
    }

    /// Parse CoT type to determine affiliation
    static func parseAffiliation(from cotType: String) -> MarkerAffiliation {
        let components = cotType.split(separator: "-")
        guard components.count >= 2 else { return .unknown }

        let affiliationCode = String(components[1]).lowercased()
        switch affiliationCode {
        case "f": return .friendly
        case "h": return .hostile
        case "n": return .neutral
        case "u": return .unknown
        default: return .unknown
        }
    }

    /// Validate CoT XML structure
    static func validateCoT(_ xml: String) -> Bool {
        // Basic validation
        return xml.contains("<?xml") &&
               xml.contains("<event") &&
               xml.contains("</event>") &&
               xml.contains("<point") &&
               xml.contains("uid=") &&
               xml.contains("type=")
    }
}

// MARK: - CoT Type Constants

extension MarkerCoTGenerator {

    /// Standard CoT types for different marker affiliations
    struct CoTTypes {
        // Ground units
        static let friendlyGround = "a-f-G-U-C"      // Friendly Ground Unit Combat
        static let hostileGround = "a-h-G-U-C"       // Hostile Ground Unit Combat
        static let neutralGround = "a-n-G"           // Neutral Ground
        static let unknownGround = "a-u-G"           // Unknown Ground

        // Specific unit types
        static let friendlyInfantry = "a-f-G-U-C-I"  // Friendly Infantry
        static let hostileInfantry = "a-h-G-U-C-I"   // Hostile Infantry
        static let friendlyArmor = "a-f-G-U-C-A"     // Friendly Armor
        static let hostileArmor = "a-h-G-U-C-A"      // Hostile Armor

        // Point markers
        static let spotReport = "b-m-p-w"            // Waypoint/Spot
        static let hostileSpot = "a-h-G-E-S"         // Hostile Equipment/Sensor

        // Emergency
        static let emergency = "b-r-f-h-c"           // Emergency/Alert
    }

    /// How values for CoT events
    struct HowValues {
        static let gpsManual = "h-g-i-g-o"           // GPS + Manual input
        static let gpsAuto = "m-g"                   // Machine generated from GPS
        static let manual = "h-e"                    // Human estimated
        static let calculated = "m-p"                // Machine calculated/predicted
    }
}
