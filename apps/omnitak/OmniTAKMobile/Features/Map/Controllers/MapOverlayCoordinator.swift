//
//  MapOverlayCoordinator.swift
//  OmniTAKMobile
//
//  Central coordinator for all map overlays
//  Manages MGRS Grid, Breadcrumb Trails, R&B Lines, Track Recordings
//

import Foundation
import MapKit
import SwiftUI
import Combine

// MARK: - Overlay Type

enum MapOverlayType: String, CaseIterable, Identifiable {
    case mgrsGrid = "MGRS Grid"
    case breadcrumbTrails = "Breadcrumb Trails"
    case rangeBearingLines = "R&B Lines"
    case trackRecordings = "Track Recordings"
    case measurementOverlays = "Measurements"
    case kmlOverlays = "KML/KMZ"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .mgrsGrid: return "grid"
        case .breadcrumbTrails: return "point.topleft.down.curvedto.point.bottomright.up"
        case .rangeBearingLines: return "arrow.triangle.swap"
        case .trackRecordings: return "point.3.connected.trianglepath.dotted"
        case .measurementOverlays: return "ruler"
        case .kmlOverlays: return "map"
        }
    }

    // Z-ordering: lower values render below higher values
    var zOrder: Int {
        switch self {
        case .mgrsGrid: return 0
        case .breadcrumbTrails: return 10
        case .rangeBearingLines: return 20
        case .trackRecordings: return 30
        case .measurementOverlays: return 40
        case .kmlOverlays: return 50
        }
    }
}

// MARK: - MGRS Grid Density

enum MGRSGridDensity: String, CaseIterable, Identifiable {
    case none = "None"
    case hundredKm = "100km"
    case tenKm = "10km"
    case oneKm = "1km"

    var id: String { rawValue }

    var spacing: MGRSGridOverlay.GridSpacing? {
        switch self {
        case .none: return nil
        case .hundredKm: return .hundredKilometer
        case .tenKm: return .tenKilometer
        case .oneKm: return .oneKilometer
        }
    }
}

// MARK: - Overlay Configuration

struct OverlayConfiguration {
    var isEnabled: Bool = false
    var opacity: CGFloat = 1.0
    var color: UIColor = .white
    var lineWidth: CGFloat = 1.0
}

// MARK: - Map Overlay Coordinator

class MapOverlayCoordinator: ObservableObject {

    // MARK: - Published Properties

    @Published var overlayVisibility: [MapOverlayType: Bool] = {
        var dict: [MapOverlayType: Bool] = [:]
        for type in MapOverlayType.allCases {
            dict[type] = false
        }
        return dict
    }()
    @Published var overlayConfigurations: [MapOverlayType: OverlayConfiguration] = {
        var dict: [MapOverlayType: OverlayConfiguration] = [:]
        for type in MapOverlayType.allCases {
            dict[type] = OverlayConfiguration()
        }
        return dict
    }()

    // MGRS Grid specific
    @Published var mgrsGridDensity: MGRSGridDensity = .oneKm
    @Published var showMGRSLabels: Bool = true
    @Published var mgrsLineColor: UIColor = UIColor.gray.withAlphaComponent(0.6)
    @Published var mgrsLabelColor: UIColor = UIColor.white.withAlphaComponent(0.9)
    @Published var currentCenterMGRS: String = ""

    // Trail settings
    @Published var trailColor: UIColor = .cyan
    @Published var trailMaxLength: Int = 100
    @Published var trailLineWidth: CGFloat = 3.0

    // R&B Line settings
    @Published var rbLineColor: UIColor = .orange
    @Published var showRBLabels: Bool = true

    // Track Recording settings
    @Published var trackColor: UIColor = .green
    @Published var trackLineWidth: CGFloat = 2.0

    // MARK: - Private Properties

