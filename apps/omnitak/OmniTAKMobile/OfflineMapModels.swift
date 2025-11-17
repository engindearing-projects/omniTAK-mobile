//
//  OfflineMapModels.swift
//  OmniTAKMobile
//
//  Enhanced data models for offline map tile caching system
//

import Foundation
import MapKit

// MARK: - Tile Source

enum TileSource: String, Codable, CaseIterable, Identifiable {
    case osm = "OpenStreetMap"
    case satellite = "Satellite"
    case hybrid = "Hybrid"
    case terrain = "Terrain"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .osm: return "OpenStreetMap"
        case .satellite: return "Satellite Imagery"
        case .hybrid: return "Hybrid (Sat + Labels)"
        case .terrain: return "Terrain"
        }
    }

    var icon: String {
        switch self {
        case .osm: return "map"
        case .satellite: return "globe.americas"
        case .hybrid: return "map.fill"
        case .terrain: return "mountain.2"
        }
    }

    var urlTemplate: String {
        switch self {
        case .osm:
            return "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        case .satellite:
            // Using ESRI World Imagery (free tier)
            return "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
        case .hybrid:
            // ESRI World Imagery with labels
            return "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
        case .terrain:
            // Using OpenTopoMap
            return "https://tile.opentopomap.org/{z}/{x}/{y}.png"
        }
    }

    func tileURL(x: Int, y: Int, z: Int) -> URL? {
        let urlString = urlTemplate
            .replacingOccurrences(of: "{x}", with: "\(x)")
            .replacingOccurrences(of: "{y}", with: "\(y)")
            .replacingOccurrences(of: "{z}", with: "\(z)")
        return URL(string: urlString)
    }

    var userAgent: String {
        switch self {
        case .osm:
            return "OmniTAK-iOS/1.0 (Offline Maps; Contact: tak-support@example.com)"
        case .satellite, .hybrid:
            return "OmniTAK-iOS/1.0"
        case .terrain:
            return "OmniTAK-iOS/1.0 (Offline Maps)"
        }
    }

    var maxZoom: Int {
        switch self {
        case .osm: return 19
        case .satellite, .hybrid: return 18
        case .terrain: return 17
        }
    }

    var averageTileSizeBytes: Int64 {
        switch self {
        case .osm: return 25_000 // ~25 KB
        case .satellite: return 60_000 // ~60 KB
        case .hybrid: return 65_000 // ~65 KB
        case .terrain: return 35_000 // ~35 KB
        }
    }
}

// MARK: - Cached Region

struct CachedRegion: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let northLatitude: Double
    let southLatitude: Double
    let eastLongitude: Double
    let westLongitude: Double
    let minZoomLevel: Int
    let maxZoomLevel: Int
    let tileSource: TileSource
    var downloadDate: Date
    var lastAccessDate: Date
    var sizeBytes: Int64
    var totalTiles: Int
    var downloadedTiles: Int
    var expirationDate: Date?

    // Computed properties
    var bounds: MKCoordinateRegion {
        let centerLat = (northLatitude + southLatitude) / 2
        let centerLon = (eastLongitude + westLongitude) / 2
        let latDelta = northLatitude - southLatitude
        let lonDelta = eastLongitude - westLongitude

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }

    var isComplete: Bool {
        downloadedTiles >= totalTiles
    }

    var downloadProgress: Double {
        guard totalTiles > 0 else { return 0 }
        return Double(downloadedTiles) / Double(totalTiles)
    }

    var isExpired: Bool {
        guard let expiration = expirationDate else { return false }
        return Date() > expiration
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: downloadDate)
    }

    var zoomRangeDescription: String {
        "Z\(minZoomLevel) - Z\(maxZoomLevel)"
    }

    init(
        id: UUID = UUID(),
        name: String,
        north: Double,
        south: Double,
        east: Double,
        west: Double,
        minZoom: Int,
        maxZoom: Int,
        source: TileSource
    ) {
        self.id = id
        self.name = name
        self.northLatitude = north
        self.southLatitude = south
        self.eastLongitude = east
        self.westLongitude = west
        self.minZoomLevel = minZoom
        self.maxZoomLevel = maxZoom
        self.tileSource = source
        self.downloadDate = Date()
        self.lastAccessDate = Date()
        self.sizeBytes = 0
        self.totalTiles = 0
        self.downloadedTiles = 0
        // Default expiration: 30 days
        self.expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
    }

    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        coordinate.latitude >= southLatitude &&
        coordinate.latitude <= northLatitude &&
        coordinate.longitude >= westLongitude &&
        coordinate.longitude <= eastLongitude
    }

    func containsZoom(_ zoom: Int) -> Bool {
        zoom >= minZoomLevel && zoom <= maxZoomLevel
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CachedRegion, rhs: CachedRegion) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Tile Coordinate (Enhanced)

