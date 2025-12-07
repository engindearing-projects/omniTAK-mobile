//
//  MeshtasticCoTConverter.swift
//  OmniTAK Mobile
//
//  Converts Meshtastic mesh nodes to TAK-compatible CoT events
//

import Foundation
import CoreLocation

// MARK: - Meshtastic CoT Converter

/// Converts Meshtastic mesh network nodes to TAK-compatible CoT (Cursor on Target) events
class MeshtasticCoTConverter {

    // MARK: - CoT Generation

    /// Generate CoT XML for a Meshtastic mesh node
    /// - Parameters:
    ///   - node: The mesh node to convert
    ///   - staleTime: How long the event should remain valid (default 5 minutes)
    /// - Returns: TAK-compatible CoT XML string
    static func generateCoT(for node: MeshNode, staleTime: TimeInterval = 300) -> String? {
        // Position is required for map display
        guard let position = node.position else {
            return nil
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let now = Date()
        let stale = now.addingTimeInterval(staleTime)

        // Create unique UID for the mesh node
        let uid = "mesh-\(String(format: "%08X", node.id).lowercased())"

        // CoT type for meshtastic nodes - using neutral atom type with ground presence
        // a-n-G = atom, neutral, ground
        let cotType = "a-n-G-U-C"

        let lat = position.latitude
        let lon = position.longitude
        let hae = Double(position.altitude ?? 0)

        // Create callsign from node name
        let callsign = escapeXML(node.longName.isEmpty ? node.shortName : node.longName)
        let shortName = escapeXML(node.shortName)

        // Build remarks with mesh-specific info
        var remarks = "Meshtastic Node\n"
        remarks += "Short Name: \(shortName)\n"
        remarks += "Node ID: !\(String(format: "%08x", node.id))"

        if let snr = node.snr {
            remarks += "\nSNR: \(String(format: "%.1f", snr)) dB"
        }

        if let hops = node.hopDistance {
            remarks += "\nHop Distance: \(hops)"
        }

        if let battery = node.batteryLevel {
            remarks += "\nBattery: \(battery)%"
        }

        let lastHeardStr = formatTimeAgo(from: node.lastHeard)
        remarks += "\nLast Heard: \(lastHeardStr)"

        // Build the CoT XML
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(uid)" type="\(cotType)" time="\(dateFormatter.string(from: now))" start="\(dateFormatter.string(from: now))" stale="\(dateFormatter.string(from: stale))" how="m-g">
            <point lat="\(lat)" lon="\(lon)" hae="\(hae)" ce="50.0" le="50.0"/>
            <detail>
                <contact callsign="\(callsign)"/>
                <usericon iconsetpath="COT_MAPPING_2525C/a-n-G"/>
                <color argb="-16744320"/>
                <remarks>\(escapeXML(remarks))</remarks>
                <precisionlocation altsrc="GPS" geopointsrc="Meshtastic"/>
                <status readiness="true"/>
                <__meshtastic__>
                    <node_id>\(String(format: "%08X", node.id))</node_id>
                    <short_name>\(shortName)</short_name>
                    <long_name>\(callsign)</long_name>
                    <snr>\(node.snr ?? 0)</snr>
                    <hop_distance>\(node.hopDistance ?? 0)</hop_distance>
                    <battery>\(node.batteryLevel ?? -1)</battery>
                    <last_heard>\(dateFormatter.string(from: node.lastHeard))</last_heard>
                </__meshtastic__>
                <takv device="Meshtastic" platform="OmniTAK" os="iOS" version="\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0")"/>
            </detail>
        </event>
        """

        return xml
    }

    /// Generate CoT for self/local node
    static func generateSelfNodeCoT(nodeNum: UInt32, firmwareVersion: String, position: MeshPosition?, staleTime: TimeInterval = 300) -> String? {
        guard let position = position else { return nil }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let now = Date()
        let stale = now.addingTimeInterval(staleTime)

        let uid = "mesh-self-\(String(format: "%08X", nodeNum).lowercased())"
        let cotType = "a-f-G-U-C" // Friendly ground unit

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(uid)" type="\(cotType)" time="\(dateFormatter.string(from: now))" start="\(dateFormatter.string(from: now))" stale="\(dateFormatter.string(from: stale))" how="m-g">
            <point lat="\(position.latitude)" lon="\(position.longitude)" hae="\(Double(position.altitude ?? 0))" ce="10.0" le="10.0"/>
            <detail>
                <contact callsign="Meshtastic !\(String(format: "%08x", nodeNum))"/>
                <usericon iconsetpath="COT_MAPPING_2525C/a-f-G"/>
                <color argb="-16711936"/>
                <remarks>My Meshtastic Node\nFirmware: \(firmwareVersion)</remarks>
                <precisionlocation altsrc="GPS" geopointsrc="Meshtastic"/>
                <status readiness="true"/>
                <__meshtastic__>
                    <node_id>\(String(format: "%08X", nodeNum))</node_id>
                    <is_self>true</is_self>
                    <firmware>\(firmwareVersion)</firmware>
                </__meshtastic__>
                <takv device="Meshtastic" platform="OmniTAK" os="iOS" version="\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0")"/>
            </detail>
        </event>
        """

        return xml
    }

