import Foundation
import Combine
import MapKit

// MARK: - Drawing Store

class DrawingStore: ObservableObject {
    @Published var markers: [MarkerDrawing] = []
    @Published var lines: [LineDrawing] = []
    @Published var circles: [CircleDrawing] = []
    @Published var polygons: [PolygonDrawing] = []

    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // UserDefaults keys
    private let markersKey = "DrawingStore.markers"
    private let linesKey = "DrawingStore.lines"
    private let routesKey = "DrawingStore.routes"  // Legacy key for backward compatibility
    private let circlesKey = "DrawingStore.circles"
    private let polygonsKey = "DrawingStore.polygons"

    init() {
        loadAllDrawings()
    }

    // MARK: - Load Drawings

    func loadAllDrawings() {
        loadMarkers()
        loadLines()
        loadCircles()
        loadPolygons()
        print("Loaded drawings - Markers: \(markers.count), Lines: \(lines.count), Circles: \(circles.count), Polygons: \(polygons.count)")
    }

    private func loadMarkers() {
        guard let data = userDefaults.data(forKey: markersKey) else {
            markers = []
            return
        }

        do {
            markers = try decoder.decode([MarkerDrawing].self, from: data)
        } catch {
            print("Failed to load markers: \(error)")
            markers = []
        }
    }

    private func loadLines() {
        // Try loading from new lines key first
        if let data = userDefaults.data(forKey: linesKey) {
            do {
                lines = try decoder.decode([LineDrawing].self, from: data)
                print("Loaded \(lines.count) lines from new format")
                return
            } catch {
                print("Failed to load lines from new format: \(error)")
            }
        }

        // Fallback to legacy routes key for backward compatibility
        if let legacyData = userDefaults.data(forKey: routesKey) {
            do {
                // Define a temporary RouteDrawing struct for migration
                struct LegacyRouteDrawing: Codable {
                    let id: UUID
                    var name: String
                    var color: DrawingColor
                    let createdAt: Date
                    var coordinates: [CoordinatePair]

                    struct CoordinatePair: Codable {
                        let latitude: Double
                        let longitude: Double
                    }
                }

                let legacyRoutes = try decoder.decode([LegacyRouteDrawing].self, from: legacyData)

                // Migrate to LineDrawing format
                lines = legacyRoutes.map { route in
                    let coords = route.coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                    return LineDrawing(
                        id: route.id,
                        name: route.name,
                        label: route.name,
                        color: route.color,
                        coordinates: coords
                    )
                }

                // Save in new format and remove legacy data
                saveLines()
                userDefaults.removeObject(forKey: routesKey)
                print("Migrated \(lines.count) legacy routes to lines")
                return
            } catch {
                print("Failed to migrate legacy routes: \(error)")
            }
        }

        lines = []
    }

    private func loadCircles() {
        guard let data = userDefaults.data(forKey: circlesKey) else {
            circles = []
            return
        }

        do {
            circles = try decoder.decode([CircleDrawing].self, from: data)
        } catch {
            print("Failed to load circles: \(error)")
            circles = []
        }
    }

    private func loadPolygons() {
        guard let data = userDefaults.data(forKey: polygonsKey) else {
            polygons = []
            return
        }

        do {
            polygons = try decoder.decode([PolygonDrawing].self, from: data)
        } catch {
            print("Failed to load polygons: \(error)")
            polygons = []
        }
    }

    // MARK: - Save Drawings

    func saveAllDrawings() {
        saveMarkers()
        saveLines()
        saveCircles()
        savePolygons()
    }

    private func saveMarkers() {
        do {
            let data = try encoder.encode(markers)
            userDefaults.set(data, forKey: markersKey)
            print("Saved \(markers.count) markers")
        } catch {
            print("Failed to save markers: \(error)")
        }
    }

    private func saveLines() {
        do {
            let data = try encoder.encode(lines)
            userDefaults.set(data, forKey: linesKey)
            print("Saved \(lines.count) lines")
        } catch {
            print("Failed to save lines: \(error)")
        }
    }

    private func saveCircles() {
        do {
            let data = try encoder.encode(circles)
            userDefaults.set(data, forKey: circlesKey)
            print("Saved \(circles.count) circles")
        } catch {
            print("Failed to save circles: \(error)")
        }
    }

    private func savePolygons() {
        do {
            let data = try encoder.encode(polygons)
            userDefaults.set(data, forKey: polygonsKey)
            print("Saved \(polygons.count) polygons")
        } catch {
            print("Failed to save polygons: \(error)")
        }
    }

    // MARK: - Add Drawings

    func addMarker(_ marker: MarkerDrawing) {
        markers.append(marker)
        saveMarkers()
        print("Added marker: \(marker.name)")
    }

    func addLine(_ line: LineDrawing) {
        lines.append(line)
        saveLines()
        print("Added line: \(line.name)")
    }

