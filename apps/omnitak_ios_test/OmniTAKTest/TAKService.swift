import Foundation
import Combine
import CoreLocation
import Network

// MARK: - Direct Network Sender (bypasses incomplete Rust FFI)

enum ConnectionProtocol {
    case tcp
    case udp
    case tls
}

/// Direct network sender for CoT messages
/// Supports TCP, UDP, and TLS protocols
class DirectTCPSender {
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.omnitak.network")
    private var currentProtocol: ConnectionProtocol = .tcp

    var isConnected: Bool {
        return connection?.state == .ready
    }

    func connect(host: String, port: UInt16, protocolType: String = "tcp", useTLS: Bool = false, completion: @escaping (Bool) -> Void) {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!
        )

        // Determine protocol and parameters
        let parameters: NWParameters

        if useTLS || protocolType.lowercased() == "tls" {
            // TLS over TCP
            currentProtocol = .tls
            parameters = NWParameters(tls: NWProtocolTLS.Options(), tcp: NWProtocolTCP.Options())
            print("🔒 Using TLS/SSL")
        } else if protocolType.lowercased() == "udp" {
            // UDP
            currentProtocol = .udp
            parameters = NWParameters.udp
            print("📡 Using UDP")
        } else {
            // TCP (default)
            currentProtocol = .tcp
            parameters = NWParameters.tcp
            print("🔌 Using TCP")
        }

        connection = NWConnection(to: endpoint, using: parameters)

        connection?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("✅ Direct\(self.currentProtocol): Connected to \(host):\(port)")
                completion(true)
            case .failed(let error):
                print("❌ Direct\(self.currentProtocol): Connection failed: \(error)")
                completion(false)
            case .waiting(let error):
                print("⏳ Direct\(self.currentProtocol): Waiting to connect: \(error)")
            default:
                break
            }
        }

        connection?.start(queue: queue)
    }

    func send(xml: String) -> Bool {
        guard let connection = connection, connection.state == .ready else {
            print("❌ DirectNetwork: Not connected")
            return false
        }

        // TAK servers expect messages terminated with newline
        let message = xml + "\n"

        guard let data = message.data(using: .utf8) else {
            print("❌ DirectNetwork: Failed to encode XML")
            return false
        }

        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("❌ DirectNetwork: Send failed: \(error)")
            } else {
                print("📤 DirectNetwork: Sent \(data.count) bytes")
            }
        })

        return true
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        print("🔌 DirectNetwork: Disconnected")
    }
}

// MARK: - CoT Event Models

// CoT Event Model
struct CoTEvent {
    let uid: String
    let type: String
    let time: Date
    let point: CoTPoint
    let detail: CoTDetail
}

struct CoTPoint {
    let lat: Double
    let lon: Double
    let hae: Double
    let ce: Double
    let le: Double
}

struct CoTDetail {
    let callsign: String
    let team: String?
    // Enhanced fields
    let speed: Double?
    let course: Double?
    let remarks: String?
    let battery: Int?
    let device: String?
    let platform: String?
}

class TAKService: ObservableObject {
    @Published var connectionStatus = "Disconnected"
    @Published var isConnected = false
    @Published var lastError = ""
    @Published var messagesReceived: Int = 0
    @Published var messagesSent: Int = 0
    @Published var lastMessage = ""
    @Published var cotEvents: [CoTEvent] = []
    @Published var enhancedMarkers: [String: EnhancedCoTMarker] = [:]  // UID -> Marker map

    private var connectionHandle: UInt64 = 0
    private var directTCP: DirectTCPSender?  // Direct TCP sender (bypasses incomplete Rust FFI)
    var onCoTReceived: ((CoTEvent) -> Void)?
    var onMarkerUpdated: ((EnhancedCoTMarker) -> Void)?
    var onChatMessageReceived: ((ChatMessage) -> Void)?

    // History tracking configuration
    var maxHistoryPerUnit: Int = 100
    var historyRetentionTime: TimeInterval = 3600  // 1 hour

    init() {
        // Initialize the omnitak library
        let result = omnitak_init()
        if result != 0 {
            print("❌ Failed to initialize omnitak library")
        }

        // Initialize direct TCP sender
        directTCP = DirectTCPSender()
    }

    deinit {
        disconnect()
        omnitak_shutdown()
    }

