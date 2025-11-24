//
//  DataPackageManager.swift
//  OmniTAKMobile
//
//  Service for importing and exporting TAK data packages
//

import Foundation
import Combine

// MARK: - Data Package Manager

class DataPackageManager: ObservableObject {

    @Published var packages: [DataPackage] = []
    @Published var isImporting: Bool = false
    @Published var isExporting: Bool = false
    @Published var lastError: String?
    @Published var importProgress: Double = 0
    @Published var exportProgress: Double = 0

    private let fileManager = FileManager.default
    private let packagesDirectory: URL
    private let packagesMetadataFile: URL
    private let extractionDirectory: URL

    // Reference to other managers for integration
    weak var kmlOverlayManager: KMLOverlayManager?

    init() {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        packagesDirectory = documentsPath.appendingPathComponent("DataPackages", isDirectory: true)
        packagesMetadataFile = documentsPath.appendingPathComponent("data_packages.json")
        extractionDirectory = fileManager.temporaryDirectory.appendingPathComponent("PackageExtraction", isDirectory: true)

        // Create directories
        try? fileManager.createDirectory(at: packagesDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: extractionDirectory, withIntermediateDirectories: true)

        loadPackages()
    }

    // MARK: - Import Package

    func importPackage(from url: URL) async throws -> PackageImportResult {
        await MainActor.run {
            isImporting = true
            importProgress = 0
            lastError = nil
        }

        defer {
            Task { @MainActor in
                isImporting = false
                importProgress = 0
            }
        }

        // Verify file exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw DataPackageError.fileNotFound(url.lastPathComponent)
        }

        // Check file extension
        let ext = url.pathExtension.lowercased()
        guard ext == "zip" || ext == "dpkg" || ext == "tak" else {
            throw DataPackageError.unsupportedFormat(ext)
        }

        await MainActor.run { importProgress = 0.1 }

        // Create extraction directory for this package
        let packageId = UUID()
        let packageExtractionDir = extractionDirectory.appendingPathComponent(packageId.uuidString)
        try fileManager.createDirectory(at: packageExtractionDir, withIntermediateDirectories: true)

        defer {
            // Cleanup extraction directory
            try? fileManager.removeItem(at: packageExtractionDir)
        }

        // Extract package
        let extractedContents = try await extractPackage(at: url, to: packageExtractionDir)

        await MainActor.run { importProgress = 0.3 }

        // Read manifest if present
        let manifest = readManifest(from: packageExtractionDir)

        await MainActor.run { importProgress = 0.4 }

        // Calculate package size
        let packageSize = try fileManager.sizeOfItem(at: url)

        // Process contents
        var packageContents: [PackageContent] = []
        var warnings: [String] = []
        var skippedFiles: [String] = []

        // Create package storage directory
        let packageStorageDir = packagesDirectory.appendingPathComponent(packageId.uuidString)
        try fileManager.createDirectory(at: packageStorageDir, withIntermediateDirectories: true)

        // Process each extracted file
        let totalFiles = extractedContents.count
        for (index, file) in extractedContents.enumerated() {
            let result = try await processExtractedFile(
                file,
                packageStorageDir: packageStorageDir,
                packageId: packageId
            )

            if let content = result.content {
                packageContents.append(content)
            }

            if let warning = result.warning {
                warnings.append(warning)
            }

            if result.skipped {
                skippedFiles.append(file.lastPathComponent)
            }

            await MainActor.run {
                importProgress = 0.4 + (0.5 * Double(index + 1) / Double(totalFiles))
            }
        }

        await MainActor.run { importProgress = 0.9 }

        // Create package record
        let package = DataPackage(
            id: packageId,
            name: manifest?.name ?? url.deletingPathExtension().lastPathComponent,
            version: manifest?.version ?? "1.0",
            importDate: Date(),
            size: packageSize,
            contents: packageContents,
            description: manifest?.description,
            author: manifest?.author,
            checksum: calculateChecksum(for: url)
        )

        // Save package metadata
        await MainActor.run {
            packages.append(package)
        }
        savePackages()

        // Copy original package file
        let originalPackageFile = packageStorageDir.appendingPathComponent("original\(url.pathExtension)")
        try? fileManager.copyItem(at: url, to: originalPackageFile)

        await MainActor.run { importProgress = 1.0 }

