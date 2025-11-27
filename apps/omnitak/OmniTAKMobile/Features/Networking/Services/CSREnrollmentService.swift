//
//  CSREnrollmentService.swift
//  OmniTAKMobile
//
//  CSR-based certificate enrollment with TAK servers
//  Implements standard TAK enrollment flow: CSR generation → submission → certificate storage
//

import Foundation
import Security

// MARK: - Enrollment Errors

enum CSREnrollmentError: LocalizedError {
    case invalidServerURL
    case networkError(Error)
    case authenticationFailed
    case serverError(Int, String)
    case invalidResponse(String)
    case certificateStorageFailed(String)
    case configurationError(String)

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "Invalid server URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .authenticationFailed:
            return "Authentication failed - check username and password"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .invalidResponse(let details):
            return "Invalid server response: \(details)"
        case .certificateStorageFailed(let details):
            return "Failed to store certificate: \(details)"
        case .configurationError(let details):
            return "Configuration error: \(details)"
        }
    }
}

// MARK: - Enrollment Configuration

struct CSREnrollmentConfiguration {
    let serverHost: String
    let serverPort: Int                 // CoT streaming port
    let enrollmentPort: Int             // API/enrollment port (usually 8446)
    let username: String
    let password: String
    let useSSL: Bool

    // Paths (TAK standard endpoints)
    let configPath: String = "/Marti/api/tls/config"
    let csrPath: String = "/Marti/api/tls/signClient/v2"

    // Client info for CSR submission
    let clientUid: String = UUID().uuidString
    let clientVersion: String = "OmniTAK-1.0"

    var baseURL: String {
        let scheme = useSSL ? "https" : "http"
        return "\(scheme)://\(serverHost):\(enrollmentPort)"
    }

    var configURL: URL? {
        URL(string: "\(baseURL)\(configPath)")
    }

    var csrURL: URL? {
        // TAKAware includes clientUid and version as query params
        let escapedUid = clientUid.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? clientUid
        let escapedVersion = clientVersion.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? clientVersion
        return URL(string: "\(baseURL)\(csrPath)?clientUid=\(escapedUid)&version=\(escapedVersion)")
    }
}

// MARK: - CA Configuration (from server)

struct CAConfiguration {
    var organizationNames: [String] = []
    var organizationalUnitNames: [String] = []
    var domainComponents: [String] = []
}

// MARK: - Enrollment Response

struct EnrollmentResponse {
    let signedCertificate: Data         // DER-encoded signed certificate
    let trustChain: [Data]              // DER-encoded CA certificates
    let privateKeyTag: String           // Tag to retrieve private key from keychain
}

// MARK: - CSR Enrollment Service

class CSREnrollmentService {

    private let csrGenerator = CSRGenerator()
    private let urlSession: URLSession

    init() {
        // Configure URLSession to accept self-signed certificates (common in TAK deployments)
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60

        self.urlSession = URLSession(
            configuration: configuration,
            delegate: CSRSelfSignedCertificateDelegate(),
            delegateQueue: nil
        )
    }

    // MARK: - Main Enrollment Method

    /// Enroll with TAK server using CSR-based authentication
    /// - Parameter config: Enrollment configuration with server and credentials
    /// - Returns: TAKServer configuration with enrolled certificates
    func enrollWithCSR(config: CSREnrollmentConfiguration) async throws -> TAKServer {
        print("[CSREnroll] Starting CSR-based enrollment for user: \(config.username)")

        // Step 1: Get CA configuration from server (provides DN components)
        print("[CSREnroll] Fetching CA configuration from server...")
        let caConfig = try await fetchCAConfiguration(config: config)
        print("[CSREnroll] CA configuration retrieved: O=\(caConfig.organizationNames), OU=\(caConfig.organizationalUnitNames)")

        // TAKaware approach: Use consistent label for both private key and certificate
        // This allows iOS to automatically create the SecIdentity
        let certificateAlias = "omnitak-cert-\(config.serverHost)"

        // Step 2: Generate CSR with DN from server
        // Use certificate alias as the key tag so they match
        print("[CSREnroll] Generating CSR with key tag: \(certificateAlias)")
        let csrResult = try csrGenerator.generateCSR(
            username: config.username,
            caConfig: caConfig,
            keyTag: certificateAlias  // Use same label as certificate
        )
        print("[CSREnroll] CSR generated successfully")

        // Step 3: Submit CSR to server
        print("[CSREnroll] Submitting CSR to server...")
        let enrollmentResponse = try await submitCSR(
            csrBase64: csrResult.csrBase64,
            config: config
        )
        print("[CSREnroll] Received signed certificate from server")

        // Step 4: Store signed certificate with private key
        // Use the same certificateAlias that was used for the key tag
        print("[CSREnroll] Storing certificate and creating identity...")
        try storeCertificateIdentity(
            response: enrollmentResponse,
            privateKeyTag: csrResult.privateKeyTag,
            certificateAlias: certificateAlias
        )
        print("[CSREnroll] Certificate identity stored successfully")

        // Step 5: Create server configuration
        let serverInstance = TAKServer(
            id: UUID(),
            name: "TAK Server (\(config.serverHost))",
            host: config.serverHost,
            port: UInt16(config.serverPort),
            protocolType: config.useSSL ? "ssl" : "tcp",
            useTLS: config.useSSL,
            isDefault: false,
            certificateName: certificateAlias,
            certificatePassword: "omnitak"  // Password for CSR-enrolled certificates
        )

        // Add server to manager (must be on main thread for @Published properties)
        await MainActor.run {
            ServerManager.shared.addServer(serverInstance)
        }

        print("[CSREnroll] Enrollment completed successfully")
        return serverInstance
    }

