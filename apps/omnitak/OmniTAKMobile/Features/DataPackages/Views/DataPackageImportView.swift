//
//  DataPackageImportView.swift
//  OmniTAKMobile
//
//  Data Package Import - ATAK Style
//  Supports .zip packages with certificates and server configs
//

import SwiftUI
import UniformTypeIdentifiers

struct DataPackageImportView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var importManager = DataPackageImportManager()
    @State private var showFilePicker = false
    @State private var importStatus: ImportStatus = .idle
    @State private var showSuccessAlert = false

    var body: some View {
        NavigationView {
            ZStack {
                // ATAK-style black background
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Cyan accent bar
                    Rectangle()
                        .fill(Color(hex: "#00BCD4"))
                        .frame(height: 2)

                    ScrollView {
                        VStack(spacing: 24) {
                            // Hero section
                            heroSection

                            // Import status
                            if importStatus != .idle {
                                statusSection
                            }

                            // Instructions
                            instructionsCard

                            // Import button
                            importButton

                            // Recent imports
                            if !importManager.recentImports.isEmpty {
                                recentImportsSection
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                }
            }
            .navigationTitle("Import Data Package")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.zip, .data],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .alert("Import Successful", isPresented: $showSuccessAlert) {
            Button("Done") {
                dismiss()
            }
        } message: {
            Text(importManager.successMessage)
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#00BCD4").opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: "#00BCD4"))
            }

            Text("Import TAK Data Package")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            Text("Automatically configure servers and certificates")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#CCCCCC"))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 12) {
            switch importStatus {
            case .idle:
                EmptyView()

            case .importing:
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#00BCD4")))

                    Text("Importing package...")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#1A1A1A"))
                .cornerRadius(12)

            case .extracting:
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#FFFC00")))

                    Text("Extracting certificates...")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#1A1A1A"))
                .cornerRadius(12)

            case .configuring:
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#4CAF50")))

                    Text("Configuring servers...")
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color(hex: "#1A1A1A"))
                .cornerRadius(12)

            case .success(let message):
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#4CAF50"))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Import Complete")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)

                        Text(message)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#CCCCCC"))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#4CAF50").opacity(0.15))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#4CAF50").opacity(0.3), lineWidth: 1)
                )

            case .error(let error):
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#FF6B6B"))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Import Failed")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)

                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#CCCCCC"))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#FF6B6B").opacity(0.15))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#FF6B6B").opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Instructions Card

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(Color(hex: "#00BCD4"))

                Text("What's in a Data Package?")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(
                    icon: "key.fill",
                    text: "Client certificates (.p12, .pfx)"
                )

                InstructionRow(
                    icon: "lock.shield.fill",
                    text: "Trust store certificates"
                )

                InstructionRow(
                    icon: "server.rack",
                    text: "Server connection settings"
                )

                InstructionRow(
                    icon: "gearshape.fill",
                    text: "Application preferences"
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#1A1A1A"))
        .cornerRadius(12)
    }

    // MARK: - Import Button

    private var importButton: some View {
        Button(action: { showFilePicker = true }) {
            HStack(spacing: 12) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 20))

                Text("Select Data Package (.zip)")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(hex: "#00BCD4"))
            .cornerRadius(12)
        }
        .disabled(importStatus == .importing || importStatus == .extracting || importStatus == .configuring)
        .opacity((importStatus == .importing || importStatus == .extracting || importStatus == .configuring) ? 0.5 : 1.0)
    }

    // MARK: - Recent Imports

    private var recentImportsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECENT IMPORTS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Color(hex: "#999999"))

            ForEach(importManager.recentImports) { import in
                RecentImportRow(import: import)
            }
        }
    }

    // MARK: - File Handling

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importDataPackage(from: url)

        case .failure(let error):
            importStatus = .error(error.localizedDescription)
        }
    }

    private func importDataPackage(from url: URL) {
        importStatus = .importing

        Task {
            do {
                // Start accessing security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    throw ImportError.accessDenied
                }
                defer { url.stopAccessingSecurityScopedResource() }

                // Import the package
                try await importManager.importPackage(from: url) { status in
                    await MainActor.run {
                        self.importStatus = status
                    }
                }

                // Show success
                await MainActor.run {
                    showSuccessAlert = true
                }

            } catch {
                await MainActor.run {
                    importStatus = .error(error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct InstructionRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#00BCD4"))
                .frame(width: 20)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#CCCCCC"))
        }
    }
}

struct RecentImportRow: View {
    let import: ImportRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(hex: "#4CAF50"))

            VStack(alignment: .leading, spacing: 4) {
                Text(import.packageName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)

                Text(import.importDate.formatted())
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#999999"))
            }

            Spacer()

            Text("\(import.itemsImported) items")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#CCCCCC"))
        }
        .padding(12)
        .background(Color(hex: "#1A1A1A"))
        .cornerRadius(8)
    }
}

// MARK: - Import Status

enum ImportStatus: Equatable {
    case idle
    case importing
    case extracting
    case configuring
    case success(String)
    case error(String)
}

// MARK: - Import Record

struct ImportRecord: Identifiable {
    let id = UUID()
    let packageName: String
    let importDate: Date
    let itemsImported: Int
}

// MARK: - Import Error

enum ImportError: LocalizedError {
    case accessDenied
    case invalidPackage
    case extractionFailed
    case noCertificatesFound

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access denied to the selected file"
        case .invalidPackage:
            return "Invalid or corrupted data package"
        case .extractionFailed:
            return "Failed to extract package contents"
        case .noCertificatesFound:
            return "No certificates found in package"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct DataPackageImportView_Previews: PreviewProvider {
    static var previews: some View {
        DataPackageImportView()
            .preferredColorScheme(.dark)
    }
}
#endif
