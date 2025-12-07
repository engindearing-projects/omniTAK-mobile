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
        try extractZipFile(from: url, to: tempDir)

        // Find and process contents
        let contents = try findPackageContents(in: tempDir)

        var importedItems = 0

        // Parse preferences FIRST to get passwords for certificate import
        await statusCallback(.configuring)
        for prefURL in contents.preferences {
            do {
                try await parsePreferences(from: prefURL)
                importedItems += 1
            } catch {
                print("⚠️ Failed to parse preferences: \(error.localizedDescription)")
            }
        }

        // Import certificates (using passwords extracted from preferences)
        for certURL in contents.certificates {
            do {
                try await importCertificate(from: certURL)
                importedItems += 1
            } catch {
                print("⚠️ Failed to import certificate: \(error.localizedDescription)")
            }
        }

        // Parse and apply additional server configurations
        for configURL in contents.serverConfigs {
            do {
                try await parseServerConfig(from: configURL)
                importedItems += 1
            } catch {
                print("⚠️ Failed to parse server config: \(error.localizedDescription)")
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

    private func extractZipFile(from sourceURL: URL, to destinationURL: URL) throws {
        // Read the ZIP data
        let zipData = try Data(contentsOf: sourceURL)

        // Use the ZipArchive class from KMZHandler
        guard let archive = ZipArchive(data: zipData) else {
            throw ImportError.extractionFailed
        }

        // Create destination directory if needed
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        // Extract each entry
        for entry in archive.entries {
            let entryURL = destinationURL.appendingPathComponent(entry.fileName)

            // Create parent directories if needed
            let parentDir = entryURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parentDir.path) {
                try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }

            // Write the file data
            try entry.data.write(to: entryURL)
        }
    }

    // MARK: - Find Package Contents

    private func findPackageContents(in directory: URL) throws -> PackageContents {
        var certificates: [URL] = []
        var serverConfigs: [URL] = []
        var preferences: [URL] = []

        // First, extract any nested zip files (TAK data packages often have nested zips)
        try extractNestedZips(in: directory)

        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey])

        while let fileURL = enumerator?.nextObject() as? URL {
            let filename = fileURL.lastPathComponent.lowercased()
            let ext = fileURL.pathExtension.lowercased()

            // Certificate files
            if ext == "p12" || ext == "pfx" || ext == "pem" || ext == "crt" || ext == "cer" {
                certificates.append(fileURL)
            }
            // Preference files (check first - .pref files contain server config)
            else if ext == "pref" || filename.contains("preference") {
                preferences.append(fileURL)
            }
            // Server config files (but not manifest.xml)
            else if (ext == "xml" && !filename.contains("manifest")) || ext == "json" || filename.contains("server") || filename.contains("connection") {
                serverConfigs.append(fileURL)
            }
        }

        return PackageContents(
            certificates: certificates,
            serverConfigs: serverConfigs,
            preferences: preferences
        )
    }

    // MARK: - Extract Nested Zips

    private func extractNestedZips(in directory: URL) throws {
        let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey])

        while let fileURL = enumerator?.nextObject() as? URL {
            if fileURL.pathExtension.lowercased() == "zip" {
                let nestedDir = fileURL.deletingPathExtension()
                try fileManager.createDirectory(at: nestedDir, withIntermediateDirectories: true)

                do {
                    try extractZipFile(from: fileURL, to: nestedDir)
                    print("📦 Extracted nested zip: \(fileURL.lastPathComponent)")

                    // Recursively extract any further nested zips
                    try extractNestedZips(in: nestedDir)
                } catch {
                    print("⚠️ Failed to extract nested zip: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Import Certificate

    private func importCertificate(from url: URL) async throws {
        let data = try Data(contentsOf: url)
        let filename = url.deletingPathExtension().lastPathComponent

        // Determine certificate type
        let ext = url.pathExtension.lowercased()

        if ext == "p12" || ext == "pfx" {
            // P12/PFX file - try passwords from preferences first, then common defaults
            var passwords = ["atakatak", ""] // Common TAK server passwords

            // Check if we have passwords from the preference file
            if filename.lowercased().contains("truststore") || filename.lowercased().contains("ca") {
                if let caPassword = UserDefaults.standard.string(forKey: "lastImportCAPassword") {
                    passwords.insert(caPassword, at: 0)
                }
            } else {
                if let clientPassword = UserDefaults.standard.string(forKey: "lastImportClientPassword") {
                    passwords.insert(clientPassword, at: 0)
                }
            }

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

        // Remove file extension from certificate name for consistent keychain labeling
        // e.g., "omnitak_test.p12" -> "omnitak_test"
        let certificateLabel = (name as NSString).deletingPathExtension

        // Store identity in keychain
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecValueRef as String: identity,
            kSecAttrLabel as String: certificateLabel
        ]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

        if addStatus != errSecSuccess && addStatus != errSecDuplicateItem {
            throw ImportError.certificateImportFailed("Failed to add identity to keychain: \(addStatus)")
        }

        // Update certificate manager
        certificateManager.loadCertificates()

        print("✅ Imported P12 certificate: \(certificateLabel)")
    }

    private func importPEMCertificate(data: Data, name: String) async throws {
        // Remove file extension for consistent labeling
        let certificateLabel = (name as NSString).deletingPathExtension

        // For PEM certificates, we'll store them for reference
        // In a full implementation, you'd parse the PEM and add to keychain

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueData as String: data,
            kSecAttrLabel as String: certificateLabel
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)

        if status != errSecSuccess && status != errSecDuplicateItem {
            throw ImportError.certificateImportFailed("Failed to add certificate: \(status)")
        }

        // Update certificate manager
        certificateManager.loadCertificates()

        print("✅ Imported PEM certificate: \(certificateLabel)")
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
            let protocolType: String?
            let useTLS: Bool?
            let certificateName: String?

            enum CodingKeys: String, CodingKey {
                case name, host, port, useTLS, certificateName
                case protocolType = "protocol"
            }
        }

        let decoder = JSONDecoder()
        let config = try decoder.decode(ServerConfig.self, from: data)

        // Create TAKServer
        let server = TAKServer(
            name: config.name ?? "Imported Server",
            host: config.host,
            port: UInt16(config.port),
            protocolType: config.protocolType ?? "tcp",
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
        print("ℹ️ Parsing preferences from: \(url.lastPathComponent)")

        let data = try Data(contentsOf: url)
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw ImportError.configParsingFailed("Invalid XML encoding")
        }

        // Parse TAK preference.pref format
        // Look for connectString entries like: "public.opentakserver.io:8089:ssl"
        if let connectString = extractPreferenceEntry(from: xmlString, key: "connectString0") {
            let components = connectString.split(separator: ":")
            if components.count >= 2 {
                let host = String(components[0])
                let port = UInt16(components[1]) ?? 8089
                let useTLS = components.count >= 3 && components[2] == "ssl"

                // Get server description if available
                let description = extractPreferenceEntry(from: xmlString, key: "description0") ?? "Imported Server"

                // Get certificate passwords
                let clientPassword = extractPreferenceEntry(from: xmlString, key: "clientPassword") ?? "atakatak"
                let caPassword = extractPreferenceEntry(from: xmlString, key: "caPassword") ?? "atakatak"

                // Get certificate location from preferences
                let certificateLocation = extractPreferenceEntry(from: xmlString, key: "certificateLocation")

                // Extract certificate name from path (e.g., "cert/omnitak_test.p12" -> "omnitak_test")
                var certificateName: String? = nil
                if let certPath = certificateLocation {
                    let filename = (certPath as NSString).lastPathComponent
                    certificateName = (filename as NSString).deletingPathExtension
                }

                // Store passwords for certificate import
                UserDefaults.standard.set(clientPassword, forKey: "lastImportClientPassword")
                UserDefaults.standard.set(caPassword, forKey: "lastImportCAPassword")

                let server = TAKServer(
                    name: description,
                    host: host,
                    port: port,
                    protocolType: useTLS ? "ssl" : "tcp",
                    useTLS: useTLS,
                    isDefault: false,
                    certificateName: certificateName,
                    certificatePassword: clientPassword
                )

                serverManager.addServer(server)
                print("✅ Imported server from preferences: \(description) (\(host):\(port), TLS: \(useTLS))")
            }
        }
    }

    private func extractPreferenceEntry(from xml: String, key: String) -> String? {
        // Match TAK preference format: <entry key="keyName" class="...">value</entry>
        let pattern = "key=\"\(key)\"[^>]*>([^<]*)</entry>"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(xml.startIndex..., in: xml)
        guard let match = regex.firstMatch(in: xml, range: range),
              let valueRange = Range(match.range(at: 1), in: xml) else {
            return nil
        }

        return String(xml[valueRange])
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
