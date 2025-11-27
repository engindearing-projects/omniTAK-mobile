//
//  SimpleEnrollView.swift
//  OmniTAKMobile
//
//  Simplified TAK server CSR enrollment view
//  Server + Username + Password → Connect → Done!
//

import SwiftUI

// MARK: - Enrollment State

enum EnrollmentState: Equatable {
    case idle
    case connecting
    case fetchingConfig
    case generatingCSR
    case submittingCSR
    case storingCertificate
    case creatingServer
    case success
    case failed(String)

    var stepNumber: Int {
        switch self {
        case .idle: return 0
        case .connecting: return 1
        case .fetchingConfig: return 2
        case .generatingCSR: return 3
        case .submittingCSR: return 4
        case .storingCertificate: return 5
        case .creatingServer: return 6
        case .success: return 7
        case .failed: return -1
        }
    }

    var isInProgress: Bool {
        switch self {
        case .idle, .success, .failed: return false
        default: return true
        }
    }
}

// MARK: - Simple Enroll View

struct SimpleEnrollView: View {
    @Environment(\.dismiss) private var dismiss

    // Form fields
    @State private var serverHost = "public.opentakserver.io"
    @State private var username = ""
    @State private var password = ""
    @State private var showPassword = false

    // Advanced options (collapsed by default)
    @State private var showAdvanced = false
    @State private var streamingPort = "8089"
    @State private var enrollmentPort = "8446"  // TAK Server standard CSR enrollment port
    @State private var allowLegacyTLS = false

    // UI state
    @State private var enrollmentState: EnrollmentState = .idle
    @State private var showQRScanner = false

    // Services
    private let csrService = CSREnrollmentService()

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection

                        // Main form
                        if enrollmentState == .idle || enrollmentState == .failed("") || isFailed {
                            formSection

                            // Connect button
                            connectButton

                            // Advanced options
                            advancedSection

                            // Divider + QR option
                            orDivider
                            qrCodeOption
                        }

                        // Progress display
                        if enrollmentState.isInProgress {
                            progressSection
                        }

                        // Success display
                        if enrollmentState == .success {
                            successSection
                        }

