//
//  ArcGISFeatureService.swift
//  OmniTAKMobile
//
//  Service for querying and managing ArcGIS feature layers
//

import Foundation
import Combine
import CoreLocation
import MapKit

class ArcGISFeatureService: ObservableObject {
    static let shared = ArcGISFeatureService()

    // Published state
    @Published var loadedFeatures: [String: [ArcGISFeature]] = [:] // layerURL -> features
    @Published var layerConfigurations: [ArcGISServiceConfiguration] = []
    @Published var isLoading: Bool = false
    @Published var lastError: String = ""
    @Published var queryStatistics: QueryStatistics = QueryStatistics()

    // Cache management
    private var featureCache: [String: CachedFeatures] = [:]
    private let cacheDirectory: URL
    private let maxCacheAge: TimeInterval = 3600 // 1 hour default
    private let session: URLSession

    // Configuration persistence
    private let configurationsKey = "com.omnitak.arcgis.layerconfigs"

    private init() {
        // Setup cache directory
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cacheDir.appendingPathComponent("ArcGISFeatures")

        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Configure URL session
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        session = URLSession(configuration: config)

        loadConfigurations()
    }

    // MARK: - Feature Querying

    /// Query features from a feature service layer
    func queryFeatures(
        serviceURL: String,
        layerId: Int = 0,
        whereClause: String = "1=1",
        outFields: [String] = ["*"],
        geometry: MKMapRect? = nil,
        returnGeometry: Bool = true,
        maxRecords: Int = 1000,
        useCache: Bool = true
    ) async throws -> [ArcGISFeature] {
        let cacheKey = "\(serviceURL)/\(layerId)"

        // Check cache first
        if useCache, let cached = featureCache[cacheKey], !cached.isExpired {
            DispatchQueue.main.async {
                self.queryStatistics.cacheHits += 1
            }
            return cached.features
        }

        DispatchQueue.main.async {
            self.isLoading = true
            self.lastError = ""
        }

        defer { DispatchQueue.main.async { self.isLoading = false } }

        // Build query URL
        let queryURL = "\(serviceURL)/\(layerId)/query"

        guard var urlComponents = URLComponents(string: queryURL) else {
            throw ArcGISError.networkError("Invalid service URL")
        }

        var queryItems = [
            URLQueryItem(name: "where", value: whereClause),
            URLQueryItem(name: "outFields", value: outFields.joined(separator: ",")),
            URLQueryItem(name: "returnGeometry", value: returnGeometry ? "true" : "false"),
            URLQueryItem(name: "outSR", value: "4326"), // Request WGS84
            URLQueryItem(name: "f", value: "json")
        ]

        // Add geometry filter if provided
        if let mapRect = geometry {
            let spatialFilter = mapRectToExtent(mapRect)
            queryItems.append(URLQueryItem(name: "geometry", value: spatialFilter))
            queryItems.append(URLQueryItem(name: "geometryType", value: "esriGeometryEnvelope"))
            queryItems.append(URLQueryItem(name: "spatialRel", value: "esriSpatialRelIntersects"))
            queryItems.append(URLQueryItem(name: "inSR", value: "4326"))
        }

        // Add result record count
        queryItems.append(URLQueryItem(name: "resultRecordCount", value: String(maxRecords)))

        // Add token if authenticated
        if let creds = ArcGISPortalService.shared.credentials, creds.isValid {
            queryItems.append(URLQueryItem(name: "token", value: creds.token))
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw ArcGISError.networkError("Failed to build query URL")
        }

        // Execute request
        var request = URLRequest(url: url)
        request.setValue("OmniTAK-iOS", forHTTPHeaderField: "Referer")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ArcGISError.networkError("Query request failed")
        }

