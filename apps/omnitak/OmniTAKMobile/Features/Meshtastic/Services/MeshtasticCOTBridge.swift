//
//  MeshtasticCOTBridge.swift
//  OmniTAK Mobile
//
//  Bridge service that converts Meshtastic mesh node data to COT (Cursor on Target)
//  format and publishes them to the TAK system for display on the map.
//

import Foundation
import Combine
import CoreLocation

/// Bridge service that observes Meshtastic nodes and converts them to COT events
@MainActor
class MeshtasticCOTBridge: ObservableObject {

    // MARK: - Singleton

    static let shared = MeshtasticCOTBridge()

    // MARK: - Published Properties

    @Published var isEnabled: Bool = true
    @Published var lastConversionTime: Date?
    @Published var nodesConverted: Int = 0

    // MARK: - Configuration

    /// Team color for Meshtastic nodes on the map
    var meshtasticTeamColor: String = "Cyan"

    /// Role assigned to Meshtastic nodes
    var meshtasticRole: String = "Team Member"

    /// COT type for Meshtastic nodes (friendly ground unit)
    var cotType: String = "a-f-G-U-C"

    /// How long before a COT event is considered stale (5 minutes default)
    var staleTimeInterval: TimeInterval = 300

    // MARK: - Dependencies

    private weak var meshtasticManager: MeshtasticManager?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        print("MeshtasticCOTBridge: Initialized")
    }

    // MARK: - Setup

    /// Configure the bridge with the Meshtastic manager to observe
    func configure(meshtasticManager: MeshtasticManager) {
        self.meshtasticManager = meshtasticManager

        // Observe changes to mesh nodes
        meshtasticManager.$meshNodes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] nodes in
                self?.handleNodesUpdate(nodes)
            }
            .store(in: &cancellables)

        // Also observe connection state for logging
        meshtasticManager.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                print("MeshtasticCOTBridge: Connection state changed to \(state)")
                if state == "Disconnected" {
                    self?.handleDisconnection()
                }
            }
            .store(in: &cancellables)

        print("MeshtasticCOTBridge: Configured with MeshtasticManager")
    }

    // MARK: - Node Processing

    /// Handle updates to the mesh nodes array
    private func handleNodesUpdate(_ nodes: [MeshNode]) {
        guard isEnabled else { return }

        for node in nodes {
            // Only process nodes that have position data
            guard let position = node.position else {
                #if DEBUG
                print("MeshtasticCOTBridge: Skipping node \(node.shortName) - no position data")
                #endif
                continue
            }

            // Convert to COT and publish
            if let cotEvent = convertNodeToCOT(node: node, position: position) {
                publishCOTEvent(cotEvent)
                nodesConverted += 1
            }
        }

        lastConversionTime = Date()

        #if DEBUG
        print("MeshtasticCOTBridge: Processed \(nodes.count) nodes, \(nodes.filter { $0.position != nil }.count) with positions")
        #endif
    }

    /// Handle disconnection - optionally mark nodes as stale
    private func handleDisconnection() {
        // When disconnected, we could optionally mark all Meshtastic nodes as offline
        // For now, just log it - the stale timeout will handle cleanup
        print("MeshtasticCOTBridge: Meshtastic disconnected")
    }

    // MARK: - COT Conversion

    /// Convert a MeshNode to a CoTEvent
    func convertNodeToCOT(node: MeshNode, position: MeshPosition) -> CoTEvent? {
        // Generate unique UID for this Meshtastic node
        let uid = "MESHTASTIC-\(String(format: "%08X", node.id))"

        // Create COT point from mesh position
        let cotPoint = CoTPoint(
            lat: position.latitude,
            lon: position.longitude,
            hae: Double(position.altitude ?? 0),
            ce: 10.0,  // Circular error estimate
            le: 10.0   // Linear error estimate
        )

        // Build remarks with Meshtastic-specific info
        var remarks = "Meshtastic Node"
        if let snr = node.snr {
            remarks += " | SNR: \(String(format: "%.1f", snr))dB"
        }
        if let hops = node.hopDistance {
            remarks += " | Hops: \(hops)"
        }
        if let battery = node.batteryLevel {
            remarks += " | Battery: \(battery)%"
        }

        // Create detail with callsign and team info
        let cotDetail = CoTDetail(
            callsign: node.shortName.isEmpty ? "MESH-\(String(format: "%04X", node.id & 0xFFFF))" : node.shortName,
            team: meshtasticTeamColor,
            speed: nil,
            course: nil,
            remarks: remarks,
            battery: node.batteryLevel,
            device: "Meshtastic",
            platform: "Meshtastic Mesh Radio"
        )

        // Use node's lastHeard time or current time
        let eventTime = node.lastHeard

        return CoTEvent(
            uid: uid,
            type: cotType,
            time: eventTime,
            point: cotPoint,
            detail: cotDetail
        )
    }

    /// Generate COT XML string from a MeshNode (for direct transmission)
    func generateCOTXML(from node: MeshNode) -> String? {
        guard let position = node.position else { return nil }
        guard let cotEvent = convertNodeToCOT(node: node, position: position) else { return nil }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let timeStr = dateFormatter.string(from: cotEvent.time)
        let startStr = timeStr
        let staleStr = dateFormatter.string(from: cotEvent.time.addingTimeInterval(staleTimeInterval))

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(cotEvent.uid)" type="\(cotEvent.type)" time="\(timeStr)" start="\(startStr)" stale="\(staleStr)">
            <point lat="\(cotEvent.point.lat)" lon="\(cotEvent.point.lon)" hae="\(cotEvent.point.hae)" ce="\(cotEvent.point.ce)" le="\(cotEvent.point.le)"/>
            <detail>
                <contact callsign="\(cotEvent.detail.callsign)"/>
                <__group name="\(meshtasticTeamColor)" role="\(meshtasticRole)"/>
                <precisionlocation altsrc="GPS" geopointsrc="GPS"/>
                <status battery="\(cotEvent.detail.battery ?? 100)"/>
                <takv device="\(cotEvent.detail.device ?? "Meshtastic")" platform="\(cotEvent.detail.platform ?? "Meshtastic")" version="1.0"/>
                <remarks>\(cotEvent.detail.remarks ?? "")</remarks>
            </detail>
        </event>
        """

        return xml
    }

    // MARK: - COT Publishing

    /// Publish a COT event to the TAK system
    private func publishCOTEvent(_ event: CoTEvent) {
        // Create the event type wrapper
        let eventType = CoTEventType.positionUpdate(event)

        // Send to the CoTEventHandler for processing
        CoTEventHandler.shared.handle(event: eventType)

        #if DEBUG
        print("MeshtasticCOTBridge: Published COT for \(event.detail.callsign) at (\(event.point.lat), \(event.point.lon))")
        #endif
    }

    // MARK: - Manual Refresh

    /// Force refresh all current nodes to COT
    func refreshAllNodes() {
        guard let manager = meshtasticManager else {
            print("MeshtasticCOTBridge: Cannot refresh - not configured")
            return
        }

        handleNodesUpdate(manager.meshNodes)
    }

    // MARK: - Statistics

    var statistics: String {
        let lastTime = lastConversionTime.map { DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .medium) } ?? "Never"
        return "Nodes converted: \(nodesConverted) | Last: \(lastTime)"
    }
}
