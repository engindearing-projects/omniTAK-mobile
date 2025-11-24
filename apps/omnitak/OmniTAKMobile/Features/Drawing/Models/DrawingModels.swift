import Foundation
import MapKit
import CoreLocation
import SwiftUI

// MARK: - Drawing Protocol

protocol DrawingObject: Identifiable, Codable {
    var id: UUID { get }
    var name: String { get set }
    var color: DrawingColor { get set }
    var createdAt: Date { get }
    var coordinates: [CLLocationCoordinate2D] { get }

    func createOverlay() -> MKOverlay
}

// MARK: - Drawing Mode

enum DrawingMode: String, CaseIterable {
    case marker = "Marker"
    case line = "Line"
    case circle = "Circle"
    case polygon = "Polygon"

    var icon: String {
        switch self {
        case .marker: return "mappin.circle.fill"
        case .line: return "line.diagonal"
        case .circle: return "circle"
        case .polygon: return "pentagon"
        }
    }

    var displayName: String {
        switch self {
        case .marker: return "Marker"
        case .line: return "Line/Polyline"
        case .circle: return "Circle"
        case .polygon: return "Polygon"
        }
    }
}

// MARK: - Drawing Color

enum DrawingColor: String, CaseIterable, Codable {
    case red = "Red"
    case blue = "Blue"
    case green = "Green"
    case yellow = "Yellow"
    case orange = "Orange"
    case purple = "Purple"
    case cyan = "Cyan"
    case white = "White"

    var uiColor: UIColor {
        switch self {
        case .red: return .systemRed
        case .blue: return .systemBlue
        case .green: return .systemGreen
        case .yellow: return .systemYellow
        case .orange: return .systemOrange
        case .purple: return .systemPurple
        case .cyan: return .systemCyan
        case .white: return .white
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .red: return .red
        case .blue: return .blue
        case .green: return .green
        case .yellow: return .yellow
        case .orange: return .orange
        case .purple: return .purple
        case .cyan: return .cyan
        case .white: return .white
        }
    }
}

// MARK: - Marker Drawing

struct MarkerDrawing: DrawingObject {
    let id: UUID
    var name: String
    var label: String  // User-editable label for marker
    var color: DrawingColor
    let createdAt: Date
    let coordinate: CLLocationCoordinate2D

    var coordinates: [CLLocationCoordinate2D] {
        [coordinate]
    }

    init(id: UUID = UUID(), name: String, label: String? = nil, color: DrawingColor, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.name = name
        self.label = label ?? name  // Default label to name if not provided
        self.color = color
        self.createdAt = Date()
        self.coordinate = coordinate
    }

    func createOverlay() -> MKOverlay {
        // Markers don't use overlays, they use annotations
        // Return a small circle for compatibility
        return MKCircle(center: coordinate, radius: 1)
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, name, label, color, createdAt, latitude, longitude
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        // Backwards compatibility - if label doesn't exist, use name
        label = (try? container.decode(String.self, forKey: .label)) ?? name
        color = try container.decode(DrawingColor.self, forKey: .color)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(label, forKey: .label)
        try container.encode(color, forKey: .color)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
    }
}

// MARK: - Line Drawing (Polyline)

struct LineDrawing: DrawingObject {
    let id: UUID
    var name: String
    var label: String  // User-editable label
    var color: DrawingColor
    let createdAt: Date
    var coordinates: [CLLocationCoordinate2D]

    init(id: UUID = UUID(), name: String, label: String? = nil, color: DrawingColor, coordinates: [CLLocationCoordinate2D]) {
        self.id = id
        self.name = name
        self.label = label ?? name
        self.color = color
        self.createdAt = Date()
        self.coordinates = coordinates
    }

    func createOverlay() -> MKOverlay {
        return MKPolyline(coordinates: coordinates, count: coordinates.count)
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, name, label, color, createdAt, points
    }

    struct CoordinatePair: Codable {
        let latitude: Double
        let longitude: Double
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        label = (try? container.decode(String.self, forKey: .label)) ?? name
        color = try container.decode(DrawingColor.self, forKey: .color)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        let points = try container.decode([CoordinatePair].self, forKey: .points)
        coordinates = points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(label, forKey: .label)
        try container.encode(color, forKey: .color)
        try container.encode(createdAt, forKey: .createdAt)
        let points = coordinates.map { CoordinatePair(latitude: $0.latitude, longitude: $0.longitude) }
        try container.encode(points, forKey: .points)
    }
}

// MARK: - Circle Drawing

struct CircleDrawing: DrawingObject {
    let id: UUID
    var name: String
    var label: String  // User-editable label
    var color: DrawingColor
    let createdAt: Date
    let center: CLLocationCoordinate2D
    let radius: CLLocationDistance

    var coordinates: [CLLocationCoordinate2D] {
        [center]
    }

    init(id: UUID = UUID(), name: String, label: String? = nil, color: DrawingColor, center: CLLocationCoordinate2D, radius: CLLocationDistance) {
        self.id = id
        self.name = name
        self.label = label ?? name
        self.color = color
        self.createdAt = Date()
        self.center = center
        self.radius = radius
    }

    func createOverlay() -> MKOverlay {
        return MKCircle(center: center, radius: radius)
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, name, label, color, createdAt, latitude, longitude, radius
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        label = (try? container.decode(String.self, forKey: .label)) ?? name
        color = try container.decode(DrawingColor.self, forKey: .color)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        radius = try container.decode(CLLocationDistance.self, forKey: .radius)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(label, forKey: .label)
        try container.encode(color, forKey: .color)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(center.latitude, forKey: .latitude)
        try container.encode(center.longitude, forKey: .longitude)
        try container.encode(radius, forKey: .radius)
    }
}

// MARK: - Polygon Drawing

struct PolygonDrawing: DrawingObject {
    let id: UUID
    var name: String
    var label: String  // User-editable label
    var color: DrawingColor
    let createdAt: Date
    var coordinates: [CLLocationCoordinate2D]

    init(id: UUID = UUID(), name: String, label: String? = nil, color: DrawingColor, coordinates: [CLLocationCoordinate2D]) {
        self.id = id
        self.name = name
        self.label = label ?? name
        self.color = color
        self.createdAt = Date()
        self.coordinates = coordinates
    }

    func createOverlay() -> MKOverlay {
        return MKPolygon(coordinates: coordinates, count: coordinates.count)
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id, name, label, color, createdAt, points
    }

    struct CoordinatePair: Codable {
        let latitude: Double
        let longitude: Double
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        label = (try? container.decode(String.self, forKey: .label)) ?? name
        color = try container.decode(DrawingColor.self, forKey: .color)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        let points = try container.decode([CoordinatePair].self, forKey: .points)
        coordinates = points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(label, forKey: .label)
        try container.encode(color, forKey: .color)
        try container.encode(createdAt, forKey: .createdAt)
        let points = coordinates.map { CoordinatePair(latitude: $0.latitude, longitude: $0.longitude) }
        try container.encode(points, forKey: .points)
    }
}

// MARK: - CLLocationCoordinate2D Extensions

// Helper function to calculate distance between two coordinates
extension CLLocationCoordinate2D {
    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let to = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return from.distance(from: to)
    }
}
