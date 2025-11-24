//
//  PluginsListView.swift
//  OmniTAKMobile
//
//  Plugin management interface
//

import SwiftUI

struct PluginsListView: View {
    @Environment(\.dismiss) var dismiss
    @State private var plugins: [PluginInfo] = [
        PluginInfo(name: "Video Streaming", version: "1.0.0", isEnabled: true, icon: "video.fill", description: "Stream and receive video feeds"),
        PluginInfo(name: "Offline Maps", version: "1.0.0", isEnabled: true, icon: "map.fill", description: "Download and use maps offline"),
        PluginInfo(name: "Data Packages", version: "1.0.0", isEnabled: true, icon: "shippingbox.fill", description: "Import and export data packages"),
        PluginInfo(name: "Drawing Tools", version: "1.0.0", isEnabled: true, icon: "pencil.tip", description: "Create tactical drawings on map"),
        PluginInfo(name: "Track Recording", version: "1.0.0", isEnabled: true, icon: "record.circle", description: "Record and playback GPS tracks"),
        PluginInfo(name: "Emergency SOS", version: "1.0.0", isEnabled: true, icon: "sos", description: "Emergency beacon and alerts"),
        PluginInfo(name: "Team Management", version: "1.0.0", isEnabled: true, icon: "person.3.fill", description: "Organize and manage teams"),
        PluginInfo(name: "Route Planning", version: "1.0.0", isEnabled: true, icon: "point.topleft.down.to.point.bottomright.curvepath.fill", description: "Plan and share routes"),
        PluginInfo(name: "Geofencing", version: "1.0.0", isEnabled: true, icon: "square.dashed", description: "Create geofence alerts"),
        PluginInfo(name: "Measurement Tools", version: "1.0.0", isEnabled: true, icon: "ruler", description: "Measure distances and areas"),
    ]

    var body: some View {
        NavigationView {
            List {
                Section("INSTALLED PLUGINS") {
                    ForEach($plugins) { $plugin in
                        PluginRow(plugin: $plugin)
                    }
                }

                Section("AVAILABLE PLUGINS") {
                    HStack {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bloodhound BFT")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Blue Force Tracking integration")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Text("Coming Soon")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                    .padding(.vertical, 4)

                    HStack {
                        Image(systemName: "cross.case.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("MEDEVAC Forms")
                                .font(.system(size: 15, weight: .semibold))
                            Text("9-Line MEDEVAC request forms")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Text("Coming Soon")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                    .padding(.vertical, 4)

                    HStack {
                        Image(systemName: "airplane")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                            .frame(width: 40)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("9-Line CAS Request")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Close Air Support request forms")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }

                        Spacer()

                        Text("Coming Soon")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .cornerRadius(4)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    HStack {
                        Spacer()
                        Text("Plugin API v1.0")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Plugins")
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

// MARK: - Plugin Info Model

struct PluginInfo: Identifiable {
    let id = UUID()
    let name: String
    let version: String
    var isEnabled: Bool
    let icon: String
    let description: String
}

// MARK: - Plugin Row

struct PluginRow: View {
    @Binding var plugin: PluginInfo

    var body: some View {
        HStack {
            Image(systemName: plugin.icon)
                .font(.system(size: 24))
                .foregroundColor(plugin.isEnabled ? .blue : .gray)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(plugin.name)
                        .font(.system(size: 15, weight: .semibold))
                    Text("v\(plugin.version)")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                Text(plugin.description)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }

            Spacer()

            Toggle("", isOn: $plugin.isEnabled)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}
