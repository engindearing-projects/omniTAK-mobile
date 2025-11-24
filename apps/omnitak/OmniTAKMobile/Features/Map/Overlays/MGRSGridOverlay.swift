//
//  MGRSGridOverlay.swift
//  OmniTAKMobile
//
//  Military Grid Reference System (MGRS) grid overlay for MapKit
//  Displays grid lines and labels similar to iTAK/ATAK
//

import Foundation
import MapKit

// MARK: - MGRS Grid Overlay

class MGRSGridOverlay: NSObject, MKOverlay {

    // MARK: - MKOverlay Properties

    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }

    var boundingMapRect: MKMapRect {
        return MKMapRect.world
    }

    // MARK: - Configuration

    var gridSpacing: GridSpacing = .oneKilometer
    var showLabels: Bool = true
    var lineColor: UIColor = UIColor.gray.withAlphaComponent(0.5)
    var lineWidth: CGFloat = 0.5
    var labelColor: UIColor = UIColor.white.withAlphaComponent(0.8)
    var labelBackgroundColor: UIColor = UIColor.black.withAlphaComponent(0.6)
    var labelFont: UIFont = UIFont.systemFont(ofSize: 10, weight: .medium)

    // MARK: - Grid Spacing Options

    enum GridSpacing: Double {
        case hundredMeter = 100
        case oneKilometer = 1000
        case tenKilometer = 10000
        case hundredKilometer = 100000

        static func forZoomLevel(_ zoomLevel: Double) -> GridSpacing {
            if zoomLevel > 15 {
                return .hundredMeter
            } else if zoomLevel > 12 {
                return .oneKilometer
            } else if zoomLevel > 8 {
                return .tenKilometer
            } else {
                return .hundredKilometer
            }
        }
    }
}

// MARK: - MGRS Grid Renderer

class MGRSGridRenderer: MKOverlayRenderer {

    private var gridOverlay: MGRSGridOverlay
    private var cachedLines: [GridLine] = []
    private var lastMapRect: MKMapRect = .null
    private var lastZoomScale: MKZoomScale = 0

    // MARK: - Grid Line Structure

    private struct GridLine {
        let start: MKMapPoint
        let end: MKMapPoint
        let type: LineType
        let label: String?
    }

    private enum LineType {
        case zoneBoundary
        case majorGrid
        case minorGrid
    }

    // MARK: - Initialization

    init(overlay: MGRSGridOverlay) {
        self.gridOverlay = overlay
        super.init(overlay: overlay)
    }

    // MARK: - Drawing

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let _ = self.rect(for: mapRect)

        // Update grid spacing based on zoom level
        let zoomLevel = calculateZoomLevel(zoomScale: zoomScale)
        let adaptiveSpacing = MGRSGridOverlay.GridSpacing.forZoomLevel(zoomLevel)

        // Calculate visible area in geographic coordinates
        let topLeft = mapPointToCoordinate(MKMapPoint(x: mapRect.minX, y: mapRect.minY))
        let bottomRight = mapPointToCoordinate(MKMapPoint(x: mapRect.maxX, y: mapRect.maxY))

        // Draw UTM zone boundaries if zoomed out enough
        if zoomLevel < 10 {
            drawZoneBoundaries(mapRect: mapRect, context: context, zoomScale: zoomScale)
        }

        // Draw MGRS grid lines
        drawGridLines(
            topLeft: topLeft,
            bottomRight: bottomRight,
            spacing: adaptiveSpacing.rawValue,
            mapRect: mapRect,
            context: context,
            zoomScale: zoomScale
        )