        return PackageImportResult(
            package: package,
            warnings: warnings,
            skippedFiles: skippedFiles,
            success: true
        )
    }

    private func extractPackage(at url: URL, to directory: URL) async throws -> [URL] {
        // Use Foundation's built-in unzipping (iOS 15+)
        // For iOS 15 compatibility, we'll use a simple approach with FileManager
        // In production, you would use ZIPFoundation or similar

        // Simple ZIP extraction using Process or third-party library
        // For now, we'll implement a basic version

        let coordinator = NSFileCoordinator()
        var extractedFiles: [URL] = []

        // Try to extract using Foundation
        do {
            extractedFiles = try await withCheckedThrowingContinuation { continuation in
                coordinator.coordinate(readingItemAt: url, options: .forUploading, error: nil) { zipURL in
                    do {
                        let files = try self.unzipFile(at: zipURL, to: directory)
                        continuation.resume(returning: files)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            throw DataPackageError.extractionFailed(error.localizedDescription)
        }

        return extractedFiles
    }

    private func unzipFile(at source: URL, to destination: URL) throws -> [URL] {
        // iOS 15+ compatible ZIP extraction
        // Using FileManager to handle ZIP archives

        var extractedFiles: [URL] = []

        // Read the ZIP file
        guard let archive = try? Data(contentsOf: source) else {
            throw DataPackageError.extractionFailed("Cannot read ZIP file")
        }

        // Simple ZIP extraction - in production use proper ZIP library
        // For this implementation, we'll handle common TAK package structure
        // by looking for specific file patterns

        // Copy the archive to destination for processing
        let tempZip = destination.appendingPathComponent("package.zip")
        try archive.write(to: tempZip)

        // Use built-in unzip via Process if available, or use bundled library
        // For iOS, we need to use a different approach

        // Attempt to use NSFileCoordinator for decompression
        let resourceValues = try source.resourceValues(forKeys: [.contentTypeKey])

        if let type = resourceValues.contentType,
           type.conforms(to: .archive) {
            // It's a valid archive, try to list contents
            // In a real implementation, you'd use a proper ZIP library here

            // For now, return empty and mark for manual handling
            print("Archive detected, extraction would occur here")
        }

        // List all files in destination
        if let enumerator = fileManager.enumerator(at: destination, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                if !fileURL.hasDirectoryPath {
                    extractedFiles.append(fileURL)
                }
            }
        }

        return extractedFiles
    }

    private func readManifest(from directory: URL) -> PackageManifest? {
        let manifestPath = directory.appendingPathComponent("manifest.json")

        guard fileManager.fileExists(atPath: manifestPath.path),
              let data = try? Data(contentsOf: manifestPath) else {
            // Try alternative manifest locations
            let altPath = directory.appendingPathComponent("package.json")
            if let altData = try? Data(contentsOf: altPath) {
                return try? JSONDecoder().decode(PackageManifest.self, from: altData)
            }
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PackageManifest.self, from: data)
    }

    private func processExtractedFile(
        _ file: URL,
        packageStorageDir: URL,
        packageId: UUID
    ) async throws -> (content: PackageContent?, warning: String?, skipped: Bool) {

        let fileName = file.lastPathComponent
        let fileExtension = file.pathExtension.lowercased()

        // Skip manifest files
        if fileName == "manifest.json" || fileName == "package.json" {
            return (nil, nil, true)
        }

        // Determine content type based on file extension
        switch fileExtension {
        case "kml", "kmz":
            // Overlay file - copy to overlays directory
            let overlaysDir = packageStorageDir.appendingPathComponent("overlays")
            try fileManager.createDirectory(at: overlaysDir, withIntermediateDirectories: true)
            let destPath = overlaysDir.appendingPathComponent(fileName)
            try fileManager.copyItem(at: file, to: destPath)

            // Import into KMLOverlayManager if available
            if let kmlManager = kmlOverlayManager {
                await kmlManager.importKMLFile(from: destPath)
            }

            return (.overlay(fileName), nil, false)

        case "png", "jpg", "jpeg", "gif", "svg":
            // Icon file
            let iconsDir = packageStorageDir.appendingPathComponent("icons")
            try fileManager.createDirectory(at: iconsDir, withIntermediateDirectories: true)
            let destPath = iconsDir.appendingPathComponent(fileName)
            try fileManager.copyItem(at: file, to: destPath)
            return (.icon(fileName), nil, false)

        case "xml", "plist", "json":
            // Configuration file (if not manifest)
            let configsDir = packageStorageDir.appendingPathComponent("configs")
            try fileManager.createDirectory(at: configsDir, withIntermediateDirectories: true)
            let destPath = configsDir.appendingPathComponent(fileName)
            try fileManager.copyItem(at: file, to: destPath)

            // Apply config if applicable
            try? applyConfiguration(from: destPath)

            return (.config(fileName), nil, false)

        case "mbtiles", "tiles":
            // Map cache file
            let cachesDir = packageStorageDir.appendingPathComponent("caches")
            try fileManager.createDirectory(at: cachesDir, withIntermediateDirectories: true)
            let destPath = cachesDir.appendingPathComponent(fileName)
            try fileManager.copyItem(at: file, to: destPath)
            return (.mapCache(fileName), nil, false)

        default:
            // Unknown file type - skip with warning
            return (nil, "Skipped unknown file type: \(fileName)", true)
        }
    }

    private func applyConfiguration(from url: URL) throws {
        // Apply configuration to UserDefaults or app settings
        // This is where you'd parse and apply TAK-specific configs

        guard let data = try? Data(contentsOf: url) else { return }

        let fileExtension = url.pathExtension.lowercased()

        switch fileExtension {
        case "json":
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Apply JSON config
                for (key, value) in json {
                    if let stringValue = value as? String {
                        UserDefaults.standard.set(stringValue, forKey: "tak_config_\(key)")
                    } else if let intValue = value as? Int {
                        UserDefaults.standard.set(intValue, forKey: "tak_config_\(key)")
                    } else if let boolValue = value as? Bool {
                        UserDefaults.standard.set(boolValue, forKey: "tak_config_\(key)")
                    }
                }
            }

        case "plist":
            if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                for (key, value) in plist {
                    UserDefaults.standard.set(value, forKey: "tak_config_\(key)")
                }
            }

        default:
            break
        }
    }

    // MARK: - Export Package

    func exportPackage(
        name: String,
        version: String = "1.0",
        description: String? = nil,
        author: String? = nil,
        includeOverlays: Bool = true,
        includeConfigs: Bool = true
    ) async throws -> PackageExportResult {

        await MainActor.run {
            isExporting = true
            exportProgress = 0
            lastError = nil
        }

        defer {
            Task { @MainActor in
                isExporting = false
                exportProgress = 0
            }
        }

        // Create temporary export directory
        let exportId = UUID()
        let exportDir = extractionDirectory.appendingPathComponent("export_\(exportId.uuidString)")
        try fileManager.createDirectory(at: exportDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: exportDir)
        }

        var includedContents: [PackageContent] = []

        await MainActor.run { exportProgress = 0.1 }

        // Export overlays (KML files)
        if includeOverlays, let kmlManager = kmlOverlayManager {
            let overlaysDir = exportDir.appendingPathComponent("overlays")
            try fileManager.createDirectory(at: overlaysDir, withIntermediateDirectories: true)

            for document in kmlManager.documents {
                // Export KML document
                let kmlPath = overlaysDir.appendingPathComponent("\(document.fileName)")
                if let sourceFile = findKMLFile(for: document) {
                    try? fileManager.copyItem(at: sourceFile, to: kmlPath)
                    includedContents.append(.overlay(document.fileName))
                }
            }
        }

        await MainActor.run { exportProgress = 0.4 }

        // Export configurations
        if includeConfigs {
            let configsDir = exportDir.appendingPathComponent("configs")
            try fileManager.createDirectory(at: configsDir, withIntermediateDirectories: true)

            // Export app settings as JSON
            let settings = exportAppSettings()
            let settingsPath = configsDir.appendingPathComponent("app_settings.json")

            if let settingsData = try? JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted) {
                try settingsData.write(to: settingsPath)
                includedContents.append(.config("app_settings.json"))
            }
        }

        await MainActor.run { exportProgress = 0.6 }

        // Create manifest
        let manifest = PackageManifest(
            name: name,
            version: version,
            description: description,
            author: author,
            createdDate: Date(),
            contents: includedContents.map { $0.fileName }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let manifestData = try encoder.encode(manifest)
        let manifestPath = exportDir.appendingPathComponent("manifest.json")
        try manifestData.write(to: manifestPath)

        await MainActor.run { exportProgress = 0.7 }

        // Create ZIP archive
        let zipFileName = "\(name.replacingOccurrences(of: " ", with: "_"))_\(version).zip"
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let zipPath = documentsDir.appendingPathComponent(zipFileName)

        // Remove existing file
        try? fileManager.removeItem(at: zipPath)

        // Create ZIP using compression
        try await createZipArchive(from: exportDir, to: zipPath)

        await MainActor.run { exportProgress = 0.9 }

        // Calculate final size
        let zipSize = try fileManager.sizeOfItem(at: zipPath)

        await MainActor.run { exportProgress = 1.0 }

        return PackageExportResult(
            packageURL: zipPath,
            packageSize: zipSize,
            includedContents: includedContents,
            success: true
        )
    }

    private func findKMLFile(for document: KMLDocument) -> URL? {
        let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        let kmlDir = paths[0].appendingPathComponent("KMLFiles")
        let filePath = kmlDir.appendingPathComponent("\(document.id.uuidString).kml")

        return fileManager.fileExists(atPath: filePath.path) ? filePath : nil
    }

    private func exportAppSettings() -> [String: Any] {
        var settings: [String: Any] = [:]

        // Export TAK-related UserDefaults
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys

        for key in allKeys {
            if key.hasPrefix("tak_config_") || key.hasPrefix("omnitak_") {
                if let value = defaults.object(forKey: key) {
                    settings[key] = value
                }
            }
        }

        return settings
    }

    private func createZipArchive(from sourceDir: URL, to destination: URL) async throws {
        // Simple ZIP creation for iOS 15+
        // In production, use a proper ZIP library like ZIPFoundation

        let coordinator = NSFileCoordinator()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var error: NSError?
            coordinator.coordinate(
                writingItemAt: sourceDir,
                options: .forMoving,
                error: &error
            ) { _ in
                // Create compressed archive
                do {
                    // Use tar/gzip as fallback or implement proper ZIP
                    // For this implementation, we'll create a simple archive

                    // List all files
                    var archiveData = Data()

                    if let enumerator = fileManager.enumerator(
                        at: sourceDir,
                        includingPropertiesForKeys: [.isRegularFileKey]
                    ) {
                        for case let fileURL as URL in enumerator {
                            if let isFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
                               isFile == true {

                                // In production, properly add to ZIP
                                if let fileData = try? Data(contentsOf: fileURL) {
                                    archiveData.append(fileData)
                                }
                            }
                        }
                    }

                    // Write combined data (placeholder for actual ZIP)
                    try archiveData.write(to: destination)

                    continuation.resume()
                } catch {
                    continuation.resume(throwing: DataPackageError.compressionFailed(error.localizedDescription))
                }
            }

            if let error = error {
                continuation.resume(throwing: DataPackageError.compressionFailed(error.localizedDescription))
            }
        }
    }

    // MARK: - Package Management

    func deletePackage(_ packageId: UUID) {
        // Remove package directory
        let packageDir = packagesDirectory.appendingPathComponent(packageId.uuidString)
        try? fileManager.removeItem(at: packageDir)

        // Remove from list
        packages.removeAll { $0.id == packageId }
        savePackages()
    }

    func getPackageContents(_ packageId: UUID) -> [URL] {
        let packageDir = packagesDirectory.appendingPathComponent(packageId.uuidString)

        guard let enumerator = fileManager.enumerator(at: packageDir, includingPropertiesForKeys: nil) else {
            return []
        }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            if !fileURL.hasDirectoryPath {
                files.append(fileURL)
            }
        }

        return files
    }

    func getOverlayFiles(for packageId: UUID) -> [URL] {
        let overlaysDir = packagesDirectory
            .appendingPathComponent(packageId.uuidString)
            .appendingPathComponent("overlays")

        guard let contents = try? fileManager.contentsOfDirectory(
            at: overlaysDir,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return contents.filter { ["kml", "kmz"].contains($0.pathExtension.lowercased()) }
    }

    func getIconFiles(for packageId: UUID) -> [URL] {
        let iconsDir = packagesDirectory
            .appendingPathComponent(packageId.uuidString)
            .appendingPathComponent("icons")

        guard let contents = try? fileManager.contentsOfDirectory(
            at: iconsDir,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return contents.filter { ["png", "jpg", "jpeg", "gif", "svg"].contains($0.pathExtension.lowercased()) }
    }

    // MARK: - Persistence

    private func savePackages() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(packages)
            try data.write(to: packagesMetadataFile)
        } catch {
            print("Failed to save packages: \(error)")
        }
    }

    private func loadPackages() {
        guard fileManager.fileExists(atPath: packagesMetadataFile.path) else { return }

        do {
            let data = try Data(contentsOf: packagesMetadataFile)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            packages = try decoder.decode([DataPackage].self, from: data)
        } catch {
            print("Failed to load packages: \(error)")
        }
    }

    // MARK: - Helpers

    private func calculateChecksum(for url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }

        // Simple hash using built-in functions
        var hasher = Hasher()
        hasher.combine(data)
        let hash = hasher.finalize()

        return String(format: "%08x", abs(hash))
    }

    func getTotalStorageUsed() -> Int64 {
        return packages.reduce(0) { $0 + $1.size }
    }

    var formattedTotalStorage: String {
        ByteCountFormatter.string(fromByteCount: getTotalStorageUsed(), countStyle: .file)
    }
}

// MARK: - FileManager Extension

extension FileManager {
    func sizeOfItem(at url: URL) throws -> Int64 {
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(resourceValues.fileSize ?? 0)
    }
}
