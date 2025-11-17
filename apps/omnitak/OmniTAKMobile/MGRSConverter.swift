//
//  MGRSConverter.swift
//  OmniTAKMobile
//
//  Military Grid Reference System (MGRS) converter
//  Accurate conversion between Lat/Lon, UTM, and MGRS coordinates
//

import Foundation
import CoreLocation

// MARK: - MGRS Converter

class MGRSConverter {

    // MARK: - WGS84 Ellipsoid Constants

    private static let a: Double = 6378137.0           // Semi-major axis
    private static let f: Double = 1 / 298.257223563   // Flattening
    private static let b: Double = 6356752.314245      // Semi-minor axis
    private static let e: Double = 0.08181919084262    // First eccentricity
    private static let e2: Double = 0.00669437999014   // e^2
    private static let ep2: Double = 0.00673949674228  // Second eccentricity squared
    private static let k0: Double = 0.9996             // UTM scale factor

    // MARK: - MGRS Grid Square Letters

    private static let latitudeBands = "CDEFGHJKLMNPQRSTUVWXX"
    private static let setOriginColumnLetters = "AJSAJS"
    private static let setOriginRowLetters = "AFAFAF"

    private static let mgrsColumnLetters = [
        "ABCDEFGH",
        "JKLMNPQR",
        "STUVWXYZ"
    ]

    private static let mgrsRowLetters = [
        "ABCDEFGHJKLMNPQRSTUV",
        "FGHJKLMNPQRSTUVABCDE"
    ]

    // MARK: - Precision Level

    enum Precision: Int {
        case tenKilometer = 1      // 10km (1 digit easting/northing)
        case oneKilometer = 2      // 1km (2 digits)
        case hundredMeter = 3      // 100m (3 digits)
        case tenMeter = 4          // 10m (4 digits)
        case oneMeter = 5          // 1m (5 digits)

        var gridSize: Double {
            switch self {
            case .tenKilometer: return 10000.0
            case .oneKilometer: return 1000.0
            case .hundredMeter: return 100.0
            case .tenMeter: return 10.0
            case .oneMeter: return 1.0
            }
        }
    }

    // MARK: - UTM Coordinate Structure

    struct UTMCoordinate {
        let zone: Int
        let hemisphere: Character  // 'N' or 'S'
        let easting: Double
        let northing: Double
        let latitudeBand: Character

        var description: String {
            String(format: "%02d%@ %06.0fE %07.0fN", zone, String(latitudeBand), easting, northing)
        }
    }

    // MARK: - MGRS Coordinate Structure

    struct MGRSCoordinate {
        let zone: Int
        let band: Character
        let column: Character
        let row: Character
        let easting: Int
        let northing: Int
        let precision: Precision

        var gridZoneDesignator: String {
            String(format: "%02d%@", zone, String(band))
        }

        var squareIdentifier: String {
            "\(column)\(row)"
        }

        func formatted(withSpaces: Bool = true) -> String {
            let eastingStr = String(format: "%0\(precision.rawValue)d", easting)
            let northingStr = String(format: "%0\(precision.rawValue)d", northing)

            if withSpaces {
                return "\(gridZoneDesignator) \(squareIdentifier) \(eastingStr) \(northingStr)"
            } else {
                return "\(gridZoneDesignator)\(squareIdentifier)\(eastingStr)\(northingStr)"
            }
        }
    }

    // MARK: - Lat/Lon to UTM Conversion

