//
//  MeshtasticBridge.swift
//  OmniTAK Mobile - Meshtastic Native Bridge Extension
//
//  Swift wrapper for Meshtastic mesh network connectivity
//

import Foundation
import CoreBluetooth

// MARK: - Meshtastic FFI Import

@_silgen_name("omnitak_connect_meshtastic")
private func omnitak_connect_meshtastic(
    _ connection_type: Int32,
    _ device_path: UnsafePointer<CChar>,
    _ port: UInt16,
    _ node_id: UInt32,
    _ device_name: UnsafePointer<CChar>?
) -> UInt64

// MARK: - Meshtastic Connection Types

public enum MeshtasticConnectionType: Int32, Codable {
    case serial = 0
    case bluetooth = 1
    case tcp = 2

    var displayName: String {
        switch self {
        case .serial: return "Serial/USB"
        case .bluetooth: return "Bluetooth"
        case .tcp: return "TCP/IP"
        }
    }

    var iconName: String {
        switch self {
        case .serial: return "cable.connector"
        case .bluetooth: return "antenna.radiowaves.left.and.right"
        case .tcp: return "network"
        }
    }
}

// MARK: - Meshtastic Configuration

public struct MeshtasticConfig: Codable {
    public let connectionType: MeshtasticConnectionType
    public let devicePath: String      // Serial path, BT address, or hostname
    public let port: Int?               // For TCP connections
    public let nodeId: UInt32?          // Target node (nil = broadcast)
    public let deviceName: String?      // Display name

    public init(
        connectionType: MeshtasticConnectionType,
        devicePath: String,
        port: Int? = nil,
        nodeId: UInt32? = nil,
        deviceName: String? = nil
    ) {
        self.connectionType = connectionType
        self.devicePath = devicePath
        self.port = port
        self.nodeId = nodeId
        self.deviceName = deviceName
    }
}

// MARK: - Meshtastic Device Model

public struct MeshtasticDevice: Identifiable, Codable {
    public let id: String
    public let name: String
    public let connectionType: MeshtasticConnectionType
    public let devicePath: String
    public let nodeId: UInt32?
    public var signalStrength: Int?     // RSSI
    public var batteryLevel: Int?
    public var isConnected: Bool
    public var lastSeen: Date?

    // Mesh network stats
    public var hopCount: Int?
    public var snr: Double?             // Signal-to-Noise Ratio
    public var channelUtilization: Double?
    public var airtime: Double?

    public init(
        id: String,
        name: String,
        connectionType: MeshtasticConnectionType,
        devicePath: String,
        nodeId: UInt32? = nil,
        signalStrength: Int? = nil,
        batteryLevel: Int? = nil,
        isConnected: Bool = false,
        lastSeen: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.connectionType = connectionType
        self.devicePath = devicePath
        self.nodeId = nodeId
        self.signalStrength = signalStrength
        self.batteryLevel = batteryLevel
        self.isConnected = isConnected
        self.lastSeen = lastSeen
    }
}

// MARK: - Signal Quality

public enum SignalQuality: String, Codable {
    case excellent
    case good
    case fair
    case poor
    case none

    static func from(rssi: Int?) -> SignalQuality {
        guard let rssi = rssi else { return .none }

        switch rssi {
        case -50...0: return .excellent
        case -70..<(-50): return .good
        case -90..<(-70): return .fair
        case ..<(-90): return .poor
        default: return .none
        }
    }

    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "yellow"
        case .poor: return "orange"
        case .none: return "gray"
        }
    }

    var iconName: String {
        switch self {
        case .excellent: return "antenna.radiowaves.left.and.right.circle.fill"
        case .good: return "antenna.radiowaves.left.and.right.circle"
        case .fair: return "antenna.radiowaves.left.and.right"
        case .poor: return "wifi.exclamationmark"
        case .none: return "wifi.slash"
        }
    }

    var displayText: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .none: return "No Signal"
        }
    }
}

// MARK: - Mesh Node

