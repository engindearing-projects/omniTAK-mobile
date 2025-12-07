import SwiftUI
import MapKit

// MARK: - ATAK Tools Menu View
// Comprehensive tools menu with 5x4 grid layout matching ATAK interface

struct ATAKToolsView: View {
    @Binding var isPresented: Bool
    @Binding var showMeasurement: Bool  // Shared measurement state from MapViewController
    @State private var showAlertDialog = false
    @State private var showBrightnessControl = false
    @State private var selectedTool: ATAKTool?

    // Feature sheet states
    @State private var showTeamManagement = false
    @State private var showRoutePlanning = false
    @State private var showGeofences = false
    @State private var showTrackRecording = false
    @State private var showChat = false
    @State private var showEmergencySOS = false
    @State private var showDataPackages = false
    @State private var showVideoStreaming = false
    @State private var showOfflineMaps = false
    @State private var showPointDropper = false
    @State private var showSettings = false
    @State private var showPlugins = false
    @State private var showMEDEVAC = false
    @State private var showCASRequest = false
    @State private var showSPOTREP = false
    @State private var showBloodhound = false
    @State private var show3DView = false
    @State private var showArcGISPortal = false
    @State private var showDigitalPointer = false
    @State private var showTurnByTurnNav = false
    @State private var showMeshtastic = false
    @State private var showADSB = false

    @ObservedObject private var chatManager = ChatManager.shared
    @StateObject private var trackRecordingService = TrackRecordingService()
    @ObservedObject private var pluginManager = PluginSettingsManager.shared
    @AppStorage("showDisabledTools") private var showDisabledTools: Bool = true

    let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 5)

    /// Filtered tools based on the toggle
    private var visibleTools: [ATAKTool] {
        if showDisabledTools {
            return ATAKTool.allTools
        } else {
            return ATAKTool.allTools.filter { pluginManager.isToolEnabled($0.id) }
        }
    }

    var body: some View {
        ZStack {
            // Dark background
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with toggle
                ToolsHeader(
                    showDisabledTools: $showDisabledTools,
                    onClose: { isPresented = false }
                )

                // Tools Grid (5x4 layout)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 0) {
                        ForEach(visibleTools) { tool in
                            let isEnabled = pluginManager.isToolEnabled(tool.id)
                            ToolButton(
                                tool: tool,
                                isEnabled: isEnabled,
                                action: {
                                    if isEnabled {
                                        handleToolSelection(tool)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .sheet(item: $selectedTool) { tool in
            ToolDetailView(tool: tool, isPresented: $selectedTool)
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
        .sheet(isPresented: $showEmergencySOS) {
            EmergencyBeaconView()
        }
        .sheet(isPresented: $showDataPackages) {
            DataPackageSheetView(isPresented: $showDataPackages)
        }
        .sheet(isPresented: $showVideoStreaming) {
            VideoFeedListView()
        }
        .sheet(isPresented: $showOfflineMaps) {
            OfflineMapsView()
        }
        .sheet(isPresented: $showPointDropper) {
            PointDropperSheetView(isPresented: $showPointDropper)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showPlugins) {
            PluginsListView()
        }
        .sheet(isPresented: $showMEDEVAC) {
            MEDEVACRequestView()
        }
        .sheet(isPresented: $showCASRequest) {
            CASRequestView()
        }
        .sheet(isPresented: $showSPOTREP) {
            SPOTREPView()
        }
        .sheet(isPresented: $showBloodhound) {
            BloodhoundSheetView()
        }
        .sheet(isPresented: $show3DView) {
            Map3DSettingsView(terrainService: TerrainVisualizationService.shared)
        }
        .sheet(isPresented: $showArcGISPortal) {
            ArcGISPortalView()
        }
        .sheet(isPresented: $showDigitalPointer) {
            DigitalPointerControlPanel()
        }
        .sheet(isPresented: $showTurnByTurnNav) {
            TurnByTurnNavigationView()
        }
        .sheet(isPresented: $showMeshtastic) {
            MeshtasticConnectionView()
        }
        .sheet(isPresented: $showADSB) {
            ADSBTrafficView()
        }
    }

    private func handleToolSelection(_ tool: ATAKTool) {
        switch tool.id {
        // Core Features
        case "teams":
            showTeamManagement = true
        case "chat":
            showChat = true
        case "routes":
            showRoutePlanning = true
        case "geofence":
            showGeofences = true
        case "tracks":
            showTrackRecording = true

        // Data & Media
        case "data":
            showDataPackages = true
        case "video":
            showVideoStreaming = true
        case "offline":
            showOfflineMaps = true
        case "drawing":
            selectedTool = tool
        case "measure":
            // Use the shared measurement overlay from MapViewController
            showMeasurement = true
            isPresented = false  // Dismiss tools menu

        // Tactical
        case "alert":
            showEmergencySOS = true
        case "pointer":
            showPointDropper = true
        case "casevac":
            showMEDEVAC = true
        case "nineline":
            showCASRequest = true
        case "bloodhound":
            showBloodhound = true
        case "spotrep":
            showSPOTREP = true

        // Utilities
        case "3dview":
            show3DView = true
        case "arcgis":
            showArcGISPortal = true
        case "brightness":
            showBrightnessControl = true
        case "plugins":
            showPlugins = true
        case "settings":
            showSettings = true
        case "digitalpointer":
            showDigitalPointer = true
        case "turnbyturn":
            showTurnByTurnNav = true
        case "meshtastic":
            showMeshtastic = true
        case "adsb":
            showADSB = true

        default:
            selectedTool = tool
        }
    }
}

// MARK: - Tools Header

struct ToolsHeader: View {
    @Binding var showDisabledTools: Bool
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Tools")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
            .padding()

            // Toggle row
            HStack {
                Text("Show disabled")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)

                Spacer()

                Toggle("", isOn: $showDisabledTools)
                    .labelsHidden()
                    .scaleEffect(0.8)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color.black)
    }
}

// MARK: - Tool Button

struct ToolButton: View {
    let tool: ATAKTool
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: tool.iconName)
                    .font(.system(size: 32))
                    .foregroundColor(isEnabled ? .white : .gray.opacity(0.4))
                    .frame(height: 44)

                Text(tool.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(isEnabled ? .white : .gray.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 32)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isEnabled ? Color(white: 0.15) : Color(white: 0.08))
            .overlay(
                Rectangle()
                    .stroke(Color(white: 0.3), lineWidth: 0.5)
            )
            .overlay(
                // Disabled overlay
                Group {
                    if !isEnabled {
                        Color.black.opacity(0.3)
                    }
                }
            )
        }
        .disabled(!isEnabled)
    }
}

