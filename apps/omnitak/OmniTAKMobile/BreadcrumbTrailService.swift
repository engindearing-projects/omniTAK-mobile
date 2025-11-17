//
//  BreadcrumbTrailService.swift
//  OmniTAKMobile
//
//  Service for tracking and visualizing user movement history as breadcrumb trails
//

import Foundation
import CoreLocation
import Combine
import MapKit

// MARK: - Breadcrumb Point

/// A single point in the breadcrumb trail
struct BreadcrumbPoint: Codable, Identifiable, Equatable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date
    let altitude: Double
    let speed: Double
    let course: Double

    init(
        id: UUID = UUID(),
        coordinate: CLLocationCoordinate2D,
        timestamp: Date = Date(),
        altitude: Double = 0,
        speed: Double = 0,
        course: Double = 0
    ) {
        self.id = id
        self.coordinate = coordinate
        self.timestamp = timestamp
        self.altitude = altitude
        self.speed = speed
        self.course = course
    }

    init(from location: CLLocation) {
        self.id = UUID()
        self.coordinate = location.coordinate
        self.timestamp = location.timestamp
        self.altitude = location.altitude
        self.speed = max(0, location.speed)
        self.course = max(0, location.course)
    }

    // Custom Codable implementation for CLLocationCoordinate2D
    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, timestamp, altitude, speed, course
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        altitude = try container.decode(Double.self, forKey: .altitude)
        speed = try container.decode(Double.self, forKey: .speed)
        course = try container.decode(Double.self, forKey: .course)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(altitude, forKey: .altitude)
        try container.encode(speed, forKey: .speed)
        try container.encode(course, forKey: .course)
    }
}

// MARK: - Breadcrumb Trail Configuration

struct BreadcrumbTrailConfiguration: Codable {
    /// Recording interval in seconds (5-60)
    var recordingInterval: TimeInterval = 10.0

    /// Maximum number of trail points (100-1000)
    var maximumTrailLength: Int = 500

    /// Minimum distance in meters to record a new point
    var minimumDistanceThreshold: Double = 5.0

    /// Team color for trail visualization (hex string)
    var teamColor: String = "#00FF00" // Default green for friendly

    /// Trail line width (2-5 points)
    var lineWidth: CGFloat = 3.0

    /// Whether to show direction arrows
    var showDirectionArrows: Bool = true

    /// Whether to fade older points
    var enableTimeFading: Bool = true

    /// Time in seconds after which points start fading (default 30 minutes)
    var fadeStartTime: TimeInterval = 1800.0

    /// Auto-save interval in seconds
    var autoSaveInterval: TimeInterval = 60.0
}

// MARK: - Breadcrumb Trail Service

