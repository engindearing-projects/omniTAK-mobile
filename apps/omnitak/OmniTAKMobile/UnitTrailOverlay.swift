//
//  UnitTrailOverlay.swift
//  OmniTAKTest
//
//  Position history trail visualization with MKPolyline overlay
//

import MapKit
import SwiftUI

// MARK: - Unit Trail Overlay

class UnitTrailOverlay: NSObject {
    let uid: String
    let positions: [CoTPosition]
    let polyline: MKPolyline
    let affiliation: UnitAffiliation

    init(uid: String, positions: [CoTPosition], affiliation: UnitAffiliation) {
        self.uid = uid
        self.positions = positions
        self.affiliation = affiliation

        // Create polyline from positions
        var coordinates = positions.map { $0.coordinate }
        self.polyline = MKPolyline(coordinates: &coordinates, count: coordinates.count)

        super.init()
    }

    /// Get the color for this trail based on affiliation
    var trailColor: UIColor {
        switch affiliation {
        case .friendly, .assumedFriend:
            return UIColor.cyan
        case .hostile, .suspect:
            return UIColor.red
        case .neutral:
            return UIColor.green
        case .unknown:
            return UIColor.yellow
        }
    }

    /// Get the SwiftUI color for this trail
    var swiftUIColor: Color {
        Color(trailColor)
    }
}

// MARK: - Trail Renderer

class UnitTrailRenderer: MKPolylineRenderer {
    var trailColor: UIColor = .cyan
    var trailWidth: CGFloat = 3.0
    var showDirectionArrows: Bool = true

    override init(polyline: MKPolyline) {
        super.init(polyline: polyline)
        setupRenderer()
    }

    private func setupRenderer() {
        strokeColor = trailColor.withAlphaComponent(0.8)
        lineWidth = trailWidth
        lineCap = .round
        lineJoin = .round
    }

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        // Draw the base polyline
        super.draw(mapRect, zoomScale: zoomScale, in: context)

        // Draw direction arrows along the trail if enabled
        if showDirectionArrows {
            drawDirectionArrows(in: context, zoomScale: zoomScale)
        }

        // Draw start/end markers
        drawStartEndMarkers(in: context, zoomScale: zoomScale)
    }

    private func drawDirectionArrows(in context: CGContext, zoomScale: MKZoomScale) {
        guard let polyline = polyline as? MKPolyline else { return }

        let points = polyline.points()
        let pointCount = polyline.pointCount

        // Draw arrows every N points (based on zoom level)
        let arrowInterval = max(3, Int(10 / zoomScale))
        let arrowSize = CGFloat(8.0) / zoomScale

        context.saveGState()
        context.setFillColor(trailColor.cgColor)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(0.5 / zoomScale)

        for i in stride(from: 0, to: pointCount - 1, by: arrowInterval) {
            let p1 = points[i]
            let p2 = points[i + 1]

            let point1 = point(for: p1)
            let point2 = point(for: p2)

            // Calculate angle
            let dx = point2.x - point1.x
            let dy = point2.y - point1.y
            let angle = atan2(dy, dx)

            // Draw arrow at midpoint
            let midX = (point1.x + point2.x) / 2
            let midY = (point1.y + point2.y) / 2

            context.saveGState()
            context.translateBy(x: midX, y: midY)
            context.rotate(by: angle)

            // Draw arrow triangle
            let arrowPath = UIBezierPath()
            arrowPath.move(to: CGPoint(x: arrowSize, y: 0))
            arrowPath.addLine(to: CGPoint(x: -arrowSize/2, y: arrowSize/2))
            arrowPath.addLine(to: CGPoint(x: -arrowSize/2, y: -arrowSize/2))
            arrowPath.close()

            context.addPath(arrowPath.cgPath)
            context.fillPath()

            context.addPath(arrowPath.cgPath)
            context.strokePath()

            context.restoreGState()
        }

        context.restoreGState()
    }

    private func drawStartEndMarkers(in context: CGContext, zoomScale: MKZoomScale) {
        guard let polyline = polyline as? MKPolyline else { return }
        guard polyline.pointCount >= 2 else { return }

        let points = polyline.points()
        let markerSize = CGFloat(6.0) / zoomScale

        // Start marker (green)
        let startPoint = point(for: points[0])
        drawCircleMarker(
            at: startPoint,
            size: markerSize,
            fillColor: UIColor.green,
            strokeColor: UIColor.white,
            in: context,
            zoomScale: zoomScale
        )

        // End marker (larger, with current trail color)
        let endPoint = point(for: points[polyline.pointCount - 1])
        drawCircleMarker(
            at: endPoint,
            size: markerSize * 1.5,
            fillColor: trailColor,
            strokeColor: UIColor.white,
            in: context,
            zoomScale: zoomScale
        )
    }

    private func drawCircleMarker(
        at point: CGPoint,
        size: CGFloat,
        fillColor: UIColor,
        strokeColor: UIColor,
        in context: CGContext,
        zoomScale: MKZoomScale
    ) {
        context.saveGState()

        let rect = CGRect(
            x: point.x - size,
            y: point.y - size,
            width: size * 2,
            height: size * 2
        )

        context.setFillColor(fillColor.cgColor)
        context.fillEllipse(in: rect)

        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(1.0 / zoomScale)
        context.strokeEllipse(in: rect)

        context.restoreGState()
    }
}

