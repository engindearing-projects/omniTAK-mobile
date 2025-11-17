//
//  MeasurementOverlay.swift
//  OmniTAKMobile
//
//  Custom overlays and renderers for measurement visualization
//

import Foundation
import MapKit
import UIKit

// MARK: - Measurement Polyline Overlay

class MeasurementPolyline: MKPolyline {
    var measurementID: UUID?
    var measurementType: MeasurementType = .distance
    var measurementColor: UIColor = UIColor(red: 1.0, green: 0.988, blue: 0.0, alpha: 1.0)
    var labelText: String?
    var showDistance: Bool = true
}

// MARK: - Measurement Polygon Overlay

class MeasurementPolygon: MKPolygon {
    var measurementID: UUID?
    var measurementColor: UIColor = UIColor(red: 1.0, green: 0.988, blue: 0.0, alpha: 1.0)
    var areaText: String?
    var perimeterText: String?
}

// MARK: - Range Ring Overlay

class RangeRingOverlay: MKCircle {
    var ringID: UUID?
    var ringColor: UIColor = UIColor(red: 1.0, green: 0.988, blue: 0.0, alpha: 1.0)
    var labelText: String = ""
    var showLabel: Bool = true
    var isDashed: Bool = true
    var lineWidth: CGFloat = 2.0
}

// MARK: - Measurement Polyline Renderer

class MeasurementPolylineRenderer: MKPolylineRenderer {

    var labelText: String?
    var showDistance: Bool = true

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        // Draw the line with dashed pattern
        self.strokeColor = (overlay as? MeasurementPolyline)?.measurementColor ?? UIColor(red: 1.0, green: 0.988, blue: 0.0, alpha: 1.0)
        self.lineWidth = 3.0
        self.lineDashPattern = [8, 4] // Dashed line

        super.draw(mapRect, zoomScale: zoomScale, in: context)

        // Draw distance labels along the line
        if showDistance, let polyline = overlay as? MeasurementPolyline {
            drawDistanceLabels(polyline: polyline, mapRect: mapRect, zoomScale: zoomScale, in: context)
        }
    }

    private func drawDistanceLabels(polyline: MeasurementPolyline, mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard polyline.pointCount >= 2 else { return }

        let points = polyline.points()
        var coordinates: [CLLocationCoordinate2D] = []

        for i in 0..<polyline.pointCount {
            let mapPoint = points[i]
            coordinates.append(mapPoint.coordinate)
        }

        // Draw total distance at midpoint of last segment
        if coordinates.count >= 2 {
            let lastIndex = coordinates.count - 1
            let midLat = (coordinates[lastIndex - 1].latitude + coordinates[lastIndex].latitude) / 2.0
            let midLon = (coordinates[lastIndex - 1].longitude + coordinates[lastIndex].longitude) / 2.0
            let midpoint = MKMapPoint(CLLocationCoordinate2D(latitude: midLat, longitude: midLon))

            if mapRect.contains(midpoint) {
                let totalDistance = MeasurementCalculator.pathDistance(coordinates: coordinates)
                let label = MeasurementCalculator.formatDistance(totalDistance)

                drawLabel(label, at: midpoint, zoomScale: zoomScale, in: context)
            }
        }
    }

    private func drawLabel(_ text: String, at mapPoint: MKMapPoint, zoomScale: MKZoomScale, in context: CGContext) {
        let point = self.point(for: mapPoint)

        context.saveGState()

        // Scale font size based on zoom
        let fontSize: CGFloat = 12.0 / zoomScale
        let font = UIFont.boldSystemFont(ofSize: fontSize)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
            .backgroundColor: UIColor.black.withAlphaComponent(0.7)
        ]

        let nsString = text as NSString
        let size = nsString.size(withAttributes: attributes)

        // Draw background
        let rect = CGRect(
            x: point.x - size.width / 2 - 4,
            y: point.y - size.height / 2 - 2,
            width: size.width + 8,
            height: size.height + 4
        )

        context.setFillColor(UIColor.black.withAlphaComponent(0.7).cgColor)
        context.fill(rect)

        // Draw text
        UIGraphicsPushContext(context)
        nsString.draw(
            at: CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2),
            withAttributes: [
                .font: font,
                .foregroundColor: UIColor.white
            ]
        )
        UIGraphicsPopContext()

        context.restoreGState()
    }
}

// MARK: - Measurement Polygon Renderer

class MeasurementPolygonRenderer: MKPolygonRenderer {

