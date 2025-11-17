//
//  ArcGISTileSource.swift
//  OmniTAKMobile
//
//  Custom MKTileOverlay for ArcGIS basemap and map service tiles
//

import Foundation
import MapKit
import UIKit

// MARK: - ArcGIS Tile Overlay

class ArcGISTileOverlay: MKTileOverlay {

    // Tile source configuration
    var serviceURL: String
    var serviceType: ArcGISMapServiceType
    var authToken: String?
    var layerId: Int?

    // Caching
    private let tileCache: NSCache<NSString, NSData>
    private let cacheDirectory: URL?
    private let enableDiskCache: Bool

    // Error handling
    private lazy var errorTile: Data? = {
        return generateErrorTile()
    }()

    private lazy var loadingTile: Data? = {
        return generateLoadingTile()
    }()

    // Statistics
    private var tileRequestCount: Int = 0
    private var cacheHitCount: Int = 0

    init(
        serviceURL: String,
        serviceType: ArcGISMapServiceType = .mapServer,
        authToken: String? = nil,
        layerId: Int? = nil,
        enableDiskCache: Bool = true
    ) {
        self.serviceURL = serviceURL
        self.serviceType = serviceType
        self.authToken = authToken
        self.layerId = layerId
        self.enableDiskCache = enableDiskCache

        // Initialize memory cache
        tileCache = NSCache<NSString, NSData>()
        tileCache.countLimit = 200
        tileCache.totalCostLimit = 50 * 1024 * 1024 // 50MB

        // Setup disk cache
        if enableDiskCache {
            let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            cacheDirectory = cacheDir.appendingPathComponent("ArcGISTiles")
            try? FileManager.default.createDirectory(at: cacheDirectory!, withIntermediateDirectories: true)
        } else {
            cacheDirectory = nil
        }

        // Initialize parent with empty template (we override url generation)
        super.init(urlTemplate: nil)

        // Configure overlay properties
        self.canReplaceMapContent = false
        self.minimumZ = 0
        self.maximumZ = 20
        self.tileSize = CGSize(width: 256, height: 256)
    }

    // Convenience initializers for common basemaps
    static func worldStreetMap() -> ArcGISTileOverlay {
        return ArcGISTileOverlay(
            serviceURL: "https://services.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer",
            serviceType: .mapServer
        )
    }

    static func worldImagery() -> ArcGISTileOverlay {
        return ArcGISTileOverlay(
            serviceURL: "https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer",
            serviceType: .mapServer
        )
    }

    static func worldTopoMap() -> ArcGISTileOverlay {
        return ArcGISTileOverlay(
            serviceURL: "https://services.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer",
            serviceType: .mapServer
        )
    }

    static func natGeoWorldMap() -> ArcGISTileOverlay {
        return ArcGISTileOverlay(
            serviceURL: "https://services.arcgisonline.com/ArcGIS/rest/services/NatGeo_World_Map/MapServer",
            serviceType: .mapServer
        )
    }

    static func usaTopo() -> ArcGISTileOverlay {
        return ArcGISTileOverlay(
            serviceURL: "https://services.arcgisonline.com/ArcGIS/rest/services/USA_Topo_Maps/MapServer",
            serviceType: .mapServer
        )
    }

    static func worldHillshade() -> ArcGISTileOverlay {
        return ArcGISTileOverlay(
            serviceURL: "https://services.arcgisonline.com/arcgis/rest/services/Elevation/World_Hillshade/MapServer",
            serviceType: .mapServer
        )
    }

    static func worldShadedRelief() -> ArcGISTileOverlay {
        return ArcGISTileOverlay(
            serviceURL: "https://services.arcgisonline.com/ArcGIS/rest/services/World_Shaded_Relief/MapServer",
            serviceType: .mapServer
        )
    }

    // MARK: - URL Generation

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        var tileURL: String