    static func latLonToUTM(_ coordinate: CLLocationCoordinate2D) -> UTMCoordinate {
        let lat = coordinate.latitude
        let lon = coordinate.longitude

        // Calculate UTM zone
        var zone = Int((lon + 180.0) / 6.0) + 1

        // Special zones for Norway and Svalbard
        if lat >= 56.0 && lat < 64.0 && lon >= 3.0 && lon < 12.0 {
            zone = 32
        } else if lat >= 72.0 && lat < 84.0 {
            if lon >= 0.0 && lon < 9.0 {
                zone = 31
            } else if lon >= 9.0 && lon < 21.0 {
                zone = 33
            } else if lon >= 21.0 && lon < 33.0 {
                zone = 35
            } else if lon >= 33.0 && lon < 42.0 {
                zone = 37
            }
        }

        let latRad = lat * .pi / 180.0
        let lonRad = lon * .pi / 180.0

        let lonOrigin = Double((zone - 1) * 6 - 180 + 3) * .pi / 180.0

        let N = a / sqrt(1 - e2 * sin(latRad) * sin(latRad))
        let T = tan(latRad) * tan(latRad)
        let C = ep2 * cos(latRad) * cos(latRad)
        let A = cos(latRad) * (lonRad - lonOrigin)

        let M = a * ((1 - e2/4 - 3*e2*e2/64 - 5*e2*e2*e2/256) * latRad
                    - (3*e2/8 + 3*e2*e2/32 + 45*e2*e2*e2/1024) * sin(2*latRad)
                    + (15*e2*e2/256 + 45*e2*e2*e2/1024) * sin(4*latRad)
                    - (35*e2*e2*e2/3072) * sin(6*latRad))

        var easting = k0 * N * (A + (1 - T + C) * pow(A, 3) / 6
                                  + (5 - 18*T + T*T + 72*C - 58*ep2) * pow(A, 5) / 120)
        easting += 500000.0

        var northing = k0 * (M + N * tan(latRad) * (A*A/2 + (5 - T + 9*C + 4*C*C) * pow(A, 4) / 24
                                                     + (61 - 58*T + T*T + 600*C - 330*ep2) * pow(A, 6) / 720))

        let hemisphere: Character = lat >= 0 ? "N" : "S"
        if lat < 0 {
            northing += 10000000.0
        }

        let latBand = getLatitudeBand(lat)

        return UTMCoordinate(zone: zone, hemisphere: hemisphere, easting: easting, northing: northing, latitudeBand: latBand)
    }

    // MARK: - UTM to Lat/Lon Conversion