    private weak var mapView: MKMapView?
    private var mgrsOverlay: MGRSGridOverlay?
    private var activeOverlays: [MapOverlayType: [MKOverlay]] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var lastMGRSUpdateTime: Date = .distantPast
    private let mgrsUpdateThrottleInterval: TimeInterval = 0.1 // Update max once per 100ms

    // MARK: - Initialization

    init() {
        setupObservers()
    }

    private func setupObservers() {
        // Observe grid density changes
        $mgrsGridDensity
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateMGRSGrid()
            }
            .store(in: &cancellables)

        // Observe label visibility changes
        $showMGRSLabels
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateMGRSGrid()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    func configure(with mapView: MKMapView) {
        self.mapView = mapView
    }

    func addOverlay(_ type: MapOverlayType) {
        guard let mapView = mapView else { return }

        // Defer @Published property update to avoid "Publishing changes from within view updates"
        DispatchQueue.main.async { [weak self] in
            self?.overlayVisibility[type] = true
            self?.objectWillChange.send()
        }

        switch type {
        case .mgrsGrid:
            enableMGRSGrid(on: mapView)
        case .breadcrumbTrails:
            // Trails are managed by marker updates
            break
        case .rangeBearingLines:
            // R&B lines are added dynamically
            break
        case .trackRecordings:
            // Track recordings are added dynamically
            break
        case .measurementOverlays:
            // Measurements are added dynamically
            break
        case .kmlOverlays:
            // KML overlays are loaded separately
            break
        }
    }

    func removeOverlay(_ type: MapOverlayType) {
        guard let mapView = mapView else { return }

        // Defer @Published property update to avoid "Publishing changes from within view updates"
        DispatchQueue.main.async { [weak self] in
            self?.overlayVisibility[type] = false
            self?.objectWillChange.send()
        }

        switch type {
        case .mgrsGrid:
            disableMGRSGrid(from: mapView)
        case .breadcrumbTrails:
            removeAllOverlays(ofType: type, from: mapView)
        case .rangeBearingLines:
            removeAllOverlays(ofType: type, from: mapView)
        case .trackRecordings:
            removeAllOverlays(ofType: type, from: mapView)
        case .measurementOverlays:
            removeAllOverlays(ofType: type, from: mapView)
        case .kmlOverlays:
            removeAllOverlays(ofType: type, from: mapView)
        }
    }

    func toggleOverlay(_ type: MapOverlayType) {
        if overlayVisibility[type] == true {
            removeOverlay(type)
        } else {
            addOverlay(type)
        }
    }

    func isOverlayVisible(_ type: MapOverlayType) -> Bool {
        return overlayVisibility[type] ?? false
    }

    // MARK: - MGRS Grid Management

    private func enableMGRSGrid(on mapView: MKMapView) {
        guard mgrsGridDensity != .none else { return }

        disableMGRSGrid(from: mapView)

        let overlay = MGRSGridOverlay()
        overlay.showLabels = showMGRSLabels
        overlay.lineColor = mgrsLineColor
        overlay.labelColor = mgrsLabelColor

        if let spacing = mgrsGridDensity.spacing {
            overlay.gridSpacing = spacing
        }

        mgrsOverlay = overlay
        mapView.addOverlay(overlay, level: .aboveLabels)

        updateCenterMGRS()
    }

    private func disableMGRSGrid(from mapView: MKMapView) {
        #if DEBUG
        print("🗺️ [MapOverlayCoordinator] disableMGRSGrid called")
        print("🗺️ [MapOverlayCoordinator] mgrsOverlay exists: \(mgrsOverlay != nil)")
        print("🗺️ [MapOverlayCoordinator] mapView overlays count: \(mapView.overlays.count)")
        #endif

        if let overlay = mgrsOverlay {
            mapView.removeOverlay(overlay)
            mgrsOverlay = nil

            #if DEBUG
            print("🗺️ [MapOverlayCoordinator] Grid overlay removed. Remaining overlays: \(mapView.overlays.count)")
            #endif
        } else {
            #if DEBUG
            print("🗺️ [MapOverlayCoordinator] No MGRS overlay to remove")
            #endif
        }
    }

