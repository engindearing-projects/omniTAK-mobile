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

    var onEnrollmentComplete: ((UUID, String) -> Void)?

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

                    // Progress indicator or error display
                    if enrollmentService.progress.isInProgress {
                        progressView
                    } else if case .failed(let error) = enrollmentService.progress {
                        errorView(error)
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
                    // Call completion callback if provided
                    if let server = enrolledServer,
                       let certName = server.certificateName,
                       let callback = onEnrollmentComplete {
                        // Generate a certificate ID from the server's certificate
                        let certificateId = UUID()
                        callback(certificateId, certName)
                    }
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
                if qrScanner.isInitializing {
                    // Loading state
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#FFFC00")))
                            .scaleEffect(1.5)

                        Text("Initializing camera...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(height: 280)
                    .frame(maxWidth: .infinity)
                    .background(Color(white: 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } else if qrScanner.isAuthorized && !qrScanner.hasCameraError {
                    ZStack {
                        QRScannerPreview(session: qrScanner.captureSession)
                            .frame(height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(hex: "#FFFC00"), lineWidth: 2)
                            )
                            .onAppear {
                                // Extra safety: ensure session starts when preview appears
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    if !qrScanner.captureSession.isRunning {
                                        #if DEBUG
                                        print("📸 QR Scanner: Preview appeared but session not running, restarting...")
                                        #endif
                                        qrScanner.startScanning()
                                    }
                                }
                            }
                    }

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
                    // Error or permission denied state
                    VStack(spacing: 12) {
                        Image(systemName: qrScanner.hasCameraError ? "exclamationmark.camera.fill" : "camera.fill")
                            .font(.system(size: 40))
                            .foregroundColor(qrScanner.hasCameraError ? Color(hex: "#FF6B6B") : Color(hex: "#CCCCCC"))

                        Text(qrScanner.hasCameraError ? "Camera Unavailable" : "Camera Access Required")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)

                        Text(qrScanner.statusMessage)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#CCCCCC"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)

                        HStack(spacing: 12) {
                            if !qrScanner.isAuthorized {
                                Button("Open Settings") {
                                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(settingsURL)
                                    }
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(hex: "#FFFC00"))
                                .cornerRadius(8)
                            }

                            if qrScanner.hasCameraError {
                                Button("Retry") {
                                    qrScanner.retryCamera()
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(white: 0.3))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .frame(height: 280)
                    .frame(maxWidth: .infinity)
                    .background(Color(white: 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(.horizontal, 24)

            // Status text (only show when camera is working)
            if qrScanner.isAuthorized && !qrScanner.hasCameraError && !qrScanner.isInitializing {
                Text(qrScanner.statusMessage)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#CCCCCC"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Helpful hint when camera fails
            if qrScanner.hasCameraError {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(Color(hex: "#FFFC00"))
                        Text("Can't scan? Use Manual Entry")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Text("Tap the button below to enter server details manually instead")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                        .multilineTextAlignment(.center)
                }
                .padding(16)
                .background(Color(hex: "#FFFC00").opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#FFFC00").opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            // Set up callbacks first
            qrScanner.onQRCodeScanned = { code in
                handleScannedCode(code)
            }
            qrScanner.onCameraError = {
                // Auto-scroll to manual entry button would go here if needed
            }

            // Check permissions and start camera
            qrScanner.checkPermissions()
        }
        .onDisappear {
            // Pause scanning when view is hidden
            qrScanner.stopScanning()
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

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(.red)

            Text("Enrollment Failed")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Text(error)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#CCCCCC"))
                .multilineTextAlignment(.center)

            Button(action: {
                enrollmentService.reset()
                qrScanner.startScanning()
            }) {
                Text("Try Again")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#FFFC00"))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    // MARK: - Toggle Button

    private var toggleButton: some View {
        Button(action: {
            withAnimation {
                showManualEntry.toggle()
                if !showManualEntry {
                    // Switching back to QR scanner - restart camera
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        qrScanner.checkPermissions()
                        qrScanner.startScanning()
                    }
                } else {
                    // Switching to manual entry - stop camera
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
            .foregroundColor(qrScanner.hasCameraError && !showManualEntry ? .black : Color(hex: "#FFFC00"))
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(qrScanner.hasCameraError && !showManualEntry ? Color(hex: "#FFFC00") : Color(white: 0.15))
            .cornerRadius(8)
        }
        .padding(.bottom, 32)
        // Add animation to draw attention when camera fails
        .scaleEffect(qrScanner.hasCameraError && !showManualEntry ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: qrScanner.hasCameraError && !showManualEntry)
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
                        #if DEBUG
                        print("🔐 Certificate Enrollment: Starting enrollment with password")
                        print("🔐 Certificate Enrollment: URL = \(scannedURL)")
                        #endif
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

        #if DEBUG
        print("🔍 QR Code Handler: Processing scanned code")
        print("🔍 QR Code Handler: Code = \(code)")
        #endif

        // Check if this is a certificate enrollment URL
        if code.lowercased().contains("enroll") && code.lowercased().hasPrefix("http") {
            #if DEBUG
            print("🔍 QR Code Handler: Detected certificate enrollment URL")
            #endif
            showPasswordPrompt = true
        } else {
            // Try to parse as iTAK/ATAK connection details
            #if DEBUG
            print("🔍 QR Code Handler: Attempting to parse as connection details")
            #endif
            parseConnectionDetails(code)
        }
    }

    private func parseConnectionDetails(_ qrData: String) {
        // iTAK/ATAK QR codes can be JSON or other formats
        // Try parsing as JSON first
        if let jsonData = qrData.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            #if DEBUG
            print("🔍 Connection Parser: Parsed as JSON: \(json)")
            #endif
            addServerFromJSON(json)
        } else {
            // Try other formats or show password prompt as fallback
            #if DEBUG
            print("🔍 Connection Parser: Not JSON, treating as enrollment URL")
            #endif
            showPasswordPrompt = true
        }
    }

    private func addServerFromJSON(_ json: [String: Any]) {
        // Extract common fields from iTAK/ATAK connection QR codes
        let host = json["hostname"] as? String ?? json["host"] as? String ?? json["server"] as? String ?? ""
        let port = json["port"] as? Int ?? json["tcpPort"] as? Int ?? 8087
        let useTLS = json["useSSL"] as? Bool ?? json["useTLS"] as? Bool ?? false
        let serverName = json["name"] as? String ?? json["alias"] as? String ?? "TAK Server"

        #if DEBUG
        print("🔍 Connection Parser: Extracted - host=\(host), port=\(port), TLS=\(useTLS)")
        #endif

        guard !host.isEmpty else {
            #if DEBUG
            print("🔍 Connection Parser: No valid host found, showing password prompt")
            #endif
            showPasswordPrompt = true
            return
        }

        // Create and add the server
        let server = TAKServer(
            name: serverName,
            host: host,
            port: UInt16(port),
            protocolType: useTLS ? "ssl" : "tcp",
            useTLS: useTLS,
            isDefault: false
        )

        #if DEBUG
        print("🔍 Connection Parser: Adding server to ServerManager")
        #endif

        ServerManager.shared.addServer(server)
        ServerManager.shared.setActiveServer(server)

        // Show success
        enrolledServer = server
        showSuccessAlert = true
    }

    private func startEnrollment(with urlString: String, password: String) {
        #if DEBUG
        print("🔐 Certificate Enrollment: startEnrollment() called")
        #endif

        enrollmentTask = Task {
            do {
                #if DEBUG
                print("🔐 Certificate Enrollment: Calling enrollFromQRCode...")
                #endif
                let server = try await enrollmentService.enrollFromQRCode(urlString, password: password)
                #if DEBUG
                print("🔐 Certificate Enrollment: Success! Server = \(server.name)")
                #endif
                await MainActor.run {
                    enrolledServer = server
                    showSuccessAlert = true
                    #if DEBUG
                    print("🔐 Certificate Enrollment: Showing success alert")
                    #endif
                }
            } catch {
                #if DEBUG
                print("🔐 Certificate Enrollment: Error - \(error.localizedDescription)")
                #endif
                await MainActor.run {
                    enrollmentService.progress = .failed(error.localizedDescription)
                    #if DEBUG
                    print("🔐 Certificate Enrollment: Set progress to failed: \(error.localizedDescription)")
                    #endif
                }
                // Allow retry
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    enrollmentService.reset()
                    qrScanner.startScanning()
                    #if DEBUG
                    print("🔐 Certificate Enrollment: Reset and restarted scanning")
                    #endif
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
                    Text("Device Certificate URL")
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
    @Published var isInitializing = false
    @Published var hasCameraError = false

    let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var animationTimer: Timer?
    private var isSessionConfigured = false
    private var backgroundObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var interruptionEndObserver: NSObjectProtocol?
    private var retryCount = 0
    private let maxRetries = 2

    var onQRCodeScanned: ((String) -> Void)?
    var onCameraError: (() -> Void)?

    override init() {
        super.init()
        startScanAnimation()
        setupLifecycleObservers()
    }

    func checkPermissions() {
        #if DEBUG
        print("📸 QR Scanner: checkPermissions() called")
        #endif

        isInitializing = true

        // Check if running on simulator
        #if targetEnvironment(simulator)
        DispatchQueue.main.async {
            #if DEBUG
            print("📸 QR Scanner: Running on simulator - camera not available")
            #endif
            self.isInitializing = false
            self.isAuthorized = false
            self.hasCameraError = true
            self.statusMessage = "Camera not available on iOS Simulator. Please use manual entry or test on a real device."
            self.onCameraError?()
        }
        return
        #else
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        #if DEBUG
        print("📸 QR Scanner: Camera authorization status = \(authStatus.rawValue)")
        #endif

        switch authStatus {
        case .authorized:
            #if DEBUG
            print("📸 QR Scanner: Camera authorized, setting up capture session")
            #endif
            isAuthorized = true
            setupCaptureSession()
        case .notDetermined:
            #if DEBUG
            print("📸 QR Scanner: Camera permission not determined, requesting access")
            #endif
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    #if DEBUG
                    print("📸 QR Scanner: Camera access granted = \(granted)")
                    #endif
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupCaptureSession()
                    } else {
                        self?.isInitializing = false
                        self?.hasCameraError = true
                        self?.statusMessage = "Camera access denied. Please use manual entry below."
                        self?.onCameraError?()
                    }
                }
            }
        case .denied, .restricted:
            #if DEBUG
            print("📸 QR Scanner: Camera access denied or restricted")
            #endif
            isAuthorized = false
            hasCameraError = true
            statusMessage = "Camera access denied. Please enable in Settings or use manual entry."
            isInitializing = false
            onCameraError?()
        @unknown default:
            #if DEBUG
            print("📸 QR Scanner: Unknown camera authorization status")
            #endif
            isAuthorized = false
            hasCameraError = true
            isInitializing = false
            statusMessage = "Camera unavailable. Please use manual entry."
            onCameraError?()
        }
        #endif
    }

    func retryCamera() {
        retryCount = 0
        hasCameraError = false
        isSessionConfigured = false
        checkPermissions()
    }

    private func setupCaptureSession() {
        #if DEBUG
        print("📸 QR Scanner: setupCaptureSession() called")
        #endif

        // Avoid reconfiguring if already set up
        guard !isSessionConfigured else {
            #if DEBUG
            print("📸 QR Scanner: Session already configured, starting scanning")
            #endif
            DispatchQueue.main.async {
                self.isInitializing = false
            }
            startScanning()
            return
        }

        #if DEBUG
        print("📸 QR Scanner: Getting video capture device")
        #endif

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            handleCameraSetupError("No camera available on this device")
            return
        }

        #if DEBUG
        print("📸 QR Scanner: Video capture device obtained: \(videoCaptureDevice.localizedName)")
        #endif

        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            handleCameraSetupError("Failed to access camera: \(error.localizedDescription)")
            return
        }

        // Begin atomic configuration
        captureSession.beginConfiguration()

        // Set session preset for high quality video
        if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
            #if DEBUG
            print("📸 QR Scanner: Set session preset to .high")
            #endif
        }

        // Remove existing inputs/outputs if any
        for input in captureSession.inputs {
            captureSession.removeInput(input)
        }
        for output in captureSession.outputs {
            captureSession.removeOutput(output)
        }

        // Add video input
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            captureSession.commitConfiguration()
            handleCameraSetupError("Cannot configure camera input")
            return
        }

        // Add metadata output for QR detection
        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            captureSession.commitConfiguration()
            handleCameraSetupError("Cannot configure QR code detection")
            return
        }

        // Commit the configuration
        captureSession.commitConfiguration()
        isSessionConfigured = true

        #if DEBUG
        print("📸 QR Scanner: Capture session configured successfully")
        #endif

        DispatchQueue.main.async {
            self.isInitializing = false
            self.hasCameraError = false
            #if DEBUG
            print("📸 QR Scanner: Updated UI state - ready to scan")
            #endif
        }

        // Start scanning on success
        #if DEBUG
        print("📸 QR Scanner: Calling startScanning() after successful setup")
        #endif
        startScanning()
    }

    private func handleCameraSetupError(_ message: String) {
        DispatchQueue.main.async {
            self.isInitializing = false
            self.statusMessage = message

            // Auto-retry if we haven't exceeded max retries
            if self.retryCount < self.maxRetries {
                self.retryCount += 1
                self.statusMessage = "\(message) Retrying... (\(self.retryCount)/\(self.maxRetries))"

                // Retry after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.isSessionConfigured = false
                    self.setupCaptureSession()
                }
            } else {
                // Max retries exceeded, show error and suggest manual entry
                self.hasCameraError = true
                self.statusMessage = "\(message). Please use manual entry below."
                self.onCameraError?()
            }
        }
    }

    func startScanning() {
        #if DEBUG
        print("📸 QR Scanner: startScanning() called")
        print("📸 QR Scanner: isSessionConfigured = \(isSessionConfigured)")
        print("📸 QR Scanner: isAuthorized = \(isAuthorized)")
        print("📸 QR Scanner: hasCameraError = \(hasCameraError)")
        #endif

        guard isSessionConfigured else {
            #if DEBUG
            print("📸 QR Scanner: Session not configured, attempting setup...")
            #endif
            // Try to set up the session first
            setupCaptureSession()
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            #if DEBUG
            print("📸 QR Scanner: Capture session isRunning = \(self.captureSession.isRunning)")
            #endif
            // Only start if not already running
            if !self.captureSession.isRunning {
                #if DEBUG
                print("📸 QR Scanner: Starting capture session...")
                #endif
                self.captureSession.startRunning()
                DispatchQueue.main.async {
                    self.statusMessage = "Position QR code within frame"
                    #if DEBUG
                    print("📸 QR Scanner: Capture session started successfully")
                    #endif
                }
            } else {
                #if DEBUG
                print("📸 QR Scanner: Capture session already running")
                #endif
            }
        }
    }

    func stopScanning() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            // Only stop if currently running
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           metadataObject.type == .qr,
           let stringValue = metadataObject.stringValue {

            #if DEBUG
            print("📸 QR Scanner: Scanned QR code content: \(stringValue)")
            #endif

            // Accept any QR code - we'll validate the content in the handler
            statusMessage = "QR code detected!"
            #if DEBUG
            print("📸 QR Scanner: QR code detected, passing to handler")
            #endif
            onQRCodeScanned?(stringValue)
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

    private func setupLifecycleObservers() {
        // Handle app backgrounding - stop camera to avoid crashes
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopScanning()
        }

        // Handle app foregrounding - restart camera
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.startScanning()
        }

        // Handle session interruptions (e.g., phone calls, FaceTime)
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureSession.wasInterruptedNotification,
            object: captureSession,
            queue: .main
        ) { [weak self] notification in
            guard let reason = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? AVCaptureSession.InterruptionReason else {
                return
            }

            DispatchQueue.main.async {
                switch reason {
                case .videoDeviceNotAvailableInBackground:
                    self?.statusMessage = "Camera unavailable in background"
                case .audioDeviceInUseByAnotherClient:
                    self?.statusMessage = "Camera in use by another app"
                case .videoDeviceInUseByAnotherClient:
                    self?.statusMessage = "Camera in use by another app"
                case .videoDeviceNotAvailableWithMultipleForegroundApps:
                    self?.statusMessage = "Camera unavailable (multitasking)"
                case .videoDeviceNotAvailableDueToSystemPressure:
                    self?.statusMessage = "Camera unavailable (system pressure)"
                @unknown default:
                    self?.statusMessage = "Camera temporarily unavailable"
                }
            }
        }

        // Handle interruption end - restart camera
        interruptionEndObserver = NotificationCenter.default.addObserver(
            forName: AVCaptureSession.interruptionEndedNotification,
            object: captureSession,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.statusMessage = "Camera restored"
            }
            // Small delay before restarting
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.startScanning()
            }
        }
    }

    deinit {
        // Clean up timer
        animationTimer?.invalidate()

        // Stop camera session
        stopScanning()

        // Remove all observers
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = interruptionEndObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - QR Scanner Preview

struct QRScannerPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        context.coordinator.previewLayer = previewLayer

        #if DEBUG
        print("📸 QR Scanner Preview: Created preview layer for session: \(session)")
        print("📸 QR Scanner Preview: Session is running: \(session.isRunning)")
        #endif

        // Force initial layout
        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            if let previewLayer = context.coordinator.previewLayer {
                previewLayer.frame = uiView.bounds
                #if DEBUG
                print("📸 QR Scanner Preview: Updated frame to \(uiView.bounds)")
                print("📸 QR Scanner Preview: Session is running: \(self.session.isRunning)")
                #endif
            }
        }
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