        // Check for error in response
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Unknown error"
            throw ArcGISError.queryFailed(message)
        }

        // Parse features
        let decoder = JSONDecoder()
        let queryResponse = try decoder.decode(ArcGISFeatureQueryResponse.self, from: data)

        // Update cache
        if useCache {
            featureCache[cacheKey] = CachedFeatures(
                features: queryResponse.features,
                timestamp: Date(),
                expiration: Date().addingTimeInterval(maxCacheAge)
            )
        }

        // Update state
        DispatchQueue.main.async {
            self.loadedFeatures[cacheKey] = queryResponse.features
            self.queryStatistics.totalQueries += 1
            self.queryStatistics.featuresLoaded += queryResponse.features.count
            self.queryStatistics.lastQueryTime = Date()

            if queryResponse.exceededTransferLimit == true {
                self.queryStatistics.transferLimitExceeded = true
            }
        }

        print("ArcGIS Features: Loaded \(queryResponse.features.count) features from \(cacheKey)")

        return queryResponse.features
    }

    /// Query features within a map region
    func queryFeaturesInRegion(
        config: ArcGISServiceConfiguration,
        region: MKCoordinateRegion
    ) async throws -> [ArcGISFeature] {
        let mapRect = regionToMapRect(region)

        return try await queryFeatures(
            serviceURL: config.serviceURL,
            layerId: config.layerId,
            whereClause: config.whereClause,
            outFields: config.outFields,
            geometry: mapRect,
            returnGeometry: config.returnGeometry,
            maxRecords: config.maxRecords,
            useCache: config.cacheEnabled
        )
    }

    /// Query all features from saved configurations
    func refreshAllLayers() async throws {
        for config in layerConfigurations {
            _ = try await queryFeatures(
                serviceURL: config.serviceURL,
                layerId: config.layerId,
                whereClause: config.whereClause,
                outFields: config.outFields,
                maxRecords: config.maxRecords,
                useCache: false
            )
        }
    }

    // MARK: - Layer Configuration Management

    /// Add a feature layer configuration
    func addLayerConfiguration(_ config: ArcGISServiceConfiguration) {
        // Remove existing if same service/layer
        layerConfigurations.removeAll {
            $0.serviceURL == config.serviceURL && $0.layerId == config.layerId
        }

        layerConfigurations.append(config)
        saveConfigurations()

        print("ArcGIS Features: Added layer configuration for \(config.serviceURL)")
    }

    /// Remove a feature layer configuration
    func removeLayerConfiguration(serviceURL: String, layerId: Int) {
        layerConfigurations.removeAll {
            $0.serviceURL == serviceURL && $0.layerId == layerId
        }

        let cacheKey = "\(serviceURL)/\(layerId)"
        loadedFeatures.removeValue(forKey: cacheKey)
        featureCache.removeValue(forKey: cacheKey)

        saveConfigurations()
    }

    // MARK: - MapKit Overlay Conversion

    /// Convert features to MapKit annotations (for point features)
    func createPointAnnotations(
        from features: [ArcGISFeature],
        titleField: String? = nil,
        subtitleField: String? = nil
    ) -> [ArcGISFeatureAnnotation] {
        return features.compactMap { feature in
            guard feature.geometry?.x != nil else { return nil }
            return ArcGISFeatureAnnotation(
                feature: feature,
                titleField: titleField,
                subtitleField: subtitleField
            )
        }
    }

    /// Convert features to MapKit polyline overlays
    func createPolylineOverlays(from features: [ArcGISFeature]) -> [ArcGISPolylineOverlay] {
        var overlays: [ArcGISPolylineOverlay] = []

        for feature in features {
            guard let geometry = feature.geometry else { continue }

            let paths = geometry.toPolylineCoordinates()

            for path in paths {
                guard !path.isEmpty else { continue }

                let overlay = ArcGISPolylineOverlay(coordinates: path, count: path.count)
                overlay.featureId = feature.id
                overlay.attributes = feature.attributes

                overlays.append(overlay)
            }
        }

        return overlays
    }

    /// Convert features to MapKit polygon overlays
    func createPolygonOverlays(from features: [ArcGISFeature]) -> [ArcGISPolygonOverlay] {
        var overlays: [ArcGISPolygonOverlay] = []

        for feature in features {
            guard let geometry = feature.geometry else { continue }

            let rings = geometry.toPolygonCoordinates()

            // First ring is exterior, rest are holes
            guard !rings.isEmpty, !rings[0].isEmpty else { continue }

            let exteriorRing = rings[0]

            if rings.count > 1 {
                // Create polygon with holes
                var interiorPolygons: [MKPolygon] = []

                for i in 1..<rings.count {
                    let hole = MKPolygon(coordinates: rings[i], count: rings[i].count)
                    interiorPolygons.append(hole)
                }

                let overlay = ArcGISPolygonOverlay(
                    coordinates: exteriorRing,
                    count: exteriorRing.count,
                    interiorPolygons: interiorPolygons
                )
                overlay.featureId = feature.id
                overlay.attributes = feature.attributes

                overlays.append(overlay)
            } else {
                // Simple polygon without holes
                let overlay = ArcGISPolygonOverlay(
                    coordinates: exteriorRing,
                    count: exteriorRing.count
                )
                overlay.featureId = feature.id
                overlay.attributes = feature.attributes

                overlays.append(overlay)
            }
        }

        return overlays
    }

    /// Create all overlays based on geometry type
    func createMapOverlays(
        from features: [ArcGISFeature],
        geometryType: ArcGISGeometryType
    ) -> (annotations: [ArcGISFeatureAnnotation], polylines: [ArcGISPolylineOverlay], polygons: [ArcGISPolygonOverlay]) {
        switch geometryType {
        case .point, .multipoint:
            return (createPointAnnotations(from: features), [], [])
        case .polyline:
            return ([], createPolylineOverlays(from: features), [])
        case .polygon:
            return ([], [], createPolygonOverlays(from: features))
        default:
            return ([], [], [])
        }
    }

    // MARK: - Cache Management

    /// Clear all cached features
    func clearCache() {
        featureCache.removeAll()
        loadedFeatures.removeAll()

        // Clear disk cache
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        queryStatistics = QueryStatistics()

        print("ArcGIS Features: Cache cleared")
    }

    /// Clear cache for specific layer
    func clearCache(for serviceURL: String, layerId: Int) {
        let cacheKey = "\(serviceURL)/\(layerId)"
        featureCache.removeValue(forKey: cacheKey)
        loadedFeatures.removeValue(forKey: cacheKey)
    }

    /// Get cache size in bytes
    func getCacheSize() -> Int64 {
        var totalSize: Int64 = 0

        // Memory cache size (approximate)
        for (_, cached) in featureCache {
            // Rough estimate: 1KB per feature
            totalSize += Int64(cached.features.count * 1024)
        }

        return totalSize
    }

    /// Remove expired cache entries
    func pruneExpiredCache() {
        let now = Date()

        featureCache = featureCache.filter { _, cached in
            !cached.isExpired
        }

        print("ArcGIS Features: Pruned expired cache entries")
    }

    // MARK: - Helper Methods

    private func mapRectToExtent(_ mapRect: MKMapRect) -> String {
        let minPoint = MKMapPoint(x: mapRect.minX, y: mapRect.minY)
        let maxPoint = MKMapPoint(x: mapRect.maxX, y: mapRect.maxY)

        let minCoord = minPoint.coordinate
        let maxCoord = maxPoint.coordinate

        return "\(minCoord.longitude),\(minCoord.latitude),\(maxCoord.longitude),\(maxCoord.latitude)"
    }

    private func regionToMapRect(_ region: MKCoordinateRegion) -> MKMapRect {
        let center = region.center
        let span = region.span

        let minLat = center.latitude - span.latitudeDelta / 2
        let maxLat = center.latitude + span.latitudeDelta / 2
        let minLon = center.longitude - span.longitudeDelta / 2
        let maxLon = center.longitude + span.longitudeDelta / 2

        let minCoord = CLLocationCoordinate2D(latitude: minLat, longitude: minLon)
        let maxCoord = CLLocationCoordinate2D(latitude: maxLat, longitude: maxLon)

        let minPoint = MKMapPoint(minCoord)
        let maxPoint = MKMapPoint(maxCoord)

        return MKMapRect(
            x: min(minPoint.x, maxPoint.x),
            y: min(minPoint.y, maxPoint.y),
            width: abs(maxPoint.x - minPoint.x),
            height: abs(maxPoint.y - minPoint.y)
        )
    }

    // MARK: - Persistence

    private func saveConfigurations() {
        if let encoded = try? JSONEncoder().encode(layerConfigurations) {
            UserDefaults.standard.set(encoded, forKey: configurationsKey)
        }
    }

    private func loadConfigurations() {
        guard let data = UserDefaults.standard.data(forKey: configurationsKey),
              let configs = try? JSONDecoder().decode([ArcGISServiceConfiguration].self, from: data) else {
            return
        }

        layerConfigurations = configs
        print("ArcGIS Features: Loaded \(configs.count) layer configurations")
    }
}

