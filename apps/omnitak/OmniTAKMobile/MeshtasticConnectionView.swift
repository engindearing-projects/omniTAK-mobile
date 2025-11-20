//
//  MeshtasticConnectionView.swift
//  OmniTAK Mobile
//
//  Beautiful UI for Meshtastic device connection and management
//

import SwiftUI
import MapKit

struct MeshtasticConnectionView: View {
    @StateObject private var manager = MeshtasticManager()
    @State private var showingDevicePicker = false
    @State private var showingMeshTopology = false
    @State private var showingSignalChart = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection Status Card
                    connectionStatusCard

                    if manager.isConnected {
                        // Signal Quality Card
                        signalQualityCard

                        // Mesh Network Stats
                        meshStatsCard

                        // Quick Actions
                        quickActionsSection

                        // Mesh Nodes List
                        meshNodesSection
                    } else {
                        // No Connection - Show Setup
                        setupGuideCard
                    }
                }
                .padding()
            }
            .navigationTitle("Meshtastic Mesh")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingMeshTopology = true }) {
                            Label("Mesh Topology", systemImage: "circle.hexagongrid")
                        }

                        Button(action: { showingSignalChart = true }) {
                            Label("Signal History", systemImage: "waveform.path.ecg")
                        }

                        Divider()

                        if manager.isConnected {
                            Button(role: .destructive, action: { manager.disconnect() }) {
                                Label("Disconnect", systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingDevicePicker) {
                MeshtasticDevicePickerView(manager: manager)
            }
            .sheet(isPresented: $showingMeshTopology) {
                MeshTopologyView(manager: manager)
            }
            .sheet(isPresented: $showingSignalChart) {
                SignalHistoryView(manager: manager)
            }
        }
    }

    // MARK: - Connection Status Card

    private var connectionStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: manager.isConnected ? "antenna.radiowaves.left.and.right.circle.fill" : "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 40))
                    .foregroundColor(manager.isConnected ? .green : .gray)

                VStack(alignment: .leading, spacing: 4) {
                    Text(manager.connectionStatus)
                        .font(.headline)

                    if let device = manager.connectedDevice {
                        Text(device.connectionType.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if !manager.isConnected {
                    Button(action: { showingDevicePicker = true }) {
                        Text("Connect")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
            }

            if let error = manager.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    // MARK: - Signal Quality Card

    private var signalQualityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Signal Quality", systemImage: manager.signalQuality.iconName)
                    .font(.headline)

                Spacer()

                Text(manager.signalQuality.displayText)
                    .font(.subheadline)
                    .foregroundColor(Color(manager.signalQuality.color))
            }

            if let device = manager.connectedDevice,
               let rssi = device.signalStrength {
                HStack {
                    Text("RSSI: \(rssi) dBm")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if let snr = device.snr {
                        Text("SNR: \(String(format: "%.1f", snr)) dB")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Signal strength bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)

                        Rectangle()
                            .fill(Color(manager.signalQuality.color))
                            .frame(width: geometry.size.width * signalStrengthPercentage(rssi: rssi), height: 8)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    // MARK: - Mesh Stats Card

    private var meshStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Mesh Network", systemImage: "network")
                    .font(.headline)

                Spacer()

                Circle()
                    .fill(Color(manager.networkHealth.color))
                    .frame(width: 12, height: 12)

                Text(manager.networkHealth.displayText)
                    .font(.caption)
                    .foregroundColor(Color(manager.networkHealth.color))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatItem(title: "Connected Nodes", value: "\(manager.networkStats.connectedNodes)/\(manager.networkStats.totalNodes)", icon: "circle.hexagongrid.fill")

                StatItem(title: "Avg Hops", value: String(format: "%.1f", manager.networkStats.averageHops), icon: "arrow.triangle.branch")

                StatItem(title: "Success Rate", value: String(format: "%.0f%%", manager.networkStats.packetSuccessRate * 100), icon: "checkmark.circle.fill")

                StatItem(title: "Utilization", value: String(format: "%.0f%%", manager.networkStats.networkUtilization * 100), icon: "chart.bar.fill")
            }

            Button(action: { showingMeshTopology = true }) {
                HStack {
                    Image(systemName: "map")
                    Text("View Mesh Topology")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                QuickActionButton(title: "Send PLI", icon: "location.fill") {
                    // Send position update
                }

                QuickActionButton(title: "Send Chat", icon: "message.fill") {
                    // Open chat
                }

                QuickActionButton(title: "Signal Chart", icon: "waveform.path.ecg") {
                    showingSignalChart = true
                }

                QuickActionButton(title: "Settings", icon: "gearshape.fill") {
                    // Open settings
                }
            }
        }
    }

    // MARK: - Mesh Nodes Section

    private var meshNodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nearby Nodes")
                    .font(.headline)

                Spacer()

                Text("\(manager.meshNodes.count) nodes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(manager.meshNodes) { node in
                MeshNodeRow(node: node)
            }
        }
    }

    // MARK: - Setup Guide Card

    private var setupGuideCard: some View {
        VStack(spacing: 20) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Off-Grid Mesh Network")
                .font(.title2)
                .bold()

            Text("Connect your Meshtastic device to enable long-range, off-grid TAK communications over LoRa mesh networks.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                SetupStep(number: 1, text: "Connect Meshtastic device via USB, Bluetooth, or TCP/IP")
                SetupStep(number: 2, text: "Select your device from the list")
                SetupStep(number: 3, text: "Start sharing TAK data through the mesh")
            }
            .padding()

            Button(action: { showingDevicePicker = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Connect Meshtastic Device")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    // MARK: - Helper Functions

    private func signalStrengthPercentage(rssi: Int) -> CGFloat {
        // Convert RSSI (-100 to -40) to percentage (0 to 1)
        let normalized = max(0, min(100, rssi + 100))
        return CGFloat(normalized) / 60.0
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.title3)
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

struct MeshNodeRow: View {
    let node: MeshNode

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(node.longName)
                    .font(.headline)

                HStack(spacing: 12) {
                    if let hopDistance = node.hopDistance {
                        Label("\(hopDistance) hops", systemImage: "arrow.triangle.branch")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let snr = node.snr {
                        Label(String(format: "%.1f dB", snr), systemImage: "waveform")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if let battery = node.batteryLevel {
                HStack(spacing: 4) {
                    Image(systemName: batteryIcon(level: battery))
                        .foregroundColor(batteryColor(level: battery))
                    Text("\(battery)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let lastHeard = node.lastHeard {
                Text(timeAgo(from: lastHeard))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func batteryIcon(level: Int) -> String {
        if level > 75 { return "battery.100" }
        if level > 50 { return "battery.75" }
        if level > 25 { return "battery.50" }
        return "battery.25"
    }

    private func batteryColor(level: Int) -> Color {
        if level > 50 { return .green }
        if level > 25 { return .orange }
        return .red
    }

    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }
}

struct SetupStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.blue)
                .clipShape(Circle())

            Text(text)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

// MARK: - Preview

struct MeshtasticConnectionView_Previews: PreviewProvider {
    static var previews: some View {
        MeshtasticConnectionView()
    }
}
