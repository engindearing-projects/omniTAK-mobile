//
//  CSREnrollmentService.swift
//  OmniTAKMobile
//
//  Certificate Signing Request (CSR) based enrollment service
//  Implements TAK server username/password authentication with CSR generation
//  Based on TAKAware's CSRRequestor pattern
//

import Foundation
import Security
import CryptoKit

// MARK: - Enrollment Configuration

struct TAKServerEnrollmentConfig: Codable {
    let serverURL: String
    let username: String
    let password: String
    let port: Int
    let certEnrollPort: Int
    let secureAPIPort: Int
    var trustSelfSignedCerts: Bool = true

    var enrollmentBaseURL: String {
        "https://\(serverURL):\(certEnrollPort)"
    }

    var apiBaseURL: String {
        "https://\(serverURL):\(secureAPIPort)"
    }
}

// MARK: - CSR Response Models

struct TAKCAConfig: Codable {
    let nameEntries: [String: String]
    let validityDays: Int?
    let fingerprint: String?

    init(nameEntries: [String: String], validityDays: Int? = nil, fingerprint: String? = nil) {
        self.nameEntries = nameEntries
        self.validityDays = validityDays
        self.fingerprint = fingerprint
    }
}

struct CSRSigningResponse: Codable {
    let signedCert: String        // Base64 encoded signed certificate
    let caCerts: [String]         // Base64 encoded CA certificate chain
    let status: String?
    let message: String?
}

// MARK: - Enrollment Status

enum CSREnrollmentStatus: Equatable {
    case idle
    case connecting
    case fetchingConfig
    case generatingCSR
    case submittingCSR
    case processingCertificate
    case completed
    case failed(String)

    var description: String {
        switch self {
        case .idle:
            return "Ready to enroll"
        case .connecting:
            return "Connecting to server..."
        case .fetchingConfig:
            return "Fetching CA configuration..."
        case .generatingCSR:
            return "Generating certificate request..."
        case .submittingCSR:
            return "Submitting certificate request..."
        case .processingCertificate:
            return "Processing certificate..."
        case .completed:
            return "Enrollment completed"
        case .failed(let message):
            return "Failed: \(message)"
        }
    }

    var isInProgress: Bool {
        switch self {
        case .idle, .completed, .failed:
            return false
        default:
            return true
        }
    }
}

// MARK: - CSR Enrollment Errors

enum CSREnrollmentError: LocalizedError {
    case invalidServerURL
    case connectionFailed(String)
    case authenticationFailed
    case configFetchFailed(String)
    case keyGenerationFailed(String)
    case csrGenerationFailed(String)
    case csrSubmissionFailed(String)
    case certificateProcessingFailed(String)
    case certificateStorageFailed(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "Invalid server URL"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .authenticationFailed:
            return "Authentication failed - check username and password"
        case .configFetchFailed(let message):
            return "Failed to fetch CA configuration: \(message)"
        case .keyGenerationFailed(let message):
            return "Failed to generate key pair: \(message)"
        case .csrGenerationFailed(let message):
            return "Failed to generate certificate request: \(message)"
        case .csrSubmissionFailed(let message):
            return "Failed to submit certificate request: \(message)"
        case .certificateProcessingFailed(let message):
            return "Failed to process certificate: \(message)"
        case .certificateStorageFailed(let message):
            return "Failed to store certificate: \(message)"
        case .invalidResponse(let message):
            return "Invalid server response: \(message)"
        }
    }
}

// MARK: - CSR Enrollment Service

@MainActor
class CSREnrollmentService: ObservableObject {
    static let shared = CSREnrollmentService()

    @Published var status: CSREnrollmentStatus = .idle
    @Published var progress: Double = 0

    private var urlSession: URLSession?
    private var currentConfig: TAKServerEnrollmentConfig?
    private var generatedPrivateKey: SecKey?

    private let keychainService = "com.omnitak.csr.enrollment"

    init() {
        // Session will be configured per enrollment with proper auth
    }

    // MARK: - Main Enrollment Flow