    static func utmToLatLon(_ utm: UTMCoordinate) -> CLLocationCoordinate2D {
        let x = utm.easting - 500000.0
        var y = utm.northing

        if utm.hemisphere == "S" {
            y -= 10000000.0
        }

        let lonOrigin = Double((utm.zone - 1) * 6 - 180 + 3)

        let e1 = (1 - sqrt(1 - e2)) / (1 + sqrt(1 - e2))
        let M = y / k0
        let mu = M / (a * (1 - e2/4 - 3*e2*e2/64 - 5*e2*e2*e2/256))

        let phi1Rad = mu + (3*e1/2 - 27*pow(e1, 3)/32) * sin(2*mu)
                     + (21*e1*e1/16 - 55*pow(e1, 4)/32) * sin(4*mu)
                     + (151*pow(e1, 3)/96) * sin(6*mu)
                     + (1097*pow(e1, 4)/512) * sin(8*mu)

        let N1 = a / sqrt(1 - e2 * sin(phi1Rad) * sin(phi1Rad))
        let T1 = tan(phi1Rad) * tan(phi1Rad)
        let C1 = ep2 * cos(phi1Rad) * cos(phi1Rad)
        let R1 = a * (1 - e2) / pow(1 - e2 * sin(phi1Rad) * sin(phi1Rad), 1.5)
        let D = x / (N1 * k0)

        let lat = phi1Rad - (N1 * tan(phi1Rad) / R1) * (D*D/2
                    - (5 + 3*T1 + 10*C1 - 4*C1*C1 - 9*ep2) * pow(D, 4) / 24
                    + (61 + 90*T1 + 298*C1 + 45*T1*T1 - 252*ep2 - 3*C1*C1) * pow(D, 6) / 720)

        let lon = (D - (1 + 2*T1 + C1) * pow(D, 3) / 6
                   + (5 - 2*C1 + 28*T1 - 3*C1*C1 + 8*ep2 + 24*T1*T1) * pow(D, 5) / 120) / cos(phi1Rad)

        let latitude = lat * 180.0 / .pi
        let longitude = lonOrigin + lon * 180.0 / .pi

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // MARK: - Lat/Lon to MGRS Conversion

    static func latLonToMGRS(_ coordinate: CLLocationCoordinate2D, precision: Precision = .tenMeter) -> MGRSCoordinate {
        let utm = latLonToUTM(coordinate)
        return utmToMGRS(utm, precision: precision)
    }

    static func utmToMGRS(_ utm: UTMCoordinate, precision: Precision = .tenMeter) -> MGRSCoordinate {
        let setNumber = utm.zone % 6

        // Get 100km square column letter
        let col = Int(utm.easting / 100000.0)
        let colIndex = (col - 1) % 8
        let columnLetter = Array(mgrsColumnLetters[setNumber % 3])[colIndex]

        // Get 100km square row letter
        let row = Int(utm.northing / 100000.0) % 20
        let rowSet = utm.zone % 2 == 0 ? 1 : 0
        let rowLetter = Array(mgrsRowLetters[rowSet])[row]

        // Get easting and northing within 100km square
        let eastingRemainder = utm.easting.truncatingRemainder(dividingBy: 100000.0)
        let northingRemainder = utm.northing.truncatingRemainder(dividingBy: 100000.0)

        // Calculate easting and northing at the specified precision
        let divisor = pow(10.0, Double(5 - precision.rawValue))
        let easting = Int(eastingRemainder / divisor)
        let northing = Int(northingRemainder / divisor)

        return MGRSCoordinate(
            zone: utm.zone,
            band: utm.latitudeBand,
            column: columnLetter,
            row: rowLetter,
            easting: easting,
            northing: northing,
            precision: precision
        )
    }

    // MARK: - MGRS to Lat/Lon Conversion

    static func mgrsToLatLon(_ mgrsString: String) -> CLLocationCoordinate2D? {
        guard let mgrs = parseMGRS(mgrsString) else {
            return nil
        }
        return mgrsCoordinateToLatLon(mgrs)
    }

    static func mgrsCoordinateToLatLon(_ mgrs: MGRSCoordinate) -> CLLocationCoordinate2D {
        let utm = mgrsToUTM(mgrs)
        return utmToLatLon(utm)
    }

    static func mgrsToUTM(_ mgrs: MGRSCoordinate) -> UTMCoordinate {
        let setNumber = mgrs.zone % 6

        // Find column number from letter
        let colIndex = mgrsColumnLetters[setNumber % 3].firstIndex(of: mgrs.column)!
        let col = mgrsColumnLetters[setNumber % 3].distance(from: mgrsColumnLetters[setNumber % 3].startIndex, to: colIndex) + 1

        // Find row number from letter
        let rowSet = mgrs.zone % 2 == 0 ? 1 : 0
        let rowIndex = mgrsRowLetters[rowSet].firstIndex(of: mgrs.row)!
        let row = mgrsRowLetters[rowSet].distance(from: mgrsRowLetters[rowSet].startIndex, to: rowIndex)

        // Calculate easting
        let multiplier = pow(10.0, Double(5 - mgrs.precision.rawValue))
        let easting100km = Double(col) * 100000.0
        let eastingRemainder = Double(mgrs.easting) * multiplier + multiplier / 2.0
        let easting = easting100km + eastingRemainder

        // Calculate northing based on latitude band
        let bandIndex = latitudeBands.firstIndex(of: mgrs.band)!
        let bandNumber = latitudeBands.distance(from: latitudeBands.startIndex, to: bandIndex)

        // Base northing for the latitude band
        let minNorthing = getMinNorthing(bandNumber)

        // Calculate northing
        var northing100km = Double(row) * 100000.0
        let northingRemainder = Double(mgrs.northing) * multiplier + multiplier / 2.0
        var northing = northing100km + northingRemainder

        // Adjust northing to be within the correct latitude band
        while northing < minNorthing {
            northing += 2000000.0
        }

        let hemisphere: Character = mgrs.band >= Character("N") ? "N" : "S"

        return UTMCoordinate(
            zone: mgrs.zone,
            hemisphere: hemisphere,
            easting: easting,
            northing: northing,
            latitudeBand: mgrs.band
        )
    }

    // MARK: - MGRS String Parsing

    static func parseMGRS(_ mgrsString: String) -> MGRSCoordinate? {
        // Remove spaces and convert to uppercase
        let cleaned = mgrsString.replacingOccurrences(of: " ", with: "").uppercased()

        guard cleaned.count >= 5 else { return nil }

        // Extract grid zone designator (2-3 chars: zone number + band letter)
        var index = cleaned.startIndex
        var zoneString = ""

        // Get zone number (1-2 digits)
        while index < cleaned.endIndex && cleaned[index].isNumber {
            zoneString.append(cleaned[index])
            index = cleaned.index(after: index)
            if zoneString.count >= 2 { break }
        }

        guard let zone = Int(zoneString), zone >= 1 && zone <= 60 else {
            return nil
        }

        // Get latitude band
        guard index < cleaned.endIndex else { return nil }
        let band = cleaned[index]
        guard latitudeBands.contains(band) else { return nil }
        index = cleaned.index(after: index)

        // Get 100km square identifier (2 letters)
        guard cleaned.distance(from: index, to: cleaned.endIndex) >= 2 else {
            return nil
        }

        let column = cleaned[index]
        index = cleaned.index(after: index)
        let row = cleaned[index]
        index = cleaned.index(after: index)

        // Get numerical location
        let remaining = String(cleaned[index...])
        guard remaining.count % 2 == 0 else { return nil }

        let precision: Precision
        let digits = remaining.count / 2

        switch digits {
        case 1: precision = .tenKilometer
        case 2: precision = .oneKilometer
        case 3: precision = .hundredMeter
        case 4: precision = .tenMeter
        case 5: precision = .oneMeter
        default: return nil
        }

        let eastingString = String(remaining.prefix(digits))
        let northingString = String(remaining.suffix(digits))

        guard let easting = Int(eastingString),
              let northing = Int(northingString) else {
            return nil
        }

        return MGRSCoordinate(
            zone: zone,
            band: band,
            column: column,
            row: row,
            easting: easting,
            northing: northing,
            precision: precision
        )
    }

    // MARK: - Helper Functions

    static func getLatitudeBand(_ latitude: Double) -> Character {
        if latitude < -80.0 { return "C" }
        if latitude >= 84.0 { return "X" }

        let bandIndex = Int((latitude + 80.0) / 8.0)
        let safeIndex = min(max(bandIndex, 0), latitudeBands.count - 1)
        return Array(latitudeBands)[safeIndex]
    }

    private static func getMinNorthing(_ bandNumber: Int) -> Double {
        // Minimum northing values for each latitude band (Southern Hemisphere)
        let minNorthings: [Double] = [
            1100000, 2000000, 2800000, 3700000, 4600000, 5500000, 6400000, 7300000, 8200000, 9100000,  // C-M
            0, 800000, 1700000, 2600000, 3500000, 4400000, 5300000, 6200000, 7000000, 7900000  // N-X
        ]

        if bandNumber >= 0 && bandNumber < minNorthings.count {
            return minNorthings[bandNumber]
        }
        return 0
    }

    // MARK: - Static Formatting Helpers

    static func formatLatLon(_ coordinate: CLLocationCoordinate2D, style: LatLonStyle = .decimalDegrees) -> String {
        switch style {
        case .decimalDegrees:
            return String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)

        case .degreesMinutes:
            let latDir = coordinate.latitude >= 0 ? "N" : "S"
            let lonDir = coordinate.longitude >= 0 ? "E" : "W"
            let lat = abs(coordinate.latitude)
            let lon = abs(coordinate.longitude)

            let latDeg = Int(lat)
            let latMin = (lat - Double(latDeg)) * 60.0
            let lonDeg = Int(lon)
            let lonMin = (lon - Double(lonDeg)) * 60.0

            return String(format: "%d\u{00B0}%.4f'%@ %d\u{00B0}%.4f'%@",
                         latDeg, latMin, latDir, lonDeg, lonMin, lonDir)

        case .degreesMinutesSeconds:
            let latDir = coordinate.latitude >= 0 ? "N" : "S"
            let lonDir = coordinate.longitude >= 0 ? "E" : "W"
            let lat = abs(coordinate.latitude)
            let lon = abs(coordinate.longitude)

            let latDeg = Int(lat)
            let latMin = Int((lat - Double(latDeg)) * 60.0)
            let latSec = ((lat - Double(latDeg)) * 60.0 - Double(latMin)) * 60.0

            let lonDeg = Int(lon)
            let lonMin = Int((lon - Double(lonDeg)) * 60.0)
            let lonSec = ((lon - Double(lonDeg)) * 60.0 - Double(lonMin)) * 60.0

            return String(format: "%d\u{00B0}%d'%.2f\"%@ %d\u{00B0}%d'%.2f\"%@",
                         latDeg, latMin, latSec, latDir, lonDeg, lonMin, lonSec, lonDir)
        }
    }

