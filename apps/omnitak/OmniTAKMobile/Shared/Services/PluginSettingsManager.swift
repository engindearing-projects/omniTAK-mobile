//
//  PluginSettingsManager.swift
//  OmniTAKMobile
//
//  Manages persistent plugin/feature enable states
//

import SwiftUI
import Combine

/// Plugin identifiers matching tool IDs in ATAKToolsView
enum PluginID: String, CaseIterable {
    case meshtastic = "meshtastic"
    case offlineMaps = "offline"
    case trackRecording = "tracks"
    case drawingTools = "drawing"
    case measurementTools = "measure"
    case dataPackages = "data"
    case teamManagement = "teams"
    case routePlanning = "routes"
    case emergencyBeacon = "alert"
    case chat = "chat"
    case video = "video"
    case geofence = "geofence"
    case casevac = "casevac"
    case nineline = "nineline"
    case bloodhound = "bloodhound"
    case spotrep = "spotrep"
    case view3d = "3dview"
    case digitalPointer = "digitalpointer"
    case turnByTurn = "turnbyturn"
    case arcgis = "arcgis"
    case adsb = "adsb"

    var displayName: String {
        switch self {
        case .meshtastic: return "Meshtastic"
        case .offlineMaps: return "Offline Maps"
        case .trackRecording: return "Track Recording"
        case .drawingTools: return "Drawing Tools"
        case .measurementTools: return "Measurement Tools"
        case .dataPackages: return "Data Packages"
        case .teamManagement: return "Team Management"
        case .routePlanning: return "Route Planning"
        case .emergencyBeacon: return "Emergency Beacon"
        case .chat: return "Chat"
        case .video: return "Video"
        case .geofence: return "Geofence"
        case .casevac: return "CASEVAC"
        case .nineline: return "9-Line CAS"
        case .bloodhound: return "Bloodhound"
        case .spotrep: return "SPOTREP"
        case .view3d: return "3D View"
        case .digitalPointer: return "Digital Pointer"
        case .turnByTurn: return "Navigation"
        case .arcgis: return "ArcGIS"
        case .adsb: return "ADS-B"
        }
    }

    var icon: String {
        switch self {
        case .meshtastic: return "dot.radiowaves.left.and.right"
        case .offlineMaps: return "map.fill"
        case .trackRecording: return "record.circle"
        case .drawingTools: return "pencil.tip"
        case .measurementTools: return "ruler"
        case .dataPackages: return "shippingbox.fill"
        case .teamManagement: return "person.3.fill"
        case .routePlanning: return "point.topleft.down.to.point.bottomright.curvepath.fill"
        case .emergencyBeacon: return "sos"
        case .chat: return "message.fill"
        case .video: return "video.fill"
        case .geofence: return "square.dashed"
        case .casevac: return "cross.case.fill"
        case .nineline: return "airplane"
        case .bloodhound: return "antenna.radiowaves.left.and.right"
        case .spotrep: return "doc.text.fill"
        case .view3d: return "view.3d"
        case .digitalPointer: return "hand.point.up.left.fill"
        case .turnByTurn: return "location.north.line.fill"
        case .arcgis: return "globe.americas.fill"
        case .adsb: return "airplane.circle.fill"
        }
    }

    var description: String {
        switch self {
        case .meshtastic: return "Off-grid LoRa mesh networking"
        case .offlineMaps: return "Download and use maps offline"
        case .trackRecording: return "Record and playback GPS tracks"
        case .drawingTools: return "Create tactical drawings on map"
        case .measurementTools: return "Measure distances and areas"
        case .dataPackages: return "Import and export data packages"
        case .teamManagement: return "Organize and manage teams"
        case .routePlanning: return "Plan and share routes"
        case .emergencyBeacon: return "Emergency beacon and alerts"
        case .chat: return "Team chat messaging"
        case .video: return "Video streaming feeds"
        case .geofence: return "Create geofence alerts"
        case .casevac: return "Request casualty evacuation"
        case .nineline: return "Close Air Support request"
        case .bloodhound: return "Blue Force Tracking"
        case .spotrep: return "Quick tactical spot report"
        case .view3d: return "3D terrain perspective view"
        case .digitalPointer: return "Share cursor position with team"
        case .turnByTurn: return "Turn-by-turn voice navigation"
        case .arcgis: return "ArcGIS Portal content"
        case .adsb: return "ADS-B aircraft traffic overlay"
        }
    }
}

/// Singleton manager for plugin enabled states with persistence
class PluginSettingsManager: ObservableObject {
    static let shared = PluginSettingsManager()

    private let userDefaults = UserDefaults.standard
    private let keyPrefix = "plugin_enabled_"

    /// Published dictionary of plugin enabled states
    @Published private(set) var enabledPlugins: [PluginID: Bool] = [:]

    private init() {
        loadSettings()
    }

    /// Load settings from UserDefaults
    private func loadSettings() {
        var settings: [PluginID: Bool] = [:]
        for plugin in PluginID.allCases {
            let key = keyPrefix + plugin.rawValue
            // Default to enabled if not set
            if userDefaults.object(forKey: key) == nil {
                settings[plugin] = true
            } else {
                settings[plugin] = userDefaults.bool(forKey: key)
            }
        }
        enabledPlugins = settings
    }

    /// Check if a plugin is enabled
    func isEnabled(_ plugin: PluginID) -> Bool {
        return enabledPlugins[plugin] ?? true
    }

    /// Check if a tool ID is enabled (for ATAKToolsView compatibility)
    func isToolEnabled(_ toolID: String) -> Bool {
        // Core tools that can't be disabled
        let alwaysEnabled = ["settings", "plugins", "pointer"]
        if alwaysEnabled.contains(toolID) {
            return true
        }

        // Map tool ID to plugin
        if let plugin = PluginID(rawValue: toolID) {
            return isEnabled(plugin)
        }

        // Unknown tools default to enabled
        return true
    }

    /// Set plugin enabled state
    func setEnabled(_ plugin: PluginID, enabled: Bool) {
        let key = keyPrefix + plugin.rawValue
        userDefaults.set(enabled, forKey: key)
        enabledPlugins[plugin] = enabled
        objectWillChange.send()
    }

    /// Toggle plugin state
    func toggle(_ plugin: PluginID) {
        let currentState = isEnabled(plugin)
        setEnabled(plugin, enabled: !currentState)
    }

    /// Get binding for a plugin (for use in Toggle views)
    func binding(for plugin: PluginID) -> Binding<Bool> {
        Binding(
            get: { self.isEnabled(plugin) },
            set: { self.setEnabled(plugin, enabled: $0) }
        )
    }

    /// Reset all plugins to enabled
    func resetAll() {
        for plugin in PluginID.allCases {
            setEnabled(plugin, enabled: true)
        }
    }
}
