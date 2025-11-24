//
//  TrackRecordingService.swift
//  OmniTAKMobile
//
//  Service for recording GPS tracks/breadcrumb trails
//

import Foundation
import CoreLocation
import Combine
import MapKit

// MARK: - Track Recording Service

/// Service for recording GPS breadcrumb trails
class TrackRecordingService: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentTrack: Track?
    @Published var savedTracks: [Track] = []
    @Published var currentLocation: CLLocation?
    @Published var recordingStartTime: Date?
    @Published var elapsedTime: TimeInterval = 0

    // Live statistics
    @Published var liveDistance: Double = 0
    @Published var liveSpeed: Double = 0
    @Published var liveAverageSpeed: Double = 0
    @Published var livePointCount: Int = 0
    @Published var liveElevationGain: Double = 0

    // MARK: - Private Properties

    private let locationManager = CLLocationManager()
    private var configuration = TrackRecordingConfiguration()
    private var lastRecordedLocation: CLLocation?
    private var lastRecordedTime: Date?
    private var elapsedTimer: Timer?

    // File management
    private let fileManager = FileManager.default
    private var tracksDirectoryURL: URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent("Tracks", isDirectory: true)
    }

    // Singleton
    static let shared = TrackRecordingService()

    // MARK: - Initialization

    override init() {
        super.init()
        setupLocationManager()
        createTracksDirectory()
        loadSavedTracks()
    }

    // MARK: - Setup

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = configuration.accuracyMode.clAccuracy
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.allowsBackgroundLocationUpdates = configuration.allowBackgroundUpdates
        locationManager.pausesLocationUpdatesAutomatically = configuration.pausesLocationUpdatesAutomatically

        // Request authorization
        locationManager.requestWhenInUseAuthorization()
    }

    private func createTracksDirectory() {
        if !fileManager.fileExists(atPath: tracksDirectoryURL.path) {
            do {
                try fileManager.createDirectory(at: tracksDirectoryURL, withIntermediateDirectories: true)
                print("Created tracks directory at: \(tracksDirectoryURL.path)")
            } catch {
                print("Failed to create tracks directory: \(error)")
            }
        }
    }

    // MARK: - Configuration

    func updateConfiguration(_ config: TrackRecordingConfiguration) {
        configuration = config
        locationManager.desiredAccuracy = config.accuracyMode.clAccuracy
        locationManager.allowsBackgroundLocationUpdates = config.allowBackgroundUpdates
        locationManager.pausesLocationUpdatesAutomatically = config.pausesLocationUpdatesAutomatically
    }

    func setAccuracyMode(_ mode: TrackRecordingConfiguration.AccuracyMode) {
        configuration.accuracyMode = mode
        locationManager.desiredAccuracy = mode.clAccuracy
    }

    func setMinimumDistanceThreshold(_ meters: Double) {
        configuration.minimumDistanceThreshold = meters
    }

    // MARK: - Recording Control

    /// Start recording a new track
    func startRecording(name: String = "", color: String? = nil) {
        guard !isRecording else {
            print("Already recording")
            return
        }

        let trackName = name.isEmpty ? "Track \(Date().formatted(date: .numeric, time: .shortened))" : name
        let trackColor = color ?? configuration.defaultTrackColor

        currentTrack = Track(
            name: trackName,
            startTime: Date(),
            isRecording: true,
            color: trackColor
        )

        isRecording = true
        isPaused = false
        recordingStartTime = Date()
        lastRecordedLocation = nil
        lastRecordedTime = nil

        // Reset live stats
        liveDistance = 0
        liveSpeed = 0
        liveAverageSpeed = 0
        livePointCount = 0
        liveElevationGain = 0
        elapsedTime = 0

        // Start location updates
        locationManager.startUpdatingLocation()

        // Start elapsed time timer
        startElapsedTimer()

        print("Started recording track: \(trackName)")
    }

    /// Stop recording and save the track
    func stopRecording() -> Track? {
        guard isRecording, var track = currentTrack else {
            print("Not recording")
            return nil
        }

        // Finalize the track
        track.endTime = Date()
        track.isRecording = false
        currentTrack = track

        isRecording = false
        isPaused = false

        // Stop location updates
        locationManager.stopUpdatingLocation()

        // Stop elapsed timer
        stopElapsedTimer()

        // Save the track
        let savedTrack = track
        saveTrack(savedTrack)

        // Add to saved tracks list
        savedTracks.insert(savedTrack, at: 0)

        // Reset current track
        currentTrack = nil
        recordingStartTime = nil

        print("Stopped recording. Track has \(savedTrack.points.count) points, distance: \(savedTrack.formattedDistance)")

        return savedTrack
    }

    /// Pause recording
    func pauseRecording() {
        guard isRecording, !isPaused else { return }

        isPaused = true
        locationManager.stopUpdatingLocation()
        stopElapsedTimer()

        print("Paused recording")
    }

    /// Resume recording
    func resumeRecording() {
        guard isRecording, isPaused else { return }

        isPaused = false
        locationManager.startUpdatingLocation()
        startElapsedTimer()

        print("Resumed recording")
    }

    /// Discard the current recording without saving
    func discardRecording() {
        guard isRecording else { return }

        isRecording = false
        isPaused = false
        currentTrack = nil
        recordingStartTime = nil

        locationManager.stopUpdatingLocation()
        stopElapsedTimer()

        // Reset live stats
        liveDistance = 0
        liveSpeed = 0
        liveAverageSpeed = 0
        livePointCount = 0
        liveElevationGain = 0
        elapsedTime = 0

        print("Discarded current recording")
    }

    // MARK: - Timer Management

    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            self.elapsedTime = Date().timeIntervalSince(startTime)
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    // MARK: - Track Persistence

    /// Save a track to disk
    func saveTrack(_ track: Track) {
        let fileURL = tracksDirectoryURL.appendingPathComponent("\(track.id.uuidString).json")

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(track)
            try data.write(to: fileURL)
            print("Saved track to: \(fileURL.path)")
        } catch {
            print("Failed to save track: \(error)")
        }
    }

    /// Load all saved tracks from disk
    func loadSavedTracks() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: tracksDirectoryURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )

            let jsonFiles = fileURLs.filter { $0.pathExtension == "json" }

            var tracks: [Track] = []

            for fileURL in jsonFiles {
                if let track = loadTrack(from: fileURL) {
                    tracks.append(track)
                }
            }

            // Sort by start time (newest first)
            tracks.sort { $0.startTime > $1.startTime }
            savedTracks = tracks

            print("Loaded \(tracks.count) saved tracks")
        } catch {
            print("Failed to load saved tracks: \(error)")
        }
    }

    /// Load a single track from a file URL
    private func loadTrack(from url: URL) -> Track? {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let track = try decoder.decode(Track.self, from: data)
            return track
        } catch {
            print("Failed to load track from \(url.path): \(error)")
            return nil
        }
    }

    /// Delete a track from disk
    func deleteTrack(_ track: Track) {
        let fileURL = tracksDirectoryURL.appendingPathComponent("\(track.id.uuidString).json")

        do {
            try fileManager.removeItem(at: fileURL)
            savedTracks.removeAll { $0.id == track.id }
            print("Deleted track: \(track.name)")
        } catch {
            print("Failed to delete track: \(error)")
        }
    }

    /// Rename a track
    func renameTrack(_ track: Track, newName: String) {
        guard let index = savedTracks.firstIndex(where: { $0.id == track.id }) else { return }

        var updatedTrack = track
        updatedTrack.name = newName
        savedTracks[index] = updatedTrack

        saveTrack(updatedTrack)
    }

    /// Update track notes
    func updateTrackNotes(_ track: Track, notes: String?) {
        guard let index = savedTracks.firstIndex(where: { $0.id == track.id }) else { return }

        var updatedTrack = track
        updatedTrack.notes = notes
        savedTracks[index] = updatedTrack

        saveTrack(updatedTrack)
    }

    // MARK: - Export Functions

    /// Export track as GPX format
    func exportToGPX(_ track: Track) -> String {
        return GPXExporter.export(track: track)
    }

    /// Export track as KML format
    func exportToKML(_ track: Track) -> String {
        return KMLExporter.export(track: track)
    }

    /// Get file URL for GPX export
    func getGPXFileURL(for track: Track) -> URL? {
        let fileName = track.name.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ":", with: "-")
        let gpxContent = exportToGPX(track)

        let tempURL = fileManager.temporaryDirectory.appendingPathComponent("\(fileName).gpx")

        do {
            try gpxContent.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Failed to create GPX file: \(error)")
            return nil
        }
    }

    /// Get file URL for KML export
    func getKMLFileURL(for track: Track) -> URL? {
        let fileName = track.name.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ":", with: "-")
        let kmlContent = exportToKML(track)

        let tempURL = fileManager.temporaryDirectory.appendingPathComponent("\(fileName).kml")

        do {
            try kmlContent.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("Failed to create KML file: \(error)")
            return nil
        }
    }

    // MARK: - Point Recording Logic

    private func shouldRecordPoint(newLocation: CLLocation) -> Bool {
        // Always record the first point
        guard let lastLocation = lastRecordedLocation,
              let lastTime = lastRecordedTime else {
            return true
        }

        // Check time constraints
        let timeSinceLastRecord = newLocation.timestamp.timeIntervalSince(lastTime)

        // Force record if maximum time interval exceeded
        if timeSinceLastRecord >= configuration.maximumTimeInterval {
            return true
        }

        // Don't record if minimum time interval not reached
        if timeSinceLastRecord < configuration.minimumTimeInterval {
            return false
        }

        // Check distance constraint
        let distance = newLocation.distance(from: lastLocation)
        return distance >= configuration.minimumDistanceThreshold
    }

    private func updateLiveStatistics() {
        guard let track = currentTrack else { return }

        liveDistance = track.totalDistance
        livePointCount = track.points.count
        liveElevationGain = track.elevationGain

        if let location = currentLocation {
            liveSpeed = location.speed >= 0 ? location.speed : 0
        }

        if elapsedTime > 0 {
            liveAverageSpeed = liveDistance / elapsedTime
        }
    }

    // MARK: - Formatted Statistics

    var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var formattedLiveDistance: String {
        liveDistance.formattedDistance
    }

    var formattedLiveSpeed: String {
        let kmh = liveSpeed * 3.6
        return String(format: "%.1f km/h", kmh)
    }

    var formattedLiveAverageSpeed: String {
        let kmh = liveAverageSpeed * 3.6
        return String(format: "%.1f km/h", kmh)
    }
}