        switch serviceType {
        case .mapServer, .imageServer:
            // ArcGIS MapServer tile endpoint: /tile/{level}/{row}/{col}
            tileURL = "\(serviceURL)/tile/\(path.z)/\(path.y)/\(path.x)"

        case .tileServer:
            // Vector or raster tile server: /tile/{z}/{y}/{x}
            tileURL = "\(serviceURL)/tile/\(path.z)/\(path.y)/\(path.x)"

        case .vectorTileServer:
            // Vector tile (pbf format)
            tileURL = "\(serviceURL)/tile/\(path.z)/\(path.y)/\(path.x).pbf"

        case .wmts:
            // WMTS pattern
            tileURL = "\(serviceURL)?SERVICE=WMTS&REQUEST=GetTile&VERSION=1.0.0&LAYER=default&STYLE=default&TILEMATRIXSET=default&TILEMATRIX=\(path.z)&TILEROW=\(path.y)&TILECOL=\(path.x)&FORMAT=image/png"

        case .exportMap:
            // Dynamic map export (for services without tile cache)
            let bbox = tileBoundingBox(for: path)
            if let layerId = layerId {
                tileURL = "\(serviceURL)/export?bbox=\(bbox)&bboxSR=3857&layers=show:\(layerId)&size=256,256&format=png&f=image"
            } else {
                tileURL = "\(serviceURL)/export?bbox=\(bbox)&bboxSR=3857&size=256,256&format=png&f=image"
            }
        }

        // Add auth token if available
        if let token = authToken {
            if tileURL.contains("?") {
                tileURL += "&token=\(token)"
            } else {
                tileURL += "?token=\(token)"
            }
        }

        return URL(string: tileURL) ?? URL(string: "about:blank")!
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        tileRequestCount += 1

        let cacheKey = "\(serviceURL)_\(path.z)_\(path.y)_\(path.x)"

        // Check memory cache first
        if let cachedData = tileCache.object(forKey: cacheKey as NSString) {
            cacheHitCount += 1
            result(cachedData as Data, nil)
            return
        }

        // Check disk cache
        if let diskCacheURL = diskCachePath(for: path),
           FileManager.default.fileExists(atPath: diskCacheURL.path) {
            if let data = try? Data(contentsOf: diskCacheURL) {
                // Store in memory cache
                tileCache.setObject(data as NSData, forKey: cacheKey as NSString)
                cacheHitCount += 1
                result(data, nil)
                return
            }
        }

        // Download tile
        let tileURL = url(forTilePath: path)

        var request = URLRequest(url: tileURL)
        request.setValue("OmniTAK-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("OmniTAK-iOS", forHTTPHeaderField: "Referer")
        request.timeoutInterval = 15

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else {
                result(nil, error)
                return
            }

            if let error = error {
                print("ArcGIS Tile Error (\(path.z)/\(path.y)/\(path.x)): \(error.localizedDescription)")
                result(self.errorTile, nil)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                result(self.errorTile, nil)
                return
            }

            // Handle different response codes
            switch httpResponse.statusCode {
            case 200:
                if let tileData = data {
                    // Cache the tile
                    self.tileCache.setObject(tileData as NSData, forKey: cacheKey as NSString)

                    // Save to disk cache
                    if let diskURL = self.diskCachePath(for: path) {
                        try? tileData.write(to: diskURL)
                    }

                    result(tileData, nil)
                } else {
                    result(self.errorTile, nil)
                }

            case 404:
                // Tile doesn't exist at this zoom level
                result(self.generateEmptyTile(), nil)

            case 401, 403:
                // Authentication error
                print("ArcGIS Tile Auth Error: \(httpResponse.statusCode)")
                result(self.errorTile, nil)

            default:
                print("ArcGIS Tile HTTP Error: \(httpResponse.statusCode)")
                result(self.errorTile, nil)
            }
        }

