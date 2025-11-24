//
//  ArcGISPortalService.swift
//  OmniTAKMobile
//
//  Service for connecting to ArcGIS Portal/Online and managing authentication
//

import Foundation
import Combine

@MainActor
class ArcGISPortalService: ObservableObject {
    static let shared = ArcGISPortalService()

    // Published state
    @Published var isAuthenticated: Bool = false
    @Published var credentials: ArcGISCredentials?
    @Published var portalItems: [ArcGISPortalItem] = []
    @Published var isLoading: Bool = false
    @Published var lastError: String = ""
    @Published var searchQuery: String = ""
    @Published var selectedItemType: ArcGISItemType?
    @Published var currentPage: Int = 1
    @Published var totalResults: Int = 0
    @Published var hasMoreResults: Bool = false

    // Configuration
    private let userDefaultsKey = "com.omnitak.arcgis.credentials"
    private let pageSize: Int = 25
    private var cancellables = Set<AnyCancellable>()
    private let session: URLSession

    // Default portal URLs
    nonisolated static let arcGISOnlineURL = "https://www.arcgis.com"
    nonisolated static let arcGISOnlineSharingURL = "https://www.arcgis.com/sharing/rest"

    private init() {
        // Configure URL session with timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)

        loadCredentials()
    }

    // MARK: - Authentication

    /// Generate authentication token using username/password
    func authenticate(
        portalURL: String = arcGISOnlineURL,
        username: String,
        password: String
    ) async throws {
        isLoading = true
        lastError = ""

        defer { DispatchQueue.main.async { self.isLoading = false } }

        // Build token generation URL
        let tokenURL = "\(portalURL)/sharing/rest/generateToken"

        guard let url = URL(string: tokenURL) else {
            throw ArcGISError.networkError("Invalid portal URL")
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Build form data
        let referer = "OmniTAK-iOS"
        let expiration = 60 * 24 * 7 // 7 days in minutes
        let params = [
            "username": username,
            "password": password,
            "referer": referer,
            "expiration": String(expiration),
            "f": "json"
        ]

        let bodyString = params.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
        }.joined(separator: "&")

        request.httpBody = bodyString.data(using: .utf8)

        // Execute request
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ArcGISError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            throw ArcGISError.networkError("HTTP \(httpResponse.statusCode)")
        }

