//
//  MeshtasticManager.swift
//  OmniTAK Mobile
//
//  Meshtastic mesh network manager - TCP and Bluetooth connections
//

import Foundation
import Combine
import SwiftUI
import CoreBluetooth

@MainActor
public class MeshtasticManager: ObservableObject {

    // MARK: - Published Properties

    @Published public var connectedDevice: MeshtasticDevice?
    @Published public var meshNodes: [MeshNode] = []
    @Published public var lastError: String?
    @Published public var connectionState: String = "Disconnected"
    @Published public var myNodeNum: UInt32 = 0
    @Published public var firmwareVersion: String = ""

    // BLE-specific properties
    @Published public var isScanning: Bool = false
    @Published public var discoveredBLEDevices: [DiscoveredBLEDevice] = []
    @Published public var bluetoothState: CBManagerState = .unknown

    // MARK: - Private Properties

    private var _tcpClient: Any? = nil
    private var _bleClient: Any? = nil

    @available(iOS 13.0, *)
    private var tcpClient: MeshtasticTCPClient {
        if _tcpClient == nil {
            _tcpClient = MeshtasticTCPClient()
            setupTCPClientObservers()
        }
        return _tcpClient as! MeshtasticTCPClient
    }

    @available(iOS 13.0, *)
    private var bleClient: MeshtasticBLEClient {
        if _bleClient == nil {
            _bleClient = MeshtasticBLEClient()
            setupBLEClientObservers()
        }
        return _bleClient as! MeshtasticBLEClient
    }

    private var tcpClientCancellables = Set<AnyCancellable>()
    private var bleClientCancellables = Set<AnyCancellable>()

    // Saved TCP connections
    @AppStorage("meshtastic_saved_hosts") private var savedHostsData: Data = Data()

    // MARK: - Initialization

    public init() {
        // TCP client is lazily initialized when needed
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

    // MARK: - BLE Client Setup

    @available(iOS 13.0, *)
    private func setupBLEClientObservers() {
        guard let client = _bleClient as? MeshtasticBLEClient else { return }

        client.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (connected: Bool) in
                if connected {
                    // Enable auto map updates when connected
                    self?.enableAutoMapUpdates()
                    // Update device connection status
                    if var device = self?.connectedDevice {
                        device.isConnected = true
                        self?.connectedDevice = device
                    }
                } else {
                    self?.handleDisconnection()
                    self?.disableAutoMapUpdates()
                }
            }
            .store(in: &bleClientCancellables)

        client.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (state: MeshtasticBLEClient.ConnectionState) in
                self?.connectionState = state.rawValue
            }
            .store(in: &bleClientCancellables)

