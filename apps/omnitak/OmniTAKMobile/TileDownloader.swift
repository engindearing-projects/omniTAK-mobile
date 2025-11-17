import Foundation
import MapKit
import Combine

// MARK: - Tile Coordinate

struct TileCoordinate: Hashable, Codable {
    let x: Int
    let y: Int
    let z: Int

    var urlString: String {
        "https://tile.openstreetmap.org/\(z)/\(x)/\(y).png"
    }
}

// MARK: - Tile Downloader

class TileDownloader: ObservableObject {
    @Published var progress: Double = 0
    @Published var isComplete: Bool = false
    @Published var isPaused: Bool = false
    @Published var error: String?

    private let region: OfflineMapRegion
    private let baseDirectory: URL
    private var tilesToDownload: [TileCoordinate] = []
    private var downloadedTiles: Set<TileCoordinate> = []
    private var currentIndex: Int = 0

    private let session: URLSession
    private var downloadTasks: [URLSessionDataTask] = []
    private let maxConcurrentDownloads = 4
    private let rateLimitDelay: TimeInterval = 0.25 // 250ms between requests
    private let semaphore: DispatchSemaphore
    private var isRunning = false
    private var shouldStop = false

    private let downloadQueue = DispatchQueue(label: "com.omnitak.tiledownloader", attributes: .concurrent)

    init(region: OfflineMapRegion, baseDirectory: URL) {
        self.region = region
        self.baseDirectory = baseDirectory

        // Configure URLSession
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 30
        config.httpMaximumConnectionsPerHost = maxConcurrentDownloads

        // Set user agent for OSM
        config.httpAdditionalHeaders = [
            "User-Agent": "OmniTAK-iOS/1.0 (Offline Maps)"
        ]

        self.session = URLSession(configuration: config)
        self.semaphore = DispatchSemaphore(value: maxConcurrentDownloads)

        // Generate tiles list
        generateTilesList()

        // Load progress if resuming
        loadProgress()
    }

    // MARK: - Tile Generation

    private func generateTilesList() {
        tilesToDownload.removeAll()

        for zoom in region.minZoom...region.maxZoom {
            let tiles = TileCalculator.tilesInRegion(region: region.region, zoom: zoom)
            tilesToDownload.append(contentsOf: tiles)
        }

        print("Generated \(tilesToDownload.count) tiles to download")
    }

    // MARK: - Download Control

    func startDownload() {
        guard !isRunning else { return }
        isRunning = true
        shouldStop = false
        isPaused = false

        downloadQueue.async { [weak self] in
            self?.downloadTiles()
        }
    }

    func pauseDownload() {
        shouldStop = true
        isPaused = true
        cancelAllTasks()
        saveProgress()
    }

    func resumeDownload() {
        guard isPaused else { return }
        isPaused = false
        shouldStop = false
        isRunning = true

        downloadQueue.async { [weak self] in
            self?.downloadTiles()
        }
    }

    func cancelDownload() {
        shouldStop = true
        cancelAllTasks()
        clearProgress()
    }

    // MARK: - Download Loop