        task.resume()
    }

    // MARK: - Cache Management

    func clearMemoryCache() {
        tileCache.removeAllObjects()
        print("ArcGIS Tiles: Memory cache cleared")
    }

    func clearDiskCache() {
        guard let cacheDir = cacheDirectory else { return }

        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        print("ArcGIS Tiles: Disk cache cleared")
    }

    func clearAllCache() {
        clearMemoryCache()
        clearDiskCache()
        tileRequestCount = 0
        cacheHitCount = 0
    }

    func getCacheStatistics() -> (requests: Int, hits: Int, hitRate: Double) {
        let hitRate = tileRequestCount > 0 ? Double(cacheHitCount) / Double(tileRequestCount) : 0
        return (tileRequestCount, cacheHitCount, hitRate)
    }

    func getDiskCacheSize() -> Int64 {
        guard let cacheDir = cacheDirectory else { return 0 }

        var totalSize: Int64 = 0
        let fileManager = FileManager.default

        if let enumerator = fileManager.enumerator(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) {
            while let fileURL = enumerator.nextObject() as? URL {
                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let size = attributes[.size] as? Int64 {
                    totalSize += size
                }
            }
        }

        return totalSize
    }

    // MARK: - Helper Methods

    private func diskCachePath(for path: MKTileOverlayPath) -> URL? {
        guard let cacheDir = cacheDirectory else { return nil }

        // Create subdirectory for zoom level
        let zoomDir = cacheDir.appendingPathComponent("\(path.z)")
        try? FileManager.default.createDirectory(at: zoomDir, withIntermediateDirectories: true)

        return zoomDir.appendingPathComponent("\(path.y)_\(path.x).png")
    }

    private func tileBoundingBox(for path: MKTileOverlayPath) -> String {
        // Convert tile coordinates to Web Mercator bounding box
        let n = pow(2.0, Double(path.z))
        let tileSize = 20037508.34 * 2.0 / n

        let xmin = -20037508.34 + Double(path.x) * tileSize
        let xmax = xmin + tileSize

        // Y is inverted for TMS
        let ymax = 20037508.34 - Double(path.y) * tileSize
        let ymin = ymax - tileSize

        return "\(xmin),\(ymin),\(xmax),\(ymax)"
    }

    private func generateErrorTile() -> Data? {
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { context in
            // Light red background
            UIColor(red: 1.0, green: 0.9, blue: 0.9, alpha: 0.5).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Grid pattern
            UIColor(red: 1.0, green: 0.8, blue: 0.8, alpha: 0.5).setStroke()
            context.cgContext.setLineWidth(0.5)

            for i in stride(from: 0, through: 256, by: 64) {
                context.cgContext.move(to: CGPoint(x: Double(i), y: 0))
                context.cgContext.addLine(to: CGPoint(x: Double(i), y: 256))
                context.cgContext.strokePath()

                context.cgContext.move(to: CGPoint(x: 0, y: Double(i)))
                context.cgContext.addLine(to: CGPoint(x: 256, y: Double(i)))
                context.cgContext.strokePath()
            }

            // Error icon
            let text = "Error"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor.red.withAlphaComponent(0.6)
            ]
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: textRect, withAttributes: attributes)
        }

        return image.pngData()
    }

    private func generateLoadingTile() -> Data? {
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { context in
            UIColor(white: 0.95, alpha: 0.5).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        return image.pngData()
    }

    private func generateEmptyTile() -> Data? {
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { _ in
            // Completely transparent tile
            UIColor.clear.setFill()
        }

        return image.pngData()
    }
}

// MARK: - Map Service Types

enum ArcGISMapServiceType: String, Codable, CaseIterable {
    case mapServer = "MapServer"
    case imageServer = "ImageServer"
    case tileServer = "TileServer"
    case vectorTileServer = "VectorTileServer"
    case wmts = "WMTS"
    case exportMap = "ExportMap"

    var displayName: String {
        switch self {
        case .mapServer:
            return "Map Server (Cached)"
        case .imageServer:
            return "Image Server"
        case .tileServer:
            return "Tile Server"
        case .vectorTileServer:
            return "Vector Tiles"
        case .wmts:
            return "WMTS Service"
        case .exportMap:
            return "Dynamic Map Export"
        }
    }
}

// MARK: - Tile Overlay Manager

class ArcGISTileManager: ObservableObject {
    static let shared = ArcGISTileManager()

    @Published var activeTileOverlays: [String: ArcGISTileOverlay] = [:]
    @Published var availableBasemaps: [BasemapInfo] = []

