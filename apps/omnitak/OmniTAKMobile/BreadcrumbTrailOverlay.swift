//
//  BreadcrumbTrailOverlay.swift
//  OmniTAKMobile
//
//  MapKit overlay for breadcrumb trail visualization with gradient coloring and direction arrows
//

import Foundation
import MapKit
import UIKit
import Combine

// MARK: - Breadcrumb Trail Polyline

/// Custom MKPolyline subclass for breadcrumb trails
class BreadcrumbTrailPolyline: MKPolyline {
    var teamColor: UIColor = UIColor.green
    var lineWidth: CGFloat = 3.0
    var timestamps: [Date] = []
    var showDirectionArrows: Bool = true
    var enableTimeFading: Bool = true
    var fadeStartTime: TimeInterval = 1800.0 // 30 minutes
}

// MARK: - Breadcrumb Trail Overlay Manager

class BreadcrumbTrailOverlayManager: ObservableObject {

    @Published var currentOverlay: BreadcrumbTrailPolyline?

    weak var service: BreadcrumbTrailService?

    init(service: BreadcrumbTrailService? = nil) {
        self.service = service
    }

    // MARK: - Overlay Creation

    /// Create or update the trail overlay from service data
    func updateOverlay() -> BreadcrumbTrailPolyline? {
        guard let service = service else { return nil }
        guard !service.trailPoints.isEmpty else {
            currentOverlay = nil
            return nil
        }

        var coordinates = service.trailCoordinates
        let polyline = BreadcrumbTrailPolyline(coordinates: &coordinates, count: coordinates.count)

        // Configure from service
        polyline.teamColor = UIColor(hexString: service.configuration.teamColor) ?? .green
        polyline.lineWidth = service.configuration.lineWidth
        polyline.timestamps = service.trailTimestamps
        polyline.showDirectionArrows = service.configuration.showDirectionArrows
        polyline.enableTimeFading = service.configuration.enableTimeFading
        polyline.fadeStartTime = service.configuration.fadeStartTime

        currentOverlay = polyline
        return polyline
    }

    /// Create overlay from raw coordinates
    func createOverlay(
        coordinates: [CLLocationCoordinate2D],
        timestamps: [Date],
        teamColor: UIColor = .green,
        lineWidth: CGFloat = 3.0
    ) -> BreadcrumbTrailPolyline? {
        guard !coordinates.isEmpty else { return nil }

        var coords = coordinates
        let polyline = BreadcrumbTrailPolyline(coordinates: &coords, count: coords.count)
        polyline.teamColor = teamColor
        polyline.lineWidth = lineWidth
        polyline.timestamps = timestamps
        polyline.showDirectionArrows = true
        polyline.enableTimeFading = true

        return polyline
    }

    /// Create renderer for the overlay
    func createRenderer(for overlay: MKOverlay) -> MKOverlayRenderer? {
        guard let breadcrumbPolyline = overlay as? BreadcrumbTrailPolyline else {
            return nil
        }

        let renderer = BreadcrumbTrailRenderer(polyline: breadcrumbPolyline)
        renderer.teamColor = breadcrumbPolyline.teamColor
        renderer.trailWidth = breadcrumbPolyline.lineWidth
        renderer.timestamps = breadcrumbPolyline.timestamps
        renderer.showDirectionArrows = breadcrumbPolyline.showDirectionArrows
        renderer.enableTimeFading = breadcrumbPolyline.enableTimeFading
        renderer.fadeStartTime = breadcrumbPolyline.fadeStartTime

        return renderer
    }
}

// MARK: - Breadcrumb Trail Renderer

/// Custom renderer with gradient coloring and direction arrows
class BreadcrumbTrailRenderer: MKPolylineRenderer {

    var teamColor: UIColor = .green
    var trailWidth: CGFloat = 3.0
    var timestamps: [Date] = []
    var showDirectionArrows: Bool = true
    var enableTimeFading: Bool = true
    var fadeStartTime: TimeInterval = 1800.0

    // MARK: - Initialization

    override init(polyline: MKPolyline) {
        super.init(polyline: polyline)
        setupRenderer()
    }

