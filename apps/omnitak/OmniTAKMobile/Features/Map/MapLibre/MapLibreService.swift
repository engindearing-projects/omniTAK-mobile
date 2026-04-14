//
//  MapLibreService.swift
//  OmniTAKMobile
//
//  Service layer for MapLibre configuration, terrain, and state management
//

import Foundation
import MapLibre
import CoreLocation
import SwiftUI

// MARK: - MapLibre Service

class MapLibreService: ObservableObject {
    static let shared = MapLibreService()

    // MARK: - Published Properties

    @Published var isMapLoaded = false
    @Published var is3DEnabled = false
    @Published var terrainExaggeration: Double = 1.5
    @Published var currentStyle: MapLibreStyle = .liberty
    @Published var showBuildings = true

    // MARK: - Map Reference

    weak var mapView: MLNMapView?

    // MARK: - Tile Providers

    // OpenFreeMap - Free, no API key required, no rate limits
    // https://openfreemap.org
    // Uses OpenStreetMap data, MIT license, attribution automatic with MapLibre

    // MARK: - Style URLs

    var currentStyleURL: URL? {
        return currentStyle.url
    }

    // MARK: - Terrain Configuration

    func configureTerrain(for style: MLNStyle) {
        guard is3DEnabled else {
            removeTerrain(from: style)
            return
        }

        // Add terrain RGB DEM source for hillshade visualization
        // Using AWS Terrain Tiles (free, no API key required)
        // Note: Full 3D terrain (MLNTerrain) is not yet available in MapLibre iOS SDK
        let terrainSourceID = "terrain-dem"
        if style.source(withIdentifier: terrainSourceID) == nil {
            // AWS Terrain Tiles - free public dataset (Terrarium encoding)
            let terrainURL = "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"
            let terrainSource = MLNRasterDEMSource(
                identifier: terrainSourceID,
                tileURLTemplates: [terrainURL],
                options: [
                    .tileSize: 256,
                    .minimumZoomLevel: 0,
                    .maximumZoomLevel: 15
                ]
            )
            style.addSource(terrainSource)
        }

        // Add hillshade layer for terrain visualization
        addHillshadeLayer(to: style, sourceID: terrainSourceID)
    }

    func removeTerrain(from style: MLNStyle) {
        // Remove hillshade layer
        if let hillshade = style.layer(withIdentifier: "terrain-hillshade") {
            style.removeLayer(hillshade)
        }
    }

    private func addHillshadeLayer(to style: MLNStyle, sourceID: String) {
        let hillshadeID = "terrain-hillshade"

        // Remove existing if present
        if let existing = style.layer(withIdentifier: hillshadeID) {
            style.removeLayer(existing)
        }

        let hillshade = MLNHillshadeStyleLayer(identifier: hillshadeID, source: style.source(withIdentifier: sourceID)!)
        hillshade.hillshadeExaggeration = NSExpression(forConstantValue: 0.5)
        hillshade.hillshadeShadowColor = NSExpression(forConstantValue: UIColor.black.withAlphaComponent(0.3))
        hillshade.hillshadeHighlightColor = NSExpression(forConstantValue: UIColor.white.withAlphaComponent(0.3))
        hillshade.hillshadeAccentColor = NSExpression(forConstantValue: UIColor.gray)

        // Insert below labels
        if let firstSymbolLayer = style.layers.first(where: { $0 is MLNSymbolStyleLayer }) {
            style.insertLayer(hillshade, below: firstSymbolLayer)
        } else {
            style.addLayer(hillshade)
        }
    }

    // Note: MLNSkyLayer is not available in current MapLibre iOS SDK
    // Sky/atmosphere effects would require a future version of the SDK

    // MARK: - Camera Controls

    func set3DMode(enabled: Bool) {
        is3DEnabled = enabled

        guard let mapView = mapView, let style = mapView.style else { return }

        if enabled {
            // Tilt camera for 3D view
            let camera = mapView.camera
            camera.pitch = 60
            mapView.setCamera(camera, withDuration: 0.5, animationTimingFunction: CAMediaTimingFunction(name: .easeInEaseOut))

            configureTerrain(for: style)
        } else {
            // Reset to 2D view
            let camera = mapView.camera
            camera.pitch = 0
            mapView.setCamera(camera, withDuration: 0.5, animationTimingFunction: CAMediaTimingFunction(name: .easeInEaseOut))

            removeTerrain(from: style)
        }
    }

    func setTerrainExaggeration(_ value: Double) {
        terrainExaggeration = value
        // Note: Full terrain exaggeration requires MLNTerrain which is not available
        // in the current MapLibre iOS SDK. This value is stored for future use
        // or when using hillshade visualization intensity.
    }

    func setCameraPitch(_ pitch: Double) {
        guard let mapView = mapView else { return }

        let camera = mapView.camera
        camera.pitch = CGFloat(min(85, max(0, pitch)))
        mapView.setCamera(camera, animated: true)
    }

    func setCameraBearing(_ bearing: Double) {
        guard let mapView = mapView else { return }
        mapView.direction = bearing
    }

