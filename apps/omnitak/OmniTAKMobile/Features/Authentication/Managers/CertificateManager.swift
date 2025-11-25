//
//  CertificateManager.swift
//  OmniTAKMobile
//
//  Certificate storage and management using iOS Keychain
//  Handles .p12 certificates, client authentication, and secure storage
//

import Foundation
import Security

// MARK: - Certificate Models

struct TAKCertificate: Codable, Identifiable {
    let id: UUID
    let name: String
    let serverURL: String
    let username: String
    let createdDate: Date
    let expiryDate: Date?
    let issuer: String?
    let isValid: Bool

    var displayName: String {
        "\(name) (\(username))"
    }

    var isExpired: Bool {
        guard let expiry = expiryDate else { return false }
        return expiry < Date()
    }
}

struct CertificateEnrollmentRequest {
    let serverURL: String
    let username: String
    let password: String
    let deviceID: String
}

struct CertificateEnrollmentResponse: Codable {
    let certificate: Data  // .p12 certificate data
    let password: String   // Certificate password
    let serverHost: String
    let serverPort: Int
    let serverProtocol: String
    let caCertificate: Data?  // Optional CA certificate
}

// MARK: - Certificate Manager

class CertificateManager: ObservableObject {

    static let shared = CertificateManager()

    @Published var certificates: [TAKCertificate] = []
    @Published var isLoading = false
    @Published var error: String?

    private let keychainService = "com.omnitak.mobile.certificates"
    private let certificatesKey = "tak_certificates_list"

    private init() {
        loadCertificates()
    }

    // MARK: - Certificate Storage

    /// Save certificate to Keychain
    func saveCertificate(
        name: String,
        serverURL: String,
        username: String,
        p12Data: Data,
        password: String
    ) throws {

        // Validate P12 certificate
        guard let identity = try? extractIdentity(from: p12Data, password: password) else {
            throw CertificateError.invalidCertificate
        }

        let certificateID = UUID()

        // Extract certificate details
        var certificate: SecCertificate?
        SecIdentityCopyCertificate(identity, &certificate)

        var expiry: Date?
        var issuer: String?

        if let cert = certificate {
            expiry = getCertificateExpiry(cert)
            issuer = getCertificateIssuer(cert)
        }

        // Store P12 data in Keychain
        let p12Key = "cert_p12_\(certificateID.uuidString)"
        try saveToKeychain(key: p12Key, data: p12Data)

        // Store password in Keychain
        let passwordKey = "cert_password_\(certificateID.uuidString)"
        try saveToKeychain(key: passwordKey, data: password.data(using: .utf8)!)

        // Create certificate record
        let takCert = TAKCertificate(
            id: certificateID,
            name: name,
            serverURL: serverURL,
            username: username,
            createdDate: Date(),
            expiryDate: expiry,
            issuer: issuer,
            isValid: true
        )

        certificates.append(takCert)
        saveCertificatesList()

        print("✅ Certificate saved: \(name) for \(username)")
    }

    /// Load certificate from Keychain
    func loadCertificate(id: UUID) throws -> (p12Data: Data, password: String) {
        let p12Key = "cert_p12_\(id.uuidString)"
        let passwordKey = "cert_password_\(id.uuidString)"

        guard let p12Data = loadFromKeychain(key: p12Key),
              let passwordData = loadFromKeychain(key: passwordKey),
              let password = String(data: passwordData, encoding: .utf8) else {
            throw CertificateError.certificateNotFound
        }

        return (p12Data, password)
    }

    /// Delete certificate from Keychain
    func deleteCertificate(id: UUID) {
        let p12Key = "cert_p12_\(id.uuidString)"
        let passwordKey = "cert_password_\(id.uuidString)"

        deleteFromKeychain(key: p12Key)
        deleteFromKeychain(key: passwordKey)

        certificates.removeAll { $0.id == id }
        saveCertificatesList()

        print("🗑️ Certificate deleted: \(id)")
    }

