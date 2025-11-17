//
//  RangeBearingOverlay.swift
//  OmniTAKMobile
//
//  MapKit overlay for displaying Range & Bearing lines with distance and bearing labels
//

import Foundation
import MapKit
import UIKit

// MARK: - Range & Bearing Line Overlay

/// Custom MKPolyline subclass for R&B lines
class RangeBearingLineOverlay: MKPolyline {
    var lineID: UUID?
    var lineColor: UIColor = UIColor.orange
    var lineWidth: CGFloat = 3.0
    var lineStyle: RangeBearingLineStyle = .solid

    // Labels
    var distanceLabel: String = ""
    var bearingLabel: String = ""
    var backAzimuthLabel: String = ""

    // Display options
    var showDistanceLabel: Bool = true
    var showBearingLabel: Bool = true
    var showBackAzimuth: Bool = false
    var showDirectionArrow: Bool = true
}

// MARK: - Range & Bearing Renderer

class RangeBearingLineRenderer: MKPolylineRenderer {

    var distanceLabel: String = ""
    var bearingLabel: String = ""
    var backAzimuthLabel: String = ""
    var showDistanceLabel: Bool = true
    var showBearingLabel: Bool = true
    var showBackAzimuth: Bool = false
    var showDirectionArrow: Bool = true
    var isDashed: Bool = false

    // MARK: - Initialization

    override init(polyline: MKPolyline) {
        super.init(polyline: polyline)

        if let rbOverlay = polyline as? RangeBearingLineOverlay {
            strokeColor = rbOverlay.lineColor
            lineWidth = rbOverlay.lineWidth
            distanceLabel = rbOverlay.distanceLabel
            bearingLabel = rbOverlay.bearingLabel
            backAzimuthLabel = rbOverlay.backAzimuthLabel
            showDistanceLabel = rbOverlay.showDistanceLabel
            showBearingLabel = rbOverlay.showBearingLabel
            showBackAzimuth = rbOverlay.showBackAzimuth
            showDirectionArrow = rbOverlay.showDirectionArrow
            isDashed = rbOverlay.lineStyle == .dashed
        } else {
            strokeColor = .orange
            lineWidth = 3.0
        }

        lineCap = .round
        lineJoin = .round

        if isDashed {
            lineDashPattern = [10, 6]
        }
    }

    // MARK: - Drawing

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        // Draw the base line
        super.draw(mapRect, zoomScale: zoomScale, in: context)

        guard polyline.pointCount >= 2 else { return }

        // Draw direction arrow at destination
        if showDirectionArrow {
            drawDirectionArrow(mapRect: mapRect, zoomScale: zoomScale, in: context)
        }

        // Draw distance label at midpoint
        if showDistanceLabel && !distanceLabel.isEmpty {
            drawDistanceLabel(mapRect: mapRect, zoomScale: zoomScale, in: context)
        }

        // Draw bearing label near origin
        if showBearingLabel && !bearingLabel.isEmpty {
            drawBearingLabel(mapRect: mapRect, zoomScale: zoomScale, in: context)
        }

