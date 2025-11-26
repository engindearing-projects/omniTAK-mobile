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

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Connection Status
                        connectionStatus

                        // Server List
                        if !serverManager.servers.isEmpty {
                            serverList
                        }

                        // Add Server Button
                        addServerButton
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
    }

    // MARK: - Connection Status

    private var connectionStatus: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(takService.isConnected ? Color(hex: "#00FF00") : Color(hex: "#FF4444"))
                .frame(width: 14, height: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(takService.isConnected ? "CONNECTED" : "DISCONNECTED")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(takService.isConnected ? Color(hex: "#00FF00") : Color(hex: "#FF4444"))

                if let server = serverManager.activeServer {
                    Text("\(server.host):\(server.port)")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#888888"))
                }
            }

            Spacer()

            // Connect/Disconnect button
            Button(action: toggleConnection) {
                Text(takService.isConnected ? "Disconnect" : "Connect")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(takService.isConnected ? .red : Color(hex: "#00FF00"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(takService.isConnected ? .red : Color(hex: "#00FF00"), lineWidth: 1)
                    )
            }
            .disabled(serverManager.activeServer == nil || !(serverManager.activeServer?.enabled ?? false))
            .opacity(serverManager.activeServer?.enabled ?? false ? 1.0 : 0.5)
        }
        .padding(16)
        .background(Color(white: 0.08))
        .cornerRadius(12)
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

    // MARK: - Actions

    private func toggleConnection() {
        if takService.isConnected {
            takService.disconnect()
        } else if let server = serverManager.activeServer, server.enabled {
            print("🔌 Connecting to \(server.host):\(server.port)")
            takService.connect(
                host: server.host,
                port: server.port,
                protocolType: server.protocolType,
                useTLS: server.useTLS,
                certificateName: server.certificateName,
                certificatePassword: server.certificatePassword
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

// MARK: - Preview

#if DEBUG
struct ServersView_Previews: PreviewProvider {
    static var previews: some View {
        ServersView()
            .preferredColorScheme(.dark)
    }
}
#endif
