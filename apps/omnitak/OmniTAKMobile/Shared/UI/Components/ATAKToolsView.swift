import SwiftUI
import MapKit

// MARK: - ATAK Tools Menu View
// Comprehensive tools menu with 5x4 grid layout matching ATAK interface

struct ATAKToolsView: View {
    @Binding var isPresented: Bool
    @Binding var showMeasurement: Bool  // Shared measurement state from MapViewController
    @State private var showAlertDialog = false
    @State private var showBrightnessControl = false

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
    @State private var showDigitalPointer = false
    @State private var showTurnByTurnNav = false
    @State private var showMeshtastic = false
    @State private var showADSB = false
    @State private var showContacts = false
    @State private var showPositionBroadcast = false
    @State private var showMissionSync = false
    @State private var showElevationProfile = false
    @State private var showLineOfSight = false
    @State private var showEchelonHierarchy = false

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
            // Use new MapLibre-based 3D terrain view
            MapLibre3DSettingsView(service: MapLibreService.shared)
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
        .sheet(isPresented: $showContacts) {
            ContactListView(chatManager: chatManager)
        }
        .sheet(isPresented: $showPositionBroadcast) {
            PositionBroadcastView()
        }
        .sheet(isPresented: $showMissionSync) {
            MissionPackageSyncView()
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
            // Reuse the existing radial-menu notification that opens the drawing tools panel
            NotificationCenter.default.post(name: .radialMenuOpenDrawingTools, object: nil)
            isPresented = false  // Dismiss tools menu so the drawing panel is visible
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
        case "brightness":
            showBrightnessControl = true
        case "plugins":
            showPlugins = true
        case "settings":
            showSettings = true
        case "turnbyturn":
            showTurnByTurnNav = true
        case "meshtastic":
            showMeshtastic = true
        case "adsb":
            showADSB = true

        // Drawer-absorbed map-driven destinations
        case "contacts":
            showContacts = true
        case "selfsa":
            showPositionBroadcast = true
        case "missionsync":
            showMissionSync = true
        case "elevation":
            showElevationProfile = true
        case "los":
            showLineOfSight = true
        case "echelon":
            showEchelonHierarchy = true

        default:
            // Unknown tool ids are a no-op — there is no fallback detail view.
            break
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
            ZStack(alignment: .topTrailing) {
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

                // "Beta" badge for disabled/experimental tools
                if !isEnabled {
                    Text("BETA")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .cornerRadius(3)
                        .padding(4)
                }
            }
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
        ATAKTool(id: "video", displayName: "Video", iconName: "video.fill", description: "Video streaming (Beta - requires TAK server)"),
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
        ATAKTool(id: "3dview", displayName: "3D Terrain", iconName: "view.3d", description: "Real 3D terrain with MapLibre"),
        ATAKTool(id: "turnbyturn", displayName: "Navigation", iconName: "location.north.line.fill", description: "Turn-by-turn voice navigation"),
        ATAKTool(id: "meshtastic", displayName: "Meshtastic", iconName: "dot.radiowaves.left.and.right", description: "Meshtastic mesh networking"),

        // Row 5 - Map-driven destinations (absorbed from removed navigation drawer)
        ATAKTool(id: "contacts", displayName: "Contacts", iconName: "person.2.fill", description: "Team contacts and presence"),
        ATAKTool(id: "selfsa", displayName: "Self SA", iconName: "dot.radiowaves.up.forward", description: "Position broadcasting (PLI)"),
        ATAKTool(id: "missionsync", displayName: "Mission Sync", iconName: "arrow.triangle.2.circlepath", description: "Mission package sync"),
        ATAKTool(id: "elevation", displayName: "Elevation", iconName: "mountain.2.fill", description: "Elevation profile"),
        ATAKTool(id: "los", displayName: "Line of Sight", iconName: "eye.fill", description: "Line of sight analysis"),

        // Row 6 - Hierarchy & Utilities
        ATAKTool(id: "echelon", displayName: "Hierarchy", iconName: "rectangle.connected.to.line.below", description: "Unit hierarchy / echelon"),
        ATAKTool(id: "adsb", displayName: "ADS-B", iconName: "airplane.circle.fill", description: "ADS-B aircraft tracking"),
        ATAKTool(id: "plugins", displayName: "Plugins", iconName: "puzzlepiece.extension.fill", description: "Manage plugins"),
        ATAKTool(id: "settings", displayName: "Settings", iconName: "gearshape.fill", description: "App settings")
    ]
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
// Color extension with hex initializer is defined in SharedUIComponents.swift
