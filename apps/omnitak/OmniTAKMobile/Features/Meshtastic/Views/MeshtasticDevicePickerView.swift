//
//  MeshtasticDevicePickerView.swift
//  OmniTAK Mobile
//
//  Device picker for Meshtastic - supports Bluetooth and TCP connections
//

import SwiftUI
import CoreBluetooth

struct MeshtasticDevicePickerView: View {
    @ObservedObject var manager: MeshtasticManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedTab: ConnectionTab = .bluetooth

    enum ConnectionTab: String, CaseIterable {
        case bluetooth = "Bluetooth"
        case tcp = "TCP/IP"

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
                Picker("Connection Type", selection: $selectedTab) {
                    ForEach(ConnectionTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Tab Content
                switch selectedTab {
                case .bluetooth:
                    BluetoothConnectionView(manager: manager, dismiss: dismiss)
                case .tcp:
                    TCPConnectionView(manager: manager, dismiss: dismiss)
                }
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

// MARK: - Bluetooth Connection View

private struct BluetoothConnectionView: View {
    @ObservedObject var manager: MeshtasticManager
    let dismiss: DismissAction

    var body: some View {
        VStack(spacing: 0) {
            // Bluetooth Status Banner
            bluetoothStatusBanner

            // Connected Device Card
            if manager.isConnected, let device = manager.connectedDevice, device.connectionType == .bluetooth {
                connectedDeviceCard
                    .padding()
            }

            // Device List
            List {
                // Scanning Section
                Section {
                    if manager.isScanning {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text("Scanning for Meshtastic devices...")
                                .foregroundColor(.secondary)
                        }
                    } else if manager.discoveredBLEDevices.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text("No Devices Found")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Make sure your Meshtastic device is powered on and in range")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Button(action: { manager.startBLEScanning() }) {
                                Label("Start Scanning", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .listRowBackground(Color.clear)
                    }

                    // Discovered Devices
                    ForEach(manager.discoveredBLEDevices) { device in
                        Button {
                            manager.stopBLEScanning()
                            manager.connectBLE(device: device)
                        } label: {
                            BLEDeviceRow(device: device)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    HStack {
                        Text("Nearby Devices")
                        Spacer()
                        if manager.isScanning {
                            Button("Stop") {
                                manager.stopBLEScanning()
                            }
                            .font(.caption)
                        } else {
                            Button("Scan") {
                                manager.startBLEScanning()
                            }
                            .font(.caption)
                        }
                    }
                } footer: {
                    Text("Ensure Bluetooth is enabled and your Meshtastic device is powered on. The device will appear when found.")
                }
            }
            .listStyle(.insetGrouped)
        }
        .onAppear {
            // Auto-start scanning if Bluetooth is available
            if manager.bluetoothState == .poweredOn && !manager.isConnected {
                manager.startBLEScanning()
            }
        }
        .onDisappear {
            manager.stopBLEScanning()
        }
    }

    private var bluetoothStatusBanner: some View {
        Group {
            switch manager.bluetoothState {
            case .poweredOff:
                HStack {
                    Image(systemName: "bluetooth.slash")
                    Text("Bluetooth is turned off")
                    Spacer()
                    Text("Enable in Settings")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding()
                .background(Color.orange.opacity(0.15))
                .foregroundColor(.orange)

            case .unauthorized:
                HStack {
                    Image(systemName: "lock.fill")
                    Text("Bluetooth permission required")
                    Spacer()
                }
                .padding()
                .background(Color.red.opacity(0.15))
                .foregroundColor(.red)

            case .unsupported:
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("Bluetooth not supported")
                    Spacer()
                }
                .padding()
                .background(Color.red.opacity(0.15))
                .foregroundColor(.red)

            default:
                EmptyView()
            }
        }
    }

    private var connectedDeviceCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(manager.connectedDevice?.name ?? "Meshtastic Device")
                        .font(.headline)

                    if manager.myNodeNum > 0 {
                        Text("!\(String(format: "%08x", manager.myNodeNum))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if !manager.meshNodes.isEmpty {
                    VStack(alignment: .trailing) {
                        Text("\(manager.meshNodes.count)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("nodes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Button(action: { manager.disconnect() }) {
                Text("Disconnect")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - BLE Device Row

private struct BLEDeviceRow: View {
    let device: DiscoveredBLEDevice

    var body: some View {
        HStack(spacing: 12) {
            // Signal strength indicator
            Image(systemName: signalIcon)
                .font(.system(size: 20))
                .foregroundColor(signalColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.body)

                HStack(spacing: 8) {
                    Text("RSSI: \(device.rssi) dBm")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(device.signalStrength)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(signalColor.opacity(0.15))
                        .foregroundColor(signalColor)
                        .cornerRadius(4)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
    }

    private var signalIcon: String {
        switch device.rssi {
        case -50...0: return "antenna.radiowaves.left.and.right.circle.fill"
        case -70..<(-50): return "antenna.radiowaves.left.and.right.circle"
        case -90..<(-70): return "antenna.radiowaves.left.and.right"
        default: return "wifi.exclamationmark"
        }
    }

    private var signalColor: Color {
        switch device.rssi {
        case -50...0: return .green
        case -70..<(-50): return .blue
        case -90..<(-70): return .orange
        default: return .red
        }
    }
}

// MARK: - TCP Connection View

private struct TCPConnectionView: View {
    @ObservedObject var manager: MeshtasticManager
    let dismiss: DismissAction

    @State private var hostAddress: String = ""
    @State private var portString: String = "4403"
    @State private var isConnecting: Bool = false
    @State private var showingAddSheet: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Connected Device Card
            if manager.isConnected, let device = manager.connectedDevice, device.connectionType == .tcp {
                connectedDeviceCard
                    .padding()
            }

            // Device List
            List {
                Section {
                    // Show connected device first
                    if manager.isConnected,
                       let device = manager.connectedDevice,
                       device.connectionType == .tcp {
                        DeviceListRow(
                            icon: "wifi",
                            iconColor: .green,
                            title: device.name,
                            subtitle: device.devicePath,
                            isConnected: true
                        )
                    }

                    // Show saved hosts
                    ForEach(manager.savedHosts) { saved in
                        let isCurrentlyConnected = manager.isConnected &&
                            manager.connectedDevice?.devicePath == saved.host &&
                            manager.connectedDevice?.connectionType == .tcp

                        if !isCurrentlyConnected {
                            Button {
                                connectTo(host: saved.host, port: saved.port, name: saved.name)
                            } label: {
                                DeviceListRow(
                                    icon: "wifi",
                                    iconColor: .blue,
                                    title: saved.name.isEmpty ? saved.host : saved.name,
                                    subtitle: "\(saved.host):\(saved.port)",
                                    isConnected: false
                                )
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

                    // Empty state
                    if manager.savedHosts.isEmpty && !manager.isConnected {
                        VStack(spacing: 12) {
                            Image(systemName: "wifi")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text("No Saved Devices")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("Tap + to add a Meshtastic device")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Button(action: { showingAddSheet = true }) {
                                Label("Add Device", systemImage: "plus")
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
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
                    Text("Enter the IP address of your Meshtastic device with TCP enabled. Default port is 4403.")
                }
            }
            .listStyle(.insetGrouped)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTCPDeviceSheet(
                hostAddress: $hostAddress,
                portString: $portString,
                isConnecting: $isConnecting,
                onConnect: { host, port, name in
                    connectTo(host: host, port: port, name: name)
                    showingAddSheet = false
                }
            )
        }
    }

    private var connectedDeviceCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(manager.connectedDevice?.name ?? "Meshtastic Device")
                        .font(.headline)

                    if manager.myNodeNum > 0 {
                        Text("!\(String(format: "%08x", manager.myNodeNum))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if !manager.meshNodes.isEmpty {
                    VStack(alignment: .trailing) {
                        Text("\(manager.meshNodes.count)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("nodes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Button(action: { manager.disconnect() }) {
                Text("Disconnect")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.red)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func connectTo(host: String, port: UInt16, name: String) {
        isConnecting = true

        let device = MeshtasticDevice(
            id: "tcp-\(host)-\(port)",
            name: name.isEmpty ? host : name,
            connectionType: .tcp,
            devicePath: host,
            isConnected: false,
            nodeId: "\(port)"
        )

        manager.connect(to: device)
        manager.saveHost(host, port: port, name: name)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isConnecting = false
        }
    }
}

// MARK: - Device List Row

private struct DeviceListRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Add TCP Device Sheet

private struct AddTCPDeviceSheet: View {
    @Environment(\.dismiss) var dismiss

    @Binding var hostAddress: String
    @Binding var portString: String
    @Binding var isConnecting: Bool
    let onConnect: (String, UInt16, String) -> Void

    @State private var deviceName: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("IP Address (e.g. 192.168.1.100)", text: $hostAddress)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.decimalPad)

                    HStack {
                        Text("Port")
                        Spacer()
                        TextField("4403", text: $portString)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    TextField("Name (optional)", text: $deviceName)
                } header: {
                    Text("Device Address")
                } footer: {
                    Text("Enter the local IP address of your Meshtastic device. Ensure TCP is enabled on port 4403.")
                }

                Section {
                    Button(action: {
                        let port = UInt16(portString) ?? 4403
                        onConnect(hostAddress, port, deviceName)
                    }) {
                        HStack {
                            Spacer()
                            if isConnecting {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isConnecting ? "Connecting..." : "Connect")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(hostAddress.isEmpty || isConnecting)
                }
            }
            .navigationTitle("Add TCP Device")
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
        MeshtasticDevicePickerView(manager: MeshtasticManager())
    }
}
