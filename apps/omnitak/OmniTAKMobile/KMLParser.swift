//
//  KMLParser.swift
//  OmniTAKMobile
//
//  KML file parser for importing geospatial data
//

import Foundation
import MapKit
import CoreLocation

// MARK: - KML Data Models

struct KMLDocument: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var description: String?
    var fileName: String
    var importDate: Date = Date()
    var isVisible: Bool = true
    var placemarks: [KMLPlacemark] = []
    var styles: [String: KMLStyle] = [:]
    var folders: [KMLFolder] = []
}

struct KMLFolder: Codable {
    var id: UUID = UUID()
    var name: String
    var description: String?
    var placemarks: [KMLPlacemark] = []
}

struct KMLPlacemark: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var description: String?
    var styleUrl: String?
    var geometry: KMLGeometry
}

enum KMLGeometry: Codable {
    case point(KMLPoint)
    case lineString(KMLLineString)
    case polygon(KMLPolygon)
    case multiGeometry([KMLGeometry])

    private enum CodingKeys: String, CodingKey {
        case type, point, lineString, polygon, multiGeometry
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "point":
            let point = try container.decode(KMLPoint.self, forKey: .point)
            self = .point(point)
        case "lineString":
            let line = try container.decode(KMLLineString.self, forKey: .lineString)
            self = .lineString(line)
        case "polygon":
            let poly = try container.decode(KMLPolygon.self, forKey: .polygon)
            self = .polygon(poly)
        case "multiGeometry":
            let multi = try container.decode([KMLGeometry].self, forKey: .multiGeometry)
            self = .multiGeometry(multi)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown geometry type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .point(let point):
            try container.encode("point", forKey: .type)
            try container.encode(point, forKey: .point)
        case .lineString(let line):
            try container.encode("lineString", forKey: .type)
            try container.encode(line, forKey: .lineString)
        case .polygon(let poly):
            try container.encode("polygon", forKey: .type)
            try container.encode(poly, forKey: .polygon)
        case .multiGeometry(let multi):
            try container.encode("multiGeometry", forKey: .type)
            try container.encode(multi, forKey: .multiGeometry)
        }
    }
}

struct KMLPoint: Codable {
    var latitude: Double
    var longitude: Double
    var altitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct KMLLineString: Codable {
    var coordinates: [KMLPoint]

    var mapCoordinates: [CLLocationCoordinate2D] {
        coordinates.map { $0.coordinate }
    }
}

struct KMLPolygon: Codable {
    var outerBoundary: [KMLPoint]
    var innerBoundaries: [[KMLPoint]] = []

    var outerCoordinates: [CLLocationCoordinate2D] {
        outerBoundary.map { $0.coordinate }
    }
}

struct KMLStyle: Codable {
    var id: String
    var iconUrl: String?
    var iconScale: Double?
    var lineColor: String? // AABBGGRR format
    var lineWidth: Double?
    var polyColor: String? // AABBGGRR format
    var polyFill: Bool?
    var polyOutline: Bool?
}

// MARK: - KML Parser

class KMLParser: NSObject, XMLParserDelegate {

    private var currentElement: String = ""
    private var currentText: String = ""

    // Document parsing state
    private var document: KMLDocument
    private var currentPlacemark: KMLPlacemark?
    private var currentFolder: KMLFolder?
    private var currentStyle: KMLStyle?
    private var currentStyleId: String?

    // Geometry parsing state
    private var currentGeometry: KMLGeometry?
    private var currentCoordinates: String = ""
    private var isInOuterBoundary = false
    private var isInInnerBoundary = false
    private var innerBoundaries: [[KMLPoint]] = []
    private var multiGeometries: [KMLGeometry] = []
    private var geometryStack: [String] = []

    // Style parsing state
    private var isInLineStyle = false
    private var isInPolyStyle = false
    private var isInIconStyle = false

    private var parseError: Error?

    init(fileName: String) {
        self.document = KMLDocument(name: fileName, fileName: fileName)
        super.init()
    }

