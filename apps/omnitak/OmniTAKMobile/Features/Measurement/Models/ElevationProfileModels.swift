//
//  ElevationProfileModels.swift
//  OmniTAKMobile
//
//  Core data structures for elevation profile analysis
//

import Foundation
import CoreLocation
import MapKit

// MARK: - Elevation Point

struct ElevationPoint: Identifiable, Codable, Equatable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let elevation: Double // meters
    let distance: Double // meters from start

    init(id: UUID = UUID(), coordinate: CLLocationCoordinate2D, elevation: Double, distance: Double) {
        self.id = id
        self.coordinate = coordinate
        self.elevation = elevation
        self.distance = distance
    }

    // Codable conformance for CLLocationCoordinate2D
    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, elevation, distance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        elevation = try container.decode(Double.self, forKey: .elevation)
        distance = try container.decode(Double.self, forKey: .distance)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(elevation, forKey: .elevation)
        try container.encode(distance, forKey: .distance)
    }

    static func == (lhs: ElevationPoint, rhs: ElevationPoint) -> Bool {
        return lhs.id == rhs.id &&
            lhs.coordinate.latitude == rhs.coordinate.latitude &&
            lhs.coordinate.longitude == rhs.coordinate.longitude &&
            lhs.elevation == rhs.elevation &&
            lhs.distance == rhs.distance
    }
}

// MARK: - Gradient Segment

struct GradientSegment: Identifiable, Codable {
    let id: UUID
    let startDistance: Double
    let endDistance: Double
    let grade: Double // percentage
    let steepnessCategory: SteepnessCategory

    init(id: UUID = UUID(), startDistance: Double, endDistance: Double, grade: Double) {
        self.id = id
        self.startDistance = startDistance
        self.endDistance = endDistance
        self.grade = grade
        self.steepnessCategory = SteepnessCategory.from(grade: grade)
    }
}

// MARK: - Steepness Category

enum SteepnessCategory: String, Codable {
    case flat = "Flat"
    case gentle = "Gentle"
    case moderate = "Moderate"
    case steep = "Steep"
    case verysteep = "Very Steep"
    case extreme = "Extreme"

    static func from(grade: Double) -> SteepnessCategory {
        let absGrade = abs(grade)
        if absGrade < 3 {
            return .flat
        } else if absGrade < 8 {
            return .gentle
        } else if absGrade < 15 {
            return .moderate
        } else if absGrade < 25 {
            return .steep
        } else if absGrade < 40 {
            return .verysteep
        } else {
            return .extreme
        }
    }

    var color: String {
        switch self {
        case .flat: return "#4CAF50"      // Green
        case .gentle: return "#8BC34A"    // Light Green
        case .moderate: return "#FFEB3B"  // Yellow
        case .steep: return "#FF9800"     // Orange
        case .verysteep: return "#FF5722" // Deep Orange
        case .extreme: return "#F44336"   // Red
        }
    }

    var displayName: String {
        switch self {
        case .flat: return "Flat (0-3%)"
        case .gentle: return "Gentle (3-8%)"
        case .moderate: return "Moderate (8-15%)"
        case .steep: return "Steep (15-25%)"
        case .verysteep: return "Very Steep (25-40%)"
        case .extreme: return "Extreme (>40%)"
        }
    }
}

// MARK: - Profile Statistics

struct ProfileStatistics: Codable {
    let minElevation: Double           // meters
    let maxElevation: Double           // meters
    let startElevation: Double         // meters
    let endElevation: Double           // meters
    let totalClimb: Double             // meters (cumulative ascent)
    let totalDescent: Double           // meters (cumulative descent)
    let netElevationChange: Double     // meters
    let totalDistance: Double          // meters
    let maxGrade: Double               // percentage
    let minGrade: Double               // percentage
    let averageGrade: Double           // percentage
    let averageElevation: Double       // meters
    let steepSectionCount: Int         // number of steep segments
    let steepestSectionGrade: Double   // percentage
    let steepestSectionDistance: Double // meters from start

    static func empty() -> ProfileStatistics {
        return ProfileStatistics(
            minElevation: 0,
            maxElevation: 0,
            startElevation: 0,
            endElevation: 0,
            totalClimb: 0,
            totalDescent: 0,
            netElevationChange: 0,
            totalDistance: 0,
            maxGrade: 0,
            minGrade: 0,
            averageGrade: 0,
            averageElevation: 0,
            steepSectionCount: 0,
            steepestSectionGrade: 0,
            steepestSectionDistance: 0
        )
    }

