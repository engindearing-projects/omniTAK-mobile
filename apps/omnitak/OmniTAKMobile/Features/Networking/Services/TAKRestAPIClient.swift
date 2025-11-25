//
//  TAKRestAPIClient.swift
//  OmniTAKMobile
//
//  TAK Server REST API client for data sync, missions, and data packages
//  Based on TAKAware's DataSyncManager and DataPackageManager patterns
//

import Foundation
import Security

// MARK: - TAK API Configuration

struct TAKAPIConfiguration {
    let serverURL: String
    let secureAPIPort: Int
    let certificateId: UUID?
    var timeout: TimeInterval = 30

    var baseURL: String {
        "https://\(serverURL):\(secureAPIPort)"
    }

    init(serverURL: String, secureAPIPort: Int = 8443, certificateId: UUID? = nil) {
        self.serverURL = serverURL
        self.secureAPIPort = secureAPIPort
        self.certificateId = certificateId
    }

    init(from server: TAKServer) {
        self.serverURL = server.host
        self.secureAPIPort = 8443  // Default TAK API port
        if let certName = server.certificateName,
           let cert = CertificateManager.shared.certificates.first(where: { $0.name == certName }) {
            self.certificateId = cert.id
        } else {
            self.certificateId = nil
        }
    }
}

// MARK: - API Response Models

struct TAKMissionInfo: Codable, Identifiable {
    let name: String
    let description: String?
    let creatorUid: String?
    let createTime: Date?
    let passwordProtected: Bool
    let groups: [String]?
    let keywords: [String]?
    let uids: [TAKMissionUID]?
    let contents: [TAKMissionContent]?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, description, creatorUid, createTime, passwordProtected, groups, keywords, uids, contents
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        creatorUid = try container.decodeIfPresent(String.self, forKey: .creatorUid)
        passwordProtected = try container.decodeIfPresent(Bool.self, forKey: .passwordProtected) ?? false
        groups = try container.decodeIfPresent([String].self, forKey: .groups)
        keywords = try container.decodeIfPresent([String].self, forKey: .keywords)
        uids = try container.decodeIfPresent([TAKMissionUID].self, forKey: .uids)
        contents = try container.decodeIfPresent([TAKMissionContent].self, forKey: .contents)

        // Handle date parsing
        if let timeString = try container.decodeIfPresent(String.self, forKey: .createTime) {
            createTime = ISO8601DateFormatter().date(from: timeString)
        } else if let timeDouble = try? container.decode(Double.self, forKey: .createTime) {
            createTime = Date(timeIntervalSince1970: timeDouble / 1000)
        } else {
            createTime = nil
        }
    }
}

struct TAKMissionUID: Codable, Identifiable {
    let data: String
    let timestamp: Date?
    let creatorUid: String?
    let details: TAKMissionUIDDetails?

    var id: String { data }

    enum CodingKeys: String, CodingKey {
        case data, timestamp, creatorUid, details
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decode(String.self, forKey: .data)
        creatorUid = try container.decodeIfPresent(String.self, forKey: .creatorUid)
        details = try container.decodeIfPresent(TAKMissionUIDDetails.self, forKey: .details)

        if let timeString = try container.decodeIfPresent(String.self, forKey: .timestamp) {
            timestamp = ISO8601DateFormatter().date(from: timeString)
        } else if let timeDouble = try? container.decode(Double.self, forKey: .timestamp) {
            timestamp = Date(timeIntervalSince1970: timeDouble / 1000)
        } else {
            timestamp = nil
        }
    }
}

struct TAKMissionUIDDetails: Codable {
    let type: String?
    let callsign: String?
    let iconsetPath: String?
    let color: Int?
    let location: TAKLocation?
}

struct TAKLocation: Codable {
    let lat: Double
    let lon: Double
    let hae: Double?
}

struct TAKMissionContent: Codable, Identifiable {
    let hash: String
    let name: String
    let mimeType: String?
    let size: Int64?
    let submitter: String?
    let submissionTime: Date?
    let keywords: [String]?

    var id: String { hash }

    enum CodingKeys: String, CodingKey {
        case hash, name, mimeType, size, submitter, submissionTime, keywords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hash = try container.decode(String.self, forKey: .hash)
        name = try container.decode(String.self, forKey: .name)
        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
        size = try container.decodeIfPresent(Int64.self, forKey: .size)
        submitter = try container.decodeIfPresent(String.self, forKey: .submitter)
        keywords = try container.decodeIfPresent([String].self, forKey: .keywords)

