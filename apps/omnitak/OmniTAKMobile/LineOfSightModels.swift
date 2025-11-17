//
//  LineOfSightModels.swift
//  OmniTAKMobile
//
//  Core data structures for Line of Sight analysis
//

import Foundation
import CoreLocation
import MapKit

// MARK: - LOS Result

enum LOSResult: String, CaseIterable, Codable {
    case visible = "Visible"
    case obstructed = "Obstructed"
    case partial = "Partial"

    var icon: String {
        switch self {
        case .visible: return "eye.fill"
        case .obstructed: return "eye.slash.fill"
        case .partial: return "eye.trianglebadge.exclamationmark"
        }
    }

    var color: String {
        switch self {
        case .visible: return "#4CAF50"
        case .obstructed: return "#FF4444"
        case .partial: return "#FFA500"
        }
    }

    var description: String {
        switch self {
        case .visible: return "Clear line of sight"
        case .obstructed: return "Line of sight blocked"
        case .partial: return "Partial obstruction detected"
        }
    }
}

// MARK: - Obstruction Type

enum LOSObstructionType: String, CaseIterable, Codable {
    case terrain = "Terrain"
    case vegetation = "Vegetation"
    case building = "Building"
    case atmospheric = "Atmospheric"
    case fresnelZone = "Fresnel Zone"
    case earthCurvature = "Earth Curvature"

    var icon: String {
        switch self {
        case .terrain: return "mountain.2.fill"
        case .vegetation: return "leaf.fill"
        case .building: return "building.2.fill"
        case .atmospheric: return "cloud.fill"
        case .fresnelZone: return "wave.3.right"
        case .earthCurvature: return "globe"
        }
    }
}

// MARK: - LOS Obstruction

struct LOSObstruction: Identifiable, Codable {
    var id: UUID
    var location: CLLocationCoordinate2D
    var elevation: Double // meters above sea level
    var type: LOSObstructionType
    var distanceFromObserver: Double // meters
    var clearanceRequired: Double // meters needed to clear
    var clearanceAvailable: Double // actual clearance in meters
    var percentageAlongPath: Double // 0.0 to 1.0

    init(id: UUID = UUID(),
         location: CLLocationCoordinate2D,
         elevation: Double,
         type: LOSObstructionType,
         distanceFromObserver: Double,
         clearanceRequired: Double = 0,
         clearanceAvailable: Double = 0,
         percentageAlongPath: Double = 0) {
        self.id = id
        self.location = location
        self.elevation = elevation
        self.type = type
        self.distanceFromObserver = distanceFromObserver
        self.clearanceRequired = clearanceRequired
        self.clearanceAvailable = clearanceAvailable
        self.percentageAlongPath = percentageAlongPath
    }

    // Codable conformance for CLLocationCoordinate2D
    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, elevation, type, distanceFromObserver
        case clearanceRequired, clearanceAvailable, percentageAlongPath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        elevation = try container.decode(Double.self, forKey: .elevation)
        type = try container.decode(LOSObstructionType.self, forKey: .type)
        distanceFromObserver = try container.decode(Double.self, forKey: .distanceFromObserver)
        clearanceRequired = try container.decode(Double.self, forKey: .clearanceRequired)
        clearanceAvailable = try container.decode(Double.self, forKey: .clearanceAvailable)
        percentageAlongPath = try container.decode(Double.self, forKey: .percentageAlongPath)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(location.latitude, forKey: .latitude)
        try container.encode(location.longitude, forKey: .longitude)
        try container.encode(elevation, forKey: .elevation)
        try container.encode(type, forKey: .type)
        try container.encode(distanceFromObserver, forKey: .distanceFromObserver)
        try container.encode(clearanceRequired, forKey: .clearanceRequired)
        try container.encode(clearanceAvailable, forKey: .clearanceAvailable)
        try container.encode(percentageAlongPath, forKey: .percentageAlongPath)
    }
}

// MARK: - Terrain Profile Point

struct TerrainProfilePoint: Identifiable, Codable {
    var id: UUID
    var location: CLLocationCoordinate2D
    var elevation: Double // meters
    var distanceFromStart: Double // meters
    var losElevation: Double // elevation of LOS line at this point
    var clearance: Double // difference between LOS and terrain

