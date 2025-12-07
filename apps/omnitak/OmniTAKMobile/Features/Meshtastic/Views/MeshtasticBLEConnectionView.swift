//
//  MeshtasticBLEConnectionView.swift
//  OmniTAK Mobile
//
//  Bluetooth Low Energy connection view for Meshtastic devices
//

import SwiftUI

struct MeshtasticBLEConnectionView: View {
    @ObservedObject var manager: MeshtasticManager = MeshtasticManager.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Connected Device Card (if connected via BLE)
                if manager.isConnected && manager.connectedDevice?.connectionType == .bluetooth {
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
                        } else if manager.discoveredBLEDevices.isEmpty && !manager.isConnected {
                            VStack(spacing: 12) {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 36))
                                    .foregroundColor(.secondary)
                                Text("No Devices Found")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("Tap 'Scan' to search for nearby Meshtastic devices")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .listRowBackground(Color.clear)
                        }

                        // Discovered devices
                        ForEach(manager.discoveredBLEDevices, id: \.id) { device in
                            Button {
                                manager.connectBLE(device: device)
                            } label: {
                                BLEDeviceRow(device: device, isConnected: isDeviceConnected(device))
                            }
                            .buttonStyle(.plain)
                            .disabled(isDeviceConnected(device))
                        }
                    } header: {
                        HStack {
                            Text("Bluetooth Devices")
                            Spacer()
                            if !manager.isScanning {
                                Button("Scan") {
                                    manager.startBluetoothScan()
                                }
                                .font(.caption)
                            } else {
                                Button("Stop") {
                                    manager.stopBluetoothScan()
                                }
                                .font(.caption)
                            }
                        }
                    } footer: {
                        Text("Ensure your Meshtastic device has Bluetooth enabled and is in range.")
                    }

                    // Connection Status
                    if let error = manager.lastError {
                        Section {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Bluetooth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if manager.isScanning {
                        ProgressView()
                    } else {
                        Button(action: { manager.startBluetoothScan() }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .onAppear {
                // Auto-start scanning when view appears
                if !manager.isConnected {
                    manager.startBluetoothScan()
                }
            }
            .onDisappear {
                manager.stopBluetoothScan()
            }
        }
    }

    // MARK: - Connected Device Card

    private var connectedDeviceCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Status indicator
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

                // Mesh info
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

            // Disconnect button
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

    // MARK: - Helpers

    private func isDeviceConnected(_ device: MeshtasticBLEDevice) -> Bool {
        guard let connected = manager.connectedDevice else { return false }
        return connected.devicePath == device.id.uuidString
    }
}

// MARK: - BLE Device Row

private struct BLEDeviceRow: View {
    let device: MeshtasticBLEDevice
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Signal strength indicator
            signalIcon
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

                    Text(timeAgo(from: device.lastSeen))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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

    private var signalIcon: Image {
        if device.rssi > -60 {
            return Image(systemName: "antenna.radiowaves.left.and.right")
        } else if device.rssi > -80 {
            return Image(systemName: "antenna.radiowaves.left.and.right")
        } else {
            return Image(systemName: "antenna.radiowaves.left.and.right.slash")
        }
    }

    private var signalColor: Color {
        if device.rssi > -60 {
            return .green
        } else if device.rssi > -80 {
            return .orange
        } else {
            return .red
        }
    }

    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }
}

// MARK: - Preview

struct MeshtasticBLEConnectionView_Previews: PreviewProvider {
    static var previews: some View {
        MeshtasticBLEConnectionView()
    }
}
