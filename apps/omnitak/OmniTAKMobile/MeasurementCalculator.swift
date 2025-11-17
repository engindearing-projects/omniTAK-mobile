//
//  MeasurementCalculator.swift
//  OmniTAKMobile
//
//  Geodesic calculations for distance, bearing, and area measurements
//

import Foundation
import CoreLocation

// MARK: - Measurement Calculator

class MeasurementCalculator {

    // Earth's mean radius in meters (WGS84)
    static let earthRadiusMeters: Double = 6371000.0

    // MARK: - Distance Calculations

    /// Calculate distance between two points using Haversine formula
    /// More accurate for long distances on a sphere
    static func haversineDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude.degreesToRadians
        let lon1 = from.longitude.degreesToRadians
        let lat2 = to.latitude.degreesToRadians
        let lon2 = to.longitude.degreesToRadians

        let dLat = lat2 - lat1
        let dLon = lon2 - lon1

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadiusMeters * c
    }

    /// Calculate distance using CLLocation (Vincenty formula - most accurate)
    static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let location1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let location2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return location1.distance(from: location2)
    }

    /// Calculate total distance along a path of multiple points
    static func pathDistance(coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count >= 2 else { return 0.0 }

        var totalDistance: Double = 0.0
        for i in 0..<(coordinates.count - 1) {
            totalDistance += distance(from: coordinates[i], to: coordinates[i + 1])
        }
        return totalDistance
    }

    /// Calculate individual segment distances along a path
    static func segmentDistances(coordinates: [CLLocationCoordinate2D]) -> [Double] {
        guard coordinates.count >= 2 else { return [] }

        var distances: [Double] = []
        for i in 0..<(coordinates.count - 1) {
            distances.append(distance(from: coordinates[i], to: coordinates[i + 1]))
        }
        return distances
    }

    // MARK: - Bearing Calculations

    /// Calculate initial bearing (forward azimuth) from point A to point B
    /// Returns bearing in degrees (0-360)
    static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude.degreesToRadians
        let lon1 = from.longitude.degreesToRadians
        let lat2 = to.latitude.degreesToRadians
        let lon2 = to.longitude.degreesToRadians

        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        let bearingRadians = atan2(y, x)
        var bearingDegrees = bearingRadians.radiansToDegrees

        // Normalize to 0-360
        bearingDegrees = (bearingDegrees + 360).truncatingRemainder(dividingBy: 360)

        return bearingDegrees
    }

    /// Calculate back bearing (reverse azimuth)
    static func backBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let forwardBearing = bearing(from: from, to: to)
        var backBearing = forwardBearing + 180.0
        if backBearing >= 360.0 {
            backBearing -= 360.0
        }
        return backBearing
    }

    /// Calculate final bearing at destination
    static func finalBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        // Final bearing is the reverse of the initial bearing from destination to origin
        let reverseBearing = bearing(from: to, to: from)
        var finalBearing = (reverseBearing + 180.0).truncatingRemainder(dividingBy: 360.0)
        return finalBearing
    }

    // MARK: - Area Calculations

    /// Calculate polygon area using spherical excess formula (Girard's theorem)
    /// Returns area in square meters
    static func polygonArea(coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count >= 3 else { return 0.0 }

        // Close the polygon if not already closed
        var coords = coordinates
        if coords.first?.latitude != coords.last?.latitude ||
           coords.first?.longitude != coords.last?.longitude {
            coords.append(coords.first!)
        }

        // Use spherical polygon area formula
        var area: Double = 0.0
        let n = coords.count

        for i in 0..<(n - 1) {
            let p1 = coords[i]
            let p2 = coords[i + 1]

            let lat1 = p1.latitude.degreesToRadians
            let lat2 = p2.latitude.degreesToRadians
            let dLon = (p2.longitude - p1.longitude).degreesToRadians

            area += dLon * (2 + sin(lat1) + sin(lat2))
        }

        area = abs(area * earthRadiusMeters * earthRadiusMeters / 2.0)
        return area
    }

    /// Calculate polygon perimeter
    static func polygonPerimeter(coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count >= 3 else { return 0.0 }

        var perimeter = pathDistance(coordinates: coordinates)

        // Add closing segment if polygon is not closed
        if let first = coordinates.first, let last = coordinates.last {
            if first.latitude != last.latitude || first.longitude != last.longitude {
                perimeter += distance(from: last, to: first)
            }
        }

        return perimeter
    }

    // MARK: - Unit Conversions

    static func metersToKilometers(_ meters: Double) -> Double {
        return meters / 1000.0
    }

    static func metersToMiles(_ meters: Double) -> Double {
        return meters / 1609.344
    }

    static func metersToNauticalMiles(_ meters: Double) -> Double {
        return meters / 1852.0
    }

    static func metersToFeet(_ meters: Double) -> Double {
        return meters * 3.28084
    }

    static func metersToYards(_ meters: Double) -> Double {
        return meters * 1.09361
    }

    static func squareMetersToAcres(_ sqMeters: Double) -> Double {
        return sqMeters / 4046.86
    }

    static func squareMetersToHectares(_ sqMeters: Double) -> Double {
        return sqMeters / 10000.0
    }

    static func squareMetersToSquareMiles(_ sqMeters: Double) -> Double {
        return sqMeters / 2589988.0
    }

    static func squareMetersToSquareKilometers(_ sqMeters: Double) -> Double {
        return sqMeters / 1000000.0
    }

    static func squareMetersToSquareFeet(_ sqMeters: Double) -> Double {
        return sqMeters * 10.7639
    }

    static func degreesToMils(_ degrees: Double) -> Double {
        // NATO standard: 6400 mils = 360 degrees
        return degrees * (6400.0 / 360.0)
    }

    static func degreesToMilsWarsaw(_ degrees: Double) -> Double {
        // Warsaw Pact standard: 6000 mils = 360 degrees
        return degrees * (6000.0 / 360.0)
    }

    // MARK: - Formatting Helpers

    /// Format distance with appropriate unit
    static func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.1f m", meters)
        } else if meters < 10000 {
            return String(format: "%.2f km", meters / 1000.0)
        } else {
            return String(format: "%.1f km", meters / 1000.0)
        }
    }

    /// Format bearing with cardinal direction
    static func formatBearing(_ degrees: Double) -> String {
        let cardinal = cardinalDirection(for: degrees)
        return String(format: "%.1f\u{00B0} %@", degrees, cardinal)
    }

    /// Get cardinal direction from degrees
    static func cardinalDirection(for degrees: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int(round(degrees / 22.5).truncatingRemainder(dividingBy: 16.0))
        return directions[index]
    }

    /// Format area with appropriate unit
    static func formatArea(_ squareMeters: Double) -> String {
        if squareMeters < 10000 {
            return String(format: "%.1f m\u{00B2}", squareMeters)
        } else if squareMeters < 1000000 {
            return String(format: "%.2f ha", squareMeters / 10000.0)
        } else {
            return String(format: "%.2f km\u{00B2}", squareMeters / 1000000.0)
        }
    }

    // MARK: - Complete Measurement Calculation

    /// Calculate all measurements for given points based on measurement type
    static func calculate(type: MeasurementType, points: [CLLocationCoordinate2D]) -> MeasurementResult {
        var result = MeasurementResult.empty()

        switch type {
        case .distance:
            guard points.count >= 2 else { return result }

            let totalDistance = pathDistance(coordinates: points)
            result.distanceMeters = totalDistance
            result.distanceKilometers = metersToKilometers(totalDistance)
            result.distanceMiles = metersToMiles(totalDistance)
            result.distanceNauticalMiles = metersToNauticalMiles(totalDistance)
            result.distanceFeet = metersToFeet(totalDistance)
            result.cumulativeDistance = totalDistance
            result.segmentDistances = segmentDistances(coordinates: points)

        case .bearing:
            guard points.count >= 2 else { return result }

            let from = points[0]
            let to = points[1]
            let bearingDeg = bearing(from: from, to: to)

            result.bearingDegrees = bearingDeg
            result.bearingMils = degreesToMils(bearingDeg)
            result.backBearingDegrees = backBearing(from: from, to: to)

            // Also calculate distance for bearing
            let dist = distance(from: from, to: to)
            result.distanceMeters = dist
            result.distanceMiles = metersToMiles(dist)
            result.distanceNauticalMiles = metersToNauticalMiles(dist)

        case .area:
            guard points.count >= 3 else { return result }

            let areaM2 = polygonArea(coordinates: points)
            result.areaSquareMeters = areaM2
            result.areaAcres = squareMetersToAcres(areaM2)
            result.areaHectares = squareMetersToHectares(areaM2)
            result.areaSquareMiles = squareMetersToSquareMiles(areaM2)
            result.perimeterMeters = polygonPerimeter(coordinates: points)

        case .rangeRing:
            // Range rings don't need calculation, just configuration
            break
        }

        return result
    }
}

