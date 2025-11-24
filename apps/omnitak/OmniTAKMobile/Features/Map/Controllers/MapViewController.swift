import SwiftUI
import MapKit
import CoreLocation

// ATAK-style Map View with tactical interface
struct ATAKMapView: View {
    @StateObject private var takService = TAKService()
    @StateObject private var federation = MultiServerFederation()  // Multi-server support
    @StateObject private var locationManager = LocationManager()
    @StateObject private var drawingStore: DrawingStore
    @StateObject private var drawingManager: DrawingToolsManager
    @StateObject private var radialMenuCoordinator = RadialMenuMapCoordinator()
    @ObservedObject private var chatManager = ChatManager.shared
    @StateObject private var trackRecordingService = TrackRecordingService()
    @StateObject private var overlayCoordinator = MapOverlayCoordinator()
    @StateObject private var mapStateManager = MapStateManager()
    @StateObject private var measurementManager = MeasurementManager()

    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365), // Default: DC
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var showServerConfig = false
    @State private var showLayersPanel = false
    @State private var showDrawingPanel = false
    @State private var showDrawingList = false
    @State private var showNavigationDrawer = false
    @State private var currentScreen = "map"
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
    @State private var showLineOfSight = false
    @State private var showEchelonHierarchy = false
    @State private var showMissionSync = false
    @State private var showMeshtastic = false
    @State private var showMeasurement = false

    // Position broadcasting service
    @ObservedObject private var positionBroadcastService = PositionBroadcastService.shared

    // Layer states
    @State private var activeMapLayer = "satellite"
    @State private var showFriendly = true
    @State private var showHostile = true
    @State private var showUnknown = false

    // Map overlay states
    @State private var showCompass = false  // Hidden by default for max map space
    @State private var showCoordinates = false  // Hidden by default for max map space
    @State private var showScaleBar = false  // Hidden by default for max map space
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
    @State private var showCallsignPanel = false  // Hidden by default for max map space

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

    // MARK: - Computed Properties to Fix Type Checking

    @ViewBuilder
    private var mainMapView: some View {
        TacticalMapView(
            region: $mapRegion,
            mapType: $mapType,
            trackingMode: $trackingMode,
            markers: cotMarkers,
            showsUserLocation: true,
            drawingStore: drawingStore,
            drawingManager: drawingManager,
            radialMenuCoordinator: radialMenuCoordinator,
            overlayCoordinator: overlayCoordinator,
            mapStateManager: mapStateManager,
            measurementManager: measurementManager,
            onMapTap: handleMapTap
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var gridOverlay: some View {
        GridOverlayView(region: mapRegion, isVisible: overlayCoordinator.mgrsGridEnabled)
            .zIndex(100)
            .opacity(overlayCoordinator.mgrsGridEnabled ? 1 : 0)
            .allowsHitTesting(overlayCoordinator.mgrsGridEnabled)
    }

    @ViewBuilder
    private var topToolbars: some View {
        VStack(spacing: 0) {
            ATAKStatusBar(
                connectionStatus: multiServerConnectionStatus(),
                isConnected: federation.getConnectedCount() > 0,
                messagesReceived: takService.messagesReceived,
                messagesSent: takService.messagesSent,
                gpsAccuracy: locationManager.accuracy,
                serverName: multiServerDisplayName(),
                onServerTap: { showServerConfig = true },
                onMenuTap: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showToolsMenu = true
                    }
                }
            )

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
                    showUnknown: $showUnknown,
                    showCompass: $showCompass,
                    showCoordinates: $showCoordinates,
                    showScaleBar: $showScaleBar,
                    showGrid: $showGrid,
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
                    isVisible: $showDrawingList
                )
                .padding(.trailing, 8)
                .padding(.vertical, isLandscape ? 80 : 120)
                .transition(.move(edge: .trailing))
            }
            .zIndex(1010)
        }
    }

    @ViewBuilder
    private var navigationDrawer: some View {
        NavigationDrawer(
            isOpen: $showNavigationDrawer,
            currentScreen: $currentScreen,
            userName: "Operator",
            userCallsign: "ALPHA-1",
            connectionStatus: takService.isConnected ? "CONNECTED" : "DISCONNECTED",
            onNavigate: { screen in
                currentScreen = screen
                #if DEBUG
                print("🧭 Navigate to: \(screen)")
                #endif

                // Handle navigation
                switch screen {
                case "map":
                    // Already on map, do nothing
                    break
                case "tools":
                    showToolsMenu = true
                case "teams":
                    showTeamManagement = true
                case "routes":
                    showRoutePlanning = true
                case "geofences":
                    showGeofences = true
                case "tracks":
                    showTrackRecording = true
                case "chat":
                    showChat = true
                case "contacts":
                    showContacts = true
                case "emergency":
                    showEmergencySOS = true
                case "settings":
                    showSettings = true
                case "servers":
                    showServerConfig = true
                case "plugins":
                    showPlugins = true
                case "about":
                    showAbout = true
                case "selfsa":
                    showPositionBroadcast = true
                case "meshtastic":
                    showMeshtastic = true
                case "elevation":
                    showElevationProfile = true
                case "los":
                    showLineOfSight = true
                case "echelon":
                    showEchelonHierarchy = true
                case "missionsync":
                    showMissionSync = true
                default:
                    break
                }
            }
        )
        .zIndex(1001)
    }

    @ViewBuilder
    private var statusIndicators: some View {
        Group {
            gpsStatusIndicator
            callsignDisplay
            geofenceAlert
        }
    }

    @ViewBuilder
    private var gpsStatusIndicator: some View {
        VStack {
            HStack {
                Spacer()
                GPSStatusIndicator(
                    accuracy: locationManager.accuracy,
                    isAvailable: locationManager.location != nil,
                    showError: false
                )
                .padding([.trailing], 12)
                .padding([.top], 60)
            }
            Spacer()
        }
        .zIndex(1002)
    }

    @ViewBuilder
    private var callsignDisplay: some View {
        if showCallsignPanel, let location = locationManager.location {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    CallsignDisplay(
                        callsign: "MURK",
                        coordinates: formatCoordinates(location.coordinate),
                        altitude: formatAltitude(location.altitude),
                        speed: formatSpeed(location.speed),
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
                    callsign: "MURK",
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
        CompassOverlayView(
            heading: locationManager.location?.course,
            isVisible: showCompass
        )
        .zIndex(1005)
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
            mapCenterDisplay
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

    @ViewBuilder
    private var mapCenterDisplay: some View {
        VStack {
            Spacer()
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("CENTER")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)
                    Text(mapStateManager.formattedCenterCoordinate)
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)

                    Button(action: {
                        mapStateManager.cycleCoordinateFormat()
                    }) {
                        Text(mapStateManager.coordinateFormat.shortName)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.2))
                            .cornerRadius(3)
                    }
                }
                .padding(6)
                .background(Color.black.opacity(0.8))
                .cornerRadius(6)
                .padding(.leading, 8)
                .padding(.bottom, 75)
                Spacer()
            }
        }
        .zIndex(1011)
    }

    @ViewBuilder
    private var gpsFollowButton: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom, spacing: 8) {
                // GPS Follow Button - Bottom Left
                Button(action: centerOnUser) {
                    VStack(spacing: 2) {
                        Image(systemName: trackingMode == .follow ? "location.fill" : "location")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(trackingMode == .follow ? Color(hex: "#FFFC00") : .white)

                        Text(trackingMode == .follow ? "Follow" : "GPS")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(trackingMode == .follow ? Color(hex: "#FFFC00") : .white)
                    }
                    .frame(width: 48, height: 48)
                    .background(
                        trackingMode == .follow ?
                        Color(hex: "#FFFC00").opacity(0.25) :
                        Color.black.opacity(0.7)
                    )
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(trackingMode == .follow ? Color(hex: "#FFFC00") : Color.white.opacity(0.3), lineWidth: trackingMode == .follow ? 2 : 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)

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
            .padding(.bottom, isCursorModeActive ? 222 : (showQuickActionToolbar ? 130 : 80))
        }
        .zIndex(1012)
    }

    var body: some View {
        ZStack {
            mainMapView
            gridOverlay
            topToolbars
            sidePanels
            navigationDrawer
            statusIndicators
            mapOverlayComponents
            interactiveOverlays
            gpsFollowButton

            // Compact measurement overlay (ATAK-style)
            if showMeasurement {
                CompactMeasurementOverlay(manager: measurementManager, isPresented: $showMeasurement)
                    .zIndex(1000)
            }
        }
        .background(modalSheets)
        .background(errorOverlays)
        .background(lifecycleHandlers)
    }

    private var modalSheets: some View {
        EmptyView()
            .sheet(isPresented: $showServerConfig) {
                NetworkPreferencesView()
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
                case "show_layers":
                    withAnimation(.spring()) {
                        showLayersPanel.toggle()
                    }
                case "draw_shape":
                    withAnimation(.spring()) {
                        showDrawingPanel.toggle()
                    }
                case "meshtastic":
                    showMeshtastic = true
                default:
                    print("Unknown custom action: \(identifier)")
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
        let marker = PointDropperService.shared.quickDrop(
            at: coordinate,
            name: callsign,
            broadcast: false
        )

        print("Marker dropped at: \(coordinate.latitude), \(coordinate.longitude) - \(marker.name)")

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
        // Auto-connect to active server from ServerManager
        let serverManager = ServerManager.shared
        if let activeServer = serverManager.activeServer {
            takService.connect(
                host: activeServer.host,
                port: activeServer.port,
                protocolType: activeServer.protocolType,
                useTLS: activeServer.useTLS,
                certificateName: activeServer.certificateName,
                certificatePassword: activeServer.certificatePassword
            )
            #if DEBUG
            print("🔌 Auto-connecting to: \(activeServer.displayName)")
            #endif
        }
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
            #if DEBUG
            print("🔓 GPS follow mode disabled - free pan enabled")
            #endif
        } else {
            // Enable follow mode and center on user
            if let location = locationManager.location {
                withAnimation {
                    mapRegion.center = location.coordinate
                    mapRegion.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                }
                trackingMode = .follow
                #if DEBUG
                print("🎯 GPS follow mode enabled: \(location.coordinate.latitude), \(location.coordinate.longitude)")
                #endif
            } else {
                print("❌ No location available")
            }
        }
    }

    private func sendSelfPosition() {
        guard let location = locationManager.location else {
            print("❌ Cannot send position - no location")
            return
        }

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
            #if DEBUG
            print("📤 Broadcast position to \(federation.getConnectedCount()) server(s): \(location.coordinate.latitude), \(location.coordinate.longitude)")
            #endif
        } else {
            #if DEBUG
            print("⚠️ No servers connected - cannot broadcast position")
            #endif
        }
    }

    private func zoomIn() {
        // Zoom in by halving the span - no animation for instant response
        mapRegion.span.latitudeDelta = max(mapRegion.span.latitudeDelta / 2, 0.001)
        mapRegion.span.longitudeDelta = max(mapRegion.span.longitudeDelta / 2, 0.001)
        #if DEBUG
        print("🔍 Zoom in: \(mapRegion.span.latitudeDelta)")
        #endif
    }

    private func zoomOut() {
        // Zoom out by doubling the span - no animation for instant response
        mapRegion.span.latitudeDelta = min(mapRegion.span.latitudeDelta * 2, 180)
        mapRegion.span.longitudeDelta = min(mapRegion.span.longitudeDelta * 2, 180)
        #if DEBUG
        print("🔍 Zoom out: \(mapRegion.span.latitudeDelta)")
        #endif
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
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Toggle overlay visibility
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

    private func toggleMapOverlay(_ overlay: String) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        // Toggle map overlay visibility
        withAnimation(.easeInOut(duration: 0.3)) {
            switch overlay {
            case "compass":
                showCompass.toggle()
                #if DEBUG
                print("🧭 Compass: \(showCompass ? "ON" : "OFF")")
                #endif
            case "coordinates":
                showCoordinates.toggle()
                #if DEBUG
                print("📍 Coordinates: \(showCoordinates ? "ON" : "OFF")")
                #endif
            case "scale":
                showScaleBar.toggle()
                print("📏 Scale Bar: \(showScaleBar ? "ON" : "OFF")")
            case "grid":
                showGrid.toggle()
                #if DEBUG
                print("🗺️ Grid: \(showGrid ? "ON" : "OFF")")
                #endif
            default:
                break
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
        let altitudeFeet = altitude * 3.28084 // Convert meters to feet
        return String(format: "%.0f ft MSL", altitudeFeet)
    }

    private func formatSpeed(_ speed: CLLocationSpeed) -> String {
        let speedMPH = speed * 2.23694 // Convert m/s to MPH
        return String(format: "%.0f MPH", max(0, speedMPH))
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
                <takv device="iPhone" platform="OmniTAK" os="iOS" version="1.0.0"/>
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
            // Zoom Controls
            VStack(spacing: 4) {
                MapToolButton(icon: "plus", label: "", compact: true) {
                    onZoomIn()
                }
                MapToolButton(icon: "minus", label: "", compact: true) {
                    onZoomOut()
                }
            }

            Spacer()

            // Drawing Tools
            MapToolButton(icon: "pencil.tip.crop.circle", label: "Draw") {
                showDrawingPanel.toggle()
                showLayersPanel = false
                showDrawingList = false
            }

            // Drawing List
            MapToolButton(icon: "list.bullet.rectangle", label: "Drawings") {
                showDrawingList.toggle()
                showLayersPanel = false
                showDrawingPanel = false
            }
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
    @Binding var showUnknown: Bool
    @Binding var showCompass: Bool
    @Binding var showCoordinates: Bool
    @Binding var showScaleBar: Bool
    @Binding var showGrid: Bool
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
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    @Published var accuracy: Double = 0

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
        accuracy = locations.last?.horizontalAccuracy ?? 0
    }
}

// MARK: - Tactical Map View (UIViewRepresentable for mapType support)

struct TacticalMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var mapType: MKMapType
    @Binding var trackingMode: MapUserTrackingMode
    let markers: [CoTMarker]
    let showsUserLocation: Bool
    @ObservedObject var drawingStore: DrawingStore
    @ObservedObject var drawingManager: DrawingToolsManager
    @ObservedObject var radialMenuCoordinator: RadialMenuMapCoordinator
    @ObservedObject var overlayCoordinator: MapOverlayCoordinator
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
            print("Map type updated to: \(mapTypeString(mapType))")
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

        // Update markers
        updateAnnotations(mapView: mapView, markers: markers, context: context)

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

    private func updateAnnotations(mapView: MKMapView, markers: [CoTMarker], context: Context) {
        // Remove old CoT annotations (but keep drawing annotations)
        let oldAnnotations = mapView.annotations.filter { annotation in
            !(annotation is MKUserLocation) &&
            !context.coordinator.isDrawingAnnotation(annotation)
        }
        mapView.removeAnnotations(oldAnnotations)

        // Add new CoT annotations
        let annotations = markers.map { marker -> MKPointAnnotation in
            let annotation = MKPointAnnotation()
            annotation.coordinate = marker.coordinate
            annotation.title = marker.callsign
            annotation.subtitle = marker.type
            return annotation
        }
        mapView.addAnnotations(annotations)

        // Update drawing annotations
        updateDrawingAnnotations(mapView: mapView, context: context)
    }

    private func updateDrawingAnnotations(mapView: MKMapView, context: Context) {
        // Remove old drawing annotations
        let oldDrawingAnnotations = mapView.annotations.filter { context.coordinator.isDrawingAnnotation($0) }
        mapView.removeAnnotations(oldDrawingAnnotations)

        // Add drawing marker annotations
        for marker in drawingStore.markers {
            let annotation = DrawingMarkerAnnotation(marker: marker)
            mapView.addAnnotation(annotation)
        }

        // Add label annotations for circles
        for circle in drawingStore.circles {
            let annotation = DrawingLabelAnnotation(
                coordinate: circle.center,
                label: circle.label,
                color: circle.color
            )
            mapView.addAnnotation(annotation)
        }

        // Add label annotations for polygons
        for polygon in drawingStore.polygons {
            // Calculate centroid of polygon
            if let centroid = calculateCentroid(coordinates: polygon.coordinates) {
                let annotation = DrawingLabelAnnotation(
                    coordinate: centroid,
                    label: polygon.label,
                    color: polygon.color
                )
                mapView.addAnnotation(annotation)
            }
        }

        // Add label annotations for lines
        for line in drawingStore.lines {
            // Use midpoint of line
            if line.coordinates.count >= 2 {
                let midIndex = line.coordinates.count / 2
                let annotation = DrawingLabelAnnotation(
                    coordinate: line.coordinates[midIndex],
                    label: line.label,
                    color: line.color
                )
                mapView.addAnnotation(annotation)
            }
        }

        // Add temporary drawing point annotations
        if drawingManager.isDrawingActive {
            let tempAnnotations = drawingManager.getTemporaryAnnotations()
            mapView.addAnnotations(tempAnnotations)
        }

        // Add temporary measurement point annotations
        if measurementManager.isActive {
            let tempAnnotations = measurementManager.getTemporaryAnnotations()
            mapView.addAnnotations(tempAnnotations)
        }
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

            // Also check annotations (drawing markers)
            var hitAnnotation: MKAnnotation? = nil
            if hitOverlay == nil {
                let annotationViews = mapView.annotations.compactMap { mapView.view(for: $0) }
                for view in annotationViews {
                    let viewPoint = gesture.location(in: view)
                    if view.bounds.contains(viewPoint) {
                        hitAnnotation = view.annotation
                        // Check if it's a drawing marker
                        if let drawingMarker = view.annotation as? DrawingMarkerAnnotation {
                            drawingId = drawingMarker.marker.id
                            drawingType = .marker
                        }
                        break
                    }
                }
            }

            // Determine menu configuration based on what was tapped
            let screenPoint = gesture.location(in: mapView)

            if hitOverlay != nil || hitAnnotation != nil {
                // Long-press on a shape or marker - show marker context menu
                parent.radialMenuCoordinator.showContextMenu(
                    at: screenPoint,
                    for: coordinate,
                    menuType: .markerContext,
                    drawingId: drawingId,
                    drawingType: drawingType
                )
            } else {
                // Long-press on empty map - show map context menu
                parent.radialMenuCoordinator.showContextMenu(
                    at: screenPoint,
                    for: coordinate,
                    menuType: .mapContext
                )
            }
        }

        func isDrawingAnnotation(_ annotation: MKAnnotation) -> Bool {
            return annotation is DrawingMarkerAnnotation ||
                   annotation is DrawingLabelAnnotation ||
                   annotation.title == "Point"
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
    var coordinate: CLLocationCoordinate2D
    let label: String
    let color: DrawingColor

    init(coordinate: CLLocationCoordinate2D, label: String, color: DrawingColor) {
        self.coordinate = coordinate
        self.label = label
        self.color = color
        super.init()
    }
}

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