                        // Error display
                        if case .failed(let message) = enrollmentState {
                            errorSection(message)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        }
        .sheet(isPresented: $showQRScanner) {
            CertificateEnrollmentView()
        }
    }

    private var isFailed: Bool {
        if case .failed = enrollmentState { return true }
        return false
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#FFFC00").opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(Color(hex: "#FFFC00"))
            }

            Text("Connect to TAK Server")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)

            Text("Enter your server credentials to get started")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "#CCCCCC"))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: 16) {
            // Server Host
            VStack(alignment: .leading, spacing: 8) {
                Text("Server")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#CCCCCC"))

                TextField("public.opentakserver.io", text: $serverHost)
                    .textFieldStyle(TAKTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
            }

            // Username
            VStack(alignment: .leading, spacing: 8) {
                Text("Username")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#CCCCCC"))

                TextField("Enter username", text: $username)
                    .textFieldStyle(TAKTextFieldStyle())
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }

            // Password
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#CCCCCC"))

                HStack(spacing: 0) {
                    if showPassword {
                        TextField("Enter password", text: $password)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    } else {
                        SecureField("Enter password", text: $password)
                    }

                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(Color(hex: "#666666"))
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.leading, 16)
                .background(Color(white: 0.12))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(white: 0.25), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Connect Button

    private var connectButton: some View {
        Button(action: startEnrollment) {
            HStack(spacing: 10) {
                if enrollmentState.isInProgress {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                }

                Text(enrollmentState.isInProgress ? "Connecting..." : "Connect to Server")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isFormValid ? Color(hex: "#FFFC00") : Color(hex: "#666666"))
            .cornerRadius(12)
        }
        .disabled(!isFormValid || enrollmentState.isInProgress)
    }

    private var isFormValid: Bool {
        !serverHost.isEmpty && !username.isEmpty && !password.isEmpty
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        VStack(spacing: 12) {
            Button(action: { withAnimation(.spring(response: 0.3)) { showAdvanced.toggle() } }) {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(Color(hex: "#666666"))

                    Text("Advanced Options")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "#CCCCCC"))

                    Spacer()

                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#666666"))
                }
                .padding(16)
                .background(Color(white: 0.08))
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())

            if showAdvanced {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        // Streaming Port
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Streaming Port")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#999999"))

                            TextField("8089", text: $streamingPort)
                                .textFieldStyle(TAKTextFieldStyle())
                                .keyboardType(.numberPad)
                        }

                        // Enrollment Port
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enrollment Port")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#999999"))

                            TextField("8446", text: $enrollmentPort)
                                .textFieldStyle(TAKTextFieldStyle())
                                .keyboardType(.numberPad)
                        }
                    }

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
                }
                .padding(16)
                .background(Color(white: 0.08))
                .cornerRadius(10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - OR Divider

    private var orDivider: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(Color(white: 0.2))
                .frame(height: 1)

            Text("OR")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#666666"))

            Rectangle()
                .fill(Color(white: 0.2))
                .frame(height: 1)
        }
        .padding(.vertical, 8)
    }

    // MARK: - QR Code Option

    private var qrCodeOption: some View {
        Button(action: { showQRScanner = true }) {
            HStack(spacing: 12) {
                Image(systemName: "qrcode.viewfinder")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#FFFC00"))

                Text("Scan QR Code Instead")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#CCCCCC"))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#666666"))
            }
            .padding(16)
            .background(Color(white: 0.08))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(white: 0.15), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 20) {
            // Progress header
            HStack {
                Text("Enrolling with Server")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#FFFC00")))
            }

            // Step indicators
            VStack(spacing: 12) {
                EnrollmentStepRow(step: 1, label: "Connecting to server", currentStep: enrollmentState.stepNumber)
                EnrollmentStepRow(step: 2, label: "Fetching CA configuration", currentStep: enrollmentState.stepNumber)
                EnrollmentStepRow(step: 3, label: "Generating certificate request", currentStep: enrollmentState.stepNumber)
                EnrollmentStepRow(step: 4, label: "Submitting to server", currentStep: enrollmentState.stepNumber)
                EnrollmentStepRow(step: 5, label: "Storing certificate", currentStep: enrollmentState.stepNumber)
                EnrollmentStepRow(step: 6, label: "Creating server config", currentStep: enrollmentState.stepNumber)
            }
        }
        .padding(20)
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }

    // MARK: - Success Section

    private var successSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "#00FF00"))

            VStack(spacing: 8) {
                Text("Connected!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("You're now connected to \(serverHost)")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "#CCCCCC"))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.1))
        .cornerRadius(12)
        .onAppear {
            // Auto-dismiss after success
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dismiss()
            }
        }
    }

    // MARK: - Error Section

    private func errorSection(_ message: String) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#FF6B6B"))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connection Failed")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        // Parse formatted error message (title\n\nmessage\n\nsteps)
                        let parts = message.components(separatedBy: "\n\n")
                        if parts.count >= 2 {
                            VStack(alignment: .leading, spacing: 12) {
                                // Error title
                                Text(parts[0])
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "#FFAAAA"))
                                    .fixedSize(horizontal: false, vertical: true)

                                // Error message
                                if parts.count >= 2 && !parts[1].isEmpty {
                                    Text(parts[1])
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(hex: "#CCCCCC"))
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                // Troubleshooting steps
                                if parts.count >= 3 && !parts[2].isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "wrench.and.screwdriver")
                                                .foregroundColor(Color(hex: "#FFFC00"))
                                                .font(.system(size: 12))
                                            Text("Troubleshooting")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.white)
                                        }

                                        ForEach(parts[2].components(separatedBy: "\n"), id: \.self) { step in
                                            if !step.isEmpty {
                                                Text(step)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(Color(hex: "#AAAAAA"))
                                                    .fixedSize(horizontal: false, vertical: true)
                                                    .padding(.leading, step.hasPrefix("•") || step.hasPrefix("1.") ? 12 : 0)
                                            }
                                        }
                                    }
                                    .padding(12)
                                    .background(Color(white: 0.08))
                                    .cornerRadius(8)
                                }
                            }
                        } else {
                            // Fallback for simple error messages
                            Text(message)
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#CCCCCC"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 0)
                }

                Button(action: { enrollmentState = .idle }) {
                    Text("Try Again")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(hex: "#FF6B6B"))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: "#FF6B6B"), lineWidth: 1)
                        )
                }
            }
            .padding(16)
        }
        .frame(maxHeight: 400)
        .background(Color(hex: "#FF6B6B").opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#FF6B6B").opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Enrollment Action

    private func startEnrollment() {
        guard isFormValid else { return }

        // Hide keyboard
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        Task {
            await performEnrollment()
        }
    }

    private func performEnrollment() async {
        await MainActor.run { enrollmentState = .connecting }

        do {
            // Update progress states
            await MainActor.run { enrollmentState = .fetchingConfig }
            try await Task.sleep(nanoseconds: 300_000_000) // Brief delay for UI feedback

            await MainActor.run { enrollmentState = .generatingCSR }
            try await Task.sleep(nanoseconds: 200_000_000)

            await MainActor.run { enrollmentState = .submittingCSR }

            // Perform actual enrollment
            let port = Int(streamingPort) ?? 8089
            let enrollPort = Int(enrollmentPort) ?? 8446

            let server = try await csrService.enroll(
                server: serverHost,
                port: port,
                enrollmentPort: enrollPort,
                username: username,
                password: password
            )

            await MainActor.run { enrollmentState = .storingCertificate }
            try await Task.sleep(nanoseconds: 200_000_000)

            await MainActor.run { enrollmentState = .creatingServer }
            try await Task.sleep(nanoseconds: 200_000_000)

            // Set as active server and connect
            await MainActor.run {
                ServerManager.shared.setActiveServer(server)

                // Actually connect to the server
                TAKService.shared.connect(
                    host: server.host,
                    port: server.port,
                    protocolType: server.protocolType,
                    useTLS: server.useTLS,
                    certificateName: server.certificateName,
                    certificatePassword: server.certificatePassword
                )

                enrollmentState = .success
            }

            print("[SimpleEnroll] Enrollment successful for \(serverHost)")

        } catch {
            await MainActor.run {
                let errorMessage = error.localizedDescription
                enrollmentState = .failed(errorMessage)
            }
            print("[SimpleEnroll] Enrollment failed: \(error)")
        }
    }
}

