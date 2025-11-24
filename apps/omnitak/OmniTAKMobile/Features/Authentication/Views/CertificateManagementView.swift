//
//  CertificateManagementView.swift
//  OmniTAKMobile
//
//  Certificate management UI for viewing, importing, and managing certificates
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Certificate Management View

struct CertificateManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var certificateManager = CertificateManager.shared

    @State private var showImportSheet = false
    @State private var showEnrollmentView = false
    @State private var selectedCertificate: TAKCertificate?
    @State private var showDeleteAlert = false
    @State private var certificateToDelete: TAKCertificate?

    var body: some View {
        NavigationView {
            ZStack {
                // ATAK dark background
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    if certificateManager.certificates.isEmpty {
                        emptyStateView
                    } else {
                        certificateListView
                    }
                }
            }
            .navigationTitle("Certificates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showImportSheet = true }) {
                            Label("Import from File", systemImage: "doc.badge.plus")
                        }

                        Button(action: { showEnrollmentView = true }) {
                            Label("Enroll from Server", systemImage: "qrcode.viewfinder")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color(hex: "#FFFC00"))
                            .font(.system(size: 20))
                    }
                }
            }
            .sheet(isPresented: $showImportSheet) {
                CertificateImportSheet()
            }
            .sheet(isPresented: $showEnrollmentView) {
                CertificateEnrollmentView()
            }
            .sheet(item: $selectedCertificate) { certificate in
                CertificateDetailView(certificate: certificate)
            }
            .alert("Delete Certificate", isPresented: $showDeleteAlert, presenting: certificateToDelete) { cert in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    certificateManager.deleteCertificate(id: cert.id)
                }
            } message: { cert in
                Text("Are you sure you want to delete '\(cert.name)'? This action cannot be undone.")
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundColor(Color(hex: "#CCCCCC"))

            Text("No Certificates")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text("Import a certificate file or enroll with a TAK server to get started")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#CCCCCC"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 12) {
                Button(action: { showImportSheet = true }) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("Import from File")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#FFFC00"))
                    .cornerRadius(12)
                }

                Button(action: { showEnrollmentView = true }) {
                    HStack {
                        Image(systemName: "qrcode.viewfinder")
                        Text("Enroll from Server")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#FFFC00"))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(white: 0.15))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)

            Spacer()
        }
    }

    // MARK: - Certificate List

    private var certificateListView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(certificateManager.certificates) { certificate in
                    CertificateRow(
                        certificate: certificate,
                        onTap: { selectedCertificate = certificate },
                        onDelete: {
                            certificateToDelete = certificate
                            showDeleteAlert = true
                        }
                    )
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Certificate Row

struct CertificateRow: View {
    let certificate: TAKCertificate
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status icon
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: statusIcon)
                        .font(.system(size: 20))
                        .foregroundColor(statusColor)
                }

                // Certificate info
                VStack(alignment: .leading, spacing: 4) {
                    Text(certificate.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(certificate.username)
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(certificate.serverURL)
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#999999"))
                            .lineLimit(1)

                        if certificate.isExpired {
                            Text("• EXPIRED")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.red)
                        } else if let expiry = certificate.expiryDate {
                            Text("• Expires \(formatDate(expiry))")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#999999"))
                        }
                    }
                }

                Spacer()

                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.red.opacity(0.8))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(16)
            .background(Color(white: 0.12))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(statusColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var statusColor: Color {
        if certificate.isExpired {
            return .red
        } else if !certificate.isValid {
            return .orange
        } else {
            return Color(hex: "#00FF00")
        }
    }

    private var statusIcon: String {
        if certificate.isExpired {
            return "exclamationmark.triangle.fill"
        } else if !certificate.isValid {
            return "exclamationmark.circle.fill"
        } else {
            return "checkmark.shield.fill"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Certificate Detail View

struct CertificateDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let certificate: TAKCertificate

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Status header
                        VStack(spacing: 12) {
                            Image(systemName: certificate.isExpired ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                                .font(.system(size: 56))
                                .foregroundColor(certificate.isExpired ? .red : Color(hex: "#00FF00"))

                            Text(certificate.name)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            if certificate.isExpired {
                                Text("EXPIRED")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(Color.red)
                                    .cornerRadius(6)
                            } else {
                                Text("Valid")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .background(Color(hex: "#00FF00"))
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.top, 20)

                        // Details
                        VStack(spacing: 16) {
                            CertificateDetailRow(label: "Username", value: certificate.username)
                            CertificateDetailRow(label: "Server URL", value: certificate.serverURL)

                            if let issuer = certificate.issuer {
                                CertificateDetailRow(label: "Issuer", value: issuer)
                            }

                            CertificateDetailRow(label: "Created", value: formatDate(certificate.createdDate))

                            if let expiry = certificate.expiryDate {
                                CertificateDetailRow(label: "Expires", value: formatDate(expiry))

                                if !certificate.isExpired {
                                    let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0
                                    CertificateDetailRow(label: "Days Remaining", value: "\(daysRemaining) days")
                                }
                            }

                            CertificateDetailRow(label: "Certificate ID", value: certificate.id.uuidString)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct CertificateDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "#CCCCCC"))
                .textCase(.uppercase)

            Text(value)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(white: 0.12))
        .cornerRadius(8)
    }
}

// MARK: - Certificate Import Sheet

struct CertificateImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var certificateManager = CertificateManager.shared

    @State private var showFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var certificateName = ""
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = ""

    var onComplete: ((UUID, String) -> Void)?

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // File picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Certificate File (.p12)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#CCCCCC"))

                            Button(action: { showFilePicker = true }) {
                                HStack {
                                    Image(systemName: "doc.badge.plus")
                                    if let url = selectedFileURL {
                                        Text(url.lastPathComponent)
                                            .lineLimit(1)
                                    } else {
                                        Text("Select .p12 file")
                                    }
                                    Spacer()
                                }
                                .font(.system(size: 16))
                                .foregroundColor(selectedFileURL != nil ? .white : Color(hex: "#CCCCCC"))
                                .padding()
                                .background(Color(white: 0.15))
                                .cornerRadius(8)
                            }
                        }

                        // Form fields
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Certificate Name")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#CCCCCC"))

                            TextField("e.g., My TAK Cert", text: $certificateName)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Server URL")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#CCCCCC"))

                            TextField("e.g., https://tak.example.com", text: $serverURL)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .keyboardType(.URL)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Username")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#CCCCCC"))

                            TextField("Username", text: $username)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Certificate Password")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#CCCCCC"))

                            SecureField("Password", text: $password)
                                .textFieldStyle(.roundedBorder)
                        }

                        // Import button
                        Button(action: importCertificate) {
                            Text("Import Certificate")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "#FFFC00"))
                                .cornerRadius(12)
                        }
                        .disabled(!isFormValid)
                        .opacity(isFormValid ? 1.0 : 0.5)
                        .padding(.top, 20)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Import Certificate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [UTType(filenameExtension: "p12")!],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        selectedFileURL = url
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            .alert("Import Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var isFormValid: Bool {
        selectedFileURL != nil &&
        !certificateName.isEmpty &&
        !serverURL.isEmpty &&
        !username.isEmpty &&
        !password.isEmpty
    }

    private func importCertificate() {
        guard let url = selectedFileURL else { return }

        do {
            try certificateManager.importCertificate(
                from: url,
                password: password,
                name: certificateName,
                serverURL: serverURL,
                username: username
            )

            // Get the most recently added certificate (the one we just imported)
            if let latestCert = certificateManager.certificates.last {
                onComplete?(latestCert.id, latestCert.name)
            }

            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CertificateManagementView_Previews: PreviewProvider {
    static var previews: some View {
        CertificateManagementView()
            .preferredColorScheme(.dark)
    }
}
#endif
