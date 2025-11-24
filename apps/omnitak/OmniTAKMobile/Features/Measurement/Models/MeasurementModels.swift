//
//  MeasurementModels.swift
//  OmniTAKMobile
//
//  Core data structures for measurement tools
//

import Foundation
import CoreLocation
import MapKit
import UIKit

// MARK: - Measurement Type

enum MeasurementType: String, CaseIterable, Codable {
    case distance = "Distance"
    case bearing = "Bearing"
    case area = "Area"
    case rangeRing = "Range Ring"

    var icon: String {
        switch self {
        case .distance: return "ruler"
        case .bearing: return "location.north.line"
        case .area: return "square.dashed"
        case .rangeRing: return "circle.dashed"
        }
    }

    var displayName: String {
        return rawValue
    }

    var instructions: String {
        switch self {
        case .distance:
            return "Tap map to place points. Distance is calculated along the path."
        case .bearing:
            return "Tap map to set start point, then end point. Bearing is calculated from start to end."
        case .area:
            return "Tap map to create polygon vertices. Minimum 3 points required."
        case .rangeRing:
            return "Tap map to set center point. Configure ring distances in settings."
        }
    }
}

// MARK: - Distance Unit

enum DistanceUnit: String, CaseIterable, Codable {
    case meters = "Meters"
    case kilometers = "Kilometers"
    case feet = "Feet"
    case miles = "Miles"
    case nauticalMiles = "Nautical Miles"
    case yards = "Yards"

    var abbreviation: String {
        switch self {
        case .meters: return "m"
        case .kilometers: return "km"
        case .feet: return "ft"
        case .miles: return "mi"
        case .nauticalMiles: return "NM"
        case .yards: return "yd"
        }
    }

    func fromMeters(_ meters: Double) -> Double {
        switch self {
        case .meters: return meters
        case .kilometers: return meters / 1000.0
        case .feet: return meters * 3.28084
        case .miles: return meters / 1609.344
        case .nauticalMiles: return meters / 1852.0
        case .yards: return meters * 1.09361
        }
    }
}

// MARK: - Area Unit

enum AreaUnit: String, CaseIterable, Codable {
    case squareMeters = "Square Meters"
    case squareKilometers = "Square Kilometers"
    case squareFeet = "Square Feet"
    case squareMiles = "Square Miles"
    case acres = "Acres"
    case hectares = "Hectares"

    var abbreviation: String {
        switch self {
        case .squareMeters: return "m\u{00B2}"
        case .squareKilometers: return "km\u{00B2}"
        case .squareFeet: return "ft\u{00B2}"
        case .squareMiles: return "mi\u{00B2}"
        case .acres: return "ac"
        case .hectares: return "ha"
        }
    }

    func fromSquareMeters(_ sqMeters: Double) -> Double {
        switch self {
        case .squareMeters: return sqMeters
        case .squareKilometers: return sqMeters / 1_000_000.0
        case .squareFeet: return sqMeters * 10.7639
        case .squareMiles: return sqMeters / 2_589_988.0
        case .acres: return sqMeters / 4046.86
        case .hectares: return sqMeters / 10_000.0
        }
    }
}

// MARK: - Bearing Unit

enum BearingUnit: String, CaseIterable, Codable {
    case degrees = "Degrees"
    case mils = "Mils (NATO)"
    case milsWarsaw = "Mils (Warsaw)"

    var abbreviation: String {
        switch self {
        case .degrees: return "\u{00B0}"
        case .mils: return "mil"
        case .milsWarsaw: return "mil"
        }
    }

    func fromDegrees(_ degrees: Double) -> Double {
        switch self {
        case .degrees: return degrees
        case .mils: return degrees * (6400.0 / 360.0) // NATO standard
        case .milsWarsaw: return degrees * (6000.0 / 360.0) // Warsaw Pact
        }
    }
}

// MARK: - Measurement Result

struct MeasurementResult: Codable {
    var distanceMeters: Double?
    var distanceMiles: Double?
    var distanceNauticalMiles: Double?
    var distanceKilometers: Double?
    var distanceFeet: Double?

    var bearingDegrees: Double?
    var bearingMils: Double?
    var backBearingDegrees: Double?

    var areaSquareMeters: Double?
    var areaAcres: Double?
    var areaHectares: Double?
    var areaSquareMiles: Double?

    var perimeterMeters: Double?

    // For multi-segment paths
    var segmentDistances: [Double]?
    var cumulativeDistance: Double?

    static func empty() -> MeasurementResult {
        return MeasurementResult()
    }
}

// MARK: - Measurement

struct Measurement: Identifiable, Codable {
    var id: UUID
    var type: MeasurementType
    var points: [CLLocationCoordinate2D]
    var result: MeasurementResult
    var createdAt: Date
    var name: String
    var color: UIColor

    init(id: UUID = UUID(), type: MeasurementType, points: [CLLocationCoordinate2D] = [], name: String? = nil) {
        self.id = id
        self.type = type
        self.points = points
        self.result = MeasurementResult.empty()
        self.createdAt = Date()
        self.name = name ?? "\(type.displayName) \(id.uuidString.prefix(4))"
        self.color = UIColor(red: 1.0, green: 0.988, blue: 0.0, alpha: 1.0) // FFFC00
    }

