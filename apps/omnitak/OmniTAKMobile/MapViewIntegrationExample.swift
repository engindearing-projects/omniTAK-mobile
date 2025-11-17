//
//  MapViewIntegrationExample.swift
//  OmniTAKMobile
//
//  Example integration showing how to wire up all the new map overlay features
//  This demonstrates the usage of MapOverlayCoordinator, MapStateManager, and MGRSGridToggleView
//

import SwiftUI
import MapKit
import CoreLocation

// MARK: - Enhanced ATAK Map View with Full Overlay Support

/// Example view demonstrating full integration of MGRS grid, overlay coordinator, and state manager
struct EnhancedATAKMapViewExample: View {

    // MARK: - State Objects

    @StateObject private var overlayCoordinator = MapOverlayCoordinator()
    @StateObject private var stateManager = MapStateManager()
    @StateObject private var drawingStore = DrawingStore()
    @StateObject private var drawingManager: DrawingToolsManager
    @StateObject private var radialMenuCoordinator = RadialMenuMapCoordinator()

    // MARK: - Map State

    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var mapType: MKMapType = .satellite
    @State private var trackingMode: MapUserTrackingMode = .follow

    // MARK: - UI State

    @State private var showLayersPanel = false
    @State private var showSettings = false

    // MARK: - Sample Data

    private var sampleMarkers: [CoTMarker] {
        [
            CoTMarker(
                uid: "sample-1",
                coordinate: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
                type: "a-f-G-E-S",
                callsign: "ALPHA-1",
                team: "Cyan"
            )
        ]
    }

    // MARK: - Initialization

    init() {
        let store = DrawingStore()
        _drawingStore = StateObject(wrappedValue: store)
        _drawingManager = StateObject(wrappedValue: DrawingToolsManager(drawingStore: store))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Main Map View with full integration
            IntegratedMapView(
                region: $mapRegion,
                mapType: $mapType,
                trackingMode: $trackingMode,
                markers: sampleMarkers,
                showsUserLocation: true,
                drawingStore: drawingStore,
                drawingManager: drawingManager,
                radialMenuCoordinator: radialMenuCoordinator,
                overlayCoordinator: overlayCoordinator,
                stateManager: stateManager,
                onMapTap: handleMapTap
            )
            .ignoresSafeArea()

            // Cursor Crosshair (when in cursor/measurement mode)
            CursorCrosshairView(stateManager: stateManager)

            // Top Status Bar
            VStack(spacing: 0) {
                topStatusBar
                    .padding(.horizontal, 8)
                    .padding(.top, 8)

                Spacer()

                // Bottom Toolbar
                bottomToolbar
                    .padding(.horizontal, 8)
                    .padding(.bottom, 20)
            }

            // MGRS Grid Toggle Button - Top Left
            VStack {
                HStack {
                    MGRSGridToggleView(
                        overlayCoordinator: overlayCoordinator,
                        stateManager: stateManager
                    )
                    .padding(.leading, 16)
                    .padding(.top, 70)

                    Spacer()
                }
                Spacer()
            }

            // Coordinate Format Picker - Top Right
            VStack {
                HStack {
                    Spacer()
                    CoordinateFormatPicker(stateManager: stateManager)
                        .padding(.trailing, 16)
                        .padding(.top, 70)
                }
                Spacer()
            }

            // MGRS Center Coordinate Display - Top Center
            if overlayCoordinator.mgrsGridEnabled {
                VStack {
                    MGRSCoordinateOverlay(
                        overlayCoordinator: overlayCoordinator,
                        stateManager: stateManager
                    )
                    .padding(.top, 70)

                    Spacer()
                }
            }

            // Mode Indicator - Bottom Left
            VStack {
                Spacer()
                HStack {
                    modeIndicator
                        .padding(.leading, 16)
                        .padding(.bottom, 100)
                    Spacer()
                }
            }

            // Range & Bearing Display
            if stateManager.rangeBearingState.isComplete {
                VStack {
                    Spacer()
                    rangeBearingDisplay
                        .padding(.bottom, 150)
                }
            }

            // Radial Menu
            if radialMenuCoordinator.showRadialMenu {
                RadialMenuView(
                    isPresented: $radialMenuCoordinator.showRadialMenu,
                    centerPoint: radialMenuCoordinator.menuCenterPoint,
                    configuration: radialMenuCoordinator.menuConfiguration,
                    onSelect: { action in
                        radialMenuCoordinator.executeAction(action)
                    }
                )
                .zIndex(3000)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            setupInitialState()
        }
        .onDisappear {
            saveState()
        }
    }

    // MARK: - Sub Views

    private var topStatusBar: some View {
        HStack(spacing: 12) {
            Text("OmniTAK")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(red: 1.0, green: 0.988, blue: 0.0))

            Spacer()

            // Current Coordinate Display
            Text(stateManager.formattedCenterCoordinate)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.green)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer()

            // Settings Button
            Button(action: { showSettings = true }) {
                Image(systemName: "gear")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
    }

