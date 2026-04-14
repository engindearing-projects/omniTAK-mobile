//
//  MapLibre3DView.swift
//  OmniTAKMobile
//
//  MapLibre-based 3D terrain view with real DEM elevation data
//  Replaces the limited MapKit 3D implementation
//

import SwiftUI
import MapLibre
import CoreLocation

// MARK: - MapLibre 3D View

struct MapLibre3DView: UIViewRepresentable {
    @ObservedObject var service: MapLibreService
    @Binding var camera: MapLibreCamera

    var onMapTap: ((CLLocationCoordinate2D) -> Void)?

    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView(frame: .zero)
        mapView.delegate = context.coordinator

        // Configure map style with terrain support
        if let styleURL = service.currentStyleURL {
            mapView.styleURL = styleURL
        }

        // Enable user location
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none

        // Set initial camera
        mapView.setCenter(camera.center, zoomLevel: camera.zoom, animated: false)
        mapView.direction = camera.bearing
        mapView.camera.pitch = CGFloat(camera.pitch)

        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)

        // Store reference in service
        service.mapView = mapView

        return mapView
    }

    func updateUIView(_ mapView: MLNMapView, context: Context) {
        // Update camera if changed externally
        if mapView.centerCoordinate.latitude != camera.center.latitude ||
           mapView.centerCoordinate.longitude != camera.center.longitude {
            mapView.setCenter(camera.center, animated: true)
        }

        if mapView.zoomLevel != camera.zoom {
            mapView.setZoomLevel(camera.zoom, animated: true)
        }

        if mapView.direction != camera.bearing {
            mapView.direction = camera.bearing
        }

        if Double(mapView.camera.pitch) != camera.pitch {
            let newCamera = mapView.camera
            newCamera.pitch = CGFloat(camera.pitch)
            mapView.setCamera(newCamera, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MLNMapViewDelegate {
        var parent: MapLibre3DView

        init(_ parent: MapLibre3DView) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MLNMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onMapTap?(coordinate)
        }

        // MARK: - MLNMapViewDelegate

        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            // Add terrain source and layer when style loads
            parent.service.configureTerrain(for: style)
        }

        func mapViewDidFinishLoadingMap(_ mapView: MLNMapView) {
            parent.service.isMapLoaded = true
        }

        func mapView(_ mapView: MLNMapView, regionDidChangeAnimated animated: Bool) {
            // Update camera binding when user pans/zooms
            DispatchQueue.main.async {
                self.parent.camera.center = mapView.centerCoordinate
                self.parent.camera.zoom = mapView.zoomLevel
                self.parent.camera.bearing = mapView.direction
                self.parent.camera.pitch = Double(mapView.camera.pitch)
            }
        }
    }
}

// MARK: - Camera State

struct MapLibreCamera: Equatable {
    var center: CLLocationCoordinate2D
    var zoom: Double
    var bearing: Double
    var pitch: Double

    static func == (lhs: MapLibreCamera, rhs: MapLibreCamera) -> Bool {
        return lhs.center.latitude == rhs.center.latitude &&
               lhs.center.longitude == rhs.center.longitude &&
               lhs.zoom == rhs.zoom &&
               lhs.bearing == rhs.bearing &&
               lhs.pitch == rhs.pitch
    }

    static let defaultCamera = MapLibreCamera(
        center: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365), // Washington DC
        zoom: 12,
        bearing: 0,
        pitch: 0
    )

    static let terrain3DCamera = MapLibreCamera(
        center: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
        zoom: 14,
        bearing: 0,
        pitch: 60 // Tilted for 3D effect
    )
}

// MARK: - Preview

struct MapLibre3DView_Previews: PreviewProvider {
    static var previews: some View {
        MapLibre3DView(
            service: MapLibreService(),
            camera: .constant(.defaultCamera)
        )
        .ignoresSafeArea()
    }
}
