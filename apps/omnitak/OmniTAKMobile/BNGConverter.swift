//
//  BNGConverter.swift
//  OmniTAKMobile
//
//  British National Grid (BNG/OSGB) converter
//  Accurate conversion between WGS84 Lat/Lon and British National Grid coordinates
//

import Foundation
import CoreLocation

// MARK: - BNG Converter

class BNGConverter {

    // MARK: - OSGB36 Ellipsoid Constants (Airy 1830)

    private static let a_OSGB: Double = 6377563.396        // Semi-major axis
    private static let b_OSGB: Double = 6356256.909        // Semi-minor axis
    private static let f_OSGB: Double = 1 / 299.3249646    // Flattening
    private static let e2_OSGB: Double = 0.00667054015     // First eccentricity squared

    // MARK: - WGS84 Ellipsoid Constants

    private static let a_WGS84: Double = 6378137.0         // Semi-major axis
    private static let b_WGS84: Double = 6356752.314245    // Semi-minor axis
    private static let f_WGS84: Double = 1 / 298.257223563 // Flattening
    private static let e2_WGS84: Double = 0.00669437999014 // First eccentricity squared

    // MARK: - British National Grid Projection Parameters

    private static let lat0: Double = 49.0 * .pi / 180.0   // True origin latitude (49°N)
    private static let lon0: Double = -2.0 * .pi / 180.0   // True origin longitude (2°W)
    private static let N0: Double = -100000.0              // Northing of true origin
    private static let E0: Double = 400000.0               // Easting of true origin
    private static let F0: Double = 0.9996012717           // Scale factor on central meridian

    // MARK: - Helmert Transform Parameters (WGS84 to OSGB36)

    private static let tx: Double = -446.448               // Translation in X (meters)
    private static let ty: Double = 125.157                // Translation in Y (meters)
    private static let tz: Double = -542.060               // Translation in Z (meters)
    private static let rx: Double = -0.1502 / 3600.0 * .pi / 180.0  // Rotation about X (radians)
    private static let ry: Double = -0.2470 / 3600.0 * .pi / 180.0  // Rotation about Y (radians)
    private static let rz: Double = -0.8421 / 3600.0 * .pi / 180.0  // Rotation about Z (radians)
    private static let s: Double = 20.4894 / 1_000_000.0   // Scale factor (ppm)

    // MARK: - Grid Square Letters

