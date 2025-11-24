//
//  RangeBearingService.swift
//  OmniTAKMobile
//
//  Service for Range & Bearing calculations with support for multiple simultaneous lines
//

import Foundation
import CoreLocation
import Combine
import MapKit

// MARK: - Range & Bearing Line

/// A single Range & Bearing line between two points
struct RangeBearingLine: Identifiable, Equatable {
    let id: UUID
    var origin: CLLocationCoordinate2D
    var destination: CLLocationCoordinate2D
    var timestamp: Date
    var label: String

    // Calculated properties
    var distanceMeters: Double
    var trueBearing: Double // True bearing in degrees (0-360)
    var magneticBearing: Double // Magnetic bearing adjusted for declination
    var backAzimuth: Double // Reverse bearing
    var gridBearing: Double // Grid bearing (used for map grids)

    init(
        id: UUID = UUID(),
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        label: String = "",
        magneticDeclination: Double = 0.0
    ) {
        self.id = id
        self.origin = origin
        self.destination = destination
        self.timestamp = Date()
        self.label = label.isEmpty ? "R&B \(Date().formatted(date: .omitted, time: .shortened))" : label

        // Calculate distance using Vincenty formula via CLLocation
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let destLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        self.distanceMeters = originLocation.distance(from: destLocation)

        // Calculate true bearing using spherical law of sines
        let lat1 = origin.latitude.degreesToRadians
        let lon1 = origin.longitude.degreesToRadians
        let lat2 = destination.latitude.degreesToRadians
        let lon2 = destination.longitude.degreesToRadians
        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearingRadians = atan2(y, x)
        var bearingDegrees = bearingRadians.radiansToDegrees

        // Normalize to 0-360
        bearingDegrees = (bearingDegrees + 360).truncatingRemainder(dividingBy: 360)
        self.trueBearing = bearingDegrees

        // Magnetic bearing = True bearing - Magnetic declination
        // (East declination is positive, West declination is negative)
        var magBearing = bearingDegrees - magneticDeclination
        magBearing = (magBearing + 360).truncatingRemainder(dividingBy: 360)
        self.magneticBearing = magBearing

        // Back azimuth (reverse bearing) = bearing + 180
        var backAz = bearingDegrees + 180.0
        if backAz >= 360.0 {
            backAz -= 360.0
        }
        self.backAzimuth = backAz

        // Grid bearing is typically the same as true bearing for most purposes
        // In production, this would account for grid convergence
        self.gridBearing = bearingDegrees
    }
}

// MARK: - Range & Bearing Configuration

struct RangeBearingConfiguration {
    /// Primary distance unit for display
    var distanceUnit: RangeBearingDistanceUnit = .meters

    /// Bearing format (true vs magnetic)
    var bearingType: RangeBearingBearingType = .magnetic

    /// Line style
    var lineStyle: RangeBearingLineStyle = .solid

    /// Default line color (hex)
    var lineColor: String = "#FF8800" // Orange/amber

    /// Line width
    var lineWidth: CGFloat = 3.0

    /// Show distance label
    var showDistanceLabel: Bool = true

    /// Show bearing label
    var showBearingLabel: Bool = true

    /// Show back azimuth
    var showBackAzimuth: Bool = false

    /// Magnetic declination in degrees (East positive, West negative)
    /// This should be set based on user location
    var magneticDeclination: Double = 0.0
}

enum RangeBearingDistanceUnit: String, CaseIterable {
    case meters = "m"
    case feet = "ft"
    case nauticalMiles = "NM"
    case kilometers = "km"
    case miles = "mi"

    var displayName: String {
        switch self {
        case .meters: return "Meters"
        case .feet: return "Feet"
        case .nauticalMiles: return "Nautical Miles"
        case .kilometers: return "Kilometers"
        case .miles: return "Miles"
        }
    }
}

enum RangeBearingBearingType: String, CaseIterable {
    case magnetic = "MAG"
    case `true` = "TRUE"
    case grid = "GRID"

    var displayName: String {
        switch self {
        case .magnetic: return "Magnetic"
        case .true: return "True"
        case .grid: return "Grid"
        }
    }
}

