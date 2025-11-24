//
//  RadialMenuMapOverlay.swift
//  OmniTAKMobile
//
//  SwiftUI overlay that integrates radial menu with map view
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Radial Menu Map Overlay

/// SwiftUI overlay that adds radial menu functionality to a map view
struct RadialMenuMapOverlay: View {
    @ObservedObject var coordinator: RadialMenuMapCoordinator
    let mapView: MKMapView

    @State private var longPressLocation: CGPoint = .zero
    @State private var isLongPressing: Bool = false

    var body: some View {
        ZStack {
            // Long press gesture detection layer
            if coordinator.isRadialMenuEnabled {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(longPressGesture)
                    .allowsHitTesting(!coordinator.showRadialMenu)
            }

            // Radial menu when visible
            if coordinator.showRadialMenu {
                RadialMenuView(
                    isPresented: $coordinator.showRadialMenu,
                    centerPoint: coordinator.menuCenterPoint,
                    configuration: coordinator.menuConfiguration,
                    onSelect: { action in
                        coordinator.executeAction(action)
                    },
                    onEvent: { event in
                        handleMenuEvent(event)
                    }
                )
                .zIndex(9999)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Gestures

    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .simultaneously(with: DragGesture(minimumDistance: 0))
            .onEnded { value in
                guard let dragValue = value.second else { return }
                handleLongPress(at: dragValue.location)
            }
    }

    // MARK: - Handlers

    private func handleLongPress(at location: CGPoint) {
        guard coordinator.isRadialMenuEnabled else { return }

        // Ensure we're using the map view's coordinate system
        let mapLocation = location

        // Invoke the coordinator to handle the long press
        coordinator.handleLongPress(at: mapLocation, on: mapView)
    }

    private func handleMenuEvent(_ event: RadialMenuEvent) {
        switch event {
        case .opened(let point):
            print("Radial menu opened at: \(point)")

        case .itemHighlighted(let index):
            coordinator.highlightItem(at: index)

        case .itemSelected(let action):
            print("Selected action: \(action.identifier)")

        case .dismissed:
            coordinator.dismissMenu()
        }
    }
}

// MARK: - Radial Menu Map Integration View

/// Complete view that wraps a map with radial menu integration
struct RadialMenuMapIntegrationView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var mapType: MKMapType
    @ObservedObject var coordinator: RadialMenuMapCoordinator

    let markers: [CoTMarker]
    let showsUserLocation: Bool

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.mapType = mapType
        mapView.region = region

        // Add long press gesture recognizer
        let longPressGesture = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(MapCoordinatorDelegate.handleLongPressGesture(_:))
        )
        longPressGesture.minimumPressDuration = 0.5
        longPressGesture.allowableMovement = 10
        mapView.addGestureRecognizer(longPressGesture)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.mapView = mapView
        context.coordinator.radialMenuCoordinator = coordinator

        if mapView.mapType != mapType {
            mapView.mapType = mapType
        }

        if !context.coordinator.isUserInteracting {
            mapView.setRegion(region, animated: true)
        }

        updateAnnotations(mapView: mapView, context: context)
    }

    func makeCoordinator() -> MapCoordinatorDelegate {
        MapCoordinatorDelegate(self)
    }

    private func updateAnnotations(mapView: MKMapView, context: Context) {
        let oldAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(oldAnnotations)

        let annotations = markers.map { marker -> MKPointAnnotation in
            let annotation = MKPointAnnotation()
            annotation.coordinate = marker.coordinate
            annotation.title = marker.callsign
            annotation.subtitle = marker.type
            return annotation
        }
        mapView.addAnnotations(annotations)
    }

    // MARK: - Coordinator Delegate

    class MapCoordinatorDelegate: NSObject, MKMapViewDelegate {
        var parent: RadialMenuMapIntegrationView
        var mapView: MKMapView?
        var radialMenuCoordinator: RadialMenuMapCoordinator?
        var isUserInteracting = false

        init(_ parent: RadialMenuMapIntegrationView) {
            self.parent = parent
        }

        @objc func handleLongPressGesture(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let mapView = mapView,
                  let radialCoordinator = radialMenuCoordinator else {
                return
            }

            let point = gesture.location(in: mapView)
            radialCoordinator.handleLongPress(at: point, on: mapView)
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

            let identifier = "RadialMenuMarker"
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
                color = .systemCyan
            } else if type?.contains("a-h") == true {
                color = .systemRed
            } else {
                color = .systemYellow
            }

            let size = CGSize(width: 30, height: 30)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { _ in
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
    }
}