        client.$nodes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (nodes: [UInt32: MeshNode]) in
                self?.meshNodes = Array(nodes.values)
            }
            .store(in: &bleClientCancellables)

        client.$myNodeNum
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (nodeNum: UInt32) in
                self?.myNodeNum = nodeNum
            }
            .store(in: &bleClientCancellables)

        client.$firmwareVersion
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (version: String) in
                self?.firmwareVersion = version
            }
            .store(in: &bleClientCancellables)

        client.$lastError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (error: String?) in
                self?.lastError = error
            }
            .store(in: &bleClientCancellables)

        client.$isScanning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (scanning: Bool) in
                self?.isScanning = scanning
            }
            .store(in: &bleClientCancellables)

        client.$discoveredDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (devices: [DiscoveredBLEDevice]) in
                self?.discoveredBLEDevices = devices
            }
            .store(in: &bleClientCancellables)

        client.$bluetoothState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (state: CBManagerState) in
                self?.bluetoothState = state
            }
            .store(in: &bleClientCancellables)
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

    // MARK: - BLE Scanning

    /// Start scanning for Bluetooth Meshtastic devices
    public func startBLEScanning() {
        guard #available(iOS 13.0, *) else {
            lastError = "Bluetooth requires iOS 13.0 or later"
            return
        }

        lastError = nil
        bleClient.startScanning()
    }

    /// Stop BLE scanning
    public func stopBLEScanning() {
        guard #available(iOS 13.0, *) else { return }
        bleClient.stopScanning()
    }

    /// Connect to a discovered BLE device
    public func connectBLE(device: DiscoveredBLEDevice) {
        guard #available(iOS 13.0, *) else {
            lastError = "Bluetooth requires iOS 13.0 or later"
            return
        }

        lastError = nil

        // Create a MeshtasticDevice for the BLE device
        let meshtasticDevice = MeshtasticDevice(
            id: device.id.uuidString,
            name: device.name,
            connectionType: .bluetooth,
            devicePath: device.id.uuidString,
            isConnected: false,
            signalStrength: device.rssi,
            nodeId: nil,
            lastSeen: Date()
        )

        connectedDevice = meshtasticDevice
        bleClient.connect(to: device)

        print("Connecting to BLE device: \(device.name)")
    }

    // MARK: - Connection Management

    /// Connect to a Meshtastic device
    public func connect(to device: MeshtasticDevice) {
        lastError = nil

        switch device.connectionType {
        case .bluetooth:
            // For BLE, need to scan and find the device first
            lastError = "Use connectBLE() with a discovered device for Bluetooth connections"

        case .tcp:
            let port = UInt16(device.nodeId ?? "4403") ?? 4403
            connectTCP(host: device.devicePath, port: port, device: device)
        }
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
        guard #available(iOS 13.0, *) else { return }

        // Only disconnect the client type we're actually using
        if let device = connectedDevice {
            switch device.connectionType {
            case .bluetooth:
                if let client = _bleClient as? MeshtasticBLEClient {
                    client.disconnect()
                }
            case .tcp:
                if let client = _tcpClient as? MeshtasticTCPClient {
                    client.disconnect()
                }
            }
        }
        // Don't disconnect "just in case" - this causes issues during connection

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

        if let device = connectedDevice {
            switch device.connectionType {
            case .bluetooth:
                bleClient.sendTextMessage(text, to: destination)
            case .tcp:
                tcpClient.sendTextMessage(text, to: destination)
            }
        }
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

    // MARK: - TAK Map Integration

    /// Callback for when CoT events are generated from mesh nodes (XML format)
    public var onCoTGenerated: ((String) -> Void)?

    /// Whether automatic map updates are enabled
    @Published public var autoMapUpdateEnabled: Bool = true

    private var mapUpdateCancellable: AnyCancellable?

    /// Publish all mesh nodes with positions to the TAK map
    public func publishMeshNodesToMap() {
        let cotEvents = MeshtasticCoTConverter.toCoTEvents(nodes: meshNodes, ownNodeId: myNodeNum)
        for event in cotEvents {
            TAKService.shared.updateEnhancedMarker(from: event)
        }
        print("📍 Published \(cotEvents.count) mesh nodes to TAK map")
    }

    /// Publish a single node to the TAK map
    public func publishNodeToMap(_ node: MeshNode) {
        let isOwn = node.id == myNodeNum
        if let event = MeshtasticCoTConverter.toCoTEvent(node: node, isOwnNode: isOwn) {
            TAKService.shared.updateEnhancedMarker(from: event)
            print("📍 Published node \(node.shortName) to TAK map")
        }
    }

    /// Generate CoT XML for all mesh nodes with positions
    public func publishMeshNodesToCoT() {
        let cotEvents = MeshtasticCoTConverter.generateCoTForAllNodes(meshNodes)
        for cotXML in cotEvents {
            onCoTGenerated?(cotXML)
        }
        print("Published \(cotEvents.count) mesh nodes as CoT XML")
    }

    /// Generate CoT XML for a specific node
    public func generateCoT(for node: MeshNode) -> String? {
        return MeshtasticCoTConverter.generateCoT(for: node)
    }

    /// Get nodes with valid positions
    public var nodesWithPositions: [MeshNode] {
        meshNodes.filter { $0.position != nil }
    }

    /// Enable automatic publishing of mesh nodes to TAK map when nodes are updated
    public func enableAutoMapUpdates() {
        guard autoMapUpdateEnabled else { return }

        mapUpdateCancellable?.cancel()

        // Subscribe to node changes and publish to map
        mapUpdateCancellable = $meshNodes
            .receive(on: DispatchQueue.main)
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] nodes in
                guard let self = self, self.autoMapUpdateEnabled else { return }
                if !nodes.isEmpty {
                    self.publishMeshNodesToMap()
                }
            }
        print("🗺️ Auto map updates enabled for Meshtastic nodes")
    }

    /// Disable automatic map updates
    public func disableAutoMapUpdates() {
        mapUpdateCancellable?.cancel()
        mapUpdateCancellable = nil
        print("🗺️ Auto map updates disabled")
    }

    /// Remove all Meshtastic markers from TAK map
    public func clearMeshMarkersFromMap() {
        // TAKService uses enhancedMarkers dictionary with UID as key
        // We'd need TAKService to expose a remove method, but for now just let them expire
        // meshNodes count: \(meshNodes.count) markers will expire
        print("🗺️ Mesh markers will expire from map")
    }
}
