//
//  CoTMessageParser.swift
//  OmniTAKMobile
//
//  Parse incoming CoT XML messages, extract event data into structured objects
//

import Foundation
import CoreLocation

// MARK: - Parsed CoT Event Types

enum CoTEventType {
    case positionUpdate(CoTEvent)      // a-f-G-*, a-h-*, a-n-*, a-u-* (SA messages)
    case chatMessage(ChatMessage)       // b-t-f (GeoChat)
    case emergencyAlert(EmergencyAlert) // b-a-* (alerts)
    case waypoint(CoTEvent)             // b-m-p-w (waypoint markers)
    case unknown(String)                // Unrecognized type
}

// MARK: - Emergency Alert

struct EmergencyAlert: Identifiable {
    let id: String
    let uid: String
    let alertType: AlertType
    let callsign: String
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date
    let message: String?
    let cancel: Bool

    enum AlertType: String, CaseIterable {
        case emergency = "911"
        case ringTheBell = "Ring the Bell"
        case inContact = "In Contact"
        case custom = "Custom"

        static func from(type: String) -> AlertType {
            if type.contains("911") { return .emergency }
            if type.contains("Ring") { return .ringTheBell }
            if type.contains("Contact") { return .inContact }
            return .custom
        }
    }

    // Custom Equatable to handle CLLocationCoordinate2D
    static func == (lhs: EmergencyAlert, rhs: EmergencyAlert) -> Bool {
        lhs.id == rhs.id &&
        lhs.uid == rhs.uid &&
        lhs.alertType == rhs.alertType &&
        lhs.callsign == rhs.callsign &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.timestamp == rhs.timestamp &&
        lhs.message == rhs.message &&
        lhs.cancel == rhs.cancel
    }
}

extension EmergencyAlert: Equatable {}

// MARK: - CoT Message Parser

class CoTMessageParser {

    // MARK: - Main Parser

    /// Parse a CoT XML message and return the appropriate event type
    static func parse(xml: String) -> CoTEventType? {
        // Extract type first to determine message category
        guard let eventType = extractAttribute("type", from: xml) else {
            print("CoTMessageParser: Failed to extract event type")
            return nil
        }

        // Route based on type prefix
        if eventType.hasPrefix("a-") {
            // Position/SA message (a-f-*, a-h-*, a-n-*, a-u-*)
            if let cotEvent = parsePositionUpdate(xml: xml) {
                return .positionUpdate(cotEvent)
            }
        } else if eventType == "b-t-f" {
            // Chat message
            if let chatMessage = parseChatMessage(xml: xml) {
                return .chatMessage(chatMessage)
            }
        } else if eventType.hasPrefix("b-a-") {
            // Emergency alert
            if let alert = parseEmergencyAlert(xml: xml) {
                return .emergencyAlert(alert)
            }
        } else if eventType == "b-m-p-w" || eventType.hasPrefix("b-m-p-s-p-i") {
            // Waypoint marker
            if let cotEvent = parseWaypoint(xml: xml) {
                return .waypoint(cotEvent)
            }
        }

        // Return unknown type for unrecognized messages
        return .unknown(eventType)
    }

    // MARK: - Position Update Parser

    static func parsePositionUpdate(xml: String) -> CoTEvent? {
        // Extract required fields
        guard let uid = extractAttribute("uid", from: xml),
              let typeStr = extractAttribute("type", from: xml),
              let point = extractPoint(from: xml) else {
            return nil
        }

        // Extract timestamps
        let time = extractTimestamp("time", from: xml) ?? Date()
        let start = extractTimestamp("start", from: xml) ?? time
        let stale = extractTimestamp("stale", from: xml) ?? time.addingTimeInterval(3600)

        // Extract detail information
        let detail = extractDetail(from: xml)

        return CoTEvent(
            uid: uid,
            type: typeStr,
            time: time,
            point: point,
            detail: detail
        )
    }

    // MARK: - Chat Message Parser

    static func parseChatMessage(xml: String) -> ChatMessage? {
        // Delegate to existing ChatXMLParser for compatibility
        return ChatXMLParser.parseGeoChatMessage(xml: xml)
    }

