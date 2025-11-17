//
//  ArcGISModels.swift
//  OmniTAKMobile
//
//  Data models for ArcGIS Portal content, features, and geometries
//

import Foundation
import CoreLocation
import MapKit

// MARK: - Portal Authentication

struct ArcGISCredentials: Codable {
    var portalURL: String
    var username: String
    var token: String
    var tokenExpiration: Date
    var referer: String

    init(portalURL: String = "https://www.arcgis.com",
         username: String = "",
         token: String = "",
         tokenExpiration: Date = Date(),
         referer: String = "") {
        self.portalURL = portalURL
        self.username = username
        self.token = token
        self.tokenExpiration = tokenExpiration
        self.referer = referer
    }

    var isValid: Bool {
        !token.isEmpty && tokenExpiration > Date()
    }

    var isExpiringSoon: Bool {
        tokenExpiration.timeIntervalSinceNow < 300 // 5 minutes
    }
}

// MARK: - Portal Item Types

enum ArcGISItemType: String, Codable, CaseIterable {
    case webMap = "Web Map"
    case featureService = "Feature Service"
    case mapService = "Map Service"
    case imageService = "Image Service"
    case vectorTileService = "Vector Tile Service"
    case tileService = "Tile Service"
    case layer = "Layer"
    case unknown = "Unknown"

    var icon: String {
        switch self {
        case .webMap:
            return "map.fill"
        case .featureService:
            return "square.3.layers.3d"
        case .mapService:
            return "map"
        case .imageService:
            return "photo.stack"
        case .vectorTileService:
            return "square.grid.3x3.fill"
        case .tileService:
            return "square.grid.3x3"
        case .layer:
            return "square.3.layers.3d.down.right"
        case .unknown:
            return "questionmark.circle"
        }
    }
}

// MARK: - Portal Item

struct ArcGISPortalItem: Codable, Identifiable {
    var id: String
    var title: String
    var owner: String
    var itemType: String
    var url: String?
    var description: String?
    var snippet: String?
    var thumbnail: String?
    var created: Date?
    var modified: Date?
    var numViews: Int
    var size: Int64
    var tags: [String]
    var extent: [[Double]]?
    var accessInformation: String?

    enum CodingKeys: String, CodingKey {
        case id, title, owner, url, description, snippet, thumbnail
        case created, modified, numViews, size, tags, extent, accessInformation
        case itemType = "type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        owner = try container.decode(String.self, forKey: .owner)
        itemType = try container.decode(String.self, forKey: .itemType)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        snippet = try container.decodeIfPresent(String.self, forKey: .snippet)
        thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)

        // Handle timestamps (milliseconds since epoch)
        if let createdMs = try container.decodeIfPresent(Int64.self, forKey: .created) {
            created = Date(timeIntervalSince1970: Double(createdMs) / 1000.0)
        }
        if let modifiedMs = try container.decodeIfPresent(Int64.self, forKey: .modified) {
            modified = Date(timeIntervalSince1970: Double(modifiedMs) / 1000.0)
        }

        numViews = try container.decodeIfPresent(Int.self, forKey: .numViews) ?? 0
        size = try container.decodeIfPresent(Int64.self, forKey: .size) ?? 0
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        extent = try container.decodeIfPresent([[Double]].self, forKey: .extent)
        accessInformation = try container.decodeIfPresent(String.self, forKey: .accessInformation)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(owner, forKey: .owner)
        try container.encode(itemType, forKey: .itemType)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(snippet, forKey: .snippet)
        try container.encodeIfPresent(thumbnail, forKey: .thumbnail)
        if let created = created {
            try container.encode(Int64(created.timeIntervalSince1970 * 1000), forKey: .created)
        }
        if let modified = modified {
            try container.encode(Int64(modified.timeIntervalSince1970 * 1000), forKey: .modified)
        }
        try container.encode(numViews, forKey: .numViews)
        try container.encode(size, forKey: .size)
        try container.encode(tags, forKey: .tags)
        try container.encodeIfPresent(extent, forKey: .extent)
        try container.encodeIfPresent(accessInformation, forKey: .accessInformation)
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var thumbnailURL: URL? {
        guard let thumbnail = thumbnail else { return nil }
        return URL(string: "https://www.arcgis.com/sharing/rest/content/items/\(id)/info/\(thumbnail)")
    }