    private func setupRenderer() {
        strokeColor = teamColor
        lineWidth = trailWidth
        lineCap = .round
        lineJoin = .round
    }

    // MARK: - Drawing

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        // Draw the gradient trail
        drawGradientTrail(mapRect: mapRect, zoomScale: zoomScale, in: context)

        // Draw direction arrows
        if showDirectionArrows {
            drawDirectionArrows(mapRect: mapRect, zoomScale: zoomScale, in: context)
        }

        // Draw start and end markers
        drawStartEndMarkers(mapRect: mapRect, zoomScale: zoomScale, in: context)
    }

    // MARK: - Gradient Trail Drawing

    private func drawGradientTrail(mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard polyline.pointCount >= 2 else { return }

        let points = polyline.points()
        let currentTime = Date()

        context.saveGState()
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(trailWidth / zoomScale)

        // Draw segments with varying opacity based on age
        for i in 0..<(polyline.pointCount - 1) {
            let startPoint = point(for: points[i])
            let endPoint = point(for: points[i + 1])

            // Calculate opacity based on timestamp
            var alpha: CGFloat = 1.0
            if enableTimeFading && i < timestamps.count {
                let pointAge = currentTime.timeIntervalSince(timestamps[i])
                if pointAge > fadeStartTime {
                    // Fade from 1.0 to 0.3 over time
                    let fadeProgress = min(1.0, (pointAge - fadeStartTime) / fadeStartTime)
                    alpha = CGFloat(1.0 - (fadeProgress * 0.7))
                }
            } else if enableTimeFading && !timestamps.isEmpty {
                // Gradient from oldest (faded) to newest (bright)
                let progress = CGFloat(i) / CGFloat(polyline.pointCount - 1)
                alpha = 0.3 + (progress * 0.7)
            }

            // Set color with calculated alpha
            context.setStrokeColor(teamColor.withAlphaComponent(alpha).cgColor)

            // Draw segment
            context.move(to: startPoint)
            context.addLine(to: endPoint)
            context.strokePath()
        }

        context.restoreGState()
    }

    // MARK: - Direction Arrows Drawing

    private func drawDirectionArrows(mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard polyline.pointCount >= 2 else { return }

        let points = polyline.points()

        // Draw arrows every N points based on zoom level
        let arrowInterval = max(5, Int(20.0 / zoomScale))
        let arrowSize = CGFloat(8.0) / zoomScale

        context.saveGState()
        context.setLineWidth(1.0 / zoomScale)

        for i in stride(from: arrowInterval, to: polyline.pointCount - 1, by: arrowInterval) {
            let p1 = points[max(0, i - 1)]
            let p2 = points[i]

            let point1 = point(for: p1)
            let point2 = point(for: p2)

            // Calculate angle
            let dx = point2.x - point1.x
            let dy = point2.y - point1.y
            let angle = atan2(dy, dx)

            // Calculate alpha based on position in trail
            var alpha: CGFloat = 1.0
            if enableTimeFading {
                let progress = CGFloat(i) / CGFloat(polyline.pointCount - 1)
                alpha = 0.5 + (progress * 0.5)
            }

            // Draw arrow at point2
            context.saveGState()
            context.translateBy(x: point2.x, y: point2.y)
            context.rotate(by: angle)

            // Arrow triangle
            let arrowPath = UIBezierPath()
            arrowPath.move(to: CGPoint(x: arrowSize, y: 0))
            arrowPath.addLine(to: CGPoint(x: -arrowSize / 2, y: arrowSize / 2))
            arrowPath.addLine(to: CGPoint(x: -arrowSize / 2, y: -arrowSize / 2))
            arrowPath.close()

            context.setFillColor(teamColor.withAlphaComponent(alpha).cgColor)
            context.addPath(arrowPath.cgPath)
            context.fillPath()

            // White border
            context.setStrokeColor(UIColor.white.withAlphaComponent(alpha * 0.8).cgColor)
            context.addPath(arrowPath.cgPath)
            context.strokePath()

            context.restoreGState()
        }

        context.restoreGState()
    }

    // MARK: - Start/End Markers

    private func drawStartEndMarkers(mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard polyline.pointCount >= 2 else { return }

        let points = polyline.points()
        let markerSize = CGFloat(10.0) / zoomScale

        // Start marker (faded circle)
        let startPoint = point(for: points[0])
        drawCircleMarker(
            at: startPoint,
            size: markerSize * 0.8,
            fillColor: teamColor.withAlphaComponent(0.4),
            strokeColor: UIColor.white.withAlphaComponent(0.5),
            in: context,
            zoomScale: zoomScale
        )

        // End marker (bright pulsing effect - larger circle)
        let endPoint = point(for: points[polyline.pointCount - 1])
        drawCircleMarker(
            at: endPoint,
            size: markerSize * 1.2,
            fillColor: teamColor,
            strokeColor: UIColor.white,
            in: context,
            zoomScale: zoomScale
        )

        // Inner dot for end marker
        drawCircleMarker(
            at: endPoint,
            size: markerSize * 0.4,
            fillColor: UIColor.white,
            strokeColor: UIColor.clear,
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

        if strokeColor != UIColor.clear {
            context.setStrokeColor(strokeColor.cgColor)
            context.setLineWidth(2.0 / zoomScale)
            context.strokeEllipse(in: rect)
        }

        context.restoreGState()
    }
}

