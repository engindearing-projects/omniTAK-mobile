//
//  CertificateEnrollmentView.swift
//  OmniTAKMobile
//
//  QR code-based certificate enrollment UI for TAK servers
//

import SwiftUI
import AVFoundation

// MARK: - Certificate Enrollment View

struct CertificateEnrollmentView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var enrollmentService = CertificateEnrollmentService.shared
    @StateObject private var qrScanner = QRScannerViewModel()

    @State private var showManualEntry = false
    @State private var scannedURL = ""
    @State private var certificatePassword = ""
    @State private var showPasswordPrompt = false
    @State private var enrollmentTask: Task<Void, Never>?
    @State private var enrolledServer: TAKServer?
    @State private var showSuccessAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                // ATAK dark background
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    enrollmentHeader

                    if showManualEntry {
                        manualEntryView
                    } else {
                        qrScannerView
                    }

                    // Progress indicator
                    if enrollmentService.progress.isInProgress {
                        progressView
                    }

                    Spacer()

                    // Toggle between scan and manual entry
                    toggleButton
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        enrollmentTask?.cancel()
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
            .sheet(isPresented: $showPasswordPrompt) {
                passwordPromptSheet
            }
            .alert("Enrollment Successful", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                if let server = enrolledServer {
                    Text("Successfully enrolled with \(server.name). The server has been added to your server list.")
                } else {
                    Text("Certificate enrollment completed successfully.")
                }
            }
            .onDisappear {
                qrScanner.stopScanning()
                enrollmentService.reset()
            }
        }
    }

    // MARK: - Header

    private var enrollmentHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#FFFC00"))

            Text("Certificate Enrollment")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text(showManualEntry ? "Enter enrollment details manually" : "Scan QR code from TAK server")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#CCCCCC"))
        }
        .padding(.vertical, 24)
    }

    // MARK: - QR Scanner View

    private var qrScannerView: some View {
        VStack(spacing: 16) {
            // Camera preview
            ZStack {
                if qrScanner.isAuthorized {
                    QRScannerPreview(session: qrScanner.captureSession)
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "#FFFC00"), lineWidth: 2)
                        )

                    // Scanning overlay
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(Color(hex: "#FFFC00").opacity(0.3))
                            .frame(height: 2)
                            .offset(y: qrScanner.scanLineOffset)
                    }
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Color(hex: "#CCCCCC"))

                        Text("Camera Access Required")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)

                        Text("Please enable camera access in Settings to scan QR codes")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#CCCCCC"))
                            .multilineTextAlignment(.center)

                        Button("Open Settings") {
                            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsURL)
                            }
                        }
                        .foregroundColor(Color(hex: "#FFFC00"))
                        .padding(.top, 8)
                    }
                    .frame(height: 280)
                    .frame(maxWidth: .infinity)
                    .background(Color(white: 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 24)

            // Status text
            Text(qrScanner.statusMessage)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#CCCCCC"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .onAppear {
            qrScanner.checkPermissions()
            qrScanner.onQRCodeScanned = { code in
                handleScannedCode(code)
            }
        }
    }

    // MARK: - Manual Entry View

    private var manualEntryView: some View {
        ManualEnrollmentEntryView(
            onEnroll: { server, port, truststore, usercert, password in
                startManualEnrollment(server: server, port: port, truststoreURL: truststore, usercertURL: usercert, password: password)
            }
        )
    }

    // MARK: - Progress View

    private var progressView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#FFFC00")))
                .scaleEffect(1.2)

            Text(enrollmentService.progress.description)
                .font(.system(size: 14))
                .foregroundColor(.white)
        }
        .padding()
        .background(Color(white: 0.15))
        .cornerRadius(12)
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    // MARK: - Toggle Button

    private var toggleButton: some View {
        Button(action: {
            withAnimation {
                showManualEntry.toggle()
                if !showManualEntry {
                    qrScanner.startScanning()
                } else {
                    qrScanner.stopScanning()
                }
            }
        }) {
            HStack {
                Image(systemName: showManualEntry ? "qrcode.viewfinder" : "keyboard")
                    .font(.system(size: 16))
                Text(showManualEntry ? "Scan QR Code" : "Manual Entry")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(Color(hex: "#FFFC00"))
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(Color(white: 0.15))
            .cornerRadius(8)
        }
        .padding(.bottom, 32)
    }

    // MARK: - Password Prompt Sheet

    private var passwordPromptSheet: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: "#FFFC00"))

                    Text("Certificate Password")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Text("Enter the password for the P12 certificate")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                        .multilineTextAlignment(.center)

                    SecureField("Password", text: $certificatePassword)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal, 32)

                    Button(action: {
                        showPasswordPrompt = false
                        startEnrollment(with: scannedURL, password: certificatePassword)
                    }) {
                        Text("Enroll")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "#FFFC00"))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                    .disabled(certificatePassword.isEmpty)

                    Spacer()
                }
                .padding(.top, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showPasswordPrompt = false
                        certificatePassword = ""
                        qrScanner.startScanning()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        }
    }

    // MARK: - Actions

    private func handleScannedCode(_ code: String) {
        qrScanner.stopScanning()
        scannedURL = code
        showPasswordPrompt = true
    }

    private func startEnrollment(with urlString: String, password: String) {
        enrollmentTask = Task {
            do {
                let server = try await enrollmentService.enrollFromQRCode(urlString, password: password)
                await MainActor.run {
                    enrolledServer = server
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    enrollmentService.progress = .failed(error.localizedDescription)
                }
                // Allow retry
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    enrollmentService.reset()
                    qrScanner.startScanning()
                }
            }
        }
    }

    private func startManualEnrollment(server: String, port: Int, truststoreURL: String, usercertURL: String, password: String) {
        enrollmentTask = Task {
            do {
                let serverConfig = try await enrollmentService.enrollFromManualEntry(
                    server: server,
                    port: port,
                    truststoreURL: truststoreURL,
                    usercertURL: usercertURL,
                    password: password
                )
                await MainActor.run {
                    enrolledServer = serverConfig
                    showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    enrollmentService.progress = .failed(error.localizedDescription)
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    enrollmentService.reset()
                }
            }
        }
    }
}