    private func updateMGRSGrid() {
        guard let mapView = mapView, isOverlayVisible(.mgrsGrid) else { return }
        enableMGRSGrid(on: mapView)
    }

    func updateCenterMGRS(for coordinate: CLLocationCoordinate2D? = nil) {
        // Throttle updates to prevent excessive CPU usage during map animations
        let now = Date()
        guard now.timeIntervalSince(lastMGRSUpdateTime) >= mgrsUpdateThrottleInterval else {
            return
        }
        lastMGRSUpdateTime = now

        let coord: CLLocationCoordinate2D
        if let provided = coordinate {
            coord = provided
        } else if let mapView = mapView {
            coord = mapView.centerCoordinate
        } else {
            // Defer @Published property update to avoid "Publishing changes from within view updates"
            DispatchQueue.main.async { [weak self] in
                self?.currentCenterMGRS = "--"
            }
            return
        }

        let newValue: String
        if MGRSConverter.isWithinMGRSBounds(coord) {
            newValue = MGRSConverter.formatMGRS(coord, precision: .tenMeter, withSpaces: true)
        } else {
            newValue = "Out of MGRS bounds"
        }

        // Defer @Published property update to avoid "Publishing changes from within view updates"
        DispatchQueue.main.async { [weak self] in
            self?.currentCenterMGRS = newValue
        }
    }

    // MARK: - Generic Overlay Management

    func addOverlay(_ overlay: MKOverlay, forType type: MapOverlayType) {
        guard let mapView = mapView else { return }

        if activeOverlays[type] == nil {
            activeOverlays[type] = []
        }

        activeOverlays[type]?.append(overlay)

        // Add at appropriate level based on z-order
        let level: MKOverlayLevel = type.zOrder < 25 ? .aboveRoads : .aboveLabels
        mapView.addOverlay(overlay, level: level)
    }

    func removeOverlay(_ overlay: MKOverlay, forType type: MapOverlayType) {
        guard let mapView = mapView else { return }

        mapView.removeOverlay(overlay)
        activeOverlays[type]?.removeAll { $0 === overlay }
    }

    private func removeAllOverlays(ofType type: MapOverlayType, from mapView: MKMapView) {
        guard let overlays = activeOverlays[type] else { return }

        for overlay in overlays {
            mapView.removeOverlay(overlay)
        }

        activeOverlays[type] = []
    }

    // MARK: - Performance Optimization

    func updateVisibleOverlays(in region: MKCoordinateRegion) {
        // Only render overlays that are within or near the visible region
        // This is called when the map region changes

        updateCenterMGRS(for: region.center)

        // Future: implement frustum culling for overlays
    }

    func cleanupInactiveOverlays() {
        guard let mapView = mapView else { return }

        for (type, overlays) in activeOverlays {
            if overlayVisibility[type] != true {
                for overlay in overlays {
                    mapView.removeOverlay(overlay)
                }
                activeOverlays[type] = []
            }
        }
    }

    // MARK: - Renderer Provider

    func renderer(for overlay: MKOverlay) -> MKOverlayRenderer? {
        // MGRS Grid
        if let mgrsOverlay = overlay as? MGRSGridOverlay {
            return MGRSGridRenderer(overlay: mgrsOverlay)
        }

        // Breadcrumb trails
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = trailColor.withAlphaComponent(0.8)
            renderer.lineWidth = trailLineWidth
            renderer.lineCap = .round
            renderer.lineJoin = .round
            return renderer
        }

        // Circles (range rings, etc.)
        if let circle = overlay as? MKCircle {
            let renderer = MKCircleRenderer(circle: circle)
            renderer.strokeColor = rbLineColor.withAlphaComponent(0.9)
            renderer.fillColor = rbLineColor.withAlphaComponent(0.1)
            renderer.lineWidth = 2.0
            return renderer
        }