    var areaText: String?
    var perimeterText: String?

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        // Draw the polygon
        let color = (overlay as? MeasurementPolygon)?.measurementColor ?? UIColor(red: 1.0, green: 0.988, blue: 0.0, alpha: 1.0)
        self.strokeColor = color
        self.fillColor = color.withAlphaComponent(0.2)
        self.lineWidth = 3.0
        self.lineDashPattern = [8, 4]

        super.draw(mapRect, zoomScale: zoomScale, in: context)

        // Draw area label at centroid
        if let polygon = overlay as? MeasurementPolygon {
            drawAreaLabel(polygon: polygon, mapRect: mapRect, zoomScale: zoomScale, in: context)
        }
    }

    private func drawAreaLabel(polygon: MeasurementPolygon, mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard polygon.pointCount >= 3 else { return }

        // Calculate centroid
        let points = polygon.points()
        var sumLat: Double = 0
        var sumLon: Double = 0

        for i in 0..<polygon.pointCount {
            let coord = points[i].coordinate
            sumLat += coord.latitude
            sumLon += coord.longitude
        }

        let centroidLat = sumLat / Double(polygon.pointCount)
        let centroidLon = sumLon / Double(polygon.pointCount)
        let centroid = MKMapPoint(CLLocationCoordinate2D(latitude: centroidLat, longitude: centroidLon))

        if mapRect.contains(centroid) {
            // Calculate area
            var coordinates: [CLLocationCoordinate2D] = []
            for i in 0..<polygon.pointCount {
                coordinates.append(points[i].coordinate)
            }

            let area = MeasurementCalculator.polygonArea(coordinates: coordinates)
            let label = MeasurementCalculator.formatArea(area)

            drawLabel(label, at: centroid, zoomScale: zoomScale, in: context)
        }
    }

    private func drawLabel(_ text: String, at mapPoint: MKMapPoint, zoomScale: MKZoomScale, in context: CGContext) {
        let point = self.point(for: mapPoint)

        context.saveGState()

        let fontSize: CGFloat = 12.0 / zoomScale
        let font = UIFont.boldSystemFont(ofSize: fontSize)

        let nsString = text as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        let size = nsString.size(withAttributes: attributes)

        // Draw background
        let rect = CGRect(
            x: point.x - size.width / 2 - 4,
            y: point.y - size.height / 2 - 2,
            width: size.width + 8,
            height: size.height + 4
        )

        context.setFillColor(UIColor.black.withAlphaComponent(0.7).cgColor)
        context.fill(rect)

        // Draw text
        UIGraphicsPushContext(context)
        nsString.draw(
            at: CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2),
            withAttributes: [
                .font: font,
                .foregroundColor: UIColor.white
            ]
        )
        UIGraphicsPopContext()

        context.restoreGState()
    }
}

// MARK: - Range Ring Renderer

class RangeRingRenderer: MKCircleRenderer {

    var labelText: String = ""
    var showLabel: Bool = true

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        // Draw the circle with dashed line
        if let ringOverlay = overlay as? RangeRingOverlay {
            self.strokeColor = ringOverlay.ringColor
            self.lineWidth = ringOverlay.lineWidth

            if ringOverlay.isDashed {
                self.lineDashPattern = [10, 5]
            }

            self.labelText = ringOverlay.labelText
            self.showLabel = ringOverlay.showLabel
        } else {
            self.strokeColor = UIColor(red: 1.0, green: 0.988, blue: 0.0, alpha: 1.0)
            self.lineWidth = 2.0
            self.lineDashPattern = [10, 5]
        }

        self.fillColor = nil

        super.draw(mapRect, zoomScale: zoomScale, in: context)

        // Draw distance label
        if showLabel {
            drawDistanceLabel(mapRect: mapRect, zoomScale: zoomScale, in: context)
        }
    }

    private func drawDistanceLabel(mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard let circle = overlay as? MKCircle else { return }

        // Position label at top of circle
        let centerLat = circle.coordinate.latitude
        let centerLon = circle.coordinate.longitude

        // Calculate position at top of circle (approximate)
        let radiusInDegrees = circle.radius / 111000.0 // Rough conversion
        let topCoord = CLLocationCoordinate2D(
            latitude: centerLat + radiusInDegrees,
            longitude: centerLon
        )

        let labelPoint = MKMapPoint(topCoord)

        if mapRect.contains(labelPoint) {
            let text = labelText.isEmpty ? MeasurementCalculator.formatDistance(circle.radius) : labelText
            drawLabel(text, at: labelPoint, zoomScale: zoomScale, in: context)
        }
    }

    private func drawLabel(_ text: String, at mapPoint: MKMapPoint, zoomScale: MKZoomScale, in context: CGContext) {
        let point = self.point(for: mapPoint)

        context.saveGState()

        let fontSize: CGFloat = 10.0 / zoomScale
        let font = UIFont.boldSystemFont(ofSize: fontSize)

        let nsString = text as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white
        ]
        let size = nsString.size(withAttributes: attributes)

        // Draw background
        let rect = CGRect(
            x: point.x - size.width / 2 - 3,
            y: point.y - size.height - 2,
            width: size.width + 6,
            height: size.height + 4
        )

        context.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
        context.fill(rect)

        // Draw text
        UIGraphicsPushContext(context)
        nsString.draw(
            at: CGPoint(x: point.x - size.width / 2, y: point.y - size.height),
            withAttributes: [
                .font: font,
                .foregroundColor: UIColor.white
            ]
        )
        UIGraphicsPopContext()

        context.restoreGState()
    }
}