    var parsedItemType: ArcGISItemType {
        ArcGISItemType(rawValue: itemType) ?? .unknown
    }
}

// MARK: - Portal Search Response

struct ArcGISSearchResponse: Codable {
    var results: [ArcGISPortalItem]
    var total: Int
    var start: Int
    var num: Int
    var nextStart: Int

    init(results: [ArcGISPortalItem] = [], total: Int = 0, start: Int = 1, num: Int = 10, nextStart: Int = -1) {
        self.results = results
        self.total = total
        self.start = start
        self.num = num
        self.nextStart = nextStart
    }
}

// MARK: - Feature Service Layer Info

struct ArcGISLayerInfo: Codable, Identifiable {
    var id: Int
    var name: String
    var type: String
    var geometryType: String?
    var description: String?
    var minScale: Double
    var maxScale: Double
    var defaultVisibility: Bool
    var extent: ArcGISExtent?
    var fields: [ArcGISField]?

    var displayName: String {
        name.isEmpty ? "Layer \(id)" : name
    }

    var parsedGeometryType: ArcGISGeometryType {
        guard let geometryType = geometryType else { return .unknown }
        return ArcGISGeometryType(rawValue: geometryType) ?? .unknown
    }
}

// MARK: - Field Definition

struct ArcGISField: Codable {
    var name: String
    var type: String
    var alias: String?
    var length: Int?
    var editable: Bool?
    var nullable: Bool?

    var displayName: String {
        alias ?? name
    }
}

// MARK: - Extent

struct ArcGISExtent: Codable {
    var xmin: Double
    var ymin: Double
    var xmax: Double
    var ymax: Double
    var spatialReference: ArcGISSpatialReference?

