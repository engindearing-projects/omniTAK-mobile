import SwiftUI
import MapKit
import CoreLocation

// Enhanced ATAK-style Map View with all new features integrated
struct ATAKMapViewEnhanced: View {
    @StateObject private var takService = TAKService()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var drawingStore = DrawingStore()
    @StateObject private var drawingManager: DrawingToolsManager
    @StateObject private var chatManager = ChatManager.shared
    @StateObject private var filterCriteria = CoTFilterCriteria()
    @StateObject private var offlineMapManager = OfflineMapManager.shared

    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    // Panel visibility states
    @State private var showServerConfig = false
    @State private var showLayersPanel = false
    @State private var showDrawingPanel = false
    @State private var showDrawingList = false
    @State private var showChatView = false
    @State private var showFilterPanel = false
    @State private var showUnitList = false
    @State private var showOfflineMaps = false

    // Map states
    @State private var mapType: MKMapType = .satellite
    @State private var trackingMode: MapUserTrackingMode = .follow
    @State private var activeMapLayer = "satellite"
    @State private var showFriendly = true
    @State private var showHostile = true
    @State private var showUnknown = false

    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var isLandscape: Bool {
        horizontalSizeClass == .regular || verticalSizeClass == .compact
    }

    init() {
        let store = DrawingStore()
        _drawingStore = StateObject(wrappedValue: store)
        _drawingManager = StateObject(wrappedValue: DrawingToolsManager(drawingStore: store))
    }

    // Filtered CoT markers
    private var filteredMarkers: [EnhancedCoTMarker] {
        let filterManager = CoTFilterManager(criteria: filterCriteria)
        let enrichedEvents = takService.enhancedMarkers.values.map { marker in
            return filterManager.enrichEvent(
                marker,
                userLocation: locationManager.location?.coordinate
            )
        }
        return filterManager.filterEvents(enrichedEvents).map { $0.marker }
    }

