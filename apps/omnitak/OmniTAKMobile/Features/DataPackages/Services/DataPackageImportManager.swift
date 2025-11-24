//
//  DataPackageImportManager.swift
//  OmniTAKMobile
//
//  Handles TAK Data Package imports (.zip files with certificates and configs)
//

import Foundation
import Security
import Compression

@MainActor
class DataPackageImportManager: ObservableObject {
    @Published var recentImports: [ImportRecord] = []
    @Published var successMessage = ""

    private let fileManager = FileManager.default
    private let serverManager = ServerManager.shared
    private let certificateManager = CertificateManager.shared

    // MARK: - Import Package

    func importPackage(from url: URL, statusCallback: @escaping (ImportStatus) async -> Void) async throws {
        // Create temporary directory
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Extract zip file
        await statusCallback(.extracting)
        try await extractZipFile(from: url, to: tempDir)

        // Find and process contents
        let contents = try findPackageContents(in: tempDir)

        // Import certificates
        var importedItems = 0
        for certURL in contents.certificates {
            do {
                try await importCertificate(from: certURL)
                importedItems += 1
            } catch {
                print("⚠️ Failed to import certificate: \(error.localizedDescription)")
            }
        }

        // Parse and apply server configurations
        await statusCallback(.configuring)
        for configURL in contents.serverConfigs {
            do {
                try await parseServerConfig(from: configURL)
                importedItems += 1
            } catch {
                print("⚠️ Failed to parse server config: \(error.localizedDescription)")
            }
        }

        // Parse preferences
        for prefURL in contents.preferences {
            do {
                try await parsePreferences(from: prefURL)
            } catch {
                print("⚠️ Failed to parse preferences: \(error.localizedDescription)")
            }
        }

        // Record import
        let record = ImportRecord(
            packageName: url.deletingPathExtension().lastPathComponent,
            importDate: Date(),
            itemsImported: importedItems
        )
        recentImports.insert(record, at: 0)

        // Set success message
        successMessage = "Imported \(importedItems) item(s) from data package"

        await statusCallback(.success(successMessage))
    }

    // MARK: - Extract ZIP

