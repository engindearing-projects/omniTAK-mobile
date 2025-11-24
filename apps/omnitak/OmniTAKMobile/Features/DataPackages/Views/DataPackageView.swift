//
//  DataPackageView.swift
//  OmniTAKMobile
//
//  SwiftUI interface for managing TAK data packages
//

import SwiftUI
import UniformTypeIdentifiers

struct DataPackageView: View {
    @ObservedObject var packageManager: DataPackageManager
    @Binding var isPresented: Bool

    @State private var showFilePicker = false
    @State private var showExportSheet = false
    @State private var showDeleteConfirmation = false
    @State private var packageToDelete: UUID?
    @State private var selectedPackage: DataPackage?
    @State private var showPackageDetail = false
    @State private var showCacheSettings = false

    @StateObject private var tileCacheManager = OfflineTileCacheManager.shared

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Action Buttons
                    actionButtons
                        .padding()

                    // Error/Status Banner
                    if let error = packageManager.lastError {
                        errorBanner(error)
                    }

                    // Progress Indicators
                    if packageManager.isImporting {
                        progressView("Importing package...", progress: packageManager.importProgress)
                    }

                    if packageManager.isExporting {
                        progressView("Exporting package...", progress: packageManager.exportProgress)
                    }

                    // Storage Info
                    storageInfoView
                        .padding(.horizontal)

                    // Package List
                    if packageManager.packages.isEmpty {
                        emptyStateView
                    } else {
                        packageList
                    }
                }
            }
            .navigationTitle("Data Packages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showCacheSettings = true }) {
                            Label("Cache Settings", systemImage: "internaldrive")
                        }

                        Button(action: clearAllPackages) {
                            Label("Clear All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(Color(hex: "#FFFC00"))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showFilePicker) {
            DataPackagePicker(packageManager: packageManager)
        }
        .sheet(isPresented: $showExportSheet) {
            ExportPackageSheet(packageManager: packageManager)
        }
        .sheet(isPresented: $showPackageDetail) {
            if let package = selectedPackage {
                PackageDetailView(package: package, packageManager: packageManager)
            }
        }
        .sheet(isPresented: $showCacheSettings) {
            CacheSettingsView(cacheManager: tileCacheManager)
        }
        .alert("Delete Package", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let id = packageToDelete {
                    packageManager.deletePackage(id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this data package? All associated files will be removed.")
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Import Button
            Button(action: { showFilePicker = true }) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 18))
                    Text("Import")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(hex: "#FFFC00"))
                .cornerRadius(10)
            }
            .disabled(packageManager.isImporting || packageManager.isExporting)

            // Export Button
            Button(action: { showExportSheet = true }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18))
                    Text("Export")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(Color(hex: "#FFFC00"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(hex: "#FFFC00").opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "#FFFC00"), lineWidth: 1)
                )
                .cornerRadius(10)
            }
            .disabled(packageManager.isImporting || packageManager.isExporting)
        }
    }

    // MARK: - Storage Info

    private var storageInfoView: some View {
        HStack {
            Image(systemName: "internaldrive")
                .foregroundColor(Color(hex: "#FFFC00"))

            Text("Storage Used:")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#999999"))

            Text(packageManager.formattedTotalStorage)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)

            Spacer()

            Text("\(packageManager.packages.count) package\(packageManager.packages.count == 1 ? "" : "s")")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#666666"))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(8)
    }

    // MARK: - Progress View

    private func progressView(_ message: String, progress: Double) -> some View {
        VStack(spacing: 8) {
            HStack {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#FFFC00")))
                    .scaleEffect(0.8)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#FFFC00"))
            }

            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: "#FFFC00")))
        }
        .padding()
        .background(Color(hex: "#2A2A2A"))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.red)
                .lineLimit(2)
            Spacer()
            Button(action: {
                packageManager.lastError = nil
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "shippingbox")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#3A3A3A"))

            Text("No Data Packages")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Text("Import TAK data packages (.zip) containing overlays, icons, and configurations")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#999999"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Package List

    private var packageList: some View {
        List {
            ForEach(packageManager.packages) { package in
                DataPackageRow(
                    package: package,
                    onTap: {
                        selectedPackage = package
                        showPackageDetail = true
                    },
                    onDelete: {
                        packageToDelete = package.id
                        showDeleteConfirmation = true
                    }
                )
                .listRowBackground(Color(hex: "#2A2A2A"))
            }
        }
        .listStyle(PlainListStyle())
        .background(Color(hex: "#1E1E1E"))
    }

    // MARK: - Actions

    private func clearAllPackages() {
        for package in packageManager.packages {
            packageManager.deletePackage(package.id)
        }
    }
}