    /// Generate CoT events for all nodes in the mesh
    static func generateCoTForAllNodes(_ nodes: [MeshNode], staleTime: TimeInterval = 300) -> [String] {
        return nodes.compactMap { generateCoT(for: $0, staleTime: staleTime) }
    }

    /// Parse CoT XML to extract Meshtastic node info (for incoming events)
    static func parseMeshtasticNode(from cotXML: String) -> MeshNode? {
        guard cotXML.contains("__meshtastic__") else { return nil }

        // Extract node_id
        guard let nodeIdMatch = cotXML.range(of: "<node_id>([^<]+)</node_id>", options: .regularExpression),
              let nodeIdHex = cotXML[nodeIdMatch].split(separator: ">").dropFirst().first?.split(separator: "<").first,
              let nodeId = UInt32(nodeIdHex, radix: 16) else {
            return nil
        }

        // Extract short_name
        let shortName: String
        if let shortNameMatch = cotXML.range(of: "<short_name>([^<]*)</short_name>", options: .regularExpression) {
            let shortNameStr = String(cotXML[shortNameMatch])
            shortName = shortNameStr.replacingOccurrences(of: "<short_name>", with: "")
                                    .replacingOccurrences(of: "</short_name>", with: "")
        } else {
            shortName = String(format: "%04X", nodeId & 0xFFFF)
        }

        // Extract long_name
        let longName: String
        if let longNameMatch = cotXML.range(of: "<long_name>([^<]*)</long_name>", options: .regularExpression) {
            let longNameStr = String(cotXML[longNameMatch])
            longName = longNameStr.replacingOccurrences(of: "<long_name>", with: "")
                                   .replacingOccurrences(of: "</long_name>", with: "")
        } else {
            longName = "Node \(String(format: "%08X", nodeId))"
        }

        // Extract position from point element
        var position: MeshPosition? = nil
        if let pointMatch = cotXML.range(of: "<point[^>]+>", options: .regularExpression) {
            let pointStr = String(cotXML[pointMatch])
            if let latMatch = pointStr.range(of: "lat=\"([^\"]+)\"", options: .regularExpression),
               let lonMatch = pointStr.range(of: "lon=\"([^\"]+)\"", options: .regularExpression) {
                let latStr = pointStr[latMatch].replacingOccurrences(of: "lat=\"", with: "").replacingOccurrences(of: "\"", with: "")
                let lonStr = pointStr[lonMatch].replacingOccurrences(of: "lon=\"", with: "").replacingOccurrences(of: "\"", with: "")

                if let lat = Double(latStr), let lon = Double(lonStr) {
                    var alt: Int? = nil
                    if let haeMatch = pointStr.range(of: "hae=\"([^\"]+)\"", options: .regularExpression) {
                        let haeStr = pointStr[haeMatch].replacingOccurrences(of: "hae=\"", with: "").replacingOccurrences(of: "\"", with: "")
                        alt = Int(Double(haeStr) ?? 0)
                    }
                    position = MeshPosition(latitude: lat, longitude: lon, altitude: alt)
                }
            }
        }

        // Extract SNR
        var snr: Double? = nil
        if let snrMatch = cotXML.range(of: "<snr>([^<]+)</snr>", options: .regularExpression) {
            let snrStr = String(cotXML[snrMatch]).replacingOccurrences(of: "<snr>", with: "").replacingOccurrences(of: "</snr>", with: "")
            snr = Double(snrStr)
        }

        // Extract hop distance
        var hopDistance: Int? = nil
        if let hopMatch = cotXML.range(of: "<hop_distance>([^<]+)</hop_distance>", options: .regularExpression) {
            let hopStr = String(cotXML[hopMatch]).replacingOccurrences(of: "<hop_distance>", with: "").replacingOccurrences(of: "</hop_distance>", with: "")
            hopDistance = Int(hopStr)
        }

        // Extract battery
        var battery: Int? = nil
        if let batteryMatch = cotXML.range(of: "<battery>([^<]+)</battery>", options: .regularExpression) {
            let batteryStr = String(cotXML[batteryMatch]).replacingOccurrences(of: "<battery>", with: "").replacingOccurrences(of: "</battery>", with: "")
            if let b = Int(batteryStr), b >= 0 {
                battery = b
            }
        }

        return MeshNode(
            id: nodeId,
            shortName: shortName,
            longName: longName,
            position: position,
            lastHeard: Date(),
            snr: snr,
            hopDistance: hopDistance,
            batteryLevel: battery
        )
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

    /// Format time ago string
    private static func formatTimeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))

        if seconds < 60 {
            return "\(seconds) seconds ago"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = seconds / 86400
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }

    // MARK: - Direct CoTEvent Generation

    /// Convert a MeshNode directly to a CoTEvent for TAKService.updateEnhancedMarker()
    /// - Parameter node: The mesh node to convert
    /// - Returns: CoTEvent object ready for TAKService, or nil if node has no position
    static func toCoTEvent(node: MeshNode, isOwnNode: Bool = false) -> CoTEvent? {
        guard let position = node.position else { return nil }

        let uid = isOwnNode ? "mesh-self-\(String(format: "%08X", node.id).lowercased())" : node.takUID
        let cotType = isOwnNode ? "a-f-G-U-C" : "a-n-G-U-C"  // Friendly for self, Neutral for others
        let callsign = node.longName.isEmpty ? node.shortName : node.longName

        // Build remarks
        var remarks = "Meshtastic Node"
        remarks += " | ID: \(node.formattedNodeId)"
        if let snr = node.snr {
            remarks += " | SNR: \(String(format: "%.1f", snr))dB"
        }
        if let hops = node.hopDistance {
            remarks += " | Hops: \(hops)"
        }
        if let battery = node.batteryLevel {
            remarks += " | Bat: \(battery)%"
        }

        let point = CoTPoint(
            lat: position.latitude,
            lon: position.longitude,
            hae: Double(position.altitude ?? 0),
            ce: 50.0,
            le: 50.0
        )

        let detail = CoTDetail(
            callsign: callsign,
            team: "Meshtastic",
            speed: nil,
            course: nil,
            remarks: remarks,
            battery: node.batteryLevel,
            device: "Meshtastic",
            platform: "LoRa"
        )

        return CoTEvent(
            uid: uid,
            type: cotType,
            time: node.lastHeard,
            point: point,
            detail: detail
        )
    }

    /// Convert all mesh nodes to CoTEvents
    static func toCoTEvents(nodes: [MeshNode], ownNodeId: UInt32? = nil) -> [CoTEvent] {
        return nodes.compactMap { node in
            let isOwn = (ownNodeId != nil && node.id == ownNodeId)
            return toCoTEvent(node: node, isOwnNode: isOwn)
        }
    }
}

// MARK: - Meshtastic Node UID Helper

extension MeshNode {
    /// Get the TAK-compatible UID for this node
    var takUID: String {
        return "mesh-\(String(format: "%08X", id).lowercased())"
    }

    /// Get the formatted node ID (with ! prefix like Meshtastic app)
    var formattedNodeId: String {
        return "!\(String(format: "%08x", id))"
    }
}
