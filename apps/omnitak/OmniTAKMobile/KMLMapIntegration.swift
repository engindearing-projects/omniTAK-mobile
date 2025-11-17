//
//  KMLMapIntegration.swift
//  OmniTAKMobile
//
//  Integration layer between KML overlays and the map view
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - KML-Enabled Tactical Map View

/// Extended tactical map view with KML support
struct KMLTacticalMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var mapType: MKMapType
    @Binding var trackingMode: MapUserTrackingMode
    let markers: [CoTMarker]
    let showsUserLocation: Bool
    @ObservedObject var drawingStore: DrawingStore
    @ObservedObject var drawingManager: DrawingToolsManager
    @ObservedObject var kmlManager: KMLOverlayManager
    let onMapTap: (CLLocationCoordinate2D) -> Void
    let onKMLFeatureTap: ((KMLPlacemark) -> Void)?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.mapType = mapType
        mapView.region = region

        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update coordinator reference
        context.coordinator.parent = self

        // Update map type
        if mapView.mapType != mapType {
            mapView.mapType = mapType
        }

        // Update region
        if !context.coordinator.isUserInteracting {
            mapView.setRegion(region, animated: true)
        }

        // Update markers
        updateAnnotations(mapView: mapView, markers: markers, context: context)

        // Update overlays (including KML)
        updateAllOverlays(mapView: mapView, context: context)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func updateAnnotations(mapView: MKMapView, markers: [CoTMarker], context: Context) {
        // Remove old CoT annotations (but keep drawing and KML annotations)
        let oldAnnotations = mapView.annotations.filter { annotation in
            !(annotation is MKUserLocation) &&
            !context.coordinator.isDrawingAnnotation(annotation) &&
            !(annotation is KMLPointAnnotation)
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

        // Update KML annotations
        updateKMLAnnotations(mapView: mapView, context: context)
    }

    private func updateDrawingAnnotations(mapView: MKMapView, context: Context) {
        // Remove old drawing annotations
        let oldDrawingAnnotations = mapView.annotations.filter { context.coordinator.isDrawingAnnotation($0) }
        mapView.removeAnnotations(oldDrawingAnnotations)

        // Add drawing marker annotations
        for marker in drawingStore.markers {
            let annotation = DrawingMarkerAnnotation(marker: marker)
            mapView.addAnnotation(annotation)
        }

        // Add label annotations for circles
        for circle in drawingStore.circles {
            let annotation = DrawingLabelAnnotation(
                coordinate: circle.center,
                label: circle.label,
                color: circle.color
            )
            mapView.addAnnotation(annotation)
        }

        // Add label annotations for polygons
        for polygon in drawingStore.polygons {
            if let centroid = calculateCentroid(coordinates: polygon.coordinates) {
                let annotation = DrawingLabelAnnotation(
                    coordinate: centroid,
                    label: polygon.label,
                    color: polygon.color
                )
                mapView.addAnnotation(annotation)
            }
        }

        // Add label annotations for lines
        for line in drawingStore.lines {
            if line.coordinates.count >= 2 {
                let midIndex = line.coordinates.count / 2
                let annotation = DrawingLabelAnnotation(
                    coordinate: line.coordinates[midIndex],
                    label: line.label,
                    color: line.color
                )
                mapView.addAnnotation(annotation)
            }
        }

        // Add temporary drawing point annotations
        if drawingManager.isDrawingActive {
            let tempAnnotations = drawingManager.getTemporaryAnnotations()
            mapView.addAnnotations(tempAnnotations)
        }
    }

    private func updateKMLAnnotations(mapView: MKMapView, context: Context) {
        // Remove old KML annotations
        let oldKMLAnnotations = mapView.annotations.filter { $0 is KMLPointAnnotation }
        mapView.removeAnnotations(oldKMLAnnotations)

        // Add visible KML annotations
        let visibleAnnotations = kmlManager.getVisibleAnnotations()
        mapView.addAnnotations(visibleAnnotations)
    }

    private func updateAllOverlays(mapView: MKMapView, context: Context) {
        // Remove all overlays
        mapView.removeOverlays(mapView.overlays)

        // Add saved drawing overlays
        let savedOverlays = drawingStore.getAllOverlays()
        mapView.addOverlays(savedOverlays)

        // Add temporary overlay if drawing
        if let tempOverlay = drawingManager.getTemporaryOverlay() {
            mapView.addOverlay(tempOverlay)
        }

        // Add visible KML overlays
        let kmlOverlays = kmlManager.getVisibleOverlays()
        mapView.addOverlays(kmlOverlays)
    }

    private func calculateCentroid(coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
        guard !coordinates.isEmpty else { return nil }

        var totalLat = 0.0
        var totalLon = 0.0

        for coord in coordinates {
            totalLat += coord.latitude
            totalLon += coord.longitude
        }

        return CLLocationCoordinate2D(
            latitude: totalLat / Double(coordinates.count),
            longitude: totalLon / Double(coordinates.count)
        )
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: KMLTacticalMapView
        var isUserInteracting = false

        init(_ parent: KMLTacticalMapView) {
            self.parent = parent
        }

        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onMapTap(coordinate)
        }

        func isDrawingAnnotation(_ annotation: MKAnnotation) -> Bool {
            return annotation is DrawingMarkerAnnotation ||
                   annotation is DrawingLabelAnnotation ||
                   annotation.title == "Point"
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            isUserInteracting = true
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isUserInteracting = false
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }

            // Handle KML point annotations
            if let kmlAnnotation = annotation as? KMLPointAnnotation {
                return KMLOverlayManager.annotationView(for: kmlAnnotation, in: mapView)
            }

            // Handle drawing marker annotations
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

            // Handle drawing label annotations
            if let labelAnnotation = annotation as? DrawingLabelAnnotation {
                let identifier = "DrawingLabel"

                let label = UILabel()
                label.text = labelAnnotation.label
                label.font = UIFont.systemFont(ofSize: 11, weight: .bold)
                label.textColor = .white
                label.backgroundColor = labelAnnotation.color.uiColor.withAlphaComponent(0.8)
                label.textAlignment = .center
                label.layer.cornerRadius = 4
                label.layer.masksToBounds = true
                label.sizeToFit()
                label.frame = CGRect(
                    x: 0,
                    y: 0,
                    width: label.frame.width + 12,
                    height: label.frame.height + 6
                )

                let renderer = UIGraphicsImageRenderer(size: label.bounds.size)
                let image = renderer.image { ctx in
                    label.layer.render(in: ctx.cgContext)
                }

                let customView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                customView.image = image
                customView.canShowCallout = false
                customView.centerOffset = CGPoint(x: 0, y: 0)

                return customView
            }

            // Handle temporary point annotations
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

            // Handle CoT marker annotations
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

        // MARK: - Overlay Renderers

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // Try KML overlay rendering first
            if let kmlRenderer = KMLOverlayManager.renderer(for: overlay) {
                return kmlRenderer
            }

            // Get color from drawing store
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

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            // Handle KML annotation selection
            if let kmlAnnotation = view.annotation as? KMLPointAnnotation {
                parent.onKMLFeatureTap?(kmlAnnotation.kmlPlacemark)
            }
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            // Handle callout tap for KML annotations
            if let kmlAnnotation = view.annotation as? KMLPointAnnotation {
                parent.onKMLFeatureTap?(kmlAnnotation.kmlPlacemark)
            }
        }
    }
}