    private static let gridLetters = [
        ["SV", "SW", "SX", "SY", "SZ", "TV", "TW"],
        ["SQ", "SR", "SS", "ST", "SU", "TQ", "TR"],
        ["SL", "SM", "SN", "SO", "SP", "TL", "TM"],
        ["SF", "SG", "SH", "SJ", "SK", "TF", "TG"],
        ["SA", "SB", "SC", "SD", "SE", "TA", "TB"],
        ["NV", "NW", "NX", "NY", "NZ", "OV", "OW"],
        ["NQ", "NR", "NS", "NT", "NU", "OQ", "OR"],
        ["NL", "NM", "NN", "NO", "NP", "OL", "OM"],
        ["NF", "NG", "NH", "NJ", "NK", "OF", "OG"],
        ["NA", "NB", "NC", "ND", "NE", "OA", "OB"],
        ["HV", "HW", "HX", "HY", "HZ", "JV", "JW"],
        ["HQ", "HR", "HS", "HT", "HU", "JQ", "JR"],
        ["HL", "HM", "HN", "HO", "HP", "JL", "JM"]
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

    // MARK: - BNG Coordinate Structure

    struct BNGCoordinate {
        let gridSquare: String
        let easting: Double
        let northing: Double
        let eastingDigits: Int
        let northingDigits: Int
        let precision: Precision

        func formatted(withSpaces: Bool = true) -> String {
            let eastingStr = String(format: "%0\(precision.rawValue)d", eastingDigits)
            let northingStr = String(format: "%0\(precision.rawValue)d", northingDigits)

            if withSpaces {
                return "\(gridSquare) \(eastingStr) \(northingStr)"
            } else {
                return "\(gridSquare)\(eastingStr)\(northingStr)"
            }
        }

        var fullEasting: Double { easting }
        var fullNorthing: Double { northing }
    }

    // MARK: - WGS84 to OSGB36 Datum Conversion

    static func wgs84ToOSGB36(_ wgs84Coord: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let lat = wgs84Coord.latitude * .pi / 180.0
        let lon = wgs84Coord.longitude * .pi / 180.0

        // Convert to Cartesian coordinates (WGS84)
        let sinLat = sin(lat)
        let cosLat = cos(lat)
        let sinLon = sin(lon)
        let cosLon = cos(lon)

        let nu_WGS84 = a_WGS84 / sqrt(1 - e2_WGS84 * sinLat * sinLat)
        let x1 = nu_WGS84 * cosLat * cosLon
        let y1 = nu_WGS84 * cosLat * sinLon
        let z1 = nu_WGS84 * (1 - e2_WGS84) * sinLat

        // Apply Helmert transformation
        let x2 = tx + (1 + s) * x1 + (-rz) * y1 + ry * z1
        let y2 = ty + rz * x1 + (1 + s) * y1 + (-rx) * z1
        let z2 = tz + (-ry) * x1 + rx * y1 + (1 + s) * z1

        // Convert back to latitude/longitude (OSGB36)
        let p = sqrt(x2 * x2 + y2 * y2)
        var lat2 = atan2(z2, p * (1 - e2_OSGB))

        // Iterate to refine latitude
        for _ in 0..<10 {
            let sinLat2 = sin(lat2)
            let nu_OSGB = a_OSGB / sqrt(1 - e2_OSGB * sinLat2 * sinLat2)
            lat2 = atan2(z2 + e2_OSGB * nu_OSGB * sinLat2, p)
        }

        let lon2 = atan2(y2, x2)

        return CLLocationCoordinate2D(
            latitude: lat2 * 180.0 / .pi,
            longitude: lon2 * 180.0 / .pi
        )
    }

    // MARK: - OSGB36 to WGS84 Datum Conversion

    static func osgb36ToWGS84(_ osgb36Coord: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let lat = osgb36Coord.latitude * .pi / 180.0
        let lon = osgb36Coord.longitude * .pi / 180.0

        // Convert to Cartesian coordinates (OSGB36)
        let sinLat = sin(lat)
        let cosLat = cos(lat)
        let sinLon = sin(lon)
        let cosLon = cos(lon)

        let nu_OSGB = a_OSGB / sqrt(1 - e2_OSGB * sinLat * sinLat)
        let x1 = nu_OSGB * cosLat * cosLon
        let y1 = nu_OSGB * cosLat * sinLon
        let z1 = nu_OSGB * (1 - e2_OSGB) * sinLat

        // Apply inverse Helmert transformation
        let x2 = -tx + (1 - s) * x1 + rz * y1 + (-ry) * z1
        let y2 = -ty + (-rz) * x1 + (1 - s) * y1 + rx * z1
        let z2 = -tz + ry * x1 + (-rx) * y1 + (1 - s) * z1

        // Convert back to latitude/longitude (WGS84)
        let p = sqrt(x2 * x2 + y2 * y2)
        var lat2 = atan2(z2, p * (1 - e2_WGS84))

        // Iterate to refine latitude
        for _ in 0..<10 {
            let sinLat2 = sin(lat2)
            let nu_WGS84 = a_WGS84 / sqrt(1 - e2_WGS84 * sinLat2 * sinLat2)
            lat2 = atan2(z2 + e2_WGS84 * nu_WGS84 * sinLat2, p)
        }

        let lon2 = atan2(y2, x2)

        return CLLocationCoordinate2D(
            latitude: lat2 * 180.0 / .pi,
            longitude: lon2 * 180.0 / .pi
        )
    }

    // MARK: - WGS84 Lat/Lon to BNG Conversion

    static func latLonToBNG(_ wgs84Coord: CLLocationCoordinate2D, precision: Precision = .tenMeter) -> BNGCoordinate? {
        // Check if coordinate is within reasonable bounds for UK
        if wgs84Coord.latitude < 49.0 || wgs84Coord.latitude > 61.0 ||
           wgs84Coord.longitude < -9.0 || wgs84Coord.longitude > 2.0 {
            return nil
        }

        // Convert WGS84 to OSGB36
        let osgb36Coord = wgs84ToOSGB36(wgs84Coord)

        // Convert OSGB36 lat/lon to BNG easting/northing
        let lat = osgb36Coord.latitude * .pi / 180.0
        let lon = osgb36Coord.longitude * .pi / 180.0

        let sinLat = sin(lat)
        let cosLat = cos(lat)
        let tanLat = tan(lat)

        let n = (a_OSGB - b_OSGB) / (a_OSGB + b_OSGB)
        let n2 = n * n
        let n3 = n * n * n

        let nu = a_OSGB * F0 / sqrt(1 - e2_OSGB * sinLat * sinLat)
        let rho = a_OSGB * F0 * (1 - e2_OSGB) / pow(1 - e2_OSGB * sinLat * sinLat, 1.5)
        let eta2 = nu / rho - 1

        let Ma = (1 + n + (5.0/4.0) * n2 + (5.0/4.0) * n3) * (lat - lat0)
        let Mb = (3 * n + 3 * n2 + (21.0/8.0) * n3) * sin(lat - lat0) * cos(lat + lat0)
        let Mc = ((15.0/8.0) * n2 + (15.0/8.0) * n3) * sin(2 * (lat - lat0)) * cos(2 * (lat + lat0))
        let Md = (35.0/24.0) * n3 * sin(3 * (lat - lat0)) * cos(3 * (lat + lat0))
        let M = b_OSGB * F0 * (Ma - Mb + Mc - Md)

        let I = M + N0
        let II = (nu / 2) * sinLat * cosLat
        let III = (nu / 24) * sinLat * pow(cosLat, 3) * (5 - tanLat * tanLat + 9 * eta2)
        let IIIA = (nu / 720) * sinLat * pow(cosLat, 5) * (61 - 58 * tanLat * tanLat + pow(tanLat, 4))
        let IV = nu * cosLat
        let V = (nu / 6) * pow(cosLat, 3) * (nu / rho - tanLat * tanLat)
        let VI = (nu / 120) * pow(cosLat, 5) * (5 - 18 * tanLat * tanLat + pow(tanLat, 4) + 14 * eta2 - 58 * tanLat * tanLat * eta2)

        let dLon = lon - lon0

        let northing = I + II * dLon * dLon + III * pow(dLon, 4) + IIIA * pow(dLon, 6)
        let easting = E0 + IV * dLon + V * pow(dLon, 3) + VI * pow(dLon, 5)

        // Check if within valid BNG range
        if easting < 0 || easting > 700000 || northing < 0 || northing > 1300000 {
            return nil
        }

        // Get grid square
        let gridSquare = getGridSquare(easting: easting, northing: northing)

        // Get easting and northing within 100km square
        let eastingRemainder = easting.truncatingRemainder(dividingBy: 100000.0)
        let northingRemainder = northing.truncatingRemainder(dividingBy: 100000.0)

        // Calculate digits at specified precision
        let divisor = pow(10.0, Double(5 - precision.rawValue))
        let eastingDigits = Int(eastingRemainder / divisor)
        let northingDigits = Int(northingRemainder / divisor)

        return BNGCoordinate(
            gridSquare: gridSquare,
            easting: easting,
            northing: northing,
            eastingDigits: eastingDigits,
            northingDigits: northingDigits,
            precision: precision
        )
    }

    // MARK: - BNG to WGS84 Lat/Lon Conversion

    static func bngToLatLon(_ bngString: String) -> CLLocationCoordinate2D? {
        guard let bng = parseBNG(bngString) else {
            return nil
        }
        return bngCoordinateToLatLon(bng)
    }

    static func bngCoordinateToLatLon(_ bng: BNGCoordinate) -> CLLocationCoordinate2D {
        let easting = bng.fullEasting
        let northing = bng.fullNorthing

        let n = (a_OSGB - b_OSGB) / (a_OSGB + b_OSGB)
        let n2 = n * n
        let n3 = n * n * n

        var lat = lat0
        var M: Double = 0

        // Iterate to find latitude
        repeat {
            lat = ((northing - N0) / (a_OSGB * F0) + lat)

            let Ma = (1 + n + (5.0/4.0) * n2 + (5.0/4.0) * n3) * (lat - lat0)
            let Mb = (3 * n + 3 * n2 + (21.0/8.0) * n3) * sin(lat - lat0) * cos(lat + lat0)
            let Mc = ((15.0/8.0) * n2 + (15.0/8.0) * n3) * sin(2 * (lat - lat0)) * cos(2 * (lat + lat0))
            let Md = (35.0/24.0) * n3 * sin(3 * (lat - lat0)) * cos(3 * (lat + lat0))
            M = b_OSGB * F0 * (Ma - Mb + Mc - Md)

        } while northing - N0 - M >= 0.00001

        let sinLat = sin(lat)
        let cosLat = cos(lat)
        let tanLat = tan(lat)

        let nu = a_OSGB * F0 / sqrt(1 - e2_OSGB * sinLat * sinLat)
        let rho = a_OSGB * F0 * (1 - e2_OSGB) / pow(1 - e2_OSGB * sinLat * sinLat, 1.5)
        let eta2 = nu / rho - 1

        let tanLat2 = tanLat * tanLat
        let tanLat4 = tanLat2 * tanLat2
        let tanLat6 = tanLat4 * tanLat2

        let VII = tanLat / (2 * rho * nu)
        let VIII = tanLat / (24 * rho * pow(nu, 3)) * (5 + 3 * tanLat2 + eta2 - 9 * tanLat2 * eta2)
        let IX = tanLat / (720 * rho * pow(nu, 5)) * (61 + 90 * tanLat2 + 45 * tanLat4)
        let X = 1.0 / (cosLat * nu)
        let XI = 1.0 / (cosLat * 6 * pow(nu, 3)) * (nu / rho + 2 * tanLat2)
        let XII = 1.0 / (cosLat * 120 * pow(nu, 5)) * (5 + 28 * tanLat2 + 24 * tanLat4)
        let XIIA = 1.0 / (cosLat * 5040 * pow(nu, 7)) * (61 + 662 * tanLat2 + 1320 * tanLat4 + 720 * tanLat6)

        let dE = easting - E0

        let latOSGB = lat - VII * dE * dE + VIII * pow(dE, 4) - IX * pow(dE, 6)
        let lonOSGB = lon0 + X * dE - XI * pow(dE, 3) + XII * pow(dE, 5) - XIIA * pow(dE, 7)

        let osgb36Coord = CLLocationCoordinate2D(
            latitude: latOSGB * 180.0 / .pi,
            longitude: lonOSGB * 180.0 / .pi
        )

        // Convert OSGB36 to WGS84
        return osgb36ToWGS84(osgb36Coord)
    }

    // MARK: - Grid Square Calculation

    static func getGridSquare(easting: Double, northing: Double) -> String {
        let e100km = Int(easting / 100000.0)
        let n100km = Int(northing / 100000.0)

        if n100km >= 0 && n100km < gridLetters.count && e100km >= 0 && e100km < gridLetters[n100km].count {
            return gridLetters[n100km][e100km]
        }

        return "??"
    }

    // MARK: - BNG String Parsing

    static func parseBNG(_ bngString: String) -> BNGCoordinate? {
        // Remove spaces and convert to uppercase
        let cleaned = bngString.replacingOccurrences(of: " ", with: "").uppercased()

        guard cleaned.count >= 2 else { return nil }

        // Extract grid square (2 letters)
        let gridSquare = String(cleaned.prefix(2))

        // Find grid square position
        var e100km: Int? = nil
        var n100km: Int? = nil

        for (rowIndex, row) in gridLetters.enumerated() {
            if let colIndex = row.firstIndex(of: gridSquare) {
                e100km = colIndex
                n100km = rowIndex
                break
            }
        }

        guard let e100 = e100km, let n100 = n100km else {
            return nil
        }

        // Get numerical location
        let remaining = String(cleaned.dropFirst(2))
        guard remaining.count % 2 == 0 else { return nil }

        let precision: Precision
        let digits = remaining.count / 2

        switch digits {
        case 0: precision = .tenKilometer
        case 1: precision = .tenKilometer
        case 2: precision = .oneKilometer
        case 3: precision = .hundredMeter
        case 4: precision = .tenMeter
        case 5: precision = .oneMeter
        default: return nil
        }

        let eastingDigits: Int
        let northingDigits: Int

        if digits == 0 {
            eastingDigits = 0
            northingDigits = 0
        } else {
            let eastingString = String(remaining.prefix(digits))
            let northingString = String(remaining.suffix(digits))

            guard let e = Int(eastingString), let n = Int(northingString) else {
                return nil
            }

            eastingDigits = e
            northingDigits = n
        }

        // Calculate full easting and northing
        let multiplier = pow(10.0, Double(5 - precision.rawValue))
        let easting = Double(e100) * 100000.0 + Double(eastingDigits) * multiplier + multiplier / 2.0
        let northing = Double(n100) * 100000.0 + Double(northingDigits) * multiplier + multiplier / 2.0

        return BNGCoordinate(
            gridSquare: gridSquare,
            easting: easting,
            northing: northing,
            eastingDigits: eastingDigits,
            northingDigits: northingDigits,
            precision: precision
        )
    }

    // MARK: - Static Formatting Helpers

    static func formatBNG(_ coordinate: CLLocationCoordinate2D, precision: Precision = .tenMeter, withSpaces: Bool = true) -> String {
        guard let bng = latLonToBNG(coordinate, precision: precision) else {
            return "Out of BNG bounds"
        }
        return bng.formatted(withSpaces: withSpaces)
    }

    // MARK: - Validation

    static func isValidBNG(_ bngString: String) -> Bool {
        return parseBNG(bngString) != nil
    }

    static func isWithinBNGBounds(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // BNG is valid for UK mainland and nearby areas
        return coordinate.latitude >= 49.0 && coordinate.latitude <= 61.0 &&
               coordinate.longitude >= -9.0 && coordinate.longitude <= 2.0
    }
}

// MARK: - Extensions

extension CLLocationCoordinate2D {
    /// Convert to BNG string
    func toBNG(precision: BNGConverter.Precision = .tenMeter) -> String {
        BNGConverter.formatBNG(self, precision: precision)
    }

    /// Check if within BNG bounds
    var isWithinBNGBounds: Bool {
        BNGConverter.isWithinBNGBounds(self)
    }
}

extension String {
    /// Convert BNG string to coordinate
    func bngToCoordinate() -> CLLocationCoordinate2D? {
        BNGConverter.bngToLatLon(self)
    }

    /// Check if valid BNG string
    var isValidBNG: Bool {
        BNGConverter.isValidBNG(self)
    }
}
