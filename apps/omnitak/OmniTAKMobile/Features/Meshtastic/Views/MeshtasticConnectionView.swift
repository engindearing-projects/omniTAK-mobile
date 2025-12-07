//
//  MeshtasticConnectionView.swift
//  OmniTAK Mobile
//
//  Meshtastic device connection and mesh network view
//

import SwiftUI

struct MeshtasticConnectionView: View {
    @ObservedObject private var manager = MeshtasticManager.shared
    @State private var showingDevicePicker = false
    @State private var showingMeshTopology = false
    @State private var showingNodeMap = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Connection Status Card
                    connectionStatusCard

                    if manager.isConnected {
                        // Mini Map Preview (if nodes have positions)
                        if !manager.nodesWithPositions.isEmpty {
                            miniMapCard
                        }

                        // Device Info Card
                        deviceInfoCard

                        // Mesh Nodes List
                        if !manager.meshNodes.isEmpty {
                            meshNodesSection
                        }
                    } else {
                        // No Connection - Show Setup
                        setupGuideCard
                    }
                }
                .padding()
            }
            .navigationTitle("Meshtastic")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if manager.isConnected {
                        Menu {
                            Button(action: { showingMeshTopology = true }) {
                                Label("View Nodes", systemImage: "circle.hexagongrid")
                            }

                            if !manager.nodesWithPositions.isEmpty {
                                Button(action: { showingNodeMap = true }) {
                                    Label("Node Map", systemImage: "map")
                                }

                                Button(action: { manager.publishMeshNodesToMap() }) {
                                    Label("Publish to TAK Map", systemImage: "square.and.arrow.up")
                                }
                            }

                            Divider()

                            Toggle(isOn: $manager.autoMapUpdateEnabled) {
                                Label("Auto Map Updates", systemImage: "arrow.triangle.2.circlepath")
                            }

                            Divider()

                            Button(role: .destructive, action: { manager.disconnect() }) {
                                Label("Disconnect", systemImage: "xmark.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingDevicePicker) {
                MeshtasticDevicePickerView(manager: manager)
            }
            .sheet(isPresented: $showingMeshTopology) {
                MeshTopologyView()
            }
            .sheet(isPresented: $showingNodeMap) {
                NavigationView {
                    MeshNodeMapView(manager: manager)
                        .navigationTitle("Node Map")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showingNodeMap = false }
                            }
                        }
                }
            }
        }
    }

    // MARK: - Mini Map Card

    private var miniMapCard: some View {
        VStack(spacing: 0) {
            // Map header
            HStack {
                Label("\(manager.nodesWithPositions.count) nodes with position", systemImage: "map")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Full Map") {
                    showingNodeMap = true
                }
                .font(.caption)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Mini map
            MeshNodeMapView(manager: manager)
                .frame(height: 200)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom, 12)
                .onTapGesture {
                    showingNodeMap = true
                }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    // MARK: - Connection Status Card

    private var connectionStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: statusIcon)
                    .font(.system(size: 40))
                    .foregroundColor(statusColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.headline)

                    if manager.isConnected, let device = manager.connectedDevice {
                        Text("\(device.devicePath):\(device.nodeId ?? "4403")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if !manager.isConnected && manager.connectionState == "Disconnected" {
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
                    Spacer()
                    Button("Dismiss") {
                        manager.lastError = nil
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
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

    private var statusIcon: String {
        switch manager.connectionState {
        case "Connected":
            return "antenna.radiowaves.left.and.right.circle.fill"
        case "Connecting":
            return "antenna.radiowaves.left.and.right"
        default:
            return "antenna.radiowaves.left.and.right.slash"
        }
    }

    private var statusColor: Color {
        switch manager.connectionState {
        case "Connected":
            return .green
        case "Connecting":
            return .orange
        default:
            return .gray
        }
    }

    private var statusTitle: String {
        switch manager.connectionState {
        case "Connected":
            return "Connected"
        case "Connecting":
            return "Connecting..."
        default:
            return "Not Connected"
        }
    }

    // MARK: - Device Info Card

    private var deviceInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Device Info", systemImage: "info.circle")
                    .font(.headline)

                Spacer()
            }

            Divider()

            if manager.myNodeNum > 0 {
                HStack {
                    Text("Node ID")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("!\(String(format: "%08x", manager.myNodeNum))")
                        .font(.system(.body, design: .monospaced))
                }
            }

            if !manager.firmwareVersion.isEmpty {
                HStack {
                    Text("Firmware")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(manager.firmwareVersion)
                }
            }

            HStack {
                Text("Mesh Nodes")
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(manager.meshNodes.count)")
                    .fontWeight(.semibold)
            }

            if !manager.meshNodes.isEmpty {
                Button(action: { showingMeshTopology = true }) {
                    HStack {
                        Image(systemName: "circle.hexagongrid")
                        Text("View All Nodes")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }

    // MARK: - Mesh Nodes Section

    private var meshNodesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nearby Nodes")
                    .font(.headline)

                Spacer()

                Text("\(manager.meshNodes.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }

            ForEach(manager.meshNodes.prefix(5)) { node in
                MeshNodeRow(node: node)
            }

            if manager.meshNodes.count > 5 {
                Button(action: { showingMeshTopology = true }) {
                    Text("View all \(manager.meshNodes.count) nodes...")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
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

            Text("Connect to a Meshtastic device to enable long-range, off-grid TAK communications over LoRa mesh networks.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 16) {
                Text("Connection Options:")
                    .font(.headline)

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bluetooth")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Direct BLE connection to your Meshtastic device")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "wifi")
                        .font(.title2)
                        .foregroundColor(.green)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("TCP/WiFi")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Network connection via IP address (port 4403)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)

            Button(action: { showingDevicePicker = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Connect to Device")
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
}

// MARK: - Supporting Views

struct MeshNodeRow: View {
    let node: MeshNode

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(node.longName)
                    .font(.headline)

                HStack(spacing: 12) {
                    Text(node.shortName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)

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

            Text(timeAgo(from: node.lastHeard))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
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