// MARK: - Trail Manager

class TrailManager: ObservableObject {
    @Published var trails: [String: UnitTrailOverlay] = [:]

    /// Maximum number of position points to keep per unit
    var maxTrailLength: Int = 100

    /// Minimum distance (in meters) between points to add to trail
    var minimumDistanceThreshold: Double = 5.0

    /// Update or create a trail for a marker
    func updateTrail(for marker: EnhancedCoTMarker) {
        // Filter positions to reduce clutter
        let filteredPositions = filterPositions(marker.positionHistory)

        guard filteredPositions.count >= 2 else {
            // Not enough points for a trail
            trails.removeValue(forKey: marker.uid)
            return
        }

        let trail = UnitTrailOverlay(
            uid: marker.uid,
            positions: filteredPositions,
            affiliation: marker.affiliation
        )

        trails[marker.uid] = trail
    }

    /// Remove trail for a specific unit
    func removeTrail(forUID uid: String) {
        trails.removeValue(forKey: uid)
    }

    /// Clear all trails
    func clearAllTrails() {
        trails.removeAll()
    }

    /// Filter positions to reduce clutter and improve performance
    private func filterPositions(_ positions: [CoTPosition]) -> [CoTPosition] {
        guard positions.count > 2 else { return positions }

        var filtered: [CoTPosition] = []
        var lastPosition: CoTPosition? = nil

        for position in positions {
            if let last = lastPosition {
                let distance = calculateDistance(
                    from: last.coordinate,
                    to: position.coordinate
                )

                // Only add if moved significant distance
                if distance >= minimumDistanceThreshold {
                    filtered.append(position)
                    lastPosition = position
                }
            } else {
                // Always add first position
                filtered.append(position)
                lastPosition = position
            }
        }

        // Always include the last position
        if let last = positions.last, filtered.last?.id != last.id {
            filtered.append(last)
        }

        // Limit total points
        if filtered.count > maxTrailLength {
            filtered = Array(filtered.suffix(maxTrailLength))
        }

        return filtered
    }

    private func calculateDistance(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return loc1.distance(from: loc2)
    }
}

// MARK: - Trail Configuration

struct TrailConfiguration {
    var isEnabled: Bool = true
    var showDirectionArrows: Bool = true
    var maxTrailLength: Int = 100
    var trailWidth: CGFloat = 3.0
    var minimumDistanceThreshold: Double = 5.0

    /// Trail duration in seconds (positions older than this are removed)
    var trailDuration: TimeInterval = 3600 // 1 hour

    /// Affiliation-specific trail settings
    var showFriendlyTrails: Bool = true
    var showHostileTrails: Bool = true
    var showNeutralTrails: Bool = true
    var showUnknownTrails: Bool = false
}
