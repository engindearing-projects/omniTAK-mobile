//
//  ServerManager.swift
//  OmniTAKTest
//
//  TAK Server configuration and management
//

import Foundation
import Combine

// MARK: - TAK Server Configuration

struct TAKServer: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var host: String
    var port: UInt16
    var protocolType: String
    var useTLS: Bool
    var isDefault: Bool
    var enabled: Bool  // Whether server is enabled for connection (like ATAK checkbox)
    var certificateName: String?  // Name of client certificate file (e.g., "omnitak-mobile")
    var certificatePassword: String?  // Password for .p12 certificate
    var caCertificateName: String?  // Name of CA/truststore certificate for server verification
    var caCertificatePassword: String?  // Password for CA .p12 certificate
    var allowLegacyTLS: Bool  // Allow TLS 1.0/1.1 for extremely old servers (security risk)
    var username: String?  // Username for enrollment
    var password: String?  // Password for enrollment
    var enrollmentPort: UInt16?  // Enrollment API port (default 8446)

    init(id: UUID = UUID(), name: String, host: String, port: UInt16, protocolType: String = "tcp", useTLS: Bool = false, isDefault: Bool = false, enabled: Bool = true, certificateName: String? = nil, certificatePassword: String? = nil, caCertificateName: String? = nil, caCertificatePassword: String? = nil, allowLegacyTLS: Bool = false, username: String? = nil, password: String? = nil, enrollmentPort: UInt16? = nil) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.protocolType = protocolType
        self.useTLS = useTLS
        self.isDefault = isDefault
        self.enabled = enabled
        self.certificateName = certificateName
        self.certificatePassword = certificatePassword
        self.caCertificateName = caCertificateName
        self.caCertificatePassword = caCertificatePassword
        self.allowLegacyTLS = allowLegacyTLS
        self.username = username
        self.password = password
        self.enrollmentPort = enrollmentPort
    }

    var displayName: String {
        return "\(name) (\(host):\(port))"
    }
}

// MARK: - Server Manager

class ServerManager: ObservableObject {
    static let shared = ServerManager()

    @Published var servers: [TAKServer] = []
    @Published var activeServer: TAKServer?

    private let serversKey = "tak_servers"
    private let activeServerKey = "active_server_id"

    private let bundledServerSetupKey = "bundled_server_setup_v2"

    init() {
        loadServers()

        // Set up bundled server on first launch
        setupBundledServerIfNeeded()
    }

    // MARK: - Bundled Server Setup

    private func setupBundledServerIfNeeded() {
        // Only run once per app version
        guard !UserDefaults.standard.bool(forKey: bundledServerSetupKey) else { return }

        // Import bundled certificates and add default server
        Task {
            await importBundledCertificates()
            await MainActor.run {
                addBundledServer()
                UserDefaults.standard.set(true, forKey: bundledServerSetupKey)
            }
        }
    }

    private func importBundledCertificates() async {
        // Import client certificate from bundle
        if let clientCertURL = Bundle.main.url(forResource: "bundled-client", withExtension: "p12") {
            do {
                let data = try Data(contentsOf: clientCertURL)
                try importP12ToKeychain(data: data, password: "atakatak", label: "bundled-client")
                print("✅ Imported bundled client certificate")
            } catch {
                print("⚠️ Failed to import bundled client certificate: \(error)")
            }
        } else {
            print("⚠️ bundled-client.p12 not found in app bundle")
        }

        // Import CA/truststore from bundle
        if let caCertURL = Bundle.main.url(forResource: "bundled-ca", withExtension: "p12") {
            do {
                let data = try Data(contentsOf: caCertURL)
                try importP12ToKeychain(data: data, password: "atakatak", label: "bundled-ca")
                print("✅ Imported bundled CA certificate")
            } catch {
                print("⚠️ Failed to import bundled CA certificate: \(error)")
            }
        } else {
            print("⚠️ bundled-ca.p12 not found in app bundle")
        }
    }

    private func importP12ToKeychain(data: Data, password: String, label: String) throws {
        let options: [String: Any] = [kSecImportExportPassphrase as String: password]
        var items: CFArray?
        let status = SecPKCS12Import(data as CFData, options as CFDictionary, &items)

        guard status == errSecSuccess,
              let itemsArray = items as? [[String: Any]],
              let firstItem = itemsArray.first,
              let identity = firstItem[kSecImportItemIdentity as String] else {
            throw NSError(domain: "CertImport", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Failed to import P12"])
        }

        // Store identity in keychain
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecValueRef as String: identity,
            kSecAttrLabel as String: label
        ]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus != errSecSuccess && addStatus != errSecDuplicateItem {
            throw NSError(domain: "CertImport", code: Int(addStatus), userInfo: [NSLocalizedDescriptionKey: "Failed to add to keychain"])
        }
    }

