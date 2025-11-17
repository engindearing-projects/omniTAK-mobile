//
//  Map3DViewController.swift
//  OmniTAKMobile
//
//  UIKit controller with MKMapView configured for 3D perspective viewing
//

import UIKit
import MapKit
import CoreLocation
import Combine

// MARK: - Map 3D View Controller

class Map3DViewController: UIViewController {

    // MARK: - Properties

    private var mapView: MKMapView!
    private var terrainService: TerrainVisualizationService
    private var mapStateManager: MapStateManager?
    private var overlayCoordinator: MapOverlayCoordinator?
    private var cancellables = Set<AnyCancellable>()

    // Gesture recognizers
    private var tiltGesture: UIPanGestureRecognizer!
    private var rotationGesture: UIRotationGestureRecognizer!
    private var pinchGesture: UIPinchGestureRecognizer!

    // UI Components
    private var controlsContainerView: UIView!
    private var pitchLabel: UILabel!
    private var headingLabel: UILabel!
    private var distanceLabel: UILabel!
    private var elevationLabel: UILabel!
    private var modeIndicatorView: UIView!
    private var modeLabel: UILabel!

    // Constraints for responsive layout
    private var portraitConstraints: [NSLayoutConstraint] = []
    private var landscapeConstraints: [NSLayoutConstraint] = []

    // Initial camera state
    private var initialRegion: MKCoordinateRegion
    private var initialPitch: CGFloat
    private var initialHeading: CLLocationDirection

    // Marker storage
    private var annotations: [MKAnnotation] = []

    // MARK: - Initialization