enum RangeBearingLineStyle: String, CaseIterable {
    case solid
    case dashed

    var displayName: String {
        switch self {
        case .solid: return "Solid"
        case .dashed: return "Dashed"
        }
    }
}

// MARK: - Range & Bearing Service

class RangeBearingService: ObservableObject {

    // MARK: - Published Properties

    @Published var lines: [RangeBearingLine] = []
    @Published var configuration: RangeBearingConfiguration = RangeBearingConfiguration()
    @Published var isCreatingLine: Bool = false
    @Published var temporaryOrigin: CLLocationCoordinate2D?
    @Published var temporaryDestination: CLLocationCoordinate2D?
    @Published var currentUserLocation: CLLocationCoordinate2D?

    // Singleton
    static let shared = RangeBearingService()

    // MARK: - Initialization

    init() {
        // Could load saved lines from persistence here
    }

    // MARK: - Line Management

    /// Add a new R&B line
    func addLine(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, label: String = "") {
        let line = RangeBearingLine(
            origin: origin,
            destination: destination,
            label: label,
            magneticDeclination: configuration.magneticDeclination
        )
        lines.append(line)
        print("Added R&B line: \(line.label), Distance: \(formatDistance(line.distanceMeters)), Bearing: \(formatBearing(line.trueBearing))M")
    }

    /// Remove a specific line
    func removeLine(_ line: RangeBearingLine) {
        lines.removeAll { $0.id == line.id }
    }

    /// Remove line by ID
    func removeLine(id: UUID) {
        lines.removeAll { $0.id == id }
    }

    /// Clear all lines
    func clearAllLines() {
        lines.removeAll()
    }

    /// Update a line's endpoints
    func updateLine(id: UUID, origin: CLLocationCoordinate2D? = nil, destination: CLLocationCoordinate2D? = nil) {
        guard let index = lines.firstIndex(where: { $0.id == id }) else { return }

        let currentLine = lines[index]
        let newOrigin = origin ?? currentLine.origin
        let newDestination = destination ?? currentLine.destination

        let updatedLine = RangeBearingLine(
            id: currentLine.id,
            origin: newOrigin,
            destination: newDestination,
            label: currentLine.label,
            magneticDeclination: configuration.magneticDeclination
        )

        lines[index] = updatedLine
    }

    // MARK: - Interactive Line Creation

    func startCreatingLine(at origin: CLLocationCoordinate2D) {
        isCreatingLine = true
        temporaryOrigin = origin
        temporaryDestination = nil
    }

    func updateTemporaryDestination(_ destination: CLLocationCoordinate2D) {
        guard isCreatingLine else { return }
        temporaryDestination = destination
    }

    func finishCreatingLine(label: String = "") {
        guard isCreatingLine,
              let origin = temporaryOrigin,
              let destination = temporaryDestination else {
            cancelCreatingLine()
            return
        }

        addLine(from: origin, to: destination, label: label)

        isCreatingLine = false
        temporaryOrigin = nil
        temporaryDestination = nil
    }

    func cancelCreatingLine() {
        isCreatingLine = false
        temporaryOrigin = nil
        temporaryDestination = nil
    }

    // MARK: - Quick Calculations