// MARK: - KML Feature Detail View

struct KMLFeatureDetailView: View {
    let placemark: KMLPlacemark
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Name
                        Text(placemark.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(Color(hex: "#FFFC00"))

                        // Description
                        if let description = placemark.description, !description.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "#CCCCCC"))

                                Text(description)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(Color(hex: "#2A2A2A"))
                            .cornerRadius(8)
                        }

                        // Geometry info
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Geometry")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#CCCCCC"))

                            Text(geometryDescription)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color(hex: "#2A2A2A"))
                        .cornerRadius(8)

                        // Coordinates
                        coordinatesView
                    }
                    .padding()
                }
            }
            .navigationTitle("Feature Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var geometryDescription: String {
        switch placemark.geometry {
        case .point:
            return "Point"
        case .lineString(let line):
            return "Line (\(line.coordinates.count) points)"
        case .polygon(let poly):
            return "Polygon (\(poly.outerBoundary.count) vertices)"
        case .multiGeometry(let geometries):
            return "Multi-geometry (\(geometries.count) parts)"
        }
    }

    private var coordinatesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coordinates")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(hex: "#CCCCCC"))

            switch placemark.geometry {
            case .point(let point):
                coordinateRow(lat: point.latitude, lon: point.longitude, alt: point.altitude)

            case .lineString(let line):
                ForEach(Array(line.coordinates.prefix(5).enumerated()), id: \.offset) { index, point in
                    coordinateRow(lat: point.latitude, lon: point.longitude, alt: point.altitude, label: "Point \(index + 1)")
                }
                if line.coordinates.count > 5 {
                    Text("... and \(line.coordinates.count - 5) more points")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#999999"))
                }

            case .polygon(let poly):
                ForEach(Array(poly.outerBoundary.prefix(5).enumerated()), id: \.offset) { index, point in
                    coordinateRow(lat: point.latitude, lon: point.longitude, alt: point.altitude, label: "Vertex \(index + 1)")
                }
                if poly.outerBoundary.count > 5 {
                    Text("... and \(poly.outerBoundary.count - 5) more vertices")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#999999"))
                }

            case .multiGeometry:
                Text("Multiple geometries")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(8)
    }

    private func coordinateRow(lat: Double, lon: Double, alt: Double, label: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label = label {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#FFFC00"))
            }
            HStack {
                Text("Lat: \(String(format: "%.6f", lat))")
                Spacer()
                Text("Lon: \(String(format: "%.6f", lon))")
                Spacer()
                Text("Alt: \(String(format: "%.1f", alt))m")
            }
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(.white)
        }
    }
}
