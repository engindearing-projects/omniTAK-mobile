//
//  QuickConnectView.swift
//  OmniTAKMobile
//
//  Quick and easy TAK server connection with intelligent defaults
//

import SwiftUI
import Network

// MARK: - Quick Connect View

struct QuickConnectView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = QuickConnectViewModel()
    @StateObject private var enrollmentService = CertificateEnrollmentService.shared

    @State private var selectedMethod: ConnectionMethod = .qrCode
    @State private var showSuccessAnimation = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Hero header
                    heroHeader

                    // Connection method selector
                    methodSelector

                    // Main content
                    ScrollView {
                        VStack(spacing: 24) {
                            switch selectedMethod {
                            case .qrCode:
                                QRCodeConnectView()
                            case .autoDiscover:
                                AutoDiscoveryView(viewModel: viewModel)
                            case .quickSetup:
                                QuickSetupView()
                            case .manual:
                                ManualConnectView()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                    }
                }

                // Success overlay
                if showSuccessAnimation {
                    successOverlay
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { /* Help */ }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(Color(hex: "#FFFC00"))
                    }
                }
            }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#FFFC00").opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(Color(hex: "#FFFC00"))
            }

            Text("Connect to TAK Server")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)

            Text("Choose the easiest way to connect")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "#CCCCCC"))
        }
        .padding(.vertical, 32)
    }

    // MARK: - Method Selector

    private var methodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ConnectionMethod.allCases, id: \.self) { method in
                    MethodCard(
                        method: method,
                        isSelected: selectedMethod == method,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedMethod = method
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(white: 0.08))
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Color(hex: "#00FF00"))
                    .scaleEffect(showSuccessAnimation ? 1.0 : 0.5)
                    .opacity(showSuccessAnimation ? 1.0 : 0.0)

                VStack(spacing: 8) {
                    Text("Connected!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("You're ready to start using OmniTAK")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                }
                .opacity(showSuccessAnimation ? 1.0 : 0.0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showSuccessAnimation = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dismiss()
            }
        }
    }
}

// MARK: - Connection Methods

enum ConnectionMethod: String, CaseIterable {
    case qrCode = "QR Code"
    case autoDiscover = "Auto-Discover"
    case quickSetup = "Quick Setup"
    case manual = "Manual"

    var icon: String {
        switch self {
        case .qrCode: return "qrcode.viewfinder"
        case .autoDiscover: return "wifi.circle.fill"
        case .quickSetup: return "bolt.circle.fill"
        case .manual: return "keyboard"
        }
    }

    var description: String {
        switch self {
        case .qrCode: return "Scan server QR"
        case .autoDiscover: return "Find nearby"
        case .quickSetup: return "Common servers"
        case .manual: return "Enter details"
        }
    }
}

// MARK: - Method Card

struct MethodCard: View {
    let method: ConnectionMethod
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: method.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .black : Color(hex: "#FFFC00"))
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Color(hex: "#FFFC00") : Color(white: 0.15))
                    .clipShape(Circle())

                VStack(spacing: 2) {
                    Text(method.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)

                    Text(method.description)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#999999"))
                }
            }
            .frame(width: 90)
            .padding(.vertical, 12)
            .background(isSelected ? Color(white: 0.15) : Color.clear)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(hex: "#FFFC00") : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - QR Code Connect

struct QRCodeConnectView: View {
    @State private var showScanner = false

    var body: some View {
        VStack(spacing: 20) {
            FeatureCard(
                icon: "qrcode",
                title: "Scan QR Code",
                description: "The fastest way to connect. Ask your TAK server administrator for the enrollment QR code.",
                color: Color(hex: "#FFFC00")
            )

            Button(action: { showScanner = true }) {
                HStack {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 20))
                    Text("Open QR Scanner")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(hex: "#FFFC00"))
                .cornerRadius(12)
            }

            HowToCard(steps: [
                "Ask your TAK server admin for the enrollment QR code",
                "Tap 'Open QR Scanner' above",
                "Point your camera at the QR code",
                "Enter the certificate password when prompted",
                "Done! You'll be connected automatically"
            ])
        }
        .sheet(isPresented: $showScanner) {
            CertificateEnrollmentView()
        }
    }
}

// MARK: - Auto Discovery

class QuickConnectViewModel: ObservableObject {
    @Published var discoveredServers: [DiscoveredServer] = []
    @Published var isScanning = false

    func startDiscovery() {
        isScanning = true

        // Scan for common TAK server ports on local network
        let commonPorts: [UInt16] = [8087, 8089, 8443, 8444, 8446]

        // For demo/development, add localhost servers
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.discoveredServers = [
                DiscoveredServer(name: "Local TAK Server", host: "127.0.0.1", port: 8087, type: .tcp, requiresCert: false),
                DiscoveredServer(name: "Local TAK Server (SSL)", host: "127.0.0.1", port: 8089, type: .ssl, requiresCert: true)
            ]
            self.isScanning = false
        }
    }
}

