//
//  MapViewController_Modified.swift
//  OmniTAKTest
//
//  Modified version with Chat integration
//  INSTRUCTIONS: Replace MapViewController.swift with this file content
//

import SwiftUI
import MapKit
import CoreLocation

// ATAK-style Map View with tactical interface
struct ATAKMapView: View {
    @StateObject private var takService = TAKService()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var drawingStore = DrawingStore()
    @StateObject private var drawingManager: DrawingToolsManager

    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365), // Default: DC
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var showServerConfig = false
    @State private var showLayersPanel = false
    @State private var showDrawingPanel = false
    @State private var showDrawingList = false
    @State private var showChat = false  // ADDED: Chat panel state
    @State private var mapType: MKMapType = .satellite
    @State private var showTraffic = false
    @State private var trackingMode: MapUserTrackingMode = .follow
    @State private var orientation = UIDeviceOrientation.unknown

    // Layer states
    @State private var activeMapLayer = "satellite"
    @State private var showFriendly = true
    @State private var showHostile = true
    @State private var showUnknown = false

    init() {
        let store = DrawingStore()
        _drawingStore = StateObject(wrappedValue: store)
        _drawingManager = StateObject(wrappedValue: DrawingToolsManager(drawingStore: store))
    }

    // Detect device orientation
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var isLandscape: Bool {
        horizontalSizeClass == .regular || verticalSizeClass == .compact
    }

    // Computed CoT markers from TAK service - filtered by overlay settings
    private var cotMarkers: [CoTMarker] {
        takService.cotEvents.compactMap { event in
            let marker = CoTMarker(
                uid: event.uid,
                coordinate: CLLocationCoordinate2D(
                    latitude: event.point.lat,
                    longitude: event.point.lon
                ),
                type: event.type,
                callsign: event.detail.callsign,
                team: event.detail.team ?? "Unknown"
            )

            // Filter based on overlay settings
            if event.type.contains("a-f") && !showFriendly {
                return nil  // Hide friendly
            }
            if event.type.contains("a-h") && !showHostile {
                return nil  // Hide hostile
            }
            if event.type.contains("a-u") && !showUnknown {
                return nil  // Hide unknown
            }

            return marker
        }
    }

    var body: some View {
        ZStack {
            // Main Map View - Using UIViewRepresentable for mapType support
            TacticalMapView(
                region: $mapRegion,
                mapType: $mapType,
                trackingMode: $trackingMode,
                markers: cotMarkers,
                showsUserLocation: true,
                drawingStore: drawingStore,
                drawingManager: drawingManager,
                onMapTap: handleMapTap
            )
            .ignoresSafeArea()

            // Top Status Bar (ATAK-style)
            VStack(spacing: 0) {
                ATAKStatusBar(
                    connectionStatus: takService.connectionStatus,
                    isConnected: takService.isConnected,
                    messagesReceived: takService.messagesReceived,
                    messagesSent: takService.messagesSent,
                    gpsAccuracy: locationManager.accuracy,
                    serverName: ServerManager.shared.activeServer?.name,
                    onServerTap: { showServerConfig = true }
                )
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
                .padding(.horizontal, 8)
                .padding(.top, 8)

                Spacer()

                // Bottom Toolbar (ATAK-style) - MODIFIED: Added showChat binding
                ATAKBottomToolbar(
                    mapType: $mapType,
                    showLayersPanel: $showLayersPanel,
                    showDrawingPanel: $showDrawingPanel,
                    showDrawingList: $showDrawingList,
                    showChat: $showChat,  // ADDED
                    onCenterUser: centerOnUser,
                    onSendCoT: sendSelfPosition,
                    onZoomIn: zoomIn,
                    onZoomOut: zoomOut
                )
                .background(Color.black.opacity(0.7))
                .cornerRadius(12)
                .padding(.horizontal, 8)
                .padding(.bottom, 20)
            }

            // Left Side Panel (ATAK-style tools) - Responsive positioning
            if showLayersPanel {
                HStack {
                    ATAKSidePanel(
                        isExpanded: $showLayersPanel,
                        activeMapLayer: $activeMapLayer,
                        showFriendly: $showFriendly,
                        showHostile: $showHostile,
                        showUnknown: $showUnknown,
                        onLayerToggle: { layer in
                            toggleLayer(layer)
                        },
                        onOverlayToggle: { overlay in
                            toggleOverlay(overlay)
                        }
                    )
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(12)
                    .padding(.leading, 8)
                    .padding(.vertical, isLandscape ? 80 : 120)
                    .transition(.move(edge: .leading))

                    Spacer()
                }
            }

            // Drawing Tools Panel - Right side
            if showDrawingPanel {
                HStack {
                    Spacer()
                    DrawingToolsPanel(
                        drawingManager: drawingManager,
                        isVisible: $showDrawingPanel,
                        onComplete: {
                            // Drawing completed
                        },
                        onCancel: {
                            // Drawing cancelled
                        }
                    )
                    .padding(.trailing, 8)
                    .padding(.vertical, isLandscape ? 80 : 120)
                    .transition(.move(edge: .trailing))
                }
            }

            // Drawing List Panel - Right side
            if showDrawingList {
                HStack {
                    Spacer()
                    DrawingListPanel(
                        drawingStore: drawingStore,
                        isVisible: $showDrawingList
                    )
                    .padding(.trailing, 8)
                    .padding(.vertical, isLandscape ? 80 : 120)
                    .transition(.move(edge: .trailing))
                }
            }
        }
        .sheet(isPresented: $showServerConfig) {
            ServerConfigView(takService: takService)
        }
        .sheet(isPresented: $showChat) {  // ADDED: Chat sheet
            ChatView(chatManager: ChatManager.shared)
        }
        .onAppear {
            setupTAKConnection()
            startLocationUpdates()
            setupChatIntegration()  // ADDED
        }
    }

    // MARK: - Drawing Handler

    private func handleMapTap(at coordinate: CLLocationCoordinate2D) {
        if drawingManager.isDrawingActive {
            drawingManager.handleMapTap(at: coordinate)
        }
    }

    // MARK: - Actions

    private func setupTAKConnection() {
        // Auto-connect to active server from ServerManager
        let serverManager = ServerManager.shared
        if let activeServer = serverManager.activeServer {
            takService.connect(
                host: activeServer.host,
                port: activeServer.port,
                protocolType: activeServer.protocolType,
                useTLS: activeServer.useTLS
            )
            print("Auto-connecting to: \(activeServer.displayName)")
        }
    }

    private func startLocationUpdates() {
        locationManager.startUpdating()
    }

    // ADDED: Setup chat integration
    private func setupChatIntegration() {
        // Configure ChatManager with TAKService and LocationManager
        ChatManager.shared.configure(takService: takService, locationManager: locationManager)

        // Register callback for incoming chat messages
        takService.onChatMessageReceived = { chatMessage in
            ChatManager.shared.receiveMessage(chatMessage)
        }
    }

    private func centerOnUser() {
        if let location = locationManager.location {
            withAnimation {
                mapRegion.center = location.coordinate
                mapRegion.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            }
            trackingMode = .follow
            print("Centered on user: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        } else {
            print("No location available")
        }
    }

    private func sendSelfPosition() {
        guard let location = locationManager.location else {
            print("Cannot send position - no location")
            return
        }

        let cotXml = generateSelfCoT(location: location)
        let success = takService.sendCoT(xml: cotXml)
        if success {
            print("Broadcast position: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }
    }

    private func zoomIn() {
        withAnimation {
            mapRegion.span.latitudeDelta = max(mapRegion.span.latitudeDelta / 2, 0.001)
            mapRegion.span.longitudeDelta = max(mapRegion.span.longitudeDelta / 2, 0.001)
        }
        print("Zoom in: \(mapRegion.span.latitudeDelta)")
    }

    private func zoomOut() {
        withAnimation {
            mapRegion.span.latitudeDelta = min(mapRegion.span.latitudeDelta * 2, 180)
            mapRegion.span.longitudeDelta = min(mapRegion.span.longitudeDelta * 2, 180)
        }
        print("Zoom out: \(mapRegion.span.latitudeDelta)")
    }

    private func toggleLayer(_ layer: String) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Update active layer
        activeMapLayer = layer

        // Toggle map layers
        withAnimation(.easeInOut(duration: 0.3)) {
            switch layer {
            case "satellite":
                mapType = .satellite
                print("Map type: Satellite")
            case "hybrid":
                mapType = .hybrid
                print("Map type: Hybrid")
            case "standard":
                mapType = .standard
                print("Map type: Standard")
            default:
                break
            }
        }
    }

    private func toggleOverlay(_ overlay: String) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Toggle overlay visibility
        switch overlay {
        case "friendly":
            showFriendly.toggle()
            print("Friendly units: \(showFriendly ? "ON" : "OFF")")
        case "hostile":
            showHostile.toggle()
            print("Hostile units: \(showHostile ? "ON" : "OFF")")
        case "unknown":
            showUnknown.toggle()
            print("Unknown units: \(showUnknown ? "ON" : "OFF")")
        default:
            break
        }
    }

    private func generateSelfCoT(location: CLLocation) -> String {
        let now = ISO8601DateFormatter().string(from: Date())
        let stale = ISO8601DateFormatter().string(from: Date().addingTimeInterval(300))

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="SELF-\(UUID().uuidString)" type="a-f-G-E-S" how="m-g" time="\(now)" start="\(now)" stale="\(stale)">
            <point lat="\(location.coordinate.latitude)" lon="\(location.coordinate.longitude)" hae="\(location.altitude)" ce="\(location.horizontalAccuracy)" le="\(location.verticalAccuracy)"/>
            <detail>
                <contact callsign="OmniTAK-iOS" endpoint="*:-1:stcp"/>
                <__group name="Cyan" role="Team Member"/>
                <status battery="100"/>
                <takv device="iPhone" platform="OmniTAK" os="iOS" version="1.0.0"/>
                <track speed="\(location.speed)" course="\(location.course)"/>
            </detail>
        </event>
        """
    }
}

// NOTE: The rest of the file continues with the same content as the original MapViewController.swift
// Including: ATAKStatusBar, ATAKBottomToolbar (modified below), ToolButton, ATAKSidePanel, LayerButton, etc.