    init(terrainService: TerrainVisualizationService,
         region: MKCoordinateRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
         ),
         pitch: CGFloat = 0,
         heading: CLLocationDirection = 0) {
        self.terrainService = terrainService
        self.initialRegion = region
        self.initialPitch = pitch
        self.initialHeading = heading
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.terrainService = TerrainVisualizationService()
        self.initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        self.initialPitch = 0
        self.initialHeading = 0
        super.init(coder: coder)
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupMapView()
        setupGestureRecognizers()
        setupUI()
        setupConstraints()
        configureTerrainService()
        setupObservers()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateLayout()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate { _ in
            self.updateLayout()
        }
    }

    // MARK: - Setup

    private func setupMapView() {
        mapView = MKMapView()
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.mapType = .satelliteFlyover
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true

        // Configure for iOS 15+ 3D features
        if #available(iOS 16.0, *) {
            let configuration = MKStandardMapConfiguration(elevationStyle: .realistic)
            configuration.emphasisStyle = .default
            mapView.preferredConfiguration = configuration
        }

        // Set initial region and camera
        mapView.setRegion(initialRegion, animated: false)

        let camera = MKMapCamera()
        camera.centerCoordinate = initialRegion.center
        camera.centerCoordinateDistance = calculateDistanceFromSpan(initialRegion.span)
        camera.pitch = initialPitch
        camera.heading = initialHeading
        mapView.setCamera(camera, animated: false)

        view.addSubview(mapView)

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupGestureRecognizers() {
        // Two-finger vertical pan for pitch adjustment
        tiltGesture = UIPanGestureRecognizer(target: self, action: #selector(handleTiltGesture(_:)))
        tiltGesture.minimumNumberOfTouches = 2
        tiltGesture.maximumNumberOfTouches = 2
        tiltGesture.delegate = self
        mapView.addGestureRecognizer(tiltGesture)

        // Two-finger rotation for heading adjustment
        rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotationGesture(_:)))
        rotationGesture.delegate = self
        mapView.addGestureRecognizer(rotationGesture)

        // Pinch for zoom/altitude control
        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        pinchGesture.delegate = self
        mapView.addGestureRecognizer(pinchGesture)
    }

    private func setupUI() {
        // Controls container with military dark theme
        controlsContainerView = UIView()
        controlsContainerView.translatesAutoresizingMaskIntoConstraints = false
        controlsContainerView.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        controlsContainerView.layer.cornerRadius = 10
        controlsContainerView.layer.borderWidth = 1
        controlsContainerView.layer.borderColor = UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 0.8).cgColor
        view.addSubview(controlsContainerView)

        // Mode indicator
        modeIndicatorView = UIView()
        modeIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        modeIndicatorView.backgroundColor = UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 0.9)
        modeIndicatorView.layer.cornerRadius = 4
        controlsContainerView.addSubview(modeIndicatorView)

        modeLabel = createLabel(text: "2D", fontSize: 12, weight: .bold)
        modeIndicatorView.addSubview(modeLabel)

        // Info labels
        pitchLabel = createLabel(text: "PITCH: 0.0°", fontSize: 11)
        headingLabel = createLabel(text: "HEADING: N (0°)", fontSize: 11)
        distanceLabel = createLabel(text: "ALT: 5.00 km", fontSize: 11)
        elevationLabel = createLabel(text: "ELEV: 0 m", fontSize: 11)

        let stackView = UIStackView(arrangedSubviews: [pitchLabel, headingLabel, distanceLabel, elevationLabel])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.alignment = .leading
        controlsContainerView.addSubview(stackView)

        NSLayoutConstraint.activate([
            modeIndicatorView.topAnchor.constraint(equalTo: controlsContainerView.topAnchor, constant: 8),
            modeIndicatorView.leadingAnchor.constraint(equalTo: controlsContainerView.leadingAnchor, constant: 8),
            modeIndicatorView.trailingAnchor.constraint(equalTo: controlsContainerView.trailingAnchor, constant: -8),

            modeLabel.centerXAnchor.constraint(equalTo: modeIndicatorView.centerXAnchor),
            modeLabel.centerYAnchor.constraint(equalTo: modeIndicatorView.centerYAnchor),
            modeLabel.topAnchor.constraint(equalTo: modeIndicatorView.topAnchor, constant: 4),
            modeLabel.bottomAnchor.constraint(equalTo: modeIndicatorView.bottomAnchor, constant: -4),

            stackView.topAnchor.constraint(equalTo: modeIndicatorView.bottomAnchor, constant: 8),
            stackView.leadingAnchor.constraint(equalTo: controlsContainerView.leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: controlsContainerView.trailingAnchor, constant: -8),
            stackView.bottomAnchor.constraint(equalTo: controlsContainerView.bottomAnchor, constant: -8)
        ])
    }

    private func createLabel(text: String, fontSize: CGFloat, weight: UIFont.Weight = .semibold) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: weight)
        label.textColor = UIColor(red: 0.0, green: 1.0, blue: 0.8, alpha: 1.0) // Tactical cyan
        return label
    }

    private func setupConstraints() {
        // Portrait constraints
        portraitConstraints = [
            controlsContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            controlsContainerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            controlsContainerView.widthAnchor.constraint(equalToConstant: 160)
        ]

        // Landscape constraints
        landscapeConstraints = [
            controlsContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            controlsContainerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            controlsContainerView.widthAnchor.constraint(equalToConstant: 180)
        ]
    }

    private func updateLayout() {
        NSLayoutConstraint.deactivate(portraitConstraints)
        NSLayoutConstraint.deactivate(landscapeConstraints)

        let isLandscape = view.bounds.width > view.bounds.height

        if isLandscape {
            NSLayoutConstraint.activate(landscapeConstraints)
        } else {
            NSLayoutConstraint.activate(portraitConstraints)
        }
    }

    private func configureTerrainService() {
        terrainService.configure(with: mapView)
        terrainService.syncCameraState()
    }

    private func setupObservers() {
        // Observe camera state changes
        terrainService.$cameraState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateCameraLabels(state)
            }
            .store(in: &cancellables)

        // Observe mode changes
        terrainService.$currentMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.updateModeIndicator(mode)
            }
            .store(in: &cancellables)

        // Observe terrain elevation
        terrainService.$currentTerrainElevation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] elevation in
                self?.elevationLabel.text = String(format: "ELEV: %.0f m", elevation)
            }
            .store(in: &cancellables)
    }

    // MARK: - Gesture Handlers

    @objc private func handleTiltGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: mapView)

        switch gesture.state {
        case .changed:
            // Vertical pan controls pitch (inverted: pan down = increase pitch)
            let pitchDelta = -translation.y * 0.3
            let newPitch = terrainService.cameraState.pitch + CGFloat(pitchDelta)
            terrainService.setPitch(newPitch)
            gesture.setTranslation(.zero, in: mapView)

        case .ended:
            terrainService.savePreferences()

        default:
            break
        }
    }

    @objc private func handleRotationGesture(_ gesture: UIRotationGestureRecognizer) {
        switch gesture.state {
        case .changed:
            let headingDelta = gesture.rotation * 180 / .pi
            terrainService.rotateCamera(by: -headingDelta)
            gesture.rotation = 0

        case .ended:
            terrainService.savePreferences()

        default:
            break
        }
    }

    @objc private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .changed:
            let scale = gesture.scale
            let newDistance = terrainService.cameraState.distance / Double(scale)
            terrainService.setDistance(newDistance)
            gesture.scale = 1.0

        case .ended:
            terrainService.savePreferences()

        default:
            break
        }
    }

    // MARK: - UI Updates

    private func updateCameraLabels(_ state: CameraState) {
        pitchLabel.text = "PITCH: \(TerrainVisualizationService.formatPitch(state.pitch))"
        headingLabel.text = "HDG: \(TerrainVisualizationService.formatHeading(state.heading))"
        distanceLabel.text = "ALT: \(TerrainVisualizationService.formatDistance(state.distance))"
    }

    private func updateModeIndicator(_ mode: Map3DViewMode) {
        modeLabel.text = mode.rawValue

        switch mode {
        case .standard2D:
            modeIndicatorView.backgroundColor = UIColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 0.9)
        case .perspective3D:
            modeIndicatorView.backgroundColor = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.9)
        case .flyover:
            modeIndicatorView.backgroundColor = UIColor(red: 0.8, green: 0.4, blue: 0.2, alpha: 0.9)
        }
    }

    // MARK: - Public Methods

    func setMapStateManager(_ manager: MapStateManager) {
        self.mapStateManager = manager

        // Sync initial state
        manager.$mapRegion
            .sink { [weak self] region in
                self?.mapView.setRegion(region, animated: true)
            }
            .store(in: &cancellables)
    }

    func setOverlayCoordinator(_ coordinator: MapOverlayCoordinator) {
        self.overlayCoordinator = coordinator
        coordinator.configure(with: mapView)
    }

    func addAnnotation(_ annotation: MKAnnotation) {
        annotations.append(annotation)
        mapView.addAnnotation(annotation)
    }

    func addAnnotations(_ newAnnotations: [MKAnnotation]) {
        annotations.append(contentsOf: newAnnotations)
        mapView.addAnnotations(newAnnotations)
    }

    func removeAllAnnotations() {
        mapView.removeAnnotations(annotations)
        annotations.removeAll()
    }

    func setMapType(_ mapType: MKMapType) {
        mapView.mapType = mapType
    }

    func centerOnCoordinate(_ coordinate: CLLocationCoordinate2D, animated: Bool = true) {
        terrainService.setCenter(coordinate)
    }

    func lookAtCoordinate(_ coordinate: CLLocationCoordinate2D, fromDistance: CLLocationDistance? = nil) {
        terrainService.lookAt(coordinate: coordinate, fromDistance: fromDistance)
    }

    func toggle3DMode() {
        if terrainService.currentMode == .standard2D {
            terrainService.transitionTo3D()
        } else {
            terrainService.transitionTo2D()
        }
    }

    func startFlyoverAlongRoute(_ coordinates: [CLLocationCoordinate2D], altitude: CLLocationDistance = 1000) {
        terrainService.startFlyover(along: coordinates, altitude: altitude)
    }

    func stopFlyover() {
        terrainService.stopFlyover()
    }

    // MARK: - Helper Methods

    private func calculateDistanceFromSpan(_ span: MKCoordinateSpan) -> CLLocationDistance {
        // Approximate conversion from span to altitude
        let latDelta = span.latitudeDelta
        let metersPerDegree: CLLocationDistance = 111000
        return latDelta * metersPerDegree * 0.5
    }
}

