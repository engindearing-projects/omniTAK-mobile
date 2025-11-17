//
//  TerrainVisualizationService.swift
//  OmniTAKMobile
//
//  Service for managing 3D terrain visualization, camera animations, and elevation data
//

import Foundation
import MapKit
import CoreLocation
import Combine

// MARK: - 3D View Mode

enum Map3DViewMode: String, CaseIterable, Identifiable {
    case standard2D = "2D"
    case perspective3D = "3D"
    case flyover = "Flyover"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .standard2D: return "map"
        case .perspective3D: return "view.3d"
        case .flyover: return "airplane"
        }
    }

    var description: String {
        switch self {
        case .standard2D: return "Standard 2D overhead view"
        case .perspective3D: return "3D perspective view with terrain"
        case .flyover: return "Animated flyover mode"
        }
    }
}

// MARK: - Terrain Exaggeration

enum TerrainExaggeration: Double, CaseIterable, Identifiable {
    case none = 1.0
    case moderate = 2.0
    case high = 3.0

    var id: Double { rawValue }

    var displayName: String {
        switch self {
        case .none: return "1x (Normal)"
        case .moderate: return "2x (Enhanced)"
        case .high: return "3x (Maximum)"
        }
    }
}

// MARK: - Camera Preset

struct CameraPreset: Identifiable, Codable {
    let id: UUID
    var name: String
    var centerCoordinate: CLLocationCoordinate2D
    var distance: CLLocationDistance
    var pitch: CGFloat
    var heading: CLLocationDirection
    var timestamp: Date

    init(id: UUID = UUID(), name: String, centerCoordinate: CLLocationCoordinate2D, distance: CLLocationDistance, pitch: CGFloat, heading: CLLocationDirection) {
        self.id = id
        self.name = name
        self.centerCoordinate = centerCoordinate
        self.distance = distance
        self.pitch = pitch
        self.heading = heading
        self.timestamp = Date()
    }

    // Custom Codable implementation for CLLocationCoordinate2D
    enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, distance, pitch, heading, timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        centerCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        distance = try container.decode(CLLocationDistance.self, forKey: .distance)
        pitch = try container.decode(CGFloat.self, forKey: .pitch)
        heading = try container.decode(CLLocationDirection.self, forKey: .heading)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(centerCoordinate.latitude, forKey: .latitude)
        try container.encode(centerCoordinate.longitude, forKey: .longitude)
        try container.encode(distance, forKey: .distance)
        try container.encode(pitch, forKey: .pitch)
        try container.encode(heading, forKey: .heading)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

// MARK: - Flyover Waypoint

struct FlyoverWaypoint: Identifiable {
    let id: UUID = UUID()
    let coordinate: CLLocationCoordinate2D
    let altitude: CLLocationDistance
    let pitch: CGFloat
    let heading: CLLocationDirection
    let duration: TimeInterval
}

// MARK: - Camera State

struct CameraState {
    var centerCoordinate: CLLocationCoordinate2D
    var distance: CLLocationDistance
    var pitch: CGFloat
    var heading: CLLocationDirection

    var asMapCamera: MKMapCamera {
        let camera = MKMapCamera()
        camera.centerCoordinate = centerCoordinate
        camera.centerCoordinateDistance = distance
        camera.pitch = pitch
        camera.heading = heading
        return camera
    }

    static func from(camera: MKMapCamera) -> CameraState {
        return CameraState(
            centerCoordinate: camera.centerCoordinate,
            distance: camera.centerCoordinateDistance,
            pitch: camera.pitch,
            heading: camera.heading
        )
    }
}

// MARK: - Terrain Visualization Service

class TerrainVisualizationService: NSObject, ObservableObject {

    // Singleton instance
    static let shared = TerrainVisualizationService()

    // MARK: - Published Properties

    @Published var currentMode: Map3DViewMode = .standard2D
    @Published var cameraState: CameraState = CameraState(
        centerCoordinate: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
        distance: 5000,
        pitch: 0,
        heading: 0
    )

