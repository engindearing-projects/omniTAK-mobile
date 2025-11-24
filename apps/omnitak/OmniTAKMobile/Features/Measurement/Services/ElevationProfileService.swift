//
//  ElevationProfileService.swift
//  OmniTAKMobile
//
//  Service for calculating elevation profiles along paths
//

import Foundation
import CoreLocation
import MapKit
import Combine

// MARK: - Elevation Profile Service

class ElevationProfileService: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var currentProfile: ElevationProfile?
    @Published var savedProfiles: [ElevationProfile] = []
    @Published var isCalculating: Bool = false
    @Published var progress: Double = 0
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let persistenceKey = "saved_elevation_profiles"
    private let locationManager = CLLocationManager()

    // MARK: - Initialization

    override init() {
        super.init()
        loadSavedProfiles()
    }

    // MARK: - Profile Generation

    /// Generate elevation profile from a path of coordinates
    func generateProfile(for request: ElevationProfileRequest) async throws -> ElevationProfile {
        guard request.coordinates.count >= 2 else {
            throw ElevationProfileError.insufficientPoints
        }

        await MainActor.run {
            isCalculating = true
            progress = 0
            errorMessage = nil
        }

        defer {
            Task { @MainActor in
                isCalculating = false
                progress = 1.0
            }
        }

        // Sample points along the path
        let sampledCoordinates = samplePointsAlongPath(
            coordinates: request.coordinates,
            interval: request.samplingInterval
        )

        await MainActor.run {
            progress = 0.2
        }

        // Get elevation for each point
        var elevationPoints: [ElevationPoint] = []
        var cumulativeDistance: Double = 0

        for (index, coordinate) in sampledCoordinates.enumerated() {
            let elevation = try await getElevation(for: coordinate)

            if index > 0 {
                let previousCoordinate = sampledCoordinates[index - 1]
                let segmentDistance = calculateDistance(from: previousCoordinate, to: coordinate)
                cumulativeDistance += segmentDistance
            }

            let point = ElevationPoint(
                coordinate: coordinate,
                elevation: elevation,
                distance: cumulativeDistance
            )
            elevationPoints.append(point)

            await MainActor.run {
                self.progress = 0.2 + (Double(index) / Double(sampledCoordinates.count)) * 0.6
            }
        }

        await MainActor.run {
            progress = 0.8
        }

        // Calculate statistics
        let statistics = calculateStatistics(from: elevationPoints)

        // Calculate gradient segments
        let gradientSegments = calculateGradientSegments(from: elevationPoints)

        await MainActor.run {
            progress = 0.9
        }

        // Create profile
        let profile = ElevationProfile(
            name: request.name,
            points: elevationPoints,
            statistics: statistics,
            gradientSegments: gradientSegments,
            pathCoordinates: request.coordinates
        )

        await MainActor.run {
            self.currentProfile = profile
            progress = 1.0
        }

        return profile
    }

    /// Generate profile for a point-to-point route
    func generatePointToPointProfile(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, samplingInterval: Double = 50) async throws -> ElevationProfile {
        let request = ElevationProfileRequest(
            coordinates: [start, end],
            samplingInterval: samplingInterval,
            name: "Point to Point Profile"
        )
        return try await generateProfile(for: request)
    }

    /// Generate profile from MKRoute
    func generateRouteProfile(from route: MKRoute, samplingInterval: Double = 50) async throws -> ElevationProfile {
        let polyline = route.polyline
        var coordinates: [CLLocationCoordinate2D] = []

        let pointCount = polyline.pointCount
        let points = polyline.points()

        for i in 0..<pointCount {
            coordinates.append(points[i].coordinate)
        }

        let request = ElevationProfileRequest(
            coordinates: coordinates,
            samplingInterval: samplingInterval,
            name: route.name
        )

        return try await generateProfile(for: request)
    }

    // MARK: - Elevation Data Retrieval

    /// Get elevation for a single coordinate
    private func getElevation(for coordinate: CLLocationCoordinate2D) async throws -> Double {
        // Use CLGeocoder for elevation data (limited but available)
        // In a production app, you might use a dedicated elevation API like:
        // - Apple Maps elevation (when available)
        // - Open-Elevation API
        // - Google Elevation API
        // - USGS Elevation Point Query Service

        // For now, use a simulation based on coordinate with realistic terrain modeling
        return simulateElevation(for: coordinate)
    }

    /// Simulate elevation data based on coordinate (for demonstration)
    /// In production, replace with actual elevation API
    private func simulateElevation(for coordinate: CLLocationCoordinate2D) -> Double {
        // Create realistic terrain simulation using multiple frequencies
        let lat = coordinate.latitude
        let lon = coordinate.longitude

        // Base elevation (sea level to high mountains)
        let baseElevation = 500.0

        // Large-scale terrain features (mountains, valleys)
        let largeScale = sin(lat * 0.1) * cos(lon * 0.1) * 800

        // Medium-scale features (hills, ridges)
        let mediumScale = sin(lat * 0.5) * cos(lon * 0.5) * 200

        // Small-scale features (local variations)
        let smallScale = sin(lat * 2.0) * cos(lon * 2.0) * 50

        // Very local variations
        let microScale = sin(lat * 10.0) * cos(lon * 10.0) * 10

        // Combine all scales
        let elevation = baseElevation + largeScale + mediumScale + smallScale + microScale

        // Ensure elevation is non-negative
        return max(0, elevation)
    }

    // MARK: - Path Sampling

    /// Sample points along a path at regular intervals
    private func samplePointsAlongPath(coordinates: [CLLocationCoordinate2D], interval: Double) -> [CLLocationCoordinate2D] {
        guard coordinates.count >= 2 else { return coordinates }

        var sampledPoints: [CLLocationCoordinate2D] = [coordinates[0]]
        var remainingDistance = interval

        for i in 1..<coordinates.count {
            let start = coordinates[i - 1]
            let end = coordinates[i]
            let segmentDistance = calculateDistance(from: start, to: end)
            var distanceCovered: Double = 0

            while distanceCovered + remainingDistance < segmentDistance {
                distanceCovered += remainingDistance
                let fraction = distanceCovered / segmentDistance
                let interpolatedPoint = interpolateCoordinate(from: start, to: end, fraction: fraction)
                sampledPoints.append(interpolatedPoint)
                remainingDistance = interval
            }

            remainingDistance -= (segmentDistance - distanceCovered)
        }

        // Always include the last point
        if let last = coordinates.last, sampledPoints.last != last {
            sampledPoints.append(last)
        }

        return sampledPoints
    }

    /// Interpolate between two coordinates
    private func interpolateCoordinate(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, fraction: Double) -> CLLocationCoordinate2D {
        let lat = start.latitude + (end.latitude - start.latitude) * fraction
        let lon = start.longitude + (end.longitude - start.longitude) * fraction
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Calculate distance between two coordinates
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let location2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return location1.distance(from: location2)
    }

    // MARK: - Statistics Calculation

    /// Calculate comprehensive statistics from elevation points
    private func calculateStatistics(from points: [ElevationPoint]) -> ProfileStatistics {
        guard !points.isEmpty else {
            return ProfileStatistics.empty()
        }

        let elevations = points.map { $0.elevation }
        let minElevation = elevations.min() ?? 0
        let maxElevation = elevations.max() ?? 0
        let startElevation = points.first?.elevation ?? 0
        let endElevation = points.last?.elevation ?? 0
        let totalDistance = points.last?.distance ?? 0

        // Calculate total climb and descent
        var totalClimb: Double = 0
        var totalDescent: Double = 0
        var grades: [Double] = []
        var steepSections: [(grade: Double, distance: Double)] = []

        for i in 1..<points.count {
            let elevationChange = points[i].elevation - points[i - 1].elevation
            let distanceChange = points[i].distance - points[i - 1].distance

            if elevationChange > 0 {
                totalClimb += elevationChange
            } else {
                totalDescent += abs(elevationChange)
            }

            // Calculate grade (percentage)
            if distanceChange > 0 {
                let grade = (elevationChange / distanceChange) * 100
                grades.append(grade)

                // Track steep sections (> 15% grade)
                if abs(grade) > 15 {
                    steepSections.append((grade: grade, distance: points[i - 1].distance))
                }
            }
        }

        let maxGrade = grades.max() ?? 0
        let minGrade = grades.min() ?? 0
        let averageGrade = grades.isEmpty ? 0 : grades.reduce(0, +) / Double(grades.count)
        let averageElevation = elevations.reduce(0, +) / Double(elevations.count)

        let steepestSection = steepSections.max(by: { abs($0.grade) < abs($1.grade) })

        return ProfileStatistics(
            minElevation: minElevation,
            maxElevation: maxElevation,
            startElevation: startElevation,
            endElevation: endElevation,
            totalClimb: totalClimb,
            totalDescent: totalDescent,
            netElevationChange: endElevation - startElevation,
            totalDistance: totalDistance,
            maxGrade: maxGrade,
            minGrade: minGrade,
            averageGrade: averageGrade,
            averageElevation: averageElevation,
            steepSectionCount: steepSections.count,
            steepestSectionGrade: steepestSection?.grade ?? 0,
            steepestSectionDistance: steepestSection?.distance ?? 0
        )
    }

    /// Calculate gradient segments for visualization
    private func calculateGradientSegments(from points: [ElevationPoint]) -> [GradientSegment] {
        var segments: [GradientSegment] = []

        for i in 1..<points.count {
            let elevationChange = points[i].elevation - points[i - 1].elevation
            let distanceChange = points[i].distance - points[i - 1].distance

            if distanceChange > 0 {
                let grade = (elevationChange / distanceChange) * 100
                let segment = GradientSegment(
                    startDistance: points[i - 1].distance,
                    endDistance: points[i].distance,
                    grade: grade
                )
                segments.append(segment)
            }
        }

        return segments
    }

    // MARK: - Profile Management

    /// Save a profile
    func saveProfile(_ profile: ElevationProfile) {
        savedProfiles.append(profile)
        persistProfiles()
    }

    /// Delete a profile
    func deleteProfile(_ profile: ElevationProfile) {
        savedProfiles.removeAll { $0.id == profile.id }
        persistProfiles()
    }

    /// Clear all saved profiles
    func clearAllProfiles() {
        savedProfiles.removeAll()
        persistProfiles()
    }

    // MARK: - Persistence

    private func loadSavedProfiles() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let profiles = try? JSONDecoder().decode([ElevationProfile].self, from: data) else {
            return
        }
        savedProfiles = profiles
    }

    private func persistProfiles() {
        guard let data = try? JSONEncoder().encode(savedProfiles) else { return }
        UserDefaults.standard.set(data, forKey: persistenceKey)
    }

    // MARK: - Export

    /// Export profile data
    func exportProfile(_ profile: ElevationProfile, format: ElevationExportFormat) -> Data? {
        switch format {
        case .json:
            return exportToJSON(profile)
        case .csv:
            return exportToCSV(profile)
        case .gpx:
            return exportToGPX(profile)
        }
    }

    private func exportToJSON(_ profile: ElevationProfile) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(profile)
    }

    private func exportToCSV(_ profile: ElevationProfile) -> Data? {
        var csv = "Distance (m),Elevation (m),Latitude,Longitude,Grade (%)\n"

        for (index, point) in profile.points.enumerated() {
            var grade: Double = 0
            if index > 0 && index < profile.gradientSegments.count {
                grade = profile.gradientSegments[index - 1].grade
            }

            csv += String(format: "%.2f,%.2f,%.6f,%.6f,%.2f\n",
                         point.distance,
                         point.elevation,
                         point.coordinate.latitude,
                         point.coordinate.longitude,
                         grade)
        }

        // Add statistics
        csv += "\nStatistics\n"
        csv += "Min Elevation (m),\(profile.statistics.minElevation)\n"
        csv += "Max Elevation (m),\(profile.statistics.maxElevation)\n"
        csv += "Total Climb (m),\(profile.statistics.totalClimb)\n"
        csv += "Total Descent (m),\(profile.statistics.totalDescent)\n"
        csv += "Total Distance (m),\(profile.statistics.totalDistance)\n"
        csv += "Max Grade (%),\(profile.statistics.maxGrade)\n"
        csv += "Average Grade (%),\(profile.statistics.averageGrade)\n"

        return csv.data(using: .utf8)
    }

    private func exportToGPX(_ profile: ElevationProfile) -> Data? {
        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="OmniTAKMobile"
             xmlns="http://www.topografix.com/GPX/1/1">
          <trk>
            <name>\(profile.name)</name>
            <trkseg>

        """

        for point in profile.points {
            gpx += """
              <trkpt lat="\(point.coordinate.latitude)" lon="\(point.coordinate.longitude)">
                <ele>\(point.elevation)</ele>
              </trkpt>

            """
        }

        gpx += """
            </trkseg>
          </trk>
        </gpx>
        """

        return gpx.data(using: .utf8)
    }

    // MARK: - Utility Methods

    /// Format distance for display
    static func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        } else {
            return String(format: "%.2f km", meters / 1000)
        }
    }

    /// Format elevation for display
    static func formatElevation(_ meters: Double, unit: ElevationUnit = .meters) -> String {
        return unit.format(meters)
    }

    /// Format grade for display
    static func formatGrade(_ percentage: Double) -> String {
        return String(format: "%.1f%%", percentage)
    }
}
