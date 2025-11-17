//
//  OfflineTileCache.swift
//  OmniTAKMobile
//
//  Offline map tile caching system with MKTileOverlay support
//

import Foundation
import MapKit
import Combine

// MARK: - Cached Tile Overlay

class CachedTileOverlay: MKTileOverlay {

    private let cacheManager: OfflineTileCacheManager

    init(cacheManager: OfflineTileCacheManager) {
        self.cacheManager = cacheManager
        super.init(urlTemplate: nil)

        self.canReplaceMapContent = true
        self.minimumZ = 0
        self.maximumZ = 19
        self.tileSize = CGSize(width: 256, height: 256)
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        // Default to OpenStreetMap
        let urlString = "https://tile.openstreetmap.org/\(path.z)/\(path.x)/\(path.y).png"
        return URL(string: urlString)!
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        // First check cache
        if let cachedData = cacheManager.getTile(at: path) {
            result(cachedData, nil)
            return
        }

        // Download from network
        let tileURL = url(forTilePath: path)

        URLSession.shared.dataTask(with: tileURL) { [weak self] data, response, error in
            if let error = error {
                // Try offline fallback
                if let fallbackData = self?.cacheManager.getFallbackTile(at: path) {
                    result(fallbackData, nil)
                } else {
                    result(nil, error)
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data else {
                result(nil, NSError(domain: "TileCache", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
                return
            }

            // Cache the tile
            self?.cacheManager.cacheTile(data, at: path)

            result(data, nil)
        }.resume()
    }
}

// MARK: - Offline Tile Cache Manager

class OfflineTileCacheManager: ObservableObject {

    static let shared = OfflineTileCacheManager()

    @Published var cacheSize: Int64 = 0
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0
    @Published var lastError: String?

    private let cacheDirectory: URL
    private let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500 MB default
    private let fileManager = FileManager.default

    private var downloadTask: Task<Void, Error>?
    private var tilesToDownload: [MKTileOverlayPath] = []
    private var downloadedCount: Int = 0

    init() {
        let cachesPath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachesPath.appendingPathComponent("MapTileCache", isDirectory: true)

        // Create cache directory
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Calculate current cache size
        updateCacheSize()
    }

    // MARK: - Cache Operations

    func getTile(at path: MKTileOverlayPath) -> Data? {
        let tilePath = tileFilePath(for: path)

        guard fileManager.fileExists(atPath: tilePath.path) else {
            return nil
        }

        return try? Data(contentsOf: tilePath)
    }

    func cacheTile(_ data: Data, at path: MKTileOverlayPath) {
        let tilePath = tileFilePath(for: path)
        let tileDirectory = tilePath.deletingLastPathComponent()

        // Create directory structure
        try? fileManager.createDirectory(at: tileDirectory, withIntermediateDirectories: true)

        // Write tile
        try? data.write(to: tilePath)

        // Update cache size
        cacheSize += Int64(data.count)

        // Check cache limits
        if cacheSize > maxCacheSize {
            Task {
                await cleanupCache()
            }
        }
    }

    func getFallbackTile(at path: MKTileOverlayPath) -> Data? {
        // Try lower zoom level as fallback
        if path.z > 0 {
            let fallbackPath = MKTileOverlayPath(
                x: path.x / 2,
                y: path.y / 2,
                z: path.z - 1,
                contentScaleFactor: path.contentScaleFactor
            )
            return getTile(at: fallbackPath)
        }
        return nil
    }

    private func tileFilePath(for path: MKTileOverlayPath) -> URL {
        return cacheDirectory
            .appendingPathComponent("\(path.z)", isDirectory: true)
            .appendingPathComponent("\(path.x)", isDirectory: true)
            .appendingPathComponent("\(path.y).png")
    }

    // MARK: - Download Tiles for Region

    func downloadTilesForRegion(
        _ region: MKCoordinateRegion,
        minZoom: Int = 10,
        maxZoom: Int = 16,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {

        guard !isDownloading else {
            throw TileCacheError.downloadInProgress
        }

        await MainActor.run {
            isDownloading = true
            downloadProgress = 0
            lastError = nil
        }

        defer {
            Task { @MainActor in
                isDownloading = false
            }
        }

        // Calculate tiles to download
        tilesToDownload = []
        for zoom in minZoom...maxZoom {
            let tiles = tilesInRegion(region, zoom: zoom)
            tilesToDownload.append(contentsOf: tiles)
        }

        let totalTiles = tilesToDownload.count
        downloadedCount = 0

        print("Downloading \(totalTiles) tiles for offline use")

        // Download tiles with rate limiting
        let maxConcurrent = 4
        let batchSize = maxConcurrent

        for batchStart in stride(from: 0, to: tilesToDownload.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, tilesToDownload.count)
            let batch = Array(tilesToDownload[batchStart..<batchEnd])

            // Download batch concurrently
            try await withThrowingTaskGroup(of: Void.self) { group in
                for tile in batch {
                    group.addTask {
                        try await self.downloadTile(at: tile)
                    }
                }

                try await group.waitForAll()
            }

            downloadedCount += batch.count

            let progress = Double(downloadedCount) / Double(totalTiles)

            await MainActor.run {
                self.downloadProgress = progress
            }
            progressHandler?(progress)

            // Rate limiting
            try await Task.sleep(nanoseconds: 250_000_000) // 250ms
        }

        print("Completed downloading \(downloadedCount) tiles")
    }

    private func downloadTile(at path: MKTileOverlayPath) async throws {
        // Skip if already cached
        if getTile(at: path) != nil {
            return
        }

        let urlString = "https://tile.openstreetmap.org/\(path.z)/\(path.x)/\(path.y).png"
        guard let url = URL(string: urlString) else {
            throw TileCacheError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("OmniTAK-iOS/1.0 (Offline Maps)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TileCacheError.invalidResponse
        }

        // Handle rate limiting
        if httpResponse.statusCode == 429 {
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            throw TileCacheError.rateLimited
        }

        guard httpResponse.statusCode == 200 else {
            throw TileCacheError.downloadFailed(httpResponse.statusCode)
        }

        cacheTile(data, at: path)
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil

        Task { @MainActor in
            isDownloading = false
            downloadProgress = 0
        }
    }

    // MARK: - Tile Calculations

    private func tilesInRegion(_ region: MKCoordinateRegion, zoom: Int) -> [MKTileOverlayPath] {
        let center = region.center
        let span = region.span

        let minLat = center.latitude - span.latitudeDelta / 2
        let maxLat = center.latitude + span.latitudeDelta / 2
        let minLon = center.longitude - span.longitudeDelta / 2
        let maxLon = center.longitude + span.longitudeDelta / 2

        let minTile = tileCoordinate(latitude: maxLat, longitude: minLon, zoom: zoom)
        let maxTile = tileCoordinate(latitude: minLat, longitude: maxLon, zoom: zoom)

        var tiles: [MKTileOverlayPath] = []

        for x in minTile.x...maxTile.x {
            for y in minTile.y...maxTile.y {
                let path = MKTileOverlayPath(x: x, y: y, z: zoom, contentScaleFactor: 1.0)
                tiles.append(path)
            }
        }

        return tiles
    }

    private func tileCoordinate(latitude: Double, longitude: Double, zoom: Int) -> (x: Int, y: Int) {
        let n = pow(2.0, Double(zoom))
        let x = Int((longitude + 180.0) / 360.0 * n)
        let latRad = latitude * .pi / 180.0
        let y = Int((1.0 - asinh(tan(latRad)) / .pi) / 2.0 * n)

        return (x, y)
    }

    // MARK: - Cache Management

    func clearCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        Task { @MainActor in
            cacheSize = 0
        }
    }

    func updateCacheSize() {
        let size = calculateDirectorySize(url: cacheDirectory)
        Task { @MainActor in
            cacheSize = size
        }
    }

    private func cleanupCache() async {
        // Remove oldest tiles until under limit
        guard let enumerator = fileManager.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var files: [(URL, Date, Int64)] = []

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let modDate = resourceValues.contentModificationDate,
                  let size = resourceValues.fileSize else {
                continue
            }

            files.append((fileURL, modDate, Int64(size)))
        }

        // Sort by modification date (oldest first)
        files.sort { $0.1 < $1.1 }

        // Remove until under limit
        var currentSize = cacheSize
        let targetSize = maxCacheSize * 80 / 100 // 80% of max

        for (url, _, size) in files {
            if currentSize <= targetSize {
                break
            }

            try? fileManager.removeItem(at: url)
            currentSize -= size
        }

        await MainActor.run {
            cacheSize = currentSize
        }
    }

    private func calculateDirectorySize(url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }
        return totalSize
    }

    var formattedCacheSize: String {
        ByteCountFormatter.string(fromByteCount: cacheSize, countStyle: .file)
    }

    var formattedMaxCacheSize: String {
        ByteCountFormatter.string(fromByteCount: maxCacheSize, countStyle: .file)
    }

    func getCachePercentage() -> Double {
        return Double(cacheSize) / Double(maxCacheSize) * 100
    }
}

// MARK: - Error Types

enum TileCacheError: LocalizedError {
    case downloadInProgress
    case invalidURL
    case invalidResponse
    case rateLimited
    case downloadFailed(Int)
    case cacheFull

    var errorDescription: String? {
        switch self {
        case .downloadInProgress:
            return "A download is already in progress"
        case .invalidURL:
            return "Invalid tile URL"
        case .invalidResponse:
            return "Invalid server response"
        case .rateLimited:
            return "Rate limited by tile server"
        case .downloadFailed(let code):
            return "Download failed with HTTP \(code)"
        case .cacheFull:
            return "Cache storage is full"
        }
    }
}

// MARK: - MKTileOverlayPath Extension

extension MKTileOverlayPath: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(x)
        hasher.combine(y)
        hasher.combine(z)
    }

    public static func == (lhs: MKTileOverlayPath, rhs: MKTileOverlayPath) -> Bool {
        return lhs.x == rhs.x && lhs.y == rhs.y && lhs.z == rhs.z
    }
}

// MARK: - Cached Map View Controller Helper

class CachedMapViewHelper {

    static func setupCachedTileOverlay(for mapView: MKMapView) -> CachedTileOverlay {
        let cacheManager = OfflineTileCacheManager.shared
        let overlay = CachedTileOverlay(cacheManager: cacheManager)

        // Add as base layer
        mapView.addOverlay(overlay, level: .aboveLabels)

        return overlay
    }

    static func renderer(for overlay: MKOverlay) -> MKOverlayRenderer? {
        if let tileOverlay = overlay as? CachedTileOverlay {
            return MKTileOverlayRenderer(tileOverlay: tileOverlay)
        }
        return nil
    }
}
