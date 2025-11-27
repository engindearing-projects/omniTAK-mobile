//
//  ServersView.swift
//  OmniTAKMobile
//
//  Single unified server management view
//  Checkbox to enable, tap to connect, simple and clean
//

import SwiftUI

// MARK: - Servers View

struct ServersView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var serverManager = ServerManager.shared
    @ObservedObject private var takService = TAKService.shared

    @State private var showEnrollment = false
    @State private var showDataPackageImport = false
    @State private var serverToEdit: TAKServer? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Server List
                        if !serverManager.servers.isEmpty {
                            serverList
                        }

                        // Add Server Button
                        addServerButton

                        // Import Data Package Button
                        importDataPackageButton
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Servers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        }
        .sheet(isPresented: $showEnrollment) {
            SimpleEnrollView()
        }
        .sheet(isPresented: $showDataPackageImport) {
            DataPackageImportView()
        }
        .sheet(item: $serverToEdit) { server in
            ServerEditView(server: server)
        }
    }

    // MARK: - Server List

    private var serverList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SERVERS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: "#666666"))
                .padding(.leading, 4)

            ForEach(serverManager.servers) { server in
                ServerRowSimple(
                    server: server,
                    isActive: server.id == serverManager.activeServer?.id,
                    isConnected: takService.isConnected && server.id == serverManager.activeServer?.id,
                    onToggleEnabled: {
                        serverManager.toggleServerEnabled(server)
                        // Disconnect if disabling connected server
                        if takService.isConnected && server.id == serverManager.activeServer?.id && !server.enabled {
                            takService.disconnect()
                        }
                    },
                    onSelect: {
                        serverManager.setActiveServer(server)
                    },
                    onEdit: {
                        serverToEdit = server
                    },
                    onDelete: {
                        if takService.isConnected && server.id == serverManager.activeServer?.id {
                            takService.disconnect()
                        }
                        serverManager.deleteServer(server)
                    }
                )
            }
        }
    }

    // MARK: - Add Server Button

    private var addServerButton: some View {
        Button(action: { showEnrollment = true }) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#FFFC00"))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Server")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Sign in with username & password")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#888888"))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(Color(hex: "#444444"))
            }
            .padding(16)
            .background(Color(white: 0.08))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#FFFC00").opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Import Data Package Button

    private var importDataPackageButton: some View {
        Button(action: { showDataPackageImport = true }) {
            HStack(spacing: 12) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#00BCD4"))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Import Data Package")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Import .zip with certs & server config")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#888888"))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(Color(hex: "#444444"))
            }
            .padding(16)
            .background(Color(white: 0.08))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#00BCD4").opacity(0.3), lineWidth: 1)
            )
        }
    }

}

// MARK: - Server Row (Simple)