    static func formatMGRS(_ coordinate: CLLocationCoordinate2D, precision: Precision = .tenMeter, withSpaces: Bool = true) -> String {
        let mgrs = latLonToMGRS(coordinate, precision: precision)
        return mgrs.formatted(withSpaces: withSpaces)
    }

    static func formatUTM(_ coordinate: CLLocationCoordinate2D) -> String {
        let utm = latLonToUTM(coordinate)
        return utm.description
    }

    // MARK: - Validation

    static func isValidMGRS(_ mgrsString: String) -> Bool {
        return parseMGRS(mgrsString) != nil
    }

    static func isValidLatLon(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return coordinate.latitude >= -90.0 && coordinate.latitude <= 90.0
            && coordinate.longitude >= -180.0 && coordinate.longitude <= 180.0
    }

    static func isWithinMGRSBounds(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // MGRS is defined for latitudes between 80S and 84N
        return coordinate.latitude >= -80.0 && coordinate.latitude <= 84.0
    }

    // MARK: - Grid Zone Information

    static func getGridZoneDesignator(_ coordinate: CLLocationCoordinate2D) -> String {
        let utm = latLonToUTM(coordinate)
        return String(format: "%02d%@", utm.zone, String(utm.latitudeBand))
    }

    static func get100kmSquareID(_ coordinate: CLLocationCoordinate2D) -> String {
        let mgrs = latLonToMGRS(coordinate, precision: .oneMeter)
        return mgrs.squareIdentifier
    }