    private func extractZipFile(from sourceURL: URL, to destinationURL: URL) async throws {
        try await Task.detached {
            // Use NSFileCoordinator for coordinated file access
            var coordinatedURL: NSURL?
            let coordinator = NSFileCoordinator()
            var error: NSError?

            coordinator.coordinate(readingItemAt: sourceURL as URL, options: [], error: &error) { url in
                coordinatedURL = url as NSURL
            }

            guard let readURL = coordinatedURL as URL? else {
                throw ImportError.extractionFailed
            }

            // Use unzip command through Process
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-q", "-o", readURL.path, "-d", destinationURL.path]

            let pipe = Pipe()
            process.standardError = pipe

            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                print("⚠️ Unzip error: \(errorMessage)")
                throw ImportError.extractionFailed
            }
        }.value
    }

    // MARK: - Find Package Contents

    private func findPackageContents(in directory: URL) throws -> PackageContents {
        var certificates: [URL] = []
        var serverConfigs: [URL] = []
        var preferences: [URL] = []

        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey])

        while let fileURL = enumerator?.nextObject() as? URL {
            let filename = fileURL.lastPathComponent.lowercased()
            let ext = fileURL.pathExtension.lowercased()

            // Certificate files
            if ext == "p12" || ext == "pfx" || ext == "pem" || ext == "crt" || ext == "cer" {
                certificates.append(fileURL)
            }
            // Server config files
            else if ext == "xml" || ext == "json" || filename.contains("server") || filename.contains("connection") {
                serverConfigs.append(fileURL)
            }
            // Preference files
            else if filename.contains("pref") || filename.contains("config") {
                preferences.append(fileURL)
            }
        }

        return PackageContents(
            certificates: certificates,
            serverConfigs: serverConfigs,
            preferences: preferences
        )
    }

    // MARK: - Import Certificate

    private func importCertificate(from url: URL) async throws {
        let data = try Data(contentsOf: url)
        let filename = url.deletingPathExtension().lastPathComponent

        // Determine certificate type
        let ext = url.pathExtension.lowercased()

        if ext == "p12" || ext == "pfx" {
            // P12/PFX file - try common passwords or prompt user
            let passwords = ["atakatak", ""] // Common TAK server passwords

            for password in passwords {
                do {
                    try await importP12Certificate(data: data, password: password, name: filename)
                    print("✅ Imported P12 certificate: \(filename)")
                    return
                } catch {
                    continue
                }
            }

            throw ImportError.certificateImportFailed("Could not import P12 certificate with default passwords")
        }
        else if ext == "pem" || ext == "crt" || ext == "cer" {
            // PEM/CRT file
            try await importPEMCertificate(data: data, name: filename)
            print("✅ Imported PEM certificate: \(filename)")
        }
    }

    private func importP12Certificate(data: Data, password: String, name: String) async throws {
        let options: [String: Any] = [kSecImportExportPassphrase as String: password]

        var items: CFArray?
        let status = SecPKCS12Import(data as CFData, options as CFDictionary, &items)

        guard status == errSecSuccess else {
            throw ImportError.certificateImportFailed("P12 import failed with status: \(status)")
        }

        guard let itemsArray = items as? [[String: Any]],
              let firstItem = itemsArray.first,
              let identity = firstItem[kSecImportItemIdentity as String] else {
            throw ImportError.certificateImportFailed("No identity found in P12")
        }

        // Store identity in keychain
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecValueRef as String: identity,
            kSecAttrLabel as String: name
        ]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        if addStatus != errSecSuccess && addStatus != errSecDuplicateItem {
            throw ImportError.certificateImportFailed("Failed to add identity to keychain: \(addStatus)")
        }

        // Update certificate manager
        await certificateManager.loadCertificates()
    }

    private func importPEMCertificate(data: Data, name: String) async throws {
        // For PEM certificates, we'll store them for reference
        // In a full implementation, you'd parse the PEM and add to keychain

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueData as String: data,
            kSecAttrLabel as String: name
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)

        if status != errSecSuccess && status != errSecDuplicateItem {
            throw ImportError.certificateImportFailed("Failed to add certificate: \(status)")
        }

        // Update certificate manager
        await certificateManager.loadCertificates()
    }

    // MARK: - Parse Server Config

    private func parseServerConfig(from url: URL) async throws {
        let data = try Data(contentsOf: url)
        let ext = url.pathExtension.lowercased()

        if ext == "json" {
            try await parseJSONConfig(data: data)
        } else if ext == "xml" {
            try await parseXMLConfig(data: data)
        }
    }

    private func parseJSONConfig(data: Data) async throws {
        struct ServerConfig: Codable {
            let name: String?
            let host: String
            let port: Int
            let protocol: String?
            let useTLS: Bool?
            let certificateName: String?
        }

        let decoder = JSONDecoder()
        let config = try decoder.decode(ServerConfig.self, from: data)

        // Create TAKServer
        let server = TAKServer(
            name: config.name ?? "Imported Server",
            host: config.host,
            port: UInt16(config.port),
            protocolType: config.protocol ?? "tcp",
            useTLS: config.useTLS ?? false,
            isDefault: false,
            certificateName: config.certificateName
        )

        // Add to server manager
        serverManager.addServer(server)
        print("✅ Imported server configuration: \(server.name)")
    }

    private func parseXMLConfig(data: Data) async throws {
        // Basic XML parsing for TAK preference files
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw ImportError.configParsingFailed("Invalid XML encoding")
        }

        // Look for server connection info in XML
        // This is a simplified parser - TAK uses complex XML structures

        if let host = extractXMLValue(from: xmlString, key: "connectString") {
            let components = host.split(separator: ":")
            if components.count >= 2 {
                let serverHost = String(components[0])
                let port = UInt16(components[1]) ?? 8087

                let server = TAKServer(
                    name: "Imported Server",
                    host: serverHost,
                    port: port,
                    protocolType: "tcp",
                    useTLS: false,
                    isDefault: false
                )

                serverManager.addServer(server)
                print("✅ Imported server from XML: \(server.name)")
            }
        }
    }

    private func extractXMLValue(from xml: String, key: String) -> String? {
        let pattern = "name=\"\(key)\"[^>]*>([^<]*)<"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(xml.startIndex..., in: xml)
        guard let match = regex.firstMatch(in: xml, range: range),
              let valueRange = Range(match.range(at: 1), in: xml) else {
            return nil
        }

        return String(xml[valueRange])
    }

    // MARK: - Parse Preferences

    private func parsePreferences(from url: URL) async throws {
        // Parse TAK preference files
        // This would apply app-wide settings from the package
        print("ℹ️ Parsing preferences from: \(url.lastPathComponent)")
    }
}

// MARK: - Package Contents

struct PackageContents {
    let certificates: [URL]
    let serverConfigs: [URL]
    let preferences: [URL]
}

// MARK: - Import Errors

extension ImportError {
    static func certificateImportFailed(_ message: String) -> ImportError {
        .error(message)
    }

    static func configParsingFailed(_ message: String) -> ImportError {
        .error(message)
    }

    static func error(_ message: String) -> ImportError {
        .invalidPackage
    }
}