        // Draw origin marker (small circle)
        drawOriginMarker(mapRect: mapRect, zoomScale: zoomScale, in: context)
    }

    // MARK: - Direction Arrow

    private func drawDirectionArrow(mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let points = polyline.points()
        let lastIndex = polyline.pointCount - 1

        let endPoint = point(for: points[lastIndex])
        let prevPoint = point(for: points[max(0, lastIndex - 1)])

        // Calculate angle
        let angle = atan2(endPoint.y - prevPoint.y, endPoint.x - prevPoint.x)

        // Arrow size
        let arrowSize: CGFloat = 18.0 / zoomScale

        // Arrow angle (30 degrees)
        let arrowAngle: CGFloat = .pi / 6

        let leftPoint = CGPoint(
            x: endPoint.x - arrowSize * cos(angle - arrowAngle),
            y: endPoint.y - arrowSize * sin(angle - arrowAngle)
        )

        let rightPoint = CGPoint(
            x: endPoint.x - arrowSize * cos(angle + arrowAngle),
            y: endPoint.y - arrowSize * sin(angle + arrowAngle)
        )

        context.saveGState()

        if let color = strokeColor {
            context.setFillColor(color.cgColor)
        }

        // Draw filled arrow
        context.move(to: endPoint)
        context.addLine(to: leftPoint)
        context.addLine(to: rightPoint)
        context.closePath()
        context.fillPath()

        // Draw arrow border
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(1.5 / zoomScale)
        context.move(to: endPoint)
        context.addLine(to: leftPoint)
        context.addLine(to: rightPoint)
        context.closePath()
        context.strokePath()

        context.restoreGState()
    }

    // MARK: - Distance Label

    private func drawDistanceLabel(mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard polyline.pointCount >= 2 else { return }

        let points = polyline.points()

        // Calculate midpoint
        let midLat = (points[0].coordinate.latitude + points[polyline.pointCount - 1].coordinate.latitude) / 2.0
        let midLon = (points[0].coordinate.longitude + points[polyline.pointCount - 1].coordinate.longitude) / 2.0
        let midMapPoint = MKMapPoint(CLLocationCoordinate2D(latitude: midLat, longitude: midLon))

        if mapRect.contains(midMapPoint) {
            let screenPoint = point(for: midMapPoint)
            drawLabel(distanceLabel, at: screenPoint, zoomScale: zoomScale, in: context, backgroundColor: UIColor.black.withAlphaComponent(0.75))
        }
    }

    // MARK: - Bearing Label

    private func drawBearingLabel(mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard polyline.pointCount >= 2 else { return }

        let points = polyline.points()
        let originCoord = points[0].coordinate
        let destCoord = points[polyline.pointCount - 1].coordinate

        // Calculate a point slightly offset from origin along the line direction
        let offsetDistance = 0.15 // 15% along the line
        let labelLat = originCoord.latitude + (destCoord.latitude - originCoord.latitude) * offsetDistance
        let labelLon = originCoord.longitude + (destCoord.longitude - originCoord.longitude) * offsetDistance
        let labelMapPoint = MKMapPoint(CLLocationCoordinate2D(latitude: labelLat, longitude: labelLon))

        if mapRect.contains(labelMapPoint) {
            let screenPoint = point(for: labelMapPoint)

            // Create label text
            var labelText = bearingLabel
            if showBackAzimuth && !backAzimuthLabel.isEmpty {
                labelText += "\nBack: \(backAzimuthLabel)"
            }

            drawLabel(labelText, at: screenPoint, zoomScale: zoomScale, in: context, backgroundColor: UIColor(red: 1.0, green: 0.533, blue: 0.0, alpha: 0.85))
        }
    }

    // MARK: - Origin Marker

    private func drawOriginMarker(mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard polyline.pointCount >= 1 else { return }

        let points = polyline.points()
        let originPoint = point(for: points[0])
        let markerSize: CGFloat = 8.0 / zoomScale

        context.saveGState()

        // Outer circle (white)
        let outerRect = CGRect(
            x: originPoint.x - markerSize,
            y: originPoint.y - markerSize,
            width: markerSize * 2,
            height: markerSize * 2
        )

        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: outerRect)

        // Inner circle (line color)
        let innerSize = markerSize * 0.7
        let innerRect = CGRect(
            x: originPoint.x - innerSize,
            y: originPoint.y - innerSize,
            width: innerSize * 2,
            height: innerSize * 2
        )

        if let color = strokeColor {
            context.setFillColor(color.cgColor)
        }
        context.fillEllipse(in: innerRect)

        // Border
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(1.0 / zoomScale)
        context.strokeEllipse(in: outerRect)

        context.restoreGState()
    }

    // MARK: - Label Drawing Helper

    private func drawLabel(
        _ text: String,
        at point: CGPoint,
        zoomScale: MKZoomScale,
        in context: CGContext,
        backgroundColor: UIColor = UIColor.black.withAlphaComponent(0.75)
    ) {
        context.saveGState()

        let fontSize: CGFloat = 12.0 / zoomScale
        let font = UIFont.boldSystemFont(ofSize: fontSize)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]

        let nsString = text as NSString
        let size = nsString.boundingRect(
            with: CGSize(width: 300, height: 100),
            options: .usesLineFragmentOrigin,
            attributes: attributes,
            context: nil
        ).size

        // Draw background with rounded corners
        let padding: CGFloat = 6.0 / zoomScale
        let rect = CGRect(
            x: point.x - size.width / 2 - padding,
            y: point.y - size.height / 2 - padding / 2,
            width: size.width + padding * 2,
            height: size.height + padding
        )

        let cornerRadius: CGFloat = 4.0 / zoomScale
        let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)

        context.setFillColor(backgroundColor.cgColor)
        context.addPath(path.cgPath)
        context.fillPath()

        // Draw border
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(1.0 / zoomScale)
        context.addPath(path.cgPath)
        context.strokePath()

        // Draw text
        UIGraphicsPushContext(context)
        nsString.draw(
            in: CGRect(
                x: point.x - size.width / 2,
                y: point.y - size.height / 2,
                width: size.width,
                height: size.height
            ),
            withAttributes: attributes
        )
        UIGraphicsPopContext()

        context.restoreGState()
    }
}

// MARK: - Range & Bearing Overlay Manager

class RangeBearingOverlayManager: ObservableObject {

    @Published var overlays: [RangeBearingLineOverlay] = []

    weak var service: RangeBearingService?

    init(service: RangeBearingService? = nil) {
        self.service = service
    }

    // MARK: - Overlay Creation