        if let timeString = try container.decodeIfPresent(String.self, forKey: .submissionTime) {
            submissionTime = ISO8601DateFormatter().date(from: timeString)
        } else if let timeDouble = try? container.decode(Double.self, forKey: .submissionTime) {
            submissionTime = Date(timeIntervalSince1970: timeDouble / 1000)
        } else {
            submissionTime = nil
        }
    }
}

struct TAKDataPackageInfo: Codable, Identifiable {
    let hash: String
    let name: String
    let mimeType: String
    let size: Int64
    let submitter: String?
    let submissionTime: Date?
    let creator: String?
    let expiration: Date?
    let groups: [String]?
    let keywords: [String]?

    var id: String { hash }

    enum CodingKeys: String, CodingKey {
        case hash, name, mimeType, size, submitter, submissionTime, creator, expiration, groups, keywords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hash = try container.decode(String.self, forKey: .hash)
        name = try container.decode(String.self, forKey: .name)
        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType) ?? "application/octet-stream"
        size = try container.decodeIfPresent(Int64.self, forKey: .size) ?? 0
        submitter = try container.decodeIfPresent(String.self, forKey: .submitter)
        creator = try container.decodeIfPresent(String.self, forKey: .creator)
        groups = try container.decodeIfPresent([String].self, forKey: .groups)
        keywords = try container.decodeIfPresent([String].self, forKey: .keywords)

        if let timeString = try container.decodeIfPresent(String.self, forKey: .submissionTime) {
            submissionTime = ISO8601DateFormatter().date(from: timeString)
        } else if let timeDouble = try? container.decode(Double.self, forKey: .submissionTime) {
            submissionTime = Date(timeIntervalSince1970: timeDouble / 1000)
        } else {
            submissionTime = nil
        }

        if let timeString = try container.decodeIfPresent(String.self, forKey: .expiration) {
            expiration = ISO8601DateFormatter().date(from: timeString)
        } else if let timeDouble = try? container.decode(Double.self, forKey: .expiration) {
            expiration = Date(timeIntervalSince1970: timeDouble / 1000)
        } else {
            expiration = nil
        }
    }
}

// MARK: - API Errors

enum TAKAPIError: LocalizedError {
    case invalidConfiguration
    case certificateNotFound
    case connectionFailed(String)
    case authenticationRequired
    case forbidden
    case notFound(String)
    case serverError(Int, String?)
    case invalidResponse(String)
    case decodingFailed(String)
    case downloadFailed(String)
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Invalid API configuration"
        case .certificateNotFound:
            return "Client certificate not found"
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .authenticationRequired:
            return "Authentication required"
        case .forbidden:
            return "Access forbidden"
        case .notFound(let resource):
            return "Resource not found: \(resource)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Unknown")"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        case .decodingFailed(let message):
            return "Failed to decode response: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        }
    }
}

// MARK: - TAK REST API Client

@MainActor
class TAKRestAPIClient: ObservableObject {
    static let shared = TAKRestAPIClient()

    @Published var isConnected: Bool = false
    @Published var lastError: String?

    private var urlSession: URLSession?
    private var configuration: TAKAPIConfiguration?

    init() {}

    // MARK: - Configuration

    func configure(with config: TAKAPIConfiguration) {
        self.configuration = config

        // Create URL session with client certificate
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.timeout
        sessionConfig.timeoutIntervalForResource = config.timeout * 4

        let delegate = TAKAPIURLSessionDelegate(certificateId: config.certificateId)
        urlSession = URLSession(configuration: sessionConfig, delegate: delegate, delegateQueue: nil)

        isConnected = true
        lastError = nil
    }

    func configure(from server: TAKServer) {
        let config = TAKAPIConfiguration(from: server)
        configure(with: config)
    }

    func disconnect() {
        urlSession?.invalidateAndCancel()
        urlSession = nil
        configuration = nil
        isConnected = false
    }

    // MARK: - Missions API

    /// Retrieve list of available missions
    func getMissions() async throws -> [TAKMissionInfo] {
        let data = try await get(endpoint: "/Marti/api/missions")
        return try decodeMissionsResponse(data)
    }