    var difficultyRating: String {
        let avgAbsGrade = abs(averageGrade)
        let climbPerKm = totalDistance > 0 ? (totalClimb / totalDistance) * 1000 : 0

        if avgAbsGrade < 3 && climbPerKm < 30 {
            return "Easy"
        } else if avgAbsGrade < 8 && climbPerKm < 60 {
            return "Moderate"
        } else if avgAbsGrade < 15 && climbPerKm < 100 {
            return "Difficult"
        } else {
            return "Very Difficult"
        }
    }
}

// MARK: - Elevation Profile

struct ElevationProfile: Identifiable, Codable {
    let id: UUID
    let name: String
    let createdAt: Date
    let points: [ElevationPoint]
    let statistics: ProfileStatistics
    let gradientSegments: [GradientSegment]
    let pathCoordinates: [CLLocationCoordinate2D]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        points: [ElevationPoint],
        statistics: ProfileStatistics,
        gradientSegments: [GradientSegment] = [],
        pathCoordinates: [CLLocationCoordinate2D] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.points = points
        self.statistics = statistics
        self.gradientSegments = gradientSegments
        self.pathCoordinates = pathCoordinates
    }

    // Codable conformance for CLLocationCoordinate2D array
    enum CodingKeys: String, CodingKey {
        case id, name, createdAt, points, statistics, gradientSegments, pathCoordinates
    }

    struct CoordinatePair: Codable {
        let latitude: Double
        let longitude: Double
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        points = try container.decode([ElevationPoint].self, forKey: .points)
        statistics = try container.decode(ProfileStatistics.self, forKey: .statistics)
        gradientSegments = try container.decodeIfPresent([GradientSegment].self, forKey: .gradientSegments) ?? []
        let pairs = try container.decodeIfPresent([CoordinatePair].self, forKey: .pathCoordinates) ?? []
        pathCoordinates = pairs.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(points, forKey: .points)
        try container.encode(statistics, forKey: .statistics)
        try container.encode(gradientSegments, forKey: .gradientSegments)
        let pairs = pathCoordinates.map { CoordinatePair(latitude: $0.latitude, longitude: $0.longitude) }
        try container.encode(pairs, forKey: .pathCoordinates)
    }

    static func empty() -> ElevationProfile {
        return ElevationProfile(
            name: "Empty Profile",
            points: [],
            statistics: ProfileStatistics.empty()
        )
    }
}

// MARK: - Profile Request

struct ElevationProfileRequest {
    let coordinates: [CLLocationCoordinate2D]
    let samplingInterval: Double // meters between sample points
    let name: String

    init(coordinates: [CLLocationCoordinate2D], samplingInterval: Double = 50, name: String = "Elevation Profile") {
        self.coordinates = coordinates
        self.samplingInterval = samplingInterval
        self.name = name
    }
}

// MARK: - Profile Error

enum ElevationProfileError: Error, LocalizedError {
    case insufficientPoints
    case elevationDataUnavailable
    case calculationFailed
    case invalidPath
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .insufficientPoints:
            return "At least two points are required to generate an elevation profile."
        case .elevationDataUnavailable:
            return "Elevation data is not available for this region."
        case .calculationFailed:
            return "Failed to calculate elevation profile."
        case .invalidPath:
            return "The provided path is invalid."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Elevation Unit

enum ElevationUnit: String, CaseIterable, Codable {
    case meters = "Meters"
    case feet = "Feet"

    var abbreviation: String {
        switch self {
        case .meters: return "m"
        case .feet: return "ft"
        }
    }

    func convert(fromMeters meters: Double) -> Double {
        switch self {
        case .meters: return meters
        case .feet: return meters * 3.28084
        }
    }

    func format(_ valueInMeters: Double) -> String {
        let converted = convert(fromMeters: valueInMeters)
        switch self {
        case .meters:
            return String(format: "%.1f m", converted)
        case .feet:
            return String(format: "%.0f ft", converted)
        }
    }
}

// MARK: - Export Format

enum ElevationExportFormat: String, CaseIterable {
    case json = "JSON"
    case csv = "CSV"
    case gpx = "GPX"

    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .gpx: return "gpx"
        }
    }

    var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .csv: return "text/csv"
        case .gpx: return "application/gpx+xml"
        }
    }
}