// MARK: - Manual Entry Form

struct ManualEnrollmentEntryView: View {
    @State private var serverHost = ""
    @State private var serverPort = "8443"
    @State private var truststoreURL = ""
    @State private var usercertURL = ""
    @State private var password = ""

    var onEnroll: (String, Int, String, String, String) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Server details
                VStack(alignment: .leading, spacing: 8) {
                    Text("Server Host")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#CCCCCC"))

                    TextField("e.g., tak.example.com", text: $serverHost)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Port")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#CCCCCC"))

                    TextField("8443", text: $serverPort)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Trust Store URL")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#CCCCCC"))

                    TextField("https://...", text: $truststoreURL)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("User Certificate URL")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#CCCCCC"))

                    TextField("https://...", text: $usercertURL)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Certificate Password")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#CCCCCC"))

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }

                Button(action: {
                    let port = Int(serverPort) ?? 8443
                    onEnroll(serverHost, port, truststoreURL, usercertURL, password)
                }) {
                    Text("Enroll")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#FFFC00"))
                        .cornerRadius(12)
                }
                .disabled(!isFormValid)
                .opacity(isFormValid ? 1.0 : 0.5)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
    }

    private var isFormValid: Bool {
        !serverHost.isEmpty && !truststoreURL.isEmpty && !usercertURL.isEmpty && !password.isEmpty
    }
}

// MARK: - QR Scanner ViewModel

class QRScannerViewModel: NSObject, ObservableObject, AVCaptureMetadataOutputObjectsDelegate {
    @Published var isAuthorized = false
    @Published var statusMessage = "Position QR code within frame"
    @Published var scanLineOffset: CGFloat = -140

    let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var animationTimer: Timer?

    var onQRCodeScanned: ((String) -> Void)?

    override init() {
        super.init()
        startScanAnimation()
    }

    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupCaptureSession()
                    }
                }
            }
        case .denied, .restricted:
            isAuthorized = false
            statusMessage = "Camera access denied"
        @unknown default:
            isAuthorized = false
        }
    }

    private func setupCaptureSession() {
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            statusMessage = "No camera available"
            return
        }

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            statusMessage = "Failed to access camera"
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            statusMessage = "Cannot add camera input"
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            statusMessage = "Cannot add metadata output"
            return
        }

        startScanning()
    }

    func startScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
        DispatchQueue.main.async {
            self.statusMessage = "Position QR code within frame"
        }
    }

    func stopScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           metadataObject.type == .qr,
           let stringValue = metadataObject.stringValue {

            // Validate TAK enrollment URL format
            if stringValue.hasPrefix("tak://enroll") {
                statusMessage = "QR code detected!"
                onQRCodeScanned?(stringValue)
            } else {
                statusMessage = "Invalid TAK enrollment QR code"
            }
        }
    }

    private func startScanAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.scanLineOffset += 2
                if self.scanLineOffset > 140 {
                    self.scanLineOffset = -140
                }
            }
        }
    }

    deinit {
        animationTimer?.invalidate()
    }
}

// MARK: - QR Scanner Preview

struct QRScannerPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        context.coordinator.previewLayer = previewLayer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}

// MARK: - Preview

#if DEBUG
struct CertificateEnrollmentView_Previews: PreviewProvider {
    static var previews: some View {
        CertificateEnrollmentView()
            .preferredColorScheme(.dark)
    }
}
#endif
