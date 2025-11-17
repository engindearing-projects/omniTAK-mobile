//
//  KMLOverlayManager.swift
//  OmniTAKMobile
//
//  Manages KML overlays and their display on the map
//

import Foundation
import MapKit
import CoreLocation
import SwiftUI

// MARK: - KML Overlay Types

/// Custom overlay wrapper that maintains reference to KML source
class KMLPointAnnotation: MKPointAnnotation {
    var kmlPlacemark: KMLPlacemark
    var kmlDocumentId: UUID
    var style: KMLStyle?

    init(placemark: KMLPlacemark, documentId: UUID, style: KMLStyle?) {
        self.kmlPlacemark = placemark
        self.kmlDocumentId = documentId
        self.style = style
        super.init()

        self.title = placemark.name
        self.subtitle = placemark.description
    }
}

class KMLPolylineOverlay: MKPolyline {
    var kmlPlacemarkId: UUID?
    var kmlDocumentId: UUID?
    var style: KMLStyle?
}

class KMLPolygonOverlay: MKPolygon {
    var kmlPlacemarkId: UUID?
    var kmlDocumentId: UUID?
    var style: KMLStyle?
}

// MARK: - KML Overlay Manager

class KMLOverlayManager: ObservableObject {

    @Published var documents: [KMLDocument] = []
    @Published var isLoading = false
    @Published var lastError: String?

    private let documentsDirectory: URL
    private let kmlStorageFile: URL

    // Track overlays by document ID
    var overlaysByDocument: [UUID: [MKOverlay]] = [:]
    var annotationsByDocument: [UUID: [MKAnnotation]] = [:]

    init() {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        documentsDirectory = paths[0].appendingPathComponent("KMLFiles")
        kmlStorageFile = paths[0].appendingPathComponent("kml_documents.json")

        // Create directory if needed
        try? FileManager.default.createDirectory(at: documentsDirectory, withIntermediateDirectories: true)

        loadStoredDocuments()
    }

    // MARK: - Import Methods