        // Parse response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let error = json?["error"] as? [String: Any] {
            let _ = error["message"] as? String ?? "Unknown error"
            throw ArcGISError.invalidCredentials
        }

        guard let token = json?["token"] as? String,
              let expiresMs = json?["expires"] as? Int64 else {
            throw ArcGISError.parseError("Missing token in response")
        }

        let expirationDate = Date(timeIntervalSince1970: Double(expiresMs) / 1000.0)

        // Create and store credentials
        let newCredentials = ArcGISCredentials(
            portalURL: portalURL,
            username: username,
            token: token,
            tokenExpiration: expirationDate,
            referer: referer
        )

        DispatchQueue.main.async {
            self.credentials = newCredentials
            self.isAuthenticated = true
            self.saveCredentials()
        }

        print("ArcGIS Portal: Authenticated as \(username)")
    }

    /// Authenticate with existing token
    func authenticateWithToken(
        portalURL: String = arcGISOnlineURL,
        token: String,
        username: String = "token_user",
        expiration: Date = Date().addingTimeInterval(3600)
    ) {
        let newCredentials = ArcGISCredentials(
            portalURL: portalURL,
            username: username,
            token: token,
            tokenExpiration: expiration,
            referer: "OmniTAK-iOS"
        )

        credentials = newCredentials
        isAuthenticated = true
        saveCredentials()

        print("ArcGIS Portal: Authenticated with token")
    }

    /// Sign out and clear credentials
    func signOut() {
        credentials = nil
        isAuthenticated = false
        portalItems = []
        searchQuery = ""
        currentPage = 1
        totalResults = 0
        hasMoreResults = false

        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        print("ArcGIS Portal: Signed out")
    }

    // MARK: - Portal Content Search

    /// Search for portal items
    func searchContent(
        query: String = "",
        itemType: ArcGISItemType? = nil,
        sortField: String = "modified",
        sortOrder: String = "desc",
        page: Int = 1
    ) async throws {
        guard isAuthenticated, let creds = credentials else {
            throw ArcGISError.portalNotConfigured
        }

        // Check token expiration
        if !creds.isValid {
            throw ArcGISError.tokenExpired
        }

        DispatchQueue.main.async {
            self.isLoading = true
            self.lastError = ""
            self.searchQuery = query
            self.selectedItemType = itemType
            self.currentPage = page
        }

        defer { DispatchQueue.main.async { self.isLoading = false } }

        // Build search URL
        let searchURL = "\(creds.portalURL)/sharing/rest/search"

        guard var urlComponents = URLComponents(string: searchURL) else {
            throw ArcGISError.networkError("Invalid search URL")
        }

        // Build query string
        var queryParts: [String] = []

        if !query.isEmpty {
            queryParts.append(query)
        }

        if let type = itemType {
            queryParts.append("type:\"\(type.rawValue)\"")
        }

        let finalQuery = queryParts.isEmpty ? "*" : queryParts.joined(separator: " AND ")

        let start = (page - 1) * pageSize + 1

        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: finalQuery),
            URLQueryItem(name: "sortField", value: sortField),
            URLQueryItem(name: "sortOrder", value: sortOrder),
            URLQueryItem(name: "start", value: String(start)),
            URLQueryItem(name: "num", value: String(pageSize)),
            URLQueryItem(name: "token", value: creds.token),
            URLQueryItem(name: "f", value: "json")
        ]

        guard let url = urlComponents.url else {
            throw ArcGISError.networkError("Failed to build search URL")
        }

        // Execute request
        var request = URLRequest(url: url)
        request.setValue("OmniTAK-iOS", forHTTPHeaderField: "Referer")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ArcGISError.networkError("Search request failed")
        }

        // Check for error in response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any] {
            let code = error["code"] as? Int ?? 0
            let message = error["message"] as? String ?? "Unknown error"

            if code == 498 || code == 499 {
                throw ArcGISError.tokenExpired
            }
            throw ArcGISError.serviceError(message)
        }

        // Parse search results
        let decoder = JSONDecoder()
        let searchResponse = try decoder.decode(ArcGISSearchResponse.self, from: data)

        DispatchQueue.main.async {
            if page == 1 {
                self.portalItems = searchResponse.results
            } else {
                self.portalItems.append(contentsOf: searchResponse.results)
            }
            self.totalResults = searchResponse.total
            self.hasMoreResults = searchResponse.nextStart > 0
        }

        print("ArcGIS Portal: Found \(searchResponse.total) items, loaded \(searchResponse.results.count)")
    }

    /// Load more results (pagination)
    func loadMoreResults() async throws {
        guard hasMoreResults else { return }
        try await searchContent(
            query: searchQuery,
            itemType: selectedItemType,
            page: currentPage + 1
        )
    }

    /// Get item details
    func getItemDetails(itemId: String) async throws -> ArcGISPortalItem {
        guard isAuthenticated, let creds = credentials else {
            throw ArcGISError.portalNotConfigured
        }

        let itemURL = "\(creds.portalURL)/sharing/rest/content/items/\(itemId)"

        guard var urlComponents = URLComponents(string: itemURL) else {
            throw ArcGISError.networkError("Invalid item URL")
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "token", value: creds.token),
            URLQueryItem(name: "f", value: "json")
        ]

        guard let url = urlComponents.url else {
            throw ArcGISError.networkError("Failed to build item URL")
        }

        var request = URLRequest(url: url)
        request.setValue("OmniTAK-iOS", forHTTPHeaderField: "Referer")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ArcGISError.networkError("Failed to fetch item details")
        }

        let decoder = JSONDecoder()
        return try decoder.decode(ArcGISPortalItem.self, from: data)
    }

    /// Get feature service layer info
    func getFeatureServiceInfo(serviceURL: String) async throws -> [ArcGISLayerInfo] {
        guard var urlComponents = URLComponents(string: serviceURL) else {
            throw ArcGISError.networkError("Invalid service URL")
        }

        var queryItems = [
            URLQueryItem(name: "f", value: "json")
        ]

        if let creds = credentials, creds.isValid {
            queryItems.append(URLQueryItem(name: "token", value: creds.token))
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw ArcGISError.networkError("Failed to build service URL")
        }

        var request = URLRequest(url: url)
        request.setValue("OmniTAK-iOS", forHTTPHeaderField: "Referer")

        let (data, _) = try await session.data(for: request)

        // Parse service info
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let layersArray = json["layers"] as? [[String: Any]] else {
            throw ArcGISError.parseError("Failed to parse service info")
        }

        var layers: [ArcGISLayerInfo] = []

        for layerDict in layersArray {
            guard let id = layerDict["id"] as? Int,
                  let name = layerDict["name"] as? String else {
                continue
            }

            let layer = ArcGISLayerInfo(
                id: id,
                name: name,
                type: layerDict["type"] as? String ?? "Feature Layer",
                geometryType: layerDict["geometryType"] as? String,
                description: layerDict["description"] as? String,
                minScale: layerDict["minScale"] as? Double ?? 0,
                maxScale: layerDict["maxScale"] as? Double ?? 0,
                defaultVisibility: layerDict["defaultVisibility"] as? Bool ?? true,
                extent: nil,
                fields: nil
            )

            layers.append(layer)
        }

        return layers
    }

    // MARK: - URL Building Helpers

    /// Build authenticated URL for a resource
    func buildAuthenticatedURL(baseURL: String, additionalParams: [String: String] = [:]) -> URL? {
        guard var urlComponents = URLComponents(string: baseURL) else { return nil }

        var queryItems = additionalParams.map { URLQueryItem(name: $0.key, value: $0.value) }

        if let creds = credentials, creds.isValid {
            queryItems.append(URLQueryItem(name: "token", value: creds.token))
        }

        queryItems.append(URLQueryItem(name: "f", value: "json"))

        urlComponents.queryItems = queryItems

        return urlComponents.url
    }

    /// Get thumbnail URL for portal item
    func getThumbnailURL(for item: ArcGISPortalItem) -> URL? {
        guard let thumbnail = item.thumbnail, !thumbnail.isEmpty else { return nil }

        let baseURL = "\(credentials?.portalURL ?? Self.arcGISOnlineURL)/sharing/rest/content/items/\(item.id)/info/\(thumbnail)"

        if let creds = credentials, creds.isValid {
            return URL(string: "\(baseURL)?token=\(creds.token)")
        }

        return URL(string: baseURL)
    }

    // MARK: - Persistence

    private func saveCredentials() {
        guard let credentials = credentials else { return }

        if let encoded = try? JSONEncoder().encode(credentials) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadCredentials() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let savedCredentials = try? JSONDecoder().decode(ArcGISCredentials.self, from: data) else {
            return
        }

        if savedCredentials.isValid {
            credentials = savedCredentials
            isAuthenticated = true
            print("ArcGIS Portal: Loaded saved credentials for \(savedCredentials.username)")
        } else {
            print("ArcGIS Portal: Saved credentials expired")
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        }
    }

    // MARK: - Token Refresh

    /// Refresh token if expiring soon
    func refreshTokenIfNeeded() async throws {
        guard let creds = credentials, creds.isExpiringSoon else { return }

        // Token refresh would require re-authentication with stored password
        // For security, we don't store passwords, so user must re-authenticate
        print("ArcGIS Portal: Token expiring soon, user should re-authenticate")
    }
}

