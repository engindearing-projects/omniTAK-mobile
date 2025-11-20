//
//  MeshtasticManager.swift
//  OmniTAK Mobile
//
//  High-level Meshtastic mesh network manager with state management
//

import Foundation
import Combine
import CoreBluetooth
import CoreLocation

@MainActor
public class MeshtasticManager: ObservableObject {

    // MARK: - Published Properties

    @Published public var devices: [MeshtasticDevice] = []
    @Published public var connectedDevice: MeshtasticDevice?
    @Published public var meshNodes: [MeshNode] = []
    @Published public var networkStats: MeshNetworkStats = MeshNetworkStats()
    @Published public var isScanning: Bool = false
    @Published public var signalHistory: [SignalStrengthReading] = []
    @Published public var lastError: String?

    // MARK: - Private Properties

    private var bridge: OmniTAKNativeBridge?
    private var connectionId: UInt64 = 0
    private var signalMonitorTimer: Timer?
    private var nodeDiscoveryTimer: Timer?

    // MARK: - Initialization

    public init(bridge: OmniTAKNativeBridge? = nil) {
        self.bridge = bridge
    }

    // MARK: - Device Discovery

    /// Scan for available Meshtastic devices
    public func scanForDevices() {
        isScanning = true
        lastError = nil

        // Discover Serial/USB devices
        discoverSerialDevices()

        // Discover Bluetooth devices
        discoverBluetoothDevices()

        // Discover TCP-enabled devices
        discoverTCPDevices()

        // Stop scanning after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.isScanning = false
        }
    }

    private func discoverSerialDevices() {
        #if os(macOS)
        let serialPaths = [
            "/dev/cu.usbserial",
            "/dev/cu.SLAB_USBtoUART",
            "/dev/cu.wchusbserial",
            "/dev/tty.usbserial"
        ]

        for basePath in serialPaths {
            if let paths = try? FileManager.default.contentsOfDirectory(atPath: "/dev")
                .filter({ $0.contains(basePath.replacingOccurrences(of: "/dev/", with: "")) })
                .map({ "/dev/\($0)" }) {

                for path in paths {
                    if !devices.contains(where: { $0.devicePath == path }) {
                        let device = MeshtasticDevice(
                            id: UUID().uuidString,
                            name: "Meshtastic USB",
                            connectionType: .serial,
                            devicePath: path,
                            isConnected: false,
                            lastSeen: Date()
                        )
                        devices.append(device)
                    }
                }
            }
        }
        #endif

        #if os(iOS)
        // iOS doesn't support direct serial access, but document for completeness
        // Users would need MFi-certified USB accessories
        #endif
    }

    private func discoverBluetoothDevices() {
        // Bluetooth LE scanning will be implemented in BluetoothManager
        // For now, add a placeholder for manual entry
        let btDevice = MeshtasticDevice(
            id: "bluetooth-manual",
            name: "Bluetooth Meshtastic (Manual)",
            connectionType: .bluetooth,
            devicePath: "00:00:00:00:00:00",
            isConnected: false
        )

        if !devices.contains(where: { $0.id == btDevice.id }) {
            devices.append(btDevice)
        }
    }

    private func discoverTCPDevices() {
        // Add common TCP device entry
        let tcpDevice = MeshtasticDevice(
            id: "tcp-local",
            name: "TCP Meshtastic (192.168.x.x)",
            connectionType: .tcp,
            devicePath: "192.168.1.100",
            isConnected: false
        )

        if !devices.contains(where: { $0.id == tcpDevice.id }) {
            devices.append(tcpDevice)
        }
    }

    // MARK: - Connection Management

    /// Connect to a Meshtastic device
    public func connect(to device: MeshtasticDevice) {
        guard let bridge = bridge else {
            lastError = "Native bridge not initialized"
            return
        }

        lastError = nil

        let config = MeshtasticConfig(
            connectionType: device.connectionType,
            devicePath: device.devicePath,
            port: device.connectionType == .tcp ? 4403 : nil,
            nodeId: device.nodeId,
            deviceName: device.name
        )

        connectionId = bridge.connectMeshtastic(config: config)

        if connectionId > 0 {
            var updatedDevice = device
            updatedDevice.isConnected = true
            updatedDevice.lastSeen = Date()

            connectedDevice = updatedDevice

            // Update device in list
            if let index = devices.firstIndex(where: { $0.id == device.id }) {
                devices[index] = updatedDevice
            }

            // Start monitoring
            startSignalMonitoring()
            startNodeDiscovery()

            print("✅ Connected to Meshtastic: \(device.name)")
        } else {
            lastError = "Failed to connect to \(device.name)"
            print("❌ Connection failed")
        }
    }

    /// Disconnect from current device
    public func disconnect() {
        guard let bridge = bridge, connectionId > 0 else { return }

        bridge.disconnect(connectionId: Int(connectionId))

        if var device = connectedDevice {
            device.isConnected = false
            if let index = devices.firstIndex(where: { $0.id == device.id }) {
                devices[index] = device
            }
        }

        connectedDevice = nil
        connectionId = 0

        stopSignalMonitoring()
        stopNodeDiscovery()

        print("⚡ Disconnected from Meshtastic")
    }

    // MARK: - Signal Monitoring

    private func startSignalMonitoring() {
        signalMonitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateSignalStrength()
            }
        }
    }

    private func stopSignalMonitoring() {
        signalMonitorTimer?.invalidate()
        signalMonitorTimer = nil
    }

    private func updateSignalStrength() {
        guard var device = connectedDevice else { return }

        // Simulate signal readings (real implementation would query device)
        let rssi = Int.random(in: -100...(-40))
        device.signalStrength = rssi

        let reading = SignalStrengthReading(
            timestamp: Date(),
            rssi: rssi,
            snr: Double.random(in: -10...20)
        )

        signalHistory.append(reading)

        // Keep only last 100 readings
        if signalHistory.count > 100 {
            signalHistory.removeFirst()
        }

        connectedDevice = device

        // Update in devices list
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index] = device
        }
    }

    // MARK: - Node Discovery

    private func startNodeDiscovery() {
        nodeDiscoveryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.discoverMeshNodes()
            }
        }

        // Immediate first discovery
        discoverMeshNodes()
    }

    private func stopNodeDiscovery() {
        nodeDiscoveryTimer?.invalidate()
        nodeDiscoveryTimer = nil
    }

    private func discoverMeshNodes() {
        // Simulate mesh node discovery (real implementation would parse from device)
        // In production, this would come from NODEINFO_APP messages

        let sampleNodes = [
            MeshNode(
                id: 0x12345678,
                shortName: "MESH-A",
                longName: "Alpha Node",
                position: MeshPosition(latitude: 37.7749, longitude: -122.4194),
                lastHeard: Date(),
                snr: 12.5,
                hopDistance: 1,
                batteryLevel: 85
            ),
            MeshNode(
                id: 0x23456789,
                shortName: "MESH-B",
                longName: "Bravo Node",
                position: MeshPosition(latitude: 37.7849, longitude: -122.4094),
                lastHeard: Date().addingTimeInterval(-30),
                snr: 8.2,
                hopDistance: 2,
                batteryLevel: 60
            ),
            MeshNode(
                id: 0x34567890,
                shortName: "MESH-C",
                longName: "Charlie Node",
                position: MeshPosition(latitude: 37.7649, longitude: -122.4294),
                lastHeard: Date().addingTimeInterval(-60),
                snr: 5.1,
                hopDistance: 3,
                batteryLevel: 40
            )
        ]

        // Update only if we have a connected device
        if connectedDevice != nil {
            meshNodes = sampleNodes

            // Update network stats
            networkStats = MeshNetworkStats(
                connectedNodes: sampleNodes.filter { $0.hopDistance ?? 999 <= 3 }.count,
                totalNodes: sampleNodes.count,
                averageHops: Double(sampleNodes.compactMap { $0.hopDistance }.reduce(0, +)) / Double(max(sampleNodes.count, 1)),
                packetSuccessRate: 0.92,
                networkUtilization: 0.35,
                lastUpdate: Date()
            )
        }
    }

    // MARK: - Messaging

    /// Send a CoT message through the mesh
    public func sendCoT(_ cotXML: String) -> Bool {
        guard let bridge = bridge, connectionId > 0 else {
            lastError = "Not connected to Meshtastic device"
            return false
        }

        let result = bridge.sendCot(connectionId: Int(connectionId), cotXml: cotXML)

        if result == 0 {
            print("📡 Sent CoT through mesh network")
            return true
        } else {
            lastError = "Failed to send CoT message"
            print("❌ Failed to send CoT")
            return false
        }
    }

    /// Get signal quality for current connection
    public var signalQuality: SignalQuality {
        return SignalQuality.from(rssi: connectedDevice?.signalStrength)
    }

    /// Check if device is connected
    public var isConnected: Bool {
        return connectedDevice?.isConnected ?? false
    }

    /// Get formatted connection status
    public var connectionStatus: String {
        if let device = connectedDevice {
            return "Connected: \(device.name)"
        } else {
            return "Not Connected"
        }
    }

    /// Get mesh network health indicator
    public var networkHealth: NetworkHealth {
        if !isConnected {
            return .disconnected
        }

        let connectedRatio = Double(networkStats.connectedNodes) / Double(max(networkStats.totalNodes, 1))

        if connectedRatio > 0.8 && networkStats.packetSuccessRate > 0.9 {
            return .excellent
        } else if connectedRatio > 0.6 && networkStats.packetSuccessRate > 0.7 {
            return .good
        } else if connectedRatio > 0.4 {
            return .fair
        } else {
            return .poor
        }
    }
}

// MARK: - Supporting Types

public struct SignalStrengthReading {
    public let timestamp: Date
    public let rssi: Int
    public let snr: Double
}

public enum NetworkHealth {
    case disconnected
    case poor
    case fair
    case good
    case excellent

    var color: String {
        switch self {
        case .disconnected: return "gray"
        case .poor: return "red"
        case .fair: return "orange"
        case .good: return "blue"
        case .excellent: return "green"
        }
    }

    var displayText: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .poor: return "Poor"
        case .fair: return "Fair"
        case .good: return "Good"
        case .excellent: return "Excellent"
        }
    }
}