// MARK: - Data Package Row

struct DataPackageRow: View {
    let package: DataPackage
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "shippingbox.fill")
                        .foregroundColor(Color(hex: "#FFFC00"))
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(package.name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text("v\(package.version)")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#999999"))
                    }

                    Spacer()

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.8))
                            .frame(width: 30)
                    }
                }

                HStack {
                    // Contents summary
                    Label(package.contentsSummary, systemImage: "square.3.layers.3d")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                        .lineLimit(1)

                    Spacer()

                    // Size
                    Text(package.formattedSize)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "#FFFC00"))
                }

                HStack {
                    // Import date
                    Text("Imported: \(formatDate(package.importDate))")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#666666"))

                    Spacer()

                    // Contents count
                    Text("\(package.contents.count) items")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#666666"))
                }

                if let description = package.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#AAAAAA"))
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Package Detail View

struct PackageDetailView: View {
    let package: DataPackage
    @ObservedObject var packageManager: DataPackageManager
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Package Info
                        VStack(alignment: .leading, spacing: 12) {
                            DetailRow(icon: "shippingbox", label: "Name", value: package.name)
                            DetailRow(icon: "number", label: "Version", value: package.version)
                            DetailRow(icon: "calendar", label: "Imported", value: formatDate(package.importDate))
                            DetailRow(icon: "internaldrive", label: "Size", value: package.formattedSize)

                            if let author = package.author {
                                DetailRow(icon: "person", label: "Author", value: author)
                            }

                            if let checksum = package.checksum {
                                DetailRow(icon: "checkmark.shield", label: "Checksum", value: checksum)
                            }
                        }
                        .background(Color(hex: "#2A2A2A"))
                        .cornerRadius(10)

                        // Description
                        if let description = package.description, !description.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color(hex: "#FFFC00"))

                                Text(description)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(hex: "#2A2A2A"))
                            .cornerRadius(10)
                        }

                        // Contents List
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Contents (\(package.contents.count))")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#FFFC00"))
                                .padding(.horizontal)

                            ForEach(Array(package.contents.enumerated()), id: \.offset) { _, content in
                                HStack {
                                    Image(systemName: content.iconName)
                                        .foregroundColor(Color(hex: "#FFFC00"))
                                        .frame(width: 24)

                                    Text(content.fileName)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                        .lineLimit(1)

                                    Spacer()

                                    Text(content.typeString)
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "#999999"))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(hex: "#3A3A3A"))
                                        .cornerRadius(4)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                        .background(Color(hex: "#2A2A2A"))
                        .cornerRadius(10)
                    }
                    .padding()
                }
            }
            .navigationTitle("Package Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Export Package Sheet

struct ExportPackageSheet: View {
    @ObservedObject var packageManager: DataPackageManager
    @Environment(\.presentationMode) var presentationMode

    @State private var packageName = "OmniTAK_Export"
    @State private var packageVersion = "1.0"
    @State private var packageDescription = ""
    @State private var authorName = ""
    @State private var includeOverlays = true
    @State private var includeConfigs = true
    @State private var isExporting = false
    @State private var exportResult: PackageExportResult?
    @State private var showShareSheet = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Package Info
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Package Information")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#FFFC00"))

                            TextField("Package Name", text: $packageName)
                                .textFieldStyle(DataPackageTextFieldStyle())

                            TextField("Version", text: $packageVersion)
                                .textFieldStyle(DataPackageTextFieldStyle())

                            TextField("Author (optional)", text: $authorName)
                                .textFieldStyle(DataPackageTextFieldStyle())

                            TextField("Description (optional)", text: $packageDescription)
                                .textFieldStyle(DataPackageTextFieldStyle())
                        }
                        .padding()
                        .background(Color(hex: "#2A2A2A"))
                        .cornerRadius(10)

                        // Include Options
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Include Content")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#FFFC00"))

                            Toggle(isOn: $includeOverlays) {
                                Label("KML Overlays", systemImage: "map")
                                    .foregroundColor(.white)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#FFFC00")))

                            Toggle(isOn: $includeConfigs) {
                                Label("App Configurations", systemImage: "gearshape")
                                    .foregroundColor(.white)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#FFFC00")))
                        }
                        .padding()
                        .background(Color(hex: "#2A2A2A"))
                        .cornerRadius(10)

                        // Export Button
                        Button(action: exportPackage) {
                            HStack {
                                if isExporting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                }
                                Text(isExporting ? "Exporting..." : "Create Package")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#FFFC00"))
                            .cornerRadius(10)
                        }
                        .disabled(packageName.isEmpty || isExporting)

                        // Result
                        if let result = exportResult {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Package Created")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.green)
                                }

                                Text("Size: \(ByteCountFormatter.string(fromByteCount: result.packageSize, countStyle: .file))")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)

                                Text("Location: Documents/\(result.packageURL.lastPathComponent)")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#999999"))

                                Button(action: { showShareSheet = true }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Share Package")
                                    }
                                    .foregroundColor(Color(hex: "#FFFC00"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color(hex: "#FFFC00").opacity(0.15))
                                    .cornerRadius(8)
                                }
                            }
                            .padding()
                            .background(Color(hex: "#2A2A2A"))
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Export Package")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showShareSheet) {
            if let result = exportResult {
                ActivityView(activityItems: [result.packageURL])
            }
        }
    }

    private func exportPackage() {
        isExporting = true

        Task {
            do {
                let result = try await packageManager.exportPackage(
                    name: packageName,
                    version: packageVersion,
                    description: packageDescription.isEmpty ? nil : packageDescription,
                    author: authorName.isEmpty ? nil : authorName,
                    includeOverlays: includeOverlays,
                    includeConfigs: includeConfigs
                )

                await MainActor.run {
                    exportResult = result
                    isExporting = false
                }
            } catch {
                await MainActor.run {
                    packageManager.lastError = error.localizedDescription
                    isExporting = false
                }
            }
        }
    }
}

