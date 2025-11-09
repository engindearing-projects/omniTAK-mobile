import Foundation
import Combine
import CoreLocation

// MARK: - Data Types

enum DataType: String, CaseIterable {
    case friendly = "friendly"      // a-f-*
    case hostile = "hostile"        // a-h-*
    case unknown = "unknown"        // a-u-*
    case neutral = "neutral"        // a-n-*
    case sensor = "sensor"          // b-*
    case geofence = "geofence"      // u-d-f
    case route = "route"            // b-m-p-c
    case casevac = "casevac"        // b-r-f-h-c
    case target = "target"          // u-d-c-c
    case all = "all"
}

// MARK: - Data Sharing Policy

struct DataSharingPolicy {
    var receiveTypes: [DataType]
    var sendTypes: [DataType]
    var autoShare: Bool
    var blueTeamOnly: Bool
    var bidirectional: Bool

    static var `default`: DataSharingPolicy {
        DataSharingPolicy(
            receiveTypes: [.all],
            sendTypes: [.friendly],  // Default: only send friendly data
            autoShare: true,
            blueTeamOnly: true,      // Default: blue team mode on
            bidirectional: true
        )
    }
}

// MARK: - Federated Server

struct FederatedServer: Identifiable {
    let id: String
    var name: String
    var host: String
    var port: UInt16
    var protocolType: String
    var useTLS: Bool
    var policy: DataSharingPolicy
    var status: ServerStatus
    var lastError: String?
    var takService: TAKService?

    enum ServerStatus: String {
        case connected
        case connecting
        case disconnected
        case error
    }
}

// MARK: - Federated CoT Event

struct FederatedCoTEvent {
    let event: CoTEvent
    let sourceServerId: String
    let sourceServerName: String
    let receivedAt: Date
    var sharedTo: [String]  // Server IDs this event has been shared to
}

// MARK: - Multi-Server Federation Manager

class MultiServerFederation: ObservableObject {
    @Published var servers: [FederatedServer] = []
    @Published var federatedEvents: [String: FederatedCoTEvent] = [:]  // UID -> Event

    private var cancellables = Set<AnyCancellable>()

    init() {
        print("🌐 MultiServerFederation initialized")
    }

    // MARK: - Server Management

    func addServer(
        id: String,
        name: String,
        host: String,
        port: UInt16,
        protocolType: String,
        useTLS: Bool,
        policy: DataSharingPolicy = .default
    ) {
        let server = FederatedServer(
            id: id,
            name: name,
            host: host,
            port: port,
            protocolType: protocolType,
            useTLS: useTLS,
            policy: policy,
            status: .disconnected,
            takService: nil
        )

        servers.append(server)
        print("✅ Added server to federation: \(name) (\(id))")
    }

    func removeServer(id: String) {
        if let index = servers.firstIndex(where: { $0.id == id }) {
            let server = servers[index]
            if server.status == .connected {
                disconnectServer(id: id)
            }
            servers.remove(at: index)
            print("🗑️ Removed server from federation: \(id)")
        }
    }

    func updatePolicy(id: String, policy: DataSharingPolicy) {
        if let index = servers.firstIndex(where: { $0.id == id }) {
            servers[index].policy = policy
            print("📋 Updated policy for server: \(id)")
        }
    }

    // MARK: - Connection Management