    /// Get detailed mission info
    func getMission(name: String, password: String? = nil) async throws -> TAKMissionInfo {
        var endpoint = "/Marti/api/missions/\(name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name)"
        if let password = password {
            endpoint += "?password=\(password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? password)"
        }

        let data = try await get(endpoint: endpoint)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // TAK API wraps response in "data" array
        if let response = try? decoder.decode(TAKAPIResponse<[TAKMissionInfo]>.self, from: data),
           let mission = response.data?.first {
            return mission
        }

        // Try direct decode
        if let mission = try? decoder.decode(TAKMissionInfo.self, from: data) {
            return mission
        }

        throw TAKAPIError.decodingFailed("Cannot decode mission response")
    }

    /// Subscribe to a mission
    func subscribeMission(name: String, uid: String, password: String? = nil) async throws {
        var endpoint = "/Marti/api/missions/\(name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name)/subscription"
        endpoint += "?uid=\(uid)"
        if let password = password {
            endpoint += "&password=\(password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? password)"
        }

        _ = try await put(endpoint: endpoint, body: nil)
    }

    /// Unsubscribe from a mission
    func unsubscribeMission(name: String, uid: String) async throws {
        let endpoint = "/Marti/api/missions/\(name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name)/subscription?uid=\(uid)"
        _ = try await delete(endpoint: endpoint)
    }