    func connect(host: String, port: UInt16, protocolType: String, useTLS: Bool) {
        print("🔌 TAKService.connect() called with host=\(host), port=\(port), protocol=\(protocolType), tls=\(useTLS)")

        // Use DirectTCPSender for actual network communication
        connectionStatus = "Connecting..."
        directTCP?.connect(host: host, port: port, protocolType: protocolType, useTLS: useTLS) { [weak self] success in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if success {
                    self.isConnected = true
                    self.connectionStatus = "Connected"
                    self.lastError = ""
                    print("✅ DirectTCP Connected to TAK server: \(host):\(port)")

                    // Also initialize Rust FFI (for potential future use)
                    var protocolCode: Int32
                    switch protocolType.lowercased() {
                    case "tcp":
                        protocolCode = 0
                    case "udp":
                        protocolCode = 1
                    case "tls":
                        protocolCode = 2
                    case "websocket", "ws":
                        protocolCode = 3
                    default:
                        protocolCode = 0
                    }

                    let hostCStr = host.cString(using: .utf8)!
                    let result = omnitak_connect(
                        hostCStr,
                        port,
                        protocolCode,
                        useTLS ? 1 : 0,
                        nil, nil, nil
                    )

                    if result > 0 {
                        self.connectionHandle = result
                        self.registerCallback()
                        print("📡 Rust FFI also initialized (connection ID: \(result))")
                    }
                } else {
                    self.connectionStatus = "Connection Failed"
                    self.lastError = "Failed to connect to \(host):\(port)"
                    print("❌ Connection failed")
                }
            }
        }
    }

    func disconnect() {
        // Disconnect DirectTCP
        directTCP?.disconnect()

        // Also disconnect Rust FFI
        if connectionHandle > 0 {
            omnitak_unregister_callback(connectionHandle)
            omnitak_disconnect(connectionHandle)
            connectionHandle = 0
        }

        isConnected = false
        connectionStatus = "Disconnected"
        print("🔌 Disconnected from TAK server")
    }

    func sendCoT(xml: String) -> Bool {
        guard isConnected, let directTCP = directTCP else {
            print("❌ Not connected")
            return false
        }

        // Use DirectTCPSender for actual sending
        if directTCP.send(xml: xml) {
            messagesSent += 1
            print("📤 Sent CoT message via DirectTCP")

            // Also send via Rust FFI for testing (even though it's a stub)
            if connectionHandle > 0 {
                let xmlCStr = xml.cString(using: .utf8)!
                _ = omnitak_send_cot(connectionHandle, xmlCStr)
            }

            return true
        } else {
            print("❌ Failed to send CoT message")
            return false
        }
    }

    // Send chat message (wrapper for convenience)
    func sendChatMessage(xml: String) -> Bool {
        return sendCoT(xml: xml)
    }

    private func registerCallback() {
        // Create context pointer
        let context = Unmanaged.passUnretained(self).toOpaque()

        // Register callback
        omnitak_register_callback(connectionHandle, cotCallback, context)
    }

    // MARK: - Enhanced Marker Management

    func updateEnhancedMarker(from event: CoTEvent) {
        let coordinate = CLLocationCoordinate2D(
            latitude: event.point.lat,
            longitude: event.point.lon
        )

        let affiliation = UnitAffiliation.from(cotType: event.type)
        let unitType = UnitType.from(cotType: event.type)

        // Check if marker exists
        if var existingMarker = enhancedMarkers[event.uid] {
            // Update existing marker
            var updatedHistory = existingMarker.positionHistory

            // Add new position if it's different enough
            let newPosition = CoTPosition(
                coordinate: coordinate,
                altitude: event.point.hae,
                timestamp: event.time,
                speed: event.detail.speed,
                course: event.detail.course
            )

            // Only add if position changed significantly
            if shouldAddToHistory(newPosition: newPosition, existingHistory: updatedHistory) {
                updatedHistory.append(newPosition)

                // Trim history to max length
                if updatedHistory.count > maxHistoryPerUnit {
                    updatedHistory = Array(updatedHistory.suffix(maxHistoryPerUnit))
                }

                // Remove old positions
                let cutoffTime = Date().addingTimeInterval(-historyRetentionTime)
                updatedHistory.removeAll { $0.timestamp < cutoffTime }
            }

            // Create updated marker
            let updatedMarker = EnhancedCoTMarker(
                id: existingMarker.id,
                uid: event.uid,
                type: event.type,
                timestamp: event.time,
                coordinate: coordinate,
                altitude: event.point.hae,
                ce: event.point.ce,
                le: event.point.le,
                callsign: event.detail.callsign,
                team: event.detail.team,
                affiliation: affiliation,
                unitType: unitType,
                speed: event.detail.speed,
                course: event.detail.course,
                remarks: event.detail.remarks,
                battery: event.detail.battery,
                device: event.detail.device,
                platform: event.detail.platform,
                lastUpdate: Date(),
                positionHistory: updatedHistory
            )

            enhancedMarkers[event.uid] = updatedMarker
            onMarkerUpdated?(updatedMarker)

        } else {
            // Create new marker
            let initialPosition = CoTPosition(
                coordinate: coordinate,
                altitude: event.point.hae,
                timestamp: event.time,
                speed: event.detail.speed,
                course: event.detail.course
            )

            let newMarker = EnhancedCoTMarker(
                id: UUID(),
                uid: event.uid,
                type: event.type,
                timestamp: event.time,
                coordinate: coordinate,
                altitude: event.point.hae,
                ce: event.point.ce,
                le: event.point.le,
                callsign: event.detail.callsign,
                team: event.detail.team,
                affiliation: affiliation,
                unitType: unitType,
                speed: event.detail.speed,
                course: event.detail.course,
                remarks: event.detail.remarks,
                battery: event.detail.battery,
                device: event.detail.device,
                platform: event.detail.platform,
                lastUpdate: Date(),
                positionHistory: [initialPosition]
            )

            enhancedMarkers[event.uid] = newMarker
            onMarkerUpdated?(newMarker)
        }
    }

    private func shouldAddToHistory(newPosition: CoTPosition, existingHistory: [CoTPosition]) -> Bool {
        guard let lastPosition = existingHistory.last else { return true }

        // Calculate distance from last position
        let loc1 = CLLocation(
            latitude: lastPosition.coordinate.latitude,
            longitude: lastPosition.coordinate.longitude
        )
        let loc2 = CLLocation(
            latitude: newPosition.coordinate.latitude,
            longitude: newPosition.coordinate.longitude
        )

        let distance = loc1.distance(from: loc2)

        // Add if moved more than 5 meters or more than 30 seconds passed
        let timeDiff = newPosition.timestamp.timeIntervalSince(lastPosition.timestamp)
        return distance > 5.0 || timeDiff > 30
    }

    /// Remove stale markers (older than 15 minutes)
    func removeStaleMarkers() {
        let cutoffTime = Date().addingTimeInterval(-900)  // 15 minutes
        enhancedMarkers = enhancedMarkers.filter { _, marker in
            marker.lastUpdate > cutoffTime
        }
    }

    /// Get marker by UID
    func getMarker(uid: String) -> EnhancedCoTMarker? {
        return enhancedMarkers[uid]
    }

    /// Get all markers as array
    func getAllMarkers() -> [EnhancedCoTMarker] {
        return Array(enhancedMarkers.values)
    }
}

