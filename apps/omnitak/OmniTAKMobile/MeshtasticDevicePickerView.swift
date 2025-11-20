//
//  MeshtasticDevicePickerView.swift
//  OmniTAK Mobile
//
//  Beautiful device discovery and selection UI
//

import SwiftUI

struct MeshtasticDevicePickerView: View {
    @ObservedObject var manager: MeshtasticManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedType: MeshtasticConnectionType = .serial
    @State private var customDevicePath = ""
    @State private var customPort = "4403"
    @State private var customDeviceName = ""
    @State private var showingManualEntry = false

    var body: some View {
        NavigationView {
            List {
                Section {
                    Picker("Connection Type", selection: $selectedType) {
                        ForEach([MeshtasticConnectionType.serial, .bluetooth, .tcp], id: \.self) { type in
                            Label(type.displayName, systemImage: type.iconName)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Connection Type")
                }

                if manager.isScanning {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Scanning for devices...")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section {
                    ForEach(filteredDevices) { device in
                        DeviceRow(device: device) {
                            manager.connect(to: device)
                            dismiss()
                        }
                    }

                    if filteredDevices.isEmpty && !manager.isScanning {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)

                            Text("No devices found")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            Text("Make sure your Meshtastic device is connected and powered on.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Button(action: { showingManualEntry = true }) {
                                Label("Enter Manually", systemImage: "keyboard")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                } header: {
                    HStack {
                        Text("Available Devices")
                        Spacer()
                        Button(action: { manager.scanForDevices() }) {
                            Label("Scan", systemImage: "arrow.clockwise")
                                .font(.caption)
                        }
                    }
                }

                Section {
                    connectionGuide
                } header: {
                    Text("Connection Guide")
                }
            }
            .navigationTitle("Connect Meshtastic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingManualEntry = true }) {
                        Image(systemName: "keyboard")
                    }
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                ManualEntryView(
                    connectionType: selectedType,
                    devicePath: $customDevicePath,
                    port: $customPort,
                    deviceName: $customDeviceName
                ) {
                    // Connect with manual entry
                    let device = MeshtasticDevice(
                        id: UUID().uuidString,
                        name: customDeviceName.isEmpty ? "Custom Device" : customDeviceName,
                        connectionType: selectedType,
                        devicePath: customDevicePath,
                        isConnected: false
                    )
                    manager.connect(to: device)
                    dismiss()
                }
            }
            .onAppear {
                manager.scanForDevices()
            }
        }
    }

    private var filteredDevices: [MeshtasticDevice] {
        manager.devices.filter { $0.connectionType == selectedType }
    }

    private var connectionGuide: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch selectedType {
            case .serial:
                GuideItem(icon: "cable.connector", text: "Connect Meshtastic device via USB cable")
                GuideItem(icon: "checkmark.circle", text: "Device will appear as /dev/ttyUSB* or COM*")
                GuideItem(icon: "info.circle", text: "Default baud rate: 38400")

            case .bluetooth:
                GuideItem(icon: "antenna.radiowaves.left.and.right", text: "Enable Bluetooth on your device")
                GuideItem(icon: "keyboard", text: "Pair Meshtastic device in Settings")
                GuideItem(icon: "checkmark.circle", text: "Return here to connect")

            case .tcp:
                GuideItem(icon: "network", text: "Ensure Meshtastic has WiFi/Ethernet")
                GuideItem(icon: "server.rack", text: "Default port: 4403")
                GuideItem(icon: "wifi", text: "Device must be on same network")
            }
        }
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: MeshtasticDevice
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: device.connectionType.iconName)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.headline)

                    Text(device.devicePath)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let lastSeen = device.lastSeen {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("Last seen \(timeAgo(from: lastSeen))")
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if device.isConnected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if let signalStrength = device.signalStrength {
                    SignalStrengthIndicator(rssi: signalStrength)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }
}

// MARK: - Signal Strength Indicator

struct SignalStrengthIndicator: View {
    let rssi: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: index))
                    .frame(width: 4, height: CGFloat(6 + index * 3))
            }
        }
    }

    private func barColor(for index: Int) -> Color {
        let quality = SignalQuality.from(rssi: rssi)
        let requiredBars: Int

        switch quality {
        case .excellent: requiredBars = 4
        case .good: requiredBars = 3
        case .fair: requiredBars = 2
        case .poor: requiredBars = 1
        case .none: requiredBars = 0
        }

        return index < requiredBars ? .green : .gray.opacity(0.3)
    }
}

// MARK: - Manual Entry View

struct ManualEntryView: View {
    @Environment(\.dismiss) var dismiss

    let connectionType: MeshtasticConnectionType
    @Binding var devicePath: String
    @Binding var port: String
    @Binding var deviceName: String
    let onConnect: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Device Name (Optional)", text: $deviceName)
                } header: {
                    Text("Device Info")
                }

                Section {
                    switch connectionType {
                    case .serial:
                        TextField("Device Path", text: $devicePath)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)

                        Text("Examples: /dev/ttyUSB0, COM3")
                            .font(.caption)
                            .foregroundColor(.secondary)

                    case .bluetooth:
                        TextField("Bluetooth Address", text: $devicePath)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)

                        Text("Format: 00:11:22:33:44:55")
                            .font(.caption)
                            .foregroundColor(.secondary)

                    case .tcp:
                        TextField("Hostname or IP", text: $devicePath)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)

                        TextField("Port", text: $port)
                            .keyboardType(.numberPad)

                        Text("Default port: 4403")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Connection Details")
                }

                Section {
                    Button(action: {
                        onConnect()
                        dismiss()
                    }) {
                        Text("Connect")
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                    }
                    .disabled(devicePath.isEmpty)
                }
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Guide Item

struct GuideItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

struct MeshtasticDevicePickerView_Previews: PreviewProvider {
    static var previews: some View {
        MeshtasticDevicePickerView(manager: MeshtasticManager())
    }
}