class BreadcrumbTrailService: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var isRecording: Bool = false
    @Published var trailPoints: [BreadcrumbPoint] = []
    @Published var currentLocation: CLLocation?
    @Published var configuration: BreadcrumbTrailConfiguration = BreadcrumbTrailConfiguration()
    @Published var totalDistance: Double = 0.0
    @Published var recordingDuration: TimeInterval = 0.0
    @Published var pointCount: Int = 0

    // MARK: - Private Properties

    private let locationManager = CLLocationManager()
    private var recordingTimer: Timer?
    private var autoSaveTimer: Timer?
    private var durationTimer: Timer?
    private var startTime: Date?
    private var lastRecordedLocation: CLLocation?
    private var cancellables = Set<AnyCancellable>()

    // UserDefaults keys
    private let trailPointsKey = "breadcrumb_trail_points"
    private let configurationKey = "breadcrumb_trail_config"

    // Singleton
    static let shared = BreadcrumbTrailService()

    // MARK: - Initialization

    override init() {
        super.init()
        setupLocationManager()
        loadConfiguration()
        loadPersistedTrail()
    }

    // MARK: - Setup

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.requestWhenInUseAuthorization()
    }

    // MARK: - Configuration

    func updateConfiguration(_ config: BreadcrumbTrailConfiguration) {
        configuration = config
        saveConfiguration()

        // Restart timer if recording
        if isRecording {
            stopRecordingTimer()
            startRecordingTimer()
        }
    }

    func setRecordingInterval(_ interval: TimeInterval) {
        configuration.recordingInterval = max(5, min(60, interval))
        saveConfiguration()

        if isRecording {
            stopRecordingTimer()
            startRecordingTimer()
        }
    }

    func setMaximumTrailLength(_ length: Int) {
        configuration.maximumTrailLength = max(100, min(1000, length))
        saveConfiguration()
        trimTrailToMaxLength()
    }

    func setTeamColor(_ hexColor: String) {
        configuration.teamColor = hexColor
        saveConfiguration()
    }

    // MARK: - Recording Control

    func startRecording() {
        guard !isRecording else {
            print("Breadcrumb trail already recording")
            return
        }

        isRecording = true
        startTime = Date()
        lastRecordedLocation = nil

        locationManager.startUpdatingLocation()
        startRecordingTimer()
        startAutoSaveTimer()

        print("Started breadcrumb trail recording")
    }

    func stopRecording() {
        guard isRecording else { return }

        isRecording = false

        locationManager.stopUpdatingLocation()
        stopRecordingTimer()
        stopAutoSaveTimer()

        saveTrailToUserDefaults()

        print("Stopped breadcrumb trail recording with \(trailPoints.count) points")
    }

    func clearTrail() {
        trailPoints.removeAll()
        totalDistance = 0.0
        pointCount = 0
        lastRecordedLocation = nil

        clearPersistedTrail()

        print("Cleared breadcrumb trail")
    }

    // MARK: - Timer Management

    private func startRecordingTimer() {
        stopRecordingTimer()

        recordingTimer = Timer.scheduledTimer(withTimeInterval: configuration.recordingInterval, repeats: true) { [weak self] _ in
            self?.recordCurrentLocation()
        }

        // Also update duration timer
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startTime, self.isRecording else { return }
            self.recordingDuration = Date().timeIntervalSince(start)
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil
    }

    private func startAutoSaveTimer() {
        stopAutoSaveTimer()

        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: configuration.autoSaveInterval, repeats: true) { [weak self] _ in
            self?.saveTrailToUserDefaults()
        }
    }

    private func stopAutoSaveTimer() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }

    // MARK: - Point Recording

    private func recordCurrentLocation() {
        guard let location = currentLocation else { return }

        // Check minimum distance threshold
        if let lastLocation = lastRecordedLocation {
            let distance = location.distance(from: lastLocation)
            if distance < configuration.minimumDistanceThreshold {
                return
            }

            // Update total distance
            totalDistance += distance
        }

        let point = BreadcrumbPoint(from: location)
        trailPoints.append(point)
        lastRecordedLocation = location
        pointCount = trailPoints.count

        // Trim to maximum length
        trimTrailToMaxLength()

        print("Recorded breadcrumb point #\(trailPoints.count) at (\(location.coordinate.latitude), \(location.coordinate.longitude))")
    }

    private func trimTrailToMaxLength() {
        if trailPoints.count > configuration.maximumTrailLength {
            let excess = trailPoints.count - configuration.maximumTrailLength
            trailPoints.removeFirst(excess)
            pointCount = trailPoints.count
        }
    }

    // MARK: - Persistence

    private func saveConfiguration() {
        do {
            let data = try JSONEncoder().encode(configuration)
            UserDefaults.standard.set(data, forKey: configurationKey)
        } catch {
            print("Failed to save breadcrumb configuration: \(error)")
        }
    }

    private func loadConfiguration() {
        guard let data = UserDefaults.standard.data(forKey: configurationKey) else { return }

        do {
            configuration = try JSONDecoder().decode(BreadcrumbTrailConfiguration.self, from: data)
        } catch {
            print("Failed to load breadcrumb configuration: \(error)")
        }
    }

    private func saveTrailToUserDefaults() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(trailPoints)
            UserDefaults.standard.set(data, forKey: trailPointsKey)
            print("Saved \(trailPoints.count) breadcrumb points to UserDefaults")
        } catch {
            print("Failed to save breadcrumb trail: \(error)")
        }
    }

    private func loadPersistedTrail() {
        guard let data = UserDefaults.standard.data(forKey: trailPointsKey) else { return }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            trailPoints = try decoder.decode([BreadcrumbPoint].self, from: data)
            pointCount = trailPoints.count
            recalculateTotalDistance()
            print("Loaded \(trailPoints.count) breadcrumb points from UserDefaults")
        } catch {
            print("Failed to load breadcrumb trail: \(error)")
        }
    }

    private func clearPersistedTrail() {
        UserDefaults.standard.removeObject(forKey: trailPointsKey)
    }

    private func recalculateTotalDistance() {
        guard trailPoints.count >= 2 else {
            totalDistance = 0.0
            return
        }

        totalDistance = 0.0
        for i in 1..<trailPoints.count {
            let loc1 = CLLocation(latitude: trailPoints[i-1].coordinate.latitude, longitude: trailPoints[i-1].coordinate.longitude)
            let loc2 = CLLocation(latitude: trailPoints[i].coordinate.latitude, longitude: trailPoints[i].coordinate.longitude)
            totalDistance += loc1.distance(from: loc2)
        }
    }

    // MARK: - Export Functions

    /// Export trail as GPX format
    func exportToGPX() -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="OmniTAK iOS"
             xmlns="http://www.topografix.com/GPX/1/1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>Breadcrumb Trail</name>
            <time>\(dateFormatter.string(from: Date()))</time>
          </metadata>
          <trk>
            <name>Breadcrumb Trail</name>
            <desc>Total Distance: \(formattedTotalDistance)</desc>
            <trkseg>
        """

        for point in trailPoints {
            gpx += """

              <trkpt lat="\(point.coordinate.latitude)" lon="\(point.coordinate.longitude)">
                <ele>\(point.altitude)</ele>
                <time>\(dateFormatter.string(from: point.timestamp))</time>
              </trkpt>
            """
        }

        gpx += """

            </trkseg>
          </trk>
        </gpx>
        """

        return gpx
    }

    /// Export trail as KML format
    func exportToKML() -> String {
        let dateFormatter = ISO8601DateFormatter()

        var kml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <kml xmlns="http://www.opengis.net/kml/2.2">
          <Document>
            <name>Breadcrumb Trail</name>
            <description>Recorded on \(dateFormatter.string(from: Date()))
        Distance: \(formattedTotalDistance)
        Points: \(trailPoints.count)</description>
            <Style id="breadcrumbStyle">
              <LineStyle>
                <color>\(hexToKMLColor(configuration.teamColor))</color>
                <width>\(configuration.lineWidth)</width>
              </LineStyle>
            </Style>
            <Placemark>
              <name>Breadcrumb Trail</name>
              <styleUrl>#breadcrumbStyle</styleUrl>
              <LineString>
                <altitudeMode>absolute</altitudeMode>
                <coordinates>
        """

        for point in trailPoints {
            kml += "\(point.coordinate.longitude),\(point.coordinate.latitude),\(point.altitude)\n"
        }

        kml += """
                </coordinates>
              </LineString>
            </Placemark>
          </Document>
        </kml>
        """

        return kml
    }

    private func hexToKMLColor(_ hex: String) -> String {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))

        guard cleanHex.count == 6 else {
            return "FF00FF00" // Default to green
        }

        let r = String(cleanHex.prefix(2))
        let g = String(cleanHex.dropFirst(2).prefix(2))
        let b = String(cleanHex.dropFirst(4).prefix(2))

        // KML format is AABBGGRR (alpha, blue, green, red)
        return "FF\(b)\(g)\(r)"
    }

    /// Get file URL for GPX export
    func getGPXFileURL() -> URL? {
        let fileName = "BreadcrumbTrail_\(Date().timeIntervalSince1970)"
        let gpxContent = exportToGPX()

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName).gpx")

        do {
            try gpxContent.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Failed to create GPX file: \(error)")
            return nil
        }
    }

    /// Get file URL for KML export
    func getKMLFileURL() -> URL? {
        let fileName = "BreadcrumbTrail_\(Date().timeIntervalSince1970)"
        let kmlContent = exportToKML()

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName).kml")

        do {
            try kmlContent.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Failed to create KML file: \(error)")
            return nil
        }
    }

    // MARK: - Formatted Properties

    var formattedTotalDistance: String {
        if totalDistance < 1000 {
            return String(format: "%.1f m", totalDistance)
        } else {
            return String(format: "%.2f km", totalDistance / 1000.0)
        }
    }

    var formattedRecordingDuration: String {
        let hours = Int(recordingDuration) / 3600
        let minutes = (Int(recordingDuration) % 3600) / 60
        let seconds = Int(recordingDuration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    // MARK: - Trail Data Access

    /// Get trail coordinates for MapKit overlay
    var trailCoordinates: [CLLocationCoordinate2D] {
        return trailPoints.map { $0.coordinate }
    }

    /// Get timestamps for time-based fading
    var trailTimestamps: [Date] {
        return trailPoints.map { $0.timestamp }
    }

    /// Get the oldest point age in seconds
    var oldestPointAge: TimeInterval {
        guard let oldestPoint = trailPoints.first else { return 0 }
        return Date().timeIntervalSince(oldestPoint.timestamp)
    }

    /// Get the newest point age in seconds
    var newestPointAge: TimeInterval {
        guard let newestPoint = trailPoints.last else { return 0 }
        return Date().timeIntervalSince(newestPoint.timestamp)
    }

    deinit {
        stopRecording()
        cancellables.removeAll()
    }
}

// MARK: - CLLocationManagerDelegate

extension BreadcrumbTrailService: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Breadcrumb trail location manager error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location authorization granted for breadcrumb trail")
        case .denied, .restricted:
            print("Location authorization denied - breadcrumb trail will not work")
        case .notDetermined:
            print("Location authorization not determined")
        @unknown default:
            break
        }
    }
}