    // MARK: - Emergency Alert Parser

    static func parseEmergencyAlert(xml: String) -> EmergencyAlert? {
        guard let uid = extractAttribute("uid", from: xml),
              let typeStr = extractAttribute("type", from: xml),
              let point = extractPoint(from: xml) else {
            return nil
        }

        // Extract callsign
        var callsign = uid
        if let callsignRange = xml.range(of: "callsign=\"([^\"]+)\"", options: .regularExpression) {
            let match = xml[callsignRange]
            callsign = extractValueFromQuotedAttribute(String(match)) ?? uid
        }

        // Extract alert type
        var alertTypeStr = "Custom"
        if let emergencyRange = xml.range(of: "<emergency[^>]*>([^<]*)</emergency>", options: .regularExpression) {
            let emergencyContent = String(xml[emergencyRange])
            if let typeAttr = extractAttribute("type", from: emergencyContent) {
                alertTypeStr = typeAttr
            }
        }

        // Check if this is a cancel message
        let isCancelled = xml.contains("cancel=\"true\"") || xml.contains("cancel=\"1\"")

        // Extract message from remarks
        var message: String? = nil
        if let remarksRange = xml.range(of: "<remarks>([^<]+)</remarks>", options: .regularExpression) {
            let remarksMatch = String(xml[remarksRange])
            if let start = remarksMatch.range(of: ">"),
               let end = remarksMatch.range(of: "</") {
                message = String(remarksMatch[start.upperBound..<end.lowerBound])
            }
        }

        let timestamp = extractTimestamp("time", from: xml) ?? Date()

        return EmergencyAlert(
            id: UUID().uuidString,
            uid: uid,
            alertType: EmergencyAlert.AlertType.from(type: alertTypeStr),
            callsign: callsign,
            coordinate: CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon),
            timestamp: timestamp,
            message: message,
            cancel: isCancelled
        )
    }

    // MARK: - Waypoint Parser

    static func parseWaypoint(xml: String) -> CoTEvent? {
        // Waypoints are similar to position updates but represent static markers
        return parsePositionUpdate(xml: xml)
    }

    // MARK: - Helper Methods

    private static func extractAttribute(_ name: String, from xml: String) -> String? {
        // Look for attribute pattern: name="value"
        let pattern = "\(name)=\"([^\"]+)\""
        guard let range = xml.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        return extractValueFromQuotedAttribute(String(xml[range]))
    }

    private static func extractValueFromQuotedAttribute(_ attr: String) -> String? {
        let parts = attr.split(separator: "\"")
        return parts.count > 1 ? String(parts[1]) : nil
    }

    private static func extractPoint(from xml: String) -> CoTPoint? {
        guard let pointRange = xml.range(of: "<point[^>]+>", options: .regularExpression) else {
            return nil
        }

        let pointTag = String(xml[pointRange])

        guard let latStr = extractAttribute("lat", from: pointTag),
              let lonStr = extractAttribute("lon", from: pointTag),
              let lat = Double(latStr),
              let lon = Double(lonStr) else {
            return nil
        }

        let hae = Double(extractAttribute("hae", from: pointTag) ?? "0") ?? 0
        let ce = Double(extractAttribute("ce", from: pointTag) ?? "9999") ?? 9999
        let le = Double(extractAttribute("le", from: pointTag) ?? "9999") ?? 9999

        return CoTPoint(lat: lat, lon: lon, hae: hae, ce: ce, le: le)
    }

    private static func extractTimestamp(_ attrName: String, from xml: String) -> Date? {
        guard let timeStr = extractAttribute(attrName, from: xml) else {
            return nil
        }

        // Try ISO8601 format first (2025-01-15T12:30:00Z)
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: timeStr) {
            return date
        }

        // Try without fractional seconds
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: timeStr) {
            return date
        }

        // Try custom TAK format (2025-01-15T12:30:00.000Z)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        if let date = dateFormatter.date(from: timeStr) {
            return date
        }

        // Try without milliseconds
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return dateFormatter.date(from: timeStr)
    }

    private static func extractDetail(from xml: String) -> CoTDetail {
        var callsign = ""
        var team: String? = nil
        var speed: Double? = nil
        var course: Double? = nil
        var remarks: String? = nil
        var battery: Int? = nil
        var device: String? = nil
        var platform: String? = nil

        // Extract callsign from contact element
        if let contactRange = xml.range(of: "<contact[^>]+/>", options: .regularExpression) {
            let contactTag = String(xml[contactRange])
            callsign = extractAttribute("callsign", from: contactTag) ?? ""
        }

        // Extract team from __group element
        if let groupRange = xml.range(of: "<__group[^>]*>", options: .regularExpression) {
            let groupTag = String(xml[groupRange])
            team = extractAttribute("name", from: groupTag)
        }

        // Extract speed and course from track element
        if let trackRange = xml.range(of: "<track[^>]+/>", options: .regularExpression) {
            let trackTag = String(xml[trackRange])
            if let speedStr = extractAttribute("speed", from: trackTag) {
                speed = Double(speedStr)
            }
            if let courseStr = extractAttribute("course", from: trackTag) {
                course = Double(courseStr)
            }
        }

        // Extract remarks
        if let remarksRange = xml.range(of: "<remarks>([^<]*)</remarks>", options: .regularExpression) {
            let remarksMatch = String(xml[remarksRange])
            if let start = remarksMatch.range(of: ">"),
               let end = remarksMatch.range(of: "</") {
                remarks = String(remarksMatch[start.upperBound..<end.lowerBound])
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                    .replacingOccurrences(of: "&amp;", with: "&")
            }
        }

        // Extract battery from status element
        if let statusRange = xml.range(of: "<status[^>]+/>", options: .regularExpression) {
            let statusTag = String(xml[statusRange])
            if let batteryStr = extractAttribute("battery", from: statusTag) {
                battery = Int(batteryStr)
            }
        }

        // Extract device and platform from takv element
        if let takvRange = xml.range(of: "<takv[^>]+/>", options: .regularExpression) {
            let takvTag = String(xml[takvRange])
            device = extractAttribute("device", from: takvTag)
            platform = extractAttribute("platform", from: takvTag)
        }

        return CoTDetail(
            callsign: callsign,
            team: team,
            speed: speed,
            course: course,
            remarks: remarks,
            battery: battery,
            device: device,
            platform: platform
        )
    }

    // MARK: - XML Stream Buffer

    /// Extract complete XML messages from a buffer that may contain multiple messages
    /// Returns array of complete XML strings and remaining incomplete buffer
    static func extractCompleteMessages(from buffer: String) -> (messages: [String], remaining: String) {
        var messages: [String] = []
        var currentBuffer = buffer

        // Look for complete <event>...</event> pairs
        while let startRange = currentBuffer.range(of: "<event") {
            // Find the closing </event> tag
            let searchString = String(currentBuffer[startRange.lowerBound...])

            if let endRange = searchString.range(of: "</event>") {
                // Extract the complete message
                let endIndex = searchString.index(endRange.upperBound, offsetBy: 0)
                let completeMessage = String(searchString[..<endIndex])
                messages.append(completeMessage)

                // Update buffer to remove the processed message
                let globalEndIndex = currentBuffer.index(startRange.lowerBound, offsetBy: searchString.distance(from: searchString.startIndex, to: endIndex))
                currentBuffer = String(currentBuffer[globalEndIndex...])
            } else {
                // Incomplete message, keep in buffer
                break
            }
        }

        return (messages, currentBuffer)
    }

    /// Validate if XML is well-formed CoT message
    static func isValidCoTMessage(_ xml: String) -> Bool {
        // Basic validation
        guard xml.contains("<event") && xml.contains("</event>") else {
            return false
        }

        // Must have uid and type attributes
        guard xml.contains("uid=\"") && xml.contains("type=\"") else {
            return false
        }

        // Must have point element
        guard xml.contains("<point") else {
            return false
        }

        return true
    }
}