// MARK: - Bearing Arrow Overlay

class BearingArrowOverlay: MKPolyline {
    var bearingDegrees: Double = 0
    var measurementColor: UIColor = UIColor(red: 1.0, green: 0.988, blue: 0.0, alpha: 1.0)
    var distanceMeters: Double = 0
}

// MARK: - Bearing Arrow Renderer

class BearingArrowRenderer: MKPolylineRenderer {

    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        // Draw the line
        if let bearingOverlay = overlay as? BearingArrowOverlay {
            self.strokeColor = bearingOverlay.measurementColor
        } else {
            self.strokeColor = UIColor(red: 1.0, green: 0.988, blue: 0.0, alpha: 1.0)
        }

        self.lineWidth = 3.0

        super.draw(mapRect, zoomScale: zoomScale, in: context)

        // Draw arrow head at end
        if let polyline = overlay as? MKPolyline, polyline.pointCount >= 2 {
            drawArrowHead(polyline: polyline, zoomScale: zoomScale, in: context)
        }

        // Draw bearing label
        if let bearingOverlay = overlay as? BearingArrowOverlay {
            drawBearingLabel(overlay: bearingOverlay, mapRect: mapRect, zoomScale: zoomScale, in: context)
        }
    }

    private func drawArrowHead(polyline: MKPolyline, zoomScale: MKZoomScale, in context: CGContext) {
        let points = polyline.points()
        let lastIndex = polyline.pointCount - 1
        guard lastIndex > 0 else { return }

        let endPoint = self.point(for: points[lastIndex])
        let prevPoint = self.point(for: points[lastIndex - 1])

        // Calculate angle
        let angle = atan2(endPoint.y - prevPoint.y, endPoint.x - prevPoint.x)

        // Arrow size
        let arrowSize: CGFloat = 15.0 / zoomScale

        // Arrow points
        let arrowAngle: CGFloat = .pi / 6 // 30 degrees

        let leftPoint = CGPoint(
            x: endPoint.x - arrowSize * cos(angle - arrowAngle),
            y: endPoint.y - arrowSize * sin(angle - arrowAngle)
        )

        let rightPoint = CGPoint(
            x: endPoint.x - arrowSize * cos(angle + arrowAngle),
            y: endPoint.y - arrowSize * sin(angle + arrowAngle)
        )

        // Draw arrow
        context.saveGState()

        if let color = strokeColor {
            context.setFillColor(color.cgColor)
        }
        context.move(to: endPoint)
        context.addLine(to: leftPoint)
        context.addLine(to: rightPoint)
        context.closePath()
        context.fillPath()

        context.restoreGState()
    }

    private func drawBearingLabel(overlay: BearingArrowOverlay, mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard overlay.pointCount >= 2 else { return }

        let points = overlay.points()
        let midLat = (points[0].coordinate.latitude + points[1].coordinate.latitude) / 2.0
        let midLon = (points[0].coordinate.longitude + points[1].coordinate.longitude) / 2.0
        let midpoint = MKMapPoint(CLLocationCoordinate2D(latitude: midLat, longitude: midLon))

        if mapRect.contains(midpoint) {
            let bearingText = MeasurementCalculator.formatBearing(overlay.bearingDegrees)
            let distanceText = MeasurementCalculator.formatDistance(overlay.distanceMeters)
            let label = "\(bearingText)\n\(distanceText)"

            drawLabel(label, at: midpoint, zoomScale: zoomScale, in: context)
        }
    }

    private func drawLabel(_ text: String, at mapPoint: MKMapPoint, zoomScale: MKZoomScale, in context: CGContext) {
        let point = self.point(for: mapPoint)

        context.saveGState()

        let fontSize: CGFloat = 11.0 / zoomScale
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
            with: CGSize(width: 200, height: 100),
            options: .usesLineFragmentOrigin,
            attributes: attributes,
            context: nil
        ).size

        // Draw background
        let rect = CGRect(
            x: point.x - size.width / 2 - 4,
            y: point.y - size.height / 2 - 2,
            width: size.width + 8,
            height: size.height + 4
        )

        context.setFillColor(UIColor.black.withAlphaComponent(0.7).cgColor)
        context.fill(rect)

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

