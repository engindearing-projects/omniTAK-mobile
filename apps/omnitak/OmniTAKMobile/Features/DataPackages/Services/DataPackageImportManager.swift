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

    /// Published state for password prompt UI — set when a YAML config specifies `PROMPT` for a P12 password.
    @Published var pendingPasswordRequest: String? = nil
    private var passwordContinuation: CheckedContinuation<String?, Never>?
    private var yamlCertConfig: YAMLCertConfig?

    // MARK: - Password Prompt Support

    /// Called by the view when the user enters (or cancels) the certificate password prompt.
    func supplyPassword(_ password: String?) {
        guard let continuation = passwordContinuation else { return }
        passwordContinuation = nil
        pendingPasswordRequest = nil
        continuation.resume(returning: password)
    }

    /// Suspends until the user supplies a password via the UI.
    private func requestPassword(for filename: String) async -> String? {
        return await withCheckedContinuation { continuation in
            self.passwordContinuation = continuation
            self.pendingPasswordRequest = filename
        }
    }

    // MARK: - Import Package

    func importPackage(from url: URL, statusCallback: @escaping (ImportStatus) async -> Void) async throws {
        print("📦 DataPackageImportManager: Starting import from \(url.lastPathComponent)")

        // Create temporary directory
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        print("📁 Created temp directory: \(tempDir.path)")

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Extract zip file
        await statusCallback(.extracting)
        print("📦 Extracting ZIP file...")
        try extractZipFile(from: url, to: tempDir)

        // List what was extracted
        if let enumerator = fileManager.enumerator(at: tempDir, includingPropertiesForKeys: nil) {
            print("📁 Extracted files:")
            while let fileURL = enumerator.nextObject() as? URL {
                print("   - \(fileURL.path.replacingOccurrences(of: tempDir.path, with: ""))")
            }
        }

        // Find and process contents
        let contents = try findPackageContents(in: tempDir)
        print("📋 Found contents:")
        print("   - Preferences: \(contents.preferences.count)")
        print("   - Certificates: \(contents.certificates.count)")
        print("   - Server configs: \(contents.serverConfigs.count)")

        var importedItems = 0

        // Step 1: Parse preferences FIRST to get passwords for certificate import
        await statusCallback(.configuring)
        for prefURL in contents.preferences {
            print("📝 Processing preference file: \(prefURL.lastPathComponent)")
            do {
                try await parsePreferences(from: prefURL)
                importedItems += 1
                print("   ✅ Preference parsed successfully")
            } catch {
                print("   ❌ Failed to parse preferences: \(error)")
            }
        }

        // Step 2: Parse server configs BEFORE importing certs
        // YAML configs tell us which certs to use and whether to prompt for passwords
        for configURL in contents.serverConfigs {
            print("⚙️ Processing server config: \(configURL.lastPathComponent)")
            do {
                try await parseServerConfig(from: configURL)
                importedItems += 1
                print("   ✅ Server config parsed successfully")
            } catch {
                print("   ❌ Failed to parse server config: \(error)")
            }
        }

        // Step 3: Import certificates (using passwords from preferences and YAML configs)
        for certURL in contents.certificates {
            print("🔐 Processing certificate: \(certURL.lastPathComponent)")
            do {
                try await importCertificate(from: certURL)
                importedItems += 1
                print("   ✅ Certificate imported successfully")
            } catch {
                print("   ❌ Failed to import certificate: \(error)")
            }
        }

        print("📊 Import complete: \(importedItems) items imported")

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
        // Start accessing security-scoped resource for files from document picker
        let didStartAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        print("📦 Reading ZIP from: \(sourceURL.path)")
        print("   Security scoped access: \(didStartAccess)")

        // Read the ZIP data
        let zipData: Data
        do {
            zipData = try Data(contentsOf: sourceURL)
            print("📦 Read \(zipData.count) bytes from ZIP file")
        } catch {
            print("❌ Failed to read ZIP file: \(error.localizedDescription)")
            throw ImportError.extractionFailed
        }

        // Use the ZipArchive class from KMZHandler
        guard let archive = ZipArchive(data: zipData) else {
            print("❌ ZipArchive failed to parse ZIP data")
            throw ImportError.extractionFailed
        }

        print("📦 ZipArchive found \(archive.entries.count) entries")

        // Create destination directory if needed
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        // Extract each entry
        for entry in archive.entries {
            // Skip macOS resource fork files
            if entry.fileName.contains("__MACOSX") || entry.fileName.hasPrefix("._") {
                print("   ⏭️ Skipping: \(entry.fileName)")
                continue
            }

            let entryURL = destinationURL.appendingPathComponent(entry.fileName)
            print("   📄 Extracting: \(entry.fileName) (\(entry.data.count) bytes)")

            // Create parent directories if needed
            let parentDir = entryURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parentDir.path) {
                try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }

            // Write the file data
            try entry.data.write(to: entryURL)
        }

        print("📦 ZIP extraction complete")
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
            else if (ext == "xml" && !filename.contains("manifest")) || ext == "json" || ext == "yaml" || ext == "yml" || filename.contains("server") || filename.contains("connection") {
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
        let fullFilename = url.lastPathComponent

        // Determine certificate type
        let ext = url.pathExtension.lowercased()

        if ext == "p12" || ext == "pfx" {
            // P12/PFX file - try passwords from preferences first, then common defaults
            var passwords = [CertificateImportPipeline.bundledP12Password, ""] // Common TAK server passwords

            // Check if YAML config specifies a password or PROMPT for this cert
            if let yamlConfig = yamlCertConfig, fullFilename == yamlConfig.clientP12Filename {
                if yamlConfig.clientP12PasswordIsPrompt {
                    // YAML says PROMPT — ask the user for the password
                    if let prompted = await requestPassword(for: fullFilename) {
                        passwords.insert(prompted, at: 0)
                    }
                } else if let yamlPassword = yamlConfig.clientP12Password {
                    passwords.insert(yamlPassword, at: 0)
                }
            }

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

            throw ImportError.certificateImportFailed("Could not import P12 certificate with any available password")
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
              let firstItem = itemsArray.first else {
            throw ImportError.certificateImportFailed("No items found in P12")
        }

        // Remove file extension from certificate name for consistent keychain labeling
        // e.g., "omnitak_test.p12" -> "omnitak_test"
        let certificateLabel = (name as NSString).deletingPathExtension

        // Check if this is an identity (cert + key) or just certificates (truststore/CA)
        if let identity = firstItem[kSecImportItemIdentity as String] {
            // Full identity with private key - store as identity
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassIdentity,
                kSecValueRef as String: identity,
                kSecAttrLabel as String: certificateLabel
            ]

            // Delete existing first to avoid duplicates
            SecItemDelete(addQuery as CFDictionary)
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

            if addStatus != errSecSuccess && addStatus != errSecDuplicateItem {
                throw ImportError.certificateImportFailed("Failed to add identity to keychain: \(addStatus)")
            }

            print("✅ Imported P12 identity (client cert): \(certificateLabel)")
        } else if let certChain = firstItem[kSecImportItemCertChain as String] as? [SecCertificate] {
            // Certificate-only P12 (truststore/CA) - store certificates
            print("📜 Importing certificate-only P12 (truststore/CA): \(certificateLabel)")

            for (index, certificate) in certChain.enumerated() {
                let certLabel = index == 0 ? certificateLabel : "\(certificateLabel)-\(index)"
                let certQuery: [String: Any] = [
                    kSecClass as String: kSecClassCertificate,
                    kSecValueRef as String: certificate,
                    kSecAttrLabel as String: certLabel,
                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
                ]

                // Delete existing first to avoid duplicates
                SecItemDelete(certQuery as CFDictionary)
                let addStatus = SecItemAdd(certQuery as CFDictionary, nil)

                if addStatus != errSecSuccess && addStatus != errSecDuplicateItem {
                    print("⚠️ Failed to add certificate \(index) to keychain: \(addStatus)")
                } else {
                    print("✅ Imported CA certificate: \(certLabel)")
                }
            }
        } else if let trust = firstItem[kSecImportItemTrust as String] {
            // Fallback for cert-only P12 files (e.g. truststores) where kSecImportItemCertChain
            // may not be populated. Extract certificates from the SecTrust object instead.
            let trustRef = trust as! SecTrust
            print("📜 Extracting certificates from trust object for: \(certificateLabel)")

            if let certChain = SecTrustCopyCertificateChain(trustRef) as? [SecCertificate] {
                for (index, certificate) in certChain.enumerated() {
                    let certLabel = index == 0 ? certificateLabel : "\(certificateLabel)-\(index)"
                    let certQuery: [String: Any] = [
                        kSecClass as String: kSecClassCertificate,
                        kSecValueRef as String: certificate,
                        kSecAttrLabel as String: certLabel,
                        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
                    ]

                    SecItemDelete(certQuery as CFDictionary)
                    let addStatus = SecItemAdd(certQuery as CFDictionary, nil)

                    if addStatus != errSecSuccess && addStatus != errSecDuplicateItem {
                        print("⚠️ Failed to add certificate \(index) to keychain: \(addStatus)")
                    } else {
                        print("✅ Imported CA certificate (via trust): \(certLabel)")
                    }
                }
            } else {
                throw ImportError.certificateImportFailed("No certificates found in trust object")
            }
        } else {
            throw ImportError.certificateImportFailed("No identity or certificates found in P12")
        }

        // Update certificate manager
        certificateManager.loadCertificates()
    }

    private func importPEMCertificate(data: Data, name: String) async throws {
        let certificateLabel = (name as NSString).deletingPathExtension

        guard let pemString = String(data: data, encoding: .utf8) else {
            throw ImportError.certificateImportFailed("Invalid PEM encoding")
        }

        // Strip PEM headers/footers and base64-decode to get DER data
        let base64 = pemString
            .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespaces)

        guard let derData = Data(base64Encoded: base64) else {
            throw ImportError.certificateImportFailed("Failed to decode PEM base64 data")
        }

        // Create SecCertificate from DER data
        guard let certificate = SecCertificateCreateWithData(nil, derData as CFData) else {
            throw ImportError.certificateImportFailed("Failed to create certificate from DER data")
        }

        // Store in keychain using the SecCertificate ref (not raw data)
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate,
            kSecAttrLabel as String: certificateLabel,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Delete existing first to avoid duplicates
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: certificateLabel
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let status = SecItemAdd(addQuery as CFDictionary, nil)

        if status != errSecSuccess && status != errSecDuplicateItem {
            throw ImportError.certificateImportFailed("Failed to add certificate to keychain: \(status)")
        }

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
        } else if ext == "yaml" || ext == "yml" {
            try await parseYAMLConfig(data: data)
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

    // MARK: - Parse YAML Config (OmniTAK native format)

    private func parseYAMLConfig(data: Data) async throws {
        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportError.configParsingFailed("Invalid YAML encoding")
        }

        print("📄 Parsing YAML config (\(data.count) bytes)")

        // Lightweight extraction for the omnitak.yaml connection format.
        // Matches `key: value` lines — the regex word boundary prevents partial
        // key matches (e.g. "client_p12" won't match "client_p12_password").
        func extractValue(_ key: String) -> String? {
            let escaped = NSRegularExpression.escapedPattern(for: key)
            let pattern = "\\b\(escaped)\\s*:\\s*(.+)"
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
                  let valueRange = Range(match.range(at: 1), in: content) else {
                return nil
            }
            return String(content[valueRange]).trimmingCharacters(in: .whitespaces)
        }

        // Connection details
        guard let host = extractValue("host") else {
            throw ImportError.configParsingFailed("No host found in YAML config")
        }

        let name = extractValue("name") ?? "Imported Server"
        let port = UInt16(extractValue("port") ?? "8089") ?? 8089
        let protocolStr = extractValue("protocol") ?? "tcp"
        let useTLS = protocolStr == "tls" || protocolStr == "ssl"

        // TLS certificate references
        let clientP12 = extractValue("client_p12")
        let clientP12Password = extractValue("client_p12_password")
        let caCert = extractValue("ca_cert")

        print("   host=\(host) port=\(port) protocol=\(protocolStr)")
        print("   client_p12=\(clientP12 ?? "none") password=\(clientP12Password == "PROMPT" ? "PROMPT" : "(set)") ca_cert=\(caCert ?? "none")")

        // Store cert config so the certificate import step can use it
        if clientP12 != nil || caCert != nil {
            yamlCertConfig = YAMLCertConfig(
                clientP12Filename: clientP12,
                clientP12Password: clientP12Password == "PROMPT" ? nil : clientP12Password,
                clientP12PasswordIsPrompt: clientP12Password == "PROMPT",
                caCertFilename: caCert
            )
        }

        // Derive keychain labels from filenames (strip extension)
        let certificateName = clientP12.map { ($0 as NSString).deletingPathExtension }
        let caCertificateName = caCert.map { ($0 as NSString).deletingPathExtension }

        let server = TAKServer(
            name: name,
            host: host,
            port: port,
            protocolType: useTLS ? "ssl" : "tcp",
            useTLS: useTLS,
            isDefault: false,
            certificateName: certificateName,
            caCertificateName: caCertificateName
        )

        serverManager.addServer(server)
        print("✅ Imported server from YAML config: \(name) (\(host):\(port), TLS: \(useTLS))")
    }

    // MARK: - Parse Preferences

    private func parsePreferences(from url: URL) async throws {
        print("📝 parsePreferences: Reading \(url.lastPathComponent)")

        let data = try Data(contentsOf: url)
        print("   📄 Read \(data.count) bytes")

        guard let xmlString = String(data: data, encoding: .utf8) else {
            print("   ❌ Failed to decode as UTF-8")
            throw ImportError.configParsingFailed("Invalid XML encoding")
        }

        print("   📄 XML content preview: \(String(xmlString.prefix(200)))...")

        // Parse TAK preference.pref format
        // Look for connectString entries like: "public.opentakserver.io:8089:ssl"
        let connectString = extractPreferenceEntry(from: xmlString, key: "connectString0")
        print("   🔍 connectString0 = \(connectString ?? "NOT FOUND")")

        if let connectString = connectString {
            let components = connectString.split(separator: ":")
            if components.count >= 2 {
                let host = String(components[0])
                let port = UInt16(components[1]) ?? 8089
                let useTLS = components.count >= 3 && components[2] == "ssl"

                // Get server description if available
                let description = extractPreferenceEntry(from: xmlString, key: "description0") ?? "Imported Server"

                // Get certificate passwords
                let clientPassword = extractPreferenceEntry(from: xmlString, key: "clientPassword") ?? CertificateImportPipeline.bundledP12Password
                let caPassword = extractPreferenceEntry(from: xmlString, key: "caPassword") ?? CertificateImportPipeline.bundledP12Password

                // Get client certificate location from preferences
                let certificateLocation = extractPreferenceEntry(from: xmlString, key: "certificateLocation")

                // Extract client certificate name from path (e.g., "cert/xerxes-itak.p12" -> "xerxes-itak")
                var certificateName: String? = nil
                if let certPath = certificateLocation {
                    let filename = (certPath as NSString).lastPathComponent
                    certificateName = (filename as NSString).deletingPathExtension
                }

                // Get CA/truststore certificate location from preferences
                let caLocation = extractPreferenceEntry(from: xmlString, key: "caLocation")

                // Extract CA certificate name from path (e.g., "cert/truststore-root.p12" -> "truststore-root")
                var caCertificateName: String? = nil
                if let caPath = caLocation {
                    let filename = (caPath as NSString).lastPathComponent
                    caCertificateName = (filename as NSString).deletingPathExtension
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
                    certificatePassword: clientPassword,
                    caCertificateName: caCertificateName,
                    caCertificatePassword: caPassword
                )

                serverManager.addServer(server)
                print("✅ Imported server from preferences: \(description) (\(host):\(port), TLS: \(useTLS))")
                if let caCert = caCertificateName {
                    print("   📜 CA Certificate: \(caCert)")
                }
                if let clientCert = certificateName {
                    print("   🔐 Client Certificate: \(clientCert)")
                }
                return  // Success!
            }
        }

        // If we get here, no server config was found
        print("   ❌ No connectString0 found in preferences file")
        throw ImportError.configParsingFailed("No server connection found in preferences")
    }

    private func extractPreferenceEntry(from xml: String, key: String) -> String? {
        // Match TAK preference format: <entry key="keyName" class="...">value</entry>
        let pattern = "key=\"\(key)\"[^>]*>([^<]*)</entry>"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            print("      ⚠️ Failed to create regex for key: \(key)")
            return nil
        }

        let range = NSRange(xml.startIndex..., in: xml)
        guard let match = regex.firstMatch(in: xml, range: range),
              let valueRange = Range(match.range(at: 1), in: xml) else {
            // Debug: show a snippet around where the key might be
            if xml.contains(key) {
                print("      ⚠️ Key '\(key)' exists in XML but regex didn't match")
            }
            return nil
        }

        let value = String(xml[valueRange])
        print("      ✅ Found \(key) = \(value)")
        return value
    }
}

// MARK: - Package Contents

struct PackageContents {
    let certificates: [URL]
    let serverConfigs: [URL]
    let preferences: [URL]
}

// MARK: - YAML Cert Config

/// Holds certificate references parsed from an omnitak.yaml config file,
/// used to guide the subsequent certificate import step.
private struct YAMLCertConfig {
    var clientP12Filename: String?
    var clientP12Password: String?
    var clientP12PasswordIsPrompt: Bool
    var caCertFilename: String?
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
