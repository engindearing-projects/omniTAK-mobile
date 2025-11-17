//
//  BloodhoundService.swift
//  OmniTAKMobile
//
//  Blue Force Tracking (BFT) visualization service
//  Tracks all friendly force positions, calculates movement vectors,
//  detects stale tracks, and maintains situational awareness
//

import Foundation
import Combine
import CoreLocation
import SwiftUI

// MARK: - Track Data Models

struct BloodhoundTrack: Identifiable, Codable {
    let id: UUID
    let uid: String
    var callsign: String
    var team: String?
    var positions: [TrackPosition]
    var lastUpdate: Date
    var alertFlags: TrackAlertFlags

    // Computed properties
    var isOnline: Bool {
        Date().timeIntervalSince(lastUpdate) < 300 // 5 minutes
    }

    var isStale: Bool {
        Date().timeIntervalSince(lastUpdate) >= 900 // 15 minutes
    }

    var currentPosition: TrackPosition? {
        positions.last
    }

    var ageInSeconds: TimeInterval {
        Date().timeIntervalSince(lastUpdate)
    }

    var formattedAge: String {
        let age = ageInSeconds
        if age < 60 {
            return String(format: "%.0fs", age)
        } else if age < 3600 {
            return String(format: "%.0fm", age / 60)
        } else {
            return String(format: "%.1fh", age / 3600)
        }
    }

    // Movement calculations
    var currentSpeed: Double? {
        guard positions.count >= 2 else { return nil }
        let last = positions[positions.count - 1]
        let prev = positions[positions.count - 2]
        return last.speed ?? calculateSpeed(from: prev, to: last)
    }

    var currentHeading: Double? {
        guard positions.count >= 2 else { return nil }
        let last = positions[positions.count - 1]
        let prev = positions[positions.count - 2]
        return last.course ?? calculateBearing(from: prev.coordinate, to: last.coordinate)
    }

    var averageSpeed: Double {
        guard positions.count >= 2 else { return 0 }

        var totalSpeed = 0.0
        var count = 0

        for i in 1..<positions.count {
            let speed = positions[i].speed ?? calculateSpeed(from: positions[i-1], to: positions[i])
            totalSpeed += speed
            count += 1
        }

        return count > 0 ? totalSpeed / Double(count) : 0
    }

    private func calculateSpeed(from: TrackPosition, to: TrackPosition) -> Double {
        let loc1 = CLLocation(latitude: from.coordinate.latitude, longitude: from.coordinate.longitude)
        let loc2 = CLLocation(latitude: to.coordinate.latitude, longitude: to.coordinate.longitude)
        let distance = loc2.distance(from: loc1)
        let time = to.timestamp.timeIntervalSince(from.timestamp)
        return time > 0 ? distance / time : 0
    }

    private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radiansBearing = atan2(y, x)
        let degreesBearing = radiansBearing * 180 / .pi

        return (degreesBearing + 360).truncatingRemainder(dividingBy: 360)
    }

    // Predict future position
    func predictPosition(secondsAhead: TimeInterval) -> CLLocationCoordinate2D? {
        guard let current = currentPosition,
              let speed = currentSpeed,
              let heading = currentHeading,
              speed > 0 else {
            return currentPosition?.coordinate
        }

        let distance = speed * secondsAhead
        let headingRad = heading * .pi / 180

        // Simple projection (Earth radius ~ 6371 km)
        let earthRadius = 6371000.0
        let lat1 = current.coordinate.latitude * .pi / 180
        let lon1 = current.coordinate.longitude * .pi / 180

        let lat2 = asin(sin(lat1) * cos(distance / earthRadius) +
                        cos(lat1) * sin(distance / earthRadius) * cos(headingRad))
        let lon2 = lon1 + atan2(sin(headingRad) * sin(distance / earthRadius) * cos(lat1),
                                cos(distance / earthRadius) - sin(lat1) * sin(lat2))

        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }
}