// MARK: - ATAK Tool Model

struct ATAKTool: Identifiable {
    let id: String
    let displayName: String
    let iconName: String
    let description: String

    static let allTools: [ATAKTool] = [
        // Row 1 - Core Features
        ATAKTool(id: "teams", displayName: "Teams", iconName: "person.3.fill", description: "Team management and coordination"),
        ATAKTool(id: "chat", displayName: "Chat", iconName: "message.fill", description: "Team chat messaging"),
        ATAKTool(id: "routes", displayName: "Routes", iconName: "point.topleft.down.to.point.bottomright.curvepath.fill", description: "Route planning and navigation"),
        ATAKTool(id: "geofence", displayName: "Geofence", iconName: "square.dashed", description: "Create geofence alerts"),
        ATAKTool(id: "tracks", displayName: "Tracks", iconName: "record.circle", description: "Track recording and playback"),

        // Row 2 - Data & Media
        ATAKTool(id: "data", displayName: "Data Packages", iconName: "shippingbox.fill", description: "Manage data packages"),
        ATAKTool(id: "video", displayName: "Video", iconName: "video.fill", description: "Video streaming feeds"),
        ATAKTool(id: "offline", displayName: "Offline Maps", iconName: "arrow.down.doc.fill", description: "Download maps for offline use"),
        ATAKTool(id: "drawing", displayName: "Drawing", iconName: "pencil.tip.crop.circle", description: "Draw on map"),
        ATAKTool(id: "measure", displayName: "Measure", iconName: "ruler", description: "Distance and area measurement"),

        // Row 3 - Tactical
        ATAKTool(id: "alert", displayName: "Emergency", iconName: "sos", description: "Emergency SOS beacon"),
        ATAKTool(id: "pointer", displayName: "Point Drop", iconName: "mappin.and.ellipse", description: "Drop tactical markers"),
        ATAKTool(id: "casevac", displayName: "CASEVAC", iconName: "cross.case.fill", description: "Request casualty evacuation"),
        ATAKTool(id: "nineline", displayName: "9-Line CAS", iconName: "airplane", description: "Close Air Support request"),
        ATAKTool(id: "bloodhound", displayName: "Bloodhound", iconName: "antenna.radiowaves.left.and.right", description: "Blue Force Tracking"),

        // Row 4 - Utilities & Reports
        ATAKTool(id: "spotrep", displayName: "SPOTREP", iconName: "doc.text.fill", description: "Quick tactical spot report"),
        ATAKTool(id: "3dview", displayName: "3D View", iconName: "view.3d", description: "3D terrain perspective view"),
        ATAKTool(id: "digitalpointer", displayName: "Digital Pointer", iconName: "hand.point.up.left.fill", description: "Share cursor position with team"),
        ATAKTool(id: "turnbyturn", displayName: "Navigation", iconName: "location.north.line.fill", description: "Turn-by-turn voice navigation"),
        ATAKTool(id: "meshtastic", displayName: "Meshtastic", iconName: "dot.radiowaves.left.and.right", description: "Meshtastic mesh networking"),

        // Row 5 - Additional Utilities
        ATAKTool(id: "arcgis", displayName: "ArcGIS", iconName: "globe.americas.fill", description: "ArcGIS Portal content"),
        ATAKTool(id: "adsb", displayName: "ADS-B", iconName: "airplane.circle.fill", description: "ADS-B aircraft tracking"),
        ATAKTool(id: "plugins", displayName: "Plugins", iconName: "puzzlepiece.extension.fill", description: "Manage plugins"),
        ATAKTool(id: "settings", displayName: "Settings", iconName: "gearshape.fill", description: "App settings")
    ]
}

