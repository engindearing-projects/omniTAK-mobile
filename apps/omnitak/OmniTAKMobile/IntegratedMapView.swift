//
//  IntegratedMapView.swift
//  OmniTAKMobile
//
//  Enhanced MapView integration with MGRS grid, overlays, and state management
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Integrated Map View

struct IntegratedMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var mapType: MKMapType
    @Binding var trackingMode: MapUserTrackingMode

    let markers: [CoTMarker]
    let showsUserLocation: Bool

    @ObservedObject var drawingStore: DrawingStore
    @ObservedObject var drawingManager: DrawingToolsManager
    @ObservedObject var radialMenuCoordinator: RadialMenuMapCoordinator
    @ObservedObject var overlayCoordinator: MapOverlayCoordinator
    @ObservedObject var stateManager: MapStateManager

    let onMapTap: (CLLocationCoordinate2D) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.mapType = mapType
        mapView.region = region

        // Configure map view based on state manager
        mapView.isScrollEnabled = stateManager.allowsPanning
        mapView.isZoomEnabled = stateManager.allowsZooming
        mapView.isRotateEnabled = stateManager.allowsRotation

        // Add gesture recognizers
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMapTap(_:))
        )
        mapView.addGestureRecognizer(tapGesture)

        let longPressGesture = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPressGesture.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPressGesture)

        // Configure overlay coordinator with map view
        overlayCoordinator.configure(with: mapView)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self

        // Update map type
        if mapView.mapType != mapType {
            mapView.mapType = mapType
        }

        // Update region if not user interacting
        if !context.coordinator.isUserInteracting {
            mapView.setRegion(region, animated: true)
        }

        // Update gesture permissions
        mapView.isScrollEnabled = stateManager.allowsPanning
        mapView.isZoomEnabled = stateManager.allowsZooming
        mapView.isRotateEnabled = stateManager.allowsRotation

        // Update annotations
        updateAnnotations(mapView: mapView, context: context)

        // Update overlays
        updateOverlays(mapView: mapView, context: context)

        // Update center coordinate in state manager
        stateManager.updateMapCenter(mapView.centerCoordinate)
        overlayCoordinator.updateCenterMGRS(for: mapView.centerCoordinate)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Annotation Updates

    private func updateAnnotations(mapView: MKMapView, context: Context) {
        // Remove old CoT annotations
        let oldAnnotations = mapView.annotations.filter { annotation in
            !(annotation is MKUserLocation) &&
            !context.coordinator.isDrawingAnnotation(annotation)
        }
        mapView.removeAnnotations(oldAnnotations)

        // Add new CoT annotations
        let annotations = markers.map { marker -> MKPointAnnotation in
            let annotation = MKPointAnnotation()
            annotation.coordinate = marker.coordinate
            annotation.title = marker.callsign
            annotation.subtitle = marker.type
            return annotation
        }
        mapView.addAnnotations(annotations)

        // Update drawing annotations
        updateDrawingAnnotations(mapView: mapView, context: context)
    }

    private func updateDrawingAnnotations(mapView: MKMapView, context: Context) {
        let oldDrawingAnnotations = mapView.annotations.filter {
            context.coordinator.isDrawingAnnotation($0)
        }
        mapView.removeAnnotations(oldDrawingAnnotations)

        // Add drawing marker annotations
        for marker in drawingStore.markers {
            let annotation = DrawingMarkerAnnotation(marker: marker)
            mapView.addAnnotation(annotation)
        }

        // Add temporary drawing points
        if drawingManager.isDrawingActive {
            let tempAnnotations = drawingManager.getTemporaryAnnotations()
            mapView.addAnnotations(tempAnnotations)
        }
    }

    // MARK: - Overlay Updates

    private func updateOverlays(mapView: MKMapView, context: Context) {
        // Get all current overlays sorted by z-order
        var allOverlays: [(MKOverlay, Int)] = []

        // MGRS Grid (z-order 0) - managed by coordinator
        if overlayCoordinator.mgrsGridEnabled {
            if let mgrsOverlay = context.coordinator.getMGRSOverlay() {
                allOverlays.append((mgrsOverlay, 0))
            } else {
                // Create new MGRS overlay if needed
                let overlay = MGRSGridOverlay()
                overlay.showLabels = overlayCoordinator.showMGRSLabels
                overlay.lineColor = overlayCoordinator.mgrsLineColor
                overlay.labelColor = overlayCoordinator.mgrsLabelColor

                if let spacing = overlayCoordinator.mgrsGridDensity.spacing {
                    overlay.gridSpacing = spacing
                }

                context.coordinator.setMGRSOverlay(overlay)
                allOverlays.append((overlay, 0))
            }
        } else {
            context.coordinator.removeMGRSOverlay(from: mapView)
        }

        // Drawing overlays (z-order 10-30)
        let savedOverlays = drawingStore.getAllOverlays()
        for overlay in savedOverlays {
            allOverlays.append((overlay, 20))
        }

        // Temporary drawing overlay (z-order 25)
        if let tempOverlay = drawingManager.getTemporaryOverlay() {
            allOverlays.append((tempOverlay, 25))
        }

        // Range & Bearing line (z-order 35)
        if stateManager.rangeBearingState.isComplete,
           let first = stateManager.rangeBearingState.firstPoint,
           let second = stateManager.rangeBearingState.secondPoint {
            var coords = [first, second]
            let rbLine = MKPolyline(coordinates: &coords, count: 2)
            allOverlays.append((rbLine, 35))
        }

        // Sort by z-order and add to map
        allOverlays.sort { $0.1 < $1.1 }

        // Remove old non-MGRS overlays
        let currentOverlays = mapView.overlays.filter { !($0 is MGRSGridOverlay) }
        mapView.removeOverlays(currentOverlays)

        // Add overlays in z-order
        for (overlay, _) in allOverlays where !(overlay is MGRSGridOverlay) {
            mapView.addOverlay(overlay, level: .aboveRoads)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: IntegratedMapView
        var isUserInteracting = false
        private var mgrsOverlay: MGRSGridOverlay?

        init(_ parent: IntegratedMapView) {
            self.parent = parent
        }

        // MARK: - MGRS Overlay Management

        func getMGRSOverlay() -> MGRSGridOverlay? {
            return mgrsOverlay
        }

        func setMGRSOverlay(_ overlay: MGRSGridOverlay) {
            mgrsOverlay = overlay
        }

        func removeMGRSOverlay(from mapView: MKMapView) {
            if let overlay = mgrsOverlay {
                mapView.removeOverlay(overlay)
                mgrsOverlay = nil
            }
        }

        // MARK: - Gesture Handlers

        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            // Update state manager
            parent.stateManager.handleMapTap(at: coordinate, screenPoint: point)

            // Call external handler
            parent.onMapTap(coordinate)
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return }
            guard let mapView = gesture.view as? MKMapView else { return }

            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            // Check if long-press is on an overlay
            let mapPoint = MKMapPoint(coordinate)
            var hitOverlay: MKOverlay? = nil
            var drawingId: UUID? = nil
            var drawingType: RadialMenuContext.DrawingType? = nil

            for overlay in mapView.overlays {
                if overlay is MGRSGridOverlay {
                    continue // Skip MGRS grid
                }

                if let polygon = overlay as? MKPolygon {
                    let renderer = MKPolygonRenderer(polygon: polygon)
                    let mapPointForRenderer = renderer.point(for: mapPoint)
                    if renderer.path.contains(mapPointForRenderer) {
                        hitOverlay = overlay
                        if let found = parent.drawingStore.polygons.first(where: { drawing in
                            drawing.coordinates.count == polygon.pointCount
                        }) {
                            drawingId = found.id
                            drawingType = .polygon
                        }
                        break
                    }
                } else if let circle = overlay as? MKCircle {
                    let circleCenter = MKMapPoint(circle.coordinate)
                    let distance = mapPoint.distance(to: circleCenter)
                    if distance <= circle.radius {
                        hitOverlay = overlay
                        if let found = parent.drawingStore.circles.first(where: { drawing in
                            abs(drawing.center.latitude - circle.coordinate.latitude) < 0.0001 &&
                            abs(drawing.center.longitude - circle.coordinate.longitude) < 0.0001
                        }) {
                            drawingId = found.id
                            drawingType = .circle
                        }
                        break
                    }
                } else if let polyline = overlay as? MKPolyline {
                    let renderer = MKPolylineRenderer(polyline: polyline)
                    let mapPointForRenderer = renderer.point(for: mapPoint)
                    let strokePath = renderer.path.copy(
                        strokingWithWidth: 30.0,
                        lineCap: .round,
                        lineJoin: .round,
                        miterLimit: 10
                    )
                    if strokePath.contains(mapPointForRenderer) {
                        hitOverlay = overlay
                        if let found = parent.drawingStore.lines.first(where: { drawing in
                            drawing.coordinates.count == polyline.pointCount
                        }) {
                            drawingId = found.id
                            drawingType = .line
                        }
                        break
                    }
                }
            }

            let screenPoint = gesture.location(in: mapView)

            if hitOverlay != nil {
                parent.radialMenuCoordinator.showContextMenu(
                    at: screenPoint,
                    for: coordinate,
                    menuType: .markerContext,
                    drawingId: drawingId,
                    drawingType: drawingType
                )
            } else {
                parent.radialMenuCoordinator.showContextMenu(
                    at: screenPoint,
                    for: coordinate,
                    menuType: .mapContext
                )
            }
        }

        func isDrawingAnnotation(_ annotation: MKAnnotation) -> Bool {
            return annotation is DrawingMarkerAnnotation ||
                   annotation is DrawingLabelAnnotation ||
                   annotation.title == "Point"
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            isUserInteracting = true
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region
                self.parent.stateManager.updateMapRegion(mapView.region)
                self.parent.overlayCoordinator.updateVisibleOverlays(in: mapView.region)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isUserInteracting = false
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }

            // Drawing marker annotations
            if let drawingAnnotation = annotation as? DrawingMarkerAnnotation {
                let identifier = "DrawingMarker"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = annotation
                }

                let size = CGSize(width: 30, height: 30)
                let renderer = UIGraphicsImageRenderer(size: size)
                let image = renderer.image { context in
                    drawingAnnotation.marker.color.uiColor.setFill()
                    let path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
                    path.fill()

                    UIColor.white.setStroke()
                    path.lineWidth = 2
                    path.stroke()
                }

                annotationView?.image = image
                annotationView?.centerOffset = CGPoint(x: 0, y: -size.height / 2)

                return annotationView
            }

            // Temporary point annotations
            if annotation.title == "Point" {
                let identifier = "TempPoint"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                } else {
                    annotationView?.annotation = annotation
                }

                let size = CGSize(width: 12, height: 12)
                let renderer = UIGraphicsImageRenderer(size: size)
                let image = renderer.image { context in
                    UIColor.systemYellow.setFill()
                    let path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
                    path.fill()

                    UIColor.white.setStroke()
                    path.lineWidth = 2
                    path.stroke()
                }

                annotationView?.image = image
                return annotationView
            }

            // CoT marker annotations
            let identifier = "CoTMarker"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }

            let type = annotation.subtitle ?? ""
            let color: UIColor
            if type?.contains("a-f") == true {
                color = .systemBlue
            } else if type?.contains("a-h") == true {
                color = .systemRed
            } else {
                color = .systemYellow
            }

            let size = CGSize(width: 30, height: 30)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { context in
                color.setFill()
                let path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
                path.fill()

                UIColor.white.setStroke()
                path.lineWidth = 2
                path.stroke()
            }

            annotationView?.image = image
            annotationView?.centerOffset = CGPoint(x: 0, y: -size.height / 2)

            return annotationView
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // MGRS Grid
            if let mgrsOverlay = overlay as? MGRSGridOverlay {
                return MGRSGridRenderer(overlay: mgrsOverlay)
            }

            // Check if coordinator can provide renderer
            if let renderer = parent.overlayCoordinator.renderer(for: overlay) {
                return renderer
            }

            // Drawing overlays - get color from drawing store
            let color = parent.drawingStore.getDrawingColor(for: overlay)?.uiColor ?? UIColor.systemRed

            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = color
                renderer.lineWidth = 3
                return renderer
            }

            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.strokeColor = color
                renderer.fillColor = color.withAlphaComponent(0.2)
                renderer.lineWidth = 2
                return renderer
            }

            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.strokeColor = color
                renderer.fillColor = color.withAlphaComponent(0.2)
                renderer.lineWidth = 2
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
