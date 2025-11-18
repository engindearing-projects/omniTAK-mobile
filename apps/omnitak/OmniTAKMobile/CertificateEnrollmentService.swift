//
//  CertificateEnrollmentService.swift
//  OmniTAKMobile
//
//  TAK Server certificate enrollment service
//  Handles QR code parsing, certificate download, and keychain storage
//

import Foundation
import Security
import Combine

// MARK: - Enrollment URL Model

struct TAKEnrollmentURL: Codable {
    let server: String
    let port: Int
    let truststoreURL: String
    let usercertURL: String

    init?(from urlString: String) {
        guard let url = URL(string: urlString),
              url.scheme == "tak",
              url.host == "enroll",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }

        var serverHost: String?
        var serverPort: Int = 8443
        var truststore: String?
        var usercert: String?

        for item in queryItems {
            switch item.name {
            case "server":
                serverHost = item.value
            case "port":
                if let value = item.value, let portNum = Int(value) {
                    serverPort = portNum
                }
            case "truststore":
                truststore = item.value
            case "usercert":
                usercert = item.value
            default:
                break
            }
        }

        guard let host = serverHost,
              let truststoreStr = truststore,
              let usercertStr = usercert else {
            return nil
        }

        self.server = host
        self.port = serverPort
        self.truststoreURL = truststoreStr
        self.usercertURL = usercertStr
    }
}

// MARK: - Certificate Metadata

struct CertificateMetadata: Codable, Identifiable {
    let id: UUID
    let serverHost: String
    let serverPort: Int
    let certificateAlias: String
    let enrollmentDate: Date
    let expirationDate: Date?
    let subjectName: String?
    let issuerName: String?

    init(id: UUID = UUID(), serverHost: String, serverPort: Int, certificateAlias: String, enrollmentDate: Date = Date(), expirationDate: Date? = nil, subjectName: String? = nil, issuerName: String? = nil) {
        self.id = id
        self.serverHost = serverHost
        self.serverPort = serverPort
        self.certificateAlias = certificateAlias
        self.enrollmentDate = enrollmentDate
        self.expirationDate = expirationDate
        self.subjectName = subjectName
        self.issuerName = issuerName
    }
}

// MARK: - Enrollment Error Types

enum EnrollmentError: LocalizedError {
    case invalidURL
    case networkError(String)
    case certificateDownloadFailed(String)
    case keychainImportFailed(String)
    case invalidCertificateFormat
    case passwordRequired
    case serverCreationFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid enrollment URL format"
        case .networkError(let message):
            return "Network error: \(message)"
        case .certificateDownloadFailed(let message):
            return "Failed to download certificate: \(message)"
        case .keychainImportFailed(let message):
            return "Failed to import certificate: \(message)"
        case .invalidCertificateFormat:
            return "Invalid certificate format"
        case .passwordRequired:
            return "Certificate password is required"
        case .serverCreationFailed:
            return "Failed to create server configuration"
        }
    }
}

// MARK: - Enrollment Progress

enum EnrollmentProgress: Equatable {
    case idle
    case parsingURL
    case downloadingTrustStore
    case downloadingUserCert
    case importingCertificates
    case creatingServerConfig
    case completed
    case failed(String)