    var body: some View {
        ZStack {
            // Main Map View
            EnhancedMapViewRepresentable(
                region: $mapRegion,
                mapType: $mapType,
                trackingMode: $trackingMode,
                markers: filteredMarkers,
                showsUserLocation: true,
                drawingStore: drawingStore,
                drawingManager: drawingManager,
                takService: takService,
                onMapTap: handleMapTap
            )
            .ignoresSafeArea()

            // Top Status Bar
            VStack(spacing: 0) {
                EnhancedStatusBar(
                    connectionStatus: takService.connectionStatus,
                    isConnected: takService.isConnected,
                    messagesReceived: takService.messagesReceived,
                    messagesSent: takService.messagesSent,
                    gpsAccuracy: locationManager.accuracy,
                    serverName: ServerManager.shared.activeServer?.name,
                    unreadChatCount: chatManager.totalUnreadCount,
                    onServerTap: { showServerConfig = true }
                )
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
                .padding(.horizontal, 8)
                .padding(.top, 8)

                Spacer()

                // Enhanced Bottom Toolbar with all features
                EnhancedBottomToolbar(
                    mapType: $mapType,
                    showLayersPanel: $showLayersPanel,
                    showDrawingPanel: $showDrawingPanel,
                    showDrawingList: $showDrawingList,
                    showChatView: $showChatView,
                    showFilterPanel: $showFilterPanel,
                    showUnitList: $showUnitList,
                    showOfflineMaps: $showOfflineMaps,
                    unreadChatCount: chatManager.totalUnreadCount,
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

            // Layer Panel (Left)
            if showLayersPanel {
                HStack {
                    ATAKSidePanel(
                        isExpanded: $showLayersPanel,
                        activeMapLayer: $activeMapLayer,
                        showFriendly: $showFriendly,
                        showHostile: $showHostile,
                        showUnknown: $showUnknown,
                        onLayerToggle: toggleLayer,
                        onOverlayToggle: toggleOverlay
                    )
                    .background(Color.black.opacity(0.9))
                    .cornerRadius(12)
                    .padding(.leading, 8)
                    .padding(.vertical, isLandscape ? 80 : 120)
                    .transition(.move(edge: .leading))

                    Spacer()
                }
            }

            // Drawing Tools Panel (Right)
            if showDrawingPanel {
                HStack {
                    Spacer()
                    DrawingToolsPanel(
                        drawingManager: drawingManager,
                        isVisible: $showDrawingPanel,
                        onComplete: {},
                        onCancel: {}
                    )
                    .padding(.trailing, 8)
                    .padding(.vertical, isLandscape ? 80 : 120)
                    .transition(.move(edge: .trailing))
                }
            }

            // Drawing List Panel (Right)
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

            // CoT Filter Panel (Right)
            if showFilterPanel {
                HStack {
                    Spacer()
                    CoTFilterPanel(
                        filterCriteria: filterCriteria,
                        isVisible: $showFilterPanel,
                        totalUnits: takService.enhancedMarkers.count,
                        filteredUnits: filteredMarkers.count
                    )
                    .frame(width: 320)
                    .padding(.trailing, 8)
                    .padding(.vertical, isLandscape ? 80 : 120)
                    .transition(.move(edge: .trailing))
                }
            }

            // Unit List View (Right)
            if showUnitList {
                HStack {
                    Spacer()
                    CoTUnitListView(
                        filterCriteria: filterCriteria,
                        events: Array(takService.enhancedMarkers.values),
                        userLocation: locationManager.location?.coordinate,
                        isVisible: $showUnitList,
                        onSelectUnit: { marker in
                            centerOnMarker(marker)
                        }
                    )
                    .frame(width: 350)
                    .padding(.trailing, 8)
                    .padding(.vertical, isLandscape ? 60 : 100)
                    .transition(.move(edge: .trailing))
                }
            }
        }
        .sheet(isPresented: $showServerConfig) {
            ServerConfigView(takService: takService)
        }
        .sheet(isPresented: $showChatView) {
            ChatView(chatManager: chatManager)
        }
        .sheet(isPresented: $showOfflineMaps) {
            OfflineMapsView()
        }
        .onAppear {
            setupTAKConnection()
            startLocationUpdates()
            setupChatIntegration()
        }
    }

    // MARK: - Setup

    private func setupTAKConnection() {
        if let activeServer = ServerManager.shared.activeServer {
            takService.connect(
                host: activeServer.host,
                port: activeServer.port,
                protocolType: activeServer.protocolType,
                useTLS: activeServer.useTLS
            )
        }
    }

    private func startLocationUpdates() {
        locationManager.startUpdating()
    }

    private func setupChatIntegration() {
        chatManager.setTAKService(takService)
        chatManager.setLocationManager(locationManager)
    }

    // MARK: - Actions

    private func handleMapTap(at coordinate: CLLocationCoordinate2D) {
        if drawingManager.isDrawingActive {
            drawingManager.handleMapTap(at: coordinate)
        }
    }

    private func centerOnUser() {
        if let location = locationManager.location {
            withAnimation {
                mapRegion.center = location.coordinate
                mapRegion.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            }
            trackingMode = .follow
        }
    }

    private func centerOnMarker(_ marker: EnhancedCoTMarker) {
        withAnimation {
            mapRegion.center = marker.coordinate
            mapRegion.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        }
    }

    private func sendSelfPosition() {
        guard let location = locationManager.location else { return }
        let cotXml = generateSelfCoT(location: location)
        _ = takService.sendCoT(xml: cotXml)
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

    private func toggleLayer(_ layer: String) {
        activeMapLayer = layer
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
        switch overlay {
        case "friendly": showFriendly.toggle()
        case "hostile": showHostile.toggle()
        case "unknown": showUnknown.toggle()
        default: break
        }
    }

    // MARK: - CoT Generation

    private func generateSelfCoT(location: CLLocation) -> String {
        let uid = "SELF-iOS-\(UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString)"
        let formatter = ISO8601DateFormatter()
        let now = Date()
        let time = formatter.string(from: now)
        let stale = formatter.string(from: now.addingTimeInterval(300))

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="\(uid)" type="a-f-G-E-S" time="\(time)" start="\(time)" stale="\(stale)">
            <point lat="\(location.coordinate.latitude)" lon="\(location.coordinate.longitude)" hae="\(location.altitude)" ce="\(location.horizontalAccuracy)" le="\(location.verticalAccuracy)"/>
            <detail>
                <contact callsign="OmniTAK-iOS"/>
                <__group name="Cyan" role="Team Member"/>
                <takv device="iPhone" platform="iOS" os="\(UIDevice.current.systemVersion)" version="1.0"/>
                <track speed="\(location.speed)" course="\(location.course)"/>
            </detail>
        </event>
        """
    }
}

// MARK: - Enhanced Status Bar

struct EnhancedStatusBar: View {
    let connectionStatus: String
    let isConnected: Bool
    let messagesReceived: Int
    let messagesSent: Int
    let gpsAccuracy: Double?
    let serverName: String?
    let unreadChatCount: Int
    let onServerTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Server/Connection Status
            Button(action: onServerTap) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(serverName ?? "No Server")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
            }

            Divider()
                .frame(height: 16)
                .background(Color.white.opacity(0.3))

            // Message Counters
            HStack(spacing: 8) {
                Label("\(messagesReceived)", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.green)
                Label("\(messagesSent)", systemImage: "arrow.up.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
            }

            Spacer()

            // Chat Notification Badge
            if unreadChatCount > 0 {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 20, height: 20)
                    Text("\(unreadChatCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            // GPS Accuracy
            if let accuracy = gpsAccuracy {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                    Text(String(format: "%.0fm", accuracy))
                        .font(.system(size: 11))
                }
                .foregroundColor(accuracy < 10 ? .green : accuracy < 50 ? .yellow : .orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Enhanced Bottom Toolbar

struct EnhancedBottomToolbar: View {
    @Binding var mapType: MKMapType
    @Binding var showLayersPanel: Bool
    @Binding var showDrawingPanel: Bool
    @Binding var showDrawingList: Bool
    @Binding var showChatView: Bool
    @Binding var showFilterPanel: Bool
    @Binding var showUnitList: Bool
    @Binding var showOfflineMaps: Bool
    let unreadChatCount: Int
    let onCenterUser: () -> Void
    let onSendCoT: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Layers Button
            ToolbarButton(icon: "square.stack.3d.up.fill", isActive: showLayersPanel) {
                withAnimation { showLayersPanel.toggle() }
            }

            // Drawing Tools Button
            ToolbarButton(icon: "pencil.tip.crop.circle", isActive: showDrawingPanel) {
                withAnimation { showDrawingPanel.toggle() }
            }

            // Unit List/Filter Button
            ToolbarButton(icon: "line.3.horizontal.decrease.circle", isActive: showUnitList || showFilterPanel) {
                withAnimation {
                    if showFilterPanel {
                        showFilterPanel = false
                        showUnitList = true
                    } else if showUnitList {
                        showUnitList = false
                    } else {
                        showUnitList = true
                    }
                }
            }

            Spacer()

            // Center on User
            ToolbarButton(icon: "location.circle.fill", isActive: false, action: onCenterUser)

            // Send Position
            ToolbarButton(icon: "antenna.radiowaves.left.and.right", isActive: false, action: onSendCoT)

            Spacer()

            // Team Chat (with badge)
            ZStack(alignment: .topTrailing) {
                ToolbarButton(icon: "bubble.left.and.bubble.right.fill", isActive: showChatView) {
                    withAnimation { showChatView.toggle() }
                }

                if unreadChatCount > 0 {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 16, height: 16)
                        Text("\(unreadChatCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 8, y: -8)
                }
            }

            // Offline Maps
            ToolbarButton(icon: "map.fill", isActive: showOfflineMaps) {
                withAnimation { showOfflineMaps.toggle() }
            }

            // Zoom Controls
            VStack(spacing: 4) {
                ToolbarButton(icon: "plus", isActive: false, action: onZoomIn)
                    .frame(width: 36, height: 32)
                ToolbarButton(icon: "minus", isActive: false, action: onZoomOut)
                    .frame(width: 36, height: 32)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Toolbar Button Component

struct ToolbarButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(isActive ? .blue : .white)
                .frame(width: 44, height: 44)
                .background(isActive ? Color.blue.opacity(0.2) : Color.clear)
                .cornerRadius(8)
        }
    }
}