struct TileCoordinateV2: Hashable, Codable, Equatable {
    let x: Int
    let y: Int
    let z: Int
    let source: TileSource

    var cacheKey: String {
        "\(source.rawValue)/\(z)/\(x)/\(y)"
    }

    var relativePath: String {
        "\(source.rawValue)/\(z)/\(x)/\(y).png"
    }

    func url() -> URL? {
        source.tileURL(x: x, y: y, z: z)
    }

    static func fromCoordinate(
        latitude: Double,
        longitude: Double,
        zoom: Int,
        source: TileSource = .osm
    ) -> TileCoordinateV2 {
        let n = pow(2.0, Double(zoom))
        let x = Int((longitude + 180.0) / 360.0 * n)
        let latRad = latitude * .pi / 180.0
        let y = Int((1.0 - asinh(tan(latRad)) / .pi) / 2.0 * n)

        return TileCoordinateV2(x: x, y: y, z: zoom, source: source)
    }

    func toCoordinate() -> CLLocationCoordinate2D {
        let n = pow(2.0, Double(z))
        let lon = Double(x) / n * 360.0 - 180.0
        let latRad = atan(sinh(.pi * (1.0 - 2.0 * Double(y) / n)))
        let lat = latRad * 180.0 / .pi

        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - Download Progress

struct DownloadProgress: Identifiable {
    let id: UUID
    var regionId: UUID
    var regionName: String
    var totalTiles: Int
    var downloadedTiles: Int
    var failedTiles: Int
    var bytesDownloaded: Int64
    var startTime: Date
    var isPaused: Bool
    var isCancelled: Bool
    var lastError: String?
    var currentTile: TileCoordinateV2?

    var progress: Double {
        guard totalTiles > 0 else { return 0 }
        return Double(downloadedTiles) / Double(totalTiles)
    }

    var percentComplete: Int {
        Int(progress * 100)
    }

    var remainingTiles: Int {
        max(0, totalTiles - downloadedTiles)
    }

    var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startTime)
    }

    var estimatedTimeRemaining: TimeInterval {
        guard downloadedTiles > 0 else { return 0 }
        let timePerTile = elapsedTime / Double(downloadedTiles)
        return timePerTile * Double(remainingTiles)
    }

    var formattedProgress: String {
        "\(downloadedTiles) / \(totalTiles)"
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: bytesDownloaded, countStyle: .file)
    }

    var formattedTimeRemaining: String {
        let seconds = Int(estimatedTimeRemaining)
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            let secs = seconds % 60
            return "\(minutes)m \(secs)s"
        } else {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            return "\(hours)h \(minutes)m"
        }
    }

    var downloadSpeed: String {
        guard elapsedTime > 0 else { return "-- KB/s" }
        let bytesPerSecond = Double(bytesDownloaded) / elapsedTime
        if bytesPerSecond < 1024 {
            return "\(Int(bytesPerSecond)) B/s"
        } else if bytesPerSecond < 1048576 {
            return "\(Int(bytesPerSecond / 1024)) KB/s"
        } else {
            return String(format: "%.1f MB/s", bytesPerSecond / 1048576)
        }
    }

    init(regionId: UUID, regionName: String, totalTiles: Int) {
        self.id = UUID()
        self.regionId = regionId
        self.regionName = regionName
        self.totalTiles = totalTiles
        self.downloadedTiles = 0
        self.failedTiles = 0
        self.bytesDownloaded = 0
        self.startTime = Date()
        self.isPaused = false
        self.isCancelled = false
        self.lastError = nil
        self.currentTile = nil
    }
}

// MARK: - Cache Statistics

struct CacheStatistics {
    var totalRegions: Int
    var completeRegions: Int
    var totalSizeBytes: Int64
    var totalTiles: Int
    var oldestRegion: Date?
    var newestRegion: Date?
    var expiredRegions: Int
    var sizeBySource: [TileSource: Int64]
    var regionsBySizeTop5: [(name: String, size: Int64)]

    var totalSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .file)
    }

    var averageRegionSize: Int64 {
        guard totalRegions > 0 else { return 0 }
        return totalSizeBytes / Int64(totalRegions)
    }

    var averageRegionSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: averageRegionSize, countStyle: .file)
    }

    init() {
        self.totalRegions = 0
        self.completeRegions = 0
        self.totalSizeBytes = 0
        self.totalTiles = 0
        self.oldestRegion = nil
        self.newestRegion = nil
        self.expiredRegions = 0
        self.sizeBySource = [:]
        self.regionsBySizeTop5 = []
    }

    static func calculate(from regions: [CachedRegion]) -> CacheStatistics {
        var stats = CacheStatistics()

        stats.totalRegions = regions.count
        stats.completeRegions = regions.filter { $0.isComplete }.count
        stats.totalSizeBytes = regions.reduce(0) { $0 + $1.sizeBytes }
        stats.totalTiles = regions.reduce(0) { $0 + $1.downloadedTiles }
        stats.expiredRegions = regions.filter { $0.isExpired }.count

        // Calculate size by source
        var bySource: [TileSource: Int64] = [:]
        for region in regions {
            bySource[region.tileSource, default: 0] += region.sizeBytes
        }
        stats.sizeBySource = bySource

        // Find oldest and newest
        let sorted = regions.sorted { $0.downloadDate < $1.downloadDate }
        stats.oldestRegion = sorted.first?.downloadDate
        stats.newestRegion = sorted.last?.downloadDate

        // Top 5 by size
        let sortedBySize = regions.sorted { $0.sizeBytes > $1.sizeBytes }
        stats.regionsBySizeTop5 = Array(sortedBySize.prefix(5)).map { ($0.name, $0.sizeBytes) }

        return stats
    }
}

