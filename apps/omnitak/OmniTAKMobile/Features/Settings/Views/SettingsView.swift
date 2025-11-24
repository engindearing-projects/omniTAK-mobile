//
//  SettingsView.swift
//  OmniTAKMobile
//
//  App settings and preferences
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("userCallsign") private var userCallsign = "ALPHA-1"
    @AppStorage("userName") private var userName = "Operator"
    @AppStorage("autoConnect") private var autoConnect = true
    @AppStorage("sendPositionInterval") private var sendPositionInterval = 30.0
    @AppStorage("enableHaptics") private var enableHaptics = true
    @AppStorage("darkMode") private var darkMode = true
    @AppStorage("showTrafficOverlay") private var showTrafficOverlay = false
    @AppStorage("enableLocationSharing") private var enableLocationSharing = true
    @AppStorage("batteryOptimization") private var batteryOptimization = false

    // Map Overlay Settings
    @AppStorage("mgrsGridEnabled") private var mgrsGridEnabled = false
    @AppStorage("mgrsGridDensity") private var mgrsGridDensityString = "1km"
    @AppStorage("showMGRSLabels") private var showMGRSLabels = true
    @AppStorage("coordinateDisplayFormat") private var coordinateFormatString = "MGRS"
    @AppStorage("breadcrumbTrailsEnabled") private var breadcrumbTrailsEnabled = true
    @AppStorage("trailMaxLength") private var trailMaxLength = 100
    @AppStorage("trailColorName") private var trailColorName = "cyan"

    @State private var showNetworkPreferences = false

    var body: some View {
        NavigationView {
            List {
                // User Profile
                Section("USER PROFILE") {
                    HStack {
                        Text("Callsign")
                        Spacer()
                        TextField("Callsign", text: $userCallsign)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.blue)
                    }

                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Name", text: $userName)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.blue)
                    }
                }

                // Network Preferences (ATAK Style)
                Section("NETWORK") {
                    NavigationLink(destination: NetworkPreferencesView()) {
                        HStack {
                            Image(systemName: "wifi")
                                .foregroundColor(.blue)
                            Text("Network Preferences")
                        }
                    }
                }

                // Connection Settings
                Section("CONNECTION") {
                    Toggle("Auto-connect on Launch", isOn: $autoConnect)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Position Update Interval")
                            Spacer()
                            Text("\(Int(sendPositionInterval))s")
                                .foregroundColor(.gray)
                        }
                        Slider(value: $sendPositionInterval, in: 5...120, step: 5)
                    }

                    Toggle("Enable Location Sharing", isOn: $enableLocationSharing)
                }

                // Map Overlay Settings
                Section("MAP OVERLAYS") {
                    // MGRS Grid Settings
                    Toggle("MGRS Grid Overlay", isOn: $mgrsGridEnabled)

                    if mgrsGridEnabled {
                        Picker("Grid Density", selection: $mgrsGridDensityString) {
                            Text("100km").tag("100km")
                            Text("10km").tag("10km")
                            Text("1km").tag("1km")
                        }

                        Toggle("Show Grid Labels", isOn: $showMGRSLabels)
                    }

                    // Coordinate Display Format
                    Picker("Coordinate Format", selection: $coordinateFormatString) {
                        Text("Decimal Degrees (DD)").tag("DD")
                        Text("Degrees Minutes (DM)").tag("DM")
                        Text("Degrees Minutes Seconds (DMS)").tag("DMS")
                        Text("MGRS").tag("MGRS")
                        Text("UTM").tag("UTM")
                        Text("British National Grid (BNG)").tag("BNG")
                    }

                    // Help text for coordinate formats
                    if coordinateFormatString == "BNG" {
                        Text("BNG is optimized for UK/Ireland (49°N-61°N, 9°W-2°E). Uses OSGB36 datum with grid squares like SU, TQ, NT.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }

                // Trail Settings
                Section("BREADCRUMB TRAILS") {
                    Toggle("Enable Trails", isOn: $breadcrumbTrailsEnabled)

                    if breadcrumbTrailsEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Max Trail Length")
                                Spacer()
                                Text("\(trailMaxLength) points")
                                    .foregroundColor(.gray)
                            }
                            Slider(value: Binding(
                                get: { Double(trailMaxLength) },
                                set: { trailMaxLength = Int($0) }
                            ), in: 10...500, step: 10)
                        }

                        Picker("Trail Color", selection: $trailColorName) {
                            Text("Cyan").tag("cyan")
                            Text("Green").tag("green")
                            Text("Orange").tag("orange")
                            Text("Red").tag("red")
                            Text("Blue").tag("blue")
                        }
                    }
                }

                // Display Settings
                Section("DISPLAY") {
                    Toggle("Dark Mode", isOn: $darkMode)
                    Toggle("Show Traffic Overlay", isOn: $showTrafficOverlay)
                    Toggle("Enable Haptic Feedback", isOn: $enableHaptics)
                }

                // Performance
                Section("PERFORMANCE") {
                    Toggle("Battery Optimization", isOn: $batteryOptimization)

                    HStack {
                        Text("Cache Size")
                        Spacer()
                        Text("127 MB")
                            .foregroundColor(.gray)
                    }

                    Button("Clear Cache") {
                        // Clear cache
                    }
                    .foregroundColor(.red)
                }

                // Data Management
                Section("DATA MANAGEMENT") {
                    Button("Export All Data") {
                        // Export
                    }

                    Button("Import Data Package") {
                        // Import
                    }

                    Button("Reset to Defaults") {
                        userCallsign = "ALPHA-1"
                        userName = "Operator"
                        autoConnect = true
                        sendPositionInterval = 30.0
                        enableHaptics = true
                        darkMode = true
                        showTrafficOverlay = false
                        enableLocationSharing = true
                        batteryOptimization = false
                        // Map overlay defaults
                        mgrsGridEnabled = false
                        mgrsGridDensityString = "1km"
                        showMGRSLabels = true
                        coordinateFormatString = "MGRS"
                        breadcrumbTrailsEnabled = true
                        trailMaxLength = 100
                        trailColorName = "cyan"
                    }
                    .foregroundColor(.orange)
                }

                // Danger Zone
                Section("DANGER ZONE") {
                    Button("Clear All Team Data") {
                        TeamService.shared.clearAllTeamData()
                    }
                    .foregroundColor(.red)

                    Button("Reset App") {
                        // Reset everything
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
