import Foundation
import Combine
import CoreLocation
import Network
import Security

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

    // Receive buffer for handling fragmented XML
    private var receiveBuffer: String = ""
    private let bufferLock = NSLock()

    // Callbacks
    var onMessageReceived: ((String) -> Void)?
    var onConnectionStateChanged: ((Bool) -> Void)?

    // Statistics
    private(set) var bytesReceived: Int = 0
    private(set) var messagesReceived: Int = 0

    var isConnected: Bool {
        return connection?.state == .ready
    }

    func connect(host: String, port: UInt16, protocolType: String = "tcp", useTLS: Bool = false, certificateName: String? = nil, certificatePassword: String? = nil, allowLegacyTLS: Bool = false, completion: @escaping (Bool) -> Void) {
        // Create endpoint with explicit IPv4 if possible
        let nwHost: NWEndpoint.Host
        if let ipv4 = IPv4Address(host) {
            nwHost = NWEndpoint.Host.ipv4(ipv4)
            #if DEBUG
            print("🌐 Using explicit IPv4: \(host)")
            #endif
        } else {
            nwHost = NWEndpoint.Host(host)
            #if DEBUG
            print("🌐 Using hostname: \(host)")
            #endif
        }

        let endpoint = NWEndpoint.hostPort(
            host: nwHost,
            port: NWEndpoint.Port(rawValue: port)!
        )

        // Determine protocol and parameters
        let parameters: NWParameters

        if useTLS || protocolType.lowercased() == "tls" {
            // TLS over TCP
            currentProtocol = .tls
            let tlsOptions = NWProtocolTLS.Options()

            // Configure TLS settings for TAK Server compatibility
            let secOptions = tlsOptions.securityProtocolOptions

            // Support TLS 1.2 and 1.3 (TAK servers may use either)
            // For extremely old servers, allow TLS 1.0/1.1 (security risk - opt-in only)
            if allowLegacyTLS {
                #if DEBUG
                print("⚠️  WARNING: Allowing legacy TLS 1.0+ (security risk)")
                #endif
                sec_protocol_options_set_min_tls_protocol_version(secOptions, .TLSv10)
            } else {
                // TLS 1.2 is minimum for secure legacy TAK server compatibility
                sec_protocol_options_set_min_tls_protocol_version(secOptions, .TLSv12)
            }

            // Set max to TLS 1.3 for modern servers
            sec_protocol_options_set_max_tls_protocol_version(secOptions, .TLSv13)

            // Add legacy cipher suites for older TAK servers
            // These are commonly needed for TAK servers running older OpenSSL versions
            sec_protocol_options_append_tls_ciphersuite(secOptions, tls_ciphersuite_t(rawValue: UInt16(TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384))!)
            sec_protocol_options_append_tls_ciphersuite(secOptions, tls_ciphersuite_t(rawValue: UInt16(TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256))!)
            sec_protocol_options_append_tls_ciphersuite(secOptions, tls_ciphersuite_t(rawValue: UInt16(TLS_RSA_WITH_AES_256_GCM_SHA384))!)
            sec_protocol_options_append_tls_ciphersuite(secOptions, tls_ciphersuite_t(rawValue: UInt16(TLS_RSA_WITH_AES_128_GCM_SHA256))!)

            // For very old TAK servers (use with caution)
            sec_protocol_options_append_tls_ciphersuite(secOptions, tls_ciphersuite_t(rawValue: UInt16(TLS_RSA_WITH_AES_256_CBC_SHA))!)
            sec_protocol_options_append_tls_ciphersuite(secOptions, tls_ciphersuite_t(rawValue: UInt16(TLS_RSA_WITH_AES_128_CBC_SHA))!)

            // Disable server certificate verification for self-signed certs
            // TAK servers typically use self-signed certificates
            sec_protocol_options_set_verify_block(secOptions, { (metadata, trust, complete) in
                // Accept all server certificates (similar to verify_server: false in Rust)
                #if DEBUG
                print("🔓 Accepting server certificate (self-signed CA)")
                #endif
                complete(true)
            }, .main)

            // Log TLS negotiation details for debugging
            #if DEBUG
            sec_protocol_options_set_tls_negotiation_monitor(secOptions, .main) { (metadata) in
                let version = sec_protocol_metadata_get_negotiated_tls_protocol_version(metadata)
                let ciphersuite = sec_protocol_metadata_get_negotiated_tls_ciphersuite(metadata)

                let versionString: String
                switch version {
                case .TLSv10: versionString = "TLS 1.0"
                case .TLSv11: versionString = "TLS 1.1"
                case .TLSv12: versionString = "TLS 1.2"
                case .TLSv13: versionString = "TLS 1.3"
                default: versionString = "Unknown"
                }

                print("🔐 TLS Negotiated: \(versionString), Cipher: 0x\(String(format: "%04X", ciphersuite.rawValue))")
            }
            #endif

            // Configure client certificate if provided
            if let certName = certificateName, !certName.isEmpty {
                #if DEBUG
                print("🔐 Configuring client certificate: \(certName)")
                #endif
                if let identity = loadClientCertificate(name: certName, password: certificatePassword ?? "atakatak") {
                    sec_protocol_options_set_local_identity(secOptions, identity)
                    #if DEBUG
                    print("✅ Client certificate loaded successfully")
                    #endif
                } else {
                    #if DEBUG
                    print("⚠️ Failed to load client certificate, continuing without it")
                    #endif
                }
            } else {
                #if DEBUG
                print("🔒 Using TLS without client certificate")
                #endif
            }

            let tcpOptions = NWProtocolTCP.Options()
            parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)

            // Force IPv4 for localhost/127.0.0.1 connections
            if host.contains("127.0.0.1") || host.contains("localhost") {
                parameters.requiredInterfaceType = .loopback
                parameters.preferNoProxies = true
            }

            #if DEBUG
            if allowLegacyTLS {
                print("🔒 Using TLS/SSL (TLS 1.0-1.3, legacy mode, legacy cipher suites, accepting self-signed certs)")
            } else {
                print("🔒 Using TLS/SSL (TLS 1.2-1.3, legacy cipher suites enabled, accepting self-signed certs)")
            }
            #endif
        } else if protocolType.lowercased() == "udp" {
            // UDP
            currentProtocol = .udp
            parameters = NWParameters.udp
            #if DEBUG
            print("📡 Using UDP")
            #endif
        } else {
            // TCP (default)
            currentProtocol = .tcp
            parameters = NWParameters.tcp

            // Force IPv4 for localhost/127.0.0.1 connections
            if host.contains("127.0.0.1") || host.contains("localhost") {
                parameters.requiredInterfaceType = .loopback
                parameters.preferNoProxies = true
            }

            #if DEBUG
            print("🔌 Using TCP")
            #endif
        }

        connection = NWConnection(to: endpoint, using: parameters)

        connection?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                #if DEBUG
                print("✅ Direct\(self.currentProtocol): Connected to \(host):\(port)")
                #endif
                self.onConnectionStateChanged?(true)
                // Start the receive loop
                self.startReceiveLoop()
                completion(true)
            case .failed(let error):
                print("❌ Direct\(self.currentProtocol): Connection failed: \(error)")
                self.onConnectionStateChanged?(false)
                completion(false)
            case .waiting(let error):
                #if DEBUG
                print("⏳ Direct\(self.currentProtocol): Waiting to connect: \(error)")
                #endif
            case .cancelled:
                #if DEBUG
                print("🔌 Direct\(self.currentProtocol): Connection cancelled")
                #endif
                self.onConnectionStateChanged?(false)
            default:
                break
            }
        }

        connection?.start(queue: queue)
    }

    // MARK: - Continuous Receive Loop

    private func startReceiveLoop() {
        guard let connection = connection else { return }

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ DirectNetwork: Receive error: \(error)")
                return
            }

            if let data = data, !data.isEmpty {
                self.bytesReceived += data.count
                self.processReceivedData(data)
            }

            if isComplete {
                #if DEBUG
                print("🔌 DirectNetwork: Connection closed by server")
                #endif
                self.onConnectionStateChanged?(false)
                return
            }

            // Continue receiving
            self.startReceiveLoop()
        }
    }

    private func processReceivedData(_ data: Data) {
        guard let receivedString = String(data: data, encoding: .utf8) else {
            #if DEBUG
            print("⚠️ DirectNetwork: Failed to decode received data as UTF-8")
            #endif
            return
        }

        #if DEBUG
        print("📥 DirectNetwork: Received \(data.count) bytes")
        #endif

        bufferLock.lock()
        receiveBuffer += receivedString
        bufferLock.unlock()

        // Extract complete XML messages from buffer
        extractAndProcessMessages()
    }

    private func extractAndProcessMessages() {
        bufferLock.lock()
        defer { bufferLock.unlock() }

        // Use CoTMessageParser to extract complete messages
        let (messages, remaining) = CoTMessageParser.extractCompleteMessages(from: receiveBuffer)

        // Update buffer with remaining incomplete data
        receiveBuffer = remaining

        // Process each complete message
        for message in messages {
            if CoTMessageParser.isValidCoTMessage(message) {
                messagesReceived += 1
                #if DEBUG
                print("📨 DirectNetwork: Complete message #\(messagesReceived) extracted (\(message.count) chars)")
                #endif

                // Call the message handler
                DispatchQueue.main.async { [weak self] in
                    self?.onMessageReceived?(message)
                }
            } else {
                #if DEBUG
                print("⚠️ DirectNetwork: Invalid CoT message discarded")
                #endif
            }
        }

        // Warn if buffer is getting too large (potential memory leak)
        if receiveBuffer.count > 100000 {
            #if DEBUG
            print("⚠️ DirectNetwork: Buffer size warning: \(receiveBuffer.count) chars")
            #endif
            // Clear buffer if it's absurdly large (malformed data protection)
            if receiveBuffer.count > 1000000 {
                print("❌ DirectNetwork: Buffer overflow protection - clearing buffer")
                receiveBuffer = ""
            }
        }
    }

    func clearReceiveBuffer() {
        bufferLock.lock()
        receiveBuffer = ""
        bufferLock.unlock()
    }

    func getReceiveBufferSize() -> Int {
        bufferLock.lock()
        let size = receiveBuffer.count
        bufferLock.unlock()
        return size
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
                #if DEBUG
                print("📤 DirectNetwork: Sent \(data.count) bytes")
                #endif
            }
        })

        return true
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        clearReceiveBuffer()
        #if DEBUG
        print("🔌 DirectNetwork: Disconnected")
        #endif
    }

    func resetStatistics() {
        bytesReceived = 0
        messagesReceived = 0
    }

    private func loadClientCertificate(name: String, password: String) -> sec_identity_t? {
        // Try loading from CertificateManager first (Keychain storage)
        if let cert = CertificateManager.shared.certificates.first(where: { $0.name == name }) {
            #if DEBUG
            print("🔐 Loading certificate from CertificateManager: \(name)")
            #endif

            do {
                let identity = try CertificateManager.shared.getIdentity(for: cert.id)
                return sec_identity_create(identity)
            } catch {
                print("⚠️ Failed to load from CertificateManager: \(error.localizedDescription)")
                // Fall through to try other sources
            }
        }

        // Try loading from Documents folder (enrolled certificates)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let certificatesPath = documentsPath.appendingPathComponent("Certificates")
        let docCertPath = certificatesPath.appendingPathComponent("\(name).p12")

        if FileManager.default.fileExists(atPath: docCertPath.path) {
            #if DEBUG
            print("📂 Found certificate in Documents: \(docCertPath.path)")
            #endif

            if let identity = loadP12Identity(from: docCertPath, password: password) {
                return identity
            }
        }

        // Fallback: Look for .p12 file in app bundle
        guard let certPath = Bundle.main.path(forResource: name, ofType: "p12") else {
            print("❌ Certificate file not found: \(name).p12")
            print("   Searched in: CertificateManager, Documents/Certificates, and app bundle")
            return nil
        }

        #if DEBUG
        print("📂 Found certificate in app bundle: \(certPath)")
        #endif

        let bundleCertURL = URL(fileURLWithPath: certPath)
        return loadP12Identity(from: bundleCertURL, password: password)
    }

    private func loadP12Identity(from url: URL, password: String) -> sec_identity_t? {
        // Load certificate data
        guard let certData = try? Data(contentsOf: url) as CFData else {
            print("❌ Failed to read certificate data from: \(url.path)")
            return nil
        }

        // Import options with password
        let options: [String: Any] = [
            kSecImportExportPassphrase as String: password
        ]

        // Import identity
        var items: CFArray?
        let status = SecPKCS12Import(certData, options as CFDictionary, &items)

        guard status == errSecSuccess else {
            print("❌ Failed to import certificate: \(status)")
            if status == errSecAuthFailed {
                print("   Incorrect password for certificate")
            }
            return nil
        }

        guard let itemsArray = items as? [[String: Any]],
              let firstItem = itemsArray.first,
              let identity = firstItem[kSecImportItemIdentity as String] else {
            print("❌ No identity found in certificate")
            return nil
        }

        // Convert SecIdentity to sec_identity_t
        return sec_identity_create(identity as! SecIdentity)
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
    @Published var bytesReceived: Int = 0

    private var connectionHandle: UInt64 = 0
    private var directTCP: DirectTCPSender?  // Direct TCP sender (bypasses incomplete Rust FFI)
    var onCoTReceived: ((CoTEvent) -> Void)?
    var onMarkerUpdated: ((EnhancedCoTMarker) -> Void)?
    var onChatMessageReceived: ((ChatMessage) -> Void)?

    // CoT Event Handler for routing
    private let eventHandler = CoTEventHandler.shared

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

        // Configure the event handler
        eventHandler.configure(takService: self, chatManager: ChatManager.shared)

        // Setup receive handler
        setupReceiveHandler()
    }

    private func setupReceiveHandler() {
        directTCP?.onMessageReceived = { [weak self] xml in
            self?.handleReceivedMessage(xml)
        }

        directTCP?.onConnectionStateChanged = { [weak self] connected in
            DispatchQueue.main.async {
                if !connected && self?.isConnected == true {
                    self?.isConnected = false
                    self?.connectionStatus = "Disconnected"
                    #if DEBUG
                    print("🔌 TAKService: Connection lost")
                    #endif
                }
            }
        }
    }

    private func handleReceivedMessage(_ xml: String) {
        messagesReceived += 1
        lastMessage = xml

        // Update bytes received
        if let tcp = directTCP {
            bytesReceived = tcp.bytesReceived
        }

        #if DEBUG
        print("📥 TAKService: Processing message #\(messagesReceived)")
        #endif

        // Parse the message using CoTMessageParser
        if let eventType = CoTMessageParser.parse(xml: xml) {
            // Route to event handler
            eventHandler.handle(event: eventType)
        } else {
            #if DEBUG
            print("⚠️ TAKService: Failed to parse CoT message")
            #endif
        }
    }

    deinit {
        disconnect()
        omnitak_shutdown()
    }

    func connect(host: String, port: UInt16, protocolType: String, useTLS: Bool, certificateName: String? = nil, certificatePassword: String? = nil) {
        #if DEBUG
        print("🔌 TAKService.connect() called with host=\(host), port=\(port), protocol=\(protocolType), tls=\(useTLS), cert=\(certificateName ?? "none")")
        #endif

        // Use DirectTCPSender for actual network communication
        connectionStatus = "Connecting..."
        directTCP?.connect(host: host, port: port, protocolType: protocolType, useTLS: useTLS, certificateName: certificateName, certificatePassword: certificatePassword) { [weak self] success in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if success {
                    self.isConnected = true
                    self.connectionStatus = "Connected"
                    self.lastError = ""
                    #if DEBUG
                    print("✅ DirectTCP Connected to TAK server: \(host):\(port)")
                    #endif

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
                        #if DEBUG
                        print("📡 Rust FFI also initialized (connection ID: \(result))")
                        #endif
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
        #if DEBUG
        print("🔌 Disconnected from TAK server")
        #endif
    }

    func sendCoT(xml: String) -> Bool {
        guard isConnected, let directTCP = directTCP else {
            print("❌ Not connected")
            return false
        }

        // Use DirectTCPSender for actual sending
        if directTCP.send(xml: xml) {
            messagesSent += 1
            #if DEBUG
            print("📤 Sent CoT message via DirectTCP")
            #endif

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

    // MARK: - Waypoint CoT Messages

    /// Send a waypoint as a CoT message
    func sendWaypoint(_ waypoint: Waypoint, staleTime: TimeInterval = 3600) -> Bool {
        let xml = WaypointManager.shared.exportToCoT(waypoint, staleTime: staleTime)
        return sendCoT(xml: xml)
    }

    /// Broadcast a waypoint to the TAK network
    func broadcastWaypoint(
        name: String,
        coordinate: CLLocationCoordinate2D,
        altitude: Double = 0,
        icon: WaypointIcon = .waypoint,
        color: WaypointColor = .blue,
        remarks: String? = nil
    ) -> Bool {
        let waypoint = Waypoint(
            name: name,
            remarks: remarks,
            coordinate: coordinate,
            altitude: altitude,
            icon: icon,
            color: color
        )

        return sendWaypoint(waypoint)
    }

    /// Send a route (series of waypoints) as CoT messages
    func sendRoute(_ route: WaypointRoute) -> Bool {
        let waypoints = WaypointManager.shared.getWaypointsForRoute(route)
        var success = true

        for waypoint in waypoints {
            if !sendWaypoint(waypoint) {
                success = false
            }
        }

        return success
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
        if let existingMarker = enhancedMarkers[event.uid] {
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

    // MARK: - Receive Statistics

    /// Get current receive buffer size
    func getReceiveBufferSize() -> Int {
        return directTCP?.getReceiveBufferSize() ?? 0
    }

    /// Clear the receive buffer
    func clearReceiveBuffer() {
        directTCP?.clearReceiveBuffer()
    }

    /// Get event handler statistics
    func getEventStatistics() -> CoTEventStatistics {
        return eventHandler.getStatistics()
    }

    /// Get active emergency alerts
    func getActiveEmergencies() -> [EmergencyAlert] {
        return eventHandler.activeEmergencies
    }

    /// Reset all statistics
    func resetStatistics() {
        messagesReceived = 0
        messagesSent = 0
        bytesReceived = 0
        directTCP?.resetStatistics()
        eventHandler.resetStatistics()
    }

    /// Configure notification settings
    func setNotificationsEnabled(_ enabled: Bool) {
        eventHandler.enableNotifications = enabled
    }

    /// Configure emergency alerts
    func setEmergencyAlertsEnabled(_ enabled: Bool) {
        eventHandler.enableEmergencyAlerts = enabled
    }
}

// MARK: - Location Manager Stub removed - use LocationManager from MapViewController.swift

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
                #if DEBUG
                print("💬 Received chat message from \(chatMessage.senderCallsign): \(chatMessage.messageText)")
                #endif
            }
        }
    } else if message.contains("type=\"b-m-p-w\"") || message.contains("<usericon") {
        // Check if this is a waypoint marker (b-m-p-w) or has waypoint metadata
        if let event = parseCoT(xml: message) {
            DispatchQueue.main.async {
                service.messagesReceived += 1
                service.lastMessage = message

                // Import waypoint into WaypointManager
                _ = WaypointManager.shared.importFromCoT(
                    uid: event.uid,
                    type: event.type,
                    coordinate: CLLocationCoordinate2D(latitude: event.point.lat, longitude: event.point.lon),
                    callsign: event.detail.callsign,
                    altitude: event.point.hae,
                    remarks: event.detail.remarks
                )

                #if DEBUG
                print("📍 Received waypoint: \(event.detail.callsign)")
                #endif
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

                #if DEBUG
                print("📥 Received CoT: \(event.detail.callsign) at (\(event.point.lat), \(event.point.lon))")
                #endif
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
