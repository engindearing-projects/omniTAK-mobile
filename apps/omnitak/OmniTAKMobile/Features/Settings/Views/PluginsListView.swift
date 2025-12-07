//
//  PluginsListView.swift
//  OmniTAKMobile
//
//  Plugin management interface
//

import SwiftUI

struct PluginsListView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var pluginManager = PluginSettingsManager.shared

    var body: some View {
        NavigationView {
            List {
                Section("FEATURES") {
                    ForEach(PluginID.allCases, id: \.self) { plugin in
                        PluginRow(plugin: plugin, pluginManager: pluginManager)
                    }
                }

                Section {
                    Button(action: {
                        pluginManager.resetAll()
                    }) {
                        HStack {
                            Spacer()
                            Text("Enable All Features")
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                }

                Section {
                    HStack {
                        Spacer()
                        Text("OmniTAK Mobile v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0")")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Features")
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

// MARK: - Plugin Row

struct PluginRow: View {
    let plugin: PluginID
    @ObservedObject var pluginManager: PluginSettingsManager

    var body: some View {
        HStack {
            Image(systemName: plugin.icon)
                .font(.system(size: 24))
                .foregroundColor(pluginManager.isEnabled(plugin) ? .blue : .gray)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(plugin.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(pluginManager.isEnabled(plugin) ? .primary : .gray)
                    Text("v1.0.0")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                Text(plugin.description)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }

            Spacer()

            Toggle("", isOn: pluginManager.binding(for: plugin))
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}