        // Draw labels if enabled and zoomed in enough
        if gridOverlay.showLabels && zoomLevel > 10 {
            drawGridLabels(
                topLeft: topLeft,
                bottomRight: bottomRight,
                spacing: adaptiveSpacing.rawValue,
                mapRect: mapRect,
                context: context,
                zoomScale: zoomScale
            )
        }
    }

    // MARK: - Zone Boundaries

    private func drawZoneBoundaries(mapRect: MKMapRect, context: CGContext, zoomScale: MKZoomScale) {
        context.saveGState()

        // Draw UTM zone meridians (every 6 degrees)
        context.setStrokeColor(UIColor.orange.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(1.5 / zoomScale)

        let topLeft = mapPointToCoordinate(MKMapPoint(x: mapRect.minX, y: mapRect.minY))
        let bottomRight = mapPointToCoordinate(MKMapPoint(x: mapRect.maxX, y: mapRect.maxY))

        let startLon = floor(topLeft.longitude / 6) * 6
        let endLon = ceil(bottomRight.longitude / 6) * 6

        for lon in stride(from: startLon, through: endLon, by: 6.0) {
            let topPoint = point(for: MKMapPoint(coordinateForLon: lon, lat: topLeft.latitude))
            let bottomPoint = point(for: MKMapPoint(coordinateForLon: lon, lat: bottomRight.latitude))

            context.move(to: topPoint)
            context.addLine(to: bottomPoint)
        }
        context.strokePath()

        context.restoreGState()
    }

    // MARK: - Grid Lines

    private func drawGridLines(
        topLeft: CLLocationCoordinate2D,
        bottomRight: CLLocationCoordinate2D,
        spacing: Double,
        mapRect: MKMapRect,
        context: CGContext,
        zoomScale: MKZoomScale
    ) {
        context.saveGState()

        context.setStrokeColor(gridOverlay.lineColor.cgColor)
        context.setLineWidth(gridOverlay.lineWidth / zoomScale)

        // Get UTM zone for the center of the visible area
        let centerLat = (topLeft.latitude + bottomRight.latitude) / 2
        let centerLon = (topLeft.longitude + bottomRight.longitude) / 2
        let centerCoord = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)

        let centerUTM = MGRSConverter.latLonToUTM(centerCoord)

        // Calculate UTM bounds
        let tlUTM = MGRSConverter.latLonToUTM(topLeft)
        let brUTM = MGRSConverter.latLonToUTM(bottomRight)

        // Only draw if we're in the same zone (simplified for performance)
        guard tlUTM.zone == brUTM.zone else {
            // Handle cross-zone rendering differently
            drawCrossZoneGrid(topLeft: topLeft, bottomRight: bottomRight, spacing: spacing, mapRect: mapRect, context: context, zoomScale: zoomScale)
            context.restoreGState()
            return
        }

        let minEasting = floor(min(tlUTM.easting, brUTM.easting) / spacing) * spacing
        let maxEasting = ceil(max(tlUTM.easting, brUTM.easting) / spacing) * spacing
        let minNorthing = floor(min(tlUTM.northing, brUTM.northing) / spacing) * spacing
        let maxNorthing = ceil(max(tlUTM.northing, brUTM.northing) / spacing) * spacing

        // Draw vertical lines (constant easting)
        for easting in stride(from: minEasting, through: maxEasting, by: spacing) {
            var points: [CGPoint] = []

            for northing in stride(from: minNorthing, through: maxNorthing, by: spacing / 10) {
                let utm = MGRSConverter.UTMCoordinate(
                    zone: centerUTM.zone,
                    hemisphere: centerUTM.hemisphere,
                    easting: easting,
                    northing: northing,
                    latitudeBand: centerUTM.latitudeBand
                )
                let coord = MGRSConverter.utmToLatLon(utm)
                let mapPoint = MKMapPoint(coord)
                points.append(point(for: mapPoint))
            }

            if points.count > 1 {
                context.move(to: points[0])
                for i in 1..<points.count {
                    context.addLine(to: points[i])
                }
            }
        }
        context.strokePath()

        // Draw horizontal lines (constant northing)
        for northing in stride(from: minNorthing, through: maxNorthing, by: spacing) {
            var points: [CGPoint] = []

            for easting in stride(from: minEasting, through: maxEasting, by: spacing / 10) {
                let utm = MGRSConverter.UTMCoordinate(
                    zone: centerUTM.zone,
                    hemisphere: centerUTM.hemisphere,
                    easting: easting,
                    northing: northing,
                    latitudeBand: centerUTM.latitudeBand
                )
                let coord = MGRSConverter.utmToLatLon(utm)
                let mapPoint = MKMapPoint(coord)
                points.append(point(for: mapPoint))
            }

            if points.count > 1 {
                context.move(to: points[0])
                for i in 1..<points.count {
                    context.addLine(to: points[i])
                }
            }
        }
        context.strokePath()

        context.restoreGState()
    }

    private func drawCrossZoneGrid(
        topLeft: CLLocationCoordinate2D,
        bottomRight: CLLocationCoordinate2D,
        spacing: Double,
        mapRect: MKMapRect,
        context: CGContext,
        zoomScale: MKZoomScale
    ) {
        // Simplified cross-zone rendering: just draw grid for each zone separately
        let tlZone = Int((topLeft.longitude + 180) / 6) + 1
        let brZone = Int((bottomRight.longitude + 180) / 6) + 1

        for zone in tlZone...brZone {
            let _ = Double((zone - 1) * 6 - 180 + 3)
            let zoneLeftLon = Double((zone - 1) * 6 - 180)
            let zoneRightLon = zoneLeftLon + 6

            let clippedTopLeft = CLLocationCoordinate2D(
                latitude: topLeft.latitude,
                longitude: max(topLeft.longitude, zoneLeftLon)
            )
            let clippedBottomRight = CLLocationCoordinate2D(
                latitude: bottomRight.latitude,
                longitude: min(bottomRight.longitude, zoneRightLon)
            )

            // Skip if clipped area is invalid
            guard clippedTopLeft.longitude < clippedBottomRight.longitude else { continue }

            drawGridLinesForZone(
                zone: zone,
                topLeft: clippedTopLeft,
                bottomRight: clippedBottomRight,
                spacing: spacing,
                context: context,
                zoomScale: zoomScale
            )
        }
    }

    private func drawGridLinesForZone(
        zone: Int,
        topLeft: CLLocationCoordinate2D,
        bottomRight: CLLocationCoordinate2D,
        spacing: Double,
        context: CGContext,
        zoomScale: MKZoomScale
    ) {
        let tlUTM = MGRSConverter.latLonToUTM(topLeft)
        let brUTM = MGRSConverter.latLonToUTM(bottomRight)

        guard tlUTM.zone == zone && brUTM.zone == zone else { return }

        let minEasting = floor(min(tlUTM.easting, brUTM.easting) / spacing) * spacing
        let maxEasting = ceil(max(tlUTM.easting, brUTM.easting) / spacing) * spacing
        let minNorthing = floor(min(tlUTM.northing, brUTM.northing) / spacing) * spacing
        let maxNorthing = ceil(max(tlUTM.northing, brUTM.northing) / spacing) * spacing

        // Simplified: just draw lines without detailed curvature
        for easting in stride(from: minEasting, through: maxEasting, by: spacing) {
            let topUTM = MGRSConverter.UTMCoordinate(zone: zone, hemisphere: tlUTM.hemisphere, easting: easting, northing: maxNorthing, latitudeBand: tlUTM.latitudeBand)
            let bottomUTM = MGRSConverter.UTMCoordinate(zone: zone, hemisphere: brUTM.hemisphere, easting: easting, northing: minNorthing, latitudeBand: brUTM.latitudeBand)

            let topCoord = MGRSConverter.utmToLatLon(topUTM)
            let bottomCoord = MGRSConverter.utmToLatLon(bottomUTM)

            let topPoint = point(for: MKMapPoint(topCoord))
            let bottomPoint = point(for: MKMapPoint(bottomCoord))

            context.move(to: topPoint)
            context.addLine(to: bottomPoint)
        }

        for northing in stride(from: minNorthing, through: maxNorthing, by: spacing) {
            let leftUTM = MGRSConverter.UTMCoordinate(zone: zone, hemisphere: tlUTM.hemisphere, easting: minEasting, northing: northing, latitudeBand: tlUTM.latitudeBand)
            let rightUTM = MGRSConverter.UTMCoordinate(zone: zone, hemisphere: brUTM.hemisphere, easting: maxEasting, northing: northing, latitudeBand: brUTM.latitudeBand)

            let leftCoord = MGRSConverter.utmToLatLon(leftUTM)
            let rightCoord = MGRSConverter.utmToLatLon(rightUTM)

            let leftPoint = point(for: MKMapPoint(leftCoord))
            let rightPoint = point(for: MKMapPoint(rightCoord))

            context.move(to: leftPoint)
            context.addLine(to: rightPoint)
        }

        context.strokePath()
    }

    // MARK: - Grid Labels

    private func drawGridLabels(
        topLeft: CLLocationCoordinate2D,
        bottomRight: CLLocationCoordinate2D,
        spacing: Double,
        mapRect: MKMapRect,
        context: CGContext,
        zoomScale: MKZoomScale
    ) {
        let centerLat = (topLeft.latitude + bottomRight.latitude) / 2
        let centerLon = (topLeft.longitude + bottomRight.longitude) / 2
        let centerCoord = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)

        let centerUTM = MGRSConverter.latLonToUTM(centerCoord)
        let tlUTM = MGRSConverter.latLonToUTM(topLeft)
        let brUTM = MGRSConverter.latLonToUTM(bottomRight)

        // Only draw labels if we're in the same zone
        guard tlUTM.zone == brUTM.zone else { return }

        let minEasting = floor(min(tlUTM.easting, brUTM.easting) / spacing) * spacing
        let maxEasting = ceil(max(tlUTM.easting, brUTM.easting) / spacing) * spacing
        let minNorthing = floor(min(tlUTM.northing, brUTM.northing) / spacing) * spacing
        let maxNorthing = ceil(max(tlUTM.northing, brUTM.northing) / spacing) * spacing

        let fontSize = max(8.0, min(14.0, 12.0 / zoomScale))
        let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)

        // Draw easting labels along bottom
        for easting in stride(from: minEasting, through: maxEasting, by: spacing) {
            let utm = MGRSConverter.UTMCoordinate(
                zone: centerUTM.zone,
                hemisphere: centerUTM.hemisphere,
                easting: easting,
                northing: (minNorthing + maxNorthing) / 2,
                latitudeBand: centerUTM.latitudeBand
            )
            let coord = MGRSConverter.utmToLatLon(utm)
            let mapPoint = MKMapPoint(coord)
            let screenPoint = point(for: mapPoint)

            // Format easting label (show only significant digits)
            let eastingKm = Int(easting / 1000) % 100
            let label = String(format: "%02d", eastingKm)

            drawLabel(label, at: screenPoint, font: font, context: context, zoomScale: zoomScale)
        }

        // Draw northing labels along left side
        for northing in stride(from: minNorthing, through: maxNorthing, by: spacing) {
            let utm = MGRSConverter.UTMCoordinate(
                zone: centerUTM.zone,
                hemisphere: centerUTM.hemisphere,
                easting: (minEasting + maxEasting) / 2,
                northing: northing,
                latitudeBand: centerUTM.latitudeBand
            )
            let coord = MGRSConverter.utmToLatLon(utm)
            let mapPoint = MKMapPoint(coord)
            let screenPoint = point(for: mapPoint)

            // Format northing label
            let northingKm = Int(northing / 1000) % 100
            let label = String(format: "%02d", northingKm)

            drawLabel(label, at: screenPoint, font: font, context: context, zoomScale: zoomScale, vertical: true)
        }

        // Draw 100km square identifier at center
        let mgrs = MGRSConverter.latLonToMGRS(centerCoord, precision: .oneMeter)
        let squareLabel = "\(mgrs.gridZoneDesignator) \(mgrs.squareIdentifier)"
        let centerMapPoint = MKMapPoint(centerCoord)
        let centerScreenPoint = point(for: centerMapPoint)

        let largeFontSize = max(12.0, min(20.0, 16.0 / zoomScale))
        let largeFont = UIFont.systemFont(ofSize: largeFontSize, weight: .bold)
        drawLabel(squareLabel, at: centerScreenPoint, font: largeFont, context: context, zoomScale: zoomScale, isLarge: true)
    }

    private func drawLabel(
        _ text: String,
        at point: CGPoint,
        font: UIFont,
        context: CGContext,
        zoomScale: MKZoomScale,
        vertical: Bool = false,
        isLarge: Bool = false
    ) {
        context.saveGState()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: gridOverlay.labelColor
        ]

        let textSize = text.size(withAttributes: attributes)

        // Background rectangle
        let padding: CGFloat = isLarge ? 4.0 : 2.0
        var rect = CGRect(
            x: point.x - textSize.width / 2 - padding,
            y: point.y - textSize.height / 2 - padding,
            width: textSize.width + padding * 2,
            height: textSize.height + padding * 2
        )

        if vertical {
            rect.origin.x = point.x - textSize.width - padding * 3
        }

        // Draw background
        context.setFillColor(gridOverlay.labelBackgroundColor.cgColor)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 2)
        context.addPath(path.cgPath)
        context.fillPath()

        // Draw text
        let textRect = CGRect(
            x: rect.origin.x + padding,
            y: rect.origin.y + padding,
            width: textSize.width,
            height: textSize.height
        )

        UIGraphicsPushContext(context)
        text.draw(in: textRect, withAttributes: attributes)
        UIGraphicsPopContext()

        context.restoreGState()
    }

    // MARK: - Helper Methods

    private func calculateZoomLevel(zoomScale: MKZoomScale) -> Double {
        let maxZoomScale = MKMapSize.world.width / 256.0
        let zoomLevel = max(0, log2(maxZoomScale * Double(zoomScale)))
        return zoomLevel
    }

    private func mapPointToCoordinate(_ mapPoint: MKMapPoint) -> CLLocationCoordinate2D {
        return mapPoint.coordinate
    }
}