    // MARK: - CA Configuration Retrieval

    private func fetchCAConfiguration(config: CSREnrollmentConfiguration) async throws -> CAConfiguration {
        guard let url = config.configURL else {
            throw CSREnrollmentError.invalidServerURL
        }

        let authHeader = generateAuthHeader(config: config)
        print("[CSREnroll] Request URL: \(url.absoluteString)")
        print("[CSREnroll] Auth header: \(authHeader)")
        print("[CSREnroll] Username: '\(config.username)' Password length: \(config.password.count)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw CSREnrollmentError.invalidResponse("Not an HTTP response")
            }

            print("[CSREnroll] Config response status: \(httpResponse.statusCode)")

            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 401 {
                    throw CSREnrollmentError.authenticationFailed
                }
                let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw CSREnrollmentError.serverError(httpResponse.statusCode, errorMsg)
            }

            // Parse XML configuration (TAK servers return XML from /Marti/api/tls/config)
            return parseCAConfigXML(data: data)

        } catch let error as CSREnrollmentError {
            throw error
        } catch {
            throw CSREnrollmentError.networkError(error)
        }
    }

    /// Parse CA configuration XML response
    /// Format: <nameEntry name="O" value="Organization"/>
    private func parseCAConfigXML(data: Data) -> CAConfiguration {
        var caConfig = CAConfiguration()

        guard let xmlString = String(data: data, encoding: .utf8) else {
            print("[CSREnroll] Warning: Could not decode config response as UTF-8")
            return caConfig
        }

        print("[CSREnroll] Parsing CA config XML...")

        // Simple XML parsing for nameEntry elements
        // Format: <nameEntry name="O" value="OrganizationName"/>
        let pattern = #"<nameEntry\s+name="([^"]+)"\s+value="([^"]+)"/?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            print("[CSREnroll] Warning: Failed to create regex for XML parsing")
            return caConfig
        }

        let range = NSRange(xmlString.startIndex..., in: xmlString)
        let matches = regex.matches(in: xmlString, options: [], range: range)

        for match in matches {
            guard match.numberOfRanges == 3,
                  let nameRange = Range(match.range(at: 1), in: xmlString),
                  let valueRange = Range(match.range(at: 2), in: xmlString) else {
                continue
            }

            let name = String(xmlString[nameRange]).uppercased()
            let value = String(xmlString[valueRange])

            switch name {
            case "O":
                caConfig.organizationNames.append(value)
                print("[CSREnroll] Found O: \(value)")
            case "OU":
                caConfig.organizationalUnitNames.append(value)
                print("[CSREnroll] Found OU: \(value)")
            case "DC":
                caConfig.domainComponents.append(value)
                print("[CSREnroll] Found DC: \(value)")
            default:
                print("[CSREnroll] Ignoring nameEntry: \(name)=\(value)")
            }
        }

        return caConfig
    }

    // MARK: - CSR Submission

    private func submitCSR(
        csrBase64: String,
        config: CSREnrollmentConfiguration
    ) async throws -> EnrollmentResponse {
        guard let url = config.csrURL else {
            throw CSREnrollmentError.invalidServerURL
        }

        // TAKAware sends raw base64-encoded CSR as body (not JSON wrapped)
        // Content-Type: text/plain; charset=utf-8
        guard let bodyData = csrBase64.data(using: .utf8) else {
            throw CSREnrollmentError.invalidResponse("Failed to encode CSR as UTF-8")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(generateAuthHeader(config: config), forHTTPHeaderField: "Authorization")
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        print("[CSREnroll] Submitting CSR to \(url.absoluteString)")

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw CSREnrollmentError.invalidResponse("Not an HTTP response")
            }

            print("[CSREnroll] CSR submission response status: \(httpResponse.statusCode)")

            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 401 {
                    throw CSREnrollmentError.authenticationFailed
                }
                let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw CSREnrollmentError.serverError(httpResponse.statusCode, errorMsg)
            }

            // Parse response
            return try parseEnrollmentResponse(data: data)

        } catch let error as CSREnrollmentError {
            throw error
        } catch {
            throw CSREnrollmentError.networkError(error)
        }
    }

    // MARK: - Response Parsing

    private func parseEnrollmentResponse(data: Data) throws -> EnrollmentResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            let responseStr = String(data: data, encoding: .utf8) ?? "Unable to decode"
            throw CSREnrollmentError.invalidResponse("Invalid JSON response: \(responseStr)")
        }

        print("[CSREnroll] Parsing enrollment response...")

        // Extract signed certificate
        guard let signedCertPEM = json["signedCert"] else {
            throw CSREnrollmentError.invalidResponse("Missing 'signedCert' in response")
        }

        let signedCertDER = try pemToDER(signedCertPEM)
        print("[CSREnroll] Signed certificate parsed (\(signedCertDER.count) bytes)")

        // Extract CA trust chain (entries prefixed with "ca")
        var trustChain: [Data] = []
        let caEntries = json.filter { $0.key.starts(with: "ca") }.sorted { $0.key < $1.key }

        for (key, caPEM) in caEntries {
            do {
                let caDER = try pemToDER(caPEM)
                trustChain.append(caDER)
                print("[CSREnroll] CA certificate '\(key)' parsed (\(caDER.count) bytes)")
            } catch {
                print("[CSREnroll] Warning: Failed to parse CA cert '\(key)': \(error)")
            }
        }

        print("[CSREnroll] Parsed \(trustChain.count) CA certificates")

        // Create temporary key tag (will be replaced by actual private key tag)
        let privateKeyTag = "temp"

        return EnrollmentResponse(
            signedCertificate: signedCertDER,
            trustChain: trustChain,
            privateKeyTag: privateKeyTag
        )
    }

    // MARK: - Certificate Storage
    // Implementation follows TAKaware's approach for keychain identity creation

    private func storeCertificateIdentity(
        response: EnrollmentResponse,
        privateKeyTag: String,
        certificateAlias: String
    ) throws {
        // Verify the private key exists (it should have been created with the same label)
        guard csrGenerator.retrievePrivateKey(tag: privateKeyTag) != nil else {
            throw CSREnrollmentError.certificateStorageFailed("Failed to retrieve private key from keychain")
        }

        // Create SecCertificate from DER data
        guard let certificate = SecCertificateCreateWithData(nil, response.signedCertificate as CFData) else {
            throw CSREnrollmentError.certificateStorageFailed("Failed to create certificate from DER data")
        }

        // Clear existing certificates and identities (TAKaware approach)
        clearCertsAndIdentities(label: certificateAlias)

        print("[CSREnroll] Adding client certificate to keychain with label: \(certificateAlias)")

        // Add certificate to keychain with kSecReturnAttributes to get issuer/serial
        // This is exactly how TAKaware does it
        let addArgs: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrLabel as String: certificateAlias,
            kSecValueRef as String: certificate,
            kSecReturnAttributes as String: true
        ]

        var resultRef: AnyObject?
        let addStatus = SecItemAdd(addArgs as CFDictionary, &resultRef)

        guard addStatus == errSecSuccess, let certAttrs = resultRef as? [String: Any] else {
            throw CSREnrollmentError.certificateStorageFailed("Failed to add certificate to keychain: \(addStatus)")
        }

        print("[CSREnroll] Certificate added, attempting to create identity...")

        // Get issuer and serial number from certificate attributes
        // These are used to match the certificate with the private key
        guard let issuer = certAttrs[kSecAttrIssuer as String] as? Data,
              let serialNumber = certAttrs[kSecAttrSerialNumber as String] as? Data else {
            print("[CSREnroll] Warning: Could not retrieve issuer/serial from certificate attributes")
            print("[CSREnroll] Available attributes: \(certAttrs.keys)")

            // Store mapping for fallback retrieval
            UserDefaults.standard.set(privateKeyTag, forKey: "csr_key_tag_\(certificateAlias)")
            UserDefaults.standard.set(response.signedCertificate, forKey: "csr_cert_data_\(certificateAlias)")
            return  // Early return - identity will be found by certificate matching
        }

        print("[CSREnroll] Got issuer (\(issuer.count) bytes) and serial (\(serialNumber.count) bytes)")

        // Query for identity using issuer and serial number (TAKaware approach)
        // iOS automatically creates SecIdentity when cert + key have matching public keys
        // CRITICAL: Use kSecReturnPersistentRef to make iOS create a persistent identity
        let identityArgs: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrIssuer as String: issuer,
            kSecAttrSerialNumber as String: serialNumber,
            kSecReturnPersistentRef as String: true  // This is critical - makes identity persist
        ]

        var identityRef: CFTypeRef?
        let identityStatus = SecItemCopyMatching(identityArgs as CFDictionary, &identityRef)

        if identityStatus == errSecSuccess, let _ = identityRef as? Data {
            print("[CSREnroll] ✅ SecIdentity created with persistent reference!")

            // Verify by querying again with kSecReturnRef
            let verifyArgs: [String: Any] = [
                kSecClass as String: kSecClassIdentity,
                kSecAttrIssuer as String: issuer,
                kSecAttrSerialNumber as String: serialNumber,
                kSecReturnRef as String: true
            ]

            var verifyRef: CFTypeRef?
            let verifyStatus = SecItemCopyMatching(verifyArgs as CFDictionary, &verifyRef)

            if verifyStatus == errSecSuccess, verifyRef != nil {
                let identity = verifyRef as! SecIdentity
                var certRef: SecCertificate?
                var keyRef: SecKey?
                let certStatus = SecIdentityCopyCertificate(identity, &certRef)
                let keyStatus = SecIdentityCopyPrivateKey(identity, &keyRef)

                if certStatus == errSecSuccess && keyStatus == errSecSuccess {
                    print("[CSREnroll] ✅ Identity validated: certificate and private key accessible")
                } else {
                    print("[CSREnroll] ⚠️ Identity incomplete - cert status: \(certStatus), key status: \(keyStatus)")
                }
            }
        } else {
            print("[CSREnroll] ⚠️ Identity not found (status: \(identityStatus))")
            print("[CSREnroll] Reason: iOS did not automatically link cert with key")
            print("[CSREnroll] This usually means:")
            print("[CSREnroll]   1. Certificate and private key have different labels")
            print("[CSREnroll]   2. Public key in cert doesn't match private key")
            print("[CSREnroll]   3. Certificate was not stored with proper attributes")

            // Add explicit validation to help diagnose
            validateCertificateKeyPairing(certificateAlias: certificateAlias, privateKeyTag: privateKeyTag)
        }

        // Store mapping for TAKService lookup
        UserDefaults.standard.set(privateKeyTag, forKey: "csr_key_tag_\(certificateAlias)")
        UserDefaults.standard.set(response.signedCertificate, forKey: "csr_cert_data_\(certificateAlias)")

        print("[CSREnroll] Stored certificate mapping: \(certificateAlias) -> \(privateKeyTag)")

        // Store CA trust chain
        for (index, caData) in response.trustChain.enumerated() {
            if let caCert = SecCertificateCreateWithData(nil, caData as CFData) {
                let caQuery: [String: Any] = [
                    kSecClass as String: kSecClassCertificate,
                    kSecValueRef as String: caCert,
                    kSecAttrLabel as String: "\(certificateAlias)-ca-\(index)",
                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
                ]

                SecItemDelete(caQuery as CFDictionary)
                let caStatus = SecItemAdd(caQuery as CFDictionary, nil)

                if caStatus == errSecSuccess || caStatus == errSecDuplicateItem {
                    print("[CSREnroll] Stored CA certificate \(index)")
                } else {
                    print("[CSREnroll] Warning: Failed to store CA cert \(index): \(caStatus)")
                }
            }
        }
    }

    /// Clear existing certificates and identities for a given label
    private func clearCertsAndIdentities(label: String) {
        // Delete certificate with this label
        let certQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: label
        ]
        SecItemDelete(certQuery as CFDictionary)

        // Delete identity with this label
        let identityQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: label
        ]
        SecItemDelete(identityQuery as CFDictionary)
    }

    /// Validate that certificate and private key can be paired
    private func validateCertificateKeyPairing(certificateAlias: String, privateKeyTag: String) {
        print("[CSREnroll] 🔍 Validating certificate-key pairing...")

        // Check if certificate exists
        let certQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: certificateAlias,
            kSecReturnRef as String: true,
            kSecReturnAttributes as String: true
        ]

        var certItem: CFTypeRef?
        let certStatus = SecItemCopyMatching(certQuery as CFDictionary, &certItem)

        if certStatus == errSecSuccess {
            print("[CSREnroll] ✅ Certificate found with label: \(certificateAlias)")
            if let certDict = certItem as? [String: Any] {
                print("[CSREnroll]    Certificate attributes: \(certDict.keys.joined(separator: ", "))")
            }
        } else {
            print("[CSREnroll] ❌ Certificate NOT found (status: \(certStatus))")
            return
        }

        // Check if private key exists
        let keyQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrApplicationTag as String: privateKeyTag.data(using: .utf8)!,
            kSecReturnRef as String: true,
            kSecReturnAttributes as String: true
        ]

        var keyItem: CFTypeRef?
        let keyStatus = SecItemCopyMatching(keyQuery as CFDictionary, &keyItem)

        if keyStatus == errSecSuccess {
            print("[CSREnroll] ✅ Private key found with tag: \(privateKeyTag)")
            if let keyDict = keyItem as? [String: Any] {
                print("[CSREnroll]    Key attributes: \(keyDict.keys.joined(separator: ", "))")
                if let keyLabel = keyDict[kSecAttrLabel as String] as? String {
                    print("[CSREnroll]    Key label: \(keyLabel)")
                    if keyLabel == certificateAlias {
                        print("[CSREnroll] ✅ Labels match!")
                    } else {
                        print("[CSREnroll] ❌ Label mismatch! Key: '\(keyLabel)' vs Cert: '\(certificateAlias)'")
                    }
                }
            }
        } else {
            print("[CSREnroll] ❌ Private key NOT found (status: \(keyStatus))")
            return
        }

        // Try to find identity by label (alternative method)
        let identityByLabelQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: certificateAlias,
            kSecReturnRef as String: true
        ]

        var identityByLabel: CFTypeRef?
        let identityByLabelStatus = SecItemCopyMatching(identityByLabelQuery as CFDictionary, &identityByLabel)

        if identityByLabelStatus == errSecSuccess {
            print("[CSREnroll] ✅ Identity found by label: \(certificateAlias)")
        } else {
            print("[CSREnroll] ⚠️ Identity NOT found by label (status: \(identityByLabelStatus))")
            print("[CSREnroll]    This means iOS did not auto-create the identity")
        }

        print("[CSREnroll] 🔍 Validation complete")
    }

    // MARK: - Helper Methods

    private func generateAuthHeader(config: CSREnrollmentConfiguration) -> String {
        let credentials = "\(config.username):\(config.password)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        return "Basic \(base64Credentials)"
    }

    private func pemToDER(_ pem: String) throws -> Data {
        // Remove PEM headers/footers and whitespace
        var lines = pem.components(separatedBy: .newlines)
        lines = lines.filter { line in
            !line.contains("-----BEGIN") &&
            !line.contains("-----END") &&
            !line.trimmingCharacters(in: .whitespaces).isEmpty
        }

        let base64String = lines.joined()

        guard let derData = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters) else {
            throw CSREnrollmentError.invalidResponse("Failed to decode PEM certificate")
        }

        return derData
    }
}

// MARK: - Self-Signed Certificate Delegate

/// URLSession delegate for CSR enrollment that accepts self-signed certificates
private class CSRSelfSignedCertificateDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Accept self-signed certificates for HTTPS (common in TAK deployments)
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }

        completionHandler(.performDefaultHandling, nil)
    }
}

// MARK: - Convenience Methods

extension CSREnrollmentService {

    /// Quick enrollment with common defaults
    func enroll(
        server: String,
        port: Int = 8089,
        enrollmentPort: Int = 8446,
        username: String,
        password: String
    ) async throws -> TAKServer {
        let config = CSREnrollmentConfiguration(
            serverHost: server,
            serverPort: port,
            enrollmentPort: enrollmentPort,
            username: username,
            password: password,
            useSSL: true
        )

        return try await enrollWithCSR(config: config)
    }
}