    @Published var terrainExaggeration: TerrainExaggeration = .none
    @Published var isAnimating: Bool = false
    @Published var savedPresets: [CameraPreset] = []
    @Published var flyoverWaypoints: [FlyoverWaypoint] = []
    @Published var flyoverProgress: Double = 0
    @Published var isFlyoverActive: Bool = false

    // Camera constraints
    @Published var minPitch: CGFloat = 0
    @Published var maxPitch: CGFloat = 85
    @Published var minDistance: CLLocationDistance = 100
    @Published var maxDistance: CLLocationDistance = 50000000

    // Elevation data
    @Published var currentTerrainElevation: Double = 0
    @Published var showElevationAwareness: Bool = true

    // MARK: - Private Properties

    private weak var mapView: MKMapView?
    private var cancellables = Set<AnyCancellable>()
    private var flyoverTimer: Timer?
    private var currentFlyoverIndex: Int = 0
    private let persistenceKey = "saved_camera_presets"

    // MARK: - Initialization

    override init() {
        super.init()
        loadPresets()
        loadPreferences()
        setupObservers()
    }

    private func setupObservers() {
        // Observe mode changes
        $currentMode
            .dropFirst()
            .sink { [weak self] mode in
                self?.handleModeChange(mode)
            }
            .store(in: &cancellables)

        // Observe terrain exaggeration changes
        $terrainExaggeration
            .dropFirst()
            .sink { [weak self] _ in
                self?.applyTerrainExaggeration()
            }
            .store(in: &cancellables)
    }

    // MARK: - Map View Configuration

    func configure(with mapView: MKMapView) {
        self.mapView = mapView
        syncCameraState()
    }

    func syncCameraState() {
        guard let camera = mapView?.camera else { return }
        cameraState = CameraState.from(camera: camera)
    }

    // MARK: - Mode Management

    private func handleModeChange(_ mode: Map3DViewMode) {
        switch mode {
        case .standard2D:
            transitionTo2D()
        case .perspective3D:
            transitionTo3D()
        case .flyover:
            // Flyover is started separately with specific waypoints
            break
        }
        savePreferences()
    }

    func transitionTo2D() {
        guard let mapView = mapView else { return }

        let camera = MKMapCamera()
        camera.centerCoordinate = cameraState.centerCoordinate
        camera.centerCoordinateDistance = cameraState.distance
        camera.pitch = 0
        camera.heading = 0

        animateCamera(to: camera, duration: 0.5)
        currentMode = .standard2D
    }

    func transitionTo3D() {
        guard let mapView = mapView else { return }

        let camera = MKMapCamera()
        camera.centerCoordinate = cameraState.centerCoordinate
        camera.centerCoordinateDistance = cameraState.distance
        camera.pitch = min(45, maxPitch)
        camera.heading = cameraState.heading

        animateCamera(to: camera, duration: 0.5)
        currentMode = .perspective3D
    }

    // MARK: - Camera Control

    func setPitch(_ pitch: CGFloat) {
        guard let mapView = mapView else { return }

        let clampedPitch = min(max(pitch, minPitch), maxPitch)

        let camera = mapView.camera.copy() as! MKMapCamera
        camera.pitch = clampedPitch

        mapView.setCamera(camera, animated: true)
        cameraState.pitch = clampedPitch
    }

    func setHeading(_ heading: CLLocationDirection) {
        guard let mapView = mapView else { return }

        var normalizedHeading = heading.truncatingRemainder(dividingBy: 360)
        if normalizedHeading < 0 {
            normalizedHeading += 360
        }

        let camera = mapView.camera.copy() as! MKMapCamera
        camera.heading = normalizedHeading

        mapView.setCamera(camera, animated: true)
        cameraState.heading = normalizedHeading
    }