// MARK: - CLLocationManagerDelegate

extension TrackRecordingService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Update current location
        currentLocation = location

        // If recording and not paused, check if we should add this point
        guard isRecording, !isPaused, var track = currentTrack else { return }

        if shouldRecordPoint(newLocation: location) {
            let trackPoint = TrackPoint(from: location)
            track.addPoint(trackPoint)
            currentTrack = track

            lastRecordedLocation = location
            lastRecordedTime = location.timestamp

            // Update live statistics
            updateLiveStatistics()

            print("Recorded point #\(track.points.count): (\(location.coordinate.latitude), \(location.coordinate.longitude))")
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("Location authorization granted for track recording")
        case .denied, .restricted:
            print("Location authorization denied - track recording will not work")
        case .notDetermined:
            print("Location authorization not determined")
        @unknown default:
            break
        }
    }
}

// MARK: - GPX Exporter

struct GPXExporter {
    static func export(track: Track) -> String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="OmniTAK iOS"
             xmlns="http://www.topografix.com/GPX/1/1"
             xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
             xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">
          <metadata>
            <name>\(escapeXML(track.name))</name>
            <time>\(dateFormatter.string(from: track.startTime))</time>
          </metadata>
          <trk>
            <name>\(escapeXML(track.name))</name>
        """

        if let notes = track.notes {
            gpx += """

