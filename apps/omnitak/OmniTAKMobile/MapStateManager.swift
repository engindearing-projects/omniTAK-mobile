//
//  MapStateManager.swift
//  OmniTAKMobile
//
//  Centralized state manager for all map modes and coordinate display
//

import Foundation
import MapKit
import SwiftUI
import Combine
import CoreLocation

// MARK: - Map Mode

enum MapMode: String, CaseIterable, Identifiable {
    case normal = "Normal"
    case cursor = "Cursor"
    case drawing = "Drawing"
    case measurement = "Measurement"
    case rangeBearing = "R&B"
    case pointDrop = "Point Drop"
    case trackRecording = "Track Recording"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .normal: return "map"
        case .cursor: return "scope"
        case .drawing: return "pencil.tip.crop.circle"
        case .measurement: return "ruler"
        case .rangeBearing: return "arrow.triangle.swap"
        case .pointDrop: return "mappin.and.ellipse"
        case .trackRecording: return "point.3.connected.trianglepath.dotted"
        }
    }

    var description: String {
        switch self {
        case .normal: return "Normal map navigation"
        case .cursor: return "Precision cursor for exact placement"
        case .drawing: return "Draw shapes on the map"
        case .measurement: return "Measure distances and areas"
        case .rangeBearing: return "Calculate range and bearing between points"
        case .pointDrop: return "Drop point markers"
        case .trackRecording: return "Record movement track"
        }
    }
}

// MARK: - Coordinate Display Format

enum CoordinateDisplayFormat: String, CaseIterable, Identifiable {
    case decimalDegrees = "DD"
    case degreesMinutes = "DM"
    case degreesMinutesSeconds = "DMS"
    case mgrs = "MGRS"
    case utm = "UTM"
    case bng = "BNG"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .decimalDegrees: return "Decimal Degrees"
        case .degreesMinutes: return "Degrees Minutes"
        case .degreesMinutesSeconds: return "Degrees Minutes Seconds"
        case .mgrs: return "Military Grid Reference System"
        case .utm: return "Universal Transverse Mercator"
        case .bng: return "British National Grid"
        }
    }

    var shortName: String { rawValue }

    func format(_ coordinate: CLLocationCoordinate2D) -> String {
        switch self {
        case .decimalDegrees:
            return MGRSConverter.formatLatLon(coordinate, style: .decimalDegrees)
        case .degreesMinutes:
            return MGRSConverter.formatLatLon(coordinate, style: .degreesMinutes)
        case .degreesMinutesSeconds:
            return MGRSConverter.formatLatLon(coordinate, style: .degreesMinutesSeconds)
        case .mgrs:
            if MGRSConverter.isWithinMGRSBounds(coordinate) {
                return MGRSConverter.formatMGRS(coordinate, precision: .tenMeter, withSpaces: true)
            } else {
                return "Out of MGRS bounds"
            }
        case .utm:
            return MGRSConverter.formatUTM(coordinate)
        case .bng:
            if BNGConverter.isWithinBNGBounds(coordinate) {
                return BNGConverter.formatBNG(coordinate, precision: .tenMeter, withSpaces: true)
            } else {
                return "Out of BNG bounds"
            }
        }
    }
}

// MARK: - Cursor State

struct CursorState {
    var isActive: Bool = false
    var position: CLLocationCoordinate2D?
    var screenPosition: CGPoint = .zero
    var lockToCenter: Bool = false
}

// MARK: - R&B Selection State

struct RangeBearingState {
    var firstPoint: CLLocationCoordinate2D?
    var secondPoint: CLLocationCoordinate2D?
    var distance: CLLocationDistance = 0
    var bearing: Double = 0
    var isSelectingSecondPoint: Bool = false

    var isComplete: Bool {
        return firstPoint != nil && secondPoint != nil
    }

    mutating func reset() {
        firstPoint = nil
        secondPoint = nil
        distance = 0
        bearing = 0
        isSelectingSecondPoint = false
    }

    mutating func calculateRangeBearing() {
        guard let p1 = firstPoint, let p2 = secondPoint else { return }

        let loc1 = CLLocation(latitude: p1.latitude, longitude: p1.longitude)
        let loc2 = CLLocation(latitude: p2.latitude, longitude: p2.longitude)

        distance = loc1.distance(from: loc2)
        bearing = calculateBearing(from: p1, to: p2)
    }