// MARK: - Enrollment Step Row

struct EnrollmentStepRow: View {
    let step: Int
    let label: String
    let currentStep: Int

    private var isComplete: Bool { currentStep > step }
    private var isActive: Bool { currentStep == step }
    private var isPending: Bool { currentStep < step }

    var body: some View {
        HStack(spacing: 12) {
            // Step indicator
            ZStack {
                if isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "#00FF00"))
                } else if isActive {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#FFFC00")))
                        .scaleEffect(0.8)
                        .frame(width: 20, height: 20)
                } else {
                    Circle()
                        .stroke(Color(white: 0.3), lineWidth: 2)
                        .frame(width: 20, height: 20)
                }
            }
            .frame(width: 24)

            // Label
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(isComplete ? Color(hex: "#00FF00") : (isActive ? .white : Color(hex: "#666666")))

            Spacer()
        }
    }
}

// MARK: - TAK Text Field Style

struct TAKTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(white: 0.12))
            .cornerRadius(10)
            .foregroundColor(.white)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(white: 0.25), lineWidth: 1)
            )
    }
}

// MARK: - Simple Enroll View Content (Embeddable)

struct SimpleEnrollViewContent: View {
    @Environment(\.dismiss) private var dismiss

    // Form fields
    @State private var serverHost = "public.opentakserver.io"
    @State private var username = ""
    @State private var password = ""
    @State private var showPassword = false

    // Advanced options (collapsed by default)
    @State private var showAdvanced = false
    @State private var streamingPort = "8089"
    @State private var enrollmentPort = "8446"  // TAK Server standard CSR enrollment port
    @State private var allowLegacyTLS = false

    // UI state
    @State private var enrollmentState: EnrollmentState = .idle
    @State private var showQRScanner = false

    // Services
    private let csrService = CSREnrollmentService()

    private var isFailed: Bool {
        if case .failed = enrollmentState { return true }
        return false
    }

    private var isFormValid: Bool {
        !serverHost.isEmpty && !username.isEmpty && !password.isEmpty
    }