// MARK: - Public Content Access (No Auth Required)

extension ArcGISPortalService {

    /// Search public content without authentication
    func searchPublicContent(
        query: String,
        itemType: ArcGISItemType? = nil,
        maxResults: Int = 25
    ) async throws -> [ArcGISPortalItem] {
        let searchURL = "\(Self.arcGISOnlineSharingURL)/search"

        guard var urlComponents = URLComponents(string: searchURL) else {
            throw ArcGISError.networkError("Invalid search URL")
        }

        var queryParts: [String] = [query]

        if let type = itemType {
            queryParts.append("type:\"\(type.rawValue)\"")
        }

        // Only show public content
        queryParts.append("access:public")

        let finalQuery = queryParts.joined(separator: " AND ")

        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: finalQuery),
            URLQueryItem(name: "num", value: String(maxResults)),
            URLQueryItem(name: "f", value: "json")
        ]

        guard let url = urlComponents.url else {
            throw ArcGISError.networkError("Failed to build search URL")
        }

        var request = URLRequest(url: url)
        request.setValue("OmniTAK-iOS", forHTTPHeaderField: "Referer")

        let (data, _) = try await session.data(for: request)

        let decoder = JSONDecoder()
        let searchResponse = try decoder.decode(ArcGISSearchResponse.self, from: data)

        return searchResponse.results
    }

    /// Get public basemap gallery
    func getPublicBasemaps() async throws -> [ArcGISPortalItem] {
        return try await searchPublicContent(
            query: "basemap",
            itemType: .tileService,
            maxResults: 20
        )
    }
}