// UIColor extension for hexString is defined elsewhere in codebase

// MARK: - Breadcrumb Trail Map Integration

class BreadcrumbTrailMapIntegration {
    weak var mapView: MKMapView?
    let service: BreadcrumbTrailService
    let overlayManager: BreadcrumbTrailOverlayManager

    private var cancellables = Set<AnyCancellable>()
    private var currentPolyline: BreadcrumbTrailPolyline?

    init(mapView: MKMapView, service: BreadcrumbTrailService) {
        self.mapView = mapView
        self.service = service
        self.overlayManager = BreadcrumbTrailOverlayManager(service: service)

        setupBindings()
    }

    private func setupBindings() {
        // Update overlay when trail points change
        service.$trailPoints
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMapOverlay()
            }
            .store(in: &cancellables)

        // Update overlay when configuration changes
        service.$configuration
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMapOverlay()
            }
            .store(in: &cancellables)
    }

    func updateMapOverlay() {
        guard let map = mapView else { return }

        // Remove existing breadcrumb overlay
        if let existing = currentPolyline {
            map.removeOverlay(existing)
        }

        // Create new overlay
        if let newOverlay = overlayManager.updateOverlay() {
            map.addOverlay(newOverlay, level: .aboveRoads)
            currentPolyline = newOverlay
        }
    }

    func cleanup() {
        if let existing = currentPolyline, let map = mapView {
            map.removeOverlay(existing)
        }
        cancellables.removeAll()
    }

    // MARK: - Renderer Provider

    func renderer(for overlay: MKOverlay) -> MKOverlayRenderer? {
        return overlayManager.createRenderer(for: overlay)
    }
}

// MARK: - Team Color Presets for ATAK

enum ATAKTeamColor: String, CaseIterable {
    case white = "#FFFFFF"
    case yellow = "#FFFF00"
    case orange = "#FF8000"
    case magenta = "#FF00FF"
    case red = "#FF0000"
    case maroon = "#800000"
    case purple = "#800080"
    case darkBlue = "#000080"
    case blue = "#0000FF"
    case cyan = "#00FFFF"
    case teal = "#008080"
    case green = "#00FF00"
    case darkGreen = "#008000"
    case brown = "#A52A2A"

    var displayName: String {
        switch self {
        case .white: return "White"
        case .yellow: return "Yellow"
        case .orange: return "Orange"
        case .magenta: return "Magenta"
        case .red: return "Red"
        case .maroon: return "Maroon"
        case .purple: return "Purple"
        case .darkBlue: return "Dark Blue"
        case .blue: return "Blue"
        case .cyan: return "Cyan"
        case .teal: return "Teal"
        case .green: return "Green"
        case .darkGreen: return "Dark Green"
        case .brown: return "Brown"
        }
    }

    var uiColor: UIColor {
        UIColor(hexString: rawValue) ?? .green
    }
}