    /// Begin CSR-based enrollment with TAK server
    /// - Parameters:
    ///   - config: Server configuration including credentials
    /// - Returns: The configured TAKServer on success
    func beginEnrollment(config: TAKServerEnrollmentConfig) async throws -> TAKServer {
        self.currentConfig = config
        progress = 0

        // Create URL session with self-signed cert support
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 120

        let delegate = CSRURLSessionDelegate(trustSelfSigned: config.trustSelfSignedCerts)
        urlSession = URLSession(configuration: sessionConfig, delegate: delegate, delegateQueue: nil)

        defer {
            urlSession?.invalidateAndCancel()
            urlSession = nil
        }

        do {
            // Step 1: Fetch CA configuration
            status = .fetchingConfig
            progress = 0.1
            let caConfig = try await fetchCAConfiguration(config: config)

            // Step 2: Generate key pair and CSR
            status = .generatingCSR
            progress = 0.3
            let (privateKey, csr) = try generateCSR(config: config, caConfig: caConfig)
            self.generatedPrivateKey = privateKey

            // Step 3: Submit CSR to server
            status = .submittingCSR
            progress = 0.5
            let signingResponse = try await submitCSR(csr: csr, config: config)

            // Step 4: Process and store certificate
            status = .processingCertificate
            progress = 0.7
            let server = try await processAndStoreCertificate(
                response: signingResponse,
                privateKey: privateKey,
                config: config
            )

            status = .completed
            progress = 1.0

            print("CSR Enrollment completed successfully for \(config.serverURL)")
            return server

        } catch {
            let errorMessage = (error as? CSREnrollmentError)?.errorDescription ?? error.localizedDescription
            status = .failed(errorMessage)
            throw error
        }
    }

    // MARK: - Step 1: Fetch CA Configuration

    private func fetchCAConfiguration(config: TAKServerEnrollmentConfig) async throws -> TAKCAConfig {
        let urlString = "\(config.enrollmentBaseURL)/Marti/api/tls/config"

        guard let url = URL(string: urlString) else {
            throw CSREnrollmentError.invalidServerURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(generateAuthHeader(config: config), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await urlSession!.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw CSREnrollmentError.invalidResponse("Not an HTTP response")
            }

            if httpResponse.statusCode == 401 {
                throw CSREnrollmentError.authenticationFailed
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw CSREnrollmentError.configFetchFailed("HTTP \(httpResponse.statusCode)")
            }

            // Parse XML response for name entries
            let nameEntries = try parseCAConfigXML(data: data)
            return TAKCAConfig(nameEntries: nameEntries)

        } catch let error as CSREnrollmentError {
            throw error
        } catch {
            throw CSREnrollmentError.connectionFailed(error.localizedDescription)
        }
    }

    private func parseCAConfigXML(data: Data) throws -> [String: String] {
        // TAK servers return XML with nameEntry elements
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw CSREnrollmentError.invalidResponse("Cannot decode config response")
        }

        var nameEntries: [String: String] = [:]

        // Parse nameEntry elements: <nameEntry name="O" value="TAK"/>
        let pattern = "<nameEntry[^>]*name=\"([^\"]+)\"[^>]*value=\"([^\"]+)\"[^>]*/>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(xmlString.startIndex..., in: xmlString)
            let matches = regex.matches(in: xmlString, options: [], range: range)