    func setDistance(_ distance: CLLocationDistance) {
        guard let mapView = mapView else { return }

        let clampedDistance = min(max(distance, minDistance), maxDistance)

        let camera = mapView.camera.copy() as! MKMapCamera
        camera.centerCoordinateDistance = clampedDistance

        mapView.setCamera(camera, animated: true)
        cameraState.distance = clampedDistance
    }

    func setCenter(_ coordinate: CLLocationCoordinate2D) {
        guard let mapView = mapView else { return }

        let camera = mapView.camera.copy() as! MKMapCamera
        camera.centerCoordinate = coordinate

        mapView.setCamera(camera, animated: true)
        cameraState.centerCoordinate = coordinate
    }

    func rotateCamera(by degrees: CLLocationDirection) {
        let newHeading = cameraState.heading + degrees
        setHeading(newHeading)
    }

    func tiltCamera(by degrees: CGFloat) {
        let newPitch = cameraState.pitch + degrees
        setPitch(newPitch)
    }

    func zoomIn() {
        let newDistance = cameraState.distance * 0.75
        setDistance(newDistance)
    }

    func zoomOut() {
        let newDistance = cameraState.distance * 1.5
        setDistance(newDistance)
    }

    // MARK: - "Look At" Functionality

    func lookAt(coordinate: CLLocationCoordinate2D, fromDistance: CLLocationDistance? = nil, withPitch: CGFloat? = nil) {
        guard let mapView = mapView else { return }

        let distance = fromDistance ?? cameraState.distance
        let pitch = withPitch ?? (currentMode == .standard2D ? 0 : 45)

        // Calculate heading from current position to target
        let bearing = calculateBearing(from: cameraState.centerCoordinate, to: coordinate)

        let camera = MKMapCamera(
            lookingAtCenter: coordinate,
            fromDistance: distance,
            pitch: pitch,
            heading: bearing
        )

        animateCamera(to: camera, duration: 1.0)
    }

    func lookAt(coordinate: CLLocationCoordinate2D, fromEyeCoordinate eyeCoordinate: CLLocationCoordinate2D, eyeAltitude: CLLocationDistance) {
        guard let mapView = mapView else { return }

        let camera = MKMapCamera(
            lookingAtCenter: coordinate,
            fromEyeCoordinate: eyeCoordinate,
            eyeAltitude: eyeAltitude
        )

        animateCamera(to: camera, duration: 1.0)
    }

    private func calculateBearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> CLLocationDirection {
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

    // MARK: - Camera Animation

    func animateCamera(to camera: MKMapCamera, duration: TimeInterval) {
        guard let mapView = mapView else { return }

        isAnimating = true

        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseInOut]) {
            mapView.setCamera(camera, animated: false)
        } completion: { [weak self] _ in
            self?.isAnimating = false
            self?.cameraState = CameraState.from(camera: camera)
        }
    }

    func animateToCameraState(_ state: CameraState, duration: TimeInterval = 1.0) {
        animateCamera(to: state.asMapCamera, duration: duration)
    }

    // MARK: - Flyover Mode

    func startFlyover(waypoints: [FlyoverWaypoint]) {
        guard !waypoints.isEmpty else { return }

        flyoverWaypoints = waypoints
        currentFlyoverIndex = 0
        flyoverProgress = 0
        isFlyoverActive = true
        currentMode = .flyover

        flyToNextWaypoint()
    }