    func flyTo(coordinate: CLLocationCoordinate2D, zoom: Double? = nil, pitch: Double? = nil, bearing: Double? = nil, duration: TimeInterval = 2.0) {
        guard let mapView = mapView else { return }

        let camera = MLNMapCamera(
            lookingAtCenter: coordinate,
            altitude: mapView.camera.altitude,
            pitch: CGFloat(pitch ?? Double(mapView.camera.pitch)),
            heading: bearing ?? mapView.direction
        )

        if let zoom = zoom {
            camera.altitude = MLNAltitudeForZoomLevel(zoom, CGFloat(camera.pitch), coordinate.latitude, mapView.frame.size)
        }

        mapView.fly(to: camera, withDuration: duration, completionHandler: nil)
    }

    func resetCamera() {
        guard let mapView = mapView else { return }

        let camera = MLNMapCamera(
            lookingAtCenter: mapView.centerCoordinate,
            altitude: mapView.camera.altitude,
            pitch: 0,
            heading: 0
        )

        mapView.fly(to: camera, withDuration: 0.5, completionHandler: nil)
    }

    // MARK: - Style Management

    func setStyle(_ style: MapLibreStyle) {
        currentStyle = style

        guard let mapView = mapView, let url = style.url else { return }
        mapView.styleURL = url
    }

    // MARK: - Marker Management

    func addMarker(at coordinate: CLLocationCoordinate2D, title: String?, icon: UIImage? = nil) -> MLNPointAnnotation {
        let annotation = MLNPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = title
        mapView?.addAnnotation(annotation)
        return annotation
    }

    func removeMarker(_ annotation: MLNPointAnnotation) {
        mapView?.removeAnnotation(annotation)
    }

    func removeAllMarkers() {
        guard let mapView = mapView, let annotations = mapView.annotations else { return }
        mapView.removeAnnotations(annotations)
    }

    // MARK: - Polyline/Route

    func addRoute(coordinates: [CLLocationCoordinate2D], color: UIColor = .systemBlue, lineWidth: CGFloat = 4) -> MLNPolyline {
        let polyline = MLNPolyline(coordinates: coordinates, count: UInt(coordinates.count))
        mapView?.addAnnotation(polyline)
        return polyline
    }
}

// MARK: - Map Styles

enum MapLibreStyle: String, CaseIterable, Identifiable {
    case liberty = "Liberty"        // OpenFreeMap - colorful OSM style
    case bright = "Bright"          // OpenFreeMap - clean bright style
    case positron = "Positron"      // OpenFreeMap - light minimalist style
    case streets = "Streets"        // OSM Carto style
    case dark = "Dark"              // Dark theme

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .liberty: return "map.fill"
        case .bright: return "sun.max.fill"
        case .positron: return "rectangle.split.3x1"
        case .streets: return "road.lanes"
        case .dark: return "moon.fill"
        }
    }

    // Free tile sources - no API keys required
    var url: URL? {
        let urlString: String

        switch self {
        case .liberty:
            // OpenFreeMap Liberty - colorful detailed style
            urlString = "https://tiles.openfreemap.org/styles/liberty"
        case .bright:
            // OpenFreeMap Bright - clean bright style
            urlString = "https://tiles.openfreemap.org/styles/bright"
        case .positron:
            // OpenFreeMap Positron - light minimalist style
            urlString = "https://tiles.openfreemap.org/styles/positron"
        case .streets:
            // OpenStreetMap Carto style (raster fallback)
            urlString = "https://tiles.openfreemap.org/styles/liberty"
        case .dark:
            // Dark style - using Positron as base (can be customized)
            urlString = "https://tiles.openfreemap.org/styles/positron"
        }

        return URL(string: urlString)
    }
}

// MARK: - Flyover Animation

extension MapLibreService {
    func startFlyover(along coordinates: [CLLocationCoordinate2D], altitude: Double = 500, duration: TimeInterval = 30) {
        guard let mapView = mapView, coordinates.count >= 2 else { return }

        // Calculate waypoints with smooth camera transitions
        let totalPoints = coordinates.count
        let segmentDuration = duration / Double(totalPoints - 1)

        flyoverStep(mapView: mapView, coordinates: coordinates, currentIndex: 0, altitude: altitude, segmentDuration: segmentDuration)
    }

    private func flyoverStep(mapView: MLNMapView, coordinates: [CLLocationCoordinate2D], currentIndex: Int, altitude: Double, segmentDuration: TimeInterval) {
        guard currentIndex < coordinates.count else { return }

        let coordinate = coordinates[currentIndex]

        // Calculate bearing to next point
        var bearing: Double = mapView.direction
        if currentIndex < coordinates.count - 1 {
            let nextCoord = coordinates[currentIndex + 1]
            bearing = bearingBetween(from: coordinate, to: nextCoord)
        }

        let camera = MLNMapCamera(
            lookingAtCenter: coordinate,
            altitude: altitude,
            pitch: 70, // High pitch for flyover effect
            heading: bearing
        )

        mapView.fly(to: camera, withDuration: segmentDuration) { [weak self] in
            // Continue to next waypoint
            self?.flyoverStep(mapView: mapView, coordinates: coordinates, currentIndex: currentIndex + 1, altitude: altitude, segmentDuration: segmentDuration)
        }
    }

    private func bearingBetween(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        var bearing = atan2(y, x) * 180 / .pi
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)

        return bearing
    }
}