    /// Get SecIdentity for authentication
    func getIdentity(for certificateID: UUID) throws -> SecIdentity {
        let (p12Data, password) = try loadCertificate(id: certificateID)

        guard let identity = try? extractIdentity(from: p12Data, password: password) else {
            throw CertificateError.invalidCertificate
        }

        return identity
    }

    // MARK: - Keychain Operations

    private func saveToKeychain(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw CertificateError.keychainError("Failed to save: \(status)")
        }
    }

    private func loadFromKeychain(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }

        return result as? Data
    }

    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Certificate List Persistence

    /// Reload certificates from storage - called after external changes
    func loadCertificates() {
        if let data = UserDefaults.standard.data(forKey: certificatesKey),
           let decoded = try? JSONDecoder().decode([TAKCertificate].self, from: data) {
            certificates = decoded
        }
    }

    private func saveCertificatesList() {
        if let encoded = try? JSONEncoder().encode(certificates) {
            UserDefaults.standard.set(encoded, forKey: certificatesKey)
        }
    }

    // MARK: - Certificate Parsing

    private func extractIdentity(from p12Data: Data, password: String) throws -> SecIdentity? {
        let options: [String: Any] = [
            kSecImportExportPassphrase as String: password
        ]

        var items: CFArray?
        let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &items)

        guard status == errSecSuccess,
              let itemsArray = items as? [[String: Any]],
              let firstItem = itemsArray.first,
              let identity = firstItem[kSecImportItemIdentity as String] as! SecIdentity? else {
            return nil
        }

        return identity
    }

    private func getCertificateExpiry(_ certificate: SecCertificate) -> Date? {
        // On iOS, we need to parse the certificate data directly using DER/ASN.1 parsing
        guard let data = SecCertificateCopyData(certificate) as Data? else {
            return nil
        }

        // Parse DER-encoded certificate to extract notAfter date
        // X.509 structure: Certificate -> TBSCertificate -> Validity -> notAfter

        var offset = 0

        // Skip the outer SEQUENCE tag and length
        guard data.count > offset, data[offset] == 0x30 else { return nil }
        offset += 1
        let (_, lengthSize) = parseDERLength(data, offset: offset)
        offset += lengthSize

        // Skip the inner TBSCertificate SEQUENCE tag and length
        guard data.count > offset, data[offset] == 0x30 else { return nil }
        offset += 1
        let (_, tbsLengthSize) = parseDERLength(data, offset: offset)
        offset += tbsLengthSize

        // Skip version (optional, tagged [0])
        if data.count > offset && data[offset] == 0xA0 {
            offset += 1
            let (versionLength, versionLengthSize) = parseDERLength(data, offset: offset)
            offset += versionLengthSize + versionLength
        }

        // Skip serial number (INTEGER)
        if data.count > offset && data[offset] == 0x02 {
            offset += 1
            let (serialLength, serialLengthSize) = parseDERLength(data, offset: offset)
            offset += serialLengthSize + serialLength
        }

        // Skip signature algorithm (SEQUENCE)
        if data.count > offset && data[offset] == 0x30 {
            offset += 1
            let (sigLength, sigLengthSize) = parseDERLength(data, offset: offset)
            offset += sigLengthSize + sigLength
        }

        // Skip issuer (SEQUENCE)
        if data.count > offset && data[offset] == 0x30 {
            offset += 1
            let (issuerLength, issuerLengthSize) = parseDERLength(data, offset: offset)
            offset += issuerLengthSize + issuerLength
        }

        // Now we should be at Validity (SEQUENCE)
        guard data.count > offset && data[offset] == 0x30 else { return nil }
        offset += 1
        let (_, validityLengthSize) = parseDERLength(data, offset: offset)
        offset += validityLengthSize

        // Skip notBefore (UTCTime 0x17 or GeneralizedTime 0x18)
        if data.count > offset && (data[offset] == 0x17 || data[offset] == 0x18) {
            let _ = data[offset]
            offset += 1
            let (notBeforeLength, notBeforeLengthSize) = parseDERLength(data, offset: offset)
            offset += notBeforeLengthSize + notBeforeLength

            // Now we're at notAfter
            guard data.count > offset && (data[offset] == 0x17 || data[offset] == 0x18) else {
                return nil
            }
            let notAfterType = data[offset]
            offset += 1
            let (notAfterLength, notAfterLengthSize) = parseDERLength(data, offset: offset)
            offset += notAfterLengthSize

            // Extract the date string
            guard offset + notAfterLength <= data.count else { return nil }
            let dateData = data[offset..<(offset + notAfterLength)]
            guard let dateString = String(data: dateData, encoding: .ascii) else { return nil }

            // Parse the date string
            return parseASN1Date(dateString, type: notAfterType)
        }

        return nil
    }

    private func parseDERLength(_ data: Data, offset: Int) -> (length: Int, size: Int) {
        guard offset < data.count else { return (0, 0) }

        let firstByte = data[offset]

        if firstByte & 0x80 == 0 {
            // Short form: length is in the first byte
            return (Int(firstByte), 1)
        } else {
            // Long form: first byte tells us how many bytes encode the length
            let numLengthBytes = Int(firstByte & 0x7F)
            guard offset + numLengthBytes < data.count else { return (0, 0) }

            var length = 0
            for i in 1...numLengthBytes {
                length = (length << 8) | Int(data[offset + i])
            }
            return (length, numLengthBytes + 1)
        }
    }

    private func parseASN1Date(_ dateString: String, type: UInt8) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        if type == 0x17 {
            // UTCTime: YYMMDDhhmmssZ or YYMMDDhhmmss+hhmm
            if dateString.hasSuffix("Z") {
                formatter.dateFormat = "yyMMddHHmmss'Z'"
            } else {
                formatter.dateFormat = "yyMMddHHmmssZ"
            }
        } else if type == 0x18 {
            // GeneralizedTime: YYYYMMDDhhmmssZ
            if dateString.hasSuffix("Z") {
                formatter.dateFormat = "yyyyMMddHHmmss'Z'"
            } else {
                formatter.dateFormat = "yyyyMMddHHmmssZ"
            }
        }

        return formatter.date(from: dateString)
    }

    private func getCertificateIssuer(_ certificate: SecCertificate) -> String? {
        // Use the subject summary as the issuer name
        // This is the most reliable iOS-compatible method
        return SecCertificateCopySubjectSummary(certificate) as String?
    }

    // MARK: - Import from File

    func importCertificate(from url: URL, password: String, name: String, serverURL: String, username: String) throws {
        guard url.startAccessingSecurityScopedResource() else {
            throw CertificateError.fileAccessDenied
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        let data = try Data(contentsOf: url)

        try saveCertificate(
            name: name,
            serverURL: serverURL,
            username: username,
            p12Data: data,
            password: password
        )
    }
}

// MARK: - Errors

enum CertificateError: Error, LocalizedError {
    case invalidCertificate
    case certificateNotFound
    case certificateExpired
    case keychainError(String)
    case fileAccessDenied
    case networkError(String)
    case authenticationFailed
    case invalidServerResponse

    var errorDescription: String? {
        switch self {
        case .invalidCertificate:
            return "Invalid or corrupted certificate"
        case .certificateNotFound:
            return "Certificate not found in storage"
        case .certificateExpired:
            return "Certificate has expired"
        case .keychainError(let message):
            return "Keychain error: \(message)"
        case .fileAccessDenied:
            return "Unable to access certificate file"
        case .networkError(let message):
            return "Network error: \(message)"
        case .authenticationFailed:
            return "Authentication failed - check username and password"
        case .invalidServerResponse:
            return "Invalid response from server"
        }
    }
}