struct TrackPosition: Identifiable, Codable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let altitude: Double
    let timestamp: Date
    let speed: Double?
    let course: Double?

    init(coordinate: CLLocationCoordinate2D, altitude: Double, timestamp: Date, speed: Double?, course: Double?) {
        self.id = UUID()
        self.coordinate = coordinate
        self.altitude = altitude
        self.timestamp = timestamp
        self.speed = speed
        self.course = course
    }
}

struct TrackAlertFlags: OptionSet, Codable {
    let rawValue: Int

    static let rapidMovement = TrackAlertFlags(rawValue: 1 << 0)
    static let positionJump = TrackAlertFlags(rawValue: 1 << 1)
    static let staleTrack = TrackAlertFlags(rawValue: 1 << 2)
    static let highSpeed = TrackAlertFlags(rawValue: 1 << 3)
    static let altitudeChange = TrackAlertFlags(rawValue: 1 << 4)
}

// MARK: - CLLocationCoordinate2D Codable Extension

extension CLLocationCoordinate2D: Codable {
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
}

// MARK: - Statistics

struct BloodhoundStatistics {
    var totalTracked: Int = 0
    var onlineCount: Int = 0
    var staleCount: Int = 0
    var movingCount: Int = 0
    var stationaryCount: Int = 0
    var averageNetworkSpeed: Double = 0
    var maxSpeed: Double = 0
    var alertCount: Int = 0

    var offlineCount: Int {
        totalTracked - onlineCount
    }
}

// MARK: - Bloodhound Service

class BloodhoundService: ObservableObject {
    static let shared = BloodhoundService()

    // Published properties
    @Published var tracks: [String: BloodhoundTrack] = [:]
    @Published var statistics: BloodhoundStatistics = BloodhoundStatistics()
    @Published var recentAlerts: [TrackAlert] = []
    @Published var lastUpdateTime: Date = Date()

    // Configuration
    var maxHistoryLength: Int = 200
    var staleThreshold: TimeInterval = 900 // 15 minutes
    var rapidMovementThreshold: Double = 20.0 // m/s
    var positionJumpThreshold: Double = 500.0 // meters
    var highSpeedThreshold: Double = 30.0 // m/s

    // Private
    private var cancellables = Set<AnyCancellable>()
    private var cleanupTimer: Timer?
    private var persistenceURL: URL?

    // MARK: - Initialization

    init() {
        setupPersistence()
        loadPersistedTracks()
        startCleanupTimer()
    }

    deinit {
        cleanupTimer?.invalidate()
    }

    // MARK: - TAKService Integration

    /// Observe TAKService cotEvents and update tracks
    func observeTAKService(_ takService: TAKService) {
        // Subscribe to cotEvents changes
        takService.$cotEvents
            .sink { [weak self] events in
                self?.processCotEvents(events)
            }
            .store(in: &cancellables)

        // Also observe enhanced markers
        takService.$enhancedMarkers
            .sink { [weak self] markers in
                self?.processEnhancedMarkers(markers)
            }
            .store(in: &cancellables)
    }

    private func processCotEvents(_ events: [CoTEvent]) {
        for event in events {
            // Only track friendly forces (a-f-*)
            guard event.type.hasPrefix("a-f-") else { continue }
            updateTrack(from: event)
        }
        updateStatistics()
        persistTracks()
    }

    private func processEnhancedMarkers(_ markers: [String: EnhancedCoTMarker]) {
        for (uid, marker) in markers {
            // Only track friendly forces
            guard marker.affiliation == .friendly || marker.affiliation == .assumedFriend else {
                continue
            }
            updateTrack(from: marker)
        }
        updateStatistics()
        persistTracks()
    }

    // MARK: - Track Management