        // Polygons
        if let polygon = overlay as? MKPolygon {
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.strokeColor = .systemBlue.withAlphaComponent(0.8)
            renderer.fillColor = .systemBlue.withAlphaComponent(0.2)
            renderer.lineWidth = 2.0
            return renderer
        }

        return nil
    }

    // MARK: - Settings Persistence

    func saveSettings() {
        let defaults = UserDefaults.standard

        // MGRS Grid settings
        defaults.set(mgrsGridDensity.rawValue, forKey: "mgrsGridDensity")
        defaults.set(showMGRSLabels, forKey: "showMGRSLabels")
        defaults.set(isOverlayVisible(.mgrsGrid), forKey: "mgrsGridEnabled")

        // Trail settings
        defaults.set(trailMaxLength, forKey: "trailMaxLength")
        defaults.set(Float(trailLineWidth), forKey: "trailLineWidth")

        // Save overlay visibility
        for (type, visible) in overlayVisibility {
            defaults.set(visible, forKey: "overlay_\(type.rawValue)_visible")
        }
    }

    func loadSettings() {
        let defaults = UserDefaults.standard

        #if DEBUG
        print("🗺️ [MapOverlayCoordinator] Loading settings...")
        #endif

        // MGRS Grid settings
        if let densityString = defaults.string(forKey: "mgrsGridDensity"),
           let density = MGRSGridDensity(rawValue: densityString) {
            mgrsGridDensity = density
        }

        showMGRSLabels = defaults.bool(forKey: "showMGRSLabels")

        // Trail settings
        let savedTrailLength = defaults.integer(forKey: "trailMaxLength")
        if savedTrailLength > 0 {
            trailMaxLength = savedTrailLength
        }

        let savedTrailWidth = defaults.float(forKey: "trailLineWidth")
        if savedTrailWidth > 0 {
            trailLineWidth = CGFloat(savedTrailWidth)
        }

        // Load overlay visibility and apply state
        for type in MapOverlayType.allCases {
            // IMPORTANT: Always start with MGRS grid disabled to fix stuck grid issue
            // User can manually enable it via the toggle button
            let visible = type == .mgrsGrid ? false : defaults.bool(forKey: "overlay_\(type.rawValue)_visible")

            #if DEBUG
            print("🗺️ [MapOverlayCoordinator] Loaded \(type.rawValue): \(visible)")
            #endif

            overlayVisibility[type] = visible

            // Apply the loaded state to the map (if mapView is configured)
            if visible && mapView != nil {
                // Delay adding overlays until next run loop to ensure map is ready
                DispatchQueue.main.async { [weak self] in
                    self?.addOverlay(type)
                }
            }
        }
    }
}

// MARK: - SwiftUI Binding Extensions

extension MapOverlayCoordinator {
    var mgrsGridEnabled: Bool {
        get {
            return isOverlayVisible(.mgrsGrid)
        }
        set {
            #if DEBUG
            print("🗺️ [MapOverlayCoordinator] mgrsGridEnabled SET: \(newValue)")
            #endif

            if newValue {
                addOverlay(.mgrsGrid)
            } else {
                removeOverlay(.mgrsGrid)
            }
        }
    }

    var breadcrumbTrailsEnabled: Bool {
        get { isOverlayVisible(.breadcrumbTrails) }
        set {
            if newValue {
                addOverlay(.breadcrumbTrails)
            } else {
                removeOverlay(.breadcrumbTrails)
            }
        }
    }

    var rangeBearingEnabled: Bool {
        get { isOverlayVisible(.rangeBearingLines) }
        set {
            if newValue {
                addOverlay(.rangeBearingLines)
            } else {
                removeOverlay(.rangeBearingLines)
            }
        }
    }
}
