//
//  ConnectionStatusWidget.swift
//  OmniTAKMobile
//
//  Real-time connection status indicator with beautiful animations
//

import SwiftUI

// MARK: - Connection Status Widget

struct ConnectionStatusWidget: View {
    @ObservedObject var takService: TAKService
    @ObservedObject var serverManager = ServerManager.shared

    @State private var pulseAnimation = false
    @State private var showDetails = false

    var body: some View {
        Button(action: { showDetails.toggle() }) {
            HStack(spacing: 12) {
                // Animated status indicator
                ZStack {
                    if takService.isConnected {
                        Circle()
                            .fill(Color(hex: "#00FF00").opacity(0.3))
                            .frame(width: 32, height: 32)
                            .scaleEffect(pulseAnimation ? 1.4 : 1.0)
                            .opacity(pulseAnimation ? 0.0 : 1.0)
                    }

                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(statusText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    if let server = serverManager.activeServer {
                        Text(server.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#CCCCCC"))
                            .lineLimit(1)
                    }
                }

                Spacer()

                if takService.isConnected {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 10))
                            Text("\(takService.messagesReceived)")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(Color(hex: "#00FF00"))

                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 10))
                            Text("\(takService.messagesSent)")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(Color(hex: "#00BFFF"))
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(hex: "#666666"))
                    .rotationEffect(.degrees(showDetails ? 90 : 0))
            }
            .padding(12)
            .background(Color(white: 0.12))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(statusColor.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showDetails) {
            ConnectionDetailsView(takService: takService)
        }
        .onAppear {
            if takService.isConnected {
                startPulseAnimation()
            }
        }
        .onChange(of: takService.isConnected) { newValue in
            if newValue {
                startPulseAnimation()
            }
        }
    }

    private var statusColor: Color {
        if takService.isConnected {
            return Color(hex: "#00FF00")
        } else {
            return Color(hex: "#FF6B6B")
        }
    }

    private var statusText: String {
        if takService.isConnected {
            return "Connected"
        } else if takService.connectionStatus.contains("Connecting") {
            return "Connecting..."
        } else {
            return "Disconnected"
        }
    }

    private func startPulseAnimation() {
        withAnimation(Animation.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
            pulseAnimation = true
        }
    }
}

// MARK: - Connection Details View

struct ConnectionDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var takService: TAKService
    @ObservedObject var serverManager = ServerManager.shared

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Status header
                        statusHeader

                        // Active server info
                        if let server = serverManager.activeServer {
                            serverInfoSection(server)
                        }

                        // Statistics
                        statisticsSection

                        // Quick actions
                        quickActionsSection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Connection Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        }
    }

    private var statusHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(takService.isConnected ? Color(hex: "#00FF00").opacity(0.2) : Color(hex: "#FF6B6B").opacity(0.2))
                    .frame(width: 100, height: 100)

                Image(systemName: takService.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(takService.isConnected ? Color(hex: "#00FF00") : Color(hex: "#FF6B6B"))
            }

            VStack(spacing: 8) {
                Text(takService.isConnected ? "Connected" : "Disconnected")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                Text(takService.connectionStatus)
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "#CCCCCC"))
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func serverInfoSection(_ server: TAKServer) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Server Details")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                InfoRow(icon: "server.rack", label: "Server", value: server.name)
                InfoRow(icon: "network", label: "Host", value: server.host)
                InfoRow(icon: "number", label: "Port", value: String(server.port))
                InfoRow(
                    icon: server.useTLS ? "lock.shield.fill" : "network",
                    label: "Protocol",
                    value: server.useTLS ? "TLS/SSL" : server.protocolType.uppercased(),
                    valueColor: server.useTLS ? Color(hex: "#00FF00") : .white
                )
            }
        }
        .padding(16)
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Statistics")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            HStack(spacing: 12) {
                StatCard(
                    icon: "arrow.down.circle.fill",
                    label: "Received",
                    value: String(takService.messagesReceived),
                    color: Color(hex: "#00FF00")
                )

                StatCard(
                    icon: "arrow.up.circle.fill",
                    label: "Sent",
                    value: String(takService.messagesSent),
                    color: Color(hex: "#00BFFF")
                )
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(spacing: 12) {
            if takService.isConnected {
                ActionButton(
                    title: "Disconnect",
                    icon: "xmark.circle.fill",
                    color: Color(hex: "#FF6B6B"),
                    action: {
                        // TODO: Disconnect
                    }
                )
            } else {
                ActionButton(
                    title: "Reconnect",
                    icon: "arrow.clockwise.circle.fill",
                    color: Color(hex: "#00FF00"),
                    action: {
                        // TODO: Reconnect
                    }
                )

                ActionButton(
                    title: "Change Server",
                    icon: "arrow.left.arrow.right.circle.fill",
                    color: Color(hex: "#FFFC00"),
                    action: {
                        // TODO: Show server picker
                    }
                )
            }
        }
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = .white

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#FFFC00"))
                .frame(width: 28)

            Text(label)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#CCCCCC"))

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(valueColor)
        }
        .padding(12)
        .background(Color(white: 0.15))
        .cornerRadius(8)
    }
}

struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#CCCCCC"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color)
            .cornerRadius(12)
        }
    }
}

// MARK: - Compact Status Badge

struct CompactStatusBadge: View {
    @ObservedObject var takService: TAKService

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(takService.isConnected ? Color(hex: "#00FF00") : Color(hex: "#FF6B6B"))
                .frame(width: 8, height: 8)

            Text(takService.isConnected ? "Online" : "Offline")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(takService.isConnected ? Color(hex: "#00FF00") : Color(hex: "#FF6B6B"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(white: 0.15))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#if DEBUG
struct ConnectionStatusWidget_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ConnectionStatusWidget(takService: TAKService())
            CompactStatusBadge(takService: TAKService())
        }
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}
#endif