// MARK: - MKMapViewDelegate

extension Map3DViewController: MKMapViewDelegate {

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        terrainService.syncCameraState()
        terrainService.updateTerrainElevation()

        if let mapStateManager = mapStateManager {
            mapStateManager.updateMapRegion(mapView.region)
        }

        if let overlayCoordinator = overlayCoordinator {
            overlayCoordinator.updateVisibleOverlays(in: mapView.region)
        }
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }

        let identifier = "Marker3D"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = true
            annotationView?.displayPriority = .required

            // Elevation-aware rendering: markers will automatically appear at correct altitude
            // when using 3D map configuration
        } else {
            annotationView?.annotation = annotation
        }

        return annotationView
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let coordinator = overlayCoordinator,
           let renderer = coordinator.renderer(for: overlay) {
            return renderer
        }

        // Default renderers
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .systemBlue
            renderer.lineWidth = 3.0
            return renderer
        }

        if let polygon = overlay as? MKPolygon {
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.strokeColor = .systemBlue
            renderer.fillColor = .systemBlue.withAlphaComponent(0.2)
            renderer.lineWidth = 2.0
            return renderer
        }

        if let circle = overlay as? MKCircle {
            let renderer = MKCircleRenderer(circle: circle)
            renderer.strokeColor = .systemOrange
            renderer.fillColor = .systemOrange.withAlphaComponent(0.1)
            renderer.lineWidth = 2.0
            return renderer
        }

        return MKOverlayRenderer(overlay: overlay)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension Map3DViewController: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow rotation and pinch to work together
        if (gestureRecognizer == rotationGesture && otherGestureRecognizer == pinchGesture) ||
           (gestureRecognizer == pinchGesture && otherGestureRecognizer == rotationGesture) {
            return true
        }
        return false
    }
}

