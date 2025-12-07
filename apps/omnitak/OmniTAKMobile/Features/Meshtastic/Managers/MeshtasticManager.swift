//
//  MeshtasticManager.swift
//  OmniTAK Mobile
//
//  Meshtastic mesh network manager - TCP/Network connections only
//

import Foundation
import Combine
import SwiftUI

@MainActor
public class MeshtasticManager: ObservableObject {

    // MARK: - Singleton

    /// Shared instance for app-wide Meshtastic management
    public static let shared = MeshtasticManager()

    // MARK: - Published Properties

    @Published public var connectedDevice: MeshtasticDevice?
    @Published public var meshNodes: [MeshNode] = []
    @Published public var lastError: String?
    @Published public var connectionState: String = "Disconnected"
    @Published public var myNodeNum: UInt32 = 0
    @Published public var firmwareVersion: String = ""

    // MARK: - Private Properties

    private var _tcpClient: Any? = nil

    @available(iOS 13.0, *)
    private var tcpClient: MeshtasticTCPClient {
        if _tcpClient == nil {
            _tcpClient = MeshtasticTCPClient()
            setupTCPClientObservers()
        }
        return _tcpClient as! MeshtasticTCPClient
    }

    private var tcpClientCancellables = Set<AnyCancellable>()

    // Saved TCP connections
    @AppStorage("meshtastic_saved_hosts") private var savedHostsData: Data = Data()

    // MARK: - Initialization

    public init() {
        // TCP client is lazily initialized when needed
        // Configure COT bridge to convert mesh nodes to map markers
        configureCOTBridge()
    }

    /// Configure the COT bridge for converting Meshtastic data to TAK format
    private func configureCOTBridge() {
        MeshtasticCOTBridge.shared.configure(meshtasticManager: self)
        print("MeshtasticManager: COT bridge configured")
    }

    // MARK: - TCP Client Setup

    @available(iOS 13.0, *)
    private func setupTCPClientObservers() {
        guard let client = _tcpClient as? MeshtasticTCPClient else { return }

        client.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (connected: Bool) in
                if !connected {
                    self?.handleDisconnection()
                }
            }
            .store(in: &tcpClientCancellables)

        client.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (state: MeshtasticTCPClient.ConnectionState) in
                self?.connectionState = state.rawValue
            }
            .store(in: &tcpClientCancellables)

        client.$nodes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (nodes: [UInt32: MeshNode]) in
                self?.meshNodes = Array(nodes.values)
            }
            .store(in: &tcpClientCancellables)

        client.$myNodeNum
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (nodeNum: UInt32) in
                self?.myNodeNum = nodeNum
            }
            .store(in: &tcpClientCancellables)

        client.$firmwareVersion
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (version: String) in
                self?.firmwareVersion = version
            }
            .store(in: &tcpClientCancellables)

        client.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (error: String?) in
                self?.lastError = error
            }
            .store(in: &tcpClientCancellables)
    }

    private func handleDisconnection() {
        if var device = connectedDevice {
            device.isConnected = false
            connectedDevice = device
        }
    }

    // MARK: - Saved Hosts

    public struct SavedHost: Codable, Identifiable {
        public var id: String { "\(host):\(port)" }
        public var host: String
        public var port: UInt16
        public var name: String
        public var lastConnected: Date?
    }

    public var savedHosts: [SavedHost] {
        get {
            (try? JSONDecoder().decode([SavedHost].self, from: savedHostsData)) ?? []
        }
        set {
            savedHostsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    public func saveHost(_ host: String, port: UInt16, name: String) {
        var hosts = savedHosts
        if let idx = hosts.firstIndex(where: { $0.host == host && $0.port == port }) {
            hosts[idx].name = name
            hosts[idx].lastConnected = Date()
        } else {
            hosts.append(SavedHost(host: host, port: port, name: name, lastConnected: Date()))
        }
        savedHosts = hosts
    }

    public func removeHost(_ host: String, port: UInt16) {
        savedHosts.removeAll { $0.host == host && $0.port == port }
    }

    // MARK: - Connection Management

    /// Connect to a Meshtastic device (TCP only for iOS)
    public func connect(to device: MeshtasticDevice) {
        lastError = nil

        guard device.connectionType == .tcp else {
            lastError = "Only TCP/Network connections are supported on iOS"
            return
        }

        let port = UInt16(device.nodeId ?? "4403") ?? 4403
        connectTCP(host: device.devicePath, port: port, device: device)
    }

    /// Connect via TCP to a Meshtastic device
    public func connectTCP(host: String, port: UInt16 = 4403, device: MeshtasticDevice? = nil) {
        guard #available(iOS 13.0, *) else {
            lastError = "TCP connections require iOS 13.0 or later"
            return
        }

        lastError = nil

        // Create or use provided device
        var targetDevice = device ?? MeshtasticDevice(
            id: "tcp-\(host)-\(port)",
            name: "\(host):\(port)",
            connectionType: .tcp,
            devicePath: host,
            isConnected: false,
            nodeId: "\(port)"
        )

        // Connect via TCP client
        tcpClient.connect(host: host, port: port)

        // Update device state
        targetDevice.isConnected = true
        targetDevice.lastSeen = Date()
        connectedDevice = targetDevice

        // Save for future use
        saveHost(host, port: port, name: targetDevice.name)

        print("Connecting to Meshtastic TCP: \(host):\(port)")
    }

    /// Disconnect from current device
    public func disconnect() {
        if #available(iOS 13.0, *) {
            tcpClient.disconnect()
        }

        if var device = connectedDevice {
            device.isConnected = false
        }

        connectedDevice = nil
        meshNodes.removeAll()
        myNodeNum = 0
        firmwareVersion = ""
        connectionState = "Disconnected"

        print("Disconnected from Meshtastic")
    }

    /// Send a text message through the mesh
    public func sendMessage(_ text: String, to destination: UInt32 = 0xFFFFFFFF) {
        guard #available(iOS 13.0, *), isConnected else {
            lastError = "Not connected"
            return
        }

        tcpClient.sendTextMessage(text, to: destination)
    }

    // MARK: - Status Properties

    /// Check if device is connected
    public var isConnected: Bool {
        connectedDevice?.isConnected ?? false
    }

    /// Get formatted connection status
    public var connectionStatus: String {
        if let device = connectedDevice, device.isConnected {
            return "Connected: \(device.name)"
        }
        return "Not Connected"
    }
}
