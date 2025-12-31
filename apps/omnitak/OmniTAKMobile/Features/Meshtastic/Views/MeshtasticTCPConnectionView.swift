//
//  MeshtasticTCPConnectionView.swift
//  OmniTAK Mobile
//
//  Meshtastic TCP Connection UI
//

import SwiftUI

struct MeshtasticTCPConnectionView: View {
    @ObservedObject var manager: MeshtasticManager = MeshtasticManager.shared
    @Environment(\.dismiss) var dismiss

    @State private var hostAddress: String = ""
    @State private var portString: String = "4403"
    @State private var isConnecting: Bool = false
    @State private var showingAddSheet: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Connected Device Card (if connected)
                if manager.isConnected {
                    connectedDeviceCard
                        .padding()
                }

                // Device List
                List {
                    // Saved Devices Section
                    Section {
                        // Show connected device first
                        if manager.isConnected, let device = manager.connectedDevice {
                            DeviceListRow(
                                icon: "wifi",
                                iconColor: .green,
                                title: device.name,
                                subtitle: device.devicePath,
                                isConnected: true
                            )
                        }

                        // Show saved hosts (not currently connected)
                        ForEach(manager.savedHosts) { saved in
                            let isCurrentlyConnected = manager.isConnected &&
                                manager.connectedDevice?.devicePath == saved.host

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
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 36))
                                    .foregroundColor(.secondary)
                                Text("No Saved Devices")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("Tap + to add a Meshtastic device")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                            .listRowBackground(Color.clear)
                        }
                    } header: {
                        Text("Saved Devices")
                    } footer: {
                        Text("Enter the IP address of your Meshtastic device with TCP enabled. Default port is 4403.")
                    }
                }
                .listStyle(.insetGrouped)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Connect Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddDeviceSheet(
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

    // MARK: - Actions

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

// MARK: - Add Device Sheet

private struct AddDeviceSheet: View {
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
                        .textContentType(.none)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.numbersAndPunctuation)

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

struct MeshtasticTCPConnectionView_Previews: PreviewProvider {
    static var previews: some View {
        MeshtasticTCPConnectionView()
    }
}
