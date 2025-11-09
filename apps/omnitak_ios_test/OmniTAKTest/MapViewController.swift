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
    @State private var showNavigationDrawer = false
    @State private var currentScreen = "map"
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
                    onServerTap: { showServerConfig = true },
                    onMenuTap: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showNavigationDrawer.toggle()
                        }
                    }
                )
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
                .padding(.horizontal, 8)
                .padding(.top, 8)

                Spacer()

                // Bottom Toolbar (ATAK-style)
                ATAKBottomToolbar(
                    mapType: $mapType,
                    showLayersPanel: $showLayersPanel,
                    showDrawingPanel: $showDrawingPanel,
                    showDrawingList: $showDrawingList,
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

            // Navigation Drawer Overlay - ATAK Style
            NavigationDrawer(
                isOpen: $showNavigationDrawer,
                currentScreen: $currentScreen,
                userName: "Operator",
                userCallsign: "ALPHA-1",
                connectionStatus: takService.isConnected ? "CONNECTED" : "DISCONNECTED",
                onNavigate: { screen in
                    currentScreen = screen
                    print("🧭 Navigate to: \(screen)")
                    // TODO: Implement screen navigation
                }
            )
            .zIndex(1001) // Above all other UI elements
        }
        .sheet(isPresented: $showServerConfig) {
            ServerConfigView(takService: takService)
        }
        .onAppear {
            setupTAKConnection()
            startLocationUpdates()
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
            print("🔌 Auto-connecting to: \(activeServer.displayName)")
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
            print("🎯 Centered on user: \(location.coordinate.latitude), \(location.coordinate.longitude)")
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
            print("📤 Broadcast position: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        }
    }

    private func zoomIn() {
        withAnimation {
            mapRegion.span.latitudeDelta = max(mapRegion.span.latitudeDelta / 2, 0.001)
            mapRegion.span.longitudeDelta = max(mapRegion.span.longitudeDelta / 2, 0.001)
        }
        print("🔍 Zoom in: \(mapRegion.span.latitudeDelta)")
    }

    private func zoomOut() {
        withAnimation {
            mapRegion.span.latitudeDelta = min(mapRegion.span.latitudeDelta * 2, 180)
            mapRegion.span.longitudeDelta = min(mapRegion.span.longitudeDelta * 2, 180)
        }
        print("🔍 Zoom out: \(mapRegion.span.latitudeDelta)")
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
                print("🗺️ Map type: Satellite")
            case "hybrid":
                mapType = .hybrid
                print("🗺️ Map type: Hybrid")
            case "standard":
                mapType = .standard
                print("🗺️ Map type: Standard")
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
            print("⚠️ Hostile units: \(showHostile ? "ON" : "OFF")")
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

    var body: some View {
        HStack(spacing: 12) {
            // Hamburger Menu Button - ATAK Style
            Button(action: onMenuTap) {
                VStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 24, height: 3)
                        .cornerRadius(2)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 24, height: 3)
                        .cornerRadius(2)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 24, height: 3)
                        .cornerRadius(2)
                }
                .frame(width: 48, height: 48)
            }

            // iTAK Title with LED Status Indicator
            HStack(spacing: 8) {
                Text("iTAK")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.988, blue: 0.0)) // #FFFC00

                HStack(spacing: 6) {
                    // LED-style connection indicator with glow
                    Circle()
                        .fill(isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                        .shadow(color: isConnected ? .green : .red, radius: 4)

                    Text(isConnected ? "CONN" : "DISC")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(isConnected ? .green : .red)
                }
            }

            Spacer()

            // Server Name Button
            Button(action: onServerTap) {
                HStack(spacing: 4) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 10))
                    Text(serverName ?? "TAK")
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundColor(isConnected ? .green : .gray)
            }

            // Messages
            HStack(spacing: 2) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 10))
                Text("\(messagesReceived)")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.cyan)

            HStack(spacing: 2) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 10))
                Text("\(messagesSent)")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.orange)

            Spacer()

            // GPS Status
            HStack(spacing: 4) {
                Image(systemName: gpsAccuracy < 10 ? "location.fill" : "location.slash.fill")
                    .font(.system(size: 10))
                Text(String(format: "±%.0fm", gpsAccuracy))
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(gpsAccuracy < 10 ? .green : .yellow)

            // Time
            Text(Date().formatted(date: .omitted, time: .shortened))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - ATAK Bottom Toolbar

struct ATAKBottomToolbar: View {
    @Binding var mapType: MKMapType
    @Binding var showLayersPanel: Bool
    @Binding var showDrawingPanel: Bool
    @Binding var showDrawingList: Bool
    let onCenterUser: () -> Void
    let onSendCoT: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            // Layers
            ToolButton(icon: "square.stack.3d.up.fill", label: "Layers") {
                showLayersPanel.toggle()
                showDrawingPanel = false
                showDrawingList = false
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

            // Drawing Tools
            ToolButton(icon: "pencil.tip.crop.circle", label: "Draw") {
                showDrawingPanel.toggle()
                showLayersPanel = false
                showDrawingList = false
            }

            // Drawing List
            ToolButton(icon: "list.bullet.rectangle", label: "Drawings") {
                showDrawingList.toggle()
                showLayersPanel = false
                showDrawingPanel = false
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// Tool Button Component
struct ToolButton: View {
    let icon: String
    let label: String
    var compact: Bool = false
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: compact ? 16 : 20, weight: .semibold))
                if !label.isEmpty {
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                }
            }
            .foregroundColor(.white)
            .frame(width: compact ? 36 : 56, height: compact ? 36 : 56)
            .background(isPressed ? Color.cyan.opacity(0.5) : Color.black.opacity(0.3))
            .cornerRadius(8)
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
    let onLayerToggle: (String) -> Void
    let onOverlayToggle: (String) -> Void

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

// MARK: - Server Config View

// MARK: - Server Management Views

struct ServerConfigView: View {
    @ObservedObject var takService: TAKService
    @StateObject var serverManager = ServerManager.shared
    @State private var showAddServer = false
    @State private var serverToEdit: TAKServer?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("STATUS") {
                    HStack {
                        Text("Connection")
                        Spacer()
                        Text(takService.connectionStatus)
                            .foregroundColor(takService.isConnected ? .green : .red)
                    }
                    HStack {
                        Text("Active Server")
                        Spacer()
                        Text(serverManager.activeServer?.name ?? "None")
                            .foregroundColor(.blue)
                    }
                    HStack {
                        Text("Messages RX")
                        Spacer()
                        Text("\(takService.messagesReceived)")
                    }
                    HStack {
                        Text("Messages TX")
                        Spacer()
                        Text("\(takService.messagesSent)")
                    }
                }

                Section("TAK SERVERS") {
                    ForEach(serverManager.servers) { server in
                        ServerRow(
                            server: server,
                            isActive: serverManager.activeServer?.id == server.id,
                            isConnected: takService.isConnected && serverManager.activeServer?.id == server.id,
                            onSelect: {
                                selectAndConnect(server)
                            },
                            onEdit: {
                                serverToEdit = server
                            }
                        )
                    }
                    .onDelete(perform: deleteServers)
                }

                Section {
                    Button(action: { showAddServer = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Server")
                        }
                        .foregroundColor(.blue)
                    }

                    if takService.isConnected {
                        Button(action: { takService.disconnect() }) {
                            HStack {
                                Spacer()
                                Text("Disconnect")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("TAK Servers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAddServer) {
                ServerEditView(server: nil, onSave: { newServer in
                    serverManager.addServer(newServer)
                    showAddServer = false
                })
            }
            .sheet(item: $serverToEdit) { server in
                ServerEditView(server: server, onSave: { updatedServer in
                    serverManager.updateServer(updatedServer)
                    serverToEdit = nil
                })
            }
        }
    }

    private func selectAndConnect(_ server: TAKServer) {
        serverManager.setActiveServer(server)
        if takService.isConnected {
            takService.disconnect()
        }
        takService.connect(
            host: server.host,
            port: server.port,
            protocolType: server.protocolType,
            useTLS: server.useTLS
        )
    }

    private func deleteServers(at offsets: IndexSet) {
        for index in offsets {
            let server = serverManager.servers[index]
            serverManager.deleteServer(server)
        }
    }
}

struct ServerRow: View {
    let server: TAKServer
    let isActive: Bool
    let isConnected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(server.name)
                        .font(.system(size: 15, weight: .semibold))
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 14))
                    }
                }
                Text("\(server.host):\(server.port)")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                HStack(spacing: 8) {
                    Text(server.protocolType.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                    if server.useTLS {
                        Text("TLS")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                    if isConnected {
                        Text("CONNECTED")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.3))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: onSelect) {
                    Image(systemName: isConnected ? "bolt.circle.fill" : "bolt.circle")
                        .font(.system(size: 24))
                        .foregroundColor(isConnected ? .green : .blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)
    }
}

struct ServerEditView: View {
    let server: TAKServer?
    let onSave: (TAKServer) -> Void

    @State private var name: String
    @State private var host: String
    @State private var port: String
    @State private var protocolType: String
    @State private var useTLS: Bool
    @Environment(\.dismiss) var dismiss

    init(server: TAKServer?, onSave: @escaping (TAKServer) -> Void) {
        self.server = server
        self.onSave = onSave
        _name = State(initialValue: server?.name ?? "")
        _host = State(initialValue: server?.host ?? "")
        _port = State(initialValue: server != nil ? "\(server!.port)" : "8087")
        _protocolType = State(initialValue: server?.protocolType ?? "tcp")
        _useTLS = State(initialValue: server?.useTLS ?? false)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("SERVER DETAILS") {
                    TextField("Name", text: $name)
                        .autocapitalization(.words)
                    TextField("Host", text: $host)
                        .autocapitalization(.none)
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                }

                Section("CONNECTION") {
                    Picker("Protocol", selection: $protocolType) {
                        Text("TCP").tag("tcp")
                        Text("UDP").tag("udp")
                    }
                    Toggle("Use TLS", isOn: $useTLS)
                }

                Section {
                    Button(action: saveServer) {
                        HStack {
                            Spacer()
                            Text("Save Server")
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                    .disabled(name.isEmpty || host.isEmpty || port.isEmpty)
                }
            }
            .navigationTitle(server == nil ? "Add Server" : "Edit Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveServer() {
        guard let portNum = UInt16(port), !name.isEmpty, !host.isEmpty else { return }

        let updatedServer = TAKServer(
            id: server?.id ?? UUID(),
            name: name,
            host: host,
            port: portNum,
            protocolType: protocolType,
            useTLS: useTLS,
            isDefault: server?.isDefault ?? false
        )

        onSave(updatedServer)
        dismiss()
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
    let onMapTap: (CLLocationCoordinate2D) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = showsUserLocation
        mapView.mapType = mapType
        mapView.region = region

        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:)))
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update coordinator reference
        context.coordinator.parent = self

        // Update map type
        if mapView.mapType != mapType {
            mapView.mapType = mapType
            print("🗺️ Map type updated to: \(mapTypeString(mapType))")
        }

        // Update region
        if !context.coordinator.isUserInteracting {
            mapView.setRegion(region, animated: true)
        }

        // Update markers
        updateAnnotations(mapView: mapView, markers: markers, context: context)

        // Update overlays
        updateOverlays(mapView: mapView, context: context)
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

        // Add temporary drawing point annotations
        if drawingManager.isDrawingActive {
            let tempAnnotations = drawingManager.getTemporaryAnnotations()
            mapView.addAnnotations(tempAnnotations)
        }
    }

    private func updateOverlays(mapView: MKMapView, context: Context) {
        // Remove all overlays
        mapView.removeOverlays(mapView.overlays)

        // Add saved drawing overlays
        let savedOverlays = drawingStore.getAllOverlays()
        mapView.addOverlays(savedOverlays)

        // Add temporary overlay if drawing
        if let tempOverlay = drawingManager.getTemporaryOverlay() {
            mapView.addOverlay(tempOverlay)
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

        init(_ parent: TacticalMapView) {
            self.parent = parent
        }

        @objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onMapTap(coordinate)
        }

        func isDrawingAnnotation(_ annotation: MKAnnotation) -> Bool {
            return annotation is DrawingMarkerAnnotation || annotation.title == "Point"
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            isUserInteracting = true
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isUserInteracting = false
            }
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

            // Handle temporary point annotations
            if annotation.title == "Point" {
                let identifier = "TempPoint"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

                if annotationView == nil {
                    annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                } else {
                    annotationView?.annotation = annotation
                }

                // Create small point marker
                let size = CGSize(width: 12, height: 12)
                let renderer = UIGraphicsImageRenderer(size: size)
                let image = renderer.image { context in
                    UIColor.systemYellow.setFill()
                    let path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: size))
                    path.fill()

                    UIColor.white.setStroke()
                    path.lineWidth = 2
                    path.stroke()
                }

                annotationView?.image = image

                return annotationView
            }

            // Handle CoT marker annotations
            let identifier = "CoTMarker"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }

            // Determine marker color based on subtitle (type)
            let type = annotation.subtitle ?? ""
            let color: UIColor
            if type?.contains("a-f") == true {
                color = .systemBlue  // Friendly
            } else if type?.contains("a-h") == true {
                color = .systemRed   // Hostile
            } else {
                color = .systemYellow // Unknown
            }

            // Create custom marker image
            let size = CGSize(width: 30, height: 30)
            let renderer = UIGraphicsImageRenderer(size: size)
            let image = renderer.image { context in
                color.setFill()
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

        // MARK: - Overlay Renderers

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
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
        self.title = marker.name
        self.subtitle = "Drawing Marker"
        super.init()
    }
}