public struct MeshNode: Identifiable, Codable {
    public let id: UInt32
    public let shortName: String
    public let longName: String
    public var position: MeshPosition?
    public var lastHeard: Date?
    public var snr: Double?
    public var hopDistance: Int?
    public var batteryLevel: Int?

    public init(
        id: UInt32,
        shortName: String,
        longName: String,
        position: MeshPosition? = nil,
        lastHeard: Date? = nil,
        snr: Double? = nil,
        hopDistance: Int? = nil,
        batteryLevel: Int? = nil
    ) {
        self.id = id
        self.shortName = shortName
        self.longName = longName
        self.position = position
        self.lastHeard = lastHeard
        self.snr = snr
        self.hopDistance = hopDistance
        self.batteryLevel = batteryLevel
    }
}

public struct MeshPosition: Codable {
    public let latitude: Double
    public let longitude: Double
    public let altitude: Int?
    public let time: Date?

    public init(latitude: Double, longitude: Double, altitude: Int? = nil, time: Date? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.time = time
    }
}

// MARK: - Mesh Network Stats

public struct MeshNetworkStats: Codable {
    public var connectedNodes: Int
    public var totalNodes: Int
    public var averageHops: Double
    public var packetSuccessRate: Double
    public var networkUtilization: Double
    public var lastUpdate: Date

    public init(
        connectedNodes: Int = 0,
        totalNodes: Int = 0,
        averageHops: Double = 0,
        packetSuccessRate: Double = 0,
        networkUtilization: Double = 0,
        lastUpdate: Date = Date()
    ) {
        self.connectedNodes = connectedNodes
        self.totalNodes = totalNodes
        self.averageHops = averageHops
        self.packetSuccessRate = packetSuccessRate
        self.networkUtilization = networkUtilization
        self.lastUpdate = lastUpdate
    }
}

// MARK: - Meshtastic Manager Extension

extension OmniTAKNativeBridge {

    /// Connect to a Meshtastic device
    public func connectMeshtastic(config: MeshtasticConfig) -> UInt64 {
        let connectionType = config.connectionType.rawValue
        let port = UInt16(config.port ?? 0)
        let nodeId = config.nodeId ?? 0

        var connectionId: UInt64 = 0

        config.devicePath.withCString { pathPtr in
            if let deviceName = config.deviceName {
                deviceName.withCString { namePtr in
                    connectionId = omnitak_connect_meshtastic(
                        connectionType,
                        pathPtr,
                        port,
                        nodeId,
                        namePtr
                    )
                }
            } else {
                connectionId = omnitak_connect_meshtastic(
                    connectionType,
                    pathPtr,
                    port,
                    nodeId,
                    nil
                )
            }
        }

        if connectionId > 0 {
            print("✅ Meshtastic connected: \(config.deviceName ?? config.devicePath)")
        } else {
            print("❌ Failed to connect Meshtastic device")
        }

        return connectionId
    }

    /// Auto-discover Meshtastic devices
    public func discoverMeshtasticDevices(completion: @escaping ([MeshtasticDevice]) -> Void) {
        var devices: [MeshtasticDevice] = []

        // Discover Serial/USB devices
        #if os(macOS)
        let serialPaths = [
            "/dev/cu.usbserial-*",
            "/dev/cu.SLAB_USBtoUART*",
            "/dev/cu.wchusbserial*"
        ]

        for pattern in serialPaths {
            if let matches = try? FileManager.default.contentsOfDirectory(atPath: "/dev")
                .filter({ $0.hasPrefix("cu.") })
                .map({ "/dev/\($0)" }) {
                for path in matches {
                    let device = MeshtasticDevice(
                        id: path,
                        name: "Meshtastic \(path.components(separatedBy: "/").last ?? "Device")",
                        connectionType: .serial,
                        devicePath: path,
                        isConnected: false
                    )
                    devices.append(device)
                }
            }
        }
        #endif

        completion(devices)
    }
}