    var description: String {
        switch self {
        case .idle:
            return "Ready to enroll"
        case .parsingURL:
            return "Parsing enrollment URL..."
        case .downloadingTrustStore:
            return "Downloading trust store..."
        case .downloadingUserCert:
            return "Downloading user certificate..."
        case .importingCertificates:
            return "Importing certificates..."
        case .creatingServerConfig:
            return "Creating server configuration..."
        case .completed:
            return "Enrollment completed successfully"
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

// MARK: - Certificate Enrollment Service

class CertificateEnrollmentService: ObservableObject {
    static let shared = CertificateEnrollmentService()

    @Published var progress: EnrollmentProgress = .idle
    @Published var enrolledCertificates: [CertificateMetadata] = []

    private let certificatesKey = "enrolled_certificates"
    private let urlSession: URLSession

    init() {
        // Configure URLSession to accept self-signed certificates (common in TAK)
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.urlSession = URLSession(configuration: configuration, delegate: SelfSignedCertificateDelegate(), delegateQueue: nil)

        loadCertificateMetadata()
    }

    // MARK: - Persistence

    private func loadCertificateMetadata() {
        if let data = UserDefaults.standard.data(forKey: certificatesKey),
           let decoded = try? JSONDecoder().decode([CertificateMetadata].self, from: data) {
            enrolledCertificates = decoded
        }
    }

    private func saveCertificateMetadata() {
        if let encoded = try? JSONEncoder().encode(enrolledCertificates) {
            UserDefaults.standard.set(encoded, forKey: certificatesKey)
        }
    }

    // MARK: - Main Enrollment Flow

    func enrollFromQRCode(_ qrContent: String, password: String) async throws -> TAKServer {
        await MainActor.run { progress = .parsingURL }

        guard let enrollmentURL = TAKEnrollmentURL(from: qrContent) else {
            await MainActor.run { progress = .failed("Invalid QR code format") }
            throw EnrollmentError.invalidURL
        }

        return try await performEnrollment(enrollmentURL: enrollmentURL, password: password)
    }

    func enrollFromManualEntry(server: String, port: Int, truststoreURL: String, usercertURL: String, password: String) async throws -> TAKServer {
        await MainActor.run { progress = .parsingURL }

        let enrollmentURL = TAKEnrollmentURL(
            server: server,
            port: port,
            truststoreURL: truststoreURL,
            usercertURL: usercertURL
        )

        return try await performEnrollment(enrollmentURL: enrollmentURL, password: password)
    }

    private func performEnrollment(enrollmentURL: TAKEnrollmentURL, password: String) async throws -> TAKServer {
        guard !password.isEmpty else {
            await MainActor.run { progress = .failed("Password required") }
            throw EnrollmentError.passwordRequired
        }

        // Download trust store
        await MainActor.run { progress = .downloadingTrustStore }
        let trustStoreData = try await downloadCertificate(from: enrollmentURL.truststoreURL)

        // Download user certificate
        await MainActor.run { progress = .downloadingUserCert }
        let userCertData = try await downloadCertificate(from: enrollmentURL.usercertURL)

        // Import certificates into keychain
        await MainActor.run { progress = .importingCertificates }
        let certificateAlias = try importCertificates(
            trustStoreData: trustStoreData,
            userCertData: userCertData,
            password: password,
            serverHost: enrollmentURL.server
        )

        // Create server configuration
        await MainActor.run { progress = .creatingServerConfig }
        let server = try createServerConfiguration(
            enrollmentURL: enrollmentURL,
            certificateAlias: certificateAlias,
            password: password
        )

        // Save certificate metadata
        let metadata = CertificateMetadata(
            serverHost: enrollmentURL.server,
            serverPort: enrollmentURL.port,
            certificateAlias: certificateAlias
        )
        await MainActor.run {
            enrolledCertificates.append(metadata)
            saveCertificateMetadata()
            progress = .completed
        }

        print("Certificate enrollment completed for \(enrollmentURL.server)")
        return server
    }

    // MARK: - Certificate Download

    private func downloadCertificate(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw EnrollmentError.certificateDownloadFailed("Invalid URL")
        }

        do {
            let (data, response) = try await urlSession.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw EnrollmentError.certificateDownloadFailed("Invalid response")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw EnrollmentError.certificateDownloadFailed("HTTP \(httpResponse.statusCode)")
            }

            return data
        } catch let error as EnrollmentError {
            throw error
        } catch {
            throw EnrollmentError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Certificate Import

    private func importCertificates(trustStoreData: Data, userCertData: Data, password: String, serverHost: String) throws -> String {
        let certificateAlias = "tak-\(serverHost)-\(UUID().uuidString.prefix(8))"

        // Use CertificateManager to save the user certificate
        try CertificateManager.shared.saveCertificate(
            name: certificateAlias,
            serverURL: "https://\(serverHost)",
            username: "enrolled-user",
            p12Data: userCertData,
            password: password
        )

        // Also save trust store using old method (for CA certificate chain)
        try importP12Certificate(data: trustStoreData, password: password, alias: "\(certificateAlias)-ca")

        // Save certificate files to app documents for backward compatibility with TAKService
        try saveCertificateToDocuments(data: userCertData, filename: "\(certificateAlias).p12")
        try saveCertificateToDocuments(data: trustStoreData, filename: "\(certificateAlias)-ca.p12")

        return certificateAlias
    }

    private func importP12Certificate(data: Data, password: String, alias: String) throws {
        let options: [String: Any] = [
            kSecImportExportPassphrase as String: password
        ]

        var items: CFArray?
        let status = SecPKCS12Import(data as CFData, options as CFDictionary, &items)

        guard status == errSecSuccess else {
            let errorMessage = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown error"
            throw EnrollmentError.keychainImportFailed(errorMessage)
        }

        guard let itemArray = items as? [[String: Any]],
              let firstItem = itemArray.first else {
            throw EnrollmentError.invalidCertificateFormat
        }

        // Extract identity (private key + certificate)
        if let identity = firstItem[kSecImportItemIdentity as String] {
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassIdentity,
                kSecValueRef as String: identity,
                kSecAttrLabel as String: alias,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            ]

            // Delete existing if present
            SecItemDelete(addQuery as CFDictionary)

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus != errSecSuccess && addStatus != errSecDuplicateItem {
                let errorMessage = SecCopyErrorMessageString(addStatus, nil) as String? ?? "Unknown error"
                throw EnrollmentError.keychainImportFailed(errorMessage)
            }
        }

        // Extract and store trust chain
        if let trustChain = firstItem[kSecImportItemCertChain as String] as? [SecCertificate] {
            for (index, certificate) in trustChain.enumerated() {
                let certQuery: [String: Any] = [
                    kSecClass as String: kSecClassCertificate,
                    kSecValueRef as String: certificate,
                    kSecAttrLabel as String: "\(alias)-chain-\(index)",
                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
                ]

                SecItemDelete(certQuery as CFDictionary)
                SecItemAdd(certQuery as CFDictionary, nil)
            }
        }

        print("Imported certificate with alias: \(alias)")
    }

    private func saveCertificateToDocuments(data: Data, filename: String) throws {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let certificatesPath = documentsPath.appendingPathComponent("Certificates")

        // Create certificates directory if needed
        if !FileManager.default.fileExists(atPath: certificatesPath.path) {
            try FileManager.default.createDirectory(at: certificatesPath, withIntermediateDirectories: true)
        }

        let filePath = certificatesPath.appendingPathComponent(filename)
        try data.write(to: filePath)

        print("Saved certificate to: \(filePath.path)")
    }

    // MARK: - Server Configuration

    private func createServerConfiguration(enrollmentURL: TAKEnrollmentURL, certificateAlias: String, password: String) throws -> TAKServer {
        let server = TAKServer(
            name: "TAK Server (\(enrollmentURL.server))",
            host: enrollmentURL.server,
            port: UInt16(enrollmentURL.port),
            protocolType: "ssl",
            useTLS: true,
            isDefault: false,
            certificateName: certificateAlias,
            certificatePassword: password
        )

        // Add to ServerManager
        ServerManager.shared.addServer(server)

        return server
    }

    // MARK: - Certificate Management

    func removeCertificate(_ metadata: CertificateMetadata) {
        // Find matching certificate in CertificateManager by server URL
        if let cert = CertificateManager.shared.certificates.first(where: {
            $0.serverURL.contains(metadata.serverHost)
        }) {
            CertificateManager.shared.deleteCertificate(id: cert.id)
        }

        // Remove from keychain (legacy cleanup)
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: metadata.certificateAlias
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // Remove CA certificate
        let caDeleteQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: "\(metadata.certificateAlias)-ca"
        ]
        SecItemDelete(caDeleteQuery as CFDictionary)

        // Remove from documents
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let certificatesPath = documentsPath.appendingPathComponent("Certificates")

        let userCertPath = certificatesPath.appendingPathComponent("\(metadata.certificateAlias).p12")
        let caCertPath = certificatesPath.appendingPathComponent("\(metadata.certificateAlias)-ca.p12")

        try? FileManager.default.removeItem(at: userCertPath)
        try? FileManager.default.removeItem(at: caCertPath)

        // Remove from metadata list
        enrolledCertificates.removeAll { $0.id == metadata.id }
        saveCertificateMetadata()

        print("Removed certificate: \(metadata.certificateAlias)")
    }

    func reset() {
        progress = .idle
    }
}

// MARK: - Fileprivate TAKEnrollmentURL initializer for manual entry

fileprivate extension TAKEnrollmentURL {
    init(server: String, port: Int, truststoreURL: String, usercertURL: String) {
        self.server = server
        self.port = port
        self.truststoreURL = truststoreURL
        self.usercertURL = usercertURL
    }
}

// MARK: - Self-Signed Certificate Delegate

class SelfSignedCertificateDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Accept self-signed certificates (common in TAK deployments)
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