// MARK: - Cache Settings View

struct CacheSettingsView: View {
    @ObservedObject var cacheManager: OfflineTileCacheManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1E1E1E")
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    // Cache Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tile Cache")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#FFFC00"))

                        DetailRow(icon: "internaldrive", label: "Used", value: cacheManager.formattedCacheSize)
                        DetailRow(icon: "chart.bar", label: "Max Size", value: cacheManager.formattedMaxCacheSize)

                        // Progress bar
                        VStack(spacing: 4) {
                            ProgressView(value: cacheManager.getCachePercentage(), total: 100)
                                .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: "#FFFC00")))

                            Text("\(Int(cacheManager.getCachePercentage()))% used")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#666666"))
                        }
                    }
                    .padding()
                    .background(Color(hex: "#2A2A2A"))
                    .cornerRadius(10)

                    // Clear Cache Button
                    Button(action: { showClearConfirmation = true }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Tile Cache")
                        }
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red.opacity(0.15))
                        .cornerRadius(10)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Cache Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(Color(hex: "#FFFC00"))
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Clear Cache", isPresented: $showClearConfirmation) {
            Button("Clear", role: .destructive) {
                cacheManager.clearCache()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all cached map tiles. You will need to re-download them for offline use.")
        }
    }
}

// MARK: - Data Package Picker

struct DataPackagePicker: UIViewControllerRepresentable {
    let packageManager: DataPackageManager

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let zipType = UTType.archive
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [zipType])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(packageManager: packageManager)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let packageManager: DataPackageManager

        init(packageManager: DataPackageManager) {
            self.packageManager = packageManager
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            // Access security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                DispatchQueue.main.async {
                    self.packageManager.lastError = "Unable to access the selected file"
                }
                return
            }

            defer { url.stopAccessingSecurityScopedResource() }

            // Copy to temp directory
            let tempDir = FileManager.default.temporaryDirectory
            let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)

            do {
                try? FileManager.default.removeItem(at: tempURL)
                try FileManager.default.copyItem(at: url, to: tempURL)

                Task {
                    do {
                        _ = try await self.packageManager.importPackage(from: tempURL)
                        try? FileManager.default.removeItem(at: tempURL)
                    } catch {
                        await MainActor.run {
                            self.packageManager.lastError = error.localizedDescription
                        }
                        try? FileManager.default.removeItem(at: tempURL)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.packageManager.lastError = "Failed to copy file: \(error.localizedDescription)"
                }
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}

// MARK: - Activity View (Share Sheet)

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Dark TextField Style

struct DataPackageTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(Color(hex: "#3A3A3A"))
            .cornerRadius(8)
            .foregroundColor(.white)
    }
}

// MARK: - Preview

struct DataPackageView_Previews: PreviewProvider {
    static var previews: some View {
        DataPackageView(
            packageManager: DataPackageManager(),
            isPresented: .constant(true)
        )
    }
}
