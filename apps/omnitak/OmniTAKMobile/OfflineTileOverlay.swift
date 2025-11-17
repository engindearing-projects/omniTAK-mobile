import Foundation
import MapKit

// MARK: - Offline Tile Overlay

class OfflineTileOverlay: MKTileOverlay {
    private let offlineMapManager: OfflineMapManager
    private let networkMonitor: NetworkMonitor
    private var activeRegion: OfflineMapRegion?

    // Placeholder tile for missing/loading tiles
    private lazy var placeholderTile: Data? = {
        return generatePlaceholderTile()
    }()

    init(offlineMapManager: OfflineMapManager = .shared,
         networkMonitor: NetworkMonitor = .shared) {
        self.offlineMapManager = offlineMapManager
        self.networkMonitor = networkMonitor

        super.init(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png")

        self.canReplaceMapContent = false
        self.minimumZ = 0
        self.maximumZ = 19
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        let tileCoordinate = TileCoordinate(x: path.x, y: path.y, z: path.z)

        // Convert tile path to geographic coordinate to find region
        let coord = coordinateForTile(path)

        // Try to find a region containing this coordinate at this zoom level
        if let region = offlineMapManager.findRegionContaining(coordinate: coord, zoom: path.z) {
            if let tilePath = offlineMapManager.tilePath(for: tileCoordinate, regionId: region.id) {
                return tilePath
            }
        }

        // If network is available, return online URL
        if networkMonitor.isConnected {
            return URL(string: tileCoordinate.urlString)!
        }

        // Return a local placeholder URL
        return URL(string: "about:blank")!
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let tileCoordinate = TileCoordinate(x: path.x, y: path.y, z: path.z)
        let coord = coordinateForTile(path)

        // Priority 1: Try to load from offline cache
        if let region = offlineMapManager.findRegionContaining(coordinate: coord, zoom: path.z),
           let tilePath = offlineMapManager.tilePath(for: tileCoordinate, regionId: region.id) {

            do {
                let data = try Data(contentsOf: tilePath)
                result(data, nil)
                return
            } catch {
                print("Failed to load cached tile: \(error)")
            }
        }

        // Priority 2: If online, try to download tile
        if networkMonitor.isConnected {
            downloadTile(at: path, result: result)
            return
        }

        // Priority 3: Return placeholder tile
        result(placeholderTile, nil)
    }

    // MARK: - Online Tile Download

    private func downloadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let tileCoordinate = TileCoordinate(x: path.x, y: path.y, z: path.z)

        guard let url = URL(string: tileCoordinate.urlString) else {
            result(placeholderTile, nil)
            return
        }

        var request = URLRequest(url: url)
        request.setValue("OmniTAK-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("Tile download error: \(error.localizedDescription)")
                result(self?.placeholderTile, nil)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data else {
                result(self?.placeholderTile, nil)
                return
            }

            result(data, nil)
        }

        task.resume()
    }

    // MARK: - Helper Methods

    private func coordinateForTile(_ path: MKTileOverlayPath) -> CLLocationCoordinate2D {
        let n = pow(2.0, Double(path.z))
        let lon = Double(path.x) / n * 360.0 - 180.0
        let lat_rad = atan(sinh(.pi * (1.0 - 2.0 * Double(path.y) / n)))
        let lat = lat_rad * 180.0 / .pi

        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func generatePlaceholderTile() -> Data? {
        // Create a simple gray placeholder tile (256x256)
        let size = CGSize(width: 256, height: 256)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { context in
            // Gray background
            UIColor(white: 0.9, alpha: 1.0).setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Grid pattern
            UIColor(white: 0.85, alpha: 1.0).setStroke()
            context.cgContext.setLineWidth(1.0)

            for i in stride(from: 0, through: 256, by: 32) {
                context.cgContext.move(to: CGPoint(x: Double(i), y: 0))
                context.cgContext.addLine(to: CGPoint(x: Double(i), y: 256))
                context.cgContext.strokePath()

                context.cgContext.move(to: CGPoint(x: 0, y: Double(i)))
                context.cgContext.addLine(to: CGPoint(x: 256, y: Double(i)))
                context.cgContext.strokePath()
            }

            // "No Map" text
            let text = "No Map"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .medium),
                .foregroundColor: UIColor.gray
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
}

// MARK: - Offline Tile Renderer (Alternative Approach)

class OfflineTileRenderer: NSObject {
    private let overlay: OfflineTileOverlay

    init(overlay: OfflineTileOverlay) {
        self.overlay = overlay
        super.init()
    }
}

// MARK: - MKTileOverlayRenderer Extension

extension MKTileOverlayRenderer {
    convenience init(offlineOverlay: OfflineTileOverlay) {
        self.init(tileOverlay: offlineOverlay)
    }
}