struct ServerRowSimple: View {
    let server: TAKServer
    let isActive: Bool
    let isConnected: Bool
    let onToggleEnabled: () -> Void
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: onToggleEnabled) {
                Image(systemName: server.enabled ? "checkmark.square.fill" : "square")
                    .font(.system(size: 24))
                    .foregroundColor(server.enabled ? Color(hex: "#00FF00") : Color(hex: "#555555"))
            }
            .buttonStyle(PlainButtonStyle())

            // Server info (tappable)
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    // Status dot
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(server.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(server.enabled ? .white : Color(hex: "#666666"))

                        HStack(spacing: 4) {
                            Text("\(server.host):\(server.port)")
                            if server.useTLS {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 10))
                            }
                        }
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#888888"))
                    }

                    Spacer()

                    // Status badge
                    if isConnected {
                        Text("CONNECTED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(hex: "#00FF00"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(hex: "#00FF00").opacity(0.15))
                            .cornerRadius(4)
                    } else if isActive && server.enabled {
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(hex: "#FFFC00"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(hex: "#FFFC00").opacity(0.15))
                            .cornerRadius(4)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Edit
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#888888"))
            }
            .buttonStyle(PlainButtonStyle())

            // Delete
            Button(action: { showDeleteConfirm = true }) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#666666"))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(Color(white: isActive ? 0.1 : 0.06))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isActive && server.enabled ? Color(hex: "#FFFC00").opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .opacity(server.enabled ? 1.0 : 0.6)
        .confirmationDialog("Delete Server?", isPresented: $showDeleteConfirm) {
            Button("Delete \(server.name)", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var statusColor: Color {
        if isConnected {
            return Color(hex: "#00FF00")
        } else if isActive && server.enabled {
            return Color(hex: "#FFFC00")
        } else {
            return Color(hex: "#444444")
        }
    }
}

// MARK: - Server Edit View

struct ServerEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var serverManager = ServerManager.shared

    let server: TAKServer

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = ""
    @State private var enrollmentPort: String = ""
    @State private var useTLS: Bool = true
    @State private var allowLegacyTLS: Bool = false

    init(server: TAKServer) {
        self.server = server
        _name = State(initialValue: server.name)
        _host = State(initialValue: server.host)
        _port = State(initialValue: String(server.port))
        _enrollmentPort = State(initialValue: String(server.enrollmentPort ?? 8446))
        _useTLS = State(initialValue: server.useTLS)
        _allowLegacyTLS = State(initialValue: server.allowLegacyTLS)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Server Name
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Server Name")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "#CCCCCC"))

                            TextField("My TAK Server", text: $name)
                                .textFieldStyle(TAKTextFieldStyle())
                        }

                        // Host
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Host")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color(hex: "#CCCCCC"))

                            TextField("tak.example.com", text: $host)
                                .textFieldStyle(TAKTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .keyboardType(.URL)
                        }

                        // Ports
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Streaming Port")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color(hex: "#CCCCCC"))

                                TextField("8089", text: $port)
                                    .textFieldStyle(TAKTextFieldStyle())
                                    .keyboardType(.numberPad)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Enrollment Port")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color(hex: "#CCCCCC"))

                                TextField("8446", text: $enrollmentPort)
                                    .textFieldStyle(TAKTextFieldStyle())
                                    .keyboardType(.numberPad)
                            }
                        }

                        // TLS Toggle
                        Toggle(isOn: $useTLS) {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(useTLS ? Color(hex: "#00FF00") : Color(hex: "#666666"))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Use TLS/SSL")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)

                                    Text("Encrypted connection (recommended)")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "#999999"))
                                }
                            }
                        }
                        .tint(Color(hex: "#00FF00"))
                        .padding(16)
                        .background(Color(white: 0.08))
                        .cornerRadius(10)

                        // Legacy TLS Toggle
                        Toggle(isOn: $allowLegacyTLS) {
                            HStack {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .foregroundColor(allowLegacyTLS ? Color(hex: "#FF6B6B") : Color(hex: "#666666"))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Allow Legacy TLS")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)

                                    Text("For old servers (less secure)")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "#999999"))
                                }
                            }
                        }
                        .tint(Color(hex: "#FF6B6B"))
                        .padding(16)
                        .background(Color(white: 0.08))
                        .cornerRadius(10)

                        // Save Button
                        Button(action: saveChanges) {
                            Text("Save Changes")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isFormValid ? Color(hex: "#FFFC00") : Color(hex: "#666666"))
                                .cornerRadius(12)
                        }
                        .disabled(!isFormValid)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Edit Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        }
    }

    private var isFormValid: Bool {
        !name.isEmpty && !host.isEmpty && !port.isEmpty && (UInt16(port) != nil)
    }

    private func saveChanges() {
        guard let portNum = UInt16(port) else { return }
        let enrollPortNum = UInt16(enrollmentPort) ?? 8446

        var updatedServer = server
        updatedServer.name = name
        updatedServer.host = host
        updatedServer.port = portNum
        updatedServer.enrollmentPort = enrollPortNum
        updatedServer.useTLS = useTLS
        updatedServer.allowLegacyTLS = allowLegacyTLS
        updatedServer.protocolType = useTLS ? "tls" : "tcp"

        serverManager.updateServer(updatedServer)
        dismiss()
    }
}

// MARK: - Preview

#if DEBUG
struct ServersView_Previews: PreviewProvider {
    static var previews: some View {
        ServersView()
            .preferredColorScheme(.dark)
    }
}
#endif
