import Foundation
import MapKit
import Combine

// MARK: - Offline Map Region Model

struct OfflineMapRegion: Identifiable, Codable {
    let id: UUID
    var name: String
    let centerLatitude: Double
    let centerLongitude: Double
    let latitudeDelta: Double
    let longitudeDelta: Double
    let minZoom: Int
    let maxZoom: Int
    var dateCreated: Date
    var totalTiles: Int
    var downloadedTiles: Int
    var estimatedSizeBytes: Int64
    var actualSizeBytes: Int64

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }

    var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }

    var isComplete: Bool {
        downloadedTiles >= totalTiles
    }

    var progress: Double {
        guard totalTiles > 0 else { return 0 }
        return Double(downloadedTiles) / Double(totalTiles)
    }

    var formattedSize: String {
        let bytes = actualSizeBytes > 0 ? actualSizeBytes : estimatedSizeBytes
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    init(id: UUID = UUID(),
         name: String,
         center: CLLocationCoordinate2D,
         span: MKCoordinateSpan,
         minZoom: Int,
         maxZoom: Int) {
        self.id = id
        self.name = name
        self.centerLatitude = center.latitude
        self.centerLongitude = center.longitude
        self.latitudeDelta = span.latitudeDelta
        self.longitudeDelta = span.longitudeDelta
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.dateCreated = Date()
        self.totalTiles = 0
        self.downloadedTiles = 0
        self.estimatedSizeBytes = 0
        self.actualSizeBytes = 0
    }
}

// MARK: - Offline Map Manager

class OfflineMapManager: ObservableObject {
    static let shared = OfflineMapManager()

    @Published var regions: [OfflineMapRegion] = []
    @Published var currentDownload: OfflineMapRegion?
    @Published var downloadProgress: Double = 0
    @Published var isDownloading: Bool = false
    @Published var downloadError: String?

    private var tileDownloader: TileDownloader?
    private var cancellables = Set<AnyCancellable>()

    private let baseDirectory: URL
    private let regionsFile: URL

    init() {
        // Setup directories
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        baseDirectory = documentsPath.appendingPathComponent("OfflineMaps", isDirectory: true)
        regionsFile = baseDirectory.appendingPathComponent("regions.json")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)