    private func addBundledServer() {
        // Check if server already exists
        let existingServer = servers.first { $0.host == "tak.engindearing.soy" && $0.port == 8089 }
        guard existingServer == nil else {
            print("ℹ️ Bundled server already exists")
            return
        }

        let bundledServer = TAKServer(
            name: "TAK Server",
            host: "tak.engindearing.soy",
            port: 8089,
            protocolType: "ssl",
            useTLS: true,
            isDefault: true,
            enabled: true,
            certificateName: "bundled-client",
            certificatePassword: "atakatak"
        )

        servers.insert(bundledServer, at: 0)
        activeServer = bundledServer
        saveServers()
        saveActiveServer()
        print("✅ Added bundled TAK server: \(bundledServer.displayName)")
    }

    // MARK: - Persistence

    private func loadServers() {
        if let data = UserDefaults.standard.data(forKey: serversKey),
           let decoded = try? JSONDecoder().decode([TAKServer].self, from: data) {
            servers = decoded
        }

        // Load active server
        if let activeId = UserDefaults.standard.string(forKey: activeServerKey),
           let uuid = UUID(uuidString: activeId),
           let server = servers.first(where: { $0.id == uuid }) {
            activeServer = server
        } else if let first = servers.first {
            activeServer = first
        }
    }

    private func saveServers() {
        if let encoded = try? JSONEncoder().encode(servers) {
            UserDefaults.standard.set(encoded, forKey: serversKey)
        }
    }

    private func saveActiveServer() {
        if let id = activeServer?.id.uuidString {
            UserDefaults.standard.set(id, forKey: activeServerKey)
        }
    }

    // MARK: - Server Management

    func addServer(_ server: TAKServer) {
        servers.append(server)
        saveServers()
        #if DEBUG
        print("✅ Added server: \(server.displayName)")
        #endif

        // Auto-connect if the server is enabled
        if server.enabled {
            TAKService.shared.connectToServer(server)
        }
    }

    func updateServer(_ server: TAKServer) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index] = server

            // Update active server if it's the one being edited
            if activeServer?.id == server.id {
                activeServer = server
                saveActiveServer()
            }

            saveServers()
            #if DEBUG
            print("✅ Updated server: \(server.displayName)")
            #endif
        }
    }

    func deleteServer(_ server: TAKServer) {
        servers.removeAll { $0.id == server.id }

        // If active server was deleted, switch to first available
        if activeServer?.id == server.id {
            activeServer = servers.first
            saveActiveServer()
        }

        saveServers()
        #if DEBUG
        print("🗑️ Deleted server: \(server.displayName)")
        #endif
    }

    func setActiveServer(_ server: TAKServer) {
        activeServer = server
        saveActiveServer()
        print("🔄 Active server set to: \(server.displayName)")
    }

    func toggleServerEnabled(_ server: TAKServer) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index].enabled.toggle()

            // Update active server reference if needed
            if activeServer?.id == server.id {
                activeServer = servers[index]
            }

            saveServers()
            #if DEBUG
            print("🔀 Server \(server.name) enabled: \(servers[index].enabled)")
            #endif
        }
    }

    func getDefaultServer() -> TAKServer? {
        return servers.first { $0.isDefault } ?? servers.first
    }

    // MARK: - Multi-Server Support

    /// Get all enabled servers
    func getEnabledServers() -> [TAKServer] {
        return servers.filter { $0.enabled }
    }

    /// Enable a specific server
    func enableServer(_ server: TAKServer) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index].enabled = true
            saveServers()
            #if DEBUG
            print("✅ Server \(server.name) enabled")
            #endif
        }
    }

    /// Disable a specific server
    func disableServer(_ server: TAKServer) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) {
            servers[index].enabled = false
            saveServers()
            #if DEBUG
            print("❌ Server \(server.name) disabled")
            #endif
        }
    }

    /// Enable all servers
    func enableAllServers() {
        for index in servers.indices {
            servers[index].enabled = true
        }
        saveServers()
        #if DEBUG
        print("✅ All servers enabled")
        #endif
    }

    /// Disable all servers
    func disableAllServers() {
        for index in servers.indices {
            servers[index].enabled = false
        }
        saveServers()
        #if DEBUG
        print("❌ All servers disabled")
        #endif
    }

    /// Connect to all enabled servers
    func connectToEnabledServers() {
        let enabledServers = getEnabledServers()
        for server in enabledServers {
            TAKService.shared.connectToServer(server)
        }
        #if DEBUG
        print("🔌 Connecting to \(enabledServers.count) enabled server(s)")
        #endif
    }
}