    func addCircle(_ circle: CircleDrawing) {
        circles.append(circle)
        saveCircles()
        print("Added circle: \(circle.name)")
    }

    func addPolygon(_ polygon: PolygonDrawing) {
        polygons.append(polygon)
        savePolygons()
        print("Added polygon: \(polygon.name)")
    }

    // MARK: - Update Drawings

    func updateMarker(_ marker: MarkerDrawing) {
        if let index = markers.firstIndex(where: { $0.id == marker.id }) {
            markers[index] = marker
            saveMarkers()
            print("Updated marker: \(marker.name)")
        }
    }

    func updateLine(_ line: LineDrawing) {
        if let index = lines.firstIndex(where: { $0.id == line.id }) {
            lines[index] = line
            saveLines()
            print("Updated line: \(line.name)")
        }
    }

    func updateCircle(_ circle: CircleDrawing) {
        if let index = circles.firstIndex(where: { $0.id == circle.id }) {
            circles[index] = circle
            saveCircles()
            print("Updated circle: \(circle.name)")
        }
    }

    func updatePolygon(_ polygon: PolygonDrawing) {
        if let index = polygons.firstIndex(where: { $0.id == polygon.id }) {
            polygons[index] = polygon
            savePolygons()
            print("Updated polygon: \(polygon.name)")
        }
    }

    // MARK: - Delete Drawings

    func deleteMarker(_ marker: MarkerDrawing) {
        markers.removeAll { $0.id == marker.id }
        saveMarkers()
        print("Deleted marker: \(marker.name)")
    }

    func deleteLine(_ line: LineDrawing) {
        lines.removeAll { $0.id == line.id }
        saveLines()
        print("Deleted line: \(line.name)")
    }

    func deleteCircle(_ circle: CircleDrawing) {
        circles.removeAll { $0.id == circle.id }
        saveCircles()
        print("Deleted circle: \(circle.name)")
    }

    func deletePolygon(_ polygon: PolygonDrawing) {
        polygons.removeAll { $0.id == polygon.id }
        savePolygons()
        print("Deleted polygon: \(polygon.name)")
    }

    // MARK: - Clear All

    func clearAllDrawings() {
        markers.removeAll()
        lines.removeAll()
        circles.removeAll()
        polygons.removeAll()
        saveAllDrawings()
        print("Cleared all drawings")
    }

    // MARK: - Get All Overlays

    func getAllOverlays() -> [MKOverlay] {
        var overlays: [MKOverlay] = []

        // Add circles
        for circle in circles {
            overlays.append(circle.createOverlay())
        }

        // Add polygons
        for polygon in polygons {
            overlays.append(polygon.createOverlay())
        }

        // Add lines
        for line in lines {
            overlays.append(line.createOverlay())
        }

        return overlays
    }

    // MARK: - Helper Methods

    func getDrawingColor(for overlay: MKOverlay) -> DrawingColor? {
        // Check circles
        if let circle = overlay as? MKCircle {
            return circles.first {
                let circleOverlay = $0.createOverlay() as? MKCircle
                return circleOverlay?.coordinate.latitude == circle.coordinate.latitude &&
                       circleOverlay?.coordinate.longitude == circle.coordinate.longitude &&
                       circleOverlay?.radius == circle.radius
            }?.color
        }

        // Check polygons
        if let polygon = overlay as? MKPolygon {
            return polygons.first {
                let polygonOverlay = $0.createOverlay() as? MKPolygon
                return polygonOverlay?.pointCount == polygon.pointCount
            }?.color
        }

        // Check lines
        if let polyline = overlay as? MKPolyline {
            return lines.first {
                let lineOverlay = $0.createOverlay() as? MKPolyline
                return lineOverlay?.pointCount == polyline.pointCount
            }?.color
        }

        return nil
    }

    func getDrawingLabel(for overlay: MKOverlay) -> String? {
        // Check circles
        if let circle = overlay as? MKCircle {
            return circles.first {
                let circleOverlay = $0.createOverlay() as? MKCircle
                return circleOverlay?.coordinate.latitude == circle.coordinate.latitude &&
                       circleOverlay?.coordinate.longitude == circle.coordinate.longitude &&
                       circleOverlay?.radius == circle.radius
            }?.label
        }

        // Check polygons
        if let polygon = overlay as? MKPolygon {
            return polygons.first {
                let polygonOverlay = $0.createOverlay() as? MKPolygon
                return polygonOverlay?.pointCount == polygon.pointCount
            }?.label
        }

        // Check lines
        if let polyline = overlay as? MKPolyline {
            return lines.first {
                let lineOverlay = $0.createOverlay() as? MKPolyline
                return lineOverlay?.pointCount == polyline.pointCount
            }?.label
        }

        return nil
    }

    func totalDrawingCount() -> Int {
        return markers.count + lines.count + circles.count + polygons.count
    }
}