struct DiscoveredServer: Identifiable {
    let id = UUID()
    let name: String
    let host: String
    let port: UInt16
    let type: ServerType
    let requiresCert: Bool

    enum ServerType {
        case tcp, ssl, udp

        var icon: String {
            switch self {
            case .tcp: return "network"
            case .ssl: return "lock.shield.fill"
            case .udp: return "antenna.radiowaves.left.and.right"
            }
        }
    }
}

struct AutoDiscoveryView: View {
    @ObservedObject var viewModel: QuickConnectViewModel
    @State private var selectedServer: DiscoveredServer?

    var body: some View {
        VStack(spacing: 20) {
            FeatureCard(
                icon: "wifi.circle.fill",
                title: "Auto-Discover Servers",
                description: "Automatically find TAK servers on your local network. Perfect for development and testing.",
                color: Color(hex: "#00BFFF")
            )

            if viewModel.isScanning {
                scanningView
            } else if viewModel.discoveredServers.isEmpty {
                Button(action: { viewModel.startDiscovery() }) {
                    HStack {
                        Image(systemName: "wifi.circle.fill")
                            .font(.system(size: 20))
                        Text("Scan for Servers")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: "#00BFFF"))
                    .cornerRadius(12)
                }
            } else {
                discoveredServersList
            }
        }
    }

    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#00BFFF")))
                .scaleEffect(1.5)

            Text("Scanning network...")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#CCCCCC"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }

    private var discoveredServersList: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Found \(viewModel.discoveredServers.count) server(s)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#CCCCCC"))

                Spacer()

                Button(action: { viewModel.startDiscovery() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Rescan")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#00BFFF"))
                }
            }

            ForEach(viewModel.discoveredServers) { server in
                DiscoveredServerRow(server: server, onConnect: {
                    connectToServer(server)
                })
            }
        }
    }

    private func connectToServer(_ server: DiscoveredServer) {
        let takServer = TAKServer(
            name: server.name,
            host: server.host,
            port: server.port,
            protocolType: server.type == .udp ? "udp" : "tcp",
            useTLS: server.type == .ssl,
            isDefault: false
        )

        ServerManager.shared.addServer(takServer)
        ServerManager.shared.setActiveServer(takServer)

        // TODO: Show success and dismiss
    }
}

struct DiscoveredServerRow: View {
    let server: DiscoveredServer
    let onConnect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: server.type.icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "#00BFFF"))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(server.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)

                Text("\(server.host):\(server.port)")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#999999"))
            }

            Spacer()

            Button(action: onConnect) {
                Text("Connect")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#00BFFF"))
                    .cornerRadius(8)
            }
        }
        .padding(12)
        .background(Color(white: 0.1))
        .cornerRadius(10)
    }
}

// MARK: - Quick Setup

struct QuickSetupView: View {
    @State private var selectedPreset: ServerPreset?

    var body: some View {
        VStack(spacing: 20) {
            FeatureCard(
                icon: "bolt.circle.fill",
                title: "Quick Setup",
                description: "Connect to popular TAK server configurations with one tap. Choose from common presets below.",
                color: Color(hex: "#FF6B35"))

            VStack(spacing: 12) {
                ForEach(ServerPreset.popular) { preset in
                    PresetCard(preset: preset, onSelect: { selectedPreset = preset })
                }
            }
        }
        .sheet(item: $selectedPreset) { preset in
            PresetConfigView(preset: preset)
        }
    }
}

struct ServerPreset: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let icon: String
    let defaultHost: String
    let defaultPort: UInt16
    let requiresCert: Bool
    let useTLS: Bool

    static let popular: [ServerPreset] = [
        ServerPreset(
            name: "TAK Server (FreeTAKServer)",
            description: "Open source TAK server - most common setup",
            icon: "server.rack",
            defaultHost: "freetakserver.com",
            defaultPort: 8089,
            requiresCert: true,
            useTLS: true
        ),
        ServerPreset(
            name: "TAK Server (No Certificate)",
            description: "Simple TCP connection for testing",
            icon: "network",
            defaultHost: "127.0.0.1",
            defaultPort: 8087,
            requiresCert: false,
            useTLS: false
        ),
        ServerPreset(
            name: "CloudTAK",
            description: "Cloud-hosted TAK server",
            icon: "cloud.fill",
            defaultHost: "cloudtak.io",
            defaultPort: 8089,
            requiresCert: true,
            useTLS: true
        )
    ]
}