// Global callback function (must be at file scope, not inside class)
private func cotCallback(
    userData: UnsafeMutableRawPointer?,
    connectionId: UInt64,
    cotXml: UnsafePointer<CChar>?
) {
    guard let userData = userData,
          let cotXml = cotXml else {
        return
    }

    // Convert C string to Swift string
    let message = String(cString: cotXml)

    // Get the TAKService instance
    let service = Unmanaged<TAKService>.fromOpaque(userData).takeUnretainedValue()

    // Check if this is a GeoChat message (b-t-f type)
    if message.contains("type=\"b-t-f\"") {
        if let chatMessage = ChatXMLParser.parseGeoChatMessage(xml: message) {
            DispatchQueue.main.async {
                service.messagesReceived += 1
                service.lastMessage = message
                service.onChatMessageReceived?(chatMessage)
                print("💬 Received chat message from \(chatMessage.senderCallsign): \(chatMessage.messageText)")
            }
        }
    } else {
        // Parse regular CoT message
        if let event = parseCoT(xml: message) {
            DispatchQueue.main.async {
                service.messagesReceived += 1
                service.lastMessage = message
                service.cotEvents.append(event)
                service.onCoTReceived?(event)

                // Update enhanced marker
                service.updateEnhancedMarker(from: event)

                // Also parse participant info for chat
                if let participant = ChatXMLParser.parseParticipantFromPresence(xml: message) {
                    ChatManager.shared.updateParticipant(participant)
                }

                print("📥 Received CoT: \(event.detail.callsign) at (\(event.point.lat), \(event.point.lon))")
            }
        }
    }
}