            <desc>\(escapeXML(notes))</desc>
        """
        }

        gpx += """

            <trkseg>
        """

        for point in track.points {
            gpx += """

              <trkpt lat="\(point.latitude)" lon="\(point.longitude)">
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

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

// MARK: - KML Exporter

struct KMLExporter {
    static func export(track: Track) -> String {
        let dateFormatter = ISO8601DateFormatter()

        var kml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <kml xmlns="http://www.opengis.net/kml/2.2">
          <Document>
            <name>\(escapeXML(track.name))</name>
            <description>Recorded on \(dateFormatter.string(from: track.startTime))
        Distance: \(track.formattedDistance)
        Duration: \(track.formattedDuration)
        Average Speed: \(track.formattedAverageSpeed)</description>
            <Style id="trackStyle">
              <LineStyle>
                <color>\(hexToKMLColor(track.color))</color>
                <width>4</width>
              </LineStyle>
            </Style>
            <Placemark>
              <name>\(escapeXML(track.name))</name>
              <styleUrl>#trackStyle</styleUrl>
              <LineString>
                <altitudeMode>absolute</altitudeMode>
                <coordinates>
        """

        for point in track.points {
            kml += "\(point.longitude),\(point.latitude),\(point.altitude)\n"
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

    /// Convert hex color (#RRGGBB) to KML color format (AABBGGRR)
    private static func hexToKMLColor(_ hex: String) -> String {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))

        guard cleanHex.count == 6 else {
            return "FF0000FF" // Default to red
        }

        let r = String(cleanHex.prefix(2))
        let g = String(cleanHex.dropFirst(2).prefix(2))
        let b = String(cleanHex.dropFirst(4).prefix(2))

        // KML format is AABBGGRR (alpha, blue, green, red)
        return "FF\(b)\(g)\(r)"
    }

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
