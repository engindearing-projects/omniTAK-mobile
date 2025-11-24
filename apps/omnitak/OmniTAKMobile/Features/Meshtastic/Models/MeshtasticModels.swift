//
//  MeshtasticModels.swift
//  OmniTAK Mobile
//
//  Meshtastic mesh networking data models
//

import Foundation
import CoreLocation

// MARK: - Device Models

public enum MeshtasticConnectionType: String, Codable, CaseIterable {
    case serial = "Serial/USB"
    case bluetooth = "Bluetooth LE"
    case tcp = "TCP/IP"

    public var displayName: String {
        return self.rawValue
    }

    public var iconName: String {
        switch self {
        case .serial: return "cable.connector"
        case .bluetooth: return "antenna.radiowaves.left.and.right"
        case .tcp: return "network"
        }
    }
}

public struct MeshtasticDevice: Identifiable, Codable {
    public let id: String
    public var name: String
    public var connectionType: MeshtasticConnectionType
    public var devicePath: String
    public var isConnected: Bool
    public var signalStrength: Int?
    public var snr: Double?
    public var hopCount: Int?
    public var batteryLevel: Int?
    public var nodeId: String?
    public var lastSeen: Date?

    public init(
        id: String,
        name: String,
        connectionType: MeshtasticConnectionType,
        devicePath: String,
        isConnected: Bool,
        signalStrength: Int? = nil,
        snr: Double? = nil,
        hopCount: Int? = nil,
        batteryLevel: Int? = nil,
        nodeId: String? = nil,
        lastSeen: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.connectionType = connectionType
        self.devicePath = devicePath
        self.isConnected = isConnected
        self.signalStrength = signalStrength
        self.snr = snr
        self.hopCount = hopCount
        self.batteryLevel = batteryLevel
        self.nodeId = nodeId
        self.lastSeen = lastSeen
    }
}

public struct MeshtasticConfig: Codable {
    public var connectionType: MeshtasticConnectionType
    public var devicePath: String
    public var port: Int?
    public var nodeId: String?
    public var deviceName: String

    public init(
        connectionType: MeshtasticConnectionType,
        devicePath: String,
        port: Int? = nil,
        nodeId: String? = nil,
        deviceName: String
    ) {
        self.connectionType = connectionType
        self.devicePath = devicePath
        self.port = port
        self.nodeId = nodeId
        self.deviceName = deviceName
    }
}

// MARK: - Mesh Network Models

public struct MeshNode: Identifiable, Codable {
    public let id: UInt32
    public var shortName: String
    public var longName: String
    public var position: MeshPosition?
    public var lastHeard: Date
    public var snr: Double?
    public var hopDistance: Int?
    public var batteryLevel: Int?

    public init(
        id: UInt32,
        shortName: String,
        longName: String,
        position: MeshPosition? = nil,
        lastHeard: Date,
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
    public var latitude: Double
    public var longitude: Double
    public var altitude: Int?

    public init(latitude: Double, longitude: Double, altitude: Int? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

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
        averageHops: Double = 0.0,
        packetSuccessRate: Double = 0.0,
        networkUtilization: Double = 0.0,
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

// MARK: - Signal Quality

public enum SignalQuality: String, Hashable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case none = "No Signal"

    public static func from(rssi: Int?) -> SignalQuality {
        guard let rssi = rssi else { return .none }

        switch rssi {
        case -50...0: return .excellent
        case -70..<(-50): return .good
        case -85..<(-70): return .fair
        case -100..<(-85): return .poor
        default: return .none
        }
    }

    public var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        case .none: return "gray"
        }
    }

    public var iconName: String {
        switch self {
        case .excellent: return "antenna.radiowaves.left.and.right"
        case .good: return "wifi"
        case .fair: return "wifi.slash"
        case .poor: return "exclamationmark.triangle"
        case .none: return "antenna.radiowaves.left.and.right.slash"
        }
    }

    public var displayText: String {
        return self.rawValue
    }
}

// MARK: - Native Bridge Protocol

/// Protocol for bridging to native Meshtastic implementation
public protocol OmniTAKNativeBridge {
    func connectMeshtastic(config: MeshtasticConfig) -> UInt64
    func disconnect(connectionId: Int)
    func sendCot(connectionId: Int, cotXml: String) -> Int
    func receiveCot(connectionId: Int) -> String?
}