    private let overlayConfigKey = "com.omnitak.arcgis.tileoverlays"

    private init() {
        loadAvailableBasemaps()
    }

    /// Add a tile overlay to the map
    func addTileOverlay(name: String, overlay: ArcGISTileOverlay) {
        activeTileOverlays[name] = overlay
        print("ArcGIS Tiles: Added overlay '\(name)'")
    }

    /// Remove a tile overlay
    func removeTileOverlay(name: String) {
        activeTileOverlays.removeValue(forKey: name)
        print("ArcGIS Tiles: Removed overlay '\(name)'")
    }

    /// Get default basemap overlays
    private func loadAvailableBasemaps() {
        availableBasemaps = [
            BasemapInfo(
                id: "world_street",
                name: "World Street Map",
                description: "Multi-scale street map for the world",
                previewURL: "https://www.arcgis.com/sharing/rest/content/items/3b93337983e9436f8db950e38a8629af/info/thumbnail/ago_downloaded.png",
                createOverlay: { ArcGISTileOverlay.worldStreetMap() }
            ),
            BasemapInfo(
                id: "world_imagery",
                name: "World Imagery",
                description: "High resolution satellite imagery",
                previewURL: "https://www.arcgis.com/sharing/rest/content/items/10df2279f9684e4a9f6a7f08febac2a9/info/thumbnail/ago_downloaded.png",
                createOverlay: { ArcGISTileOverlay.worldImagery() }
            ),
            BasemapInfo(
                id: "world_topo",
                name: "World Topographic Map",
                description: "Topographic map with terrain",
                previewURL: "https://www.arcgis.com/sharing/rest/content/items/30e5fe3149c34df1ba922e6f5bbf808f/info/thumbnail/ago_downloaded.png",
                createOverlay: { ArcGISTileOverlay.worldTopoMap() }
            ),
            BasemapInfo(
                id: "natgeo",
                name: "National Geographic",
                description: "National Geographic style world map",
                previewURL: "https://www.arcgis.com/sharing/rest/content/items/f33a34de3a294590ab48f246e99958c9/info/thumbnail/ago_downloaded.png",
                createOverlay: { ArcGISTileOverlay.natGeoWorldMap() }
            ),
            BasemapInfo(
                id: "usa_topo",
                name: "USA Topographic Maps",
                description: "USGS topo maps for the United States",
                previewURL: nil,
                createOverlay: { ArcGISTileOverlay.usaTopo() }
            ),
            BasemapInfo(
                id: "hillshade",
                name: "World Hillshade",
                description: "Shaded relief terrain",
                previewURL: nil,
                createOverlay: { ArcGISTileOverlay.worldHillshade() }
            ),
            BasemapInfo(
                id: "shaded_relief",
                name: "World Shaded Relief",
                description: "Physical terrain shading",
                previewURL: nil,
                createOverlay: { ArcGISTileOverlay.worldShadedRelief() }
            )
        ]
    }

    /// Clear all tile caches
    func clearAllCaches() {
        for (_, overlay) in activeTileOverlays {
            overlay.clearAllCache()
        }
    }

    /// Get total cache size
    func getTotalCacheSize() -> Int64 {
        var total: Int64 = 0
        for (_, overlay) in activeTileOverlays {
            total += overlay.getDiskCacheSize()
        }
        return total
    }
}

// MARK: - Basemap Info

struct BasemapInfo: Identifiable {
    let id: String
    let name: String
    let description: String
    let previewURL: String?
    let createOverlay: () -> ArcGISTileOverlay

    var thumbnailURL: URL? {
        guard let urlString = previewURL else { return nil }
        return URL(string: urlString)
    }
}

// MARK: - Tile Overlay Renderer

class ArcGISTileRenderer: MKTileOverlayRenderer {

    override init(tileOverlay overlay: MKTileOverlay) {
        super.init(tileOverlay: overlay)
        self.alpha = 1.0
    }

    /// Set opacity for the tile layer
    func setOpacity(_ opacity: CGFloat) {
        self.alpha = opacity
        setNeedsDisplay()
    }
}