    init(id: UUID = UUID(),
         location: CLLocationCoordinate2D,
         elevation: Double,
         distanceFromStart: Double,
         losElevation: Double = 0,
         clearance: Double = 0) {
        self.id = id
        self.location = location
        self.elevation = elevation
        self.distanceFromStart = distanceFromStart
        self.losElevation = losElevation
        self.clearance = clearance
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, elevation, distanceFromStart, losElevation, clearance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        elevation = try container.decode(Double.self, forKey: .elevation)
        distanceFromStart = try container.decode(Double.self, forKey: .distanceFromStart)
        losElevation = try container.decode(Double.self, forKey: .losElevation)
        clearance = try container.decode(Double.self, forKey: .clearance)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(location.latitude, forKey: .latitude)
        try container.encode(location.longitude, forKey: .longitude)
        try container.encode(elevation, forKey: .elevation)
        try container.encode(distanceFromStart, forKey: .distanceFromStart)
        try container.encode(losElevation, forKey: .losElevation)
        try container.encode(clearance, forKey: .clearance)
    }
}

// MARK: - LOS Analysis

struct LOSAnalysis: Identifiable, Codable {
    var id: UUID
    var startPoint: CLLocationCoordinate2D
    var endPoint: CLLocationCoordinate2D
    var observerHeight: Double // meters above ground
    var targetHeight: Double // meters above ground
    var result: LOSResult
    var obstructions: [LOSObstruction]
    var terrainProfile: [TerrainProfilePoint]
    var totalDistance: Double // meters
    var maxTerrainElevation: Double // meters
    var minClearance: Double // meters
    var effectiveEarthRadius: Double // meters (considering atmospheric refraction)
    var createdAt: Date
    var name: String

    // Radio propagation specific
    var frequencyMHz: Double?
    var fresnelZoneClearance: Double? // percentage of first Fresnel zone clearance
    var pathLossDB: Double?
    var estimatedRangeMeters: Double?

    init(id: UUID = UUID(),
         startPoint: CLLocationCoordinate2D,
         endPoint: CLLocationCoordinate2D,
         observerHeight: Double = 2.0,
         targetHeight: Double = 2.0,
         result: LOSResult = .visible,
         obstructions: [LOSObstruction] = [],
         terrainProfile: [TerrainProfilePoint] = [],
         totalDistance: Double = 0,
         maxTerrainElevation: Double = 0,
         minClearance: Double = Double.infinity,
         effectiveEarthRadius: Double = 8495000, // 4/3 Earth radius for standard atmosphere
         name: String? = nil) {
        self.id = id
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.observerHeight = observerHeight
        self.targetHeight = targetHeight
        self.result = result
        self.obstructions = obstructions
        self.terrainProfile = terrainProfile
        self.totalDistance = totalDistance
        self.maxTerrainElevation = maxTerrainElevation
        self.minClearance = minClearance
        self.effectiveEarthRadius = effectiveEarthRadius
        self.createdAt = Date()
        self.name = name ?? "LOS \(id.uuidString.prefix(4))"
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, startLat, startLon, endLat, endLon, observerHeight, targetHeight
        case result, obstructions, terrainProfile, totalDistance, maxTerrainElevation
        case minClearance, effectiveEarthRadius, createdAt, name
        case frequencyMHz, fresnelZoneClearance, pathLossDB, estimatedRangeMeters
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let startLat = try container.decode(Double.self, forKey: .startLat)
        let startLon = try container.decode(Double.self, forKey: .startLon)
        startPoint = CLLocationCoordinate2D(latitude: startLat, longitude: startLon)
        let endLat = try container.decode(Double.self, forKey: .endLat)
        let endLon = try container.decode(Double.self, forKey: .endLon)
        endPoint = CLLocationCoordinate2D(latitude: endLat, longitude: endLon)
        observerHeight = try container.decode(Double.self, forKey: .observerHeight)
        targetHeight = try container.decode(Double.self, forKey: .targetHeight)
        result = try container.decode(LOSResult.self, forKey: .result)
        obstructions = try container.decode([LOSObstruction].self, forKey: .obstructions)
        terrainProfile = try container.decode([TerrainProfilePoint].self, forKey: .terrainProfile)
        totalDistance = try container.decode(Double.self, forKey: .totalDistance)
        maxTerrainElevation = try container.decode(Double.self, forKey: .maxTerrainElevation)
        minClearance = try container.decode(Double.self, forKey: .minClearance)
        effectiveEarthRadius = try container.decode(Double.self, forKey: .effectiveEarthRadius)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        name = try container.decode(String.self, forKey: .name)
        frequencyMHz = try container.decodeIfPresent(Double.self, forKey: .frequencyMHz)
        fresnelZoneClearance = try container.decodeIfPresent(Double.self, forKey: .fresnelZoneClearance)
        pathLossDB = try container.decodeIfPresent(Double.self, forKey: .pathLossDB)
        estimatedRangeMeters = try container.decodeIfPresent(Double.self, forKey: .estimatedRangeMeters)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(startPoint.latitude, forKey: .startLat)
        try container.encode(startPoint.longitude, forKey: .startLon)
        try container.encode(endPoint.latitude, forKey: .endLat)
        try container.encode(endPoint.longitude, forKey: .endLon)
        try container.encode(observerHeight, forKey: .observerHeight)
        try container.encode(targetHeight, forKey: .targetHeight)
        try container.encode(result, forKey: .result)
        try container.encode(obstructions, forKey: .obstructions)
        try container.encode(terrainProfile, forKey: .terrainProfile)
        try container.encode(totalDistance, forKey: .totalDistance)
        try container.encode(maxTerrainElevation, forKey: .maxTerrainElevation)
        try container.encode(minClearance, forKey: .minClearance)
        try container.encode(effectiveEarthRadius, forKey: .effectiveEarthRadius)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(frequencyMHz, forKey: .frequencyMHz)
        try container.encodeIfPresent(fresnelZoneClearance, forKey: .fresnelZoneClearance)
        try container.encodeIfPresent(pathLossDB, forKey: .pathLossDB)
        try container.encodeIfPresent(estimatedRangeMeters, forKey: .estimatedRangeMeters)
    }
}