    private func downloadTiles() {
        let group = DispatchGroup()

        while currentIndex < tilesToDownload.count && !shouldStop {
            guard !isPaused else { break }

            let tile = tilesToDownload[currentIndex]

            // Skip if already downloaded
            if downloadedTiles.contains(tile) || tileExists(tile) {
                currentIndex += 1
                updateProgress()
                continue
            }

            // Wait for semaphore (rate limiting)
            semaphore.wait()
            group.enter()

            downloadTile(tile) { [weak self] success in
                guard let self = self else { return }

                if success {
                    self.downloadedTiles.insert(tile)
                    self.currentIndex += 1
                    self.updateProgress()
                }

                self.semaphore.signal()
                group.leave()

                // Rate limiting delay
                Thread.sleep(forTimeInterval: self.rateLimitDelay)
            }
        }

        // Wait for all downloads to complete
        group.wait()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if !self.shouldStop && self.currentIndex >= self.tilesToDownload.count {
                self.isComplete = true
                self.isRunning = false
                self.clearProgress()
            } else {
                self.isRunning = false
            }
        }
    }

    private func downloadTile(_ tile: TileCoordinate, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: tile.urlString) else {
            completion(false)
            return
        }

        let task = session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else {
                completion(false)
                return
            }

            // Check for errors
            if let error = error {
                print("Download error for tile \(tile): \(error.localizedDescription)")
                completion(false)
                return
            }

            // Check response
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(false)
                return
            }

            // Handle rate limiting (HTTP 429)
            if httpResponse.statusCode == 429 {
                print("Rate limited by OSM, waiting...")
                Thread.sleep(forTimeInterval: 2.0)
                completion(false)
                return
            }

            // Check success
            guard httpResponse.statusCode == 200, let data = data else {
                print("Failed to download tile \(tile): HTTP \(httpResponse.statusCode)")
                completion(false)
                return
            }

            // Save tile
            if self.saveTile(tile, data: data) {
                completion(true)
            } else {
                completion(false)
            }
        }

        downloadTasks.append(task)
        task.resume()
    }

    // MARK: - File Management

    private func saveTile(_ tile: TileCoordinate, data: Data) -> Bool {
        let tileDirectory = baseDirectory
            .appendingPathComponent("tiles", isDirectory: true)
            .appendingPathComponent("\(tile.z)", isDirectory: true)
            .appendingPathComponent("\(tile.x)", isDirectory: true)

        let tilePath = tileDirectory.appendingPathComponent("\(tile.y).png")

        do {
            try FileManager.default.createDirectory(at: tileDirectory, withIntermediateDirectories: true)
            try data.write(to: tilePath)
            return true
        } catch {
            print("Failed to save tile \(tile): \(error)")
            return false
        }
    }

    private func tileExists(_ tile: TileCoordinate) -> Bool {
        let tilePath = baseDirectory
            .appendingPathComponent("tiles", isDirectory: true)
            .appendingPathComponent("\(tile.z)", isDirectory: true)
            .appendingPathComponent("\(tile.x)", isDirectory: true)
            .appendingPathComponent("\(tile.y).png")

        return FileManager.default.fileExists(atPath: tilePath.path)
    }

    private func cancelAllTasks() {
        downloadTasks.forEach { $0.cancel() }
        downloadTasks.removeAll()
    }

    // MARK: - Progress Management

    private func updateProgress() {
        let downloaded = Double(downloadedTiles.count)
        let total = Double(tilesToDownload.count)

        DispatchQueue.main.async { [weak self] in
            self?.progress = total > 0 ? downloaded / total : 0
        }

        // Save progress periodically (every 100 tiles)
        if downloadedTiles.count % 100 == 0 {
            saveProgress()
        }
    }

    private func saveProgress() {
        let progressFile = baseDirectory.appendingPathComponent("progress.json")

        let progressData: [String: Any] = [
            "currentIndex": currentIndex,
            "downloadedTiles": downloadedTiles.map { ["x": $0.x, "y": $0.y, "z": $0.z] }
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: progressData)
            try data.write(to: progressFile)
        } catch {
            print("Failed to save progress: \(error)")
        }
    }

    private func loadProgress() {
        let progressFile = baseDirectory.appendingPathComponent("progress.json")

        guard FileManager.default.fileExists(atPath: progressFile.path) else { return }

        do {
            let data = try Data(contentsOf: progressFile)
            if let progressData = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let index = progressData["currentIndex"] as? Int,
               let tiles = progressData["downloadedTiles"] as? [[String: Int]] {

                currentIndex = index

                downloadedTiles = Set(tiles.compactMap { dict in
                    guard let x = dict["x"], let y = dict["y"], let z = dict["z"] else { return nil }
                    return TileCoordinate(x: x, y: y, z: z)
                })

                print("Resumed progress: \(downloadedTiles.count) tiles already downloaded")
            }
        } catch {
            print("Failed to load progress: \(error)")
        }
    }

    private func clearProgress() {
        let progressFile = baseDirectory.appendingPathComponent("progress.json")
        try? FileManager.default.removeItem(at: progressFile)
    }
}

// MARK: - Download Statistics

extension TileDownloader {
    var downloadedCount: Int {
        downloadedTiles.count
    }

    var totalCount: Int {
        tilesToDownload.count
    }

    var remainingCount: Int {
        totalCount - downloadedCount
    }

    var estimatedTimeRemaining: TimeInterval {
        guard downloadedCount > 0 else { return 0 }

        let averageTimePerTile = rateLimitDelay * Double(maxConcurrentDownloads)
        return averageTimePerTile * Double(remainingCount)
    }

    var formattedTimeRemaining: String {
        let seconds = Int(estimatedTimeRemaining)
        let minutes = seconds / 60
        let hours = minutes / 60

        if hours > 0 {
            return "\(hours)h \(minutes % 60)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds % 60)s"
        } else {
            return "\(seconds)s"
        }
    }
}
