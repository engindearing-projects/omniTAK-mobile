import Foundation
import MapKit
import Combine

// MARK: - Drawing Tools Manager

class DrawingToolsManager: ObservableObject {
    @Published var isDrawingActive: Bool = false
    @Published var currentMode: DrawingMode?
    @Published var currentColor: DrawingColor = .red
    @Published var temporaryPoints: [CLLocationCoordinate2D] = []
    @Published var isSelectingRadius: Bool = false

    // Circle-specific properties
    private var circleCenter: CLLocationCoordinate2D?

    private let drawingStore: DrawingStore

    init(drawingStore: DrawingStore) {
        self.drawingStore = drawingStore
    }

    // MARK: - Start Drawing

    func startDrawing(mode: DrawingMode) {
        isDrawingActive = true
        currentMode = mode
        temporaryPoints.removeAll()
        circleCenter = nil
        isSelectingRadius = false
        print("Started drawing mode: \(mode.rawValue)")
    }

    // MARK: - Handle Map Tap

    func handleMapTap(at coordinate: CLLocationCoordinate2D) {
        guard isDrawingActive, let mode = currentMode else { return }

        switch mode {
        case .marker:
            createMarker(at: coordinate)

        case .line:
            temporaryPoints.append(coordinate)
            print("Line point added (\(temporaryPoints.count) points)")

        case .circle:
            if circleCenter == nil {
                // First tap - set center
                circleCenter = coordinate
                isSelectingRadius = true
                temporaryPoints = [coordinate]
                print("Circle center set, select radius point")
            } else {
                // Second tap - calculate radius and create circle
                createCircle(radiusPoint: coordinate)
            }

        case .polygon:
            temporaryPoints.append(coordinate)
            print("Polygon point added (\(temporaryPoints.count) points)")
        }
    }

    // MARK: - Create Drawings

    private func createMarker(at coordinate: CLLocationCoordinate2D) {
        let marker = MarkerDrawing(
            name: "Marker \(drawingStore.markers.count + 1)",
            color: currentColor,
            coordinate: coordinate
        )
        drawingStore.addMarker(marker)
        cancelDrawing()
        print("Created marker at \(coordinate.latitude), \(coordinate.longitude)")
    }

    private func createCircle(radiusPoint: CLLocationCoordinate2D) {
        guard let center = circleCenter else { return }

        let radius = center.distance(to: radiusPoint)
        let circle = CircleDrawing(
            name: "Circle \(drawingStore.circles.count + 1)",
            color: currentColor,
            center: center,
            radius: radius
        )
        drawingStore.addCircle(circle)
        cancelDrawing()
        print("Created circle with radius: \(radius)m")
    }

    // MARK: - Complete Drawing

    func completeDrawing() {
        guard isDrawingActive, let mode = currentMode else { return }

        switch mode {
        case .marker:
            // Markers are created immediately
            cancelDrawing()

        case .line:
            if temporaryPoints.count >= 2 {
                let line = LineDrawing(
                    name: "Line \(drawingStore.lines.count + 1)",
                    color: currentColor,
                    coordinates: temporaryPoints
                )
                drawingStore.addLine(line)
                print("Created line with \(temporaryPoints.count) points")
            } else {
                print("Line needs at least 2 points")
            }
            cancelDrawing()

        case .circle:
            // Circles need two points (handled in handleMapTap)
            if circleCenter == nil {
                print("Circle needs center point")
            } else {
                print("Circle needs radius point")
            }

        case .polygon:
            if temporaryPoints.count >= 3 {
                let polygon = PolygonDrawing(
                    name: "Polygon \(drawingStore.polygons.count + 1)",
                    color: currentColor,
                    coordinates: temporaryPoints
                )
                drawingStore.addPolygon(polygon)
                print("Created polygon with \(temporaryPoints.count) points")
            } else {
                print("Polygon needs at least 3 points")
            }
            cancelDrawing()
        }
    }

    // MARK: - Cancel Drawing

    func cancelDrawing() {
        isDrawingActive = false
        currentMode = nil
        temporaryPoints.removeAll()
        circleCenter = nil
        isSelectingRadius = false
        print("Drawing cancelled")
    }

    // MARK: - Temporary Overlays

    func getTemporaryOverlay() -> MKOverlay? {
        guard isDrawingActive, let mode = currentMode else { return nil }

        switch mode {
        case .marker:
            return nil

        case .line:
            if temporaryPoints.count >= 2 {
                return MKPolyline(coordinates: temporaryPoints, count: temporaryPoints.count)
            }

        case .circle:
            if let center = circleCenter, temporaryPoints.count == 2 {
                let radius = center.distance(to: temporaryPoints[1])
                return MKCircle(center: center, radius: radius)
            } else if let center = circleCenter {
                // Show small circle at center while selecting radius
                return MKCircle(center: center, radius: 50)
            }

        case .polygon:
            if temporaryPoints.count >= 2 {
                return MKPolyline(coordinates: temporaryPoints, count: temporaryPoints.count)
            }
        }

        return nil
    }

    func getTemporaryAnnotations() -> [MKPointAnnotation] {
        guard isDrawingActive else { return [] }

        return temporaryPoints.enumerated().map { index, coordinate in
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = "Point \(index + 1)"
            return annotation
        }
    }

    // MARK: - Helper Methods

    func canComplete() -> Bool {
        guard isDrawingActive, let mode = currentMode else { return false }

        switch mode {
        case .marker:
            return false // Markers are created immediately

        case .line:
            return temporaryPoints.count >= 2

        case .circle:
            return circleCenter != nil && temporaryPoints.count == 2

        case .polygon:
            return temporaryPoints.count >= 3
        }
    }

    func undoLastPoint() {
        guard isDrawingActive else { return }

        if currentMode == .circle && circleCenter != nil {
            // For circle, reset to center selection
            circleCenter = nil
            isSelectingRadius = false
            temporaryPoints.removeAll()
            print("Circle reset to center selection")
        } else if !temporaryPoints.isEmpty {
            temporaryPoints.removeLast()
            print("Removed last point (\(temporaryPoints.count) points remaining)")
        }
    }

    func getInstructions() -> String {
        guard isDrawingActive, let mode = currentMode else { return "" }

        switch mode {
        case .marker:
            return "Tap map to place marker"

        case .line:
            if temporaryPoints.isEmpty {
                return "Tap map to start line"
            } else if temporaryPoints.count == 1 {
                return "Tap map to add points (need 1+ more)"
            } else {
                return "Tap to add points, press Complete when done"
            }

        case .circle:
            if circleCenter == nil {
                return "Tap map to set circle center"
            } else {
                return "Tap map to set circle radius"
            }

        case .polygon:
            if temporaryPoints.isEmpty {
                return "Tap map to start polygon"
            } else if temporaryPoints.count < 3 {
                return "Tap map to add points (need \(3 - temporaryPoints.count) more)"
            } else {
                return "Tap to add points, press Complete when done"
            }
        }
    }
}