// MARK: - Viewshed Result

struct ViewshedResult: Identifiable, Codable {
    var id: UUID
    var observerLocation: CLLocationCoordinate2D
    var observerHeight: Double // meters above ground
    var analysisRadius: Double // meters
    var azimuthResolution: Double // degrees
    var rangeResolution: Double // meters
    var visibleSectors: [ViewshedSector]
    var totalArea: Double // square meters
    var visibleArea: Double // square meters
    var visibilityPercentage: Double // 0-100
    var maxVisibleRange: Double // meters
    var createdAt: Date

    init(id: UUID = UUID(),
         observerLocation: CLLocationCoordinate2D,
         observerHeight: Double = 2.0,
         analysisRadius: Double = 5000,
         azimuthResolution: Double = 5.0,
         rangeResolution: Double = 100,
         visibleSectors: [ViewshedSector] = [],
         totalArea: Double = 0,
         visibleArea: Double = 0,
         maxVisibleRange: Double = 0) {
        self.id = id
        self.observerLocation = observerLocation
        self.observerHeight = observerHeight
        self.analysisRadius = analysisRadius
        self.azimuthResolution = azimuthResolution
        self.rangeResolution = rangeResolution
        self.visibleSectors = visibleSectors
        self.totalArea = totalArea
        self.visibleArea = visibleArea
        self.visibilityPercentage = totalArea > 0 ? (visibleArea / totalArea) * 100 : 0
        self.maxVisibleRange = maxVisibleRange
        self.createdAt = Date()
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, observerHeight, analysisRadius
        case azimuthResolution, rangeResolution, visibleSectors
        case totalArea, visibleArea, visibilityPercentage, maxVisibleRange, createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        observerLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        observerHeight = try container.decode(Double.self, forKey: .observerHeight)
        analysisRadius = try container.decode(Double.self, forKey: .analysisRadius)
        azimuthResolution = try container.decode(Double.self, forKey: .azimuthResolution)
        rangeResolution = try container.decode(Double.self, forKey: .rangeResolution)
        visibleSectors = try container.decode([ViewshedSector].self, forKey: .visibleSectors)
        totalArea = try container.decode(Double.self, forKey: .totalArea)
        visibleArea = try container.decode(Double.self, forKey: .visibleArea)
        visibilityPercentage = try container.decode(Double.self, forKey: .visibilityPercentage)
        maxVisibleRange = try container.decode(Double.self, forKey: .maxVisibleRange)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(observerLocation.latitude, forKey: .latitude)
        try container.encode(observerLocation.longitude, forKey: .longitude)
        try container.encode(observerHeight, forKey: .observerHeight)
        try container.encode(analysisRadius, forKey: .analysisRadius)
        try container.encode(azimuthResolution, forKey: .azimuthResolution)
        try container.encode(rangeResolution, forKey: .rangeResolution)
        try container.encode(visibleSectors, forKey: .visibleSectors)
        try container.encode(totalArea, forKey: .totalArea)
        try container.encode(visibleArea, forKey: .visibleArea)
        try container.encode(visibilityPercentage, forKey: .visibilityPercentage)
        try container.encode(maxVisibleRange, forKey: .maxVisibleRange)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

// MARK: - Viewshed Sector

struct ViewshedSector: Identifiable, Codable {
    var id: UUID
    var azimuth: Double // degrees from north
    var maxVisibleRange: Double // meters
    var obstructedRanges: [ClosedRange<Double>] // ranges that are blocked
    var isCompletelyVisible: Bool

    init(id: UUID = UUID(),
         azimuth: Double,
         maxVisibleRange: Double,
         obstructedRanges: [ClosedRange<Double>] = [],
         isCompletelyVisible: Bool = true) {
        self.id = id
        self.azimuth = azimuth
        self.maxVisibleRange = maxVisibleRange
        self.obstructedRanges = obstructedRanges
        self.isCompletelyVisible = isCompletelyVisible
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, azimuth, maxVisibleRange, obstructedRanges, isCompletelyVisible
    }

    struct RangePair: Codable {
        let lower: Double
        let upper: Double
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        azimuth = try container.decode(Double.self, forKey: .azimuth)
        maxVisibleRange = try container.decode(Double.self, forKey: .maxVisibleRange)
        let rangePairs = try container.decode([RangePair].self, forKey: .obstructedRanges)
        obstructedRanges = rangePairs.map { $0.lower...$0.upper }
        isCompletelyVisible = try container.decode(Bool.self, forKey: .isCompletelyVisible)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(azimuth, forKey: .azimuth)
        try container.encode(maxVisibleRange, forKey: .maxVisibleRange)
        let rangePairs = obstructedRanges.map { RangePair(lower: $0.lowerBound, upper: $0.upperBound) }
        try container.encode(rangePairs, forKey: .obstructedRanges)
        try container.encode(isCompletelyVisible, forKey: .isCompletelyVisible)
    }
}

// MARK: - Radio Frequency Band

enum RadioFrequencyBand: String, CaseIterable, Codable {
    case hf = "HF (3-30 MHz)"
    case vhf = "VHF (30-300 MHz)"
    case uhf = "UHF (300-3000 MHz)"
    case shf = "SHF (3-30 GHz)"

    var typicalFrequencyMHz: Double {
        switch self {
        case .hf: return 15.0
        case .vhf: return 150.0
        case .uhf: return 450.0
        case .shf: return 5000.0
        }
    }

    var fresnelZoneImportance: String {
        switch self {
        case .hf: return "Large zone, rarely achievable"
        case .vhf: return "Important for reliable comms"
        case .uhf: return "Critical for digital comms"
        case .shf: return "Very critical, narrow beam"
        }
    }
}

// MARK: - Atmospheric Conditions

struct AtmosphericConditions: Codable {
    var temperature: Double // Celsius
    var pressure: Double // hPa
    var humidity: Double // percentage 0-100
    var refractionCoefficient: Double // typically 0.25 to 0.5

    static func standard() -> AtmosphericConditions {
        return AtmosphericConditions(
            temperature: 15.0,
            pressure: 1013.25,
            humidity: 50.0,
            refractionCoefficient: 0.33 // 4/3 Earth radius approximation
        )
    }

    var effectiveEarthRadiusMultiplier: Double {
        // K-factor based on refraction coefficient
        return 1.0 / (1.0 - refractionCoefficient)
    }
}

// MARK: - LOS Configuration

struct LOSConfiguration: Codable {
    var defaultObserverHeight: Double
    var defaultTargetHeight: Double
    var profileResolution: Int // number of points along path
    var considerEarthCurvature: Bool
    var considerAtmosphericRefraction: Bool
    var atmosphericConditions: AtmosphericConditions
    var minimumClearanceMeters: Double

    static func defaultConfiguration() -> LOSConfiguration {
        return LOSConfiguration(
            defaultObserverHeight: 2.0,
            defaultTargetHeight: 2.0,
            profileResolution: 100,
            considerEarthCurvature: true,
            considerAtmosphericRefraction: true,
            atmosphericConditions: AtmosphericConditions.standard(),
            minimumClearanceMeters: 0.0
        )
    }
}
