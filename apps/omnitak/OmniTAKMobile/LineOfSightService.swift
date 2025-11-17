//
//  LineOfSightService.swift
//  OmniTAKMobile
//
//  Core service for Line of Sight analysis and radio propagation calculations
//

import Foundation
import CoreLocation
import MapKit
import Combine

// MARK: - Line of Sight Service

class LineOfSightService: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published var currentAnalysis: LOSAnalysis?
    @Published var savedAnalyses: [LOSAnalysis] = []
    @Published var currentViewshed: ViewshedResult?
    @Published var isAnalyzing: Bool = false
    @Published var analysisProgress: Double = 0.0
    @Published var configuration: LOSConfiguration

    // MARK: - Constants

    private let earthRadius: Double = 6371000.0 // meters
    private let speedOfLight: Double = 299792458.0 // m/s

    // MARK: - Initialization

    override init() {
        self.configuration = LOSConfiguration.defaultConfiguration()
        super.init()
    }

    // MARK: - Main LOS Analysis

    /// Calculate line of sight between two points considering terrain
    func analyzeLOS(from observer: CLLocationCoordinate2D,
                    to target: CLLocationCoordinate2D,
                    observerHeight: Double? = nil,
                    targetHeight: Double? = nil,
                    frequencyMHz: Double? = nil) -> LOSAnalysis {

        let obsHeight = observerHeight ?? configuration.defaultObserverHeight
        let tgtHeight = targetHeight ?? configuration.defaultTargetHeight

        // Calculate basic distance
        let totalDistance = calculateDistance(from: observer, to: target)

        // Generate terrain profile
        let terrainProfile = generateTerrainProfile(from: observer, to: target, samples: configuration.profileResolution)

        // Calculate LOS line considering Earth curvature
        let profileWithLOS = calculateLOSLine(
            profile: terrainProfile,
            observerHeight: obsHeight,
            targetHeight: tgtHeight,
            totalDistance: totalDistance
        )

        // Find obstructions
        let obstructions = identifyObstructions(profile: profileWithLOS, totalDistance: totalDistance)

        // Determine result
        let result = determineLOSResult(obstructions: obstructions, profile: profileWithLOS)

        // Calculate min clearance and max elevation
        let minClearance = profileWithLOS.map { $0.clearance }.min() ?? 0
        let maxElevation = profileWithLOS.map { $0.elevation }.max() ?? 0

        // Create analysis result
        var analysis = LOSAnalysis(
            startPoint: observer,
            endPoint: target,
            observerHeight: obsHeight,
            targetHeight: tgtHeight,
            result: result,
            obstructions: obstructions,
            terrainProfile: profileWithLOS,
            totalDistance: totalDistance,
            maxTerrainElevation: maxElevation,
            minClearance: minClearance,
            effectiveEarthRadius: earthRadius * configuration.atmosphericConditions.effectiveEarthRadiusMultiplier
        )

        // Add radio propagation calculations if frequency specified
        if let freq = frequencyMHz {
            analysis.frequencyMHz = freq
            analysis.fresnelZoneClearance = calculateFresnelZoneClearance(
                profile: profileWithLOS,
                frequencyMHz: freq,
                totalDistance: totalDistance
            )
            analysis.pathLossDB = calculatePathLoss(distanceMeters: totalDistance, frequencyMHz: freq)
            analysis.estimatedRangeMeters = estimateRadioRange(
                frequencyMHz: freq,
                observerHeight: obsHeight,
                targetHeight: tgtHeight
            )
        }

        currentAnalysis = analysis
        return analysis
    }

    // MARK: - Terrain Profile Generation

    /// Generate terrain profile along the path (simulated - would use elevation API in production)
    private func generateTerrainProfile(from start: CLLocationCoordinate2D,
                                        to end: CLLocationCoordinate2D,
                                        samples: Int) -> [TerrainProfilePoint] {
        var profile: [TerrainProfilePoint] = []
        let totalDistance = calculateDistance(from: start, to: end)

        for i in 0...samples {
            let fraction = Double(i) / Double(samples)
            let distance = totalDistance * fraction

            // Interpolate location
            let lat = start.latitude + (end.latitude - start.latitude) * fraction
            let lon = start.longitude + (end.longitude - start.longitude) * fraction
            let location = CLLocationCoordinate2D(latitude: lat, longitude: lon)

            // Simulate terrain elevation with realistic features
            let elevation = simulateTerrainElevation(at: location, fraction: fraction, distance: distance)

            let point = TerrainProfilePoint(
                location: location,
                elevation: elevation,
                distanceFromStart: distance
            )
            profile.append(point)
        }

        return profile
    }

    /// Simulate realistic terrain elevation (in production, use DEM/elevation service)
    private func simulateTerrainElevation(at location: CLLocationCoordinate2D,
                                          fraction: Double,
                                          distance: Double) -> Double {
        // Base elevation from location (rough approximation)
        let baseElevation = abs(sin(location.latitude * 0.1)) * 500 + 100

        // Add terrain features
        let hillFrequency = 0.0001
        let hills = sin(distance * hillFrequency) * 50

        // Add some noise for realism
        let noise = sin(location.latitude * 1000) * cos(location.longitude * 1000) * 10

        // Add mid-path ridge (common obstruction pattern)
        let ridgeFactor = exp(-pow((fraction - 0.5) * 10, 2)) * 100

        return baseElevation + hills + noise + ridgeFactor
    }

    // MARK: - LOS Line Calculation

    /// Calculate the LOS line elevation at each profile point
    private func calculateLOSLine(profile: [TerrainProfilePoint],
                                   observerHeight: Double,
                                   targetHeight: Double,
                                   totalDistance: Double) -> [TerrainProfilePoint] {
        guard profile.count >= 2 else { return profile }

        let startElevation = profile.first!.elevation + observerHeight
        let endElevation = profile.last!.elevation + targetHeight

        var updatedProfile: [TerrainProfilePoint] = []

        for point in profile {
            var updatedPoint = point
            let fraction = point.distanceFromStart / totalDistance

            // Linear LOS elevation
            var losElevation = startElevation + (endElevation - startElevation) * fraction

            // Apply Earth curvature correction if enabled
            if configuration.considerEarthCurvature {
                let earthCurvatureCorrection = calculateEarthCurvatureCorrection(
                    distance: point.distanceFromStart,
                    totalDistance: totalDistance
                )
                losElevation -= earthCurvatureCorrection
            }

            updatedPoint.losElevation = losElevation
            updatedPoint.clearance = losElevation - point.elevation

            updatedProfile.append(updatedPoint)
        }

        return updatedProfile
    }

    /// Calculate Earth curvature correction at given distance
    private func calculateEarthCurvatureCorrection(distance: Double, totalDistance: Double) -> Double {
        guard configuration.considerEarthCurvature else { return 0 }

        let effectiveRadius = earthRadius * configuration.atmosphericConditions.effectiveEarthRadiusMultiplier

        // Maximum bulge at midpoint
        let d1 = distance
        let d2 = totalDistance - distance

        // Earth bulge formula: h = (d1 * d2) / (2 * R)
        let bulge = (d1 * d2) / (2 * effectiveRadius)

        return bulge
    }

    // MARK: - Obstruction Detection

    /// Identify obstruction points along the path
    private func identifyObstructions(profile: [TerrainProfilePoint],
                                       totalDistance: Double) -> [LOSObstruction] {
        var obstructions: [LOSObstruction] = []

        for point in profile {
            if point.clearance < configuration.minimumClearanceMeters {
                let obstruction = LOSObstruction(
                    location: point.location,
                    elevation: point.elevation,
                    type: classifyObstruction(clearance: point.clearance, elevation: point.elevation),
                    distanceFromObserver: point.distanceFromStart,
                    clearanceRequired: configuration.minimumClearanceMeters,
                    clearanceAvailable: point.clearance,
                    percentageAlongPath: point.distanceFromStart / totalDistance
                )
                obstructions.append(obstruction)
            }
        }

        return obstructions
    }

    /// Classify the type of obstruction based on characteristics
    private func classifyObstruction(clearance: Double, elevation: Double) -> LOSObstructionType {
        if clearance < -50 {
            return .terrain
        } else if clearance < -10 {
            return .building
        } else if clearance < 0 {
            return .vegetation
        } else {
            return .fresnelZone
        }
    }

    /// Determine overall LOS result
    private func determineLOSResult(obstructions: [LOSObstruction],
                                     profile: [TerrainProfilePoint]) -> LOSResult {
        if obstructions.isEmpty {
            return .visible
        }

        let severeObstructions = obstructions.filter { $0.clearanceAvailable < -5 }

        if severeObstructions.count > profile.count / 10 {
            return .obstructed
        } else if !severeObstructions.isEmpty {
            return .partial
        }

        return .visible
    }

    // MARK: - Fresnel Zone Calculations

    /// Calculate first Fresnel zone radius at given point
    func calculateFirstFresnelZoneRadius(frequencyMHz: Double,
                                          distanceToObserver: Double,
                                          distanceToTarget: Double) -> Double {
        // Fresnel zone radius formula: r = sqrt(λ * d1 * d2 / (d1 + d2))
        let wavelengthMeters = speedOfLight / (frequencyMHz * 1_000_000)
        let totalDistance = distanceToObserver + distanceToTarget

        guard totalDistance > 0 else { return 0 }

        let radius = sqrt(wavelengthMeters * distanceToObserver * distanceToTarget / totalDistance)
        return radius
    }

    /// Calculate percentage of Fresnel zone clearance
    private func calculateFresnelZoneClearance(profile: [TerrainProfilePoint],
                                               frequencyMHz: Double,
                                               totalDistance: Double) -> Double {
        var minClearancePercentage: Double = 100.0

        for point in profile {
            let fresnelRadius = calculateFirstFresnelZoneRadius(
                frequencyMHz: frequencyMHz,
                distanceToObserver: point.distanceFromStart,
                distanceToTarget: totalDistance - point.distanceFromStart
            )

            guard fresnelRadius > 0 else { continue }

            let clearancePercentage = (point.clearance / fresnelRadius) * 100
            minClearancePercentage = min(minClearancePercentage, clearancePercentage)
        }

        return minClearancePercentage
    }

    // MARK: - Radio Propagation

    /// Calculate free space path loss in dB
    func calculatePathLoss(distanceMeters: Double, frequencyMHz: Double) -> Double {
        // Free Space Path Loss: FSPL = 20*log10(d) + 20*log10(f) + 32.45
        // where d is in km and f is in MHz
        let distanceKm = distanceMeters / 1000.0
        let fspl = 20 * log10(distanceKm) + 20 * log10(frequencyMHz) + 32.45
        return fspl
    }

    /// Estimate maximum radio range based on antenna heights
    func estimateRadioRange(frequencyMHz: Double,
                            observerHeight: Double,
                            targetHeight: Double) -> Double {
        // Radio horizon formula: d = 4.12 * (sqrt(h1) + sqrt(h2))
        // where d is in km and h is in meters
        let rangeKm = 4.12 * (sqrt(observerHeight) + sqrt(targetHeight))
        return rangeKm * 1000 // Convert to meters
    }

    /// Calculate ITU-R path loss model
    func calculateITURPathLoss(distanceMeters: Double,
                                frequencyMHz: Double,
                                environment: PropagationEnvironment) -> Double {
        let baseLoss = calculatePathLoss(distanceMeters: distanceMeters, frequencyMHz: frequencyMHz)

        // Add environment-specific loss
        switch environment {
        case .freeSpace:
            return baseLoss
        case .suburban:
            return baseLoss + 10
        case .urban:
            return baseLoss + 20
        case .denseUrban:
            return baseLoss + 30
        case .forest:
            return baseLoss + 15
        }
    }

    // MARK: - Viewshed Analysis

    /// Perform 360-degree viewshed analysis from a point
    func analyzeViewshed(from observer: CLLocationCoordinate2D,
                         observerHeight: Double? = nil,
                         maxRadius: Double = 5000,
                         azimuthResolution: Double = 5.0,
                         completion: @escaping (ViewshedResult) -> Void) {

        isAnalyzing = true
        analysisProgress = 0.0

        let obsHeight = observerHeight ?? configuration.defaultObserverHeight
        var sectors: [ViewshedSector] = []
        var maxVisibleRange: Double = 0
        var totalVisibleArea: Double = 0

        let totalAzimuths = Int(360.0 / azimuthResolution)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            for i in 0..<totalAzimuths {
                let azimuth = Double(i) * azimuthResolution

                // Calculate end point at max radius for this azimuth
                let endPoint = self.calculateDestinationPoint(
                    from: observer,
                    bearing: azimuth,
                    distance: maxRadius
                )

                // Analyze LOS for this direction
                let analysis = self.analyzeLOS(
                    from: observer,
                    to: endPoint,
                    observerHeight: obsHeight,
                    targetHeight: 0
                )

                // Determine visible range in this direction
                let visibleRange = self.calculateVisibleRange(from: analysis)
                maxVisibleRange = max(maxVisibleRange, visibleRange)

                // Create sector
                let sector = ViewshedSector(
                    azimuth: azimuth,
                    maxVisibleRange: visibleRange,
                    isCompletelyVisible: analysis.result == .visible
                )
                sectors.append(sector)

                // Calculate area for this sector (pie slice)
                let sectorAngleRadians = azimuthResolution * .pi / 180.0
                let sectorArea = 0.5 * pow(visibleRange, 2) * sectorAngleRadians
                totalVisibleArea += sectorArea

                // Update progress
                DispatchQueue.main.async {
                    self.analysisProgress = Double(i + 1) / Double(totalAzimuths)
                }
            }

            let totalArea = Double.pi * pow(maxRadius, 2)

            let result = ViewshedResult(
                observerLocation: observer,
                observerHeight: obsHeight,
                analysisRadius: maxRadius,
                azimuthResolution: azimuthResolution,
                rangeResolution: 100,
                visibleSectors: sectors,
                totalArea: totalArea,
                visibleArea: totalVisibleArea,
                maxVisibleRange: maxVisibleRange
            )

            DispatchQueue.main.async {
                self.currentViewshed = result
                self.isAnalyzing = false
                self.analysisProgress = 1.0
                completion(result)
            }
        }
    }

    /// Calculate visible range from LOS analysis
    private func calculateVisibleRange(from analysis: LOSAnalysis) -> Double {
        // Find first obstruction point
        if let firstObstruction = analysis.obstructions.first {
            return firstObstruction.distanceFromObserver
        }
        return analysis.totalDistance
    }

    // MARK: - Utility Functions

    /// Calculate distance between two coordinates using Haversine formula
    func calculateDistance(from start: CLLocationCoordinate2D,
                           to end: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let deltaLat = (end.latitude - start.latitude) * .pi / 180
        let deltaLon = (end.longitude - start.longitude) * .pi / 180

        let a = sin(deltaLat/2) * sin(deltaLat/2) +
                cos(lat1) * cos(lat2) * sin(deltaLon/2) * sin(deltaLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))

        return earthRadius * c
    }

    /// Calculate bearing from start to end point
    func calculateBearing(from start: CLLocationCoordinate2D,
                          to end: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let deltaLon = (end.longitude - start.longitude) * .pi / 180

        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)

        var bearing = atan2(y, x) * 180 / .pi
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)

        return bearing
    }

    /// Calculate destination point given start, bearing, and distance
    func calculateDestinationPoint(from start: CLLocationCoordinate2D,
                                    bearing: Double,
                                    distance: Double) -> CLLocationCoordinate2D {
        let lat1 = start.latitude * .pi / 180
        let lon1 = start.longitude * .pi / 180
        let bearingRad = bearing * .pi / 180
        let angularDistance = distance / earthRadius

        let lat2 = asin(sin(lat1) * cos(angularDistance) +
                        cos(lat1) * sin(angularDistance) * cos(bearingRad))

        let lon2 = lon1 + atan2(sin(bearingRad) * sin(angularDistance) * cos(lat1),
                                 cos(angularDistance) - sin(lat1) * sin(lat2))

        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }

    // MARK: - Save/Load

    func saveAnalysis(_ analysis: LOSAnalysis) {
        savedAnalyses.append(analysis)
    }

    func removeAnalysis(_ analysis: LOSAnalysis) {
        savedAnalyses.removeAll { $0.id == analysis.id }
    }

    func clearAllAnalyses() {
        savedAnalyses.removeAll()
        currentAnalysis = nil
        currentViewshed = nil
    }

    // MARK: - Export

    func exportAnalysis(_ analysis: LOSAnalysis) -> String {
        var report = """
        LINE OF SIGHT ANALYSIS REPORT
        ==============================
        Date: \(analysis.createdAt)

        OBSERVER
        Location: \(String(format: "%.6f", analysis.startPoint.latitude)), \(String(format: "%.6f", analysis.startPoint.longitude))
        Height: \(String(format: "%.1f", analysis.observerHeight)) m AGL

        TARGET
        Location: \(String(format: "%.6f", analysis.endPoint.latitude)), \(String(format: "%.6f", analysis.endPoint.longitude))
        Height: \(String(format: "%.1f", analysis.targetHeight)) m AGL

        RESULTS
        Status: \(analysis.result.rawValue)
        Distance: \(String(format: "%.1f", analysis.totalDistance)) m
        Max Terrain Elevation: \(String(format: "%.1f", analysis.maxTerrainElevation)) m
        Minimum Clearance: \(String(format: "%.1f", analysis.minClearance)) m

        """

        if !analysis.obstructions.isEmpty {
            report += """
            OBSTRUCTIONS (\(analysis.obstructions.count) total)

            """

            for (index, obstruction) in analysis.obstructions.prefix(5).enumerated() {
                report += """
                \(index + 1). \(obstruction.type.rawValue)
                   Location: \(String(format: "%.6f", obstruction.location.latitude)), \(String(format: "%.6f", obstruction.location.longitude))
                   Elevation: \(String(format: "%.1f", obstruction.elevation)) m
                   Distance from Observer: \(String(format: "%.1f", obstruction.distanceFromObserver)) m
                   Clearance Deficit: \(String(format: "%.1f", -obstruction.clearanceAvailable)) m

                """
            }
        }

        if let freq = analysis.frequencyMHz {
            report += """
            RADIO PROPAGATION
            Frequency: \(String(format: "%.1f", freq)) MHz
            Fresnel Zone Clearance: \(String(format: "%.1f", analysis.fresnelZoneClearance ?? 0))%
            Path Loss: \(String(format: "%.1f", analysis.pathLossDB ?? 0)) dB
            Estimated Range: \(String(format: "%.1f", (analysis.estimatedRangeMeters ?? 0) / 1000)) km

            """
        }

        return report
    }
}

// MARK: - Supporting Types

enum PropagationEnvironment: String, CaseIterable {
    case freeSpace = "Free Space"
    case suburban = "Suburban"
    case urban = "Urban"
    case denseUrban = "Dense Urban"
    case forest = "Forest"
}

// MARK: - CLLocationCoordinate2D Extension

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
