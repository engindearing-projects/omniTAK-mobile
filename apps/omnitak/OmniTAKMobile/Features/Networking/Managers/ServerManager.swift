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
    var certificateName: String?  // Name of certificate file (e.g., "omnitak-mobile")
    var certificatePassword: String?  // Password for .p12 certificate
    var allowLegacyTLS: Bool  // Allow TLS 1.0/1.1 for extremely old servers (security risk)

    init(id: UUID = UUID(), name: String, host: String, port: UInt16, protocolType: String = "tcp", useTLS: Bool = false, isDefault: Bool = false, certificateName: String? = nil, certificatePassword: String? = nil, allowLegacyTLS: Bool = false) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.protocolType = protocolType
        self.useTLS = useTLS
        self.isDefault = isDefault
        self.certificateName = certificateName
        self.certificatePassword = certificatePassword
        self.allowLegacyTLS = allowLegacyTLS
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

    init() {
        loadServers()

        // Add default server if no servers exist
        if servers.isEmpty {
            let defaultServer = TAKServer(
                name: "Taky Server",
                host: "127.0.0.1",
                port: 8087,
                protocolType: "tcp",
                useTLS: false,
                isDefault: true
            )
            addServer(defaultServer)
            setActiveServer(defaultServer)
        }
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

    func getDefaultServer() -> TAKServer? {
        return servers.first { $0.isDefault } ?? servers.first
    }
}
