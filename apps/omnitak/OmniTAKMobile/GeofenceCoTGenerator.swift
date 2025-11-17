//
//  GeofenceCoTGenerator.swift
//  OmniTAKMobile
//
//  Generate CoT messages for geofence events
//

import Foundation
import CoreLocation

class GeofenceCoTGenerator {

    static func generateEventCoT(for event: GeofenceEvent, callsign: String) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let now = Date()
        let stale = now.addingTimeInterval(3600) // 1 hour stale

        let timeStr = dateFormatter.string(from: now)
        let startStr = dateFormatter.string(from: event.timestamp)
        let staleStr = dateFormatter.string(from: stale)

        // Determine event type code
        let typeCode: String
        switch event.eventType {
        case .entry:
            typeCode = "b-a-o-tbl" // Alert - observe
        case .exit:
            typeCode = "b-a-o-can" // Alert - canceled
        case .dwell:
            typeCode = "b-a-o-opn" // Alert - open
        }

        let uid = "GEOFENCE-\(event.geofenceId.uuidString)-\(event.id.uuidString)"

        let dwellInfo: String
        if let duration = event.dwellDuration {
            let minutes = Int(duration / 60)
            let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
            dwellInfo = "\(minutes)m \(seconds)s"
        } else {
            dwellInfo = "N/A"
        }

        let eventDescription: String
        switch event.eventType {
        case .entry:
            eventDescription = "Entered geofence '\(event.geofenceName)'"
        case .exit:
            eventDescription = "Exited geofence '\(event.geofenceName)' (dwell: \(dwellInfo))"
        case .dwell:
            eventDescription = "Dwell threshold exceeded in '\(event.geofenceName)' (\(dwellInfo))"
        }

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(uid)" type="\(typeCode)" time="\(timeStr)" start="\(startStr)" stale="\(staleStr)" how="h-g-i-g-o">
            <point lat="\(event.coordinate.latitude)" lon="\(event.coordinate.longitude)" hae="0.0" ce="9999999" le="9999999"/>
            <detail>
                <contact callsign="\(callsign)"/>
                <remarks>\(escapeXML(eventDescription))</remarks>
                <__geofence id="\(event.geofenceId.uuidString)" name="\(escapeXML(event.geofenceName))" event="\(event.eventType.rawValue)" userId="\(event.userId)"/>
                <link uid="\(event.userId)" type="a-f-G" relation="p-p"/>
            </detail>
        </event>
        """

        return xml
    }

    static func generateGeofenceDefinitionCoT(for geofence: Geofence, callsign: String) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let now = Date()
        let stale = now.addingTimeInterval(86400) // 24 hour stale

        let timeStr = dateFormatter.string(from: now)
        let staleStr = dateFormatter.string(from: stale)

        let uid = "GEOFENCE-DEF-\(geofence.id.uuidString)"

        // Center point for the geofence
        let centerLat: Double
        let centerLon: Double

        switch geofence.type {
        case .circle:
            centerLat = geofence.center?.latitude ?? 0
            centerLon = geofence.center?.longitude ?? 0
        case .polygon:
            if let coords = geofence.polygonCoordinates, !coords.isEmpty {
                let avgLat = coords.map { $0.latitude }.reduce(0, +) / Double(coords.count)
                let avgLon = coords.map { $0.longitude }.reduce(0, +) / Double(coords.count)
                centerLat = avgLat
                centerLon = avgLon
            } else {
                centerLat = 0
                centerLon = 0
            }
        }

        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(uid)" type="u-d-c-c" time="\(timeStr)" start="\(timeStr)" stale="\(staleStr)" how="h-e">
            <point lat="\(centerLat)" lon="\(centerLon)" hae="0.0" ce="9999999" le="9999999"/>
            <detail>
                <contact callsign="\(callsign)"/>
                <remarks>Geofence: \(escapeXML(geofence.name))</remarks>
                <shape>
        """

        if geofence.type == .circle, let center = geofence.center, let radius = geofence.radius {
            xml += """
                        <ellipse major="\(radius)" minor="\(radius)" angle="0"/>
            """
        } else if geofence.type == .polygon, let coords = geofence.polygonCoordinates {
            for coord in coords {
                xml += """
                            <polyline><vertex lat="\(coord.latitude)" lon="\(coord.longitude)"/></polyline>
                """
            }
        }

        xml += """
                </shape>
                <__geofencedef id="\(geofence.id.uuidString)" name="\(escapeXML(geofence.name))" type="\(geofence.type.rawValue)" color="\(geofence.color.hexColor)" active="\(geofence.isActive)" alertEntry="\(geofence.alertOnEntry)" alertExit="\(geofence.alertOnExit)" dwellThreshold="\(geofence.dwellTimeThreshold)"/>
            </detail>
        </event>
        """

        return xml
    }

    private static func escapeXML(_ string: String) -> String {
        var escaped = string
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&apos;")
        return escaped
    }
}
