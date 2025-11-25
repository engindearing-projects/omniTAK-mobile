//
//  ServerConfigurationView.swift
//  OmniTAKMobile
//
//  Comprehensive TAK server configuration and enrollment view
//  Supports QR code enrollment, CSR-based enrollment, and manual configuration
//

import SwiftUI
import AVFoundation

// MARK: - Main Server Configuration View

struct ServerConfigurationView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var serverManager = ServerManager.shared
    @StateObject private var certificateManager = CertificateManager.shared
    @StateObject private var csrService = CSREnrollmentService.shared
    @StateObject private var qrEnrollmentService = CertificateEnrollmentService.shared

    @State private var selectedTab: EnrollmentTab = .credentials
    @State private var showingAddServer = false
    @State private var editingServer: TAKServer?

    enum EnrollmentTab: String, CaseIterable {
        case credentials = "Username/Password"
        case qrCode = "QR Code"
        case manual = "Manual"
    }

    var body: some View {
        NavigationView {
            List {
                // Existing Servers Section
                Section {
                    ForEach(serverManager.servers) { server in
                        ServerRowView(
                            server: server,
                            isActive: serverManager.activeServer?.id == server.id,
                            onSetActive: {
                                serverManager.setActiveServer(server)
                            },
                            onEdit: {
                                editingServer = server
                            }
                        )
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            serverManager.deleteServer(serverManager.servers[index])
                        }
                    }
                } header: {
                    Text("TAK Servers")
                } footer: {
                    if serverManager.servers.isEmpty {
                        Text("No servers configured. Add a server to connect to TAK.")
                    }
                }

                // Add Server Section
                Section {
                    Button {
                        showingAddServer = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Add TAK Server")
                        }
                    }
                }

                // Certificates Section
                Section {
                    ForEach(certificateManager.certificates) { cert in
                        CertificateRowView(certificate: cert)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            certificateManager.deleteCertificate(id: certificateManager.certificates[index].id)
                        }
                    }
                } header: {
                    Text("Certificates")
                } footer: {
                    if certificateManager.certificates.isEmpty {
                        Text("No certificates enrolled. Add a server with certificate enrollment to connect securely.")
                    }
                }
            }
            .navigationTitle("Server Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddServer) {
                AddServerView()
            }
            .sheet(item: $editingServer) { server in
                EditServerView(server: server)
            }
        }
    }
}

// MARK: - Add Server View

