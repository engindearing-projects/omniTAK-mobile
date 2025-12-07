//
//  MeshtasticDevicePickerView.swift
//  OmniTAK Mobile
//
//  Device picker with connection type selection (Bluetooth or TCP)
//

import SwiftUI

struct MeshtasticDevicePickerView: View {
    @ObservedObject var manager: MeshtasticManager = MeshtasticManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var selectedConnectionType: ConnectionTab = .bluetooth

    enum ConnectionTab: String, CaseIterable {
        case bluetooth = "Bluetooth"
        case tcp = "TCP/WiFi"

        var icon: String {
            switch self {
            case .bluetooth: return "antenna.radiowaves.left.and.right"
            case .tcp: return "wifi"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Connection Type Picker
                Picker("Connection Type", selection: $selectedConnectionType) {
                    ForEach(ConnectionTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Content based on selection
                switch selectedConnectionType {
                case .bluetooth:
                    MeshtasticBLEContentView(manager: manager)
                case .tcp:
                    MeshtasticTCPContentView(manager: manager)
                }

                Spacer()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Connect Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Bluetooth Content View

private struct MeshtasticBLEContentView: View {
    @ObservedObject var manager: MeshtasticManager

    var body: some View {
        List {
            // Connected Device Section
            if manager.isConnected && manager.connectedDevice?.connectionType == .bluetooth {
                Section {
                    ConnectedDeviceRow(manager: manager)
                } header: {
                    Text("Connected")
                }
            }

            // Discovered Devices Section
            Section {
                if manager.isScanning {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Scanning for Meshtastic devices...")
                            .foregroundColor(.secondary)
                    }
                }

                if manager.discoveredBLEDevices.isEmpty && !manager.isScanning {
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("No Devices Found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Button("Start Scanning") {
                            manager.startBluetoothScan()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
                }

                ForEach(manager.discoveredBLEDevices, id: \.id) { device in
                    Button {
                        manager.connectBLE(device: device)
                    } label: {
                        BLEDeviceRowView(device: device, isConnected: isConnected(device))
                    }
                    .buttonStyle(.plain)
                    .disabled(isConnected(device))
                }
            } header: {
                HStack {
                    Text("Available Devices")
                    Spacer()
                    if manager.isScanning {
                        Button("Stop") { manager.stopBluetoothScan() }
                            .font(.caption)
                    } else {
                        Button("Scan") { manager.startBluetoothScan() }
                            .font(.caption)
                    }
                }
            } footer: {
                Text("Ensure Bluetooth is enabled on your Meshtastic device and it's in range.")
            }

            // Error Section
            if let error = manager.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .onAppear {
            if !manager.isConnected {
                manager.startBluetoothScan()
            }
        }
        .onDisappear {
            manager.stopBluetoothScan()
        }
    }

    private func isConnected(_ device: MeshtasticBLEDevice) -> Bool {
        manager.connectedDevice?.devicePath == device.id.uuidString
    }
}

// MARK: - TCP Content View

private struct MeshtasticTCPContentView: View {
    @ObservedObject var manager: MeshtasticManager
    @State private var showingAddSheet = false

    var body: some View {
        List {
            // Connected Device Section
            if manager.isConnected && manager.connectedDevice?.connectionType == .tcp {
                Section {
                    ConnectedDeviceRow(manager: manager)
                } header: {
                    Text("Connected")
                }
            }

            // Saved Hosts Section
            Section {
                ForEach(manager.savedHosts) { saved in
                    let isCurrentlyConnected = manager.isConnected &&
                        manager.connectedDevice?.devicePath == saved.host

                    if !isCurrentlyConnected {
                        Button {
                            manager.connectTCP(host: saved.host, port: saved.port)
                        } label: {
                            TCPHostRow(host: saved)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                manager.removeHost(saved.host, port: saved.port)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }

                if manager.savedHosts.isEmpty && !manager.isConnected {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("No Saved Devices")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Button("Add Device") {
                            showingAddSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
                }
            } header: {
                HStack {
                    Text("Saved Devices")
                    Spacer()
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            } footer: {
                Text("Enter the IP address of your Meshtastic device with TCP enabled (default port 4403).")
            }

            // Error Section
            if let error = manager.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
        }
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showingAddSheet) {
            AddTCPDeviceSheet(manager: manager)
        }
    }
}

// MARK: - Supporting Views

private struct ConnectedDeviceRow: View {
    @ObservedObject var manager: MeshtasticManager

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(manager.connectedDevice?.name ?? "Device")
                        .font(.headline)
                    if manager.myNodeNum > 0 {
                        Text("!\(String(format: "%08x", manager.myNodeNum))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if !manager.meshNodes.isEmpty {
                    Text("\(manager.meshNodes.count) nodes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Button(action: { manager.disconnect() }) {
                Text("Disconnect")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }
}

private struct BLEDeviceRowView: View {
    let device: MeshtasticBLEDevice
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: signalIcon)
                .foregroundColor(signalColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.body)
                Text("RSSI: \(device.rssi) dBm")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var signalIcon: String {
        device.rssi > -70 ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash"
    }

    private var signalColor: Color {
        if device.rssi > -60 { return .green }
        if device.rssi > -80 { return .orange }
        return .red
    }
}

private struct TCPHostRow: View {
    let host: MeshtasticManager.SavedHost

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi")
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(host.name.isEmpty ? host.host : host.name)
                    .font(.body)
                Text("\(host.host):\(host.port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
    }
}

private struct AddTCPDeviceSheet: View {
    @ObservedObject var manager: MeshtasticManager
    @Environment(\.dismiss) var dismiss

    @State private var host = ""
    @State private var port = "4403"
    @State private var name = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("IP Address (e.g. 192.168.1.100)", text: $host)
                        .keyboardType(.decimalPad)
                        .autocapitalization(.none)

                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("4403", text: $port)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    TextField("Name (optional)", text: $name)
                } header: {
                    Text("Device Address")
                }

                Section {
                    Button("Connect") {
                        let portNum = UInt16(port) ?? 4403
                        manager.connectTCP(host: host, port: portNum)
                        dismiss()
                    }
                    .disabled(host.isEmpty)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Add Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

struct MeshtasticDevicePickerView_Previews: PreviewProvider {
    static var previews: some View {
        MeshtasticDevicePickerView()
    }
}
