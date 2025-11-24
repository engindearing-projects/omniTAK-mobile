//
//  MapViewController_FilterIntegration.swift
//  OmniTAKTest
//
//  INSTRUCTIONS FOR INTEGRATION:
//  This file shows the modifications needed to integrate the CoT Filter feature
//  into the existing MapViewController.swift
//
//  Changes to make in MapViewController.swift:
//
//  1. Add these @StateObject declarations after the existing ones (around line 8-10):
//     @StateObject private var filterManager = CoTFilterManager()
//     @StateObject private var filterCriteria = CoTFilterCriteria()
//
//  2. Add these @State variables after the existing layer states (around line 29):
//     @State private var showFilterPanel = false
//     @State private var showUnitList = false
//     @State private var selectedCoTEvent: EnrichedCoTEvent? = nil
//
//  3. Replace the cotMarkers computed property (lines 45-72) with:

/*
    // Computed CoT markers from TAK service - filtered by advanced filters
    private var cotMarkers: [CoTMarker] {
        // Update filter manager with current events
        filterManager.updateEvents(takService.cotEvents, userLocation: locationManager.location)

        // Apply filters
        let filteredEvents = filterManager.applyFilters(criteria: filterCriteria)

        // Convert to markers and apply legacy overlay filters
        return filteredEvents.compactMap { event in
            let marker = CoTMarker(
                uid: event.uid,
                coordinate: event.coordinate,
                type: event.type,
                callsign: event.callsign,
                team: event.team ?? "Unknown"
            )

            // Legacy overlay filters (for backward compatibility)
            if event.type.contains("a-f") && !showFriendly {
                return nil
            }
            if event.type.contains("a-h") && !showHostile {
                return nil
            }
            if event.type.contains("a-u") && !showUnknown {
                return nil
            }

            return marker
        }
    }
*/

//  4. In the body's ZStack, after the showLayersPanel section (around line 132),
//     add these new panel sections:

/*
            // Filter Panel (Right Side)
            if showFilterPanel {
                HStack {
                    Spacer()

                    CoTFilterPanel(
                        criteria: filterCriteria,
                        filterManager: filterManager,
                        isExpanded: $showFilterPanel
                    )
                    .padding(.trailing, 8)
                    .padding(.vertical, isLandscape ? 80 : 120)
                    .transition(.move(edge: .trailing))
                }
            }

            // Unit List Panel (Right Side)
            if showUnitList {
                HStack {
                    Spacer()

                    CoTUnitListView(
                        filterManager: filterManager,
                        criteria: filterCriteria,
                        isExpanded: $showUnitList,
                        selectedEvent: $selectedCoTEvent,
                        mapRegion: $mapRegion
                    )
                    .padding(.trailing, 8)
                    .padding(.vertical, isLandscape ? 80 : 120)
                    .transition(.move(edge: .trailing))
                }
            }
*/

//  5. In ATAKBottomToolbar (around line 346), add these new buttons before the Spacer():

/*
            // Filter Button
            ToolButton(icon: "line.3.horizontal.decrease.circle.fill", label: "Filter") {
                withAnimation(.spring()) {
                    showFilterPanel.toggle()
                    if showFilterPanel {
                        showUnitList = false
                        showLayersPanel = false
                    }
                }
            }

            // Unit List Button
            ToolButton(icon: "list.bullet.rectangle", label: "Units") {
                withAnimation(.spring()) {
                    showUnitList.toggle()
                    if showUnitList {
                        showFilterPanel = false
                        showLayersPanel = false
                    }
                }
            }
*/

//  6. In the onAppear block (around line 140), add:
//     filterManager.updateUserLocation(locationManager.location)
//
//  7. Optional - Add a periodic update to refresh ages. Add this after onAppear:

/*
            .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
                // Update filter manager with current location for distance recalculation
                filterManager.updateUserLocation(locationManager.location)
            }
*/

// END OF INTEGRATION INSTRUCTIONS
//
// The complete modified sections are shown below for reference:

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Modified ATAKMapView (Reference Implementation)

struct ATAKMapViewWithFilters: View {
    @StateObject private var takService = TAKService()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var filterManager = CoTFilterManager()          // NEW
    @StateObject private var filterCriteria = CoTFilterCriteria()        // NEW

    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var showServerConfig = false
    @State private var showLayersPanel = false
    @State private var showFilterPanel = false                            // NEW
    @State private var showUnitList = false                               // NEW
    @State private var selectedCoTEvent: EnrichedCoTEvent? = nil          // NEW
    @State private var mapType: MKMapType = .satellite
    @State private var trackingMode: MapUserTrackingMode = .follow