    var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (ymin + ymax) / 2,
            longitude: (xmin + xmax) / 2
        )
    }

    var mapRegion: MKCoordinateRegion {
        let center = self.center
        let span = MKCoordinateSpan(
            latitudeDelta: abs(ymax - ymin),
            longitudeDelta: abs(xmax - xmin)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - Spatial Reference

struct ArcGISSpatialReference: Codable {
    var wkid: Int?
    var latestWkid: Int?

    var isWGS84: Bool {
        wkid == 4326 || latestWkid == 4326
    }

    var isWebMercator: Bool {
        wkid == 3857 || wkid == 102100 || latestWkid == 3857
    }
}

// MARK: - Geometry Types

enum ArcGISGeometryType: String, Codable {
    case point = "esriGeometryPoint"
    case polyline = "esriGeometryPolyline"
    case polygon = "esriGeometryPolygon"
    case multipoint = "esriGeometryMultipoint"
    case envelope = "esriGeometryEnvelope"
    case unknown = "Unknown"

    var displayName: String {
        switch self {
        case .point:
            return "Point"
        case .polyline:
            return "Line"
        case .polygon:
            return "Polygon"
        case .multipoint:
            return "Multipoint"
        case .envelope:
            return "Envelope"
        case .unknown:
            return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .point:
            return "mappin"
        case .polyline:
            return "line.diagonal"
        case .polygon:
            return "hexagon.fill"
        case .multipoint:
            return "mappin.and.ellipse"
        case .envelope:
            return "rectangle"
        case .unknown:
            return "questionmark"
        }
    }
}

// MARK: - Feature Query Response

struct ArcGISFeatureQueryResponse: Codable {
    var objectIdFieldName: String?
    var globalIdFieldName: String?
    var geometryType: String?
    var spatialReference: ArcGISSpatialReference?
    var fields: [ArcGISField]?
    var features: [ArcGISFeature]
    var exceededTransferLimit: Bool?

    var parsedGeometryType: ArcGISGeometryType {
        guard let geometryType = geometryType else { return .unknown }
        return ArcGISGeometryType(rawValue: geometryType) ?? .unknown
    }
}

// MARK: - Feature

struct ArcGISFeature: Codable, Identifiable {
    var id: String
    var attributes: [String: ArcGISAttributeValue]
    var geometry: ArcGISGeometry?

    enum CodingKeys: String, CodingKey {
        case attributes, geometry
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        attributes = try container.decode([String: ArcGISAttributeValue].self, forKey: .attributes)
        geometry = try container.decodeIfPresent(ArcGISGeometry.self, forKey: .geometry)

        // Generate ID from OBJECTID or GlobalID if available
        if let objectId = attributes["OBJECTID"]?.intValue {
            id = String(objectId)
        } else if let globalId = attributes["GlobalID"]?.stringValue {
            id = globalId
        } else {
            id = UUID().uuidString
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(attributes, forKey: .attributes)
        try container.encodeIfPresent(geometry, forKey: .geometry)
    }

    func getValue(for field: String) -> String {
        attributes[field]?.displayValue ?? ""
    }
}

// MARK: - Attribute Value (handles mixed types)

enum ArcGISAttributeValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let doubleVal = try? container.decode(Double.self) {
            self = .double(doubleVal)
        } else if let boolVal = try? container.decode(Bool.self) {
            self = .bool(boolVal)
        } else if let stringVal = try? container.decode(String.self) {
            self = .string(stringVal)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        if case .int(let value) = self { return value }
        return nil
    }

    var doubleValue: Double? {
        if case .double(let value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var displayValue: String {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        case .double(let value):
            return String(format: "%.2f", value)
        case .bool(let value):
            return value ? "Yes" : "No"
        case .null:
            return ""
        }
    }
}

// MARK: - Geometry (esriJSON format)

struct ArcGISGeometry: Codable {
    var x: Double?
    var y: Double?
    var z: Double?
    var paths: [[[Double]]]?
    var rings: [[[Double]]]?
    var points: [[Double]]?
    var spatialReference: ArcGISSpatialReference?

    // Convert to CLLocationCoordinate2D for point geometry
    func toCoordinate() -> CLLocationCoordinate2D? {
        guard let x = x, let y = y else { return nil }

        // Check if coordinates need Web Mercator to WGS84 conversion
        if let sr = spatialReference, sr.isWebMercator {
            return webMercatorToWGS84(x: x, y: y)
        }

        return CLLocationCoordinate2D(latitude: y, longitude: x)
    }

    // Convert paths (polylines) to coordinate arrays
    func toPolylineCoordinates() -> [[CLLocationCoordinate2D]] {
        guard let paths = paths else { return [] }

        return paths.map { path in
            path.compactMap { point -> CLLocationCoordinate2D? in
                guard point.count >= 2 else { return nil }
                let x = point[0]
                let y = point[1]

                if let sr = spatialReference, sr.isWebMercator {
                    return webMercatorToWGS84(x: x, y: y)
                }

                return CLLocationCoordinate2D(latitude: y, longitude: x)
            }
        }
    }

    // Convert rings (polygons) to coordinate arrays
    func toPolygonCoordinates() -> [[CLLocationCoordinate2D]] {
        guard let rings = rings else { return [] }

        return rings.map { ring in
            ring.compactMap { point -> CLLocationCoordinate2D? in
                guard point.count >= 2 else { return nil }
                let x = point[0]
                let y = point[1]

                if let sr = spatialReference, sr.isWebMercator {
                    return webMercatorToWGS84(x: x, y: y)
                }

                return CLLocationCoordinate2D(latitude: y, longitude: x)
            }
        }
    }

    // Convert multipoint to coordinates
    func toMultipointCoordinates() -> [CLLocationCoordinate2D] {
        guard let points = points else { return [] }

        return points.compactMap { point -> CLLocationCoordinate2D? in
            guard point.count >= 2 else { return nil }
            let x = point[0]
            let y = point[1]

            if let sr = spatialReference, sr.isWebMercator {
                return webMercatorToWGS84(x: x, y: y)
            }

            return CLLocationCoordinate2D(latitude: y, longitude: x)
        }
    }

    // Web Mercator to WGS84 conversion
    private func webMercatorToWGS84(x: Double, y: Double) -> CLLocationCoordinate2D {
        let lon = (x / 20037508.34) * 180.0
        var lat = (y / 20037508.34) * 180.0
        lat = 180.0 / .pi * (2.0 * atan(exp(lat * .pi / 180.0)) - .pi / 2.0)
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - Map Overlays for Features

class ArcGISFeatureAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    var featureId: String
    var attributes: [String: ArcGISAttributeValue]

    init(feature: ArcGISFeature, titleField: String? = nil, subtitleField: String? = nil) {
        self.featureId = feature.id
        self.attributes = feature.attributes

        if let coord = feature.geometry?.toCoordinate() {
            self.coordinate = coord
        } else {
            self.coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }

        // Set title from specified field or first string attribute
        if let titleField = titleField {
            self.title = feature.getValue(for: titleField)
        } else {
            self.title = feature.attributes.first(where: { $0.value.stringValue != nil })?.value.stringValue
        }

        if let subtitleField = subtitleField {
            self.subtitle = feature.getValue(for: subtitleField)
        }

        super.init()
    }
}

class ArcGISPolylineOverlay: MKPolyline {
    var featureId: String = ""
    var attributes: [String: ArcGISAttributeValue] = [:]
}

class ArcGISPolygonOverlay: MKPolygon {
    var featureId: String = ""
    var attributes: [String: ArcGISAttributeValue] = [:]
}

// MARK: - Error Types

enum ArcGISError: LocalizedError {
    case invalidCredentials
    case tokenExpired
    case networkError(String)
    case parseError(String)
    case serviceError(String)
    case unsupportedGeometry
    case portalNotConfigured
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid portal credentials"
        case .tokenExpired:
            return "Authentication token has expired"
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .parseError(let detail):
            return "Failed to parse response: \(detail)"
        case .serviceError(let detail):
            return "Service error: \(detail)"
        case .unsupportedGeometry:
            return "Unsupported geometry type"
        case .portalNotConfigured:
            return "ArcGIS Portal not configured"
        case .queryFailed(let detail):
            return "Query failed: \(detail)"
        }
    }
}

// MARK: - Service Configuration

struct ArcGISServiceConfiguration: Codable {
    var serviceURL: String
    var layerId: Int
    var displayField: String?
    var labelField: String?
    var outFields: [String]
    var whereClause: String
    var maxRecords: Int
    var returnGeometry: Bool
    var cacheEnabled: Bool
    var cacheExpiration: TimeInterval

    init(serviceURL: String,
         layerId: Int = 0,
         displayField: String? = nil,
         labelField: String? = nil,
         outFields: [String] = ["*"],
         whereClause: String = "1=1",
         maxRecords: Int = 1000,
         returnGeometry: Bool = true,
         cacheEnabled: Bool = true,
         cacheExpiration: TimeInterval = 3600) {
        self.serviceURL = serviceURL
        self.layerId = layerId
        self.displayField = displayField
        self.labelField = labelField
        self.outFields = outFields
        self.whereClause = whereClause
        self.maxRecords = maxRecords
        self.returnGeometry = returnGeometry
        self.cacheEnabled = cacheEnabled
        self.cacheExpiration = cacheExpiration
    }
}
