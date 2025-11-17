//
//  TrackModels.swift
//  OmniTAKMobile
//
//  Data models for GPS track recording and breadcrumb trails
//

import Foundation
import CoreLocation
import SwiftUI

// MARK: - Track Point

/// A single GPS point in a track
struct TrackPoint: Codable, Identifiable, Equatable {
    let id: UUID
    var latitude: Double
    var longitude: Double
    var altitude: Double
    var timestamp: Date
    var speed: Double // meters per second
    var course: Double // degrees (0-360)
    var horizontalAccuracy: Double // meters

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        altitude: Double,
        timestamp: Date = Date(),
        speed: Double = 0,
        course: Double = 0,
        horizontalAccuracy: Double = 0
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
        self.speed = speed
        self.course = course
        self.horizontalAccuracy = horizontalAccuracy
    }

    /// Create TrackPoint from CLLocation
    init(from location: CLLocation) {
        self.id = UUID()
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.timestamp = location.timestamp
        self.speed = location.speed >= 0 ? location.speed : 0
        self.course = location.course >= 0 ? location.course : 0
        self.horizontalAccuracy = location.horizontalAccuracy
    }

    /// Get CLLocationCoordinate2D
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Get CLLocation for distance calculations
    var clLocation: CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: 0,
            course: course,
            speed: speed,
            timestamp: timestamp
        )
    }
}

// MARK: - Track