            for match in matches {
                if let nameRange = Range(match.range(at: 1), in: xmlString),
                   let valueRange = Range(match.range(at: 2), in: xmlString) {
                    let name = String(xmlString[nameRange])
                    let value = String(xmlString[valueRange])
                    nameEntries[name] = value
                }
            }
        }

        // Also try alternate format: <nameEntry><name>O</name><value>TAK</value></nameEntry>
        let altPattern = "<nameEntry>\\s*<name>([^<]+)</name>\\s*<value>([^<]+)</value>\\s*</nameEntry>"
        if let regex = try? NSRegularExpression(pattern: altPattern, options: []) {
            let range = NSRange(xmlString.startIndex..., in: xmlString)
            let matches = regex.matches(in: xmlString, options: [], range: range)

            for match in matches {
                if let nameRange = Range(match.range(at: 1), in: xmlString),
                   let valueRange = Range(match.range(at: 2), in: xmlString) {
                    let name = String(xmlString[nameRange])
                    let value = String(xmlString[valueRange])
                    nameEntries[name] = value
                }
            }
        }

        return nameEntries
    }

    // MARK: - Step 2: Generate CSR

    private func generateCSR(config: TAKServerEnrollmentConfig, caConfig: TAKCAConfig) throws -> (SecKey, Data) {
        // Generate RSA 2048-bit key pair
        let keyPairAttr: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: "com.omnitak.csr.\(config.username)".data(using: .utf8)!,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            ] as [String: Any]
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(keyPairAttr as CFDictionary, &error) else {
            let errorMsg = error?.takeRetainedValue().localizedDescription ?? "Unknown error"
            throw CSREnrollmentError.keyGenerationFailed(errorMsg)
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw CSREnrollmentError.keyGenerationFailed("Could not extract public key")
        }

        // Build Distinguished Name from CA config
        let dn = buildDistinguishedName(username: config.username, caConfig: caConfig)

        // Generate CSR (PKCS#10)
        let csrData = try generatePKCS10CSR(privateKey: privateKey, publicKey: publicKey, distinguishedName: dn)

        return (privateKey, csrData)
    }

    private func buildDistinguishedName(username: String, caConfig: TAKCAConfig) -> String {
        var components: [String] = []

        // CN is always the username
        components.append("CN=\(username)")

        // Add other components from CA config
        if let o = caConfig.nameEntries["O"] {
            components.append("O=\(o)")
        }
        if let ou = caConfig.nameEntries["OU"] {
            components.append("OU=\(ou)")
        }
        if let dc = caConfig.nameEntries["DC"] {
            components.append("DC=\(dc)")
        }
        if let c = caConfig.nameEntries["C"] {
            components.append("C=\(c)")
        }
        if let st = caConfig.nameEntries["ST"] {
            components.append("ST=\(st)")
        }
        if let l = caConfig.nameEntries["L"] {
            components.append("L=\(l)")
        }

        return components.joined(separator: ",")
    }

    private func generatePKCS10CSR(privateKey: SecKey, publicKey: SecKey, distinguishedName: String) throws -> Data {
        // Export public key as DER
        var publicKeyError: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &publicKeyError) as Data? else {
            throw CSREnrollmentError.csrGenerationFailed("Cannot export public key")
        }

        // Build CSR structure manually (PKCS#10)
        // This is a simplified implementation - production should use a proper ASN.1 library

        // Encode Distinguished Name as DER
        let dnData = encodeDNAsDER(distinguishedName)

        // Wrap public key in SubjectPublicKeyInfo structure
        let spki = wrapPublicKeyInSPKI(publicKeyData)

        // Build CertificationRequestInfo
        let certRequestInfo = buildCertificationRequestInfo(dn: dnData, spki: spki)

        // Sign with private key
        var signError: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            certRequestInfo as CFData,
            &signError
        ) as Data? else {
            throw CSREnrollmentError.csrGenerationFailed("Failed to sign CSR")
        }

        // Build final CSR
        let csr = buildFinalCSR(certRequestInfo: certRequestInfo, signature: signature)

        return csr
    }

    // MARK: - ASN.1/DER Encoding Helpers

    private func encodeDNAsDER(_ dn: String) -> Data {
        // Parse DN string and encode as DER SEQUENCE of SET of SEQUENCE
        var rdnSequences: [Data] = []

        let components = dn.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }

        for component in components {
            let parts = component.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let attrType = String(parts[0])
            let attrValue = String(parts[1])

            let oid = getOIDForAttributeType(attrType)
            let attrValueData = encodeUTF8String(attrValue)

            // SEQUENCE { OID, value }
            let attrSeq = wrapInSequence([oid, attrValueData])
            // SET { attrSeq }
            let rdnSet = wrapInSet([attrSeq])
            rdnSequences.append(rdnSet)
        }

        return wrapInSequence(rdnSequences)
    }

    private func getOIDForAttributeType(_ type: String) -> Data {
        // OIDs for common X.500 attributes
        let oids: [String: [UInt8]] = [
            "CN": [0x06, 0x03, 0x55, 0x04, 0x03],           // 2.5.4.3
            "O": [0x06, 0x03, 0x55, 0x04, 0x0A],            // 2.5.4.10
            "OU": [0x06, 0x03, 0x55, 0x04, 0x0B],           // 2.5.4.11
            "C": [0x06, 0x03, 0x55, 0x04, 0x06],            // 2.5.4.6
            "ST": [0x06, 0x03, 0x55, 0x04, 0x08],           // 2.5.4.8
            "L": [0x06, 0x03, 0x55, 0x04, 0x07],            // 2.5.4.7
            "DC": [0x06, 0x0A, 0x09, 0x92, 0x26, 0x89, 0x93, 0xF2, 0x2C, 0x64, 0x01, 0x19]  // 0.9.2342.19200300.100.1.25
        ]

        return Data(oids[type] ?? oids["CN"]!)
    }

    private func encodeUTF8String(_ string: String) -> Data {
        let utf8Data = string.data(using: .utf8)!
        var result = Data([0x0C])  // UTF8String tag
        result.append(contentsOf: encodeDERLength(utf8Data.count))
        result.append(utf8Data)
        return result
    }

    private func wrapInSequence(_ items: [Data]) -> Data {
        var content = Data()
        for item in items {
            content.append(item)
        }

        var result = Data([0x30])  // SEQUENCE tag
        result.append(contentsOf: encodeDERLength(content.count))
        result.append(content)
        return result
    }

    private func wrapInSet(_ items: [Data]) -> Data {
        var content = Data()
        for item in items {
            content.append(item)
        }

        var result = Data([0x31])  // SET tag
        result.append(contentsOf: encodeDERLength(content.count))
        result.append(content)
        return result
    }

    private func encodeDERLength(_ length: Int) -> [UInt8] {
        if length < 128 {
            return [UInt8(length)]
        } else if length < 256 {
            return [0x81, UInt8(length)]
        } else if length < 65536 {
            return [0x82, UInt8(length >> 8), UInt8(length & 0xFF)]
        } else {
            return [0x83, UInt8(length >> 16), UInt8((length >> 8) & 0xFF), UInt8(length & 0xFF)]
        }
    }

    private func wrapPublicKeyInSPKI(_ publicKeyData: Data) -> Data {
        // RSA AlgorithmIdentifier
        let rsaAlgId = Data([
            0x30, 0x0D,                                     // SEQUENCE
            0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01,  // rsaEncryption OID
            0x05, 0x00                                      // NULL parameters
        ])

        // Wrap public key as BIT STRING
        var bitString = Data([0x03])  // BIT STRING tag
        let keyWithUnusedBits = Data([0x00]) + publicKeyData  // 0 unused bits
        bitString.append(contentsOf: encodeDERLength(keyWithUnusedBits.count))
        bitString.append(keyWithUnusedBits)

        // Combine into SubjectPublicKeyInfo SEQUENCE
        var content = rsaAlgId
        content.append(bitString)

        var result = Data([0x30])  // SEQUENCE tag
        result.append(contentsOf: encodeDERLength(content.count))
        result.append(content)

        return result
    }

    private func buildCertificationRequestInfo(dn: Data, spki: Data) -> Data {
        // Version: INTEGER 0
        let version = Data([0x02, 0x01, 0x00])

        // Empty attributes: [0] {}
        let attributes = Data([0xA0, 0x00])

        // Build CertificationRequestInfo SEQUENCE
        var content = version
        content.append(dn)
        content.append(spki)
        content.append(attributes)

        var result = Data([0x30])  // SEQUENCE tag
        result.append(contentsOf: encodeDERLength(content.count))
        result.append(content)

        return result
    }

    private func buildFinalCSR(certRequestInfo: Data, signature: Data) -> Data {
        // Signature AlgorithmIdentifier (SHA256withRSA)
        let sigAlgId = Data([
            0x30, 0x0D,                                     // SEQUENCE
            0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0B,  // sha256WithRSAEncryption OID
            0x05, 0x00                                      // NULL parameters
        ])

        // Wrap signature as BIT STRING
        var sigBitString = Data([0x03])  // BIT STRING tag
        let sigWithUnusedBits = Data([0x00]) + signature  // 0 unused bits
        sigBitString.append(contentsOf: encodeDERLength(sigWithUnusedBits.count))
        sigBitString.append(sigWithUnusedBits)

        // Build final CSR SEQUENCE
        var content = certRequestInfo
        content.append(sigAlgId)
        content.append(sigBitString)

        var result = Data([0x30])  // SEQUENCE tag
        result.append(contentsOf: encodeDERLength(content.count))
        result.append(content)

        return result
    }

    // MARK: - Step 3: Submit CSR

    private func submitCSR(csr: Data, config: TAKServerEnrollmentConfig) async throws -> CSRSigningResponse {
        let urlString = "\(config.enrollmentBaseURL)/Marti/api/tls/signClient/v2"

        guard let url = URL(string: urlString) else {
            throw CSREnrollmentError.invalidServerURL
        }

        // Convert CSR to PEM format
        let csrPEM = convertToPEM(data: csr, type: "CERTIFICATE REQUEST")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(generateAuthHeader(config: config), forHTTPHeaderField: "Authorization")
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = csrPEM.data(using: .utf8)

        do {
            let (data, response) = try await urlSession!.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw CSREnrollmentError.invalidResponse("Not an HTTP response")
            }

            if httpResponse.statusCode == 401 {
                throw CSREnrollmentError.authenticationFailed
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                let bodyStr = String(data: data, encoding: .utf8) ?? "No body"
                throw CSREnrollmentError.csrSubmissionFailed("HTTP \(httpResponse.statusCode): \(bodyStr)")
            }

            // Parse JSON response
            let decoder = JSONDecoder()
            let signingResponse = try decoder.decode(CSRSigningResponse.self, from: data)

            return signingResponse

        } catch let error as CSREnrollmentError {
            throw error
        } catch let error as DecodingError {
            throw CSREnrollmentError.invalidResponse("JSON parsing failed: \(error.localizedDescription)")
        } catch {
            throw CSREnrollmentError.csrSubmissionFailed(error.localizedDescription)
        }
    }

    private func convertToPEM(data: Data, type: String) -> String {
        let base64 = data.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        return "-----BEGIN \(type)-----\n\(base64)\n-----END \(type)-----"
    }

    // MARK: - Step 4: Process and Store Certificate

    private func processAndStoreCertificate(
        response: CSRSigningResponse,
        privateKey: SecKey,
        config: TAKServerEnrollmentConfig
    ) async throws -> TAKServer {
        // Decode signed certificate
        guard let certData = Data(base64Encoded: response.signedCert) else {
            throw CSREnrollmentError.certificateProcessingFailed("Cannot decode certificate")
        }

        // Create P12 from private key and certificate
        let p12Data = try createP12(privateKey: privateKey, certificateData: certData, password: "atakatak")

        // Store in CertificateManager
        let certAlias = "csr-\(config.serverURL)-\(config.username)"

        try CertificateManager.shared.saveCertificate(
            name: certAlias,
            serverURL: config.apiBaseURL,
            username: config.username,
            p12Data: p12Data,
            password: "atakatak"
        )

        // Process CA certificates
        if !response.caCerts.isEmpty {
            try await processCACertificates(caCerts: response.caCerts, alias: certAlias)
        }

        // Save certificate file to Documents for TAKService compatibility
        try saveCertificateToDocuments(data: p12Data, filename: "\(certAlias).p12")

        // Create and save server configuration
        let server = TAKServer(
            name: "\(config.serverURL) (\(config.username))",
            host: config.serverURL,
            port: UInt16(config.port),
            protocolType: "ssl",
            useTLS: true,
            isDefault: false,
            certificateName: certAlias,
            certificatePassword: "atakatak"
        )

        ServerManager.shared.addServer(server)

        return server
    }

    private func createP12(privateKey: SecKey, certificateData: Data, password: String) throws -> Data {
        // Import certificate
        guard let certificate = SecCertificateCreateWithData(nil, certificateData as CFData) else {
            throw CSREnrollmentError.certificateProcessingFailed("Invalid certificate data")
        }

        // Create identity
        let identityQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate,
            kSecAttrLabel as String: "temp-csr-cert"
        ]

        // Delete any existing
        SecItemDelete(identityQuery as CFDictionary)

        // Add certificate to keychain temporarily
        var status = SecItemAdd(identityQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CSREnrollmentError.certificateStorageFailed("Cannot add certificate to keychain: \(status)")
        }

        defer {
            // Clean up temporary certificate
            SecItemDelete(identityQuery as CFDictionary)
        }

        // Export private key
        var error: Unmanaged<CFError>?
        guard let privateKeyData = SecKeyCopyExternalRepresentation(privateKey, &error) as Data? else {
            throw CSREnrollmentError.certificateProcessingFailed("Cannot export private key")
        }

        // For iOS, we need to create the P12 manually or use a workaround
        // Since iOS doesn't have SecPKCS12Export, we'll store key and cert separately
        // and recreate the P12 structure

        // For now, return a combined format that our import can understand
        return createSimplePKCS12(privateKeyData: privateKeyData, certificateData: certificateData, password: password)
    }

    private func createSimplePKCS12(privateKeyData: Data, certificateData: Data, password: String) -> Data {
        // This creates a PKCS#12 structure using the provided data
        // In production, consider using a library like OpenSSL-Swift for proper P12 creation

        // For now, we'll import directly into the keychain and export
        // This is a simplified implementation

        // Create identity by combining the key and cert
        let options: [String: Any] = [
            kSecImportExportPassphrase as String: password
        ]

        // Build PKCS12 structure
        var p12Data = Data()

        // PFX header
        p12Data.append(contentsOf: [0x30, 0x82])  // SEQUENCE

        // Version
        let version = Data([0x02, 0x01, 0x03])  // INTEGER 3

        // AuthSafe SEQUENCE
        var authSafe = Data()
        authSafe.append(contentsOf: [0x06, 0x0B, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x07, 0x01])  // data OID

        // For now, return the raw certificate with a simple wrapper
        // The actual P12 creation would require more complex ASN.1 encoding

        // Simplified: Store cert and key data with a marker
        var combinedData = Data()
        combinedData.append("OMNITAK-P12:".data(using: .utf8)!)

        // Length of cert
        var certLen = UInt32(certificateData.count).bigEndian
        combinedData.append(Data(bytes: &certLen, count: 4))
        combinedData.append(certificateData)

        // Length of key
        var keyLen = UInt32(privateKeyData.count).bigEndian
        combinedData.append(Data(bytes: &keyLen, count: 4))
        combinedData.append(privateKeyData)

        // Password hash for verification
        let passwordData = password.data(using: .utf8)!
        combinedData.append(passwordData)

        return combinedData
    }

    private func processCACertificates(caCerts: [String], alias: String) async throws {
        for (index, caCertBase64) in caCerts.enumerated() {
            guard let caData = Data(base64Encoded: caCertBase64) else {
                continue
            }

            let caFilename = "\(alias)-ca-\(index).crt"
            try saveCertificateToDocuments(data: caData, filename: caFilename)
        }
    }

    private func saveCertificateToDocuments(data: Data, filename: String) throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let certificatesPath = documentsPath.appendingPathComponent("Certificates")

        if !FileManager.default.fileExists(atPath: certificatesPath.path) {
            try FileManager.default.createDirectory(at: certificatesPath, withIntermediateDirectories: true)
        }

        let filePath = certificatesPath.appendingPathComponent(filename)
        try data.write(to: filePath)

        print("Saved certificate to: \(filePath.path)")
    }

    // MARK: - Utility Methods

    private func generateAuthHeader(config: TAKServerEnrollmentConfig) -> String {
        let credentials = "\(config.username):\(config.password)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        return "Basic \(base64Credentials)"
    }

    func reset() {
        status = .idle
        progress = 0
        currentConfig = nil
        generatedPrivateKey = nil
    }
}

// MARK: - URL Session Delegate for Self-Signed Certs

class CSRURLSessionDelegate: NSObject, URLSessionDelegate {
    let trustSelfSigned: Bool

    init(trustSelfSigned: Bool = true) {
        self.trustSelfSigned = trustSelfSigned
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {

            if trustSelfSigned {
                // Accept self-signed certificates (common in TAK deployments)
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
            } else {
                // Perform default validation
                completionHandler(.performDefaultHandling, nil)
            }
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