    func importKMLFile(from url: URL) async {
        await MainActor.run {
            isLoading = true
            lastError = nil
        }

        do {
            let fileExtension = url.pathExtension.lowercased()

            var kmlData: Data
            var resources: [String: Data] = [:]
            let fileName = url.lastPathComponent

            if fileExtension == "kmz" {
                // Extract KMZ
                (kmlData, resources) = try KMZHandler.extractKML(from: url)

                // Save resources if any
                if !resources.isEmpty {
                    let resourceDir = try KMZHandler.saveResources(resources, forKML: fileName)
                    print("Saved KMZ resources to: \(resourceDir.path)")
                }
            } else if fileExtension == "kml" {
                kmlData = try Data(contentsOf: url)
            } else {
                throw ImportError.unsupportedFormat
            }

            // Parse KML
            let parser = KMLParser(fileName: fileName)
            var document = try parser.parse(data: kmlData)

            // Save original KML data
            let savedURL = documentsDirectory.appendingPathComponent("\(document.id.uuidString).kml")
            try kmlData.write(to: savedURL)

            await MainActor.run {
                documents.append(document)
                createOverlays(for: document)
                saveDocuments()
                isLoading = false
            }

            print("Successfully imported KML: \(document.name) with \(document.placemarks.count) placemarks")

        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                isLoading = false
            }
            print("KML import error: \(error)")
        }
    }

    enum ImportError: LocalizedError {
        case unsupportedFormat

        var errorDescription: String? {
            switch self {
            case .unsupportedFormat:
                return "Unsupported file format. Please use .kml or .kmz files."
            }
        }
    }

    // MARK: - Overlay Creation

    func createOverlays(for document: KMLDocument) {
        var overlays: [MKOverlay] = []
        var annotations: [MKAnnotation] = []

        // Process direct placemarks
        for placemark in document.placemarks {
            let style = resolveStyle(for: placemark, in: document)
            let (newOverlays, newAnnotations) = createOverlays(for: placemark, documentId: document.id, style: style)
            overlays.append(contentsOf: newOverlays)
            annotations.append(contentsOf: newAnnotations)
        }

        // Process folders
        for folder in document.folders {
            for placemark in folder.placemarks {
                let style = resolveStyle(for: placemark, in: document)
                let (newOverlays, newAnnotations) = createOverlays(for: placemark, documentId: document.id, style: style)
                overlays.append(contentsOf: newOverlays)
                annotations.append(contentsOf: newAnnotations)
            }
        }

        overlaysByDocument[document.id] = overlays
        annotationsByDocument[document.id] = annotations

        print("Created \(overlays.count) overlays and \(annotations.count) annotations for \(document.name)")
    }

    private func resolveStyle(for placemark: KMLPlacemark, in document: KMLDocument) -> KMLStyle? {
        guard let styleUrl = placemark.styleUrl else { return nil }
        let styleId = styleUrl.replacingOccurrences(of: "#", with: "")
        return document.styles[styleId]
    }

    private func createOverlays(for placemark: KMLPlacemark, documentId: UUID, style: KMLStyle?) -> ([MKOverlay], [MKAnnotation]) {
        var overlays: [MKOverlay] = []
        var annotations: [MKAnnotation] = []

        processGeometry(placemark.geometry, placemark: placemark, documentId: documentId, style: style, overlays: &overlays, annotations: &annotations)

        return (overlays, annotations)
    }

    private func processGeometry(_ geometry: KMLGeometry, placemark: KMLPlacemark, documentId: UUID, style: KMLStyle?, overlays: inout [MKOverlay], annotations: inout [MKAnnotation]) {
        switch geometry {
        case .point(let point):
            let annotation = KMLPointAnnotation(placemark: placemark, documentId: documentId, style: style)
            annotation.coordinate = point.coordinate
            annotations.append(annotation)

        case .lineString(let lineString):
            var coordinates = lineString.mapCoordinates
            let polyline = KMLPolylineOverlay(coordinates: &coordinates, count: coordinates.count)
            polyline.kmlPlacemarkId = placemark.id
            polyline.kmlDocumentId = documentId
            polyline.style = style
            overlays.append(polyline)

        case .polygon(let polygon):
            var outerCoords = polygon.outerCoordinates
            let mkPolygon: MKPolygon

            if !polygon.innerBoundaries.isEmpty {
                // Create polygon with holes
                let interiorPolygons = polygon.innerBoundaries.map { innerCoords -> MKPolygon in
                    var coords = innerCoords.map { $0.coordinate }
                    return MKPolygon(coordinates: &coords, count: coords.count)
                }
                mkPolygon = MKPolygon(coordinates: &outerCoords, count: outerCoords.count, interiorPolygons: interiorPolygons)
            } else {
                mkPolygon = MKPolygon(coordinates: &outerCoords, count: outerCoords.count)
            }

            // Wrap in our custom class
            let kmlPolygon = KMLPolygonOverlay(points: mkPolygon.points(), count: mkPolygon.pointCount)
            kmlPolygon.kmlPlacemarkId = placemark.id
            kmlPolygon.kmlDocumentId = documentId
            kmlPolygon.style = style
            overlays.append(kmlPolygon)

        case .multiGeometry(let geometries):
            for geo in geometries {
                processGeometry(geo, placemark: placemark, documentId: documentId, style: style, overlays: &overlays, annotations: &annotations)
            }
        }
    }

    // MARK: - Document Management

    func toggleVisibility(for documentId: UUID) {
        if let index = documents.firstIndex(where: { $0.id == documentId }) {
            documents[index].isVisible.toggle()
            saveDocuments()
        }
    }

    func deleteDocument(_ documentId: UUID) {
        // Remove overlays
        overlaysByDocument.removeValue(forKey: documentId)
        annotationsByDocument.removeValue(forKey: documentId)

        // Remove from array
        documents.removeAll { $0.id == documentId }

        // Delete file
        let fileURL = documentsDirectory.appendingPathComponent("\(documentId.uuidString).kml")
        try? FileManager.default.removeItem(at: fileURL)

        saveDocuments()
    }

    func getVisibleOverlays() -> [MKOverlay] {
        var allOverlays: [MKOverlay] = []

        for document in documents where document.isVisible {
            if let overlays = overlaysByDocument[document.id] {
                allOverlays.append(contentsOf: overlays)
            }
        }

        return allOverlays
    }

    func getVisibleAnnotations() -> [MKAnnotation] {
        var allAnnotations: [MKAnnotation] = []

        for document in documents where document.isVisible {
            if let annotations = annotationsByDocument[document.id] {
                allAnnotations.append(contentsOf: annotations)
            }
        }

        return allAnnotations
    }

    // MARK: - Persistence

    private func saveDocuments() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(documents)
            try data.write(to: kmlStorageFile)
        } catch {
            print("Failed to save KML documents: \(error)")
        }
    }

    private func loadStoredDocuments() {
        guard FileManager.default.fileExists(atPath: kmlStorageFile.path) else { return }

        do {
            let data = try Data(contentsOf: kmlStorageFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            documents = try decoder.decode([KMLDocument].self, from: data)

            // Recreate overlays for each document
            for document in documents {
                createOverlays(for: document)
            }
        } catch {
            print("Failed to load KML documents: \(error)")
        }
    }

    // MARK: - Rendering Helpers

    static func renderer(for overlay: MKOverlay) -> MKOverlayRenderer? {
        if let polyline = overlay as? KMLPolylineOverlay {
            let renderer = MKPolylineRenderer(polyline: polyline)

            if let style = polyline.style, let color = style.lineUIColor() {
                renderer.strokeColor = color
            } else {
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.8)
            }

            renderer.lineWidth = CGFloat(polyline.style?.lineWidth ?? 3.0)
            renderer.lineCap = .round
            return renderer
        }

        if let polygon = overlay as? KMLPolygonOverlay {
            let renderer = MKPolygonRenderer(polygon: polygon)

            if let style = polygon.style {
                if let color = style.polyUIColor() {
                    renderer.fillColor = style.polyFill == true ? color.withAlphaComponent(0.3) : .clear
                    renderer.strokeColor = style.polyOutline == true ? color : .clear
                } else {
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.3)
                    renderer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.8)
                }
            } else {
                renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.3)
                renderer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.8)
            }

            renderer.lineWidth = 2.0
            return renderer
        }

        return nil
    }

    static func annotationView(for annotation: MKAnnotation, in mapView: MKMapView) -> MKAnnotationView? {
        guard let kmlAnnotation = annotation as? KMLPointAnnotation else {
            return nil
        }

        let identifier = "KMLPoint"
        var view: MKMarkerAnnotationView

        if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
            view = dequeuedView
            view.annotation = annotation
        } else {
            view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.canShowCallout = true
            view.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        }

        // Apply style if available
        if let _ = kmlAnnotation.style?.iconUrl {
            // Custom icon - would load from resources
            view.markerTintColor = .systemPurple
        } else {
            view.markerTintColor = .systemOrange
        }

        view.glyphImage = UIImage(systemName: "mappin")
        return view
    }
}

// MARK: - KML Statistics

extension KMLOverlayManager {
    func statistics(for document: KMLDocument) -> String {
        var points = 0
        var lines = 0
        var polygons = 0

        func countGeometry(_ geometry: KMLGeometry) {
            switch geometry {
            case .point:
                points += 1
            case .lineString:
                lines += 1
            case .polygon:
                polygons += 1
            case .multiGeometry(let geometries):
                geometries.forEach { countGeometry($0) }
            }
        }

        for placemark in document.placemarks {
            countGeometry(placemark.geometry)
        }

        for folder in document.folders {
            for placemark in folder.placemarks {
                countGeometry(placemark.geometry)
            }
        }

        var stats: [String] = []
        if points > 0 { stats.append("\(points) point\(points == 1 ? "" : "s")") }
        if lines > 0 { stats.append("\(lines) line\(lines == 1 ? "" : "s")") }
        if polygons > 0 { stats.append("\(polygons) polygon\(polygons == 1 ? "" : "s")") }

        return stats.joined(separator: ", ")
    }
}