/// A recorded GPS track consisting of multiple track points
struct Track: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var startTime: Date
    var endTime: Date?
    var points: [TrackPoint]
    var isRecording: Bool
    var color: String // Hex color for display (e.g., "#FF0000")
    var notes: String?

    init(
        id: UUID = UUID(),
        name: String = "",
        startTime: Date = Date(),
        endTime: Date? = nil,
        points: [TrackPoint] = [],
        isRecording: Bool = false,
        color: String = "#FF0000",
        notes: String? = nil
    ) {
        self.id = id
        self.name = name.isEmpty ? "Track \(Track.dateFormatter.string(from: startTime))" : name
        self.startTime = startTime
        self.endTime = endTime
        self.points = points
        self.isRecording = isRecording
        self.color = color
        self.notes = notes
    }

    // MARK: - Static Properties

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    // MARK: - Statistics

    /// Total distance in meters
    var totalDistance: Double {
        guard points.count > 1 else { return 0 }

        var distance: Double = 0
        for i in 1..<points.count {
            let loc1 = points[i-1].clLocation
            let loc2 = points[i].clLocation
            distance += loc1.distance(from: loc2)
        }
        return distance
    }

    /// Total duration in seconds
    var duration: TimeInterval {
        guard let firstPoint = points.first else { return 0 }
        let lastTime = endTime ?? points.last?.timestamp ?? startTime
        return lastTime.timeIntervalSince(firstPoint.timestamp)
    }

    /// Average speed in meters per second
    var averageSpeed: Double {
        guard duration > 0 else { return 0 }
        return totalDistance / duration
    }

    /// Maximum speed in meters per second
    var maxSpeed: Double {
        points.map { $0.speed }.max() ?? 0
    }

    /// Minimum altitude in meters
    var minAltitude: Double {
        points.map { $0.altitude }.min() ?? 0
    }

    /// Maximum altitude in meters
    var maxAltitude: Double {
        points.map { $0.altitude }.max() ?? 0
    }

    /// Elevation gain in meters (total positive altitude change)
    var elevationGain: Double {
        guard points.count > 1 else { return 0 }

        var gain: Double = 0
        for i in 1..<points.count {
            let diff = points[i].altitude - points[i-1].altitude
            if diff > 0 {
                gain += diff
            }
        }
        return gain
    }

    /// Elevation loss in meters (total negative altitude change)
    var elevationLoss: Double {
        guard points.count > 1 else { return 0 }

        var loss: Double = 0
        for i in 1..<points.count {
            let diff = points[i].altitude - points[i-1].altitude
            if diff < 0 {
                loss += abs(diff)
            }
        }
        return loss
    }

    /// Average horizontal accuracy
    var averageAccuracy: Double {
        guard !points.isEmpty else { return 0 }
        return points.map { $0.horizontalAccuracy }.reduce(0, +) / Double(points.count)
    }

    // MARK: - Formatted Statistics

    var formattedDistance: String {
        totalDistance.formattedDistance
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    var formattedAverageSpeed: String {
        let kmh = averageSpeed * 3.6
        return String(format: "%.1f km/h", kmh)
    }

    var formattedMaxSpeed: String {
        let kmh = maxSpeed * 3.6
        return String(format: "%.1f km/h", kmh)
    }

    var formattedElevationGain: String {
        String(format: "+%.0f m", elevationGain)
    }

    var formattedElevationLoss: String {
        String(format: "-%.0f m", elevationLoss)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }

    // MARK: - Helpers

    /// Add a point to the track
    mutating func addPoint(_ point: TrackPoint) {
        points.append(point)
    }

    /// Add a CLLocation to the track
    mutating func addLocation(_ location: CLLocation) {
        let point = TrackPoint(from: location)
        points.append(point)
    }

    /// Get SwiftUI color from hex string
    var swiftUIColor: Color {
        Color(hex: color)
    }

    /// Get UIColor from hex string
    var uiColor: UIColor {
        UIColor(Color(hex: color))
    }

    /// Get the bounding region for the track
    var boundingRegion: MKCoordinateRegion? {
        guard !points.isEmpty else { return nil }

        var minLat = points[0].latitude
        var maxLat = points[0].latitude
        var minLon = points[0].longitude
        var maxLon = points[0].longitude

        for point in points {
            minLat = min(minLat, point.latitude)
            maxLat = max(maxLat, point.latitude)
            minLon = min(minLon, point.longitude)
            maxLon = max(maxLon, point.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.2,
            longitudeDelta: (maxLon - minLon) * 1.2
        )

        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - Track Statistics

/// Summary statistics for a track
struct TrackStatistics {
    let distance: Double // meters
    let duration: TimeInterval // seconds
    let averageSpeed: Double // m/s
    let maxSpeed: Double // m/s
    let elevationGain: Double // meters
    let elevationLoss: Double // meters
    let pointCount: Int
    let averageAccuracy: Double // meters

    init(from track: Track) {
        self.distance = track.totalDistance
        self.duration = track.duration
        self.averageSpeed = track.averageSpeed
        self.maxSpeed = track.maxSpeed
        self.elevationGain = track.elevationGain
        self.elevationLoss = track.elevationLoss
        self.pointCount = track.points.count
        self.averageAccuracy = track.averageAccuracy
    }
}

// MARK: - Track Recording Configuration

/// Configuration for track recording behavior
struct TrackRecordingConfiguration {
    /// Minimum distance in meters between recorded points
    var minimumDistanceThreshold: Double = 5.0

    /// Minimum time interval in seconds between recorded points
    var minimumTimeInterval: TimeInterval = 1.0

    /// Maximum time interval - force record after this time even if not moved
    var maximumTimeInterval: TimeInterval = 60.0

    /// Location accuracy mode
    var accuracyMode: AccuracyMode = .best

    /// Whether to allow background location updates
    var allowBackgroundUpdates: Bool = true

    /// Whether to pause updates automatically when stationary
    var pausesLocationUpdatesAutomatically: Bool = false

    /// Default track color
    var defaultTrackColor: String = "#FF0000"

    enum AccuracyMode {
        case best // kCLLocationAccuracyBest
        case tenMeters // kCLLocationAccuracyNearestTenMeters
        case hundredMeters // kCLLocationAccuracyHundredMeters
        case navigation // kCLLocationAccuracyBestForNavigation

        var clAccuracy: CLLocationAccuracy {
            switch self {
            case .best:
                return kCLLocationAccuracyBest
            case .tenMeters:
                return kCLLocationAccuracyNearestTenMeters
            case .hundredMeters:
                return kCLLocationAccuracyHundredMeters
            case .navigation:
                return kCLLocationAccuracyBestForNavigation
            }
        }

        var displayName: String {
            switch self {
            case .best: return "Best Accuracy"
            case .tenMeters: return "10m Accuracy"
            case .hundredMeters: return "100m Accuracy"
            case .navigation: return "Navigation Mode"
            }
        }
    }
}

// MARK: - Track Color Presets

enum TrackColorPreset: String, CaseIterable {
    case red = "#FF0000"
    case green = "#00FF00"
    case blue = "#0000FF"
    case yellow = "#FFFF00"
    case orange = "#FF8800"
    case purple = "#8800FF"
    case cyan = "#00FFFF"
    case magenta = "#FF00FF"
    case lime = "#88FF00"
    case pink = "#FF88FF"

    var displayName: String {
        switch self {
        case .red: return "Red"
        case .green: return "Green"
        case .blue: return "Blue"
        case .yellow: return "Yellow"
        case .orange: return "Orange"
        case .purple: return "Purple"
        case .cyan: return "Cyan"
        case .magenta: return "Magenta"
        case .lime: return "Lime"
        case .pink: return "Pink"
        }
    }

    var swiftUIColor: Color {
        Color(hex: rawValue)
    }
}

// MARK: - Import from MapKit

import MapKit
