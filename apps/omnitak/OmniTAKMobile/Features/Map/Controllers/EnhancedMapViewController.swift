//
//  EnhancedMapViewController.swift
//  OmniTAKTest
//
//  Enhanced MapKit-based map with custom markers, info panels, and trails
//

import UIKit
import MapKit
import CoreLocation
import Combine

class EnhancedMapViewController: UIViewController {

    // MARK: - Properties

    private let mapView = MKMapView()
    private let takService: TAKService
    private let locationManager = CLLocationManager()
    private let trailManager = TrailManager()

    private var selectedMarker: EnhancedCoTMarker?
    private var infoPanelView: UIView?
    private var cancellables = Set<AnyCancellable>()

    // Marker tracking
    private var annotationsByUID: [String: CustomAnnotation] = [:]

    // Configuration
    private var showTrails = true
    private var trailConfig = TrailConfiguration()

    // MARK: - Initialization

    init(takService: TAKService) {
        self.takService = takService
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupMapView()
        setupLocationManager()
        setupTAKServiceObservers()
        setupTapGesture()
    }

    // MARK: - Setup

    private func setupMapView() {
        view.addSubview(mapView)
        mapView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.mapType = .satellite

        // Set initial region
        let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        mapView.setRegion(initialRegion, animated: false)
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    private func setupTAKServiceObservers() {
        // Observe enhanced markers
        takService.$enhancedMarkers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] markers in
                self?.updateMarkers(markers)
            }
            .store(in: &cancellables)

