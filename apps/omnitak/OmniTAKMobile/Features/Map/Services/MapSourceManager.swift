//
//  MapSourceManager.swift
//  OmniTAKMobile
//
//  Custom map source management and import service
//  Supports importing map sources from XML configuration files
//  Compatible with TAK/ATAK map source format
//

import Foundation
import MapKit
import Combine

// MARK: - Map Source Models

struct CustomMapSource: Identifiable, Codable {
    let id: UUID
    var name: String
    var url: String
    var minZoom: Int
    var maxZoom: Int
    var tileType: String
    var isVisible: Bool
    var updateFrequency: String?
    var backgroundColor: String?
    var opacity: Double
    var importDate: Date

    init(id: UUID = UUID(), name: String, url: String, minZoom: Int = 0, maxZoom: Int = 22, tileType: String = "png", isVisible: Bool = true, updateFrequency: String? = nil, backgroundColor: String? = nil, opacity: Double = 1.0) {
        self.id = id
        self.name = name
        self.url = url
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.tileType = tileType
        self.isVisible = isVisible
        self.updateFrequency = updateFrequency
        self.backgroundColor = backgroundColor
        self.opacity = opacity
        self.importDate = Date()
    }

    /// Convert URL template to MKTileOverlay format
    /// TAK uses {$z}/{$x}/{$y} or {z}/{x}/{y}, MapKit uses {z}, {x}, {y}
    var mapKitURL: String {
        var converted = url
        converted = converted.replacingOccurrences(of: "{$z}", with: "{z}")
        converted = converted.replacingOccurrences(of: "{$x}", with: "{x}")
        converted = converted.replacingOccurrences(of: "{$y}", with: "{y}")
        return converted
    }

    /// Create MKTileOverlay from this source
    func createTileOverlay() -> MKTileOverlay {
        let overlay = MKTileOverlay(urlTemplate: mapKitURL)
        overlay.minimumZ = minZoom
        overlay.maximumZ = maxZoom
        overlay.canReplaceMapContent = false
        return overlay
    }
}

// MARK: - Map Source Parser

struct MapSourceParser {
    /// Parse a custom map source XML file
    static func parse(xmlString: String) -> CustomMapSource? {
        var name: String?
        var url: String?
        var minZoom: Int = 0
        var maxZoom: Int = 22
        var tileType: String = "png"
        var updateFrequency: String?
        var backgroundColor: String?

        // Parse name
        if let nameMatch = extractTag("name", from: xmlString) {
            name = nameMatch
        }

        // Parse URL
        if let urlMatch = extractTag("url", from: xmlString) {
            url = urlMatch
        }

        // Parse zoom levels
        if let minZoomStr = extractTag("minZoom", from: xmlString),
           let minZoomInt = Int(minZoomStr) {
            minZoom = minZoomInt
        }

        if let maxZoomStr = extractTag("maxZoom", from: xmlString),
           let maxZoomInt = Int(maxZoomStr) {
            maxZoom = maxZoomInt
        }

        // Parse tile type
        if let tileTypeMatch = extractTag("tileType", from: xmlString) {
            tileType = tileTypeMatch
        }

        // Parse update frequency
        updateFrequency = extractTag("tileUpdate", from: xmlString)

        // Parse background color
        backgroundColor = extractTag("backgroundColor", from: xmlString)

        // Validate required fields
        guard let sourceName = name, let sourceURL = url else {
            return nil
        }

        return CustomMapSource(
            name: sourceName,
            url: sourceURL,
            minZoom: minZoom,
            maxZoom: maxZoom,
            tileType: tileType,
            isVisible: true,
            updateFrequency: updateFrequency,
            backgroundColor: backgroundColor
        )
    }

    /// Parse TAK data package map source XML format
    static func parseDataPackageFormat(xmlString: String) -> CustomMapSource? {
        // TAK data packages use <customMapSource> element
        guard xmlString.contains("customMapSource") || xmlString.contains("CustomMapSource") else {
            return parse(xmlString: xmlString)
        }

        return parse(xmlString: xmlString)
    }