    /// Get mission CoT content
    func getMissionContent(name: String, password: String? = nil) async throws -> String {
        var endpoint = "/Marti/api/missions/\(name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name)/cot"
        if let password = password {
            endpoint += "?password=\(password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? password)"
        }

        let data = try await get(endpoint: endpoint)
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Data Packages API

    /// Retrieve list of available data packages
    func getDataPackages() async throws -> [TAKDataPackageInfo] {
        let data = try await get(endpoint: "/Marti/api/sync/search")
        return try decodeDataPackagesResponse(data)
    }

    /// Download a data package by hash
    func downloadDataPackage(hash: String, progressHandler: ((Double) -> Void)? = nil) async throws -> URL {
        guard let config = configuration else {
            throw TAKAPIError.invalidConfiguration
        }

        let endpoint = "/Marti/sync/content?hash=\(hash)"
        let urlString = config.baseURL + endpoint

        guard let url = URL(string: urlString) else {
            throw TAKAPIError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        guard let session = urlSession else {
            throw TAKAPIError.invalidConfiguration
        }

        let (localURL, response) = try await session.download(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TAKAPIError.invalidResponse("Not an HTTP response")
        }

        try handleHTTPResponse(httpResponse)

        // Move to permanent location
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let packagesPath = documentsPath.appendingPathComponent("DataPackages")

        if !FileManager.default.fileExists(atPath: packagesPath.path) {
            try FileManager.default.createDirectory(at: packagesPath, withIntermediateDirectories: true)
        }

        let destinationURL = packagesPath.appendingPathComponent("\(hash).zip")

        // Remove existing file if present
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.moveItem(at: localURL, to: destinationURL)

        return destinationURL
    }

    /// Upload a data package
    func uploadDataPackage(fileURL: URL, name: String, creatorUid: String) async throws {
        guard let config = configuration else {
            throw TAKAPIError.invalidConfiguration
        }

        let endpoint = "/Marti/sync/missionupload?creatorUid=\(creatorUid)&name=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)"
        let urlString = config.baseURL + endpoint

        guard let url = URL(string: urlString) else {
            throw TAKAPIError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: fileURL)
        var body = Data()

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"assetfile\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/x-zip-compressed\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        guard let session = urlSession else {
            throw TAKAPIError.invalidConfiguration
        }

        let (_, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TAKAPIError.invalidResponse("Not an HTTP response")
        }

        try handleHTTPResponse(httpResponse)
    }

    /// Download content by hash (for mission attachments)
    func downloadContent(hash: String) async throws -> Data {
        return try await get(endpoint: "/Marti/sync/content?hash=\(hash)")
    }

    // MARK: - Server Info API

    /// Get server version info
    func getServerVersion() async throws -> String {
        let data = try await get(endpoint: "/Marti/api/version")
        return String(data: data, encoding: .utf8) ?? "Unknown"
    }

    /// Get server config
    func getServerConfig() async throws -> Data {
        return try await get(endpoint: "/Marti/api/config")
    }

    // MARK: - HTTP Methods

    private func get(endpoint: String) async throws -> Data {
        guard let config = configuration else {
            throw TAKAPIError.invalidConfiguration
        }

        let urlString = config.baseURL + endpoint
        guard let url = URL(string: urlString) else {
            throw TAKAPIError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        return try await performRequest(request)
    }

    private func put(endpoint: String, body: Data?) async throws -> Data {
        guard let config = configuration else {
            throw TAKAPIError.invalidConfiguration
        }

        let urlString = config.baseURL + endpoint
        guard let url = URL(string: urlString) else {
            throw TAKAPIError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        return try await performRequest(request)
    }

    private func post(endpoint: String, body: Data?) async throws -> Data {
        guard let config = configuration else {
            throw TAKAPIError.invalidConfiguration
        }

        let urlString = config.baseURL + endpoint
        guard let url = URL(string: urlString) else {
            throw TAKAPIError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        return try await performRequest(request)
    }

    private func delete(endpoint: String) async throws -> Data {
        guard let config = configuration else {
            throw TAKAPIError.invalidConfiguration
        }

        let urlString = config.baseURL + endpoint
        guard let url = URL(string: urlString) else {
            throw TAKAPIError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        return try await performRequest(request)
    }

    private func performRequest(_ request: URLRequest) async throws -> Data {
        guard let session = urlSession else {
            throw TAKAPIError.invalidConfiguration
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TAKAPIError.invalidResponse("Not an HTTP response")
            }

            try handleHTTPResponse(httpResponse)

            return data
        } catch let error as TAKAPIError {
            lastError = error.errorDescription
            throw error
        } catch {
            lastError = error.localizedDescription
            throw TAKAPIError.connectionFailed(error.localizedDescription)
        }
    }

    private func handleHTTPResponse(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 401:
            throw TAKAPIError.authenticationRequired
        case 403:
            throw TAKAPIError.forbidden
        case 404:
            throw TAKAPIError.notFound("Resource")
        default:
            throw TAKAPIError.serverError(response.statusCode, nil)
        }
    }

    // MARK: - Response Decoding

    private func decodeMissionsResponse(_ data: Data) throws -> [TAKMissionInfo] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // TAK API wraps response
        if let response = try? decoder.decode(TAKAPIResponse<[TAKMissionInfo]>.self, from: data),
           let missions = response.data {
            return missions
        }

        // Try direct array decode
        if let missions = try? decoder.decode([TAKMissionInfo].self, from: data) {
            return missions
        }

        throw TAKAPIError.decodingFailed("Cannot decode missions response")
    }

    private func decodeDataPackagesResponse(_ data: Data) throws -> [TAKDataPackageInfo] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // TAK API wraps response
        if let response = try? decoder.decode(TAKAPIResponse<[TAKDataPackageInfo]>.self, from: data),
           let packages = response.data {
            return packages
        }

        // Try "results" key
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let results = json["results"] as? [[String: Any]] {
            let resultsData = try JSONSerialization.data(withJSONObject: results)
            return try decoder.decode([TAKDataPackageInfo].self, from: resultsData)
        }

        // Try direct array decode
        if let packages = try? decoder.decode([TAKDataPackageInfo].self, from: data) {
            return packages
        }

        throw TAKAPIError.decodingFailed("Cannot decode data packages response")
    }
}

// MARK: - API Response Wrapper

struct TAKAPIResponse<T: Codable>: Codable {
    let version: String?
    let type: String?
    let data: T?
    let messages: [String]?
    let nodeId: String?
}

// MARK: - URL Session Delegate

class TAKAPIURLSessionDelegate: NSObject, URLSessionDelegate {
    let certificateId: UUID?

    init(certificateId: UUID?) {
        self.certificateId = certificateId
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            // Accept self-signed certificates (common in TAK deployments)
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            // Provide client certificate
            if let certId = certificateId {
                do {
                    let identity = try CertificateManager.shared.getIdentity(for: certId)
                    let credential = URLCredential(
                        identity: identity,
                        certificates: nil,
                        persistence: .forSession
                    )
                    completionHandler(.useCredential, credential)
                } catch {
                    print("Failed to load client certificate: \(error)")
                    completionHandler(.performDefaultHandling, nil)
                }
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
