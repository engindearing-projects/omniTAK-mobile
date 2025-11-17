//
//  USAGE_EXAMPLES.swift
//  OmniTAKTest
//
//  Code examples for Enhanced Markers feature integration
//  NOTE: This file is for reference only - do not add to Xcode target
//

import SwiftUI
import UIKit
import MapKit

// MARK: - Example 1: Basic Integration with SwiftUI

struct ContentViewExample: View {
    @StateObject private var takService = TAKService()

    var body: some View {
        EnhancedMapViewWrapper(takService: takService)
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                StatusBar(takService: takService)
            }
            .overlay(alignment: .bottom) {
                MapControls(takService: takService)
            }
    }
}

// SwiftUI wrapper for EnhancedMapViewController
struct EnhancedMapViewWrapper: UIViewControllerRepresentable {
    @ObservedObject var takService: TAKService

    func makeUIViewController(context: Context) -> EnhancedMapViewController {
        let controller = EnhancedMapViewController(takService: takService)
        context.coordinator.mapViewController = controller
        return controller
    }

    func updateUIViewController(_ uiViewController: EnhancedMapViewController, context: Context) {
        // Updates handled automatically via Combine observers
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var mapViewController: EnhancedMapViewController?
    }
}

// MARK: - Example 2: UIKit Integration

class MainViewController: UIViewController {
    private let takService = TAKService()
    private var mapViewController: EnhancedMapViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup TAK service
        setupTAKService()

        // Create and add map view controller
        let mapVC = EnhancedMapViewController(takService: takService)
        addChild(mapVC)
        view.addSubview(mapVC.view)
        mapVC.view.frame = view.bounds
        mapVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapVC.didMove(toParent: self)
        self.mapViewController = mapVC

        // Add toolbar
        setupToolbar()
    }

    private func setupTAKService() {
        // Connect to TAK server
        takService.connect(
            host: "204.48.30.216",
            port: 8087,
            protocolType: "tcp",
            useTLS: false
        )

        // Configure history tracking
        takService.maxHistoryPerUnit = 100
        takService.historyRetentionTime = 3600

        // Setup marker update callback
        takService.onMarkerUpdated = { marker in
            print("Marker updated: \(marker.callsign)")
        }
    }

    private func setupToolbar() {
        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        let centerButton = UIBarButtonItem(
            image: UIImage(systemName: "location.fill"),
            style: .plain,
            target: self,
            action: #selector(centerOnUser)
        )

        let trailButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.triangle.turn.up.right.diamond"),
            style: .plain,
            target: self,
            action: #selector(toggleTrails)
        )

        let mapTypeButton = UIBarButtonItem(
            image: UIImage(systemName: "map"),
            style: .plain,
            target: self,
            action: #selector(toggleMapType)
        )

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        toolbar.items = [
            centerButton,
            flexSpace,
            trailButton,
            flexSpace,
            mapTypeButton
        ]
    }

    @objc private func centerOnUser() {
        mapViewController?.centerOnUser()
    }

    @objc private func toggleTrails() {
        mapViewController?.toggleTrails()
    }

    @objc private func toggleMapType() {
        mapViewController?.toggleMapType()
    }
}

// MARK: - Example 3: Custom Trail Configuration

class CustomTrailViewController: UIViewController {
    private let takService = TAKService()
    private let trailManager = TrailManager()

    func configureTrails() {
        // Customize trail appearance
        trailManager.maxTrailLength = 50  // Shorter trails
        trailManager.minimumDistanceThreshold = 10.0  // Larger gaps

        // Configure trail settings
        var config = TrailConfiguration()
        config.showDirectionArrows = true
        config.trailWidth = 4.0
        config.maxTrailLength = 50
        config.trailDuration = 1800  // 30 minutes

        // Filter by affiliation
        config.showFriendlyTrails = true
        config.showHostileTrails = true
        config.showNeutralTrails = false
        config.showUnknownTrails = false
    }
}

// MARK: - Example 4: Programmatic Marker Selection