    private static func extractTag(_ tagName: String, from xml: String) -> String? {
        // Try self-closing tag first: <tagName>value</tagName>
        let pattern = "<\(tagName)>([^<]*)</\(tagName)>"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: xml, options: [], range: NSRange(xml.startIndex..., in: xml)),
           let range = Range(match.range(at: 1), in: xml) {
            return String(xml[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try attribute format: tagName="value"
        let attrPattern = "\(tagName)\\s*=\\s*\"([^\"]*)\""
        if let regex = try? NSRegularExpression(pattern: attrPattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: xml, options: [], range: NSRange(xml.startIndex..., in: xml)),
           let range = Range(match.range(at: 1), in: xml) {
            return String(xml[range])
        }

        return nil
    }
}

// MARK: - Map Source Manager

@MainActor
class MapSourceManager: ObservableObject {
    static let shared = MapSourceManager()

    // MARK: - Published Properties

    @Published var mapSources: [CustomMapSource] = []
    @Published var activeOverlays: [UUID: MKTileOverlay] = [:]
    @Published var isLoading: Bool = false
    @Published var lastError: String?

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private let sourcesKey = "custom_map_sources"
    private weak var mapView: MKMapView?

    // MARK: - Built-in Map Sources

    static let builtInSources: [CustomMapSource] = [
        CustomMapSource(
            name: "OpenStreetMap",
            url: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            minZoom: 0,
            maxZoom: 19,
            tileType: "png"
        ),
        CustomMapSource(
            name: "OpenTopoMap",
            url: "https://a.tile.opentopomap.org/{z}/{x}/{y}.png",
            minZoom: 0,
            maxZoom: 17,
            tileType: "png"
        ),
        CustomMapSource(
            name: "Stamen Terrain",
            url: "https://tiles.stadiamaps.com/tiles/stamen_terrain/{z}/{x}/{y}.png",
            minZoom: 0,
            maxZoom: 18,
            tileType: "png"
        ),
        CustomMapSource(
            name: "ESRI World Imagery",
            url: "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
            minZoom: 0,
            maxZoom: 19,
            tileType: "jpg"
        ),
        CustomMapSource(
            name: "ESRI World Topo",
            url: "https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}",
            minZoom: 0,
            maxZoom: 19,
            tileType: "jpg"
        )
    ]

    // MARK: - Initialization

    init() {
        loadMapSources()
    }

    // MARK: - Configuration

    func setMapView(_ mapView: MKMapView) {
        self.mapView = mapView
        applyVisibleOverlays()
    }

    // MARK: - Import Methods

    /// Import a map source from a file URL
    func importFromFile(url: URL) throws -> CustomMapSource {
        guard url.startAccessingSecurityScopedResource() else {
            throw MapSourceError.fileAccessDenied
        }

        defer {
            url.stopAccessingSecurityScopedResource()
        }

        let data = try Data(contentsOf: url)
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw MapSourceError.invalidFormat
        }

        return try importFromXML(xmlString)
    }

    /// Import a map source from XML string
    func importFromXML(_ xmlString: String) throws -> CustomMapSource {
        guard let source = MapSourceParser.parse(xmlString: xmlString) else {
            throw MapSourceError.parsingFailed
        }

        // Check for duplicate
        if mapSources.contains(where: { $0.url == source.url }) {
            throw MapSourceError.duplicateSource
        }

        mapSources.append(source)
        saveMapSources()

        print("Imported map source: \(source.name)")
        return source
    }

    /// Import a map source from a data package
    func importFromDataPackage(data: Data, fileName: String) throws -> CustomMapSource {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw MapSourceError.invalidFormat
        }

        guard var source = MapSourceParser.parseDataPackageFormat(xmlString: xmlString) else {
            throw MapSourceError.parsingFailed
        }

        // Use filename as name if parsing didn't find one
        if source.name.isEmpty {
            source.name = fileName.replacingOccurrences(of: ".xml", with: "")
        }

        // Check for duplicate
        if mapSources.contains(where: { $0.url == source.url }) {
            // Update existing
            if let index = mapSources.firstIndex(where: { $0.url == source.url }) {
                mapSources[index] = source
                saveMapSources()
                return source
            }
        }

        mapSources.append(source)
        saveMapSources()

        return source
    }

    /// Add a map source manually
    func addSource(_ source: CustomMapSource) {
        // Check for duplicate URL
        if let existingIndex = mapSources.firstIndex(where: { $0.url == source.url }) {
            mapSources[existingIndex] = source
        } else {
            mapSources.append(source)
        }
        saveMapSources()
    }

    /// Add a built-in source to the user's collection
    func addBuiltInSource(_ source: CustomMapSource) {
        if !mapSources.contains(where: { $0.url == source.url }) {
            mapSources.append(source)
            saveMapSources()
        }
    }