    // Codable conformance for CLLocationCoordinate2D and UIColor
    enum CodingKeys: String, CodingKey {
        case id, type, points, result, createdAt, name, colorHex
    }

    struct CoordinatePair: Codable {
        let latitude: Double
        let longitude: Double
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(MeasurementType.self, forKey: .type)
        let pointPairs = try container.decode([CoordinatePair].self, forKey: .points)
        points = pointPairs.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        result = try container.decode(MeasurementResult.self, forKey: .result)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        name = try container.decode(String.self, forKey: .name)

        if let colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) {
            color = UIColor(hexString: colorHex) ?? UIColor(red: 1.0, green: 0.988, blue: 0.0, alpha: 1.0)
        } else {
            color = UIColor(red: 1.0, green: 0.988, blue: 0.0, alpha: 1.0)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        let pointPairs = points.map { CoordinatePair(latitude: $0.latitude, longitude: $0.longitude) }
        try container.encode(pointPairs, forKey: .points)
        try container.encode(result, forKey: .result)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(name, forKey: .name)
        try container.encode(color.toHexString(), forKey: .colorHex)
    }
}

// MARK: - Range Ring

struct RangeRing: Identifiable, Codable {
    var id: UUID
    var center: CLLocationCoordinate2D
    var radiusMeters: Double
    var color: UIColor
    var label: String
    var isVisible: Bool

    init(id: UUID = UUID(), center: CLLocationCoordinate2D, radiusMeters: Double, color: UIColor? = nil, label: String? = nil) {
        self.id = id
        self.center = center
        self.radiusMeters = radiusMeters
        self.color = color ?? UIColor(red: 1.0, green: 0.988, blue: 0.0, alpha: 1.0)
        self.label = label ?? "\(Int(radiusMeters))m"
        self.isVisible = true
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, latitude, longitude, radiusMeters, colorHex, label, isVisible
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        radiusMeters = try container.decode(Double.self, forKey: .radiusMeters)

        if let colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) {
            color = UIColor(hexString: colorHex) ?? UIColor(red: 1.0, green: 0.988, blue: 0.0, alpha: 1.0)
        } else {
            color = UIColor(red: 1.0, green: 0.988, blue: 0.0, alpha: 1.0)
        }

        label = try container.decode(String.self, forKey: .label)
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(center.latitude, forKey: .latitude)
        try container.encode(center.longitude, forKey: .longitude)
        try container.encode(radiusMeters, forKey: .radiusMeters)
        try container.encode(color.toHexString(), forKey: .colorHex)
        try container.encode(label, forKey: .label)
        try container.encode(isVisible, forKey: .isVisible)
    }
}

// MARK: - Range Ring Configuration

struct RangeRingConfiguration: Codable {
    var distances: [Double] // in meters
    var color: UIColor
    var showLabels: Bool
    var lineWidth: CGFloat
    var lineDashPattern: [NSNumber]?

    static func defaultConfiguration() -> RangeRingConfiguration {
        return RangeRingConfiguration(
            distances: [100, 500, 1000, 2000, 5000],
            color: UIColor(red: 1.0, green: 0.988, blue: 0.0, alpha: 1.0),
            showLabels: true,
            lineWidth: 2.0,
            lineDashPattern: [5, 5]
        )
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case distances, colorHex, showLabels, lineWidth, lineDashPattern
    }

    init(distances: [Double], color: UIColor, showLabels: Bool, lineWidth: CGFloat, lineDashPattern: [NSNumber]?) {
        self.distances = distances
        self.color = color
        self.showLabels = showLabels
        self.lineWidth = lineWidth
        self.lineDashPattern = lineDashPattern
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        distances = try container.decode([Double].self, forKey: .distances)

        if let colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) {
            color = UIColor(hexString: colorHex) ?? UIColor(red: 1.0, green: 0.988, blue: 0.0, alpha: 1.0)
        } else {
            color = UIColor(red: 1.0, green: 0.988, blue: 0.0, alpha: 1.0)
        }

        showLabels = try container.decode(Bool.self, forKey: .showLabels)
        lineWidth = try container.decode(CGFloat.self, forKey: .lineWidth)

        if let pattern = try container.decodeIfPresent([Int].self, forKey: .lineDashPattern) {
            lineDashPattern = pattern.map { NSNumber(value: $0) }
        } else {
            lineDashPattern = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(distances, forKey: .distances)
        try container.encode(color.toHexString(), forKey: .colorHex)
        try container.encode(showLabels, forKey: .showLabels)
        try container.encode(lineWidth, forKey: .lineWidth)

        if let pattern = lineDashPattern {
            try container.encode(pattern.map { $0.intValue }, forKey: .lineDashPattern)
        }
    }
}

// MARK: - UIColor Extensions for Codable

extension UIColor {
    convenience init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }

    func toHexString() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        getRed(&r, green: &g, blue: &b, alpha: &a)

        let rgb: Int = (Int)(r * 255) << 16 | (Int)(g * 255) << 8 | (Int)(b * 255) << 0
        return String(format: "#%06x", rgb)
    }
}
