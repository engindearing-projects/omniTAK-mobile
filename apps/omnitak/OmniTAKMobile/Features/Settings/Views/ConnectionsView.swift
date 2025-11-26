//
//  ConnectionsView.swift
//  OmniTAKMobile
//
//  Unified server connection management - KISS approach
//  Simple CRUD for all TAK server connections
//

import SwiftUI

// MARK: - Connections View

struct ConnectionsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var serverManager = ServerManager.shared
    @State private var showAddServer = false
    @State private var editingServer: TAKServer?
    @State private var serverToDelete: TAKServer?
    @State private var showDeleteAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    if serverManager.servers.isEmpty {
                        emptyState
                    } else {
                        serverList
                    }
                }
            }
            .navigationTitle("Connections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddServer = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color(hex: "#FFFC00"))
                    }
                }
            }
        }
        .sheet(isPresented: $showAddServer) {
            ServerEditorView(mode: .create)
        }
        .sheet(item: $editingServer) { server in
            ServerEditorView(mode: .edit(server))
        }
        .alert("Delete Server?", isPresented: $showDeleteAlert, presenting: serverToDelete) { server in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                serverManager.deleteServer(server)
            }
        } message: { server in
            Text("Are you sure you want to delete '\(server.name)'? This cannot be undone.")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "server.rack")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "#666666"))

            VStack(spacing: 8) {
                Text("No Connections")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("Add a TAK server to get started")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#AAAAAA"))
            }

            Button(action: { showAddServer = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Server")
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(Color(hex: "#FFFC00"))
                .cornerRadius(12)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Server List

    private var serverList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(serverManager.servers) { server in
                    ConnectionServerCard(
                        server: server,
                        isActive: serverManager.activeServer?.id == server.id,
                        onTap: {
                            serverManager.setActiveServer(server)
                        },
                        onToggleEnabled: {
                            serverManager.toggleServerEnabled(server)
                        },
                        onEdit: {
                            editingServer = server
                        },
                        onDelete: {
                            serverToDelete = server
                            showDeleteAlert = true
                        }
                    )
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Connection Server Card

struct ConnectionServerCard: View {
    let server: TAKServer
    let isActive: Bool
    let onTap: () -> Void
    let onToggleEnabled: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Main content
                HStack(spacing: 12) {
                    // Enable/Disable checkbox
                    Button(action: onToggleEnabled) {
                        Image(systemName: server.enabled ? "checkmark.square.fill" : "square")
                            .font(.system(size: 22))
                            .foregroundColor(server.enabled ? Color(hex: "#FFFC00") : Color(hex: "#666666"))
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Status indicator
                    Circle()
                        .fill(server.enabled ? (isActive ? Color(hex: "#00FF00") : Color(hex: "#666666")) : Color(hex: "#333333"))
                        .frame(width: 12, height: 12)

                    // Server info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(server.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(server.enabled ? .white : Color(hex: "#666666"))

                        HStack(spacing: 8) {
                            Label(server.host, systemImage: "network")
                            Text(":")
                            Text("\(server.port)")
                        }
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#AAAAAA"))

                        // Connection type badge
                        HStack(spacing: 6) {
                            Image(systemName: server.useTLS ? "lock.fill" : "lock.open")
                            Text(server.useTLS ? "TLS" : "TCP")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(server.useTLS ? Color(hex: "#00FF00") : Color(hex: "#FFFC00"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(server.useTLS ? Color(hex: "#00FF00").opacity(0.15) : Color(hex: "#FFFC00").opacity(0.15))
                        .cornerRadius(6)
                    }

                    Spacer()

                    // Active indicator
                    if isActive {
                        VStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(Color(hex: "#00FF00"))

                            Text("ACTIVE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: "#00FF00"))
                        }
                    }
                }
                .padding(16)

                // Action buttons
                Divider()
                    .background(Color(hex: "#333333"))

                HStack(spacing: 0) {
                    Button(action: onEdit) {
                        HStack {
                            Spacer()
                            Image(systemName: "pencil")
                            Text("Edit")
                            Spacer()
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "#00BCD4"))
                        .padding(.vertical, 12)
                    }

                    Divider()
                        .frame(width: 1)
                        .background(Color(hex: "#333333"))

                    Button(action: onDelete) {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text("Delete")
                            Spacer()
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "#FF3B30"))
                        .padding(.vertical, 12)
                    }
                }
            }
            .background(Color(hex: "#1A1A1A"))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color(hex: "#00FF00") : Color(hex: "#333333"), lineWidth: 1.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Server Editor View

struct ServerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var serverManager = ServerManager.shared

    enum EditorMode {
        case create
        case edit(TAKServer)

        var title: String {
            switch self {
            case .create: return "Add Server"
            case .edit: return "Edit Server"
            }
        }

        var buttonTitle: String {
            switch self {
            case .create: return "Add"
            case .edit: return "Save"
            }
        }
    }

    let mode: EditorMode

    // Form fields
    @State private var name: String
    @State private var host: String
    @State private var port: String
    @State private var useTLS: Bool
    @State private var certificateName: String
    @State private var certificatePassword: String
    @State private var username: String
    @State private var password: String
    @State private var enrollmentPort: String

    @State private var showEnrollment = false
    @State private var enrolling = false
    @State private var enrollmentError: String?

    init(mode: EditorMode) {
        self.mode = mode

        switch mode {
        case .create:
            _name = State(initialValue: "")
            _host = State(initialValue: "")
            _port = State(initialValue: "8089")
            _useTLS = State(initialValue: true)
            _certificateName = State(initialValue: "")
            _certificatePassword = State(initialValue: "")
            _username = State(initialValue: "")
            _password = State(initialValue: "")
            _enrollmentPort = State(initialValue: "8446")

        case .edit(let server):
            _name = State(initialValue: server.name)
            _host = State(initialValue: server.host)
            _port = State(initialValue: "\(server.port)")
            _useTLS = State(initialValue: server.useTLS)
            _certificateName = State(initialValue: server.certificateName ?? "")
            _certificatePassword = State(initialValue: server.certificatePassword ?? "")
            _username = State(initialValue: server.username ?? "")
            _password = State(initialValue: server.password ?? "")
            _enrollmentPort = State(initialValue: "\(server.enrollmentPort ?? 8446)")
        }
    }

    var isFormValid: Bool {
        !name.isEmpty && !host.isEmpty && Int(port) != nil
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Basic Info
                        ConnectionFormSection(title: "BASIC INFO") {
                            ConnectionFormField(label: "Name", text: $name, placeholder: "My TAK Server")
                            ConnectionFormField(label: "Host", text: $host, placeholder: "192.168.1.100")
                            ConnectionFormField(label: "Port", text: $port, placeholder: "8089", keyboardType: .numberPad)

                            Toggle(isOn: $useTLS) {
                                HStack {
                                    Image(systemName: useTLS ? "lock.fill" : "lock.open")
                                    Text("Use TLS/SSL")
                                }
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                            }
                            .tint(Color(hex: "#00FF00"))
                        }

                        // Certificate (Optional)
                        ConnectionFormSection(title: "CERTIFICATE (OPTIONAL)") {
                            ConnectionFormField(label: "Certificate Name", text: $certificateName, placeholder: "Leave empty to enroll")
                            ConnectionFormField(label: "Certificate Password", text: $certificatePassword, placeholder: "atakatak", isSecure: true)
                        }

                        // Enrollment
                        ConnectionFormSection(title: "ENROLLMENT") {
                            Button(action: { showEnrollment.toggle() }) {
                                HStack {
                                    Image(systemName: "key.fill")
                                    Text("Certificate Enrollment")
                                    Spacer()
                                    Image(systemName: showEnrollment ? "chevron.up" : "chevron.down")
                                }
                                .font(.system(size: 16))
                                .foregroundColor(Color(hex: "#00BCD4"))
                            }

                            if showEnrollment {
                                VStack(spacing: 12) {
                                    ConnectionFormField(label: "Username", text: $username, placeholder: "username")
                                    ConnectionFormField(label: "Password", text: $password, placeholder: "password", isSecure: true)
                                    ConnectionFormField(label: "Enrollment Port", text: $enrollmentPort, placeholder: "8446", keyboardType: .numberPad)

                                    Button(action: enrollWithServer) {
                                        HStack {
                                            if enrolling {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                            } else {
                                                Image(systemName: "arrow.down.circle.fill")
                                                Text("Enroll Now")
                                            }
                                        }
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color(hex: "#FFFC00"))
                                        .cornerRadius(10)
                                    }
                                    .disabled(enrolling || username.isEmpty || password.isEmpty)

                                    if let error = enrollmentError {
                                        Text(error)
                                            .font(.system(size: 14))
                                            .foregroundColor(Color(hex: "#FF3B30"))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FF3B30"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(mode.buttonTitle) {
                        saveServer()
                    }
                    .foregroundColor(Color(hex: "#00FF00"))
                    .disabled(!isFormValid)
                }
            }
        }
    }

    // MARK: - Actions

    private func saveServer() {
        guard let portNum = UInt16(port) else { return }

        let enrollmentPortNum = UInt16(enrollmentPort) ?? 8446

        let serverId: UUID
        switch mode {
        case .create:
            serverId = UUID()
        case .edit(let existingServer):
            serverId = existingServer.id
        }

        let server = TAKServer(
            id: serverId,
            name: name,
            host: host,
            port: portNum,
            protocolType: useTLS ? "ssl" : "tcp",
            useTLS: useTLS,
            isDefault: false,
            certificateName: certificateName.isEmpty ? nil : certificateName,
            certificatePassword: certificatePassword.isEmpty ? nil : certificatePassword,
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password,
            enrollmentPort: enrollmentPortNum
        )

        switch mode {
        case .create:
            serverManager.addServer(server)
        case .edit:
            serverManager.updateServer(server)
        }

        dismiss()
    }

    private func enrollWithServer() {
        guard !username.isEmpty && !password.isEmpty else { return }

        enrolling = true
        enrollmentError = nil

        Task {
            do {
                let enrollmentService = CertificateEnrollmentService.shared
                let enrollmentPortNum = Int(enrollmentPort) ?? 8446
                let portNum = Int(port) ?? 8089

                _ = try await enrollmentService.enrollWithUsernamePassword(
                    server: host,
                    port: portNum,
                    enrollmentPort: enrollmentPortNum,
                    username: username,
                    password: password
                )

                await MainActor.run {
                    enrolling = false
                    // Auto-fill certificate name after successful enrollment
                    certificateName = "omnitak-cert-\(host)"
                    showEnrollment = false
                }
            } catch {
                await MainActor.run {
                    enrolling = false
                    enrollmentError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Connection Form Components

struct ConnectionFormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(Color(hex: "#999999"))
                .padding(.horizontal, 4)

            VStack(spacing: 12) {
                content
            }
            .padding(16)
            .background(Color(hex: "#1A1A1A"))
            .cornerRadius(12)
        }
    }
}

struct ConnectionFormField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#AAAAAA"))

            if isSecure {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(ConnectionTextFieldStyle())
                    .autocapitalization(.none)
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(ConnectionTextFieldStyle())
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
            }
        }
    }
}

struct ConnectionTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 16))
            .foregroundColor(.white)
            .padding(12)
            .background(Color(hex: "#0A0A0A"))
            .cornerRadius(8)
    }
}

// MARK: - Preview

#if DEBUG
struct ConnectionsView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionsView()
            .preferredColorScheme(.dark)
    }
}
#endif
