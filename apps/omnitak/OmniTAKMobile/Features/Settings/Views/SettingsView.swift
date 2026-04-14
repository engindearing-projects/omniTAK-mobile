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
    @AppStorage("unitSystem") private var unitSystemString = "Metric"
    @State private var cacheSizeText: String = "—"
    @State private var showCacheCleared = false

    // Map Overlay Settings
    @AppStorage("mgrsGridEnabled") private var mgrsGridEnabled = false
    @AppStorage("mgrsGridDensity") private var mgrsGridDensityString = "1km"
    @AppStorage("showMGRSLabels") private var showMGRSLabels = true
    @AppStorage("coordinateDisplayFormat") private var coordinateFormatString = "MGRS"
    @AppStorage("breadcrumbTrailsEnabled") private var breadcrumbTrailsEnabled = true
    @AppStorage("trailMaxLength") private var trailMaxLength = 100
    @AppStorage("trailColorName") private var trailColorName = "cyan"

    @State private var showServersSheet = false

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
                            .onChange(of: userCallsign) { newValue in
                                // Sync callsign to all services that send CoT
                                PositionBroadcastService.shared.userCallsign = newValue
                                ChatManager.shared.currentUserCallsign = newValue
                            }
                    }

                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Name", text: $userName)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.blue)
                    }
                }

                // Servers (Streamlined)
                Section("SERVERS") {
                    Button(action: { showServersSheet = true }) {
                        HStack {
                            // Status indicator
                            Circle()
                                .fill(TAKService.shared.isConnected ? Color(hex: "#00FF00") : Color(hex: "#FF4444"))
                                .frame(width: 10, height: 10)

                            Text("Manage Servers")
                                .foregroundColor(.primary)

                            Spacer()

                            // Server count/status
                            Text(TAKService.shared.isConnected ? "Connected" : "\(ServerManager.shared.servers.count) servers")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                }

                // Navigation Settings
                Section("NAVIGATION") {
                    NavigationLink(destination: NavigationSettingsView()) {
                        HStack {
                            Image(systemName: "location.north.line.fill")
                                .foregroundColor(Color(hex: "#FFFC00"))
                                .frame(width: 24)
                            Text("Route Navigation")
                            Spacer()
                            Text("ATAK-Style")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
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
                    // Unit System Picker
                    Picker("Unit System", selection: $unitSystemString) {
                        Text("Metric (km, m, km/h)").tag("Metric")
                        Text("Imperial (mi, ft, mph)").tag("Imperial")
                    }
                }

                // Performance
                Section("PERFORMANCE") {
                    HStack {
                        Text("Cache Size")
                        Spacer()
                        Text(cacheSizeText)
                            .foregroundColor(.gray)
                    }

                    Button("Clear Cache") {
                        clearCache()
                    }
                    .foregroundColor(.red)
                }

                // Data Management
                Section("DATA MANAGEMENT") {
                    NavigationLink(destination: DataPackageImportView()) {
                        Text("Import Data Package")
                    }

                    Button("Reset to Defaults") {
                        userCallsign = "ALPHA-1"
                        userName = "Operator"
                        unitSystemString = "Metric"
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
            .sheet(isPresented: $showServersSheet) {
                ServersView()
            }
            .alert("Cache Cleared", isPresented: $showCacheCleared) {
                Button("OK", role: .cancel) {}
            }
            .onAppear { refreshCacheSize() }
        }
    }

    private func refreshCacheSize() {
        let urlBytes = URLCache.shared.currentDiskUsage + URLCache.shared.currentMemoryUsage
        let tileBytes = tileCacheSizeBytes()
        let total = Int64(urlBytes) + tileBytes
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB, .useKB]
        formatter.countStyle = .file
        cacheSizeText = formatter.string(fromByteCount: total)
    }

    private func tileCacheSizeBytes() -> Int64 {
        guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return 0
        }
        let tileDir = cachesDir.appendingPathComponent("tiles", isDirectory: true)
        guard let enumerator = FileManager.default.enumerator(at: tileDir, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        if let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let tileDir = cachesDir.appendingPathComponent("tiles", isDirectory: true)
            try? FileManager.default.removeItem(at: tileDir)
        }
        refreshCacheSize()
        showCacheCleared = true
    }
}