// Enhanced CoT XML Parser
private func parseCoT(xml: String) -> CoTEvent? {
    // Extract UID
    guard let uidRange = xml.range(of: "uid=\"([^\"]+)\"", options: .regularExpression),
          let uid = xml[uidRange].split(separator: "\"").dropFirst().first else {
        return nil
    }

    // Extract type
    guard let typeRange = xml.range(of: "type=\"([^\"]+)\"", options: .regularExpression),
          let type = xml[typeRange].split(separator: "\"").dropFirst().first else {
        return nil
    }

    // Extract point data
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
    let ce = Double(extractAttribute("ce", from: pointTag) ?? "10") ?? 10
    let le = Double(extractAttribute("le", from: pointTag) ?? "10") ?? 10

    // Extract callsign
    var callsign = String(uid)
    if let callsignRange = xml.range(of: "callsign=\"([^\"]+)\"", options: .regularExpression),
       let extractedCallsign = xml[callsignRange].split(separator: "\"").dropFirst().first {
        callsign = String(extractedCallsign)
    }

    // Extract team
    var team: String? = nil
    if let teamRange = xml.range(of: "<__group[^>]*name=\"([^\"]+)\"", options: .regularExpression),
       let extractedTeam = xml[teamRange].split(separator: "\"").dropFirst().dropFirst().first {
        team = String(extractedTeam)
    }

    // Extract speed from track element
    var speed: Double? = nil
    if let trackRange = xml.range(of: "<track[^>]+>", options: .regularExpression) {
        let trackTag = String(xml[trackRange])
        if let speedStr = extractAttribute("speed", from: trackTag) {
            speed = Double(speedStr)
        }
    }

    // Extract course from track element
    var course: Double? = nil
    if let trackRange = xml.range(of: "<track[^>]+>", options: .regularExpression) {
        let trackTag = String(xml[trackRange])
        if let courseStr = extractAttribute("course", from: trackTag) {
            course = Double(courseStr)
        }
    }

    // Extract remarks
    var remarks: String? = nil
    if let remarksRange = xml.range(of: "<remarks>([^<]+)</remarks>", options: .regularExpression) {
        let remarksMatch = String(xml[remarksRange])
        if let start = remarksMatch.range(of: ">"),
           let end = remarksMatch.range(of: "</") {
            remarks = String(remarksMatch[start.upperBound..<end.lowerBound])
        }
    }

    // Extract battery from status element
    var battery: Int? = nil
    if let statusRange = xml.range(of: "<status[^>]+>", options: .regularExpression) {
        let statusTag = String(xml[statusRange])
        if let batteryStr = extractAttribute("battery", from: statusTag) {
            battery = Int(batteryStr)
        }
    }

    // Extract device from takv element
    var device: String? = nil
    if let takvRange = xml.range(of: "<takv[^>]+>", options: .regularExpression) {
        let takvTag = String(xml[takvRange])
        device = extractAttribute("device", from: takvTag)
    }

    // Extract platform from takv element
    var platform: String? = nil
    if let takvRange = xml.range(of: "<takv[^>]+>", options: .regularExpression) {
        let takvTag = String(xml[takvRange])
        platform = extractAttribute("platform", from: takvTag)
    }

    return CoTEvent(
        uid: String(uid),
        type: String(type),
        time: Date(),
        point: CoTPoint(lat: lat, lon: lon, hae: hae, ce: ce, le: le),
        detail: CoTDetail(
            callsign: callsign,
            team: team,
            speed: speed,
            course: course,
            remarks: remarks,
            battery: battery,
            device: device,
            platform: platform
        )
    )
}

private func extractAttribute(_ name: String, from xml: String) -> String? {
    guard let range = xml.range(of: "\(name)=\"([^\"]+)\"", options: .regularExpression) else {
        return nil
    }
    let parts = xml[range].split(separator: "\"")
    return parts.count > 1 ? String(parts[1]) : nil
}