struct AddServerView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var csrService = CSREnrollmentService.shared
    @StateObject private var qrService = CertificateEnrollmentService.shared

    @State private var selectedMethod: EnrollmentMethod = .credentials
    @State private var showError = false
    @State private var errorMessage = ""

    // CSR Enrollment Fields
    @State private var serverHost = ""
    @State private var username = ""
    @State private var password = ""
    @State private var port = "8089"
    @State private var certEnrollPort = "8446"
    @State private var secureAPIPort = "8443"
    @State private var trustSelfSigned = true

    // QR Code Fields
    @State private var qrCodeContent = ""
    @State private var certPassword = ""
    @State private var showingScanner = false

    // Manual Fields
    @State private var serverName = ""
    @State private var manualHost = ""
    @State private var manualPort = "8087"
    @State private var protocolType = "tcp"
    @State private var useTLS = false
    @State private var selectedCertificate: TAKCertificate?

    enum EnrollmentMethod: String, CaseIterable {
        case credentials = "Username/Password"
        case qrCode = "QR Code"
        case manual = "Manual"

        var icon: String {
            switch self {
            case .credentials: return "person.badge.key.fill"
            case .qrCode: return "qrcode.viewfinder"
            case .manual: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        NavigationView {
            Form {
                // Method Selection
                Section {
                    Picker("Enrollment Method", selection: $selectedMethod) {
                        ForEach(EnrollmentMethod.allCases, id: \.self) { method in
                            Label(method.rawValue, systemImage: method.icon)
                                .tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Connection Method")
                }

                // Method-specific content
                switch selectedMethod {
                case .credentials:
                    credentialsSection
                case .qrCode:
                    qrCodeSection
                case .manual:
                    manualSection
                }

                // Status Section
                if csrService.status.isInProgress || qrService.progress.isInProgress {
                    Section {
                        HStack {
                            ProgressView()
                                .padding(.trailing, 8)
                            Text(csrService.status.isInProgress ? csrService.status.description : qrService.progress.description)
                                .foregroundColor(.secondary)
                        }

                        if csrService.progress > 0 {
                            ProgressView(value: csrService.progress)
                        }
                    }
                }

                // Action Button
                Section {
                    Button {
                        Task {
                            await performEnrollment()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text(buttonTitle)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isFormValid || csrService.status.isInProgress || qrService.progress.isInProgress)
                }
            }
            .navigationTitle("Add Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Enrollment Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingScanner) {
                QRCodeScannerView { code in
                    qrCodeContent = code
                    showingScanner = false
                }
            }
        }
    }

    // MARK: - Section Views

    private var credentialsSection: some View {
        Group {
            Section {
                TextField("Server Host", text: $serverHost)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    .keyboardType(.URL)

                TextField("Username", text: $username)
                    .textContentType(.username)
                    .autocapitalization(.none)

                SecureField("Password", text: $password)
                    .textContentType(.password)
            } header: {
                Text("Server Credentials")
            } footer: {
                Text("Enter your TAK server credentials to automatically enroll a certificate.")
            }

            Section {
                TextField("CoT Port", text: $port)
                    .keyboardType(.numberPad)

                TextField("Cert Enrollment Port", text: $certEnrollPort)
                    .keyboardType(.numberPad)

                TextField("Secure API Port", text: $secureAPIPort)
                    .keyboardType(.numberPad)

                Toggle("Trust Self-Signed Certificates", isOn: $trustSelfSigned)
            } header: {
                Text("Advanced Settings")
            }
        }
    }

    private var qrCodeSection: some View {
        Group {
            Section {
                Button {
                    showingScanner = true
                } label: {
                    HStack {
                        Image(systemName: "qrcode.viewfinder")
                            .font(.title2)
                        Text("Scan QR Code")
                    }
                }

                if !qrCodeContent.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("QR Code scanned")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Scan Enrollment QR Code")
            } footer: {
                Text("Scan the QR code provided by your TAK server administrator.")
            }

            if !qrCodeContent.isEmpty {
                Section {
                    SecureField("Certificate Password", text: $certPassword)
                        .textContentType(.password)
                } header: {
                    Text("Certificate Password")
                } footer: {
                    Text("Enter the password for the certificate bundle.")
                }
            }
        }
    }

    private var manualSection: some View {
        Group {
            Section {
                TextField("Server Name", text: $serverName)

                TextField("Host Address", text: $manualHost)
                    .textContentType(.URL)
                    .autocapitalization(.none)
                    .keyboardType(.URL)

                TextField("Port", text: $manualPort)
                    .keyboardType(.numberPad)
            } header: {
                Text("Server Details")
            }

            Section {
                Picker("Protocol", selection: $protocolType) {
                    Text("TCP").tag("tcp")
                    Text("UDP").tag("udp")
                    Text("TLS/SSL").tag("ssl")
                }

                if protocolType == "ssl" {
                    Toggle("Use TLS", isOn: $useTLS)

                    Picker("Certificate", selection: $selectedCertificate) {
                        Text("None").tag(nil as TAKCertificate?)
                        ForEach(CertificateManager.shared.certificates) { cert in
                            Text(cert.displayName).tag(cert as TAKCertificate?)
                        }
                    }
                }
            } header: {
                Text("Connection Settings")
            }
        }
    }

    // MARK: - Computed Properties

    private var buttonTitle: String {
        switch selectedMethod {
        case .credentials:
            return "Enroll Certificate"
        case .qrCode:
            return "Import Certificate"
        case .manual:
            return "Add Server"
        }
    }

    private var isFormValid: Bool {
        switch selectedMethod {
        case .credentials:
            return !serverHost.isEmpty && !username.isEmpty && !password.isEmpty
        case .qrCode:
            return !qrCodeContent.isEmpty && !certPassword.isEmpty
        case .manual:
            return !serverName.isEmpty && !manualHost.isEmpty && !manualPort.isEmpty
        }
    }

    // MARK: - Actions

    private func performEnrollment() async {
        do {
            switch selectedMethod {
            case .credentials:
                let config = TAKServerEnrollmentConfig(
                    serverURL: serverHost,
                    username: username,
                    password: password,
                    port: Int(port) ?? 8089,
                    certEnrollPort: Int(certEnrollPort) ?? 8446,
                    secureAPIPort: Int(secureAPIPort) ?? 8443,
                    trustSelfSignedCerts: trustSelfSigned
                )
                _ = try await csrService.beginEnrollment(config: config)
                await MainActor.run { dismiss() }

            case .qrCode:
                _ = try await qrService.enrollFromQRCode(qrCodeContent, password: certPassword)
                await MainActor.run { dismiss() }

            case .manual:
                let server = TAKServer(
                    name: serverName,
                    host: manualHost,
                    port: UInt16(manualPort) ?? 8087,
                    protocolType: protocolType,
                    useTLS: useTLS || protocolType == "ssl",
                    certificateName: selectedCertificate?.name,
                    certificatePassword: nil  // Will use default
                )
                ServerManager.shared.addServer(server)
                await MainActor.run { dismiss() }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
                csrService.reset()
                qrService.reset()
            }
        }
    }
}

// MARK: - Edit Server View

struct EditServerView: View {
    @Environment(\.dismiss) private var dismiss

    let server: TAKServer

    @State private var name: String = ""
    @State private var host: String = ""
    @State private var port: String = ""
    @State private var protocolType: String = ""
    @State private var useTLS: Bool = false
    @State private var allowLegacyTLS: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Server Name", text: $name)
                    TextField("Host", text: $host)
                        .autocapitalization(.none)
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Server Details")
                }

                Section {
                    Picker("Protocol", selection: $protocolType) {
                        Text("TCP").tag("tcp")
                        Text("UDP").tag("udp")
                        Text("TLS/SSL").tag("ssl")
                    }

                    Toggle("Use TLS", isOn: $useTLS)
                    Toggle("Allow Legacy TLS (1.0/1.1)", isOn: $allowLegacyTLS)
                } header: {
                    Text("Connection")
                } footer: {
                    if allowLegacyTLS {
                        Text("Warning: Legacy TLS is less secure and should only be used with very old servers.")
                            .foregroundColor(.orange)
                    }
                }

                if let certName = server.certificateName {
                    Section {
                        HStack {
                            Text("Certificate")
                            Spacer()
                            Text(certName)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        Text("Authentication")
                    }
                }
            }
            .navigationTitle("Edit Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
            .onAppear {
                loadServerData()
            }
        }
    }

    private func loadServerData() {
        name = server.name
        host = server.host
        port = String(server.port)
        protocolType = server.protocolType
        useTLS = server.useTLS
        allowLegacyTLS = server.allowLegacyTLS
    }

    private func saveChanges() {
        var updated = server
        updated.name = name
        updated.host = host
        updated.port = UInt16(port) ?? server.port
        updated.protocolType = protocolType
        updated.useTLS = useTLS
        updated.allowLegacyTLS = allowLegacyTLS

        ServerManager.shared.updateServer(updated)
        dismiss()
    }
}

// MARK: - Server Row View

struct ServerRowView: View {
    let server: TAKServer
    let isActive: Bool
    let onSetActive: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(server.name)
                        .font(.headline)
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }

                Text("\(server.host):\(server.port)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Label(server.protocolType.uppercased(), systemImage: protocolIcon)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    if server.useTLS {
                        Label("TLS", systemImage: "lock.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }

                    if server.certificateName != nil {
                        Label("Cert", systemImage: "key.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            Menu {
                Button {
                    onSetActive()
                } label: {
                    Label("Set Active", systemImage: "checkmark.circle")
                }

                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSetActive()
        }
    }

    private var protocolIcon: String {
        switch server.protocolType.lowercased() {
        case "tcp": return "network"
        case "udp": return "antenna.radiowaves.left.and.right"
        case "ssl", "tls": return "lock.shield"
        default: return "questionmark.circle"
        }
    }
}

// MARK: - Certificate Row View

struct CertificateRowView: View {
    let certificate: TAKCertificate

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(certificate.displayName)
                .font(.headline)

            Text(certificate.serverURL)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                if let expiry = certificate.expiryDate {
                    if certificate.isExpired {
                        Label("Expired", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                    } else {
                        Label("Expires \(expiry, style: .relative)", systemImage: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                if let issuer = certificate.issuer {
                    Text("Issued by \(issuer)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - QR Code Scanner View

struct QRCodeScannerView: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onCodeScanned = onCodeScanned
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var onCodeScanned: ((String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    private func setupCamera() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            showAlert(message: "Camera not available")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            captureSession = AVCaptureSession()
            captureSession?.addInput(input)

            let output = AVCaptureMetadataOutput()
            captureSession?.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            previewLayer?.frame = view.layer.bounds
            previewLayer?.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer!)

            // Add scanning frame overlay
            let overlayView = UIView(frame: view.bounds)
            overlayView.backgroundColor = .clear
            view.addSubview(overlayView)

            let frameSize: CGFloat = 250
            let frameX = (view.bounds.width - frameSize) / 2
            let frameY = (view.bounds.height - frameSize) / 2

            let frameLayer = CAShapeLayer()
            let framePath = UIBezierPath(roundedRect: CGRect(x: frameX, y: frameY, width: frameSize, height: frameSize), cornerRadius: 10)
            frameLayer.path = framePath.cgPath
            frameLayer.strokeColor = UIColor.white.cgColor
            frameLayer.fillColor = UIColor.clear.cgColor
            frameLayer.lineWidth = 3
            overlayView.layer.addSublayer(frameLayer)

        } catch {
            showAlert(message: "Failed to setup camera: \(error.localizedDescription)")
        }
    }

    private func startScanning() {
        DispatchQueue.global(qos: .background).async {
            self.captureSession?.startRunning()
        }
    }

    private func stopScanning() {
        captureSession?.stopRunning()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let stringValue = object.stringValue else { return }

        // Vibrate on success
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))

        stopScanning()
        onCodeScanned?(stringValue)
        dismiss(animated: true)
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(title: "Scanner", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
}

// MARK: - Preview

#if DEBUG
struct ServerConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        ServerConfigurationView()
    }
}
#endif
