import SwiftUI
import MapKit

// UIViewRepresentable for enhanced map with trails, custom markers, and info panels
struct EnhancedMapViewRepresentable: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var mapType: MKMapType
    @Binding var trackingMode: MapUserTrackingMode
    let markers: [EnhancedCoTMarker]
    let showsUserLocation: Bool
    @ObservedObject var drawingStore: DrawingStore
    @ObservedObject var drawingManager: DrawingToolsManager
    @ObservedObject var takService: TAKService
    let onMapTap: (CLLocationCoordinate2D) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = mapType
        mapView.showsUserLocation = showsUserLocation
        mapView.setRegion(region, animated: false)

        // Add tap gesture for drawing
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMapTap(_:))
        )
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update map type
        if mapView.mapType != mapType {
            mapView.mapType = mapType
        }

        // Update region if changed significantly
        let currentCenter = mapView.region.center
        let latDiff = abs(currentCenter.latitude - region.center.latitude)
        let lonDiff = abs(currentCenter.longitude - region.center.longitude)

        if latDiff > 0.0001 || lonDiff > 0.0001 {
            mapView.setRegion(region, animated: true)
        }

        // Update markers
        context.coordinator.updateMarkers(mapView: mapView, markers: markers)

        // Update trails
        context.coordinator.updateTrails(mapView: mapView, markers: markers)

        // Update drawings
        context.coordinator.updateDrawings(mapView: mapView, store: drawingStore)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: EnhancedMapViewRepresentable
        private var markerAnnotations: [String: MKAnnotation] = [:]
        private var trailOverlays: [String: MKPolyline] = [:]
        private var drawingOverlays: [UUID: MKOverlay] = [:]
        private var selectedMarker: EnhancedCoTMarker?

        init(_ parent: EnhancedMapViewRepresentable) {
            self.parent = parent
        }

        // MARK: - Marker Management

        func updateMarkers(mapView: MKMapView, markers: [EnhancedCoTMarker]) {
            let currentUIDs = Set(markers.map { $0.uid })
            let existingUIDs = Set(markerAnnotations.keys)

            // Remove old markers
            let toRemove = existingUIDs.subtracting(currentUIDs)
            for uid in toRemove {
                if let annotation = markerAnnotations[uid] {
                    mapView.removeAnnotation(annotation)
                    markerAnnotations.removeValue(forKey: uid)
                }
            }

            // Add/update markers
            for marker in markers {
                if let existingAnnotation = markerAnnotations[marker.uid] as? MarkerAnnotation {
                    // Update existing
                    existingAnnotation.marker = marker
                } else {
                    // Add new
                    let annotation = MarkerAnnotation(marker: marker)
                    mapView.addAnnotation(annotation)
                    markerAnnotations[marker.uid] = annotation
                }
            }
        }

        // MARK: - Trail Management

        func updateTrails(mapView: MKMapView, markers: [EnhancedCoTMarker]) {
            let currentUIDs = Set(markers.map { $0.uid })
            let existingUIDs = Set(trailOverlays.keys)

            // Remove old trails
            let toRemove = existingUIDs.subtracting(currentUIDs)
            for uid in toRemove {
                if let overlay = trailOverlays[uid] {
                    mapView.removeOverlay(overlay)
                    trailOverlays.removeValue(forKey: uid)
                }
            }

            // Add/update trails
            for marker in markers where marker.positionHistory.count > 1 {
                var coordinates = marker.positionHistory.map { $0.coordinate }
                let polyline = MKPolyline(coordinates: &coordinates, count: coordinates.count)

                if let existingOverlay = trailOverlays[marker.uid] {
                    mapView.removeOverlay(existingOverlay)
                }

                mapView.addOverlay(polyline)
                trailOverlays[marker.uid] = polyline
            }
        }

        // MARK: - Drawing Management

        func updateDrawings(mapView: MKMapView, store: DrawingStore) {
            // Remove old overlays
            let currentIDs = Set(
                store.markers.map { $0.id } +
                store.lines.map { $0.id } +
                store.circles.map { $0.id } +
                store.polygons.map { $0.id }
            )
            let existingIDs = Set(drawingOverlays.keys)
            let toRemove = existingIDs.subtracting(currentIDs)

            for id in toRemove {
                if let overlay = drawingOverlays[id] {
                    mapView.removeOverlay(overlay)
                    drawingOverlays.removeValue(forKey: id)
                }
            }

            // Add new overlays
            for marker in store.markers where drawingOverlays[marker.id] == nil {
                let overlay = marker.createOverlay()
                mapView.addOverlay(overlay)
                drawingOverlays[marker.id] = overlay
            }

            for line in store.lines where drawingOverlays[line.id] == nil {
                let overlay = line.createOverlay()
                mapView.addOverlay(overlay)
                drawingOverlays[line.id] = overlay
            }

            for circle in store.circles where drawingOverlays[circle.id] == nil {
                let overlay = circle.createOverlay()
                mapView.addOverlay(overlay)
                drawingOverlays[circle.id] = overlay
            }

            for polygon in store.polygons where drawingOverlays[polygon.id] == nil {
                let overlay = polygon.createOverlay()
                mapView.addOverlay(overlay)
                drawingOverlays[polygon.id] = overlay
            }
        }

        // MARK: - Map Tap

        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onMapTap(coordinate)
        }

        // MARK: - MKMapViewDelegate

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let markerAnnotation = annotation as? MarkerAnnotation else {
                return nil
            }

            let identifier = "EnhancedMarker"
            var view: CustomMarkerAnnotation

            if let dequeuedView = mapView.dequeueReusableAnnotationView(
                withIdentifier: identifier
            ) as? CustomMarkerAnnotation {
                view = dequeuedView
                view.marker = markerAnnotation.marker
            } else {
                view = CustomMarkerAnnotation(
                    annotation: annotation,
                    reuseIdentifier: identifier
                )
                view.marker = markerAnnotation.marker
            }

            return view
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // Trail overlays
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .cyan.withAlphaComponent(0.7)
                renderer.lineWidth = 3
                renderer.lineCap = .round
                return renderer
            }

            // Circle overlays
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.strokeColor = .blue.withAlphaComponent(0.8)
                renderer.fillColor = .blue.withAlphaComponent(0.2)
                renderer.lineWidth = 2
                return renderer
            }

            // Polygon overlays
            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.strokeColor = .red.withAlphaComponent(0.8)
                renderer.fillColor = .red.withAlphaComponent(0.2)
                renderer.lineWidth = 2
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let markerAnnotation = view.annotation as? MarkerAnnotation else {
                return
            }
            selectedMarker = markerAnnotation.marker
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
        }
    }
}

// MARK: - Marker Annotation

class MarkerAnnotation: NSObject, MKAnnotation {
    var marker: EnhancedCoTMarker
    dynamic var coordinate: CLLocationCoordinate2D

    var title: String? {
        marker.callsign
    }

    var subtitle: String? {
        marker.team
    }

    init(marker: EnhancedCoTMarker) {
        self.marker = marker
        self.coordinate = marker.coordinate
        super.init()
    }
}