// MARK: - MKMapPoint Extension

extension MKMapPoint {
    init(coordinateForLon lon: Double, lat: Double) {
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        self.init(coord)
    }
}

// MARK: - Grid Overlay Configuration

struct MGRSGridConfiguration {
    var isEnabled: Bool = false
    var showLabels: Bool = true
    var adaptiveSpacing: Bool = true
    var lineColor: UIColor = UIColor.gray.withAlphaComponent(0.5)
    var lineWidth: CGFloat = 0.5
    var labelColor: UIColor = UIColor.white.withAlphaComponent(0.8)
    var labelBackgroundColor: UIColor = UIColor.black.withAlphaComponent(0.6)

    func apply(to overlay: MGRSGridOverlay) {
        overlay.showLabels = showLabels
        overlay.lineColor = lineColor
        overlay.lineWidth = lineWidth
        overlay.labelColor = labelColor
        overlay.labelBackgroundColor = labelBackgroundColor
    }
}

// MARK: - Grid Overlay Manager

class MGRSGridManager: ObservableObject {
    @Published var configuration = MGRSGridConfiguration()
    @Published var currentOverlay: MGRSGridOverlay?

    weak var mapView: MKMapView?

    func enableGrid(on mapView: MKMapView) {
        self.mapView = mapView

        if currentOverlay == nil {
            let overlay = MGRSGridOverlay()
            configuration.apply(to: overlay)
            currentOverlay = overlay
            mapView.addOverlay(overlay, level: .aboveLabels)
        }

        configuration.isEnabled = true
    }

    func disableGrid() {
        if let overlay = currentOverlay, let mapView = mapView {
            mapView.removeOverlay(overlay)
        }
        currentOverlay = nil
        configuration.isEnabled = false
    }

    func toggleGrid(on mapView: MKMapView) {
        if configuration.isEnabled {
            disableGrid()
        } else {
            enableGrid(on: mapView)
        }
    }

    func updateConfiguration() {
        if let overlay = currentOverlay {
            configuration.apply(to: overlay)
            // Force redraw
            if let mapView = mapView {
                mapView.removeOverlay(overlay)
                mapView.addOverlay(overlay, level: .aboveLabels)
            }
        }
    }

    func createRenderer(for overlay: MGRSGridOverlay) -> MGRSGridRenderer {
        return MGRSGridRenderer(overlay: overlay)
    }
}