// MARK: - Measurement Overlay Factory

class MeasurementOverlayFactory {

    static func createOverlayForMeasurement(_ measurement: Measurement) -> MKOverlay? {
        switch measurement.type {
        case .distance:
            return createDistanceOverlay(measurement)

        case .bearing:
            return createBearingOverlay(measurement)

        case .area:
            return createAreaOverlay(measurement)

        case .rangeRing:
            // Range rings are handled separately
            return nil
        }
    }

    private static func createDistanceOverlay(_ measurement: Measurement) -> MKOverlay? {
        guard measurement.points.count >= 2 else { return nil }

        let polyline = MeasurementPolyline(coordinates: measurement.points, count: measurement.points.count)
        polyline.measurementID = measurement.id
        polyline.measurementType = .distance
        polyline.measurementColor = measurement.color
        polyline.showDistance = true

        if let distance = measurement.result.distanceMeters {
            polyline.labelText = MeasurementCalculator.formatDistance(distance)
        }

        return polyline
    }

    private static func createBearingOverlay(_ measurement: Measurement) -> MKOverlay? {
        guard measurement.points.count >= 2 else { return nil }

        let arrow = BearingArrowOverlay(coordinates: measurement.points, count: 2)
        arrow.measurementColor = measurement.color
        arrow.bearingDegrees = measurement.result.bearingDegrees ?? 0
        arrow.distanceMeters = measurement.result.distanceMeters ?? 0

        return arrow
    }

    private static func createAreaOverlay(_ measurement: Measurement) -> MKOverlay? {
        guard measurement.points.count >= 3 else { return nil }

        let polygon = MeasurementPolygon(coordinates: measurement.points, count: measurement.points.count)
        polygon.measurementID = measurement.id
        polygon.measurementColor = measurement.color

        if let area = measurement.result.areaSquareMeters {
            polygon.areaText = MeasurementCalculator.formatArea(area)
        }

        return polygon
    }

    static func createRangeRingOverlays(_ rangeRings: [RangeRing]) -> [RangeRingOverlay] {
        return rangeRings.filter { $0.isVisible }.map { ring in
            let overlay = RangeRingOverlay(center: ring.center, radius: ring.radiusMeters)
            overlay.ringID = ring.id
            overlay.ringColor = ring.color
            overlay.labelText = ring.label
            overlay.showLabel = true
            overlay.isDashed = true
            return overlay
        }
    }

    static func rendererForOverlay(_ overlay: MKOverlay) -> MKOverlayRenderer {
        if let measurementPolyline = overlay as? MeasurementPolyline {
            let renderer = MeasurementPolylineRenderer(polyline: measurementPolyline)
            renderer.labelText = measurementPolyline.labelText
            renderer.showDistance = measurementPolyline.showDistance
            return renderer
        }

        if let bearingArrow = overlay as? BearingArrowOverlay {
            let renderer = BearingArrowRenderer(polyline: bearingArrow)
            return renderer
        }

        if let measurementPolygon = overlay as? MeasurementPolygon {
            let renderer = MeasurementPolygonRenderer(polygon: measurementPolygon)
            renderer.areaText = measurementPolygon.areaText
            renderer.perimeterText = measurementPolygon.perimeterText
            return renderer
        }

        if let rangeRing = overlay as? RangeRingOverlay {
            let renderer = RangeRingRenderer(circle: rangeRing)
            renderer.labelText = rangeRing.labelText
            renderer.showLabel = rangeRing.showLabel
            return renderer
        }

        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor(red: 1.0, green: 0.988, blue: 0.0, alpha: 1.0)
            renderer.lineWidth = 2.0
            return renderer
        }

        if let polygon = overlay as? MKPolygon {
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.strokeColor = UIColor(red: 1.0, green: 0.988, blue: 0.0, alpha: 1.0)
            renderer.fillColor = UIColor(red: 1.0, green: 0.988, blue: 0.0, alpha: 0.2)
            renderer.lineWidth = 2.0
            return renderer
        }

        if let circle = overlay as? MKCircle {
            let renderer = MKCircleRenderer(circle: circle)
            renderer.strokeColor = UIColor(red: 1.0, green: 0.988, blue: 0.0, alpha: 1.0)
            renderer.lineWidth = 2.0
            return renderer
        }

        return MKOverlayRenderer(overlay: overlay)
    }
}
