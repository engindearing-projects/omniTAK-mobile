//
//  MeasurementService.swift
//  OmniTAKMobile
//
//  Service layer for coordinating measurement tools with map view
//

import Foundation
import MapKit
import CoreLocation
import Combine
import SwiftUI

// MARK: - Measurement Service

class MeasurementService: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var manager: MeasurementManager
    @Published var overlays: [MKOverlay] = []
    @Published var annotations: [MKPointAnnotation] = []

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    override init() {
        self.manager = MeasurementManager()
        super.init()
        setupBindings()
    }

    private func setupBindings() {
        // Update overlays when manager state changes
        manager.$savedMeasurements
            .combineLatest(manager.$rangeRings, manager.$temporaryPoints)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _ in
                self?.updateOverlays()
            }
            .store(in: &cancellables)

        // Update annotations for temporary points
        manager.$temporaryPoints
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateAnnotations()
            }
            .store(in: &cancellables)
    }

    // MARK: - Overlay Management

    func updateOverlays() {
        var newOverlays: [MKOverlay] = []

        // Add saved measurement overlays
        for measurement in manager.savedMeasurements {
            if let overlay = MeasurementOverlayFactory.createOverlayForMeasurement(measurement) {
                newOverlays.append(overlay)
            }
        }

        // Add range ring overlays
        let ringOverlays = MeasurementOverlayFactory.createRangeRingOverlays(manager.rangeRings)
        newOverlays.append(contentsOf: ringOverlays)

        // Add temporary overlay if measuring
        if let temporaryOverlay = manager.getTemporaryOverlay() {
            newOverlays.append(temporaryOverlay)
        }

        overlays = newOverlays
    }

    func updateAnnotations() {
        annotations = manager.getTemporaryAnnotations()
    }

    // MARK: - Map Interaction

    func handleMapTap(at coordinate: CLLocationCoordinate2D) {
        manager.handleMapTap(at: coordinate)
        updateOverlays()
    }

    // MARK: - Renderer Provider

    func renderer(for overlay: MKOverlay) -> MKOverlayRenderer {
        return MeasurementOverlayFactory.rendererForOverlay(overlay)
    }

    // MARK: - Export/Import

    func exportMeasurements() -> Data? {
        let exportData = MeasurementExportData(
            measurements: manager.savedMeasurements,
            rangeRings: manager.rangeRings,
            configuration: manager.rangeRingConfiguration
        )

        return try? JSONEncoder().encode(exportData)
    }

    func importMeasurements(from data: Data) -> Bool {
        guard let exportData = try? JSONDecoder().decode(MeasurementExportData.self, from: data) else {
            return false
        }

        manager.savedMeasurements = exportData.measurements
        manager.rangeRings = exportData.rangeRings
        manager.rangeRingConfiguration = exportData.configuration

        updateOverlays()
        return true
    }

    // MARK: - Convenience Methods

    func startDistanceMeasurement() {
        manager.startMeasurement(type: .distance)
    }

    func startBearingMeasurement() {
        manager.startMeasurement(type: .bearing)
    }

    func startAreaMeasurement() {
        manager.startMeasurement(type: .area)
    }

    func startRangeRingPlacement() {
        manager.startMeasurement(type: .rangeRing)
    }

    func completeMeasurement() {
        manager.completeMeasurement()
        updateOverlays()
    }

    func cancelMeasurement() {
        manager.cancelMeasurement()
        updateOverlays()
    }

    func clearAll() {
        manager.clearAllMeasurements()
        manager.clearAllRangeRings()
        updateOverlays()
    }

    // MARK: - Quick Measurement Methods

    /// Quick distance measurement between two points
    func quickDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        return MeasurementCalculator.distance(from: from, to: to)
    }

    /// Quick bearing calculation
    func quickBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        return MeasurementCalculator.bearing(from: from, to: to)
    }

    /// Quick area calculation for polygon
    func quickArea(coordinates: [CLLocationCoordinate2D]) -> Double {
        return MeasurementCalculator.polygonArea(coordinates: coordinates)
    }

    // MARK: - Range Ring Helpers

    func addQuickRangeRing(at center: CLLocationCoordinate2D, radius: Double) {
        let ring = RangeRing(center: center, radiusMeters: radius)
        manager.rangeRings.append(ring)
        updateOverlays()
    }

    func addConcentricRings(at center: CLLocationCoordinate2D, distances: [Double]) {
        for distance in distances {
            let ring = RangeRing(center: center, radiusMeters: distance)
            manager.rangeRings.append(ring)
        }
        updateOverlays()
    }

    // MARK: - Coordinate String Conversion

    func coordinateString(for coordinate: CLLocationCoordinate2D, format: MeasurementCoordinateFormat = .decimalDegrees) -> String {
        switch format {
        case .decimalDegrees:
            return coordinate.formatDecimalDegrees()
        case .degreesMinutesSeconds:
            return coordinate.formatDMS()
        case .mgrs:
            return coordinate.formatMGRS()
        }
    }
}

// MARK: - Supporting Types

struct MeasurementExportData: Codable {
    let measurements: [Measurement]
    let rangeRings: [RangeRing]
    let configuration: RangeRingConfiguration
}

enum MeasurementCoordinateFormat: String, CaseIterable {
    case decimalDegrees = "DD"
    case degreesMinutesSeconds = "DMS"
    case mgrs = "MGRS"
}