        // Load saved regions
        loadRegions()
    }

    // MARK: - Region Management

    func addRegion(_ region: OfflineMapRegion) {
        var newRegion = region

        // Calculate total tiles
        let tiles = TileCalculator.calculateTileCount(
            region: region.region,
            minZoom: region.minZoom,
            maxZoom: region.maxZoom
        )
        newRegion.totalTiles = tiles

        // Estimate size (average ~25KB per tile)
        newRegion.estimatedSizeBytes = Int64(tiles) * 25_000

        regions.append(newRegion)
        saveRegions()
    }

    func deleteRegion(_ region: OfflineMapRegion) {
        // Delete files
        let regionPath = regionDirectory(for: region.id)
        try? FileManager.default.removeItem(at: regionPath)

        // Remove from array
        regions.removeAll { $0.id == region.id }
        saveRegions()
    }

    func updateRegion(_ region: OfflineMapRegion) {
        if let index = regions.firstIndex(where: { $0.id == region.id }) {
            regions[index] = region
            saveRegions()
        }
    }

    // MARK: - Download Management

    func startDownload(region: OfflineMapRegion) {
        guard !isDownloading else {
            print("Download already in progress")
            return
        }

        isDownloading = true
        currentDownload = region
        downloadProgress = 0
        downloadError = nil

        // Create region directory
        let regionPath = regionDirectory(for: region.id)
        try? FileManager.default.createDirectory(at: regionPath, withIntermediateDirectories: true)

        // Initialize downloader
        tileDownloader = TileDownloader(region: region, baseDirectory: regionPath)

        // Subscribe to progress
        tileDownloader?.$progress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.downloadProgress = progress

                // Update region progress
                if let index = self?.regions.firstIndex(where: { $0.id == region.id }) {
                    self?.regions[index].downloadedTiles = Int(progress * Double(region.totalTiles))
                    self?.saveRegions()
                }
            }
            .store(in: &cancellables)

        tileDownloader?.$isComplete
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isComplete in
                if isComplete {
                    self?.finishDownload()
                }
            }
            .store(in: &cancellables)

        tileDownloader?.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if let error = error {
                    self?.downloadError = error
                    self?.cancelDownload()
                }
            }
            .store(in: &cancellables)

        // Start download
        tileDownloader?.startDownload()
    }

    func pauseDownload() {
        tileDownloader?.pauseDownload()
        isDownloading = false
    }

    func resumeDownload() {
        guard currentDownload != nil else { return }
        isDownloading = true
        tileDownloader?.resumeDownload()
    }

    func cancelDownload() {
        tileDownloader?.cancelDownload()
        isDownloading = false
        currentDownload = nil
        downloadProgress = 0
        tileDownloader = nil
    }

    private func finishDownload() {
        guard let region = currentDownload else { return }

        // Calculate actual size
        let regionPath = regionDirectory(for: region.id)
        let actualSize = calculateDirectorySize(url: regionPath)

        // Update region
        if let index = regions.firstIndex(where: { $0.id == region.id }) {
            regions[index].downloadedTiles = regions[index].totalTiles
            regions[index].actualSizeBytes = actualSize
            saveRegions()
        }

        isDownloading = false
        currentDownload = nil
        downloadProgress = 0
        tileDownloader = nil

        print("Download completed for region: \(region.name)")
    }

    // MARK: - Tile Access

    func tilePath(for coordinate: TileCoordinate, regionId: UUID) -> URL? {
        let regionPath = regionDirectory(for: regionId)
        let tilePath = regionPath
            .appendingPathComponent("tiles", isDirectory: true)
            .appendingPathComponent("\(coordinate.z)", isDirectory: true)
            .appendingPathComponent("\(coordinate.x)", isDirectory: true)
            .appendingPathComponent("\(coordinate.y).png")

        return FileManager.default.fileExists(atPath: tilePath.path) ? tilePath : nil
    }

    func findRegionContaining(coordinate: CLLocationCoordinate2D, zoom: Int) -> OfflineMapRegion? {
        return regions.first { region in
            region.isComplete &&
            zoom >= region.minZoom &&
            zoom <= region.maxZoom &&
            region.region.contains(coordinate)
        }
    }

    // MARK: - Persistence

    private func saveRegions() {
        do {
            let data = try JSONEncoder().encode(regions)
            try data.write(to: regionsFile)
        } catch {
            print("Failed to save regions: \(error)")
        }
    }

    private func loadRegions() {
        guard FileManager.default.fileExists(atPath: regionsFile.path) else { return }

        do {
            let data = try Data(contentsOf: regionsFile)
            regions = try JSONDecoder().decode([OfflineMapRegion].self, from: data)
        } catch {
            print("Failed to load regions: \(error)")
        }
    }

    // MARK: - Helpers

    func regionDirectory(for id: UUID) -> URL {
        return baseDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    private func calculateDirectorySize(url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
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

    func getTotalStorageUsed() -> Int64 {
        return regions.reduce(0) { $0 + $1.actualSizeBytes }
    }
}

// MARK: - Tile Calculator

struct TileCalculator {
    static func calculateTileCount(region: MKCoordinateRegion, minZoom: Int, maxZoom: Int) -> Int {
        var total = 0

        for zoom in minZoom...maxZoom {
            let tiles = tilesInRegion(region: region, zoom: zoom)
            total += tiles.count
        }

        return total
    }

    static func tilesInRegion(region: MKCoordinateRegion, zoom: Int) -> [TileCoordinate] {
        let center = region.center
        let span = region.span

        let minLat = center.latitude - span.latitudeDelta / 2
        let maxLat = center.latitude + span.latitudeDelta / 2
        let minLon = center.longitude - span.longitudeDelta / 2
        let maxLon = center.longitude + span.longitudeDelta / 2

        let minTile = tileCoordinate(latitude: maxLat, longitude: minLon, zoom: zoom)
        let maxTile = tileCoordinate(latitude: minLat, longitude: maxLon, zoom: zoom)

        var tiles: [TileCoordinate] = []

        for x in minTile.x...maxTile.x {
            for y in minTile.y...maxTile.y {
                tiles.append(TileCoordinate(x: x, y: y, z: zoom))
            }
        }

        return tiles
    }

    static func tileCoordinate(latitude: Double, longitude: Double, zoom: Int) -> TileCoordinate {
        let n = pow(2.0, Double(zoom))
        let x = Int((longitude + 180.0) / 360.0 * n)
        let latRad = latitude * .pi / 180.0
        let y = Int((1.0 - asinh(tan(latRad)) / .pi) / 2.0 * n)

        return TileCoordinate(x: x, y: y, z: zoom)
    }
}

// MARK: - MKCoordinateRegion Extension

extension MKCoordinateRegion {
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let halfLatDelta = span.latitudeDelta / 2
        let halfLonDelta = span.longitudeDelta / 2

        let minLat = center.latitude - halfLatDelta
        let maxLat = center.latitude + halfLatDelta
        let minLon = center.longitude - halfLonDelta
        let maxLon = center.longitude + halfLonDelta

        return coordinate.latitude >= minLat &&
               coordinate.latitude <= maxLat &&
               coordinate.longitude >= minLon &&
               coordinate.longitude <= maxLon
    }
}