    func connectServer(id: String) {
        guard let index = servers.firstIndex(where: { $0.id == id }) else {
            print("❌ Server not found: \(id)")
            return
        }

        let server = servers[index]
        if server.status == .connected {
            print("⚠️ Server already connected: \(id)")
            return
        }

        servers[index].status = .connecting

        // Create TAKService instance
        let takService = TAKService()
        servers[index].takService = takService

        // Subscribe to CoT events from this server
        takService.onCoTReceived = { [weak self] event in
            self?.handleIncomingCoT(serverId: id, event: event)
        }

        // Connect to server
        takService.connect(
            host: server.host,
            port: server.port,
            protocolType: server.protocolType,
            useTLS: server.useTLS
        )

        // Update status based on connection result
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            if takService.isConnected {
                if let idx = self.servers.firstIndex(where: { $0.id == id }) {
                    self.servers[idx].status = .connected
                    print("✅ Connected to server: \(server.name) (\(id))")
                }
            } else {
                if let idx = self.servers.firstIndex(where: { $0.id == id }) {
                    self.servers[idx].status = .error
                    self.servers[idx].lastError = "Failed to connect"
                    print("❌ Failed to connect to server: \(id)")
                }
            }
        }
    }

    func disconnectServer(id: String) {
        guard let index = servers.firstIndex(where: { $0.id == id }) else {
            return
        }

        servers[index].takService?.disconnect()
        servers[index].takService = nil
        servers[index].status = .disconnected

        print("🔌 Disconnected from server: \(id)")
    }

    func connectAll() {
        print("⚡ Connecting to all servers...")
        for server in servers {
            if server.status == .disconnected {
                connectServer(id: server.id)
            }
        }
    }

    func disconnectAll() {
        print("⏸ Disconnecting from all servers...")
        for server in servers {
            if server.status == .connected {
                disconnectServer(id: server.id)
            }
        }
    }

    // MARK: - Data Federation

    private func handleIncomingCoT(serverId: String, event: CoTEvent) {
        guard let server = servers.first(where: { $0.id == serverId }) else {
            return
        }

        // Check if this data type should be received from this server
        if !shouldReceive(server: server, event: event) {
            print("🚫 Filtered incoming event from \(server.name): \(event.type)")
            return
        }

        // Create or update federated event
        let federatedEvent: FederatedCoTEvent
        if let existing = federatedEvents[event.uid] {
            federatedEvent = FederatedCoTEvent(
                event: event,
                sourceServerId: existing.sourceServerId,
                sourceServerName: existing.sourceServerName,
                receivedAt: existing.receivedAt,
                sharedTo: existing.sharedTo
            )
        } else {
            federatedEvent = FederatedCoTEvent(
                event: event,
                sourceServerId: serverId,
                sourceServerName: server.name,
                receivedAt: Date(),
                sharedTo: []
            )
        }

        federatedEvents[event.uid] = federatedEvent

        // Auto-share to other servers if policy allows
        if server.policy.autoShare {
            shareEventToOtherServers(event: federatedEvent, sourceServerId: serverId)
        }
    }

    private func shouldReceive(server: FederatedServer, event: CoTEvent) -> Bool {
        let policy = server.policy

        if policy.receiveTypes.contains(.all) {
            return true
        }

        let dataType = getDataType(cotType: event.type)
        return policy.receiveTypes.contains(dataType)
    }

    private func shouldSend(server: FederatedServer, event: CoTEvent) -> Bool {
        let policy = server.policy

        // Blue team only mode: only send friendly data
        if policy.blueTeamOnly && !event.type.contains("a-f-") {
            return false
        }

        if policy.sendTypes.contains(.all) {
            return true
        }

        let dataType = getDataType(cotType: event.type)
        return policy.sendTypes.contains(dataType)
    }

    private func shareEventToOtherServers(event: FederatedCoTEvent, sourceServerId: String) {
        let cotXml = generateCoTXml(event: event.event)

        for server in servers {
            // Skip source server and already shared servers
            if server.id == sourceServerId || event.sharedTo.contains(server.id) {
                continue
            }

            // Skip if not connected
            if server.status != .connected || server.takService == nil {
                continue
            }

            // Check if this server should receive this data
            if !shouldSend(server: server, event: event.event) {
                print("🚫 Not sharing event to \(server.name): policy restriction")
                continue
            }

            // Send to server
            if let takService = server.takService {
                let success = takService.sendCoT(xml: cotXml)
                if success {
                    federatedEvents[event.event.uid]?.sharedTo.append(server.id)
                    print("✅ Shared event \(event.event.uid) to \(server.name)")
                }
            }
        }
    }

    // MARK: - Manual Sending

    func sendToServers(event: CoTEvent, serverIds: [String]) {
        let cotXml = generateCoTXml(event: event)

        for serverId in serverIds {
            guard let server = servers.first(where: { $0.id == serverId }) else {
                print("⚠️ Cannot send to server \(serverId): not found")
                continue
            }

            guard server.status == .connected, let takService = server.takService else {
                print("⚠️ Cannot send to server \(serverId): not connected")
                continue
            }

            if !shouldSend(server: server, event: event) {
                print("⚠️ Cannot send to server \(serverId): policy restriction")
                continue
            }

            _ = takService.sendCoT(xml: cotXml)
        }
    }

    func broadcast(event: CoTEvent) {
        let serverIds = servers.map { $0.id }
        sendToServers(event: event, serverIds: serverIds)
    }

    // MARK: - Utility Functions

    private func getDataType(cotType: String) -> DataType {
        if cotType.hasPrefix("a-f-") { return .friendly }
        if cotType.hasPrefix("a-h-") { return .hostile }
        if cotType.hasPrefix("a-u-") { return .unknown }
        if cotType.hasPrefix("a-n-") { return .neutral }
        if cotType.hasPrefix("b-m-p-c") { return .route }
        if cotType.hasPrefix("b-r-f-h-c") { return .casevac }
        if cotType.hasPrefix("u-d-f") { return .geofence }
        if cotType.hasPrefix("u-d-c-c") { return .target }
        if cotType.hasPrefix("b-") { return .sensor }
        return .unknown
    }

    private func generateCoTXml(event: CoTEvent) -> String {
        let callsign = event.detail.callsign
        let team = event.detail.team ?? "Cyan"

        let dateFormatter = ISO8601DateFormatter()
        let time = dateFormatter.string(from: event.time)
        let start = time
        let stale = dateFormatter.string(from: event.time.addingTimeInterval(3600))

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(event.uid)" type="\(event.type)" time="\(time)" start="\(start)" stale="\(stale)" how="h-e">
          <point lat="\(event.point.lat)" lon="\(event.point.lon)" hae="\(event.point.hae)" ce="\(event.point.ce)" le="\(event.point.le)"/>
          <detail>
            <contact callsign="\(callsign)"/>
            <__group name="\(team)" role="Team Member"/>
          </detail>
        </event>
        """
    }

    func getConnectedCount() -> Int {
        return servers.filter { $0.status == .connected }.count
    }

    func getTotalCount() -> Int {
        return servers.count
    }

    func clearCache() {
        federatedEvents.removeAll()
        print("🗑️ Event cache cleared")
    }
}
