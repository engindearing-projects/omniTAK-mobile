import Foundation
import Combine
import CoreLocation
import Network
import Security
#if os(iOS)
import UIKit
#endif

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

    func connect(host: String, port: UInt16, protocolType: String = "tcp", useTLS: Bool = false, certificateName: String? = nil, certificatePassword: String? = nil, caCertificateName: String? = nil, caCertificatePassword: String? = nil, allowLegacyTLS: Bool = false, completion: @escaping (Bool) -> Void) {
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
                sec_protocol_options_set_min_tls_protocol_version(secOptions, tls_protocol_version_t(rawValue: 769)!) // TLS 1.0
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

            // Configure server certificate verification for self-signed/custom CA certs
            // TAK servers typically use self-signed certificates or custom CA

            // Load CA certificate if provided for proper server verification
            var caCertificates: [SecCertificate] = []
            if let caName = caCertificateName, !caName.isEmpty {
                #if DEBUG
                print("🔐 Loading CA certificate: \(caName)")
                #endif
                if let caCerts = loadCACertificates(name: caName) {
                    caCertificates = caCerts
                    #if DEBUG
                    print("✅ Loaded \(caCerts.count) CA certificate(s)")
                    #endif
                }
            }

            if !caCertificates.isEmpty {
                // Use proper CA verification with the provided CA certificate
                #if DEBUG
                print("🔒 Using CA certificate for server verification")
                #endif

                sec_protocol_options_set_verify_block(secOptions, { (metadata, trust, complete) in
                    #if DEBUG
                    print("🔐 TLS verify block called - verifying with CA certificate")
                    #endif

                    // Get the trust object from the metadata
                    let secTrust = sec_trust_copy_ref(trust).takeRetainedValue()

                    // Set our CA certificates as trusted anchors
                    SecTrustSetAnchorCertificates(secTrust, caCertificates as CFArray)
                    SecTrustSetAnchorCertificatesOnly(secTrust, true)

                    // Evaluate the trust
                    var error: CFError?
                    let trusted = SecTrustEvaluateWithError(secTrust, &error)

                    #if DEBUG
                    if trusted {
                        print("✅ Server certificate verified successfully with CA")
                    } else {
                        print("⚠️ Server certificate verification failed: \(error?.localizedDescription ?? "unknown error")")
                        print("   Accepting anyway for TAK compatibility")
                    }
                    #endif

                    // Accept even if verification fails for TAK server compatibility
                    // (some servers have expired certs or hostname mismatches)
                    complete(true)
                }, .global())
            } else {
                // No CA certificate - disable peer authentication and accept all certs
                // IMPORTANT: This allows connection to TAK servers with custom/self-signed certificates
                sec_protocol_options_set_peer_authentication_required(secOptions, false)

                #if DEBUG
                print("🔓 No CA certificate - accepting all server certificates")
                #endif

                // Set verify block that always accepts the server certificate
                sec_protocol_options_set_verify_block(secOptions, { (metadata, trust, complete) in
                    #if DEBUG
                    print("🔓 TLS verify block called - accepting server certificate (no CA)")
                    #endif
                    // Always accept the server certificate for TAK server compatibility
                    complete(true)
                }, .global())
            }

            // Note: TLS negotiation monitoring is macOS-only
            // On iOS, check connection logs for TLS details

            // Configure client certificate if provided
            var clientIdentity: sec_identity_t? = nil

            if let certName = certificateName, !certName.isEmpty {
                #if DEBUG
                print("🔐 Configuring client certificate: \(certName)")
                #endif
                clientIdentity = loadClientCertificate(name: certName, password: certificatePassword ?? "atakatak")
            }

            // Fallback: Try loading bundled-client.p12 directly from bundle
            if clientIdentity == nil {
                #if DEBUG
                print("🔐 Trying direct bundled certificate load...")
                #endif
                if let bundledURL = Bundle.main.url(forResource: "bundled-client", withExtension: "p12") {
                    #if DEBUG
                    print("📂 Found bundled-client.p12 at: \(bundledURL.path)")
                    #endif
                    if let data = try? Data(contentsOf: bundledURL) {
                        let options: [String: Any] = [kSecImportExportPassphrase as String: "atakatak"]
                        var items: CFArray?
                        let status = SecPKCS12Import(data as CFData, options as CFDictionary, &items)
                        if status == errSecSuccess,
                           let itemsArray = items as? [[String: Any]],
                           let firstItem = itemsArray.first,
                           let secIdentity = firstItem[kSecImportItemIdentity as String] {
                            clientIdentity = sec_identity_create(secIdentity as! SecIdentity)
                            #if DEBUG
                            print("✅ Directly loaded bundled client certificate")
                            #endif
                        } else {
                            print("❌ Failed to import bundled P12: status=\(status)")
                        }
                    }
                } else {
                    print("❌ bundled-client.p12 not found in app bundle")
                }
            }

            if let identity = clientIdentity {
                // Set the local identity for the TLS connection
                sec_protocol_options_set_local_identity(secOptions, identity)

                // CRITICAL: Set challenge block to respond when server requests client certificate
                // This is required for mTLS - the server asks for our certificate during handshake
                sec_protocol_options_set_challenge_block(secOptions, { (metadata, completionHandler) in
                    #if DEBUG
                    print("🔐 TLS challenge received - providing client certificate")
                    #endif
                    completionHandler(identity)
                }, .main)

                #if DEBUG
                print("✅ Client certificate configured with challenge block")
                #endif
            } else {
                #if DEBUG
                print("⚠️ No client certificate available - mTLS will fail")
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

        #if DEBUG
        if !messages.isEmpty {
            print("📨 DirectNetwork: Extracted \(messages.count) complete message(s) from buffer")
        }
        #endif

        // Update buffer with remaining incomplete data
        receiveBuffer = remaining

        // Process each complete message
        for message in messages {
            if CoTMessageParser.isValidCoTMessage(message) {
                messagesReceived += 1
                #if DEBUG
                print("📨 DirectNetwork: Complete message #\(messagesReceived) extracted (\(message.count) chars)")
                // Show message preview to help debug
                let preview = message.prefix(200)
                print("   📄 Preview: \(preview)...")
                #endif

                // Call the message handler
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else {
                        #if DEBUG
                        print("❌ DirectNetwork: self is nil, cannot call onMessageReceived!")
                        #endif
                        return
                    }
                    if self.onMessageReceived == nil {
                        #if DEBUG
                        print("❌ DirectNetwork: onMessageReceived callback is nil! Messages won't be processed!")
                        #endif
                    } else {
                        #if DEBUG
                        print("✅ DirectNetwork: Calling onMessageReceived callback")
                        #endif
                        self.onMessageReceived?(message)
                    }
                }
            } else {
                #if DEBUG
                print("⚠️ DirectNetwork: Invalid CoT message discarded")
                print("   📄 Invalid message preview: \(message.prefix(200))...")
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
        // Enhanced diagnostic logging for connection state issues
        guard let connection = connection else {
            print("❌ DirectNetwork: Connection is nil")
            return false
        }

        guard connection.state == .ready else {
            print("❌ DirectNetwork: Connection not ready - state: \(connection.state)")
            // Log what state the connection is actually in
            switch connection.state {
            case .setup:
                print("  → Connection is in setup state")
            case .waiting(let error):
                print("  → Connection is waiting: \(error)")
            case .preparing:
                print("  → Connection is preparing")
            case .ready:
                print("  → Connection is ready (should not see this)")
            case .failed(let error):
                print("  → Connection failed: \(error)")
            case .cancelled:
                print("  → Connection was cancelled")
            @unknown default:
                print("  → Unknown connection state")
            }
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

        // Try loading CSR-enrolled certificate (stored by CSREnrollmentService)
        if let identity = loadCSREnrolledIdentity(name: name) {
            #if DEBUG
            print("🔐 Loaded CSR-enrolled certificate: \(name)")
            #endif
            return identity
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
            print("   Searched in: CertificateManager, CSR-enrolled, Documents/Certificates, and app bundle")
            return nil
        }

        #if DEBUG
        print("📂 Found certificate in app bundle: \(certPath)")
        #endif

        let bundleCertURL = URL(fileURLWithPath: certPath)
        return loadP12Identity(from: bundleCertURL, password: password)
    }

    /// Load identity from CSR-enrolled certificate (TAKaware approach - query by label)
    private func loadCSREnrolledIdentity(name: String) -> sec_identity_t? {
        #if DEBUG
        print("🔐 Looking for CSR-enrolled identity with label: \(name)")
        #endif

        // First check if we have a certificate with this label (confirms CSR enrollment was done)
        let certQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: name,
            kSecReturnRef as String: true,
            kSecReturnAttributes as String: true
        ]

        var certItem: CFTypeRef?
        let certStatus = SecItemCopyMatching(certQuery as CFDictionary, &certItem)

        guard certStatus == errSecSuccess else {
            #if DEBUG
            print("🔍 No CSR-enrolled certificate found for: \(name) (status: \(certStatus))")
            #endif
            return nil
        }

        #if DEBUG
        print("📜 Found certificate with label: \(name)")
        if let certDict = certItem as? [String: Any] {
            print("📜 Certificate attributes: \(certDict.keys.joined(separator: ", "))")
        }
        #endif

        // Method 1: Try to find identity directly by label (fastest)
        let identityByLabelQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: name,
            kSecReturnRef as String: true
        ]

        var identityRef: CFTypeRef?
        let identityByLabelStatus = SecItemCopyMatching(identityByLabelQuery as CFDictionary, &identityRef)

        if identityByLabelStatus == errSecSuccess, identityRef != nil {
            let identity = identityRef as! SecIdentity
            #if DEBUG
            print("✅ Found SecIdentity by label: \(name)")

            // Validate the identity
            var cert: SecCertificate?
            var key: SecKey?
            if SecIdentityCopyCertificate(identity, &cert) == errSecSuccess &&
               SecIdentityCopyPrivateKey(identity, &key) == errSecSuccess {
                print("✅ Identity validated: both certificate and private key accessible")
                return sec_identity_create(identity)
            } else {
                print("⚠️ Identity incomplete, will try alternative methods")
            }
            #endif
        }

        #if DEBUG
        print("⚠️ Identity not found by label (status: \(identityByLabelStatus))")
        #endif

        // Method 2: Query by issuer + serial number (if available in cert attributes)
        if let certDict = certItem as? [String: Any],
           let issuer = certDict[kSecAttrIssuer as String] as? Data,
           let serialNumber = certDict[kSecAttrSerialNumber as String] as? Data {

            #if DEBUG
            print("🔍 Trying identity lookup by issuer + serial...")
            #endif

            let identityByIssuerSerialQuery: [String: Any] = [
                kSecClass as String: kSecClassIdentity,
                kSecAttrIssuer as String: issuer,
                kSecAttrSerialNumber as String: serialNumber,
                kSecReturnRef as String: true
            ]

            var identityByIssuerSerial: CFTypeRef?
            let issuerSerialStatus = SecItemCopyMatching(identityByIssuerSerialQuery as CFDictionary, &identityByIssuerSerial)

            if issuerSerialStatus == errSecSuccess, identityByIssuerSerial != nil {
                let identity = identityByIssuerSerial as! SecIdentity
                #if DEBUG
                print("✅ Found SecIdentity by issuer + serial")
                #endif
                return sec_identity_create(identity)
            }

            #if DEBUG
            print("⚠️ Identity not found by issuer + serial (status: \(issuerSerialStatus))")
            #endif
        }

        // Method 3: Fallback - Query all identities and find the one matching our certificate
        #if DEBUG
        print("🔍 Trying certificate data matching (slowest method)...")
        #endif

        let allIdentitiesQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var identityItems: CFTypeRef?
        let allIdentitiesStatus = SecItemCopyMatching(allIdentitiesQuery as CFDictionary, &identityItems)

        if allIdentitiesStatus == errSecSuccess, let identities = identityItems as? [SecIdentity] {
            // Extract target certificate for comparison
            let targetCert: SecCertificate
            // certItem can be SecCertificate directly or a dictionary with kSecValueRef
            if CFGetTypeID(certItem as CFTypeRef) == SecCertificateGetTypeID() {
                targetCert = certItem as! SecCertificate
            } else if let certDict = certItem as? [String: Any],
                      let certRef = certDict[kSecValueRef as String] {
                targetCert = certRef as! SecCertificate
            } else {
                #if DEBUG
                print("❌ Could not extract certificate for comparison")
                #endif
                return nil
            }

            let targetCertData = SecCertificateCopyData(targetCert)

            for identity in identities {
                var identityCert: SecCertificate?
                if SecIdentityCopyCertificate(identity, &identityCert) == errSecSuccess,
                   let cert = identityCert {
                    let identityCertData = SecCertificateCopyData(cert)
                    if targetCertData == identityCertData {
                        #if DEBUG
                        print("✅ Found matching SecIdentity by certificate data comparison")
                        #endif
                        return sec_identity_create(identity)
                    }
                }
            }

            #if DEBUG
            print("⚠️ No matching identity found among \(identities.count) identities")
            #endif
        } else {
            #if DEBUG
            print("⚠️ Failed to query all identities (status: \(allIdentitiesStatus))")
            #endif
        }

        print("❌ Could not find identity for CSR-enrolled certificate: \(name)")
        print("❌ This means the certificate and private key are not properly linked")
        print("❌ Possible causes:")
        print("   1. Private key was not stored with same label as certificate")
        print("   2. Certificate public key doesn't match private key")
        print("   3. iOS keychain did not auto-create the identity")
        return nil
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

    /// Load CA certificates from keychain by label
    private func loadCACertificates(name: String) -> [SecCertificate]? {
        #if DEBUG
        print("🔐 Looking for CA certificate with label: \(name)")
        #endif

        // Query for certificates with this label
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: name,
            kSecReturnRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecSuccess, let resultRef = result {
            // Check if result is an array of certificates
            if CFGetTypeID(resultRef) == CFArrayGetTypeID() {
                if let certificates = resultRef as? [SecCertificate] {
                    #if DEBUG
                    print("✅ Found \(certificates.count) CA certificate(s) with label: \(name)")
                    #endif
                    return certificates
                }
            }
            // Check if result is a single certificate
            else if CFGetTypeID(resultRef) == SecCertificateGetTypeID() {
                let certificate = resultRef as! SecCertificate
                #if DEBUG
                print("✅ Found 1 CA certificate with label: \(name)")
                #endif
                return [certificate]
            }
        }

        // Try without the exact label match (maybe stored with suffix)
        let prefixQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecReturnRef as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var allCerts: CFTypeRef?
        let allStatus = SecItemCopyMatching(prefixQuery as CFDictionary, &allCerts)

        if allStatus == errSecSuccess, let certDicts = allCerts as? [[String: Any]] {
            var matchingCerts: [SecCertificate] = []
            for certDict in certDicts {
                if let label = certDict[kSecAttrLabel as String] as? String,
                   label.hasPrefix(name),
                   let certRef = certDict[kSecValueRef as String] {
                    // Verify it's actually a SecCertificate
                    if CFGetTypeID(certRef as CFTypeRef) == SecCertificateGetTypeID() {
                        let cert = certRef as! SecCertificate
                        matchingCerts.append(cert)
                        #if DEBUG
                        print("✅ Found CA certificate with prefix label: \(label)")
                        #endif
                    }
                }
            }
            if !matchingCerts.isEmpty {
                return matchingCerts
            }
        }

        #if DEBUG
        print("⚠️ No CA certificate found with label: \(name) (status: \(status))")
        #endif

        return nil
    }
}

// MARK: - Connection State Snapshot

struct ReconnectionState {
    var isReconnecting: Bool = false
    var attemptNumber: Int = 0
    var maxAttempts: Int = 5
}

struct ConnectionStateSnapshot {
    var isConnected: Bool
    var status: String
    var reconnectionState: ReconnectionState
    var serverName: String?
    var protocolType: String?
    var lastConnectedTime: Date?

    static var disconnected: ConnectionStateSnapshot {
        ConnectionStateSnapshot(
            isConnected: false,
            status: "Not Connected",
            reconnectionState: ReconnectionState(),
            serverName: nil,
            protocolType: nil,
            lastConnectedTime: nil
        )
    }

    static func connected(serverName: String, protocolType: String) -> ConnectionStateSnapshot {
        ConnectionStateSnapshot(
            isConnected: true,
            status: "Connected",
            reconnectionState: ReconnectionState(),
            serverName: serverName,
            protocolType: protocolType,
            lastConnectedTime: Date()
        )
    }

    static func connecting(serverName: String) -> ConnectionStateSnapshot {
        ConnectionStateSnapshot(
            isConnected: false,
            status: "Connecting...",
            reconnectionState: ReconnectionState(),
            serverName: serverName,
            protocolType: nil,
            lastConnectedTime: nil
        )
    }

    static func reconnecting(attempt: Int, maxAttempts: Int) -> ConnectionStateSnapshot {
        ConnectionStateSnapshot(
            isConnected: false,
            status: "Reconnecting...",
            reconnectionState: ReconnectionState(isReconnecting: true, attemptNumber: attempt, maxAttempts: maxAttempts),
            serverName: nil,
            protocolType: nil,
            lastConnectedTime: nil
        )
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

// MARK: - Server Connection State

struct ServerConnectionState {
    let serverId: UUID
    let serverName: String
    var isConnected: Bool
    var sender: DirectTCPSender
}

class TAKService: ObservableObject {
    // Shared singleton for global access
    static let shared = TAKService()

    @Published var connectionStatus = "Disconnected"
    @Published var isConnected = false  // True if ANY server is connected
    @Published var connectionState: ConnectionStateSnapshot = .disconnected
    @Published var lastError = ""
    @Published var messagesReceived: Int = 0
    @Published var messagesSent: Int = 0
    @Published var lastMessage = ""
    @Published var cotEvents: [CoTEvent] = []
    @Published var enhancedMarkers: [String: EnhancedCoTMarker] = [:]  // UID -> Marker map
    @Published var bytesReceived: Int = 0

    // Multi-server connection tracking
    @Published var connectedServerIds: Set<UUID> = []
    private var serverConnections: [UUID: ServerConnectionState] = [:]
    private let connectionsLock = NSLock()

    // Legacy single-server tracking (for backward compatibility)
    private var currentServerName: String = ""
    private var currentProtocolType: String = ""

    private var connectionHandle: UInt64 = 0
    private var directTCP: DirectTCPSender?  // Legacy single connection (will be deprecated)
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

        // Initialize legacy direct TCP sender
        directTCP = DirectTCPSender()

        // Configure the event handler
        eventHandler.configure(takService: self, chatManager: ChatManager.shared)

        // Setup receive handler for legacy connection
        setupReceiveHandler()

        // Setup app lifecycle observers for background handling
        setupLifecycleObservers()
    }

    // MARK: - App Lifecycle Handling (Background Support)

    private func setupLifecycleObservers() {
        #if os(iOS)
        // When app enters background - keep connection alive if possible
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[TAKService] App entered background - maintaining connection")
            self?.handleEnterBackground()
        }

        // When app returns to foreground - verify and reconnect if needed
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[TAKService] App entering foreground - verifying connection")
            self?.handleEnterForeground()
        }

        // When app becomes active
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[TAKService] App became active - checking connection state")
            self?.verifyAndReconnectIfNeeded()
        }
        #endif
    }

    private func handleEnterBackground() {
        // Store current connection state for potential reconnection
        // Keep connections alive - iOS will manage them based on background modes
        print("[TAKService] Background: Connection state = \(isConnected ? "connected" : "disconnected")")
    }

    private func handleEnterForeground() {
        // Schedule verification after brief delay to allow system to stabilize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.verifyAndReconnectIfNeeded()
        }
    }

    /// Verify connection state and reconnect if disconnected
    private func verifyAndReconnectIfNeeded() {
        // Check if we should be connected but aren't
        let activeServer = ServerManager.shared.activeServer

        if activeServer != nil && !isConnected {
            print("[TAKService] Was disconnected during background - attempting reconnect")
            // Reconnect to the active server
            if let server = activeServer {
                connectToServer(server)
            }
        } else if isConnected {
            print("[TAKService] Connection maintained during background")
        }
    }

    private func setupReceiveHandler() {
        directTCP?.onMessageReceived = { [weak self] xml in
            self?.handleReceivedMessage(xml)
        }

        directTCP?.onConnectionStateChanged = { [weak self] connected in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.updateOverallConnectionState()
            }
        }
    }

    // MARK: - Multi-Server Connection Methods

    /// Check if connected to a specific server
    func isConnectedTo(serverId: UUID) -> Bool {
        connectionsLock.lock()
        defer { connectionsLock.unlock() }
        return serverConnections[serverId]?.isConnected ?? false
    }

    /// Connect to a specific server
    func connectToServer(_ server: TAKServer) {
        #if DEBUG
        print("🔌 TAKService.connectToServer() - \(server.name) (\(server.host):\(server.port))")
        #endif

        connectionsLock.lock()

        // Check if already connected
        if let existing = serverConnections[server.id], existing.isConnected {
            connectionsLock.unlock()
            #if DEBUG
            print("ℹ️ Already connected to \(server.name)")
            #endif
            return
        }

        // Create new sender for this server
        let sender = DirectTCPSender()
        var connectionState = ServerConnectionState(
            serverId: server.id,
            serverName: server.name,
            isConnected: false,
            sender: sender
        )
        serverConnections[server.id] = connectionState
        connectionsLock.unlock()

        // Setup handlers for this server's connection
        sender.onMessageReceived = { [weak self] xml in
            self?.handleReceivedMessage(xml)
        }

        sender.onConnectionStateChanged = { [weak self] connected in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.connectionsLock.lock()
                if var state = self.serverConnections[server.id] {
                    state.isConnected = connected
                    self.serverConnections[server.id] = state
                }
                self.connectionsLock.unlock()
                self.updateOverallConnectionState()

                if connected {
                    #if DEBUG
                    print("✅ Connected to \(server.name)")
                    #endif
                } else {
                    #if DEBUG
                    print("🔌 Disconnected from \(server.name)")
                    #endif
                }
            }
        }

        // Connect
        sender.connect(
            host: server.host,
            port: server.port,
            protocolType: server.protocolType,
            useTLS: server.useTLS,
            certificateName: server.certificateName,
            certificatePassword: server.certificatePassword,
            caCertificateName: server.caCertificateName,
            caCertificatePassword: server.caCertificatePassword,
            allowLegacyTLS: server.allowLegacyTLS
        ) { [weak self] success in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.connectionsLock.lock()
                if var state = self.serverConnections[server.id] {
                    state.isConnected = success
                    self.serverConnections[server.id] = state
                }
                self.connectionsLock.unlock()
                self.updateOverallConnectionState()

                if success {
                    // Configure ChatManager and PositionBroadcastService if this is the first connection
                    if self.connectedServerIds.count == 1 {
                        ChatManager.shared.setTAKService(self)
                        PositionBroadcastService.shared.configure(takService: self, locationManager: LocationManager.shared)
                    }
                    #if DEBUG
                    print("✅ Successfully connected to \(server.name)")
                    #endif
                } else {
                    self.lastError = "Failed to connect to \(server.name)"
                    #if DEBUG
                    print("❌ Failed to connect to \(server.name)")
                    #endif
                }
            }
        }
    }

    /// Disconnect from a specific server
    func disconnectFromServer(serverId: UUID) {
        connectionsLock.lock()
        guard let state = serverConnections[serverId] else {
            connectionsLock.unlock()
            return
        }

        #if DEBUG
        print("🔌 Disconnecting from \(state.serverName)")
        #endif

        state.sender.disconnect()
        serverConnections.removeValue(forKey: serverId)
        connectionsLock.unlock()

        updateOverallConnectionState()
    }

    /// Update the overall connection state based on all server connections
    private func updateOverallConnectionState() {
        connectionsLock.lock()
        // Use actual sender.isConnected state, not cached state
        // This ensures we always have accurate connection status
        var connectedIds = Set<UUID>()
        var serverNames: [String] = []

        for (serverId, state) in serverConnections {
            // Check actual NWConnection state
            let actuallyConnected = state.sender.isConnected

            // Sync cached state if needed
            if state.isConnected != actuallyConnected {
                var updatedState = state
                updatedState.isConnected = actuallyConnected
                serverConnections[serverId] = updatedState
                #if DEBUG
                print("🔄 Synced connection state for '\(state.serverName)': \(state.isConnected) → \(actuallyConnected)")
                #endif
            }

            if actuallyConnected {
                connectedIds.insert(serverId)
                serverNames.append(state.serverName)
            }
        }

        let anyConnected = !connectedIds.isEmpty
        connectionsLock.unlock()

        DispatchQueue.main.async {
            self.connectedServerIds = connectedIds
            self.isConnected = anyConnected

            if anyConnected {
                let count = connectedIds.count
                if count == 1 {
                    self.connectionStatus = "Connected to \(serverNames.first ?? "server")"
                } else {
                    self.connectionStatus = "Connected to \(count) servers"
                }
                self.connectionState = .connected(serverName: serverNames.joined(separator: ", "), protocolType: "Multi")
            } else {
                self.connectionStatus = "Disconnected"
                self.connectionState = .disconnected
            }

            // Update aggregated bytes received
            self.updateAggregatedStats()
        }
    }

    /// Update aggregated statistics from all connections
    private func updateAggregatedStats() {
        connectionsLock.lock()
        var totalBytes = 0
        for state in serverConnections.values {
            totalBytes += state.sender.bytesReceived
        }
        // Include legacy connection if active
        if let legacyBytes = directTCP?.bytesReceived {
            totalBytes += legacyBytes
        }
        connectionsLock.unlock()

        bytesReceived = totalBytes
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
            #if DEBUG
            // Log successful parse with event details
            switch eventType {
            case .positionUpdate(let event):
                print("✅ TAKService: Parsed POSITION UPDATE - UID: \(event.uid), Callsign: \(event.detail.callsign), Type: \(event.type)")
                print("   📍 Location: (\(event.point.lat), \(event.point.lon))")
                print("   📊 cotEvents count BEFORE: \(cotEvents.count)")
            case .chatMessage(let msg):
                print("✅ TAKService: Parsed CHAT MESSAGE from \(msg.senderCallsign)")
            case .emergencyAlert(let alert):
                print("✅ TAKService: Parsed EMERGENCY ALERT from \(alert.callsign)")
            case .waypoint(let event):
                print("✅ TAKService: Parsed WAYPOINT - \(event.detail.callsign)")
            case .unknown(let typeStr):
                print("⚠️ TAKService: Parsed UNKNOWN event type: \(typeStr)")
            }
            #endif

            // Route to event handler
            eventHandler.handle(event: eventType)

            #if DEBUG
            // Verify cotEvents was updated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                if let self = self {
                    print("   📊 cotEvents count AFTER: \(self.cotEvents.count)")
                }
            }
            #endif
        } else {
            #if DEBUG
            print("❌ TAKService: FAILED to parse CoT message!")
            print("   📄 XML Preview (first 500 chars):")
            print("   \(String(xml.prefix(500)))")
            // Check for common parsing issues
            if !xml.contains("<event") {
                print("   ⚠️ Missing <event> tag")
            }
            if !xml.contains("</event>") {
                print("   ⚠️ Missing </event> tag")
            }
            if !xml.contains("uid=\"") {
                print("   ⚠️ Missing uid attribute")
            }
            if !xml.contains("type=\"") {
                print("   ⚠️ Missing type attribute")
            }
            if !xml.contains("<point") {
                print("   ⚠️ Missing <point> element")
            }
            #endif
        }
    }

    deinit {
        disconnect()
        omnitak_shutdown()
    }

    func connect(host: String, port: UInt16, protocolType: String, useTLS: Bool, certificateName: String? = nil, certificatePassword: String? = nil, caCertificateName: String? = nil, caCertificatePassword: String? = nil) {
        #if DEBUG
        print("🔌 TAKService.connect() called with host=\(host), port=\(port), protocol=\(protocolType), tls=\(useTLS), cert=\(certificateName ?? "none"), ca=\(caCertificateName ?? "none")")
        #endif

        // Track current connection details
        currentServerName = "\(host):\(port)"
        currentProtocolType = useTLS ? "TLS" : protocolType.uppercased()

        // Use DirectTCPSender for actual network communication
        connectionStatus = "Connecting..."
        connectionState = .connecting(serverName: currentServerName)

        directTCP?.connect(host: host, port: port, protocolType: protocolType, useTLS: useTLS, certificateName: certificateName, certificatePassword: certificatePassword, caCertificateName: caCertificateName, caCertificatePassword: caCertificatePassword) { [weak self] success in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if success {
                    self.isConnected = true
                    self.connectionStatus = "Connected"
                    self.connectionState = .connected(serverName: self.currentServerName, protocolType: self.currentProtocolType)
                    self.lastError = ""
                    #if DEBUG
                    print("✅ DirectTCP Connected to TAK server: \(host):\(port)")
                    #endif

                    // Configure ChatManager with this TAKService so chat can send messages
                    // Note: locationManager is optional - messages will work but without location data
                    ChatManager.shared.setTAKService(self)
                    #if DEBUG
                    print("✅ ChatManager configured with TAKService")
                    #endif

                    // Configure PositionBroadcastService for PLI (Position Location Information)
                    PositionBroadcastService.shared.configure(takService: self, locationManager: LocationManager.shared)
                    #if DEBUG
                    print("✅ PositionBroadcastService configured with TAKService")
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
                    self.isConnected = false
                    self.connectionStatus = "Connection Failed"
                    self.connectionState = .disconnected
                    self.lastError = "Failed to connect to \(host):\(port)"
                    print("❌ Connection failed")
                }
            }
        }
    }

    func disconnect() {
        // Disconnect all multi-server connections
        connectionsLock.lock()
        for state in serverConnections.values {
            state.sender.disconnect()
        }
        serverConnections.removeAll()
        connectionsLock.unlock()

        // Disconnect legacy DirectTCP
        directTCP?.disconnect()

        // Also disconnect Rust FFI
        if connectionHandle > 0 {
            omnitak_unregister_callback(connectionHandle)
            omnitak_disconnect(connectionHandle)
            connectionHandle = 0
        }

        connectedServerIds.removeAll()
        isConnected = false
        connectionStatus = "Disconnected"
        connectionState = .disconnected
        #if DEBUG
        print("🔌 Disconnected from all TAK servers")
        #endif
    }

    /// Disconnect all servers (alias for disconnect)
    func disconnectAll() {
        disconnect()
    }

    func sendCoT(xml: String) -> Bool {
        // Send to all connected servers
        // IMPORTANT: Check actual sender.isConnected (NWConnection state) not cached state
        // The cached ServerConnectionState.isConnected can get out of sync
        connectionsLock.lock()
        let allConnections = Array(serverConnections.values)
        // Filter by actual connection state, not cached state
        let connectedSenders = allConnections.filter { $0.sender.isConnected }.map { $0.sender }
        let totalConnections = allConnections.count
        let connectedCount = connectedSenders.count

        // Also check for any state sync issues
        #if DEBUG
        let cachedConnectedCount = allConnections.filter { $0.isConnected }.count
        if cachedConnectedCount != connectedCount {
            print("⚠️ [SEND] State sync issue: cached=\(cachedConnectedCount), actual=\(connectedCount)")
            // Update cached state to match actual state
            for conn in allConnections {
                if conn.isConnected != conn.sender.isConnected {
                    print("  → Server '\(conn.serverName)': cached=\(conn.isConnected), actual=\(conn.sender.isConnected)")
                }
            }
        }
        #endif
        connectionsLock.unlock()

        #if DEBUG
        print("📤 [SEND] Attempting to send CoT - \(connectedCount)/\(totalConnections) server connections available")
        #endif

        guard !connectedSenders.isEmpty else {
            // Fallback to legacy connection
            #if DEBUG
            print("📤 [SEND] No multi-server connections, trying legacy connection...")
            if let tcp = directTCP {
                print("📤 [SEND] Legacy directTCP exists, isConnected: \(tcp.isConnected)")
            } else {
                print("📤 [SEND] Legacy directTCP is nil")
            }
            #endif

            guard let directTCP = directTCP, directTCP.isConnected else {
                print("❌ [SEND] Not connected to any server - cannot send message")
                print("  → Published isConnected: \(isConnected)")
                print("  → connectedServerIds count: \(connectedServerIds.count)")
                print("  → serverConnections count: \(totalConnections)")
                return false
            }

            if directTCP.send(xml: xml) {
                messagesSent += 1
                #if DEBUG
                print("📤 Sent CoT message via legacy connection")
                #endif
                return true
            } else {
                print("❌ Failed to send CoT message via legacy connection")
                return false
            }
        }

        var sentCount = 0
        for sender in connectedSenders {
            if sender.send(xml: xml) {
                sentCount += 1
            }
        }

        if sentCount > 0 {
            messagesSent += 1
            #if DEBUG
            print("📤 Sent CoT message to \(sentCount) server(s)")
            #endif
            return true
        } else {
            print("❌ Failed to send CoT message to any server")
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

    /// Get current receive buffer size (aggregated from all connections)
    func getReceiveBufferSize() -> Int {
        connectionsLock.lock()
        var totalSize = 0
        for state in serverConnections.values {
            totalSize += state.sender.getReceiveBufferSize()
        }
        connectionsLock.unlock()

        // Include legacy connection
        if let legacySize = directTCP?.getReceiveBufferSize() {
            totalSize += legacySize
        }
        return totalSize
    }

    /// Clear the receive buffer on all connections
    func clearReceiveBuffer() {
        connectionsLock.lock()
        for state in serverConnections.values {
            state.sender.clearReceiveBuffer()
        }
        connectionsLock.unlock()

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

        // Reset stats on all connections
        connectionsLock.lock()
        for state in serverConnections.values {
            state.sender.resetStatistics()
        }
        connectionsLock.unlock()

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
        #if DEBUG
        print("📨 [CHAT DEBUG] Received b-t-f message, attempting to parse...")
        #endif
        if let chatMessage = ChatXMLParser.parseGeoChatMessage(xml: message) {
            DispatchQueue.main.async {
                service.messagesReceived += 1
                service.lastMessage = message
                service.onChatMessageReceived?(chatMessage)
                #if DEBUG
                print("💬 [CHAT DEBUG] Successfully parsed chat message from \(chatMessage.senderCallsign): \(chatMessage.messageText)")
                #endif
            }
        } else {
            #if DEBUG
            print("❌ [CHAT DEBUG] FAILED to parse b-t-f message! Raw XML:")
            print(message)
            print("❌ [CHAT DEBUG] END FAILED MESSAGE")
            #endif
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