// MARK: - Download Configuration

struct DownloadConfiguration {
    var maxConcurrentDownloads: Int = 4
    var rateLimitDelay: TimeInterval = 0.25 // 250ms
    var retryAttempts: Int = 3
    var timeoutInterval: TimeInterval = 30
    var allowExpensiveNetwork: Bool = false
    var pauseOnBatteryLow: Bool = true
    var maxCacheSizeBytes: Int64 = 1024 * 1024 * 1024 // 1 GB
    var defaultExpirationDays: Int = 30
}

// MARK: - Tile Calculation Helpers

struct TileCalculationResult {
    let totalTiles: Int
    let estimatedSizeBytes: Int64
    let estimatedTimeSeconds: TimeInterval
    let tilesPerZoom: [Int: Int]

    var estimatedSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: estimatedSizeBytes, countStyle: .file)
    }

    var estimatedTimeFormatted: String {
        let seconds = Int(estimatedTimeSeconds)
        if seconds < 60 {
            return "\(seconds) seconds"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes) minutes"
        } else {
            let hours = seconds / 3600
            let minutes = (seconds % 3600) / 60
            return "\(hours)h \(minutes)m"
        }
    }
}

enum TileCalculationHelper {
    static func calculateTilesForRegion(
        north: Double,
        south: Double,
        east: Double,
        west: Double,
        minZoom: Int,
        maxZoom: Int,
        source: TileSource
    ) -> TileCalculationResult {
        var totalTiles = 0
        var tilesPerZoom: [Int: Int] = [:]

        for zoom in minZoom...min(maxZoom, source.maxZoom) {
            let count = tilesInBounds(
                north: north,
                south: south,
                east: east,
                west: west,
                zoom: zoom
            )
            tilesPerZoom[zoom] = count
            totalTiles += count
        }

        let estimatedSize = Int64(totalTiles) * source.averageTileSizeBytes
        let estimatedTime = Double(totalTiles) * 0.25 // 250ms per tile with rate limiting

        return TileCalculationResult(
            totalTiles: totalTiles,
            estimatedSizeBytes: estimatedSize,
            estimatedTimeSeconds: estimatedTime,
            tilesPerZoom: tilesPerZoom
        )
    }

    static func tilesInBounds(
        north: Double,
        south: Double,
        east: Double,
        west: Double,
        zoom: Int
    ) -> Int {
        let minTile = tileXY(latitude: north, longitude: west, zoom: zoom)
        let maxTile = tileXY(latitude: south, longitude: east, zoom: zoom)

        let xCount = abs(maxTile.x - minTile.x) + 1
        let yCount = abs(maxTile.y - minTile.y) + 1

        return xCount * yCount
    }

    static func tileXY(latitude: Double, longitude: Double, zoom: Int) -> (x: Int, y: Int) {
        let n = pow(2.0, Double(zoom))
        let x = Int((longitude + 180.0) / 360.0 * n)
        let latRad = latitude * .pi / 180.0
        let y = Int((1.0 - asinh(tan(latRad)) / .pi) / 2.0 * n)

        return (x, y)
    }

    static func generateTileList(
        north: Double,
        south: Double,
        east: Double,
        west: Double,
        minZoom: Int,
        maxZoom: Int,
        source: TileSource
    ) -> [TileCoordinateV2] {
        var tiles: [TileCoordinateV2] = []

        for zoom in minZoom...min(maxZoom, source.maxZoom) {
            let minTile = tileXY(latitude: north, longitude: west, zoom: zoom)
            let maxTile = tileXY(latitude: south, longitude: east, zoom: zoom)

            let xStart = min(minTile.x, maxTile.x)
            let xEnd = max(minTile.x, maxTile.x)
            let yStart = min(minTile.y, maxTile.y)
            let yEnd = max(minTile.y, maxTile.y)

            for x in xStart...xEnd {
                for y in yStart...yEnd {
                    tiles.append(TileCoordinateV2(x: x, y: y, z: zoom, source: source))
                }
            }
        }

        return tiles
    }
}