// MARK: - Map View Delegate Extension Helper

extension MeasurementService: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        return renderer(for: overlay)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }

        if let pointAnnotation = annotation as? MKPointAnnotation {
            let identifier = "MeasurementPoint"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if view == nil {
                view = MKMarkerAnnotationView(annotation: pointAnnotation, reuseIdentifier: identifier)
                (view as? MKMarkerAnnotationView)?.markerTintColor = UIColor(red: 1.0, green: 0.988, blue: 0.0, alpha: 1.0)
                (view as? MKMarkerAnnotationView)?.glyphImage = UIImage(systemName: "circle.fill")
                view?.canShowCallout = true
            } else {
                view?.annotation = pointAnnotation
            }

            return view
        }

        return nil
    }
}

// MARK: - Measurement Gesture Recognizer

class MeasurementTapGestureRecognizer: UITapGestureRecognizer {
    var measurementService: MeasurementService?
    weak var mapView: MKMapView?

    @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let service = measurementService,
              let map = mapView,
              service.manager.isActive else { return }

        let location = recognizer.location(in: map)
        let coordinate = map.convert(location, toCoordinateFrom: map)

        service.handleMapTap(at: coordinate)
    }
}

// MARK: - Measurement Annotation

class MeasurementPointAnnotation: MKPointAnnotation {
    var pointIndex: Int = 0
    var measurementID: UUID?
    var measurementType: MeasurementType?
}

// MARK: - Integration Helper

class MeasurementMapIntegration {
    weak var mapView: MKMapView?
    let service: MeasurementService
    private var cancellables = Set<AnyCancellable>()
    private var tapGesture: MeasurementTapGestureRecognizer?

    init(mapView: MKMapView, service: MeasurementService) {
        self.mapView = mapView
        self.service = service
        setupGestureRecognizer()
        setupOverlayBinding()
    }

    private func setupGestureRecognizer() {
        guard let map = mapView else { return }

        let tap = MeasurementTapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
        tap.measurementService = service
        tap.mapView = map
        tap.numberOfTapsRequired = 1
        tap.numberOfTouchesRequired = 1

        // Add gesture but don't cancel other gestures
        tap.cancelsTouchesInView = false
        tap.delaysTouchesBegan = false
        tap.delaysTouchesEnded = false

        map.addGestureRecognizer(tap)
        tapGesture = tap
    }

    @objc private func handleMapTap(_ recognizer: UITapGestureRecognizer) {
        guard service.manager.isActive,
              let map = mapView else { return }

        let location = recognizer.location(in: map)
        let coordinate = map.convert(location, toCoordinateFrom: map)

        service.handleMapTap(at: coordinate)
    }

    private func setupOverlayBinding() {
        // Observe overlay changes
        service.$overlays
            .receive(on: RunLoop.main)
            .sink { [weak self] newOverlays in
                self?.updateMapOverlays(newOverlays)
            }
            .store(in: &cancellables)

        // Observe annotation changes
        service.$annotations
            .receive(on: RunLoop.main)
            .sink { [weak self] newAnnotations in
                self?.updateMapAnnotations(newAnnotations)
            }
            .store(in: &cancellables)
    }

    private func updateMapOverlays(_ newOverlays: [MKOverlay]) {
        guard let map = mapView else { return }

        // Remove existing measurement overlays
        let existingMeasurementOverlays = map.overlays.filter { overlay in
            overlay is MeasurementPolyline ||
            overlay is MeasurementPolygon ||
            overlay is RangeRingOverlay ||
            overlay is BearingArrowOverlay
        }
        map.removeOverlays(existingMeasurementOverlays)

        // Add new overlays
        map.addOverlays(newOverlays)
    }

    private func updateMapAnnotations(_ newAnnotations: [MKPointAnnotation]) {
        guard let map = mapView else { return }

        // Remove existing measurement point annotations
        let existingAnnotations = map.annotations.filter { annotation in
            (annotation as? MKPointAnnotation)?.title?.contains("Point") == true ||
            (annotation as? MKPointAnnotation)?.title?.contains("Vertex") == true ||
            (annotation as? MKPointAnnotation)?.title == "Start" ||
            (annotation as? MKPointAnnotation)?.title == "End"
        }
        map.removeAnnotations(existingAnnotations)

        // Add new annotations
        map.addAnnotations(newAnnotations)
    }

    func cleanup() {
        if let gesture = tapGesture {
            mapView?.removeGestureRecognizer(gesture)
        }
        cancellables.removeAll()
    }
}

// MARK: - Usage Example View

struct MeasurementIntegrationExample: View {
    @StateObject private var measurementService = MeasurementService()
    @State private var showMeasurementPanel = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Map would go here
            Color.gray.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                // Measurement button
                MeasurementButton(
                    manager: measurementService.manager,
                    showMeasurementPanel: $showMeasurementPanel
                )

                // Other map controls would go here
            }
            .padding(.trailing, 16)
            .padding(.top, 100)

            // Measurement status bar
            VStack {
                Spacer()

                MeasurementStatusBar(manager: measurementService.manager)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
            }

            // Measurement panel
            if showMeasurementPanel {
                VStack {
                    Spacer()

                    FloatingMeasurementPanel(
                        manager: measurementService.manager,
                        isPresented: $showMeasurementPanel
                    )
                    .padding(16)
                }
            }
        }
    }
}