    func updateTrack(from event: CoTEvent) {
        let uid = event.uid
        let newPosition = TrackPosition(
            coordinate: CLLocationCoordinate2D(latitude: event.point.lat, longitude: event.point.lon),
            altitude: event.point.hae,
            timestamp: event.time,
            speed: event.detail.speed,
            course: event.detail.course
        )

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if var existingTrack = self.tracks[uid] {
                // Check for alerts before adding new position
                let alerts = self.checkForAlerts(track: existingTrack, newPosition: newPosition)

                // Update track
                existingTrack.callsign = event.detail.callsign
                existingTrack.team = event.detail.team
                existingTrack.positions.append(newPosition)
                existingTrack.lastUpdate = event.time
                existingTrack.alertFlags = alerts

                // Trim history
                if existingTrack.positions.count > self.maxHistoryLength {
                    existingTrack.positions = Array(existingTrack.positions.suffix(self.maxHistoryLength))
                }

                self.tracks[uid] = existingTrack
            } else {
                // Create new track
                let newTrack = BloodhoundTrack(
                    id: UUID(),
                    uid: uid,
                    callsign: event.detail.callsign,
                    team: event.detail.team,
                    positions: [newPosition],
                    lastUpdate: event.time,
                    alertFlags: []
                )
                self.tracks[uid] = newTrack
            }

            self.lastUpdateTime = Date()
        }
    }

    func updateTrack(from marker: EnhancedCoTMarker) {
        let uid = marker.uid

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Convert marker history to track positions
            var positions: [TrackPosition] = []
            for position in marker.positionHistory {
                let trackPos = TrackPosition(
                    coordinate: position.coordinate,
                    altitude: position.altitude,
                    timestamp: position.timestamp,
                    speed: position.speed,
                    course: position.course
                )
                positions.append(trackPos)
            }

            if var existingTrack = self.tracks[uid] {
                // Merge positions (avoid duplicates)
                for pos in positions {
                    if !existingTrack.positions.contains(where: { $0.timestamp == pos.timestamp }) {
                        existingTrack.positions.append(pos)
                    }
                }

                // Sort by timestamp
                existingTrack.positions.sort { $0.timestamp < $1.timestamp }

                // Trim history
                if existingTrack.positions.count > self.maxHistoryLength {
                    existingTrack.positions = Array(existingTrack.positions.suffix(self.maxHistoryLength))
                }

                existingTrack.callsign = marker.callsign
                existingTrack.team = marker.team
                existingTrack.lastUpdate = marker.lastUpdate

                // Check for stale status
                if existingTrack.isStale && !existingTrack.alertFlags.contains(.staleTrack) {
                    existingTrack.alertFlags.insert(.staleTrack)
                    self.addAlert(TrackAlert(
                        id: UUID(),
                        uid: uid,
                        callsign: marker.callsign,
                        type: .staleTrack,
                        timestamp: Date(),
                        message: "Track \(marker.callsign) is now stale"
                    ))
                }

                self.tracks[uid] = existingTrack
            } else {
                let newTrack = BloodhoundTrack(
                    id: UUID(),
                    uid: uid,
                    callsign: marker.callsign,
                    team: marker.team,
                    positions: positions,
                    lastUpdate: marker.lastUpdate,
                    alertFlags: []
                )
                self.tracks[uid] = newTrack
            }

            self.lastUpdateTime = Date()
        }
    }

    // MARK: - Alert Detection

    private func checkForAlerts(track: BloodhoundTrack, newPosition: TrackPosition) -> TrackAlertFlags {
        var flags: TrackAlertFlags = []

        guard let lastPosition = track.currentPosition else {
            return flags
        }

        // Check for position jump
        let loc1 = CLLocation(latitude: lastPosition.coordinate.latitude, longitude: lastPosition.coordinate.longitude)
        let loc2 = CLLocation(latitude: newPosition.coordinate.latitude, longitude: newPosition.coordinate.longitude)
        let distance = loc2.distance(from: loc1)
        let timeDiff = newPosition.timestamp.timeIntervalSince(lastPosition.timestamp)

        if distance > positionJumpThreshold && timeDiff < 60 {
            flags.insert(.positionJump)
            addAlert(TrackAlert(
                id: UUID(),
                uid: track.uid,
                callsign: track.callsign,
                type: .positionJump,
                timestamp: Date(),
                message: "Position jump detected: \(String(format: "%.0fm", distance)) in \(String(format: "%.0fs", timeDiff))"
            ))
        }

        // Check for rapid movement
        if let speed = newPosition.speed, speed > rapidMovementThreshold {
            flags.insert(.rapidMovement)
        }

        // Check for high speed
        if let speed = newPosition.speed, speed > highSpeedThreshold {
            flags.insert(.highSpeed)
            addAlert(TrackAlert(
                id: UUID(),
                uid: track.uid,
                callsign: track.callsign,
                type: .highSpeed,
                timestamp: Date(),
                message: "High speed alert: \(String(format: "%.1f m/s (%.1f km/h)", speed, speed * 3.6))"
            ))
        }

        // Check for significant altitude change
        let altitudeDiff = abs(newPosition.altitude - lastPosition.altitude)
        if altitudeDiff > 50 && timeDiff < 60 {
            flags.insert(.altitudeChange)
        }

        return flags
    }

    private func addAlert(_ alert: TrackAlert) {
        DispatchQueue.main.async { [weak self] in
            self?.recentAlerts.insert(alert, at: 0)

            // Keep only recent alerts (last 50)
            if (self?.recentAlerts.count ?? 0) > 50 {
                self?.recentAlerts = Array(self?.recentAlerts.prefix(50) ?? [])
            }
        }
    }

    // MARK: - Statistics

    func updateStatistics() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            var stats = BloodhoundStatistics()
            stats.totalTracked = self.tracks.count

            var totalSpeed = 0.0
            var speedCount = 0
            var maxSpeed = 0.0

            for track in self.tracks.values {
                if track.isOnline {
                    stats.onlineCount += 1
                }

                if track.isStale {
                    stats.staleCount += 1
                }

                if let speed = track.currentSpeed, speed > 0.5 {
                    stats.movingCount += 1
                    totalSpeed += speed
                    speedCount += 1
                    maxSpeed = max(maxSpeed, speed)
                } else {
                    stats.stationaryCount += 1
                }

                if !track.alertFlags.isEmpty {
                    stats.alertCount += 1
                }
            }

            stats.averageNetworkSpeed = speedCount > 0 ? totalSpeed / Double(speedCount) : 0
            stats.maxSpeed = maxSpeed

            self.statistics = stats
        }
    }

    // MARK: - Query Methods

    func getTrack(uid: String) -> BloodhoundTrack? {
        return tracks[uid]
    }

    func getAllTracks() -> [BloodhoundTrack] {
        return Array(tracks.values).sorted { $0.callsign < $1.callsign }
    }

    func getOnlineTracks() -> [BloodhoundTrack] {
        return tracks.values.filter { $0.isOnline }.sorted { $0.callsign < $1.callsign }
    }

    func getStaleTracks() -> [BloodhoundTrack] {
        return tracks.values.filter { $0.isStale }.sorted { $0.lastUpdate > $1.lastUpdate }
    }

    func getMovingTracks() -> [BloodhoundTrack] {
        return tracks.values.filter { ($0.currentSpeed ?? 0) > 0.5 }.sorted { ($0.currentSpeed ?? 0) > ($1.currentSpeed ?? 0) }
    }

    func getTracksByTeam(_ team: String) -> [BloodhoundTrack] {
        return tracks.values.filter { $0.team == team }.sorted { $0.callsign < $1.callsign }
    }

    func getAvailableTeams() -> [String] {
        var teams = Set<String>()
        for track in tracks.values {
            if let team = track.team {
                teams.insert(team)
            }
        }
        return Array(teams).sorted()
    }

    // MARK: - Cleanup

    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.performCleanup()
        }
    }

    private func performCleanup() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // Remove very old tracks (older than 24 hours)
            let cutoffTime = Date().addingTimeInterval(-86400)
            self.tracks = self.tracks.filter { _, track in
                track.lastUpdate > cutoffTime
            }

            // Check for stale tracks and add alerts
            for (uid, track) in self.tracks {
                if track.isStale && !track.alertFlags.contains(.staleTrack) {
                    var updatedTrack = track
                    updatedTrack.alertFlags.insert(.staleTrack)
                    self.tracks[uid] = updatedTrack

                    self.addAlert(TrackAlert(
                        id: UUID(),
                        uid: uid,
                        callsign: track.callsign,
                        type: .staleTrack,
                        timestamp: Date(),
                        message: "Track \(track.callsign) is now stale (\(track.formattedAge))"
                    ))
                }
            }

            self.updateStatistics()
            self.persistTracks()
        }
    }

    // MARK: - Persistence

    private func setupPersistence() {
        let fileManager = FileManager.default
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            persistenceURL = documentsURL.appendingPathComponent("bloodhound_tracks.json")
        }
    }

    private func persistTracks() {
        guard let url = persistenceURL else { return }

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(Array(self.tracks.values))
                try data.write(to: url)
                print("BloodhoundService: Persisted \(self.tracks.count) tracks")
            } catch {
                print("BloodhoundService: Failed to persist tracks: \(error)")
            }
        }
    }

    private func loadPersistedTracks() {
        guard let url = persistenceURL else { return }

        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }

            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let loadedTracks = try decoder.decode([BloodhoundTrack].self, from: data)

                DispatchQueue.main.async {
                    for track in loadedTracks {
                        self.tracks[track.uid] = track
                    }
                    self.updateStatistics()
                    print("BloodhoundService: Loaded \(loadedTracks.count) persisted tracks")
                }
            } catch {
                print("BloodhoundService: No persisted tracks found or failed to load: \(error)")
            }
        }
    }

    // MARK: - Manual Actions

    func removeTrack(uid: String) {
        DispatchQueue.main.async { [weak self] in
            self?.tracks.removeValue(forKey: uid)
            self?.updateStatistics()
            self?.persistTracks()
        }
    }

    func clearAllTracks() {
        DispatchQueue.main.async { [weak self] in
            self?.tracks.removeAll()
            self?.recentAlerts.removeAll()
            self?.updateStatistics()
            self?.persistTracks()
        }
    }

    func clearAlerts() {
        DispatchQueue.main.async { [weak self] in
            self?.recentAlerts.removeAll()
        }
    }
}

// MARK: - Track Alert

struct TrackAlert: Identifiable {
    let id: UUID
    let uid: String
    let callsign: String
    let type: TrackAlertType
    let timestamp: Date
    let message: String
}

enum TrackAlertType {
    case staleTrack
    case positionJump
    case highSpeed
    case rapidMovement
    case altitudeChange

    var icon: String {
        switch self {
        case .staleTrack:
            return "clock.badge.exclamationmark"
        case .positionJump:
            return "location.slash"
        case .highSpeed:
            return "speedometer"
        case .rapidMovement:
            return "arrow.up.right.circle"
        case .altitudeChange:
            return "arrow.up.and.down.circle"
        }
    }

    var color: Color {
        switch self {
        case .staleTrack:
            return .orange
        case .positionJump:
            return .red
        case .highSpeed:
            return .yellow
        case .rapidMovement:
            return .purple
        case .altitudeChange:
            return .blue
        }
    }

    var displayName: String {
        switch self {
        case .staleTrack:
            return "Stale Track"
        case .positionJump:
            return "Position Jump"
        case .highSpeed:
            return "High Speed"
        case .rapidMovement:
            return "Rapid Movement"
        case .altitudeChange:
            return "Altitude Change"
        }
    }
}