    private var bottomToolbar: some View {
        HStack(spacing: 20) {
            // Layers Button
            Button(action: { showLayersPanel.toggle() }) {
                toolButton(icon: "square.stack.3d.up.fill", label: "Layers")
            }

            Spacer()

            // Mode Buttons
            modeButton(.normal, icon: "map", label: "Normal")
            modeButton(.cursor, icon: "scope", label: "Cursor")
            modeButton(.rangeBearing, icon: "arrow.triangle.swap", label: "R&B")

            Spacer()

            // Zoom Controls
            VStack(spacing: 8) {
                Button(action: zoomIn) {
                    compactButton(icon: "plus")
                }
                Button(action: zoomOut) {
                    compactButton(icon: "minus")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var modeIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: stateManager.currentMode.icon)
                .font(.system(size: 14))
            Text(stateManager.currentMode.rawValue)
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(modeColor.opacity(0.9))
        .cornerRadius(8)
    }

    private var modeColor: Color {
        switch stateManager.currentMode {
        case .normal: return .gray
        case .cursor: return .blue
        case .drawing: return .purple
        case .measurement: return .orange
        case .rangeBearing: return .red
        case .pointDrop: return .green
        case .trackRecording: return .yellow
        }
    }

    private var rangeBearingDisplay: some View {
        VStack(spacing: 4) {
            Text("RANGE & BEARING")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.orange)

            Text(stateManager.formatRangeBearingInfo())
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Button("Clear") {
                stateManager.resetRangeBearing()
            }
            .font(.system(size: 11))
            .foregroundColor(.red)
        }
        .padding(12)
        .background(Color.black.opacity(0.9))
        .cornerRadius(10)
    }

    // MARK: - Helper Views

    private func toolButton(icon: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
            Text(label)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundColor(.white)
        .frame(width: 56, height: 56)
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    private func compactButton(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 36, height: 36)
            .background(Color.black.opacity(0.6))
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }

    private func modeButton(_ mode: MapMode, icon: String, label: String) -> some View {
        Button(action: { stateManager.setMode(mode) }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(stateManager.currentMode == mode ? .green : .white)
            .frame(width: 56, height: 56)
            .background(stateManager.currentMode == mode ? Color.green.opacity(0.3) : Color.black.opacity(0.6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(stateManager.currentMode == mode ? Color.green : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func handleMapTap(at coordinate: CLLocationCoordinate2D) {
        // Handle based on current drawing state
        if drawingManager.isDrawingActive {
            drawingManager.handleMapTap(at: coordinate)
        }
    }

    private func zoomIn() {
        withAnimation {
            mapRegion.span.latitudeDelta = max(mapRegion.span.latitudeDelta / 2, 0.001)
            mapRegion.span.longitudeDelta = max(mapRegion.span.longitudeDelta / 2, 0.001)
        }
    }

    private func zoomOut() {
        withAnimation {
            mapRegion.span.latitudeDelta = min(mapRegion.span.latitudeDelta * 2, 180)
            mapRegion.span.longitudeDelta = min(mapRegion.span.longitudeDelta * 2, 180)
        }
    }

    private func setupInitialState() {
        overlayCoordinator.loadSettings()
        stateManager.loadPreferences()
        radialMenuCoordinator.configure(drawingStore: drawingStore)
    }

    private func saveState() {
        overlayCoordinator.saveSettings()
        stateManager.savePreferences()
    }
}

// MARK: - Integration Guide

/*
 INTEGRATION STEPS:

 1. Add these StateObject properties to your main map view:
    @StateObject private var overlayCoordinator = MapOverlayCoordinator()
    @StateObject private var stateManager = MapStateManager()

 2. Replace TacticalMapView with IntegratedMapView in your view hierarchy

 3. Add overlay control UI elements:
    - MGRSGridToggleView for grid toggle button
    - CoordinateFormatPicker for coordinate format selection
    - CursorCrosshairView for cursor/measurement modes
    - MGRSCoordinateOverlay for center coordinate display

 4. Update SettingsView to include map overlay settings (already done)

 5. Configure radial menu coordinator with drawing store:
    radialMenuCoordinator.configure(drawingStore: drawingStore)

 6. Handle lifecycle:
    .onAppear { overlayCoordinator.loadSettings(); stateManager.loadPreferences() }
    .onDisappear { overlayCoordinator.saveSettings(); stateManager.savePreferences() }

 KEY FEATURES:

 - MGRS Grid Overlay: Military grid lines with density options (None, 1km, 10km, 100km)
 - Coordinate Display: Multiple formats (DD, DM, DMS, MGRS, UTM)
 - Map Modes: Normal, Cursor, Drawing, Measurement, R&B, Point Drop, Track Recording
 - Overlay Z-Ordering: Grid (bottom), Trails (middle), Markers (top)
 - Performance: Only renders visible overlays
 - Settings Persistence: All preferences saved to UserDefaults

 COORDINATION WITH OTHER AGENTS:

 - Frontend (FE) Agent: UI components are SwiftUI-based and integrate with existing patterns
 - Backend (BE) Agent: Overlay types support BreadcrumbTrailOverlay, RangeBearingOverlay if created
 - No circular dependencies: Each module is self-contained with clear interfaces
 */

// MARK: - Preview

struct EnhancedATAKMapViewExample_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedATAKMapViewExample()
    }
}