    func startFlyover(along coordinates: [CLLocationCoordinate2D], altitude: CLLocationDistance = 1000, speed: Double = 50) {
        guard coordinates.count >= 2 else { return }

        var waypoints: [FlyoverWaypoint] = []

        for i in 0..<coordinates.count {
            let coordinate = coordinates[i]
            var heading: CLLocationDirection = 0

            if i < coordinates.count - 1 {
                heading = calculateBearing(from: coordinate, to: coordinates[i + 1])
            } else if i > 0 {
                heading = calculateBearing(from: coordinates[i - 1], to: coordinate)
            }

            let pitch: CGFloat = 45

            // Calculate duration based on distance and speed
            var duration: TimeInterval = 3.0
            if i > 0 {
                let distance = CLLocation(latitude: coordinates[i - 1].latitude, longitude: coordinates[i - 1].longitude)
                    .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
                duration = distance / speed
            }

            let waypoint = FlyoverWaypoint(
                coordinate: coordinate,
                altitude: altitude,
                pitch: pitch,
                heading: heading,
                duration: duration
            )
            waypoints.append(waypoint)
        }

        startFlyover(waypoints: waypoints)
    }

    private func flyToNextWaypoint() {
        guard isFlyoverActive, currentFlyoverIndex < flyoverWaypoints.count else {
            stopFlyover()
            return
        }

        let waypoint = flyoverWaypoints[currentFlyoverIndex]

        let camera = MKMapCamera()
        camera.centerCoordinate = waypoint.coordinate
        camera.centerCoordinateDistance = waypoint.altitude
        camera.pitch = waypoint.pitch
        camera.heading = waypoint.heading

        animateCamera(to: camera, duration: waypoint.duration)

        flyoverProgress = Double(currentFlyoverIndex + 1) / Double(flyoverWaypoints.count)

        DispatchQueue.main.asyncAfter(deadline: .now() + waypoint.duration) { [weak self] in
            guard let self = self, self.isFlyoverActive else { return }
            self.currentFlyoverIndex += 1
            self.flyToNextWaypoint()
        }
    }

    func pauseFlyover() {
        isFlyoverActive = false
    }

    func resumeFlyover() {
        guard !flyoverWaypoints.isEmpty else { return }
        isFlyoverActive = true
        flyToNextWaypoint()
    }

    func stopFlyover() {
        isFlyoverActive = false
        flyoverTimer?.invalidate()
        flyoverTimer = nil
        currentFlyoverIndex = 0
        flyoverProgress = 0

        if currentMode == .flyover {
            currentMode = .perspective3D
        }
    }

    // MARK: - Terrain Exaggeration

    private func applyTerrainExaggeration() {
        // Note: iOS MapKit doesn't have native terrain exaggeration support
        // This would require custom tile overlays with modified elevation data
        // For now, we store the preference and could apply it if using custom terrain tiles
        savePreferences()
    }

    // MARK: - Elevation Awareness

    func getTerrainElevation(at coordinate: CLLocationCoordinate2D) async -> Double {
        // Simulate terrain elevation based on coordinate
        // In production, use elevation API or local DEM data
        let lat = coordinate.latitude
        let lon = coordinate.longitude

        // Multi-frequency terrain simulation
        let baseElevation = 500.0
        let largeScale = sin(lat * 0.1) * cos(lon * 0.1) * 800
        let mediumScale = sin(lat * 0.5) * cos(lon * 0.5) * 200
        let smallScale = sin(lat * 2.0) * cos(lon * 2.0) * 50

        let elevation = baseElevation + largeScale + mediumScale + smallScale
        return max(0, elevation)
    }

    func updateTerrainElevation() {
        Task {
            let elevation = await getTerrainElevation(at: cameraState.centerCoordinate)
            await MainActor.run {
                currentTerrainElevation = elevation
            }
        }
    }

    func positionCameraAtGroundLevel(coordinate: CLLocationCoordinate2D) async {
        let elevation = await getTerrainElevation(at: coordinate)
        let cameraAltitude = elevation + 2.0 // 2 meters above ground

        await MainActor.run {
            let camera = MKMapCamera()
            camera.centerCoordinate = coordinate
            camera.centerCoordinateDistance = cameraAltitude
            camera.pitch = maxPitch
            camera.heading = cameraState.heading

            animateCamera(to: camera, duration: 1.0)
        }
    }