    func parse(data: Data) throws -> KMLDocument {
        let parser = XMLParser(data: data)
        parser.delegate = self

        let success = parser.parse()

        if let error = parseError {
            throw error
        }

        if !success, let error = parser.parserError {
            throw error
        }

        return document
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName
        currentText = ""

        switch elementName {
        case "Document":
            // Document already initialized
            break

        case "Folder":
            currentFolder = KMLFolder(name: "Folder")

        case "Placemark":
            currentPlacemark = KMLPlacemark(name: "Placemark", geometry: .point(KMLPoint(latitude: 0, longitude: 0, altitude: 0)))

        case "Style":
            if let id = attributeDict["id"] {
                currentStyleId = id
                currentStyle = KMLStyle(id: id)
            }

        case "IconStyle":
            isInIconStyle = true

        case "LineStyle":
            isInLineStyle = true

        case "PolyStyle":
            isInPolyStyle = true

        case "Point":
            geometryStack.append("Point")

        case "LineString":
            geometryStack.append("LineString")

        case "Polygon":
            geometryStack.append("Polygon")
            innerBoundaries = []

        case "MultiGeometry":
            geometryStack.append("MultiGeometry")
            multiGeometries = []

        case "outerBoundaryIs":
            isInOuterBoundary = true

        case "innerBoundaryIs":
            isInInnerBoundary = true

        case "coordinates":
            currentCoordinates = ""

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "name":
            if currentPlacemark != nil {
                currentPlacemark?.name = trimmedText
            } else if currentFolder != nil {
                currentFolder?.name = trimmedText
            } else if currentStyle == nil {
                document.name = trimmedText
            }

        case "description":
            if currentPlacemark != nil {
                currentPlacemark?.description = trimmedText
            } else if currentFolder != nil {
                currentFolder?.description = trimmedText
            } else {
                document.description = trimmedText
            }

        case "styleUrl":
            currentPlacemark?.styleUrl = trimmedText

        case "coordinates":
            currentCoordinates = trimmedText

        case "Point":
            if let coords = parseCoordinateString(currentCoordinates).first {
                let geometry: KMLGeometry = .point(coords)
                handleGeometryEnd(geometry)
            }
            geometryStack.removeLast()

        case "LineString":
            let coords = parseCoordinateString(currentCoordinates)
            let geometry: KMLGeometry = .lineString(KMLLineString(coordinates: coords))
            handleGeometryEnd(geometry)
            geometryStack.removeLast()

        case "Polygon":
            let outerCoords = parseCoordinateString(currentCoordinates)
            let geometry: KMLGeometry = .polygon(KMLPolygon(outerBoundary: outerCoords, innerBoundaries: innerBoundaries))
            handleGeometryEnd(geometry)
            geometryStack.removeLast()

        case "MultiGeometry":
            let geometry: KMLGeometry = .multiGeometry(multiGeometries)
            handleGeometryEnd(geometry)
            geometryStack.removeLast()
            multiGeometries = []

        case "outerBoundaryIs":
            isInOuterBoundary = false

        case "innerBoundaryIs":
            if isInInnerBoundary {
                let innerCoords = parseCoordinateString(currentCoordinates)
                innerBoundaries.append(innerCoords)
            }
            isInInnerBoundary = false

        case "Placemark":
            if let placemark = currentPlacemark {
                if currentFolder != nil {
                    currentFolder?.placemarks.append(placemark)
                } else {
                    document.placemarks.append(placemark)
                }
            }
            currentPlacemark = nil

        case "Folder":
            if let folder = currentFolder {
                document.folders.append(folder)
            }
            currentFolder = nil

        // Style parsing
        case "href":
            if isInIconStyle {
                currentStyle?.iconUrl = trimmedText
            }

        case "scale":
            if isInIconStyle, let scale = Double(trimmedText) {
                currentStyle?.iconScale = scale
            }

        case "color":
            if isInLineStyle {
                currentStyle?.lineColor = trimmedText
            } else if isInPolyStyle {
                currentStyle?.polyColor = trimmedText
            }

        case "width":
            if isInLineStyle, let width = Double(trimmedText) {
                currentStyle?.lineWidth = width
            }

        case "fill":
            if isInPolyStyle {
                currentStyle?.polyFill = trimmedText == "1"
            }

        case "outline":
            if isInPolyStyle {
                currentStyle?.polyOutline = trimmedText == "1"
            }

        case "IconStyle":
            isInIconStyle = false

        case "LineStyle":
            isInLineStyle = false

        case "PolyStyle":
            isInPolyStyle = false

        case "Style":
            if let style = currentStyle, let id = currentStyleId {
                document.styles[id] = style
            }
            currentStyle = nil
            currentStyleId = nil

        default:
            break
        }

        currentText = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }

    // MARK: - Helper Methods

    private func handleGeometryEnd(_ geometry: KMLGeometry) {
        if geometryStack.count > 1 && geometryStack[geometryStack.count - 2] == "MultiGeometry" {
            multiGeometries.append(geometry)
        } else {
            currentPlacemark?.geometry = geometry
        }
    }

    private func parseCoordinateString(_ coordString: String) -> [KMLPoint] {
        // KML coordinates are in "lon,lat,alt" format, space or newline separated
        let trimmed = coordString.trimmingCharacters(in: .whitespacesAndNewlines)
        let coordPairs = trimmed.components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var points: [KMLPoint] = []

        for pair in coordPairs {
            let components = pair.split(separator: ",")
            if components.count >= 2,
               let lon = Double(components[0]),
               let lat = Double(components[1]) {
                let alt = components.count >= 3 ? Double(components[2]) ?? 0 : 0
                points.append(KMLPoint(latitude: lat, longitude: lon, altitude: alt))
            }
        }

        return points
    }
}

// MARK: - KML Color Conversion

extension KMLStyle {
    /// Convert KML AABBGGRR color format to UIColor
    func lineUIColor() -> UIColor? {
        guard let colorString = lineColor else { return nil }
        return kmlColorToUIColor(colorString)
    }

    func polyUIColor() -> UIColor? {
        guard let colorString = polyColor else { return nil }
        return kmlColorToUIColor(colorString)
    }

    private func kmlColorToUIColor(_ kmlColor: String) -> UIColor? {
        // KML color format: AABBGGRR (alpha, blue, green, red)
        let hex = kmlColor.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard hex.count == 8 else { return nil }

        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a = CGFloat((int >> 24) & 0xFF) / 255.0
        let b = CGFloat((int >> 16) & 0xFF) / 255.0
        let g = CGFloat((int >> 8) & 0xFF) / 255.0
        let r = CGFloat(int & 0xFF) / 255.0

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