extension EnhancedMapViewController {
    func selectMarkerByUID(_ uid: String) {
        if let marker = takService.getMarker(uid: uid) {
            // Center on marker
            let region = MKCoordinateRegion(
                center: marker.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            mapView.setRegion(region, animated: true)

            // Show info panel
            handleMarkerTap(marker)
        }
    }

    func showAllMarkers() {
        let markers = takService.getAllMarkers()
        guard !markers.isEmpty else { return }

        // Calculate bounding rect
        var minLat = 90.0, maxLat = -90.0
        var minLon = 180.0, maxLon = -180.0

        for marker in markers {
            minLat = min(minLat, marker.coordinate.latitude)
            maxLat = max(maxLat, marker.coordinate.latitude)
            minLon = min(minLon, marker.coordinate.longitude)
            maxLon = max(maxLon, marker.coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.2,  // Add 20% padding
            longitudeDelta: (maxLon - minLon) * 1.2
        )

        let region = MKCoordinateRegion(center: center, span: span)
        mapView.setRegion(region, animated: true)
    }
}

// MARK: - Example 5: Custom Info Panel Actions

class CustomActionsViewController: UIViewController {
    private let takService = TAKService()

    func showCustomInfoPanel(for marker: EnhancedCoTMarker) {
        let panel = MarkerInfoPanel(
            marker: marker,
            userLocation: getCurrentLocation(),
            onCenter: {
                self.centerMap(on: marker)
            },
            onMessage: {
                self.sendMessage(to: marker)
            },
            onTrack: {
                self.startTracking(marker)
            },
            onDismiss: {
                self.dismissPanel()
            }
        )

        // Present using UIHostingController
        let hostingController = UIHostingController(rootView: panel)
        hostingController.modalPresentationStyle = .pageSheet

        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [
                .custom { _ in 150 },   // Collapsed
                .custom { _ in 400 },   // Half
                .large()                // Full
            ]
            sheet.prefersGrabberVisible = true
        }

        present(hostingController, animated: true)
    }

    private func getCurrentLocation() -> CLLocation? {
        // Return current user location
        return nil
    }

    private func centerMap(on marker: EnhancedCoTMarker) {
        print("Centering on: \(marker.callsign)")
    }

    private func sendMessage(to marker: EnhancedCoTMarker) {
        let alert = UIAlertController(
            title: "Send Message",
            message: "Send message to \(marker.callsign)?",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "Enter message"
        }

        alert.addAction(UIAlertAction(title: "Send", style: .default) { _ in
            if let message = alert.textFields?.first?.text {
                self.sendChatMessage(message, to: marker)
            }
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alert, animated: true)
    }

    private func sendChatMessage(_ text: String, to marker: EnhancedCoTMarker) {
        // TODO: Implement TAK chat protocol
        print("Sending message to \(marker.callsign): \(text)")
    }

    private func startTracking(_ marker: EnhancedCoTMarker) {
        // Enable continuous tracking
        print("Tracking: \(marker.callsign)")
    }

    private func dismissPanel() {
        dismiss(animated: true)
    }
}

// MARK: - Example 6: Periodic Stale Marker Cleanup

class MarkerCleanupService {
    private let takService: TAKService
    private var cleanupTimer: Timer?

    init(takService: TAKService) {
        self.takService = takService
    }

    func startPeriodicCleanup(interval: TimeInterval = 60) {
        cleanupTimer?.invalidate()

        cleanupTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            self?.takService.removeStaleMarkers()
            print("Cleaned up stale markers")
        }
    }

    func stopCleanup() {
        cleanupTimer?.invalidate()
        cleanupTimer = nil
    }
}

// MARK: - Example 7: Export Trail Data

extension TrailManager {
    func exportTrailAsGPX(uid: String) -> String? {
        guard let trail = trails[uid] else { return nil }

        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="OmniTAK">
            <trk>
                <name>\(uid)</name>
                <trkseg>
        """

        for position in trail.positions {
            gpx += """

                    <trkpt lat="\(position.coordinate.latitude)" lon="\(position.coordinate.longitude)">
                        <ele>\(position.altitude)</ele>
                        <time>\(ISO8601DateFormatter().string(from: position.timestamp))</time>
            """

            if let speed = position.speed {
                gpx += "\n            <speed>\(speed)</speed>"
            }

            if let course = position.course {
                gpx += "\n            <course>\(course)</course>"
            }

            gpx += "\n        </trkpt>"
        }

        gpx += """

                </trkseg>
            </trk>
        </gpx>
        """

        return gpx
    }

    func saveTrailToFile(uid: String, filename: String) {
        guard let gpxData = exportTrailAsGPX(uid: uid),
              let data = gpxData.data(using: .utf8) else {
            return
        }

        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!

        let fileURL = documentsPath.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            print("Trail saved to: \(fileURL.path)")
        } catch {
            print("Failed to save trail: \(error)")
        }
    }
}

// MARK: - Example 8: Filter Markers by Affiliation

extension TAKService {
    func getMarkers(byAffiliation affiliation: UnitAffiliation) -> [EnhancedCoTMarker] {
        return enhancedMarkers.values.filter { $0.affiliation == affiliation }
    }

    func getMarkers(byUnitType unitType: UnitType) -> [EnhancedCoTMarker] {
        return enhancedMarkers.values.filter { $0.unitType == unitType }
    }

    func getMarkersWithinRadius(
        of coordinate: CLLocationCoordinate2D,
        radius: Double
    ) -> [EnhancedCoTMarker] {
        let centerLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        return enhancedMarkers.values.filter {
            $0.distance(from: centerLocation) <= radius
        }
    }

    func getNearestMarker(to coordinate: CLLocationCoordinate2D) -> EnhancedCoTMarker? {
        let centerLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        return enhancedMarkers.values.min { marker1, marker2 in
            marker1.distance(from: centerLocation) < marker2.distance(from: centerLocation)
        }
    }
}

// MARK: - Example 9: Monitor Marker Changes with Combine

import Combine

class MarkerMonitor: ObservableObject {
    @Published var friendlyCount = 0
    @Published var hostileCount = 0
    @Published var unknownCount = 0
    @Published var staleCount = 0

    private var cancellables = Set<AnyCancellable>()

    init(takService: TAKService) {
        takService.$enhancedMarkers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] markers in
                self?.updateCounts(markers)
            }
            .store(in: &cancellables)
    }

    private func updateCounts(_ markers: [String: EnhancedCoTMarker]) {
        let markerArray = Array(markers.values)

        friendlyCount = markerArray.filter { $0.affiliation == .friendly }.count
        hostileCount = markerArray.filter { $0.affiliation == .hostile }.count
        unknownCount = markerArray.filter { $0.affiliation == .unknown }.count
        staleCount = markerArray.filter { $0.isStale }.count
    }
}

// MARK: - Example 10: SwiftUI Status Dashboard

struct MarkerDashboard: View {
    @StateObject private var monitor: MarkerMonitor

    init(takService: TAKService) {
        _monitor = StateObject(wrappedValue: MarkerMonitor(takService: takService))
    }

    var body: some View {
        HStack(spacing: 20) {
            StatBadge(label: "Friendly", count: monitor.friendlyCount, color: .cyan)
            StatBadge(label: "Hostile", count: monitor.hostileCount, color: .red)
            StatBadge(label: "Unknown", count: monitor.unknownCount, color: .yellow)
            StatBadge(label: "Stale", count: monitor.staleCount, color: .gray)
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
    }
}

struct StatBadge: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
        }
    }
}