    func positionCameraElevated(coordinate: CLLocationCoordinate2D, heightAboveGround: CLLocationDistance = 100) async {
        let elevation = await getTerrainElevation(at: coordinate)
        let cameraAltitude = elevation + heightAboveGround

        await MainActor.run {
            let camera = MKMapCamera()
            camera.centerCoordinate = coordinate
            camera.centerCoordinateDistance = cameraAltitude
            camera.pitch = 60
            camera.heading = cameraState.heading

            animateCamera(to: camera, duration: 1.0)
        }
    }

    // MARK: - Preset Management

    func saveCurrentAsPreset(name: String) {
        let preset = CameraPreset(
            name: name,
            centerCoordinate: cameraState.centerCoordinate,
            distance: cameraState.distance,
            pitch: cameraState.pitch,
            heading: cameraState.heading
        )
        savedPresets.append(preset)
        persistPresets()
    }

    func applyPreset(_ preset: CameraPreset) {
        let state = CameraState(
            centerCoordinate: preset.centerCoordinate,
            distance: preset.distance,
            pitch: preset.pitch,
            heading: preset.heading
        )
        animateToCameraState(state)
    }

    func deletePreset(_ preset: CameraPreset) {
        savedPresets.removeAll { $0.id == preset.id }
        persistPresets()
    }

    func clearAllPresets() {
        savedPresets.removeAll()
        persistPresets()
    }

    // MARK: - Persistence

    private func loadPresets() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let presets = try? JSONDecoder().decode([CameraPreset].self, from: data) else {
            return
        }
        savedPresets = presets
    }

    private func persistPresets() {
        guard let data = try? JSONEncoder().encode(savedPresets) else { return }
        UserDefaults.standard.set(data, forKey: persistenceKey)
    }

    func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(currentMode.rawValue, forKey: "map3DViewMode")
        defaults.set(terrainExaggeration.rawValue, forKey: "terrainExaggeration")
        defaults.set(showElevationAwareness, forKey: "showElevationAwareness")
        defaults.set(cameraState.pitch, forKey: "camera3DPitch")
        defaults.set(cameraState.heading, forKey: "camera3DHeading")
        defaults.set(cameraState.distance, forKey: "camera3DDistance")
    }

    func loadPreferences() {
        let defaults = UserDefaults.standard

        if let modeString = defaults.string(forKey: "map3DViewMode"),
           let mode = Map3DViewMode(rawValue: modeString) {
            currentMode = mode
        }

        let exaggerationValue = defaults.double(forKey: "terrainExaggeration")
        if exaggerationValue > 0, let exaggeration = TerrainExaggeration(rawValue: exaggerationValue) {
            terrainExaggeration = exaggeration
        }

        showElevationAwareness = defaults.bool(forKey: "showElevationAwareness")

        let savedPitch = CGFloat(defaults.double(forKey: "camera3DPitch"))
        if savedPitch > 0 {
            cameraState.pitch = savedPitch
        }

        let savedHeading = defaults.double(forKey: "camera3DHeading")
        cameraState.heading = savedHeading

        let savedDistance = defaults.double(forKey: "camera3DDistance")
        if savedDistance > 0 {
            cameraState.distance = savedDistance
        }
    }

    // MARK: - Utility Methods

    func resetToNorth() {
        setHeading(0)
    }

    func resetPitch() {
        setPitch(0)
    }

    func resetCamera() {
        transitionTo2D()
        resetToNorth()
    }

    static func formatDistance(_ meters: CLLocationDistance) -> String {
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        } else if meters < 1000000 {
            return String(format: "%.2f km", meters / 1000)
        } else {
            return String(format: "%.0f km", meters / 1000)
        }
    }

    static func formatPitch(_ pitch: CGFloat) -> String {
        return String(format: "%.1f°", pitch)
    }

    static func formatHeading(_ heading: CLLocationDirection) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((heading + 22.5).truncatingRemainder(dividingBy: 360) / 45)
        return "\(directions[index]) (\(String(format: "%.0f", heading))°)"
    }
}