// MARK: - Supporting Types

struct CachedFeatures {
    var features: [ArcGISFeature]
    var timestamp: Date
    var expiration: Date

    var isExpired: Bool {
        Date() > expiration
    }

    var age: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }
}

struct QueryStatistics {
    var totalQueries: Int = 0
    var featuresLoaded: Int = 0
    var cacheHits: Int = 0
    var lastQueryTime: Date?
    var transferLimitExceeded: Bool = false

    var cacheHitRate: Double {
        guard totalQueries > 0 else { return 0 }
        return Double(cacheHits) / Double(totalQueries + cacheHits)
    }
}

// MARK: - Layer Service Info

extension ArcGISFeatureService {

    /// Get detailed layer information
    func getLayerInfo(serviceURL: String, layerId: Int) async throws -> ArcGISLayerInfo {
        let layerURL = "\(serviceURL)/\(layerId)"

        guard var urlComponents = URLComponents(string: layerURL) else {
            throw ArcGISError.networkError("Invalid layer URL")
        }

        var queryItems = [URLQueryItem(name: "f", value: "json")]

        if let creds = ArcGISPortalService.shared.credentials, creds.isValid {
            queryItems.append(URLQueryItem(name: "token", value: creds.token))
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw ArcGISError.networkError("Failed to build layer URL")
        }

        var request = URLRequest(url: url)
        request.setValue("OmniTAK-iOS", forHTTPHeaderField: "Referer")

        let (data, _) = try await session.data(for: request)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ArcGISError.parseError("Failed to parse layer info")
        }