// MARK: - SwiftUI Representable Wrapper

import SwiftUI

struct Map3DViewControllerRepresentable: UIViewControllerRepresentable {
    @ObservedObject var terrainService: TerrainVisualizationService
    @Binding var region: MKCoordinateRegion
    var mapStateManager: MapStateManager?
    var overlayCoordinator: MapOverlayCoordinator?
    var annotations: [MKAnnotation]
    var mapType: MKMapType
    var onMapTap: ((CLLocationCoordinate2D, CGPoint) -> Void)?

    func makeUIViewController(context: Context) -> Map3DViewController {
        let controller = Map3DViewController(
            terrainService: terrainService,
            region: region,
            pitch: terrainService.cameraState.pitch,
            heading: terrainService.cameraState.heading
        )

        if let manager = mapStateManager {
            controller.setMapStateManager(manager)
        }

        if let coordinator = overlayCoordinator {
            controller.setOverlayCoordinator(coordinator)
        }

        controller.setMapType(mapType)
        controller.addAnnotations(annotations)

        return controller
    }

    func updateUIViewController(_ uiViewController: Map3DViewController, context: Context) {
        uiViewController.setMapType(mapType)

        // Update annotations if needed
        uiViewController.removeAllAnnotations()
        uiViewController.addAnnotations(annotations)
    }
}

// MARK: - 3D Annotation for Elevation-Aware Markers

class ElevationAwareAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    var elevation: CLLocationDistance
    var markerType: String

    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?, elevation: CLLocationDistance, markerType: String = "default") {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.elevation = elevation
        self.markerType = markerType
        super.init()
    }
}