// MARK: - Double Extensions for Angle Conversion

extension Double {
    var degreesToRadians: Double {
        return self * .pi / 180.0
    }

    var radiansToDegrees: Double {
        return self * 180.0 / .pi
    }
}

// MARK: - Coordinate String Formatting

extension CLLocationCoordinate2D {
    /// Format as decimal degrees
    func formatDecimalDegrees() -> String {
        let latDir = latitude >= 0 ? "N" : "S"
        let lonDir = longitude >= 0 ? "E" : "W"
        return String(format: "%.6f\u{00B0} %@, %.6f\u{00B0} %@",
                      abs(latitude), latDir, abs(longitude), lonDir)
    }

    /// Format as degrees, minutes, seconds
    func formatDMS() -> String {
        let latDMS = degreesToDMS(latitude)
        let lonDMS = degreesToDMS(longitude)
        let latDir = latitude >= 0 ? "N" : "S"
        let lonDir = longitude >= 0 ? "E" : "W"

        return String(format: "%d\u{00B0}%d'%.2f\"%@ %d\u{00B0}%d'%.2f\"%@",
                      latDMS.degrees, latDMS.minutes, latDMS.seconds, latDir,
                      lonDMS.degrees, lonDMS.minutes, lonDMS.seconds, lonDir)
    }

    private func degreesToDMS(_ value: Double) -> (degrees: Int, minutes: Int, seconds: Double) {
        let absValue = abs(value)
        let degrees = Int(absValue)
        let minutesDecimal = (absValue - Double(degrees)) * 60.0
        let minutes = Int(minutesDecimal)
        let seconds = (minutesDecimal - Double(minutes)) * 60.0
        return (degrees, minutes, seconds)
    }

    /// Format as Military Grid Reference System (MGRS) - simplified
    func formatMGRS() -> String {
        // This is a simplified version - full MGRS requires complex zone calculations
        return String(format: "%.6f, %.6f", latitude, longitude)
    }
}