    // MARK: - Distance Calculations

    static func distanceBetweenMGRS(_ mgrs1: String, _ mgrs2: String) -> Double? {
        guard let coord1 = mgrsToLatLon(mgrs1),
              let coord2 = mgrsToLatLon(mgrs2) else {
            return nil
        }

        let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)

        return location1.distance(from: location2)
    }

    // MARK: - Supporting Types

    enum LatLonStyle {
        case decimalDegrees          // 38.897700, -77.036500
        case degreesMinutes          // 38°53.8620'N 77°02.1900'W
        case degreesMinutesSeconds   // 38°53'51.72"N 77°02'11.40"W
    }
}

// MARK: - Extensions

extension CLLocationCoordinate2D {
    /// Convert to MGRS string
    func toMGRS(precision: MGRSConverter.Precision = .tenMeter) -> String {
        MGRSConverter.formatMGRS(self, precision: precision)
    }

    /// Convert to UTM string
    func toUTM() -> String {
        MGRSConverter.formatUTM(self)
    }

    /// Get grid zone designator
    var gridZoneDesignator: String {
        MGRSConverter.getGridZoneDesignator(self)
    }

    /// Get 100km square identifier
    var mgrs100kmSquare: String {
        MGRSConverter.get100kmSquareID(self)
    }
}

extension String {
    /// Convert MGRS string to coordinate
    func toCoordinate() -> CLLocationCoordinate2D? {
        MGRSConverter.mgrsToLatLon(self)
    }

    /// Check if valid MGRS string
    var isValidMGRS: Bool {
        MGRSConverter.isValidMGRS(self)
    }
}