        // Parse layer info
        guard let id = json["id"] as? Int,
              let name = json["name"] as? String else {
            throw ArcGISError.parseError("Missing required layer info")
        }

        var fields: [ArcGISField] = []
        if let fieldsArray = json["fields"] as? [[String: Any]] {
            fields = fieldsArray.compactMap { fieldDict in
                guard let fieldName = fieldDict["name"] as? String,
                      let fieldType = fieldDict["type"] as? String else {
                    return nil
                }

                return ArcGISField(
                    name: fieldName,
                    type: fieldType,
                    alias: fieldDict["alias"] as? String,
                    length: fieldDict["length"] as? Int,
                    editable: fieldDict["editable"] as? Bool,
                    nullable: fieldDict["nullable"] as? Bool
                )
            }
        }

        var extent: ArcGISExtent?
        if let extentDict = json["extent"] as? [String: Any] {
            extent = ArcGISExtent(
                xmin: extentDict["xmin"] as? Double ?? 0,
                ymin: extentDict["ymin"] as? Double ?? 0,
                xmax: extentDict["xmax"] as? Double ?? 0,
                ymax: extentDict["ymax"] as? Double ?? 0,
                spatialReference: nil
            )
        }

        return ArcGISLayerInfo(
            id: id,
            name: name,
            type: json["type"] as? String ?? "Feature Layer",
            geometryType: json["geometryType"] as? String,
            description: json["description"] as? String,
            minScale: json["minScale"] as? Double ?? 0,
            maxScale: json["maxScale"] as? Double ?? 0,
            defaultVisibility: json["defaultVisibility"] as? Bool ?? true,
            extent: extent,
            fields: fields
        )
    }

    /// Get record count for a layer
    func getRecordCount(serviceURL: String, layerId: Int, whereClause: String = "1=1") async throws -> Int {
        let queryURL = "\(serviceURL)/\(layerId)/query"

        guard var urlComponents = URLComponents(string: queryURL) else {
            throw ArcGISError.networkError("Invalid query URL")
        }

        var queryItems = [
            URLQueryItem(name: "where", value: whereClause),
            URLQueryItem(name: "returnCountOnly", value: "true"),
            URLQueryItem(name: "f", value: "json")
        ]

        if let creds = ArcGISPortalService.shared.credentials, creds.isValid {
            queryItems.append(URLQueryItem(name: "token", value: creds.token))
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw ArcGISError.networkError("Failed to build count URL")
        }

        var request = URLRequest(url: url)
        request.setValue("OmniTAK-iOS", forHTTPHeaderField: "Referer")

        let (data, _) = try await session.data(for: request)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let count = json["count"] as? Int else {
            throw ArcGISError.parseError("Failed to parse record count")
        }

        return count
    }
}