    var body: some View {
        VStack(spacing: 20) {
            // Feature card
            FeatureCard(
                icon: "person.badge.key.fill",
                title: "Sign In to TAK Server",
                description: "Enter your server credentials to enroll and connect automatically.",
                color: Color(hex: "#FFFC00")
            )

            // Main form (only show when idle or failed)
            if enrollmentState == .idle || isFailed {
                formSection
                connectButton
                advancedSection
            }

            // Progress display
            if enrollmentState.isInProgress {
                progressSection
            }

            // Success display
            if enrollmentState == .success {
                successSection
            }

            // Error display
            if case .failed(let message) = enrollmentState {
                errorSection(message)
            }
        }
        .sheet(isPresented: $showQRScanner) {
            CertificateEnrollmentView()
        }
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: 16) {
            // Server Host
            FormField(label: "Server", text: $serverHost, placeholder: "public.opentakserver.io")

            // Username
            FormField(label: "Username", text: $username, placeholder: "Enter username")

            // Password with show/hide
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#CCCCCC"))

                HStack(spacing: 0) {
                    if showPassword {
                        TextField("Enter password", text: $password)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    } else {
                        SecureField("Enter password", text: $password)
                    }

                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(Color(hex: "#666666"))
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.leading, 16)
                .background(Color(white: 0.12))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(white: 0.25), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Connect Button

    private var connectButton: some View {
        Button(action: startEnrollment) {
            HStack(spacing: 10) {
                if enrollmentState.isInProgress {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20))
                }

                Text(enrollmentState.isInProgress ? "Connecting..." : "Connect to Server")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isFormValid ? Color(hex: "#FFFC00") : Color(hex: "#666666"))
            .cornerRadius(12)
        }
        .disabled(!isFormValid || enrollmentState.isInProgress)
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        VStack(spacing: 12) {
            Button(action: { withAnimation(.spring(response: 0.3)) { showAdvanced.toggle() } }) {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(Color(hex: "#666666"))

                    Text("Advanced Options")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(hex: "#CCCCCC"))

                    Spacer()

                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#666666"))
                }
                .padding(16)
                .background(Color(white: 0.08))
                .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())

            if showAdvanced {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        FormField(label: "Streaming Port", text: $streamingPort, placeholder: "8089", keyboardType: .numberPad)
                        FormField(label: "Enrollment Port", text: $enrollmentPort, placeholder: "8446", keyboardType: .numberPad)
                    }

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
                }
                .padding(16)
                .background(Color(white: 0.08))
                .cornerRadius(10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Enrolling with Server")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#FFFC00")))
            }

            VStack(spacing: 12) {
                EnrollmentStepRow(step: 1, label: "Connecting to server", currentStep: enrollmentState.stepNumber)
                EnrollmentStepRow(step: 2, label: "Fetching CA configuration", currentStep: enrollmentState.stepNumber)
                EnrollmentStepRow(step: 3, label: "Generating certificate request", currentStep: enrollmentState.stepNumber)
                EnrollmentStepRow(step: 4, label: "Submitting to server", currentStep: enrollmentState.stepNumber)
                EnrollmentStepRow(step: 5, label: "Storing certificate", currentStep: enrollmentState.stepNumber)
                EnrollmentStepRow(step: 6, label: "Creating server config", currentStep: enrollmentState.stepNumber)
            }
        }
        .padding(20)
        .background(Color(white: 0.1))
        .cornerRadius(12)
    }

    // MARK: - Success Section

    private var successSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "#00FF00"))

            VStack(spacing: 8) {
                Text("Connected!")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("You're now connected to \(serverHost)")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "#CCCCCC"))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color(white: 0.1))
        .cornerRadius(12)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                dismiss()
            }
        }
    }

    // MARK: - Error Section

    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#FF6B6B"))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Connection Failed")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text(message)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            Button(action: { enrollmentState = .idle }) {
                Text("Try Again")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(hex: "#FF6B6B"))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(hex: "#FF6B6B"), lineWidth: 1)
                    )
            }
        }
        .padding(16)
        .background(Color(hex: "#FF6B6B").opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#FF6B6B").opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Enrollment Action

    private func startEnrollment() {
        guard isFormValid else { return }

        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        Task {
            await performEnrollment()
        }
    }

    private func performEnrollment() async {
        await MainActor.run { enrollmentState = .connecting }

        do {
            await MainActor.run { enrollmentState = .fetchingConfig }
            try await Task.sleep(nanoseconds: 300_000_000)

            await MainActor.run { enrollmentState = .generatingCSR }
            try await Task.sleep(nanoseconds: 200_000_000)

            await MainActor.run { enrollmentState = .submittingCSR }

            let port = Int(streamingPort) ?? 8089
            let enrollPort = Int(enrollmentPort) ?? 8446

            let server = try await csrService.enroll(
                server: serverHost,
                port: port,
                enrollmentPort: enrollPort,
                username: username,
                password: password
            )

            await MainActor.run { enrollmentState = .storingCertificate }
            try await Task.sleep(nanoseconds: 200_000_000)

            await MainActor.run { enrollmentState = .creatingServer }
            try await Task.sleep(nanoseconds: 200_000_000)

            await MainActor.run {
                ServerManager.shared.setActiveServer(server)

                // Actually connect to the server
                TAKService.shared.connect(
                    host: server.host,
                    port: server.port,
                    protocolType: server.protocolType,
                    useTLS: server.useTLS,
                    certificateName: server.certificateName,
                    certificatePassword: server.certificatePassword
                )

                enrollmentState = .success
            }

            print("[SimpleEnroll] Enrollment successful for \(serverHost)")

        } catch {
            await MainActor.run {
                let errorMessage = error.localizedDescription
                enrollmentState = .failed(errorMessage)
            }
            print("[SimpleEnroll] Enrollment failed: \(error)")
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SimpleEnrollView_Previews: PreviewProvider {
    static var previews: some View {
        SimpleEnrollView()
            .preferredColorScheme(.dark)
    }
}
#endif