    private func calculateBearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let deltaLon = (end.longitude - start.longitude) * .pi / 180

        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)

        var bearing = atan2(y, x) * 180 / .pi
        if bearing < 0 {
            bearing += 360
        }

        return bearing
    }
}

// MARK: - Map State Manager

class MapStateManager: ObservableObject {

    // MARK: - Published Properties

    @Published var currentMode: MapMode = .normal
    @Published var previousMode: MapMode = .normal
    @Published var coordinateFormat: CoordinateDisplayFormat = .mgrs
    @Published var cursorState = CursorState()
    @Published var rangeBearingState = RangeBearingState()

    // Current map center and region
    @Published var mapCenter: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365)
    @Published var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    // Formatted coordinates
    @Published var formattedCenterCoordinate: String = ""
    @Published var formattedCursorCoordinate: String = ""

    // User interaction state
    @Published var isUserInteracting: Bool = false
    @Published var showCoordinateCrosshair: Bool = false

    // Gesture handling
    @Published var allowsPanning: Bool = true
    @Published var allowsZooming: Bool = true
    @Published var allowsRotation: Bool = true

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupObservers()
        loadPreferences()
    }

    private func setupObservers() {
        // Update formatted coordinates when center changes
        $mapCenter
            .sink { [weak self] coordinate in
                self?.updateFormattedCoordinates()
            }
            .store(in: &cancellables)

        // Update formatted coordinates when format changes
        $coordinateFormat
            .sink { [weak self] _ in
                self?.updateFormattedCoordinates()
            }
            .store(in: &cancellables)

        // Update cursor coordinate when cursor position changes
        $cursorState
            .map(\.position)
            .sink { [weak self] position in
                if let pos = position {
                    self?.formattedCursorCoordinate = self?.coordinateFormat.format(pos) ?? ""
                } else {
                    self?.formattedCursorCoordinate = ""
                }
            }
            .store(in: &cancellables)

        // Configure gesture handling based on mode
        $currentMode
            .sink { [weak self] mode in
                self?.configureGesturesForMode(mode)
            }
            .store(in: &cancellables)
    }

    // MARK: - Mode Management

    func setMode(_ mode: MapMode) {
        previousMode = currentMode
        currentMode = mode

        // Reset mode-specific states
        switch mode {
        case .normal:
            cursorState.isActive = false
            showCoordinateCrosshair = false
        case .cursor:
            cursorState.isActive = true
            cursorState.lockToCenter = true
            showCoordinateCrosshair = true
        case .drawing:
            cursorState.isActive = false
            showCoordinateCrosshair = false
        case .measurement:
            cursorState.isActive = true
            showCoordinateCrosshair = true
        case .rangeBearing:
            rangeBearingState.reset()
            cursorState.isActive = true
            showCoordinateCrosshair = true
        case .pointDrop:
            cursorState.isActive = true
            showCoordinateCrosshair = true
        case .trackRecording:
            cursorState.isActive = false
            showCoordinateCrosshair = false
        }
    }

    func revertToPreviousMode() {
        setMode(previousMode)
    }

    private func configureGesturesForMode(_ mode: MapMode) {
        switch mode {
        case .normal:
            allowsPanning = true
            allowsZooming = true
            allowsRotation = true
        case .cursor:
            allowsPanning = true
            allowsZooming = true
            allowsRotation = false
        case .drawing:
            allowsPanning = true
            allowsZooming = true
            allowsRotation = false
        case .measurement:
            allowsPanning = true
            allowsZooming = true
            allowsRotation = false
        case .rangeBearing:
            allowsPanning = true
            allowsZooming = true
            allowsRotation = false
        case .pointDrop:
            allowsPanning = true
            allowsZooming = true
            allowsRotation = false
        case .trackRecording:
            allowsPanning = true
            allowsZooming = true
            allowsRotation = true
        }
    }

    // MARK: - Coordinate Handling

    func updateMapCenter(_ coordinate: CLLocationCoordinate2D) {
        mapCenter = coordinate
        updateFormattedCoordinates()
    }

    func updateMapRegion(_ region: MKCoordinateRegion) {
        mapRegion = region
        mapCenter = region.center
        updateFormattedCoordinates()
    }

    private func updateFormattedCoordinates() {
        formattedCenterCoordinate = coordinateFormat.format(mapCenter)

        if let cursorPos = cursorState.position {
            formattedCursorCoordinate = coordinateFormat.format(cursorPos)
        }
    }

    func setCursorPosition(_ coordinate: CLLocationCoordinate2D) {
        cursorState.position = coordinate
    }

    func setCursorScreenPosition(_ point: CGPoint) {
        cursorState.screenPosition = point
    }

    // MARK: - Range & Bearing

    func handleRangeBearingTap(at coordinate: CLLocationCoordinate2D) {
        guard currentMode == .rangeBearing else { return }

        if rangeBearingState.firstPoint == nil {
            rangeBearingState.firstPoint = coordinate
            rangeBearingState.isSelectingSecondPoint = true
        } else if rangeBearingState.secondPoint == nil {
            rangeBearingState.secondPoint = coordinate
            rangeBearingState.calculateRangeBearing()
            rangeBearingState.isSelectingSecondPoint = false
        }
    }

    func resetRangeBearing() {
        rangeBearingState.reset()
    }

    func formatRangeBearingInfo() -> String {
        guard rangeBearingState.isComplete else { return "" }

        let distanceMeters = rangeBearingState.distance
        let bearing = rangeBearingState.bearing

        let distanceStr: String
        if distanceMeters >= 1000 {
            distanceStr = String(format: "%.2f km", distanceMeters / 1000)
        } else {
            distanceStr = String(format: "%.0f m", distanceMeters)
        }

        return "Range: \(distanceStr) | Bearing: \(String(format: "%.1f", bearing))°"
    }

    // MARK: - Tap Handling

    func handleMapTap(at coordinate: CLLocationCoordinate2D, screenPoint: CGPoint) {
        switch currentMode {
        case .normal:
            // Normal mode - no special handling
            break
        case .cursor:
            // Cursor mode - update cursor position
            setCursorPosition(coordinate)
            setCursorScreenPosition(screenPoint)
        case .drawing:
            // Drawing is handled by DrawingToolsManager
            break
        case .measurement:
            // Measurement is handled by MeasurementManager
            break
        case .rangeBearing:
            handleRangeBearingTap(at: coordinate)
        case .pointDrop:
            // Point drop is handled by PointDropperService
            break
        case .trackRecording:
            // Track recording doesn't respond to taps
            break
        }
    }

    // MARK: - Preferences

    func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(coordinateFormat.rawValue, forKey: "coordinateDisplayFormat")
    }

    func loadPreferences() {
        let defaults = UserDefaults.standard

        if let formatString = defaults.string(forKey: "coordinateDisplayFormat"),
           let format = CoordinateDisplayFormat(rawValue: formatString) {
            coordinateFormat = format
        }
    }

    // MARK: - Convenience Methods

    func cycleCoordinateFormat() {
        let allFormats = CoordinateDisplayFormat.allCases
        guard let currentIndex = allFormats.firstIndex(of: coordinateFormat) else { return }
        let nextIndex = (currentIndex + 1) % allFormats.count
        coordinateFormat = allFormats[nextIndex]
        savePreferences()
    }

    func isModeActive(_ mode: MapMode) -> Bool {
        return currentMode == mode
    }

    func getCoordinateString(for coordinate: CLLocationCoordinate2D) -> String {
        return coordinateFormat.format(coordinate)
    }
}

// MARK: - SwiftUI Bindings

extension MapStateManager {
    var isCursorModeActive: Bool {
        get { currentMode == .cursor }
        set {
            if newValue {
                setMode(.cursor)
            } else {
                setMode(.normal)
            }
        }
    }

    var isDrawingModeActive: Bool {
        get { currentMode == .drawing }
        set {
            if newValue {
                setMode(.drawing)
            } else {
                setMode(.normal)
            }
        }
    }

    var isMeasurementModeActive: Bool {
        get { currentMode == .measurement }
        set {
            if newValue {
                setMode(.measurement)
            } else {
                setMode(.normal)
            }
        }
    }

    var isRangeBearingModeActive: Bool {
        get { currentMode == .rangeBearing }
        set {
            if newValue {
                setMode(.rangeBearing)
            } else {
                setMode(.normal)
            }
        }
    }
}
