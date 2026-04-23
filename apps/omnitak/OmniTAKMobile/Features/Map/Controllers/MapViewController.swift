import SwiftUI
import MapKit
import CoreLocation

// ATAK-style Map View with tactical interface
struct ATAKMapView: View {
    @ObservedObject private var takService = TAKService.shared
    @StateObject private var federation = MultiServerFederation()  // Multi-server support
    @StateObject private var locationManager = LocationManager()
    @StateObject private var drawingStore: DrawingStore
    @StateObject private var drawingManager: DrawingToolsManager
    @StateObject private var radialMenuCoordinator = RadialMenuMapCoordinator()
    @ObservedObject private var chatManager = ChatManager.shared
    @StateObject private var trackRecordingService = TrackRecordingService()
    @StateObject private var overlayCoordinator = MapOverlayCoordinator()
    @StateObject private var routeOverlayCoordinator = RouteOverlayCoordinator()
    @ObservedObject private var routeService = RoutePlanningService.shared
    @StateObject private var mapStateManager = MapStateManager()
    @StateObject private var measurementManager = MeasurementManager()
    @ObservedObject private var adsbService = ADSBTrafficService.shared
    @ObservedObject private var pointDropperService = PointDropperService.shared
    @ObservedObject private var serverManager = ServerManager.shared

    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365), // Default: DC
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var showServerConfig = false
    @State private var showLayersPanel = false
    @State private var showDrawingPanel = false
    @State private var showDrawingList = false
    // Radial menu → Edit on a PointMarker posts .radialMenuEditMarker;
    // we hold the marker id here so a sheet can open the edit form.
    @State private var editingPointMarkerID: UUID?
    @State private var mapType: MKMapType = .satellite
    @State private var showToolsMenu = false
    @State private var showLoadingScreen = true
    @State private var showGPSError = false
    @State private var showGeofenceAlert = false
    @State private var showTraffic = false
    @State private var trackingMode: MapUserTrackingMode = .none
    @State private var orientation = UIDeviceOrientation.unknown

    // Feature screen states
    @State private var showTeamManagement = false
    @State private var showRoutePlanning = false
    @State private var showGeofences = false
    @State private var showTrackRecording = false
    @State private var showChat = false
    @State private var showContacts = false
    @State private var showEmergencySOS = false
    @State private var showSettings = false
    @State private var showPlugins = false
    @State private var showAbout = false
    @State private var showPositionBroadcast = false
    @State private var showElevationProfile = false

    // User settings
    @AppStorage("userCallsign") private var userCallsign = "ALPHA-1"
    @State private var showLineOfSight = false
    @State private var showEchelonHierarchy = false
    @State private var showMissionSync = false
    @State private var showMeshtastic = false
    @State private var showMeasurement = false
    @State private var showAppModePicker = false

    // Position broadcasting service
    @ObservedObject private var positionBroadcastService = PositionBroadcastService.shared

    // Layer states
    @State private var activeMapLayer = "satellite"
    @State private var showFriendly = true
    @State private var showHostile = true
    @State private var showNeutral = true      // Added: Neutral units (a-n-*)
    @State private var showUnknown = true      // Changed: Default to TRUE - show unknown by default

    // Map overlay states
    @State private var showCompass = false  // Hidden by default for max map space
    @State private var showCoordinates = false  // Hidden by default for max map space
    @State private var showScaleBar = true  // ATAK-style: Enabled by default in bottom-left
    @State private var showGrid = false

    // New ATAK-style UI states
    @State private var isCursorModeActive = false
    @State private var showQuickActionToolbar = false  // Hidden - user can access tools via radial menu and ATAK tools menu
    @StateObject private var cursorModeCoordinator = MapCursorModeCoordinator()
    @State private var showRangeBearingLine = false
    @State private var showRouteHere = false
    @State private var showOverlaySettings = false
    @State private var showBreadcrumbTrails = false
    @State private var showRBLines = false
    @State private var showCallsignPanel = true  // ATAK-style: Enabled by default in bottom-right
    @State private var isNavigationPanelExpanded = false  // Route navigation panel state

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

            // Filter based on overlay settings and CoT affiliation
            // CoT type format: a-{affiliation}-{dimension}-{function}
            // Affiliations: f=friendly, h=hostile, n=neutral, u=unknown
            //               j=joker (exercise hostile), k=faker (exercise friendly)
            //               s=suspect, a=assumed friendly

            // Determine affiliation from CoT type
            let type = event.type.lowercased()

            if type.hasPrefix("a-f") || type.hasPrefix("a-k") || type.hasPrefix("a-a") {
                // Friendly, Faker (exercise friendly), Assumed Friendly
                if !showFriendly {
                    return nil
                }
            } else if type.hasPrefix("a-h") || type.hasPrefix("a-j") || type.hasPrefix("a-s") {
                // Hostile, Joker (exercise hostile), Suspect
                if !showHostile {
                    return nil
                }
            } else if type.hasPrefix("a-n") {
                // Neutral
                if !showNeutral {
                    return nil
                }
            } else if type.hasPrefix("a-u") {
                // Unknown affiliation
                if !showUnknown {
                    return nil
                }
            } else if type.hasPrefix("a-") {
                // Any other 'a-' type we don't recognize - treat as unknown
                // This ensures we don't accidentally hide valid units
                if !showUnknown {
                    return nil
                }
            }
            // Non 'a-' types (waypoints, markers, etc.) are ALWAYS shown
            // They don't have affiliations and should never be filtered

            return marker
        }
    }

    // MARK: - Computed Properties to Fix Type Checking

    @ViewBuilder
    private var mainMapView: some View {
        TacticalMapView(
            region: $mapRegion,
            mapType: $mapType,
            trackingMode: $trackingMode,
            markers: cotMarkers,
            pointMarkers: pointDropperService.markers,
            aircraft: adsbService.settings.isEnabled ? adsbService.aircraft : [],
            showsUserLocation: true,
            drawingStore: drawingStore,
            drawingManager: drawingManager,
            radialMenuCoordinator: radialMenuCoordinator,
            overlayCoordinator: overlayCoordinator,
            routeOverlayCoordinator: routeOverlayCoordinator,
            mapStateManager: mapStateManager,
            measurementManager: measurementManager,
            onMapTap: handleMapTap
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var gridOverlay: some View {
        // No explicit zIndex — the ZStack child order keeps the grid above
        // the map but below UI chrome (status bar, zoom buttons, panels,
        // which all use zIndex 1000+). A prior zIndex(100) was lifting the
        // grid over the top status bar / zoom controls (#43).
        GridOverlayView(region: mapRegion, isVisible: overlayCoordinator.mgrsGridEnabled)
            .opacity(overlayCoordinator.mgrsGridEnabled ? 1 : 0)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var topToolbars: some View {
        VStack(spacing: 0) {
            ATAKStatusBar(
                connectionStatus: takService.isConnected ? "Connected" : "Disconnected",
                isConnected: takService.isConnected,
                messagesReceived: takService.messagesReceived,
                messagesSent: takService.messagesSent,
                gpsAccuracy: locationManager.accuracy,
                serverName: serverManager.activeServer?.name ?? "Offline",
                onServerTap: { showServerConfig = true },
                onMenuTap: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showToolsMenu = true
                    }
                }
            )
            .id("statusbar-\(takService.isConnected)-\(takService.messagesReceived)-\(takService.messagesSent)")

            Spacer()

            bottomToolbars
        }
    }

    @ViewBuilder
    private var bottomToolbars: some View {
        VStack(spacing: 0) {
            ATAKBottomToolbar(
                mapType: $mapType,
                showLayersPanel: $showLayersPanel,
                showDrawingPanel: $showDrawingPanel,
                showDrawingList: $showDrawingList,
                onZoomIn: zoomIn,
                onZoomOut: zoomOut
            )
            .padding(.horizontal, 8)
            .padding(.bottom, isCursorModeActive ? 240 : 140)

            if showQuickActionToolbar && !isCursorModeActive {
                QuickActionToolbar(
                    mapRegion: $mapRegion,
                    showGrid: $showGrid,
                    showLayersPanel: $showLayersPanel,
                    isCursorModeActive: $isCursorModeActive,
                    userLocation: locationManager.location,
                    onDropPoint: { coordinate in
                        dropMarkerAtLocation(coordinate: coordinate, affiliation: .friendly)
                    },
                    onToggleMeasure: {
                        showMeasurement = true
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 15)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    @ViewBuilder
    private var sidePanels: some View {
        Group {
            layersPanel
            drawingToolsPanel
            drawingListPanel
        }
    }

    @ViewBuilder
    private var layersPanel: some View {
        if showLayersPanel {
            HStack {
                ATAKSidePanel(
                    isExpanded: $showLayersPanel,
                    activeMapLayer: $activeMapLayer,
                    showFriendly: $showFriendly,
                    showHostile: $showHostile,
                    showNeutral: $showNeutral,
                    showUnknown: $showUnknown,
                    showCompass: $showCompass,
                    showCoordinates: $showCoordinates,
                    showScaleBar: $showScaleBar,
                    showGrid: $showGrid,
                    adsbService: ADSBTrafficService.shared,
                    onLayerToggle: { layer in
                        toggleLayer(layer)
                    },
                    onOverlayToggle: { overlay in
                        toggleOverlay(overlay)
                    },
                    onMapOverlayToggle: { overlay in
                        toggleMapOverlay(overlay)
                    }
                )
                .background(Color.black.opacity(0.9))
                .cornerRadius(12)
                .padding(.leading, 8)
                .padding(.vertical, isLandscape ? 80 : 120)
                .transition(.move(edge: .leading))

                Spacer()
            }
            .zIndex(1010)
        }
    }

    @ViewBuilder
    private var drawingToolsPanel: some View {
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
            .zIndex(1010)
        }
    }

    @ViewBuilder
    private var drawingListPanel: some View {
        if showDrawingList {
            HStack {
                Spacer()
                DrawingListPanel(
                    drawingStore: drawingStore,
                    isVisible: $showDrawingList,
                    onZoomToDrawing: { coordinate, radius in
                        zoomToDrawing(coordinate: coordinate, radius: radius)
                    }
                )
                .padding(.trailing, 8)
                .padding(.vertical, isLandscape ? 80 : 120)
                .transition(.move(edge: .trailing))
            }
            .zIndex(1010)
        }
    }

    @ViewBuilder
    private var statusIndicators: some View {
        Group {
            // GPS status indicator removed - GPS lock button at bottom left serves this purpose
            callsignDisplay
            geofenceAlert
        }
    }

    @ViewBuilder
    private var callsignDisplay: some View {
        if showCallsignPanel, let location = locationManager.location {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    CallsignDisplay(
                        callsign: userCallsign,
                        coordinates: formatCoordinates(location.coordinate),
                        altitude: formatAltitude(location.altitude),
                        speed: formatSpeed(location.speed),
                        heading: formatHeading(locationManager.heading),
                        accuracy: "+/- \(Int(location.horizontalAccuracy))m"
                    )
                    .padding(.trailing, 16)
                    .padding(.bottom, 120)
                }
            }
            .zIndex(1003)
        }
    }

    @ViewBuilder
    private var geofenceAlert: some View {
        if showGeofenceAlert {
            VStack {
                GeofenceAlertNotification(
                    geofenceName: "Circle 1",
                    action: "Entered",
                    callsign: userCallsign,
                    isPresented: $showGeofenceAlert
                )
                .padding(.top, 60)
                Spacer()
            }
            .zIndex(1004)
        }
    }

    @ViewBuilder
    private var mapOverlayComponents: some View {
        Group {
            compassOverlay
            // coordinateDisplay now integrated with GPS button to avoid overlap
            scaleBar
        }
    }

    @ViewBuilder
    private var compassOverlay: some View {
        // CLHeading (magnetometer) is the right source — location.course is
        // the direction of travel and freezes at the last value when the
        // user stops moving (what was causing #44 "always 347°"). Fall back
        // to course only if heading is unavailable (e.g., no magnetometer).
        CompassOverlayView(
            heading: compassHeading,
            isVisible: showCompass
        )
        .zIndex(1005)
    }

    private var compassHeading: CLLocationDirection? {
        if let heading = locationManager.heading {
            return heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
        }
        let course = locationManager.location?.course ?? -1
        return course >= 0 ? course : nil
    }

    @ViewBuilder
    private var coordinateDisplay: some View {
        CoordinateDisplayView(
            coordinate: locationManager.location?.coordinate,
            isVisible: showCoordinates
        )
        .zIndex(1006)
    }

    @ViewBuilder
    private var scaleBar: some View {
        ScaleBarView(
            region: mapRegion,
            isVisible: showScaleBar
        )
        .zIndex(1007)
    }

    @ViewBuilder
    private var interactiveOverlays: some View {
        Group {
            loadingScreen
            radialMenu
            cursorModeOverlay
            // overlaySettingsButton - Removed per user request
            // overlaySettingsPanel - Removed per user request
            // mapCenterDisplay - Removed per user request (coords available via radial menu)
        }
    }

    @ViewBuilder
    private var loadingScreen: some View {
        if showLoadingScreen {
            ATAKLoadingScreen(isLoading: $showLoadingScreen)
                .zIndex(2000)
        }
    }

    @ViewBuilder
    private var radialMenu: some View {
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

    @ViewBuilder
    private var cursorModeOverlay: some View {
        if isCursorModeActive {
            CursorModeOverlayView(
                coordinator: cursorModeCoordinator,
                mapRegion: mapRegion,
                onDropMarker: { coordinate in
                    dropMarkerAtLocation(coordinate: coordinate, affiliation: .friendly)
                },
                onClose: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isCursorModeActive = false
                        cursorModeCoordinator.deactivate()
                    }
                }
            )
            .zIndex(2500)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var overlaySettingsButton: some View {
        VStack {
            HStack {
                Button(action: {
                    withAnimation(.spring()) {
                        showOverlaySettings.toggle()
                    }
                }) {
                    Image(systemName: "square.stack.3d.up.badge.a")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(8)
                }
                .padding(.leading, 12)
                .padding(.top, 120)
                Spacer()
            }
            Spacer()
        }
        .zIndex(1008)
    }

    @ViewBuilder
    private var overlaySettingsPanel: some View {
        if showOverlaySettings {
            VStack {
                HStack {
                    OverlaySettingsPanel(
                        overlayCoordinator: overlayCoordinator,
                        mapStateManager: mapStateManager,
                        showMGRSGrid: Binding(
                            get: { overlayCoordinator.mgrsGridEnabled },
                            set: { overlayCoordinator.mgrsGridEnabled = $0 }
                        ),
                        showBreadcrumbTrails: Binding(
                            get: { overlayCoordinator.breadcrumbTrailsEnabled },
                            set: { overlayCoordinator.breadcrumbTrailsEnabled = $0 }
                        ),
                        showRBLines: Binding(
                            get: { overlayCoordinator.rangeBearingEnabled },
                            set: { overlayCoordinator.rangeBearingEnabled = $0 }
                        ),
                        onDismiss: {
                            withAnimation(.spring()) {
                                showOverlaySettings = false
                            }
                        }
                    )
                    .padding(.leading, 12)
                    .padding(.top, 170)
                    Spacer()
                }
                Spacer()
            }
            .zIndex(1009)
            .transition(.move(edge: .leading).combined(with: .opacity))
        }
    }

    // mapCenterDisplay removed - coordinates available via radial menu and settings

    @ViewBuilder
    private var gpsFollowButton: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom, spacing: 8) {
                // ATAK-style left-side control cluster
                VStack(spacing: 8) {
                    // GPS Lock/Center Button (crosshair icon)
                    Button(action: centerOnUser) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.75))
                                .frame(width: 44, height: 44)

                            Circle()
                                .stroke(trackingMode == .follow ? Color.cyan : Color.white.opacity(0.6), lineWidth: 2)
                                .frame(width: 44, height: 44)

                            Image(systemName: trackingMode == .follow ? "location.fill" : "location")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(trackingMode == .follow ? Color.cyan : .white)
                        }
                        .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)

                    // Zoom controls moved to bottom toolbar to match ATAK
                }

                // Coordinate display next to GPS button
                if showCoordinates {
                    CoordinateDisplayView(
                        coordinate: locationManager.location?.coordinate,
                        isVisible: true
                    )
                }

                Spacer()
            }
            .padding(.leading, 12)
            .padding(.bottom, isCursorModeActive ? 222 : (showQuickActionToolbar ? 150 : 90))
        }
        .zIndex(1012)
    }

    var body: some View {
        ZStack {
            mainMapView
            gridOverlay
            topToolbars
            sidePanels
            statusIndicators
            mapOverlayComponents
            interactiveOverlays
            gpsFollowButton

            // Compact measurement overlay (ATAK-style)
            if showMeasurement {
                CompactMeasurementOverlay(manager: measurementManager, isPresented: $showMeasurement)
                    .zIndex(1000)
            }

            // Route Navigation Panel (ATAK-style, top-left position)
            VStack {
                HStack {
                    RouteNavigationPanel(
                        routeService: routeService,
                        isExpanded: $isNavigationPanelExpanded
                    )
                    .frame(maxWidth: 320) // ATAK-style compact width
                    .padding(.leading, 8)
                    .padding(.top, 70) // Below status bar
                    Spacer()
                }
                Spacer()
            }
            .zIndex(1100)
        }
        .background(modalSheets)
        .background(errorOverlays)
        .background(lifecycleHandlers)
        .onReceive(NotificationCenter.default.publisher(for: .radialMenuEditMarker)) { notification in
            if let marker = notification.userInfo?["marker"] as? PointMarker {
                editingPointMarkerID = marker.id
            }
        }
        // Radial Edit on a drawing shape (marker/line/circle/polygon) posts
        // .radialMenuEditDrawing with the drawingId. DrawingPropertiesView
        // already handles every shape type by id — reuse the #38 sheet by
        // pushing the id through drawingManager.pendingRenameID.
        .onReceive(NotificationCenter.default.publisher(for: .radialMenuEditDrawing)) { notification in
            if let drawingId = notification.userInfo?["drawingId"] as? UUID {
                drawingManager.pendingRenameID = drawingId
            }
        }
    }

    private var modalSheets: some View {
        EmptyView()
            .sheet(isPresented: $showServerConfig) {
                NetworkPreferencesView()
            }
            // #38: prompt the user to name a shape immediately after creating
            // it. DrawingToolsManager publishes the new shape's id; we pop
            // the existing properties sheet (which already has a Name field).
            .sheet(isPresented: Binding(
                get: { drawingManager.pendingRenameID != nil },
                set: { if !$0 { drawingManager.pendingRenameID = nil } }
            )) {
                if let id = drawingManager.pendingRenameID {
                    DrawingPropertiesView(
                        drawingStore: drawingStore,
                        drawingID: id,
                        isPresented: Binding(
                            get: { drawingManager.pendingRenameID != nil },
                            set: { if !$0 { drawingManager.pendingRenameID = nil } }
                        )
                    )
                }
            }
            // Radial menu Edit → open PointMarker edit form. The radial
            // posts .radialMenuEditMarker (see RadialMenuActionExecutor);
            // without this observer the menu just dismissed silently.
            .sheet(isPresented: Binding(
                get: { editingPointMarkerID != nil },
                set: { if !$0 { editingPointMarkerID = nil } }
            )) {
                if let id = editingPointMarkerID {
                    PointMarkerEditView(
                        pointDropperService: pointDropperService,
                        markerID: id,
                        isPresented: Binding(
                            get: { editingPointMarkerID != nil },
                            set: { if !$0 { editingPointMarkerID = nil } }
                        )
                    )
                }
            }
            .fullScreenCover(isPresented: $showToolsMenu) {
                ATAKToolsView(isPresented: $showToolsMenu, showMeasurement: $showMeasurement)
            }
            .sheet(isPresented: $showTeamManagement) {
                TeamListView()
            }
            .sheet(isPresented: $showRoutePlanning) {
                RouteListView()
            }
            .sheet(isPresented: $showGeofences) {
                GeofenceListView()
            }
            .sheet(isPresented: $showTrackRecording) {
                TrackListView(recordingService: trackRecordingService)
            }
            .sheet(isPresented: $showChat) {
                ChatView(chatManager: chatManager)
            }
            .sheet(isPresented: $showContacts) {
                ContactListView(chatManager: chatManager)
            }
            .sheet(isPresented: $showEmergencySOS) {
                EmergencyBeaconView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showPlugins) {
                PluginsListView()
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .sheet(isPresented: $showPositionBroadcast) {
                PositionBroadcastView()
            }
            .sheet(isPresented: $showMeshtastic) {
                MeshtasticConnectionView()
            }
            .sheet(isPresented: $showElevationProfile) {
                ElevationProfileView()
            }
            .sheet(isPresented: $showLineOfSight) {
                LineOfSightView()
            }
            .sheet(isPresented: $showEchelonHierarchy) {
                EchelonHierarchyView()
            }
            .sheet(isPresented: $showMissionSync) {
                MissionPackageSyncView()
            }
    }

    private var errorOverlays: some View {
        EmptyView()
            .overlay(
                Group {
                    if showGPSError {
                        GPSErrorAlert(isPresented: $showGPSError, onSettings: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        })
                        .zIndex(2001)
                    }
                }
            )
    }

    private var lifecycleHandlers: some View {
        EmptyView()
            .onAppear {
                setupTAKConnection()
                startLocationUpdates()
                radialMenuCoordinator.configure(drawingStore: drawingStore)
                positionBroadcastService.configure(takService: takService, locationManager: locationManager)
                positionBroadcastService.isEnabled = true
                overlayCoordinator.loadSettings()
                mapStateManager.loadPreferences()
                mapStateManager.updateMapRegion(mapRegion)

                // Hook up self-healing route callback
                routeService.onRouteOverlayUpdate = { [weak routeOverlayCoordinator] route, currentLocation, waypointIndex in
                    DispatchQueue.main.async {
                        routeOverlayCoordinator?.updateSelfHealingRoute(
                            route: route,
                            currentLocation: currentLocation,
                            currentWaypointIndex: waypointIndex
                        )
                    }
                }
            }
            .onChange(of: isCursorModeActive) { newValue in
                DispatchQueue.main.async {
                    if newValue {
                        cursorModeCoordinator.activate()
                        mapStateManager.isCursorModeActive = true
                    } else {
                        cursorModeCoordinator.deactivate()
                        mapStateManager.isCursorModeActive = false
                    }
                }
            }
            .onChange(of: mapRegion.center.latitude) { _ in
                DispatchQueue.main.async {
                    mapStateManager.updateMapRegion(mapRegion)
                    // MGRS update handled by updateVisibleOverlays in map coordinator
                }
            }
            .onChange(of: mapRegion.center.longitude) { _ in
                DispatchQueue.main.async {
                    mapStateManager.updateMapRegion(mapRegion)
                    // MGRS update handled by updateVisibleOverlays in map coordinator
                }
            }
            .onChange(of: overlayCoordinator.mgrsGridEnabled) { newValue in
                DispatchQueue.main.async {
                    showGrid = newValue
                }
            }
            .onChange(of: locationManager.location?.coordinate.latitude) { _ in
                // Update map region to follow user if in follow mode (no animation)
                if trackingMode == .follow, let location = locationManager.location {
                    mapRegion.center = location.coordinate
                }
            }
            .onChange(of: locationManager.location?.coordinate.longitude) { _ in
                // Update map region to follow user if in follow mode (no animation)
                if trackingMode == .follow, let location = locationManager.location {
                    mapRegion.center = location.coordinate
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .radialMenuCustomAction)) { notification in
                guard let userInfo = notification.userInfo,
                      let identifier = userInfo["identifier"] as? String else {
                    return
                }

                switch identifier {
                case "draw_shape":
                    withAnimation(.spring()) {
                        showDrawingPanel.toggle()
                    }
                case "meshtastic":
                    showMeshtastic = true
                default:
                    break // Unknown custom action
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .radialMenuMeasurementStarted)) { notification in
                // Radial menu wants to start measurement - show the CompactMeasurementOverlay
                DispatchQueue.main.async {
                    showMeasurement = true

                    // If a specific measurement type was requested, start it
                    if let userInfo = notification.userInfo,
                       let type = userInfo["type"] as? MeasurementType {
                        measurementManager.startMeasurement(type: type)

                        // If a coordinate was provided (from radial menu), add it as the first tap
                        if let coordinate = userInfo["coordinate"] as? CLLocationCoordinate2D {
                            measurementManager.handleMapTap(at: coordinate)
                        }
                    }
                }
            }
            // Drawing action observers from radial menu
            .onReceive(NotificationCenter.default.publisher(for: .radialMenuOpenDrawingTools)) { _ in
                withAnimation(.spring()) {
                    showDrawingPanel = true
                    showDrawingList = false
                    showLayersPanel = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .radialMenuOpenDrawingsList)) { _ in
                withAnimation(.spring()) {
                    showDrawingList = true
                    showDrawingPanel = false
                    showLayersPanel = false
                }
            }
            // App mode picker from radial menu
            .onReceive(NotificationCenter.default.publisher(for: .radialMenuShowAppModePicker)) { _ in
                showAppModePicker = true
            }
            // Layers panel from radial menu
            .onReceive(NotificationCenter.default.publisher(for: .radialMenuShowLayers)) { _ in
                withAnimation(.spring()) {
                    showLayersPanel.toggle()
                }
            }
            .sheet(isPresented: $showAppModePicker) {
                AppModePickerView()
            }
            // Route navigation changes
            .onChange(of: routeService.activeRoute?.id) { newRouteId in
                DispatchQueue.main.async {
                    if let route = routeService.activeRoute {
                        // Display the active route on the map
                        routeOverlayCoordinator.displayRoute(route, isActive: routeService.isNavigating)
                    } else {
                        // Clear route overlays when navigation stops
                        routeOverlayCoordinator.clearRouteOverlays()
                    }
                }
            }
            .onChange(of: routeService.isNavigating) { isNavigating in
                DispatchQueue.main.async {
                    if let route = routeService.activeRoute {
                        // Update route display based on navigation state
                        routeOverlayCoordinator.displayRoute(route, isActive: isNavigating)
                    }
                    // Collapse navigation panel when not navigating
                    if !isNavigating {
                        isNavigationPanelExpanded = false
                    }
                }
            }
    }

    // MARK: - Drawing and Measurement Handlers

    private func handleMapTap(at coordinate: CLLocationCoordinate2D) {
        // Handle measurement tool taps first
        if measurementManager.isActive {
            measurementManager.handleMapTap(at: coordinate)
            return
        }

        // Then handle drawing tool taps
        if drawingManager.isDrawingActive {
            drawingManager.handleMapTap(at: coordinate)
        }
    }

    // MARK: - Marker Actions

    private func dropMarkerAtLocation(coordinate: CLLocationCoordinate2D, affiliation: MarkerAffiliation) {
        // Create a new marker at the specified location
        let callsign = generateCallsign(for: affiliation)

        // Use PointDropperService quickDrop
        _ = PointDropperService.shared.quickDrop(
            at: coordinate,
            name: callsign,
            broadcast: false
        )

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func generateCallsign(for affiliation: MarkerAffiliation) -> String {
        let prefix: String
        switch affiliation {
        case .friendly:
            prefix = "FRD"
        case .hostile:
            prefix = "HST"
        case .neutral:
            prefix = "NEU"
        case .unknown:
            prefix = "UNK"
        }

        let timestamp = Int(Date().timeIntervalSince1970) % 10000
        return "\(prefix)-\(timestamp)"
    }

    // MARK: - Actions

    private func setupTAKConnection() {
        // Connect to all enabled servers (respects user's toggle state)
        ServerManager.shared.connectToEnabledServers()
    }

    private func startLocationUpdates() {
        locationManager.startUpdating()

        // Check GPS status and show error if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if self.locationManager.location == nil {
                self.showGPSError = false  // Don't show error immediately
            }
        }
    }

    private func centerOnUser() {
        // Toggle tracking mode
        if trackingMode == .follow {
            // Disable follow mode - allow free panning
            trackingMode = .none
        } else {
            // Enable follow mode and center on user
            if let location = locationManager.location {
                withAnimation {
                    mapRegion.center = location.coordinate
                    mapRegion.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                }
                trackingMode = .follow
            }
        }
    }

    private func sendSelfPosition() {
        guard let location = locationManager.location else { return }

        // Send to all connected servers via federation
        if federation.getConnectedCount() > 0 {
            let cotEvent = CoTEvent(
                uid: "SELF-\(UUID().uuidString)",
                type: "a-f-G-E-S",
                time: Date(),
                point: CoTPoint(
                    lat: location.coordinate.latitude,
                    lon: location.coordinate.longitude,
                    hae: location.altitude,
                    ce: location.horizontalAccuracy,
                    le: location.verticalAccuracy
                ),
                detail: CoTDetail(
                    callsign: "OmniTAK-iOS",
                    team: "Cyan",
                    speed: location.speed >= 0 ? location.speed : nil,
                    course: location.course >= 0 ? location.course : nil,
                    remarks: nil,
                    battery: 100,
                    device: "iPhone",
                    platform: "OmniTAK"
                )
            )

            federation.broadcast(event: cotEvent)
        }
    }

    private func zoomIn() {
        mapRegion.span.latitudeDelta = max(mapRegion.span.latitudeDelta / 2, 0.001)
        mapRegion.span.longitudeDelta = max(mapRegion.span.longitudeDelta / 2, 0.001)
    }

    private func zoomOut() {
        mapRegion.span.latitudeDelta = min(mapRegion.span.latitudeDelta * 2, 180)
        mapRegion.span.longitudeDelta = min(mapRegion.span.longitudeDelta * 2, 180)
    }

    private func zoomToDrawing(coordinate: CLLocationCoordinate2D, radius: Double?) {
        let span: MKCoordinateSpan
        if let radius = radius {
            let degrees = (radius * 3) / 111000
            span = MKCoordinateSpan(
                latitudeDelta: max(degrees, 0.005),
                longitudeDelta: max(degrees, 0.005)
            )
        } else {
            span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            mapRegion = MKCoordinateRegion(center: coordinate, span: span)
        }
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
            case "satellite": mapType = .satellite
            case "hybrid": mapType = .hybrid
            case "standard": mapType = .standard
            default: break
            }
        }
    }

    private func toggleOverlay(_ overlay: String) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        switch overlay {
        case "friendly": showFriendly.toggle()
        case "hostile": showHostile.toggle()
        case "neutral": showNeutral.toggle()
        case "unknown": showUnknown.toggle()
        default: break
        }
    }

    private func toggleMapOverlay(_ overlay: String) {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        withAnimation(.easeInOut(duration: 0.3)) {
            switch overlay {
            case "compass": showCompass.toggle()
            case "coordinates": showCoordinates.toggle()
            case "scale": showScaleBar.toggle()
            case "grid": showGrid.toggle()
            default: break
            }
        }
    }

    // MARK: - Formatting Helpers

    private func formatCoordinates(_ coordinate: CLLocationCoordinate2D) -> String {
        // Convert to MGRS-style format (simplified)
        let lat = abs(coordinate.latitude)
        let lon = abs(coordinate.longitude)
        let latDeg = Int(lat)
        let lonDeg = Int(lon)
        let latMin = Int((lat - Double(latDeg)) * 60)
        let lonMin = Int((lon - Double(lonDeg)) * 60)
        let latSec = Int(((lat - Double(latDeg)) * 60 - Double(latMin)) * 60)
        let lonSec = Int(((lon - Double(lonDeg)) * 60 - Double(lonMin)) * 60)

        return "11T MN \(latDeg)\(latMin)\(latSec) \(lonDeg)\(lonMin)\(lonSec)"
    }

    private func formatAltitude(_ altitude: CLLocationDistance) -> String {
        return UnitPreferences.shared.formatAltitude(altitude) + " MSL"
    }

    private func formatSpeed(_ speed: CLLocationSpeed) -> String {
        return UnitPreferences.shared.formatSpeed(max(0, speed))
    }

    private func formatHeading(_ heading: CLHeading?) -> String {
        guard let heading = heading else {
            // Fall back to course from location if heading not available
            if locationManager.course >= 0 {
                return String(format: "%.0f°M", locationManager.course)
            }
            return ""
        }
        // Use magnetic heading for ATAK compatibility
        return String(format: "%.0f°M", heading.magneticHeading)
    }

    // MARK: - Multi-Server Helpers

    // Multi-server connection status for status bar
    private func multiServerConnectionStatus() -> String {
        let connectedCount = federation.getConnectedCount()
        let totalCount = federation.getTotalCount()

        if connectedCount == 0 {
            return "Disconnected"
        } else if connectedCount == 1 {
            if let connectedServer = federation.servers.first(where: { $0.status == .connected }) {
                return "Connected - \(connectedServer.name)"
            }
            return "Connected"
        } else {
            return "Connected to \(connectedCount)/\(totalCount) servers"
        }
    }

    // Multi-server display name for status bar
    private func multiServerDisplayName() -> String? {
        let connectedCount = federation.getConnectedCount()

        if connectedCount == 0 {
            return ServerManager.shared.activeServer?.name
        } else if connectedCount == 1 {
            return federation.servers.first(where: { $0.status == .connected })?.name
        } else {
            let connectedNames = federation.servers
                .filter { $0.status == .connected }
                .map { $0.name }
                .prefix(2)
                .joined(separator: ", ")
            return connectedCount > 2 ? "\(connectedNames) +\(connectedCount - 2)" : connectedNames
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
                <takv device="iPhone" platform="OmniTAK" os="iOS" version="\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0")"/>
                <track speed="\(location.speed)" course="\(location.course)"/>
            </detail>
        </event>
        """
    }
}

// MARK: - ATAK Status Bar

struct ATAKStatusBar: View {
    let connectionStatus: String
    let isConnected: Bool
    let messagesReceived: Int
    let messagesSent: Int
    let gpsAccuracy: Double
    let serverName: String?
    let onServerTap: () -> Void
    let onMenuTap: () -> Void

    @Environment(\.verticalSizeClass) var verticalSizeClass

    // Portrait mode detection
    var isPortrait: Bool {
        verticalSizeClass == .regular
    }

    var body: some View {
        HStack(spacing: isPortrait ? 8 : 12) {
            // Compact OmniTAK branding with status indicator
            HStack(spacing: 4) {
                // LED-style connection indicator
                Circle()
                    .fill(isConnected ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                    .shadow(color: isConnected ? .green : .red, radius: 3)

                if !isPortrait {
                    Text("OmniTAK")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 1.0, green: 0.988, blue: 0.0))
                }
            }

            // Server Name Button (compact)
            Button(action: onServerTap) {
                HStack(spacing: 2) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 9))
                    Text(serverName ?? "Offi...")
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundColor(isConnected ? .green : .gray)
            }

            // Messages (compact)
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.cyan)
                Text("\(messagesReceived)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.cyan)
            }

            HStack(spacing: 4) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.orange)
                Text("\(messagesSent)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.orange)
            }

            Spacer()

            // GPS Status (compact)
            HStack(spacing: 2) {
                Image(systemName: gpsAccuracy < 10 ? "location.fill" : "location.slash.fill")
                    .font(.system(size: 9))
                Text(String(format: "±%.0fm", gpsAccuracy))
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundColor(gpsAccuracy < 10 ? .green : .yellow)

            // Time (compact)
            Text(Date().formatted(date: .omitted, time: .shortened))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)

            // Hamburger Menu Button (compact)
            Button(action: onMenuTap) {
                VStack(spacing: 2) {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 18, height: 2)
                        .cornerRadius(1)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 18, height: 2)
                        .cornerRadius(1)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 18, height: 2)
                        .cornerRadius(1)
                }
                .frame(width: 32, height: 32)
            }
            .accessibilityIdentifier("mainMenuButton")
            .accessibilityLabel("Main Menu")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.5))  // Translucent background
    }
}

// MARK: - ATAK Bottom Toolbar

struct ATAKBottomToolbar: View {
    @Binding var mapType: MKMapType
    @Binding var showLayersPanel: Bool
    @Binding var showDrawingPanel: Bool
    @Binding var showDrawingList: Bool
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Zoom Controls only - Draw/Drawings accessible via radial menu long-press
            VStack(spacing: 4) {
                MapToolButton(icon: "plus", label: "", compact: true) {
                    onZoomIn()
                }
                MapToolButton(icon: "minus", label: "", compact: true) {
                    onZoomOut()
                }
            }

            Spacer()

            // Draw and Drawings buttons removed - accessible via radial menu (long-press on map)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// Map Tool Button Component
struct MapToolButton: View {
    let icon: String
    let label: String
    var compact: Bool = false
    var isActive: Bool = false
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: compact ? 14 : 18, weight: .semibold))
                if !label.isEmpty {
                    Text(label)
                        .font(.system(size: 8, weight: .medium))
                }
            }
            .foregroundColor(isActive ? Color(hex: "#FFFC00") : .white)
            .frame(width: compact ? 32 : 50, height: compact ? 32 : 50)
            .background(
                isActive ? Color(hex: "#FFFC00").opacity(0.3) :
                isPressed ? Color.cyan.opacity(0.5) : Color.black.opacity(0.6)
            )
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isActive ? Color(hex: "#FFFC00") : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - ATAK Side Panel

struct ATAKSidePanel: View {
    @Binding var isExpanded: Bool
    @Binding var activeMapLayer: String
    @Binding var showFriendly: Bool
    @Binding var showHostile: Bool
    @Binding var showNeutral: Bool
    @Binding var showUnknown: Bool
    @Binding var showCompass: Bool
    @Binding var showCoordinates: Bool
    @Binding var showScaleBar: Bool
    @Binding var showGrid: Bool
    @ObservedObject var adsbService: ADSBTrafficService
    let onLayerToggle: (String) -> Void
    let onOverlayToggle: (String) -> Void
    let onMapOverlayToggle: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 8) {
                // Compact header with close button
                HStack {
                    Text("LAYERS")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        withAnimation(.spring()) {
                            isExpanded = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.system(size: 16))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)

                LayerButton(icon: "map", title: "Satellite", isActive: activeMapLayer == "satellite", compact: true) {
                    onLayerToggle("satellite")
                }
                LayerButton(icon: "map.fill", title: "Hybrid", isActive: activeMapLayer == "hybrid", compact: true) {
                    onLayerToggle("hybrid")
                }
                LayerButton(icon: "map.circle", title: "Standard", isActive: activeMapLayer == "standard", compact: true) {
                    onLayerToggle("standard")
                }

                Divider()
                    .background(Color.white.opacity(0.3))
                    .padding(.vertical, 4)

                Text("UNITS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)

                LayerButton(icon: "shield.fill", title: "Friendly", isActive: showFriendly, compact: true) {
                    onOverlayToggle("friendly")
                }
                LayerButton(icon: "exclamationmark.triangle.fill", title: "Hostile", isActive: showHostile, compact: true) {
                    onOverlayToggle("hostile")
                }
                LayerButton(icon: "circle.fill", title: "Neutral", isActive: showNeutral, compact: true) {
                    onOverlayToggle("neutral")
                }
                LayerButton(icon: "questionmark.circle.fill", title: "Unknown", isActive: showUnknown, compact: true) {
                    onOverlayToggle("unknown")
                }

                Divider()
                    .background(Color.white.opacity(0.3))
                    .padding(.vertical, 4)

                Text("MAP OVERLAYS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)

                LayerButton(icon: "safari", title: "Compass", isActive: showCompass, compact: true) {
                    onMapOverlayToggle("compass")
                }
                LayerButton(icon: "location.circle", title: "Coordinates", isActive: showCoordinates, compact: true) {
                    onMapOverlayToggle("coordinates")
                }
                LayerButton(icon: "ruler", title: "Scale Bar", isActive: showScaleBar, compact: true) {
                    onMapOverlayToggle("scale")
                }

                Divider()
                    .background(Color.white.opacity(0.3))
                    .padding(.vertical, 4)

                Text("DATA FEEDS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)

                LayerButton(
                    icon: "airplane.circle.fill",
                    title: "ADS-B",
                    isActive: adsbService.settings.isEnabled,
                    compact: true
                ) {
                    var settings = adsbService.settings
                    settings.isEnabled.toggle()
                    adsbService.settings = settings
                }

                if adsbService.settings.isEnabled {
                    HStack {
                        Text("\(adsbService.aircraft.count) aircraft")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                }
            }
            .frame(width: 160)
            .padding(.vertical, 8)
            .padding(.bottom, 8)
        }
        .animation(.spring(), value: isExpanded)
    }
}

struct LayerButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    var compact: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: compact ? 6 : 8) {
                Image(systemName: icon)
                    .font(.system(size: compact ? 12 : 14))
                    .frame(width: compact ? 16 : 20)
                Text(title)
                    .font(.system(size: compact ? 11 : 13))
                Spacer()
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: compact ? 12 : 14))
                        .foregroundColor(.green)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, compact ? 8 : 12)
            .padding(.vertical, compact ? 6 : 8)
            .background(isActive ? Color.green.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
    }
}

// MARK: - CoT Marker

struct CoTMarker: Identifiable {
    let id = UUID()
    let uid: String
    let coordinate: CLLocationCoordinate2D
    let type: String
    let callsign: String
    let team: String
}

struct CoTMarkerView: View {
    let marker: CoTMarker

    var body: some View {
        VStack(spacing: 2) {
            // Icon based on type
            Image(systemName: markerIcon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(markerColor)
                .shadow(color: .black, radius: 2)

            // Callsign
            Text(marker.callsign)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(markerColor.opacity(0.8))
                .cornerRadius(4)
                .shadow(color: .black, radius: 1)
        }
    }

    private var markerIcon: String {
        if marker.type.contains("a-f") {
            return "shield.fill"  // Friendly
        } else if marker.type.contains("a-h") {
            return "exclamationmark.triangle.fill"  // Hostile
        } else {
            return "questionmark.circle.fill"  // Unknown
        }
    }

    private var markerColor: Color {
        if marker.type.contains("a-f") {
            return .cyan  // Friendly = cyan (ATAK standard)
        } else if marker.type.contains("a-h") {
            return .red  // Hostile = red
        } else {
            return .yellow  // Unknown = yellow
        }
    }
}

// MARK: - View Extensions

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var accuracy: Double = 0
    @Published var heading: CLHeading?
    @Published var course: Double = 0
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest

        // Enable background location updates for navigation and position tracking
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true

        // Request authorization - start with when in use, then prompt for always
        requestLocationAuthorization()

        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    /// Request location authorization with escalation to Always
    func requestLocationAuthorization() {
        let status = manager.authorizationStatus
        authorizationStatus = status

        switch status {
        case .notDetermined:
            // First request when in use, then iOS will prompt for upgrade
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            // Request upgrade to Always for background operation
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            // Already have full access
            break
        case .denied, .restricted:
            // User denied - they'll need to enable in Settings
            print("[LocationManager] Location access denied or restricted")
        @unknown default:
            break
        }
    }

    func startUpdating() {
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status

            // If user just granted when-in-use, request always
            if status == .authorizedWhenInUse {
                // Slight delay before requesting upgrade
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    manager.requestAlwaysAuthorization()
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
        accuracy = locations.last?.horizontalAccuracy ?? 0
        course = locations.last?.course ?? 0
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[LocationManager] Location error: \(error.localizedDescription)")
    }
}

// MARK: - Tactical Map View (UIViewRepresentable for mapType support)

struct TacticalMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var mapType: MKMapType
    @Binding var trackingMode: MapUserTrackingMode
    let markers: [CoTMarker]
    let pointMarkers: [PointMarker]  // Point markers from PointDropperService
    let aircraft: [Aircraft]
    let showsUserLocation: Bool
    @ObservedObject var drawingStore: DrawingStore
    @ObservedObject var drawingManager: DrawingToolsManager
    @ObservedObject var radialMenuCoordinator: RadialMenuMapCoordinator
    @ObservedObject var overlayCoordinator: MapOverlayCoordinator
    @ObservedObject var routeOverlayCoordinator: RouteOverlayCoordinator
    @ObservedObject var mapStateManager: MapStateManager
    @ObservedObject var measurementManager: MeasurementManager
    let onMapTap: (CLLocationCoordinate2D) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.mapType = mapType
        mapView.region = region

        // Store mapView reference in coordinator for overlay management
        context.coordinator.mapView = mapView

        // Configure overlay coordinator with map view
        overlayCoordinator.configure(with: mapView)

        // Configure route overlay coordinator with map view
        routeOverlayCoordinator.configure(with: mapView)

        // Enable all gestures - ensure map is fully interactive
        mapView.isScrollEnabled = true   // Always allow panning
        mapView.isZoomEnabled = true     // Always allow zooming
        mapView.isRotateEnabled = true   // Always allow rotation
        mapView.isPitchEnabled = false   // Disable 3D pitch for simplicity
        mapView.isUserInteractionEnabled = true  // Ensure touch works

        // Add tap gesture recognizer - configure to not block pan gestures
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        tapGesture.cancelsTouchesInView = false  // Allow pan gestures to work
        tapGesture.delaysTouchesBegan = false    // Don't delay touch events
        mapView.addGestureRecognizer(tapGesture)

        // Add long-press gesture for radial menu
        let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        longPressGesture.cancelsTouchesInView = false  // Allow pan gestures to work
        mapView.addGestureRecognizer(longPressGesture)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update coordinator reference
        context.coordinator.parent = self

        // Update map type
        if mapView.mapType != mapType {
            mapView.mapType = mapType
        }

        // Update region (only if not currently being manipulated by user)
        if !context.coordinator.isUserInteracting {
            // Only update if region has actually changed (avoid unnecessary resets)
            let currentRegion = mapView.region
            let centerChanged = abs(currentRegion.center.latitude - region.center.latitude) > 0.00001 ||
                               abs(currentRegion.center.longitude - region.center.longitude) > 0.00001
            let spanChanged = abs(currentRegion.span.latitudeDelta - region.span.latitudeDelta) > 0.00001 ||
                             abs(currentRegion.span.longitudeDelta - region.span.longitudeDelta) > 0.00001

            if centerChanged || spanChanged {
                context.coordinator.isProgrammaticUpdate = true
                mapView.setRegion(region, animated: false)  // No animation to prevent bounce
                // Note: isProgrammaticUpdate is reset in regionDidChangeAnimated
            }
        }

        // Update markers, point markers, and aircraft
        updateAnnotations(mapView: mapView, markers: markers, pointMarkers: pointMarkers, aircraft: aircraft, context: context)

        // Update overlays
        updateOverlays(mapView: mapView, context: context)

        // Update tactical overlays (MGRS Grid, Breadcrumb Trail, Range & Bearing)
        // Uses overlay visibility from overlayCoordinator
        context.coordinator.updateTacticalOverlays(
            showMGRSGrid: overlayCoordinator.mgrsGridEnabled,
            showBreadcrumbTrail: overlayCoordinator.breadcrumbTrailsEnabled,
            showRangeBearingLines: overlayCoordinator.rangeBearingEnabled
        )

        // Update overlay coordinator's visible region for performance optimizations
        overlayCoordinator.updateVisibleOverlays(in: region)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func updateAnnotations(mapView: MKMapView, markers: [CoTMarker], pointMarkers: [PointMarker], aircraft: [Aircraft], context: Context) {
        // Remove old CoT annotations only (not aircraft or point markers - they're updated separately)
        let oldCotAnnotations = mapView.annotations.filter { annotation in
            annotation is MKPointAnnotation &&
            !(annotation is MKUserLocation) &&
            !context.coordinator.isDrawingAnnotation(annotation) &&
            !(annotation is AircraftAnnotation) &&
            !(annotation is PointMarkerAnnotation)
        }
        mapView.removeAnnotations(oldCotAnnotations)

        // Add new CoT annotations
        let cotAnnotations = markers.map { marker -> MKPointAnnotation in
            let annotation = MKPointAnnotation()
            annotation.coordinate = marker.coordinate
            annotation.title = marker.callsign
            annotation.subtitle = marker.type
            return annotation
        }
        mapView.addAnnotations(cotAnnotations)

        // Update point marker annotations (hostile, friendly, etc. from radial menu)
        updatePointMarkerAnnotations(mapView: mapView, pointMarkers: pointMarkers)

        // Update aircraft annotations incrementally (no flicker)
        updateAircraftAnnotations(mapView: mapView, aircraft: aircraft)

        // Update drawing annotations
        updateDrawingAnnotations(mapView: mapView, context: context)
    }

    private func updatePointMarkerAnnotations(mapView: MKMapView, pointMarkers: [PointMarker]) {
        // Get existing point marker annotations
        let existingPointAnnotations = mapView.annotations.compactMap { $0 as? PointMarkerAnnotation }
        var existingById: [UUID: PointMarkerAnnotation] = [:]
        for annotation in existingPointAnnotations {
            existingById[annotation.marker.id] = annotation
        }

        // Track which ones we've seen
        var seenIds: Set<UUID> = []

        for marker in pointMarkers {
            seenIds.insert(marker.id)

            if let existingAnnotation = existingById[marker.id] {
                // Update existing annotation position if it changed
                if existingAnnotation.coordinate.latitude != marker.coordinate.latitude ||
                   existingAnnotation.coordinate.longitude != marker.coordinate.longitude {
                    // Remove and re-add to update position
                    mapView.removeAnnotation(existingAnnotation)
                    let newAnnotation = PointMarkerAnnotation(marker: marker)
                    mapView.addAnnotation(newAnnotation)
                }
            } else {
                // Add new annotation
                let annotation = PointMarkerAnnotation(marker: marker)
                mapView.addAnnotation(annotation)
            }
        }

        // Remove annotations for markers that no longer exist
        for (id, annotation) in existingById {
            if !seenIds.contains(id) {
                mapView.removeAnnotation(annotation)
            }
        }
    }

    private func updateAircraftAnnotations(mapView: MKMapView, aircraft: [Aircraft]) {
        // Get existing aircraft annotations
        let existingAircraftAnnotations = mapView.annotations.compactMap { $0 as? AircraftAnnotation }
        var existingById: [String: AircraftAnnotation] = [:]
        for annotation in existingAircraftAnnotations {
            existingById[annotation.aircraft.id] = annotation
        }

        // Create set of current aircraft IDs
        let currentIds = Set(aircraft.map { $0.id })

        // Remove departed aircraft
        let departedAnnotations = existingAircraftAnnotations.filter { !currentIds.contains($0.aircraft.id) }
        if !departedAnnotations.isEmpty {
            mapView.removeAnnotations(departedAnnotations)
        }

        // Update existing and add new aircraft
        var newAnnotations: [AircraftAnnotation] = []
        for aircraftData in aircraft {
            if let existingAnnotation = existingById[aircraftData.id] {
                // Update existing annotation in-place (no remove/add)
                existingAnnotation.update(with: aircraftData)

                // Refresh view if needed
                if existingAnnotation.needsVisualUpdate,
                   let view = mapView.view(for: existingAnnotation) as? AircraftAnnotationView {
                    view.refreshIfNeeded()
                }
            } else {
                // New aircraft - add annotation
                newAnnotations.append(AircraftAnnotation(aircraft: aircraftData))
            }
        }

        // Batch add new annotations
        if !newAnnotations.isEmpty {
            mapView.addAnnotations(newAnnotations)
        }
    }

    private func updateDrawingAnnotations(mapView: MKMapView, context: Context) {
        // Diff-based update: keep existing annotations whose model hasn't
        // changed, add new ones, remove orphans. The previous "remove all
        // then re-add" approach caused labels and measurement points to
        // flicker every time updateUIView ran (#39).

        updateDrawingMarkerAnnotations(mapView: mapView)
        updateDrawingLabelAnnotations(mapView: mapView)
        updateDrawingTempAnnotations(mapView: mapView)
        updateMeasurementTempAnnotations(mapView: mapView)
    }

    private func updateDrawingTempAnnotations(mapView: MKMapView) {
        let existing = mapView.annotations.compactMap { $0 as? DrawingTempPointAnnotation }
        let desired: [DrawingTempPointAnnotation] = drawingManager.isDrawingActive
            ? drawingManager.getTemporaryAnnotations().map { input in
                let a = DrawingTempPointAnnotation()
                a.coordinate = input.coordinate
                a.title = input.title
                a.subtitle = input.subtitle
                return a
            }
            : []

        if existing.count == desired.count {
            let sameCoords = zip(existing, desired).allSatisfy { lhs, rhs in
                lhs.coordinate.latitude == rhs.coordinate.latitude &&
                lhs.coordinate.longitude == rhs.coordinate.longitude
            }
            if sameCoords { return }
        }

        if !existing.isEmpty { mapView.removeAnnotations(existing) }
        if !desired.isEmpty { mapView.addAnnotations(desired) }
    }

    private func updateDrawingMarkerAnnotations(mapView: MKMapView) {
        let existing = mapView.annotations.compactMap { $0 as? DrawingMarkerAnnotation }
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.marker.id, $0) })
        let desiredIDs = Set(drawingStore.markers.map { $0.id })

        let stale = existing.filter { !desiredIDs.contains($0.marker.id) }
        if !stale.isEmpty { mapView.removeAnnotations(stale) }

        for marker in drawingStore.markers {
            if let annotation = existingByID[marker.id] {
                // Refresh in place if the underlying marker moved or was renamed.
                if annotation.coordinate.latitude != marker.coordinate.latitude ||
                   annotation.coordinate.longitude != marker.coordinate.longitude ||
                   annotation.title != marker.label {
                    mapView.removeAnnotation(annotation)
                    mapView.addAnnotation(DrawingMarkerAnnotation(marker: marker))
                }
            } else {
                mapView.addAnnotation(DrawingMarkerAnnotation(marker: marker))
            }
        }
    }

    private func updateDrawingLabelAnnotations(mapView: MKMapView) {
        let existing = mapView.annotations.compactMap { $0 as? DrawingLabelAnnotation }
        let existingByID = Dictionary(uniqueKeysWithValues: existing.map { ($0.ownerID, $0) })

        // Build the list of labels we want on-screen right now.
        var desired: [(id: UUID, coordinate: CLLocationCoordinate2D, label: String, color: DrawingColor)] = []
        desired.reserveCapacity(drawingStore.circles.count + drawingStore.polygons.count + drawingStore.lines.count)

        for circle in drawingStore.circles {
            desired.append((circle.id, circle.center, circle.label, circle.color))
        }
        for polygon in drawingStore.polygons {
            if let centroid = calculateCentroid(coordinates: polygon.coordinates) {
                desired.append((polygon.id, centroid, polygon.label, polygon.color))
            }
        }
        for line in drawingStore.lines where line.coordinates.count >= 2 {
            let midIndex = line.coordinates.count / 2
            desired.append((line.id, line.coordinates[midIndex], line.label, line.color))
        }

        let desiredIDs = Set(desired.map { $0.id })

        let stale = existing.filter { !desiredIDs.contains($0.ownerID) }
        if !stale.isEmpty { mapView.removeAnnotations(stale) }

        for item in desired {
            if let annotation = existingByID[item.id] {
                let coordChanged = annotation.coordinate.latitude != item.coordinate.latitude ||
                                   annotation.coordinate.longitude != item.coordinate.longitude
                if coordChanged || annotation.label != item.label || annotation.color != item.color {
                    mapView.removeAnnotation(annotation)
                    mapView.addAnnotation(DrawingLabelAnnotation(
                        ownerID: item.id,
                        coordinate: item.coordinate,
                        label: item.label,
                        color: item.color
                    ))
                }
            } else {
                mapView.addAnnotation(DrawingLabelAnnotation(
                    ownerID: item.id,
                    coordinate: item.coordinate,
                    label: item.label,
                    color: item.color
                ))
            }
        }
    }

    private func updateMeasurementTempAnnotations(mapView: MKMapView) {
        let existing = mapView.annotations.compactMap { $0 as? MeasurementPointAnnotation }
        let desired: [MeasurementPointAnnotation] = measurementManager.isActive
            ? measurementManager.getTemporaryAnnotations().map { input in
                let a = MeasurementPointAnnotation()
                a.coordinate = input.coordinate
                a.title = input.title
                a.subtitle = input.subtitle
                return a
            }
            : []

        // Cheap fast path: if the set of coordinates is identical, do nothing.
        if existing.count == desired.count {
            let sameCoords = zip(existing, desired).allSatisfy { lhs, rhs in
                lhs.coordinate.latitude == rhs.coordinate.latitude &&
                lhs.coordinate.longitude == rhs.coordinate.longitude
            }
            if sameCoords { return }
        }

        if !existing.isEmpty { mapView.removeAnnotations(existing) }
        if !desired.isEmpty { mapView.addAnnotations(desired) }
    }

    private func calculateCentroid(coordinates: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
        guard !coordinates.isEmpty else { return nil }

        var totalLat = 0.0
        var totalLon = 0.0

        for coord in coordinates {
            totalLat += coord.latitude
            totalLon += coord.longitude
        }

        return CLLocationCoordinate2D(
            latitude: totalLat / Double(coordinates.count),
            longitude: totalLon / Double(coordinates.count)
        )
    }

    private func updateOverlays(mapView: MKMapView, context: Context) {
        // Remove ONLY drawing/measurement overlays (preserve MGRS grid and other tactical overlays)
        let overlaysToRemove = mapView.overlays.filter { overlay in
            !(overlay is MGRSGridOverlay) &&
            !(overlay is BreadcrumbTrailPolyline) &&
            !(overlay is RangeBearingLineOverlay)
        }
        mapView.removeOverlays(overlaysToRemove)

        // Add saved drawing overlays
        let savedOverlays = drawingStore.getAllOverlays()
        mapView.addOverlays(savedOverlays)

        // Add temporary overlay if drawing
        if let tempOverlay = drawingManager.getTemporaryOverlay() {
            mapView.addOverlay(tempOverlay)
        }

        // Add measurement overlays
        if let measurementOverlay = measurementManager.getTemporaryOverlay() {
            mapView.addOverlay(measurementOverlay)
        }

        // Add range ring overlays
        for ring in measurementManager.rangeRings {
            let circle = MKCircle(center: ring.center, radius: ring.radiusMeters)
            mapView.addOverlay(circle)
        }
    }

    private func mapTypeString(_ type: MKMapType) -> String {
        switch type {
        case .standard: return "Standard"
        case .satellite: return "Satellite"
        case .hybrid: return "Hybrid"
        case .satelliteFlyover: return "Satellite Flyover"
        case .hybridFlyover: return "Hybrid Flyover"
        case .mutedStandard: return "Muted Standard"
        @unknown default: return "Unknown"
        }
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TacticalMapView
        var isUserInteracting = false
        var isProgrammaticUpdate = false
        weak var mapView: MKMapView?

        // Overlay management
        // NOTE: MGRS Grid is now managed by MapOverlayCoordinator and IntegratedMapView
        // private var currentMGRSGridOverlay: MGRSGridOverlay? // REMOVED - was causing duplicate grids
        private var currentBreadcrumbOverlay: BreadcrumbTrailPolyline?
        private var currentRangeBearingOverlays: [RangeBearingLineOverlay] = []

        // Debounce timer for grid updates
        private var gridUpdateTimer: Timer?
        private let gridUpdateDebounceInterval: TimeInterval = 0.3

        // Trail point limit for performance
        private let maxTrailPoints = 5000

        init(_ parent: TacticalMapView) {
            self.parent = parent
        }

        // MARK: - Tactical Overlay Management

        func updateTacticalOverlays(showMGRSGrid: Bool, showBreadcrumbTrail: Bool, showRangeBearingLines: Bool) {
            guard let mapView = mapView else { return }

            // NOTE: MGRS Grid is now managed by MapOverlayCoordinator and IntegratedMapView
            // updateMGRSGridOverlay(mapView: mapView, show: showMGRSGrid) // REMOVED - was causing duplicate grids

            // Update Breadcrumb Trail (z-order: middle)
            updateBreadcrumbTrailOverlay(mapView: mapView, show: showBreadcrumbTrail)

            // Update Range & Bearing Lines (z-order: top)
            updateRangeBearingOverlays(mapView: mapView, show: showRangeBearingLines)
        }

        // REMOVED: This was causing duplicate MGRS grids
        // MGRS Grid is now exclusively managed by MapOverlayCoordinator and IntegratedMapView
        /*
        private func updateMGRSGridOverlay(mapView: MKMapView, show: Bool) {
            if show {
                if currentMGRSGridOverlay == nil {
                    let gridOverlay = MGRSGridOverlay()
                    gridOverlay.lineColor = UIColor.black.withAlphaComponent(0.6)
                    gridOverlay.lineWidth = 0.5
                    gridOverlay.showLabels = true
                    gridOverlay.labelColor = UIColor.white.withAlphaComponent(0.9)
                    gridOverlay.labelBackgroundColor = UIColor.black.withAlphaComponent(0.7)

                    // Add at lowest level
                    mapView.addOverlay(gridOverlay, level: .aboveRoads)
                    currentMGRSGridOverlay = gridOverlay
                }
            } else {
                if let overlay = currentMGRSGridOverlay {
                    mapView.removeOverlay(overlay)
                    currentMGRSGridOverlay = nil
                }
            }
        }
        */

        private func updateBreadcrumbTrailOverlay(mapView: MKMapView, show: Bool) {
            if show {
                let service = BreadcrumbTrailService.shared
                guard !service.trailPoints.isEmpty else {
                    // Remove existing if no points
                    if let existing = currentBreadcrumbOverlay {
                        mapView.removeOverlay(existing)
                        currentBreadcrumbOverlay = nil
                    }
                    return
                }

                // Limit trail points for performance
                var coordinates = service.trailCoordinates
                if coordinates.count > maxTrailPoints {
                    // Keep most recent points
                    coordinates = Array(coordinates.suffix(maxTrailPoints))
                }

                // Get team color from PositionBroadcastService
                let teamColorString = PositionBroadcastService.shared.teamColor
                let teamColor = UIColor(hexString: teamColorString) ?? UIColor.green

                // Create new polyline
                let polyline = BreadcrumbTrailPolyline(coordinates: &coordinates, count: coordinates.count)
                polyline.teamColor = teamColor
                polyline.lineWidth = service.configuration.lineWidth
                polyline.timestamps = Array(service.trailTimestamps.suffix(maxTrailPoints))
                polyline.showDirectionArrows = service.configuration.showDirectionArrows
                polyline.enableTimeFading = service.configuration.enableTimeFading
                polyline.fadeStartTime = service.configuration.fadeStartTime

                // Remove old overlay
                if let existing = currentBreadcrumbOverlay {
                    mapView.removeOverlay(existing)
                }

                // Add new overlay (above grid)
                mapView.addOverlay(polyline, level: .aboveRoads)
                currentBreadcrumbOverlay = polyline

            } else {
                if let existing = currentBreadcrumbOverlay {
                    mapView.removeOverlay(existing)
                    currentBreadcrumbOverlay = nil
                }
            }
        }

        private func updateRangeBearingOverlays(mapView: MKMapView, show: Bool) {
            if show {
                let service = RangeBearingService.shared

                // Remove old overlays
                mapView.removeOverlays(currentRangeBearingOverlays)
                currentRangeBearingOverlays.removeAll()

                // Create overlays for each R&B line
                for line in service.lines {
                    var coordinates = [line.origin, line.destination]
                    let overlay = RangeBearingLineOverlay(coordinates: &coordinates, count: 2)

                    overlay.lineID = line.id
                    // Orange/amber color for R&B lines
                    overlay.lineColor = UIColor.orange
                    overlay.lineWidth = service.configuration.lineWidth
                    overlay.lineStyle = service.configuration.lineStyle

                    // Set labels
                    overlay.distanceLabel = service.formatDistance(line.distanceMeters)

                    switch service.configuration.bearingType {
                    case .magnetic:
                        overlay.bearingLabel = "\(service.formatBearing(line.magneticBearing))M"
                    case .true:
                        overlay.bearingLabel = "\(service.formatBearing(line.trueBearing))T"
                    case .grid:
                        overlay.bearingLabel = "\(service.formatBearing(line.gridBearing))G"
                    }

                    overlay.backAzimuthLabel = service.formatBearing(line.backAzimuth)

                    // Display options
                    overlay.showDistanceLabel = service.configuration.showDistanceLabel
                    overlay.showBearingLabel = service.configuration.showBearingLabel
                    overlay.showBackAzimuth = service.configuration.showBackAzimuth
                    overlay.showDirectionArrow = true

                    currentRangeBearingOverlays.append(overlay)
                }

                // Add temporary line if being created
                if service.isCreatingLine,
                   let origin = service.temporaryOrigin,
                   let destination = service.temporaryDestination {
                    var coordinates = [origin, destination]
                    let overlay = RangeBearingLineOverlay(coordinates: &coordinates, count: 2)

                    overlay.lineID = nil
                    overlay.lineColor = UIColor.orange.withAlphaComponent(0.7)
                    overlay.lineWidth = service.configuration.lineWidth
                    overlay.lineStyle = .dashed

                    // Calculate temporary values
                    let distance = service.calculateDistance(from: origin, to: destination)
                    let bearing = service.calculateMagneticBearing(from: origin, to: destination)
                    let backAz = service.calculateBackAzimuth(bearing: bearing)

                    overlay.distanceLabel = service.formatDistance(distance)
                    overlay.bearingLabel = "\(service.formatBearing(bearing))M"
                    overlay.backAzimuthLabel = service.formatBearing(backAz)

                    overlay.showDistanceLabel = true
                    overlay.showBearingLabel = true
                    overlay.showBackAzimuth = false
                    overlay.showDirectionArrow = true

                    currentRangeBearingOverlays.append(overlay)
                }

                // Add all overlays (above grid and trails)
                mapView.addOverlays(currentRangeBearingOverlays, level: .aboveLabels)

            } else {
                mapView.removeOverlays(currentRangeBearingOverlays)
                currentRangeBearingOverlays.removeAll()
            }
        }

        // MARK: - Debounced Grid Update (for fast scrolling)

        // REMOVED: Grid updates now handled by MapOverlayCoordinator
        /*
        func scheduleGridUpdate() {
            gridUpdateTimer?.invalidate()
            gridUpdateTimer = Timer.scheduledTimer(withTimeInterval: gridUpdateDebounceInterval, repeats: false) { [weak self] _ in
                self?.forceGridRedraw()
            }
        }
        */

        // REMOVED: Grid is now managed by MapOverlayCoordinator
        /*
        private func forceGridRedraw() {
            guard let mapView = mapView, let gridOverlay = currentMGRSGridOverlay else { return }
            // Force renderer to redraw by removing and re-adding
            mapView.removeOverlay(gridOverlay)
            mapView.addOverlay(gridOverlay, level: .aboveRoads)
        }
        */

        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onMapTap(coordinate)
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return }
            guard let mapView = gesture.view as? MKMapView else { return }

            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            // Check if long-press is on an overlay (drawn shape)
            let mapPoint = MKMapPoint(coordinate)
            var hitOverlay: MKOverlay? = nil
            var drawingId: UUID? = nil
            var drawingType: RadialMenuContext.DrawingType? = nil

            for overlay in mapView.overlays {
                if let polygon = overlay as? MKPolygon {
                    // Check if point is inside polygon
                    let renderer = MKPolygonRenderer(polygon: polygon)
                    let mapPointForRenderer = renderer.point(for: mapPoint)
                    if renderer.path.contains(mapPointForRenderer) {
                        hitOverlay = overlay
                        // Find the polygon drawing
                        if let found = parent.drawingStore.polygons.first(where: { drawing in
                            let coords = drawing.coordinates
                            return coords.count == polygon.pointCount
                        }) {
                            drawingId = found.id
                            drawingType = .polygon
                        }
                        break
                    }
                } else if let circle = overlay as? MKCircle {
                    // Check if point is inside circle
                    let circleCenter = MKMapPoint(circle.coordinate)
                    let distance = mapPoint.distance(to: circleCenter)
                    if distance <= circle.radius {
                        hitOverlay = overlay
                        // Find the circle drawing
                        if let found = parent.drawingStore.circles.first(where: { drawing in
                            return abs(drawing.center.latitude - circle.coordinate.latitude) < 0.0001 &&
                                   abs(drawing.center.longitude - circle.coordinate.longitude) < 0.0001 &&
                                   abs(drawing.radius - circle.radius) < 1.0
                        }) {
                            drawingId = found.id
                            drawingType = .circle
                        }
                        break
                    }
                } else if let polyline = overlay as? MKPolyline {
                    // Check if point is near the line (within 20 meters)
                    let renderer = MKPolylineRenderer(polyline: polyline)
                    let mapPointForRenderer = renderer.point(for: mapPoint)
                    let lineWidth: CGFloat = 30.0 // Tap tolerance in points
                    let strokePath = renderer.path.copy(strokingWithWidth: lineWidth, lineCap: .round, lineJoin: .round, miterLimit: 10)
                    if strokePath.contains(mapPointForRenderer) {
                        hitOverlay = overlay
                        // Find the line drawing
                        if let found = parent.drawingStore.lines.first(where: { drawing in
                            return drawing.coordinates.count == polyline.pointCount
                        }) {
                            drawingId = found.id
                            drawingType = .line
                        }
                        break
                    }
                }
            }

            // Also check annotations (drawing markers and point markers)
            // Use coordinate-based hit testing which is more reliable than view bounds
            var hitAnnotation: MKAnnotation? = nil
            var isPointMarker = false
            let hitTestRadius: CGFloat = 44.0  // Standard touch target

            if hitOverlay == nil {
                for annotation in mapView.annotations {
                    if annotation is MKUserLocation { continue }

                    let annotationPoint = mapView.convert(annotation.coordinate, toPointTo: mapView)
                    let distance = hypot(point.x - annotationPoint.x, point.y - annotationPoint.y)

                    if distance < hitTestRadius {
                        hitAnnotation = annotation
                        // Check if it's a drawing marker
                        if let drawingMarker = annotation as? DrawingMarkerAnnotation {
                            drawingId = drawingMarker.marker.id
                            drawingType = .marker
                        } else if let labelAnnotation = annotation as? DrawingLabelAnnotation {
                            // Long-pressing the shape's name label should resolve
                            // to the owning shape — otherwise users can only hit
                            // the outline, which was the #37 complaint.
                            drawingId = labelAnnotation.ownerID
                            if parent.drawingStore.circles.contains(where: { $0.id == labelAnnotation.ownerID }) {
                                drawingType = .circle
                            } else if parent.drawingStore.polygons.contains(where: { $0.id == labelAnnotation.ownerID }) {
                                drawingType = .polygon
                            } else if parent.drawingStore.lines.contains(where: { $0.id == labelAnnotation.ownerID }) {
                                drawingType = .line
                            }
                        } else if annotation is PointMarkerAnnotation {
                            // This is a point marker - use the radial menu coordinator's handler
                            isPointMarker = true
                        }
                        break
                    }
                }
            }

            // Determine menu configuration based on what was tapped
            let screenPoint = gesture.location(in: mapView)

            if isPointMarker {
                // Point marker - use the full radial menu coordinator handler
                // which properly detects PointMarkerAnnotation and shows the marker menu
                parent.radialMenuCoordinator.handleLongPress(at: screenPoint, on: mapView)
            } else if hitOverlay != nil || hitAnnotation != nil {
                // Long-press on a drawing shape or drawing marker - show marker context menu
                parent.radialMenuCoordinator.showContextMenu(
                    at: screenPoint,
                    for: coordinate,
                    menuType: .markerContext,
                    drawingId: drawingId,
                    drawingType: drawingType
                )
            } else {
                // Long-press on empty map - show map context menu
                parent.radialMenuCoordinator.handleLongPress(at: screenPoint, on: mapView)
            }
        }

        func isDrawingAnnotation(_ annotation: MKAnnotation) -> Bool {
            return annotation is DrawingMarkerAnnotation ||
                   annotation is DrawingLabelAnnotation ||
                   annotation is DrawingTempPointAnnotation ||
                   annotation is MeasurementPointAnnotation
        }

        // Handle info button tap on marker callout
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            guard let annotation = view.annotation else { return }

            // Get screen point for radial menu
            let annotationPoint = mapView.convert(annotation.coordinate, toPointTo: mapView)

            if annotation is PointMarkerAnnotation {
                // Show radial menu for point marker with edit/delete options
                parent.radialMenuCoordinator.handleLongPress(at: annotationPoint, on: mapView)
            } else if let drawingMarker = annotation as? DrawingMarkerAnnotation {
                // Show radial menu for drawing marker
                parent.radialMenuCoordinator.showContextMenu(
                    at: annotationPoint,
                    for: annotation.coordinate,
                    menuType: .markerContext,
                    drawingId: drawingMarker.marker.id,
                    drawingType: .marker
                )
            } else {
                // Generic annotation - show info
                parent.radialMenuCoordinator.handleLongPress(at: annotationPoint, on: mapView)
            }

            // Deselect to dismiss callout
            mapView.deselectAnnotation(annotation, animated: true)
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            // If this is NOT a programmatic update, it's a user gesture
            if !isProgrammaticUpdate {
                isUserInteracting = true
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Reset programmatic flag
            isProgrammaticUpdate = false

            // Always sync region back to SwiftUI to keep state consistent
            // The isUserInteracting flag in updateUIView prevents feedback loops
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }

            // Reset user interaction flag after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isUserInteracting = false
            }

            // Debounce grid updates on fast scrolling
            // NOTE: Grid updates now handled by MapOverlayCoordinator
            // if currentMGRSGridOverlay != nil {
            //     scheduleGridUpdate()
            // }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                return nil
            }

            // Handle point marker annotations (hostile, friendly, etc. from radial menu)
            if let pointMarkerAnnotation = annotation as? PointMarkerAnnotation {
                let identifier = "PointMarker"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = annotation
                }

                let marker = pointMarkerAnnotation.marker
                let size = CGSize(width: 36, height: 36)
                let renderer = UIGraphicsImageRenderer(size: size)
                let image = renderer.image { context in
                    let rect = CGRect(origin: .zero, size: size)

                    // Draw outer circle with affiliation color
                    marker.affiliation.color.uiColor.setFill()
                    let outerPath = UIBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
                    outerPath.fill()

                    // Draw white border
                    UIColor.white.setStroke()
                    outerPath.lineWidth = 2
                    outerPath.stroke()

                    // Draw affiliation icon in center
                    let iconRect = rect.insetBy(dx: 8, dy: 8)
                    let iconColor = UIColor.white
                    iconColor.setFill()

                    // Draw simple shape based on affiliation
                    switch marker.affiliation {
                    case .hostile:
                        // Diamond shape for hostile
                        let path = UIBezierPath()
                        path.move(to: CGPoint(x: iconRect.midX, y: iconRect.minY))
                        path.addLine(to: CGPoint(x: iconRect.maxX, y: iconRect.midY))
                        path.addLine(to: CGPoint(x: iconRect.midX, y: iconRect.maxY))
                        path.addLine(to: CGPoint(x: iconRect.minX, y: iconRect.midY))
                        path.close()
                        path.fill()
                    case .friendly:
                        // Circle for friendly
                        let path = UIBezierPath(ovalIn: iconRect.insetBy(dx: 2, dy: 2))
                        path.fill()
                    case .unknown:
                        // Question mark style for unknown
                        let path = UIBezierPath(ovalIn: iconRect.insetBy(dx: 2, dy: 2))
                        path.fill()
                    case .neutral:
                        // Square for neutral
                        let path = UIBezierPath(rect: iconRect.insetBy(dx: 2, dy: 2))
                        path.fill()
                    }
                }

                annotationView?.image = image
                annotationView?.centerOffset = CGPoint(x: 0, y: -size.height / 2)

                // Add callout accessory
                let detailButton = UIButton(type: .detailDisclosure)
                annotationView?.rightCalloutAccessoryView = detailButton

                return annotationView
            }

            // Handle drawing marker annotations
            if let drawingAnnotation = annotation as? DrawingMarkerAnnotation {
                let identifier = "DrawingMarker"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = annotation
                }

                // Create custom marker image with color
                let size = CGSize(width: 30, height: 30)
                let renderer = UIGraphicsImageRenderer(size: size)
                let image = renderer.image { context in
                    drawingAnnotation.marker.color.uiColor.setFill()
                    let path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
                    path.fill()

                    // Add border
                    UIColor.white.setStroke()
                    path.lineWidth = 2
                    path.stroke()
                }

                annotationView?.image = image
                annotationView?.centerOffset = CGPoint(x: 0, y: -size.height / 2)

                // Info (i) button routes through calloutAccessoryControlTapped
                // below, which opens the radial menu for the drawing. Without
                // this the callout had no entry point to edit the marker.
                annotationView?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)

                return annotationView
            }

            // Handle drawing label annotations (for shapes)
            if let labelAnnotation = annotation as? DrawingLabelAnnotation {
                let identifier = "DrawingLabel"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                } else {
                    annotationView?.annotation = annotation
                }

                // Configure label appearance - ATAK style
                annotationView?.glyphText = labelAnnotation.label
                annotationView?.markerTintColor = .clear
                annotationView?.glyphTintColor = labelAnnotation.color.uiColor
                annotationView?.displayPriority = .defaultHigh

                // Create custom view with label
                let label = UILabel()
                label.text = labelAnnotation.label
                label.font = UIFont.systemFont(ofSize: 11, weight: .bold)
                label.textColor = .white
                label.backgroundColor = labelAnnotation.color.uiColor.withAlphaComponent(0.8)
                label.textAlignment = .center
                label.layer.cornerRadius = 4
                label.layer.masksToBounds = true
                label.sizeToFit()
                label.frame = CGRect(
                    x: 0,
                    y: 0,
                    width: label.frame.width + 12,
                    height: label.frame.height + 6
                )

                // Convert UILabel to UIImage
                let renderer = UIGraphicsImageRenderer(size: label.bounds.size)
                let image = renderer.image { ctx in
                    label.layer.render(in: ctx.cgContext)
                }

                // Use a regular MKAnnotationView for custom rendering
                let customView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                customView.image = image
                customView.canShowCallout = false
                customView.centerOffset = CGPoint(x: 0, y: 0)

                return customView
            }

            // Handle route waypoint annotations
            if let waypointAnnotation = annotation as? RouteWaypointAnnotation {
                return parent.routeOverlayCoordinator.annotationView(for: waypointAnnotation, mapView: mapView)
            }

            // Handle temporary point annotations (measurement and drawing)
            if let title = annotation.title as? String, title.hasPrefix("Point") {
                let identifier = "TempPoint"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                } else {
                    annotationView?.annotation = annotation
                }

                // Create larger, more visible point marker for measurement feedback
                let size = CGSize(width: 20, height: 20)
                let renderer = UIGraphicsImageRenderer(size: size)
                let image = renderer.image { context in
                    // Yellow fill
                    UIColor(red: 1.0, green: 252/255.0, blue: 0, alpha: 1.0).setFill()
                    let circlePath = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
                    circlePath.fill()

                    // White border
                    UIColor.white.setStroke()
                    circlePath.lineWidth = 3
                    circlePath.stroke()

                    // Black inner dot for center precision
                    UIColor.black.setFill()
                    let centerDot = UIBezierPath(ovalIn: CGRect(
                        x: size.width / 2 - 2,
                        y: size.height / 2 - 2,
                        width: 4,
                        height: 4
                    ))
                    centerDot.fill()
                }

                annotationView?.image = image

                return annotationView
            }

            // Handle aircraft annotations
            if annotation is AircraftAnnotation {
                let identifier = AircraftAnnotationView.reuseIdentifier
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? AircraftAnnotationView

                if annotationView == nil {
                    annotationView = AircraftAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                } else {
                    annotationView?.annotation = annotation
                }

                return annotationView
            }

            // Handle CoT marker annotations with MIL-STD-2525 symbols
            let identifier = "CoTMarker_MilStd"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MilStd2525MapAnnotationView

            if annotationView == nil {
                annotationView = MilStd2525MapAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = annotation
            }

            // Get CoT type and callsign from annotation
            let cotType = annotation.subtitle ?? "a-u-G"
            let callsign = annotation.title ?? "UNKNOWN"

            // Configure the MIL-STD-2525 marker view
            annotationView?.configure(
                cotType: cotType ?? "a-u-G",
                callsign: callsign ?? "UNKNOWN",
                echelon: nil
            )

            return annotationView
        }

        // MARK: - Overlay Renderers

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // MARK: - RoutePolyline Renderer (Navigation Routes)
            if let routePolyline = overlay as? RoutePolyline {
                return RoutePolylineRenderer(polyline: routePolyline)
            }

            // MARK: - BreadcrumbTrailPolyline Renderer
            if let breadcrumbPolyline = overlay as? BreadcrumbTrailPolyline {
                let renderer = BreadcrumbTrailRenderer(polyline: breadcrumbPolyline)
                renderer.teamColor = breadcrumbPolyline.teamColor
                renderer.trailWidth = breadcrumbPolyline.lineWidth
                renderer.timestamps = breadcrumbPolyline.timestamps
                renderer.showDirectionArrows = breadcrumbPolyline.showDirectionArrows
                renderer.enableTimeFading = breadcrumbPolyline.enableTimeFading
                renderer.fadeStartTime = breadcrumbPolyline.fadeStartTime
                return renderer
            }

            // MARK: - RangeBearingLineOverlay Renderer
            if let rbOverlay = overlay as? RangeBearingLineOverlay {
                let renderer = RangeBearingLineRenderer(polyline: rbOverlay)
                // Renderer automatically configures from overlay properties in its init
                return renderer
            }

            // MARK: - MGRSGridOverlay Renderer
            if let gridOverlay = overlay as? MGRSGridOverlay {
                let renderer = MGRSGridRenderer(overlay: gridOverlay)
                return renderer
            }

            // Check if MapOverlayCoordinator can provide renderer
            if let coordinatorRenderer = parent.overlayCoordinator.renderer(for: overlay) {
                return coordinatorRenderer
            }

            // MARK: - Drawing Store Overlays (polygons, circles, lines)
            // Get color from drawing store
            let color = parent.drawingStore.getDrawingColor(for: overlay)?.uiColor ?? UIColor.systemRed

            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = color
                renderer.lineWidth = 3
                return renderer
            }

            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.strokeColor = color
                renderer.fillColor = color.withAlphaComponent(0.2)
                renderer.lineWidth = 2
                return renderer
            }

            if let polygon = overlay as? MKPolygon {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.strokeColor = color
                renderer.fillColor = color.withAlphaComponent(0.2)
                renderer.lineWidth = 2
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - Drawing Marker Annotation

class DrawingMarkerAnnotation: NSObject, MKAnnotation {
    let marker: MarkerDrawing
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?

    init(marker: MarkerDrawing) {
        self.marker = marker
        self.coordinate = marker.coordinate
        self.title = marker.label
        self.subtitle = "Marker"
        super.init()
    }
}

// MARK: - Drawing Label Annotation (for shapes)

class DrawingLabelAnnotation: NSObject, MKAnnotation {
    let ownerID: UUID
    var coordinate: CLLocationCoordinate2D
    var label: String
    var color: DrawingColor

    init(ownerID: UUID, coordinate: CLLocationCoordinate2D, label: String, color: DrawingColor) {
        self.ownerID = ownerID
        self.coordinate = coordinate
        self.label = label
        self.color = color
        super.init()
    }
}

// Tagged annotation for in-progress drawing points so the diff-based
// update can distinguish them from other MKPointAnnotations. Measurement
// uses MeasurementPointAnnotation from MeasurementService.swift.
class DrawingTempPointAnnotation: MKPointAnnotation {}

// MARK: - Overlay Settings Panel

struct OverlaySettingsPanel: View {
    @ObservedObject var overlayCoordinator: MapOverlayCoordinator
    @ObservedObject var mapStateManager: MapStateManager

    @Binding var showMGRSGrid: Bool
    @Binding var showBreadcrumbTrails: Bool
    @Binding var showRBLines: Bool

    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("OVERLAYS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.system(size: 16))
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)

            // MGRS Grid Toggle
            OverlayToggleButton(
                icon: "grid",
                title: "MGRS Grid",
                isActive: showMGRSGrid
            ) {
                showMGRSGrid.toggle()
                overlayCoordinator.saveSettings()
            }

            // Grid Density Picker (only show when grid is active)
            if showMGRSGrid {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Grid Density")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 10)

                    Picker("Density", selection: $overlayCoordinator.mgrsGridDensity) {
                        ForEach(MGRSGridDensity.allCases) { density in
                            Text(density.rawValue).tag(density)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 10)
                }
            }

            Divider()
                .background(Color.white.opacity(0.3))
                .padding(.vertical, 4)

            // Breadcrumb Trails Toggle
            OverlayToggleButton(
                icon: "point.topleft.down.curvedto.point.bottomright.up",
                title: "Breadcrumb Trails",
                isActive: showBreadcrumbTrails
            ) {
                showBreadcrumbTrails.toggle()
                overlayCoordinator.saveSettings()
            }

            // R&B Lines Toggle
            OverlayToggleButton(
                icon: "arrow.triangle.swap",
                title: "R&B Lines",
                isActive: showRBLines
            ) {
                showRBLines.toggle()
                overlayCoordinator.saveSettings()
            }

            Divider()
                .background(Color.white.opacity(0.3))
                .padding(.vertical, 4)

            // Current Map Center MGRS
            VStack(alignment: .leading, spacing: 4) {
                Text("MAP CENTER")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.gray)

                Text(overlayCoordinator.currentCenterMGRS.isEmpty ? "--" : overlayCoordinator.currentCenterMGRS)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 8)
        }
        .frame(width: 200)
        .background(Color.black.opacity(0.9))
        .cornerRadius(12)
    }
}

// MARK: - Overlay Toggle Button

struct OverlayToggleButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 12))
                Spacer()
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(isActive ? Color.green.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
    }
}