    /// Calculate distance between two points
    func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let location2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return location1.distance(from: location2)
    }

    /// Calculate true bearing between two points
    func calculateTrueBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude.degreesToRadians
        let lon1 = from.longitude.degreesToRadians
        let lat2 = to.latitude.degreesToRadians
        let lon2 = to.longitude.degreesToRadians
        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearingRadians = atan2(y, x)
        let bearingDegrees = bearingRadians.radiansToDegrees

        return (bearingDegrees + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Calculate magnetic bearing between two points
    func calculateMagneticBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let trueBearing = calculateTrueBearing(from: from, to: to)
        let magBearing = trueBearing - configuration.magneticDeclination
        return (magBearing + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Calculate back azimuth
    func calculateBackAzimuth(bearing: Double) -> Double {
        var backAz = bearing + 180.0
        if backAz >= 360.0 {
            backAz -= 360.0
        }
        return backAz
    }

    /// Calculate grid bearing with convergence correction
    func calculateGridBearing(trueBearing: Double, gridConvergence: Double = 0.0) -> Double {
        // Grid bearing = True bearing - Grid convergence
        let gridBearing = trueBearing - gridConvergence
        return (gridBearing + 360).truncatingRemainder(dividingBy: 360)
    }

    // MARK: - Real-Time Updates

    /// Update all lines with new magnetic declination
    func updateMagneticDeclination(_ declination: Double) {
        configuration.magneticDeclination = declination

        // Recalculate all lines with new declination
        for i in 0..<lines.count {
            let line = lines[i]
            let updatedLine = RangeBearingLine(
                id: line.id,
                origin: line.origin,
                destination: line.destination,
                label: line.label,
                magneticDeclination: declination
            )
            lines[i] = updatedLine
        }
    }

    // MARK: - Distance Formatting

    func formatDistance(_ meters: Double) -> String {
        switch configuration.distanceUnit {
        case .meters:
            if meters < 1000 {
                return String(format: "%.1f m", meters)
            } else {
                return String(format: "%.2f km", meters / 1000.0)
            }

        case .feet:
            let feet = meters * 3.28084
            if feet < 5280 {
                return String(format: "%.0f ft", feet)
            } else {
                return String(format: "%.2f mi", feet / 5280.0)
            }

        case .nauticalMiles:
            let nm = meters / 1852.0
            return String(format: "%.2f NM", nm)

        case .kilometers:
            if meters < 1000 {
                return String(format: "%.1f m", meters)
            } else {
                return String(format: "%.2f km", meters / 1000.0)
            }

        case .miles:
            let miles = meters / 1609.344
            return String(format: "%.2f mi", miles)
        }
    }

    // MARK: - Bearing Formatting

    func formatBearing(_ degrees: Double) -> String {
        // Military format: 3-digit bearing
        return String(format: "%03.0f\u{00B0}", degrees)
    }

    func formatBearingWithCardinal(_ degrees: Double) -> String {
        let cardinal = cardinalDirection(for: degrees)
        return String(format: "%03.0f\u{00B0} %@", degrees, cardinal)
    }

    func formatMilsBearing(_ degrees: Double) -> String {
        // NATO standard: 6400 mils = 360 degrees
        let mils = degrees * (6400.0 / 360.0)
        return String(format: "%.0f mils", mils)
    }

    private func cardinalDirection(for degrees: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int(round(degrees / 22.5).truncatingRemainder(dividingBy: 16.0))
        return directions[index]
    }

    // MARK: - Full R&B Description

    func getLineDescription(_ line: RangeBearingLine) -> String {
        let distance = formatDistance(line.distanceMeters)
        let bearing: String

        switch configuration.bearingType {
        case .magnetic:
            bearing = "\(formatBearing(line.magneticBearing))M"
        case .true:
            bearing = "\(formatBearing(line.trueBearing))T"
        case .grid:
            bearing = "\(formatBearing(line.gridBearing))G"
        }

        return "\(distance) @ \(bearing)"
    }

    func getDetailedLineDescription(_ line: RangeBearingLine) -> String {
        var description = """
        Range: \(formatDistance(line.distanceMeters))
        True Bearing: \(formatBearingWithCardinal(line.trueBearing))T
        Magnetic Bearing: \(formatBearingWithCardinal(line.magneticBearing))M
        Back Azimuth: \(formatBearing(line.backAzimuth))
        """

        if configuration.showBackAzimuth {
            description += "\nGrid Bearing: \(formatBearing(line.gridBearing))G"
        }

        return description
    }

    // MARK: - Temporary Line Calculations

    /// Get current temporary line data for display during creation
    func getTemporaryLineData() -> (distance: String, bearing: String)? {
        guard let origin = temporaryOrigin, let destination = temporaryDestination else {
            return nil
        }

        let distance = calculateDistance(from: origin, to: destination)
        let bearing = calculateMagneticBearing(from: origin, to: destination)

        return (formatDistance(distance), "\(formatBearing(bearing))M")
    }
}

// Double extension for degreesToRadians/radiansToDegrees is defined in MeasurementCalculator.swift