    // MARK: - Source Management

    /// Toggle visibility of a map source
    func toggleVisibility(for sourceId: UUID) {
        guard let index = mapSources.firstIndex(where: { $0.id == sourceId }) else { return }

        mapSources[index].isVisible.toggle()
        saveMapSources()

        if mapSources[index].isVisible {
            addOverlayToMap(mapSources[index])
        } else {
            removeOverlayFromMap(sourceId)
        }
    }

    /// Update source opacity
    func setOpacity(for sourceId: UUID, opacity: Double) {
        guard let index = mapSources.firstIndex(where: { $0.id == sourceId }) else { return }

        mapSources[index].opacity = opacity
        saveMapSources()

        // Recreate overlay with new opacity
        if mapSources[index].isVisible {
            removeOverlayFromMap(sourceId)
            addOverlayToMap(mapSources[index])
        }
    }

    /// Delete a map source
    func deleteSource(_ sourceId: UUID) {
        removeOverlayFromMap(sourceId)
        mapSources.removeAll { $0.id == sourceId }
        saveMapSources()
    }

    /// Reorder map sources (affects overlay z-order)
    func moveSource(from source: IndexSet, to destination: Int) {
        mapSources.move(fromOffsets: source, toOffset: destination)
        saveMapSources()
        reapplyOverlays()
    }

    // MARK: - Overlay Management

    private func addOverlayToMap(_ source: CustomMapSource) {
        guard let mapView = mapView else { return }

        let overlay = source.createTileOverlay()
        activeOverlays[source.id] = overlay
        mapView.addOverlay(overlay, level: .aboveLabels)
    }

    private func removeOverlayFromMap(_ sourceId: UUID) {
        guard let mapView = mapView,
              let overlay = activeOverlays[sourceId] else { return }

        mapView.removeOverlay(overlay)
        activeOverlays.removeValue(forKey: sourceId)
    }

    private func applyVisibleOverlays() {
        guard let mapView = mapView else { return }

        // Remove all existing tile overlays
        for overlay in activeOverlays.values {
            mapView.removeOverlay(overlay)
        }
        activeOverlays.removeAll()

        // Add visible sources in order
        for source in mapSources where source.isVisible {
            addOverlayToMap(source)
        }
    }

    private func reapplyOverlays() {
        applyVisibleOverlays()
    }

    // MARK: - Persistence

    private func loadMapSources() {
        if let data = userDefaults.data(forKey: sourcesKey),
           let decoded = try? JSONDecoder().decode([CustomMapSource].self, from: data) {
            mapSources = decoded
        }
    }

    private func saveMapSources() {
        if let encoded = try? JSONEncoder().encode(mapSources) {
            userDefaults.set(encoded, forKey: sourcesKey)
        }
    }

    /// Export a map source to XML
    func exportToXML(_ source: CustomMapSource) -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <customMapSource>
            <name>\(source.name)</name>
            <url>\(source.url)</url>
            <minZoom>\(source.minZoom)</minZoom>
            <maxZoom>\(source.maxZoom)</maxZoom>
            <tileType>\(source.tileType)</tileType>
            \(source.updateFrequency.map { "<tileUpdate>\($0)</tileUpdate>" } ?? "")
            \(source.backgroundColor.map { "<backgroundColor>\($0)</backgroundColor>" } ?? "")
        </customMapSource>
        """
    }

    /// Clear all custom map sources
    func clearAll() {
        for source in mapSources {
            removeOverlayFromMap(source.id)
        }
        mapSources.removeAll()
        saveMapSources()
    }
}

// MARK: - Errors

enum MapSourceError: LocalizedError {
    case fileAccessDenied
    case invalidFormat
    case parsingFailed
    case duplicateSource
    case overlayCreationFailed

    var errorDescription: String? {
        switch self {
        case .fileAccessDenied:
            return "Cannot access the map source file"
        case .invalidFormat:
            return "Invalid map source file format"
        case .parsingFailed:
            return "Failed to parse map source configuration"
        case .duplicateSource:
            return "This map source already exists"
        case .overlayCreationFailed:
            return "Failed to create map overlay"
        }
    }
}

// MARK: - MKMapView Extension for Custom Tile Rendering

extension MKMapView {
    /// Add a custom map source overlay
    func addMapSource(_ source: CustomMapSource, level: MKOverlayLevel = .aboveLabels) {
        let overlay = source.createTileOverlay()
        addOverlay(overlay, level: level)
    }
}