        // Observe individual marker updates for trails
        takService.onMarkerUpdated = { [weak self] marker in
            DispatchQueue.main.async {
                self?.updateTrail(for: marker)
            }
        }
    }

    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
        tapGesture.delegate = self
        mapView.addGestureRecognizer(tapGesture)
    }

    // MARK: - Marker Management

    private func updateMarkers(_ markers: [String: EnhancedCoTMarker]) {
        // Remove annotations for markers that no longer exist
        let currentUIDs = Set(markers.keys)
        let annotationUIDs = Set(annotationsByUID.keys)

        for uid in annotationUIDs.subtracting(currentUIDs) {
            if let annotation = annotationsByUID[uid] {
                mapView.removeAnnotation(annotation)
                annotationsByUID.removeValue(forKey: uid)
            }
        }

        // Update or add markers
        for (uid, marker) in markers {
            if let existingAnnotation = annotationsByUID[uid] {
                // Update existing annotation
                existingAnnotation.marker = marker
                existingAnnotation.coordinate = marker.coordinate

                // Update the view if visible
                if let annotationView = mapView.view(for: existingAnnotation) as? CustomMarkerAnnotation {
                    annotationView.marker = marker
                }
            } else {
                // Create new annotation
                let annotation = CustomAnnotation(marker: marker)
                annotationsByUID[uid] = annotation
                mapView.addAnnotation(annotation)
            }
        }
    }

    private func updateTrail(for marker: EnhancedCoTMarker) {
        guard showTrails else { return }

        // Update trail in trail manager
        trailManager.updateTrail(for: marker)

        // Remove old trail overlay
        let oldOverlays = mapView.overlays.filter { overlay in
            if let polyline = overlay as? MKPolyline,
               let title = polyline.title,
               title == marker.uid {
                return true
            }
            return false
        }
        mapView.removeOverlays(oldOverlays)

        // Add new trail overlay
        if let trail = trailManager.trails[marker.uid] {
            // Tag the polyline with the UID
            let polyline = trail.polyline
            polyline.title = marker.uid
            mapView.addOverlay(polyline)
        }
    }

    // MARK: - User Interaction

    @objc private func handleMapTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: mapView)
        let coordinate = mapView.convert(location, toCoordinateFrom: mapView)

        // Check if tapped near any annotation
        let point = mapView.convert(coordinate, toPointTo: mapView)

        for annotation in mapView.annotations {
            guard let customAnnotation = annotation as? CustomAnnotation else { continue }

            let annotationPoint = mapView.convert(annotation.coordinate, toPointTo: mapView)
            let distance = hypot(point.x - annotationPoint.x, point.y - annotationPoint.y)

            // If tapped within 44 points (standard tap target size)
            if distance < 44 {
                handleMarkerTap(customAnnotation.marker)
                return
            }
        }

        // Tapped empty space - dismiss info panel
        dismissInfoPanel()
    }

    private func handleMarkerTap(_ marker: EnhancedCoTMarker) {
        selectedMarker = marker
        showInfoPanel(for: marker)

        // Provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    // MARK: - Info Panel

    private func showInfoPanel(for marker: EnhancedCoTMarker) {
        // Remove existing panel
        dismissInfoPanel()

        // Create SwiftUI view
        let infoPanelSwiftUI = MarkerInfoPanel(
            marker: marker,
            userLocation: locationManager.location,
            onCenter: { [weak self] in
                self?.centerOnMarker(marker)
            },
            onMessage: { [weak self] in
                self?.messageMarker(marker)
            },
            onTrack: { [weak self] in
                self?.trackMarker(marker)
            },
            onDismiss: { [weak self] in
                self?.dismissInfoPanel()
            }
        )

        // Wrap in UIHostingController
        let hostingController = UIHostingController(rootView: infoPanelSwiftUI)
        addChild(hostingController)

        let panelView = hostingController.view!
        panelView.translatesAutoresizingMaskIntoConstraints = false
        panelView.backgroundColor = .clear
        view.addSubview(panelView)

        NSLayoutConstraint.activate([
            panelView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panelView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panelView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            panelView.heightAnchor.constraint(equalToConstant: 150) // Initial collapsed height
        ])

        hostingController.didMove(toParent: self)
        infoPanelView = panelView

        // Animate in
        panelView.transform = CGAffineTransform(translationX: 0, y: 200)
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            panelView.transform = .identity
        }
    }

    private func dismissInfoPanel() {
        guard let panelView = infoPanelView else { return }

        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn, animations: {
            panelView.transform = CGAffineTransform(translationX: 0, y: 200)
        }) { _ in
            // Remove hosting controller
            self.children.forEach { child in
                if child.view == panelView {
                    child.willMove(toParent: nil)
                    child.view.removeFromSuperview()
                    child.removeFromParent()
                }
            }
            self.infoPanelView = nil
        }

        selectedMarker = nil
    }

    // MARK: - Actions

    private func centerOnMarker(_ marker: EnhancedCoTMarker) {
        let region = MKCoordinateRegion(
            center: marker.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        mapView.setRegion(region, animated: true)
    }

    private func messageMarker(_ marker: EnhancedCoTMarker) {
        // TODO: Implement messaging functionality
        print("Message to: \(marker.callsign)")

        let alert = UIAlertController(
            title: "Message",
            message: "Messaging \(marker.callsign)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func trackMarker(_ marker: EnhancedCoTMarker) {
        // TODO: Implement tracking functionality
        print("Track: \(marker.callsign)")

        // For now, just center and highlight the trail
        centerOnMarker(marker)
        showTrails = true
        updateTrail(for: marker)
    }

    // MARK: - Public Methods

    func centerOnUser() {
        if let location = locationManager.location {
            let region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            mapView.setRegion(region, animated: true)
        }
    }

    func toggleMapType() {
        switch mapView.mapType {
        case .standard:
            mapView.mapType = .satellite
        case .satellite:
            mapView.mapType = .hybrid
        case .hybrid:
            mapView.mapType = .standard
        default:
            mapView.mapType = .satellite
        }
    }

    func toggleTrails() {
        showTrails.toggle()

        if showTrails {
            // Re-add all trails
            for marker in takService.enhancedMarkers.values {
                updateTrail(for: marker)
            }
        } else {
            // Remove all trail overlays
            mapView.removeOverlays(mapView.overlays)
        }
    }

    func zoomIn() {
        var region = mapView.region
        region.span.latitudeDelta = max(region.span.latitudeDelta / 2, 0.001)
        region.span.longitudeDelta = max(region.span.longitudeDelta / 2, 0.001)
        mapView.setRegion(region, animated: true)
    }

    func zoomOut() {
        var region = mapView.region
        region.span.latitudeDelta = min(region.span.latitudeDelta * 2, 180)
        region.span.longitudeDelta = min(region.span.longitudeDelta * 2, 180)
        mapView.setRegion(region, animated: true)
    }
}

// MARK: - MKMapViewDelegate

extension EnhancedMapViewController: MKMapViewDelegate {

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // Don't customize user location
        if annotation is MKUserLocation {
            return nil
        }

        guard let customAnnotation = annotation as? CustomAnnotation else {
            return nil
        }

        let identifier = "CustomMarker"
        var annotationView = mapView.dequeueReusableAnnotationView(
            withIdentifier: identifier
        ) as? CustomMarkerAnnotation

        if annotationView == nil {
            annotationView = CustomMarkerAnnotation(
                annotation: customAnnotation,
                reuseIdentifier: identifier
            )
        } else {
            annotationView?.annotation = customAnnotation
        }

        annotationView?.marker = customAnnotation.marker
        return annotationView
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polyline = overlay as? MKPolyline else {
            return MKOverlayRenderer(overlay: overlay)
        }

        // Find the trail for this polyline
        var trail: UnitTrailOverlay?
        if let uid = polyline.title {
            trail = trailManager.trails[uid]
        }

        let renderer = UnitTrailRenderer(polyline: polyline)
        renderer.trailColor = trail?.trailColor ?? UIColor.cyan
        renderer.trailWidth = trailConfig.trailWidth
        renderer.showDirectionArrows = trailConfig.showDirectionArrows

        return renderer
    }
}

// MARK: - CLLocationManagerDelegate

extension EnhancedMapViewController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Location updates handled automatically
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension EnhancedMapViewController: UIGestureRecognizerDelegate {

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }
}

// MARK: - Custom Annotation

class CustomAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var marker: EnhancedCoTMarker

    init(marker: EnhancedCoTMarker) {
        self.marker = marker
        self.coordinate = marker.coordinate
        super.init()
    }
}