    /// Create overlays for all lines in the service
    func updateOverlays() {
        guard let service = service else { return }

        var newOverlays: [RangeBearingLineOverlay] = []

        // Create overlays for each R&B line
        for line in service.lines {
            if let overlay = createOverlay(for: line) {
                newOverlays.append(overlay)
            }
        }

        // Add temporary line if being created
        if let tempOverlay = createTemporaryOverlay() {
            newOverlays.append(tempOverlay)
        }

        overlays = newOverlays
    }

    /// Create overlay for a single R&B line
    func createOverlay(for line: RangeBearingLine) -> RangeBearingLineOverlay? {
        guard let service = service else { return nil }

        var coordinates = [line.origin, line.destination]
        let overlay = RangeBearingLineOverlay(coordinates: &coordinates, count: 2)

        overlay.lineID = line.id
        overlay.lineColor = UIColor(hexString: service.configuration.lineColor) ?? .orange
        overlay.lineWidth = service.configuration.lineWidth
        overlay.lineStyle = service.configuration.lineStyle

        // Set labels
        overlay.distanceLabel = service.formatDistance(line.distanceMeters)

        switch service.configuration.bearingType {
        case .magnetic:
            overlay.bearingLabel = "\(service.formatBearing(line.magneticBearing))M"
        case .true:
            overlay.bearingLabel = "\(service.formatBearing(line.trueBearing))T"
        case .grid:
            overlay.bearingLabel = "\(service.formatBearing(line.gridBearing))G"
        }

        overlay.backAzimuthLabel = service.formatBearing(line.backAzimuth)

        // Display options
        overlay.showDistanceLabel = service.configuration.showDistanceLabel
        overlay.showBearingLabel = service.configuration.showBearingLabel
        overlay.showBackAzimuth = service.configuration.showBackAzimuth
        overlay.showDirectionArrow = true

        return overlay
    }

    /// Create temporary overlay for line being created
    func createTemporaryOverlay() -> RangeBearingLineOverlay? {
        guard let service = service,
              service.isCreatingLine,
              let origin = service.temporaryOrigin,
              let destination = service.temporaryDestination else {
            return nil
        }

        var coordinates = [origin, destination]
        let overlay = RangeBearingLineOverlay(coordinates: &coordinates, count: 2)

        overlay.lineID = nil
        overlay.lineColor = UIColor(hexString: service.configuration.lineColor)?.withAlphaComponent(0.7) ?? UIColor.orange.withAlphaComponent(0.7)
        overlay.lineWidth = service.configuration.lineWidth
        overlay.lineStyle = .dashed

        // Calculate temporary values
        let distance = service.calculateDistance(from: origin, to: destination)
        let bearing = service.calculateMagneticBearing(from: origin, to: destination)
        let backAz = service.calculateBackAzimuth(bearing: bearing)

        overlay.distanceLabel = service.formatDistance(distance)
        overlay.bearingLabel = "\(service.formatBearing(bearing))M"
        overlay.backAzimuthLabel = service.formatBearing(backAz)

        overlay.showDistanceLabel = true
        overlay.showBearingLabel = true
        overlay.showBackAzimuth = false
        overlay.showDirectionArrow = true

        return overlay
    }

    // MARK: - Renderer Creation

    func createRenderer(for overlay: MKOverlay) -> MKOverlayRenderer? {
        guard let rbOverlay = overlay as? RangeBearingLineOverlay else {
            return nil
        }

        return RangeBearingLineRenderer(polyline: rbOverlay)
    }
}

// MARK: - Range & Bearing Map Integration

class RangeBearingMapIntegration {
    weak var mapView: MKMapView?
    let service: RangeBearingService
    let overlayManager: RangeBearingOverlayManager

    private var cancellables = Set<AnyCancellable>()
    private var currentOverlays: [RangeBearingLineOverlay] = []

    init(mapView: MKMapView, service: RangeBearingService) {
        self.mapView = mapView
        self.service = service
        self.overlayManager = RangeBearingOverlayManager(service: service)

        setupBindings()
    }

    private func setupBindings() {
        // Update overlays when lines change
        service.$lines
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMapOverlays()
            }
            .store(in: &cancellables)

        // Update overlays during line creation
        service.$temporaryDestination
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMapOverlays()
            }
            .store(in: &cancellables)

        // Update overlays when configuration changes
        service.$configuration
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMapOverlays()
            }
            .store(in: &cancellables)
    }

    func updateMapOverlays() {
        guard let map = mapView else { return }

        // Remove existing R&B overlays
        map.removeOverlays(currentOverlays)

        // Create new overlays
        overlayManager.updateOverlays()
        currentOverlays = overlayManager.overlays

        // Add to map
        map.addOverlays(currentOverlays, level: .aboveLabels)
    }

    func cleanup() {
        if let map = mapView {
            map.removeOverlays(currentOverlays)
        }
        cancellables.removeAll()
    }

    // MARK: - Renderer Provider

    func renderer(for overlay: MKOverlay) -> MKOverlayRenderer? {
        return overlayManager.createRenderer(for: overlay)
    }
}

// MARK: - Combine Import

import Combine