// MARK: - Tool Detail View

struct ToolDetailView: View {
    let tool: ATAKTool
    @Binding var isPresented: ATAKTool?

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    Image(systemName: tool.iconName)
                        .font(.system(size: 80))
                        .foregroundColor(Color(hex: "#FFFC00"))
                        .padding(.top, 40)

                    Text(tool.displayName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text(tool.description)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Spacer()

                    // Tool-specific content would go here
                    if tool.id == "geofence" {
                        GeofenceToolContent()
                    } else if tool.id == "chat" {
                        ChatToolContent()
                    } else if tool.id == "alert" {
                        AlertToolContent()
                    } else {
                        Text("Coming Soon")
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                            .padding()
                    }

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = nil
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        }
    }
}

// MARK: - Geofence Tool Content

struct GeofenceToolContent: View {
    @State private var geofenceName = ""
    @State private var radius = 100.0
    @State private var showAlert = true

    var body: some View {
        VStack(spacing: 16) {
            TextField("Geofence Name", text: $geofenceName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            HStack {
                Text("Radius:")
                    .foregroundColor(.white)
                Slider(value: $radius, in: 50...5000, step: 50)
                Text("\(Int(radius))m")
                    .foregroundColor(.white)
                    .frame(width: 60)
            }
            .padding(.horizontal)

            Toggle("Alert on Entry", isOn: $showAlert)
                .foregroundColor(.white)
                .padding(.horizontal)

            Button(action: {}) {
                Text("Create Geofence")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#FFFC00"))
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Chat Tool Content

struct ChatToolContent: View {
    @State private var message = ""
    @State private var messages: [SimpleChatMessage] = []

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { msg in
                        SimpleChatBubble(message: msg)
                    }
                }
                .padding()
            }

            HStack(spacing: 12) {
                TextField("Type message...", text: $message)
                    .textFieldStyle(.roundedBorder)

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(Color(hex: "#FFFC00"))
                        .font(.system(size: 20))
                }
            }
            .padding()
            .background(Color(white: 0.15))
        }
    }

    private func sendMessage() {
        guard !message.isEmpty else { return }
        messages.append(SimpleChatMessage(text: message, sender: "You", timestamp: Date()))
        message = ""
    }
}

// Simple local message structs for tool demo (not the full ChatMessage from ChatModels.swift)
struct SimpleChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let sender: String
    let timestamp: Date
}

struct SimpleChatBubble: View {
    let message: SimpleChatMessage

    var body: some View {
        HStack {
            if message.sender == "You" {
                Spacer()
            }

            VStack(alignment: message.sender == "You" ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(12)
                    .background(message.sender == "You" ? Color(hex: "#FFFC00") : Color(white: 0.2))
                    .foregroundColor(message.sender == "You" ? .black : .white)
                    .cornerRadius(16)

                Text(message.sender)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }

            if message.sender != "You" {
                Spacer()
            }
        }
    }
}

// MARK: - Alert Tool Content

struct AlertToolContent: View {
    @State private var alertType = "Emergency"
    @State private var message = ""

    let alertTypes = ["Emergency", "Warning", "Information", "Critical"]

    var body: some View {
        VStack(spacing: 16) {
            Picker("Alert Type", selection: $alertType) {
                ForEach(alertTypes, id: \.self) { type in
                    Text(type).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            TextEditor(text: $message)
                .frame(height: 120)
                .padding(4)
                .background(Color(white: 0.2))
                .cornerRadius(8)
                .padding(.horizontal)

            Button(action: {}) {
                Text("Send Alert")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Sheet Wrapper Views

struct DataPackageSheetView: View {
    @Binding var isPresented: Bool
    @StateObject private var packageManager = DataPackageManager()

    var body: some View {
        DataPackageView(packageManager: packageManager, isPresented: $isPresented)
    }
}

struct PointDropperSheetView: View {
    @Binding var isPresented: Bool
    @StateObject private var service = PointDropperService()

    var body: some View {
        PointDropperView(
            service: service,
            isPresented: $isPresented,
            currentLocation: nil,
            mapCenter: nil
        )
    }
}

struct BloodhoundSheetView: View {
    @StateObject private var bloodhoundService = BloodhoundService()
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )

    var body: some View {
        BloodhoundView(bloodhoundService: bloodhoundService, mapRegion: $mapRegion)
    }
}

// MARK: - Color Extension
// Color extension with hex initializer is defined in NavigationDrawer.swift