// MARK: - Radial Menu Enabled Map Wrapper

/// Complete SwiftUI view that wraps a map with full radial menu support
struct RadialMenuEnabledMap: View {
    @StateObject private var coordinator = RadialMenuMapCoordinator()
    @State private var mapView: MKMapView? = nil

    @Binding var region: MKCoordinateRegion
    @Binding var mapType: MKMapType
    let markers: [CoTMarker]
    let showsUserLocation: Bool

    // Services
    var pointDropperService: PointDropperService?
    var measurementManager: MeasurementManager?
    var navigationService: NavigationService?
    var waypointManager: WaypointManager?

    var body: some View {
        ZStack {
            // Map View with UIViewRepresentable
            MapViewWithRadialMenuSupport(
                region: $region,
                mapType: $mapType,
                markers: markers,
                showsUserLocation: showsUserLocation,
                onMapViewCreated: { view in
                    self.mapView = view
                    configureCoordinator()
                },
                coordinator: coordinator
            )
            .ignoresSafeArea()

            // Radial Menu Overlay
            if let mapView = mapView {
                RadialMenuMapOverlay(
                    coordinator: coordinator,
                    mapView: mapView
                )
            }
        }
        .onAppear {
            configureCoordinator()
        }
    }

    private func configureCoordinator() {
        coordinator.configure(
            pointDropperService: pointDropperService ?? PointDropperService.shared,
            measurementManager: measurementManager,
            navigationService: navigationService ?? NavigationService.shared,
            waypointManager: waypointManager ?? WaypointManager.shared
        )
    }
}

// MARK: - Map View with Radial Menu Support

struct MapViewWithRadialMenuSupport: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var mapType: MKMapType
    let markers: [CoTMarker]
    let showsUserLocation: Bool
    let onMapViewCreated: (MKMapView) -> Void
    @ObservedObject var coordinator: RadialMenuMapCoordinator

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.mapType = mapType
        mapView.region = region

        // Add long press gesture
        let longPressGesture = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPressGesture.minimumPressDuration = 0.5
        longPressGesture.allowableMovement = 10
        mapView.addGestureRecognizer(longPressGesture)

        // Notify parent
        DispatchQueue.main.async {
            onMapViewCreated(mapView)
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.mapView = mapView
        context.coordinator.radialCoordinator = coordinator

        if mapView.mapType != mapType {
            mapView.mapType = mapType
        }

        if !context.coordinator.isUserInteracting {
            mapView.setRegion(region, animated: true)
        }

        updateAnnotations(mapView: mapView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func updateAnnotations(mapView: MKMapView) {
        let oldAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(oldAnnotations)

        let annotations = markers.map { marker -> MKPointAnnotation in
            let annotation = MKPointAnnotation()
            annotation.coordinate = marker.coordinate
            annotation.title = marker.callsign
            annotation.subtitle = marker.type
            return annotation
        }
        mapView.addAnnotations(annotations)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewWithRadialMenuSupport
        var mapView: MKMapView?
        var radialCoordinator: RadialMenuMapCoordinator?
        var isUserInteracting = false

        init(_ parent: MapViewWithRadialMenuSupport) {
            self.parent = parent
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let mapView = mapView,
                  let radialCoordinator = radialCoordinator else {
                return
            }

            let point = gesture.location(in: mapView)
            radialCoordinator.handleLongPress(at: point, on: mapView)
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

            let identifier = "MapMarker"
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
                color = .systemCyan
            } else if type?.contains("a-h") == true {
                color = .systemRed
            } else {
                color = .systemYellow
            }

            let size = CGSize(width: 30, height: 30)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { _ in
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
    }
}