    // Layer states
    @State private var activeMapLayer = "satellite"
    @State private var showFriendly = true
    @State private var showHostile = true
    @State private var showUnknown = false

    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var isLandscape: Bool {
        horizontalSizeClass == .regular || verticalSizeClass == .compact
    }

    // MODIFIED: Enhanced CoT markers with filtering
    private var cotMarkers: [CoTMarker] {
        // Update filter manager with current events and location
        filterManager.updateEvents(takService.cotEvents, userLocation: locationManager.location)

        // Apply advanced filters
        let filteredEvents = filterManager.applyFilters(criteria: filterCriteria)

        // Convert to markers and apply legacy overlay filters
        return filteredEvents.compactMap { event in
            let marker = CoTMarker(
                uid: event.uid,
                coordinate: event.coordinate,
                type: event.type,
                callsign: event.callsign,
                team: event.team ?? "Unknown"
            )

            // Legacy overlay filters (backward compatibility)
            if event.type.contains("a-f") && !showFriendly {
                return nil
            }
            if event.type.contains("a-h") && !showHostile {
                return nil
            }
            if event.type.contains("a-u") && !showUnknown {
                return nil
            }

            return marker
        }
    }

    var body: some View {
        ZStack {
            // Main Map View
            TacticalMapView(
                region: $mapRegion,
                mapType: $mapType,
                trackingMode: $trackingMode,
                markers: cotMarkers,
                showsUserLocation: true
            )
            .ignoresSafeArea()

            // Top Status Bar
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

                // Bottom Toolbar with NEW filter buttons
                ATAKBottomToolbarWithFilters(
                    mapType: $mapType,
                    showLayersPanel: $showLayersPanel,
                    showFilterPanel: $showFilterPanel,         // NEW
                    showUnitList: $showUnitList,               // NEW
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

            // Left Side Panel (Layers)
            if showLayersPanel {
                HStack {
                    ATAKSidePanel(
                        isExpanded: $showLayersPanel,
                        activeMapLayer: $activeMapLayer,
                        showFriendly: $showFriendly,
                        showHostile: $showHostile,
                        showUnknown: $showUnknown,
                        onLayerToggle: { layer in toggleLayer(layer) },
                        onOverlayToggle: { overlay in toggleOverlay(overlay) }
                    )
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(12)
                    .padding(.leading, 8)
                    .padding(.vertical, isLandscape ? 80 : 120)
                    .transition(.move(edge: .leading))

                    Spacer()
                }
            }

            // NEW: Filter Panel (Right Side)
            if showFilterPanel {
                HStack {
                    Spacer()

                    CoTFilterPanel(
                        criteria: filterCriteria,
                        filterManager: filterManager,
                        isExpanded: $showFilterPanel
                    )
                    .padding(.trailing, 8)
                    .padding(.vertical, isLandscape ? 80 : 120)
                    .transition(.move(edge: .trailing))
                }
            }

            // NEW: Unit List Panel (Right Side)
            if showUnitList {
                HStack {
                    Spacer()

                    CoTUnitListView(
                        filterManager: filterManager,
                        criteria: filterCriteria,
                        isExpanded: $showUnitList,
                        selectedEvent: $selectedCoTEvent,
                        mapRegion: $mapRegion
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
        .onAppear {
            setupTAKConnection()
            startLocationUpdates()
            filterManager.updateUserLocation(locationManager.location)  // NEW
        }
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
            // NEW: Periodic update for distance/age recalculation
            filterManager.updateUserLocation(locationManager.location)
        }
    }

    // MARK: - Actions (same as original)

    private func setupTAKConnection() {
        let serverManager = ServerManager.shared
        if let activeServer = serverManager.activeServer {
            takService.connect(
                host: activeServer.host,
                port: activeServer.port,
                protocolType: activeServer.protocolType,
                useTLS: activeServer.useTLS
            )
            #if DEBUG
            print("🔌 Auto-connecting to: \(activeServer.displayName)")
            #endif
        }
    }

    private func startLocationUpdates() {
        locationManager.startUpdating()
    }

    private func centerOnUser() {
        if let location = locationManager.location {
            withAnimation {
                mapRegion.center = location.coordinate
                mapRegion.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            }
            trackingMode = .follow
            #if DEBUG
            print("🎯 Centered on user: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            #endif
        } else {
            print("❌ No location available")
        }
    }

    private func sendSelfPosition() {
        guard let location = locationManager.location else {
            print("❌ Cannot send position - no location")
            return
        }

        let cotXml = generateSelfCoT(location: location)
        let success = takService.sendCoT(xml: cotXml)
        if success {
            #if DEBUG
            print("📤 Broadcast position: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            #endif
        }
    }

    private func zoomIn() {
        withAnimation {
            mapRegion.span.latitudeDelta = max(mapRegion.span.latitudeDelta / 2, 0.001)
            mapRegion.span.longitudeDelta = max(mapRegion.span.longitudeDelta / 2, 0.001)
        }
        #if DEBUG
        print("🔍 Zoom in: \(mapRegion.span.latitudeDelta)")
        #endif
    }

    private func zoomOut() {
        withAnimation {
            mapRegion.span.latitudeDelta = min(mapRegion.span.latitudeDelta * 2, 180)
            mapRegion.span.longitudeDelta = min(mapRegion.span.longitudeDelta * 2, 180)
        }
        #if DEBUG
        print("🔍 Zoom out: \(mapRegion.span.latitudeDelta)")
        #endif
    }

    private func toggleLayer(_ layer: String) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        activeMapLayer = layer

        withAnimation(.easeInOut(duration: 0.3)) {
            switch layer {
            case "satellite":
                mapType = .satellite
                #if DEBUG
                print("🗺️ Map type: Satellite")
                #endif
            case "hybrid":
                mapType = .hybrid
                #if DEBUG
                print("🗺️ Map type: Hybrid")
                #endif
            case "standard":
                mapType = .standard
                #if DEBUG
                print("🗺️ Map type: Standard")
                #endif
            default:
                break
            }
        }
    }

    private func toggleOverlay(_ overlay: String) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        switch overlay {
        case "friendly":
            showFriendly.toggle()
            print("👥 Friendly units: \(showFriendly ? "ON" : "OFF")")
        case "hostile":
            showHostile.toggle()
            #if DEBUG
            print("⚠️ Hostile units: \(showHostile ? "ON" : "OFF")")
            #endif
        case "unknown":
            showUnknown.toggle()
            print("❓ Unknown units: \(showUnknown ? "ON" : "OFF")")
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

// MARK: - Modified Bottom Toolbar

struct ATAKBottomToolbarWithFilters: View {
    @Binding var mapType: MKMapType
    @Binding var showLayersPanel: Bool
    @Binding var showFilterPanel: Bool          // NEW
    @Binding var showUnitList: Bool             // NEW
    let onCenterUser: () -> Void
    let onSendCoT: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            // Layers
            ToolButton(icon: "square.stack.3d.up.fill", label: "Layers") {
                withAnimation(.spring()) {
                    showLayersPanel.toggle()
                    if showLayersPanel {
                        showFilterPanel = false
                        showUnitList = false
                    }
                }
            }

            // NEW: Filter Button
            ToolButton(icon: "line.3.horizontal.decrease.circle.fill", label: "Filter") {
                withAnimation(.spring()) {
                    showFilterPanel.toggle()
                    if showFilterPanel {
                        showUnitList = false
                        showLayersPanel = false
                    }
                }
            }

            // NEW: Unit List Button
            ToolButton(icon: "list.bullet.rectangle", label: "Units") {
                withAnimation(.spring()) {
                    showUnitList.toggle()
                    if showUnitList {
                        showFilterPanel = false
                        showLayersPanel = false
                    }
                }
            }

            Spacer()

            // Center on User
            ToolButton(icon: "location.fill", label: "GPS") {
                onCenterUser()
            }

            // Send Position
            ToolButton(icon: "paperplane.fill", label: "Broadcast") {
                onSendCoT()
            }

            // Zoom Controls
            VStack(spacing: 8) {
                ToolButton(icon: "plus", label: "", compact: true) {
                    onZoomIn()
                }
                ToolButton(icon: "minus", label: "", compact: true) {
                    onZoomOut()
                }
            }

            Spacer()

            // Measure Tool
            ToolButton(icon: "ruler", label: "Measure") {
                // TODO: Implement measure tool
            }

            // Route Tool
            ToolButton(icon: "arrow.triangle.turn.up.right.diamond.fill", label: "Route") {
                // TODO: Implement route tool
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