struct PresetCard: View {
    let preset: ServerPreset
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: preset.icon)
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#FF6B35"))
                    .frame(width: 44, height: 44)
                    .background(Color(hex: "#FF6B35").opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Text(preset.description)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#999999"))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#666666"))
            }
            .padding(16)
            .background(Color(white: 0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PresetConfigView: View {
    @Environment(\.dismiss) private var dismiss
    let preset: ServerPreset

    @State private var serverHost = ""
    @State private var serverPort = ""
    @State private var certificatePassword = ""

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Preset info
                        VStack(spacing: 12) {
                            Image(systemName: preset.icon)
                                .font(.system(size: 48))
                                .foregroundColor(Color(hex: "#FF6B35"))

                            Text(preset.name)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)

                            Text(preset.description)
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#CCCCCC"))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        // Configuration
                        VStack(spacing: 16) {
                            FormField(label: "Server Host", text: $serverHost, placeholder: preset.defaultHost)
                            FormField(label: "Port", text: $serverPort, placeholder: String(preset.defaultPort), keyboardType: .numberPad)

                            if preset.requiresCert {
                                FormField(label: "Certificate Password", text: $certificatePassword, placeholder: "Enter password", isSecure: true)
                            }
                        }

                        Button(action: connect) {
                            Text("Connect to Server")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(hex: "#FF6B35"))
                                .cornerRadius(12)
                        }
                        .disabled(!isValid)
                        .opacity(isValid ? 1.0 : 0.5)
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        }
        .onAppear {
            serverHost = preset.defaultHost
            serverPort = String(preset.defaultPort)
        }
    }

    private var isValid: Bool {
        !serverHost.isEmpty && !serverPort.isEmpty && (!preset.requiresCert || !certificatePassword.isEmpty)
    }

    private func connect() {
        let port = UInt16(serverPort) ?? preset.defaultPort
        let server = TAKServer(
            name: preset.name,
            host: serverHost,
            port: port,
            protocolType: preset.useTLS ? "ssl" : "tcp",
            useTLS: preset.useTLS,
            isDefault: false,
            certificatePassword: preset.requiresCert ? certificatePassword : nil
        )

        ServerManager.shared.addServer(server)
        ServerManager.shared.setActiveServer(server)
        dismiss()
    }
}

// MARK: - Manual Connect

struct ManualConnectView: View {
    @State private var serverName = ""
    @State private var serverHost = ""
    @State private var serverPort = "8087"
    @State private var useTLS = false

    var body: some View {
        VStack(spacing: 20) {
            FeatureCard(
                icon: "keyboard",
                title: "Manual Configuration",
                description: "Full control over your connection settings. Configure all parameters manually.",
                color: Color(hex: "#9B59B6")
            )

            VStack(spacing: 16) {
                FormField(label: "Server Name", text: $serverName, placeholder: "My TAK Server")
                FormField(label: "Host", text: $serverHost, placeholder: "tak.example.com")
                FormField(label: "Port", text: $serverPort, placeholder: "8087", keyboardType: .numberPad)

                Toggle(isOn: $useTLS) {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(useTLS ? Color(hex: "#00FF00") : Color(hex: "#666666"))
                        Text("Use TLS/SSL")
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                    }
                }
                .tint(Color(hex: "#9B59B6"))
                .padding(16)
                .background(Color(white: 0.1))
                .cornerRadius(10)
            }

            Button(action: connect) {
                Text("Add Server")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: "#9B59B6"))
                    .cornerRadius(12)
            }
            .disabled(serverHost.isEmpty)
            .opacity(serverHost.isEmpty ? 0.5 : 1.0)
        }
    }

    private func connect() {
        let port = UInt16(serverPort) ?? 8087
        let server = TAKServer(
            name: serverName.isEmpty ? "TAK Server" : serverName,
            host: serverHost,
            port: port,
            protocolType: useTLS ? "ssl" : "tcp",
            useTLS: useTLS,
            isDefault: false
        )

        ServerManager.shared.addServer(server)
        ServerManager.shared.setActiveServer(server)
    }
}

// MARK: - Reusable Components

struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)
                .frame(width: 56, height: 56)
                .background(color.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#CCCCCC"))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }
}

struct HowToCard: View {
    let steps: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(Color(hex: "#FFFC00"))
                Text("How it works")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 24, height: 24)
                            .background(Color(hex: "#FFFC00"))
                            .clipShape(Circle())

                        Text(step)
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#CCCCCC"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(white: 0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#FFFC00").opacity(0.2), lineWidth: 1)
        )
    }
}

struct FormField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#CCCCCC"))

            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(CustomTextFieldStyle())
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(CustomTextFieldStyle())
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(14)
            .background(Color(white: 0.15))
            .cornerRadius(10)
            .foregroundColor(.white)
    }
}

// MARK: - Preview

#if DEBUG
struct QuickConnectView_Previews: PreviewProvider {
    static var previews: some View {
        QuickConnectView()
            .preferredColorScheme(.dark)
    }
}
#endif
