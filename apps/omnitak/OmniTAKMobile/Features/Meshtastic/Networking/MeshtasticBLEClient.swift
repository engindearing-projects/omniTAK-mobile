//
//  MeshtasticBLEClient.swift
//  OmniTAK Mobile
//
//  CoreBluetooth client for Meshtastic device communication
//  Implements the Meshtastic BLE protocol for iOS
//

import Foundation
import CoreBluetooth
import Combine

// MARK: - Meshtastic BLE UUIDs

enum MeshtasticBLEUUID {
    static let service = CBUUID(string: "6ba1b218-15a8-461f-9fa8-5dcae273eafd")
    static let toRadio = CBUUID(string: "f75c76d2-129e-4dad-a1dd-7866124401e7")
    static let fromRadio = CBUUID(string: "8ba2bcc2-ee02-4a55-a531-c525c5e454d5")
    static let fromNum = CBUUID(string: "ed9da18c-a800-4f66-a670-aa7547e34453")
}

// MARK: - BLE Protocol Constants

private enum BLEProtocol {
    static let maxPacketSize = 512
    static let mtuSize = 512
}

// MARK: - Discovered BLE Device

public struct DiscoveredBLEDevice: Identifiable {
    public let id: UUID
    public let name: String
    public let rssi: Int
    public let peripheral: CBPeripheral
    public var lastSeen: Date = Date()

    public var signalStrength: String {
        switch rssi {
        case -50...0: return "Excellent"
        case -70..<(-50): return "Good"
        case -90..<(-70): return "Fair"
        default: return "Weak"
        }
    }

    public init(id: UUID, name: String, rssi: Int, peripheral: CBPeripheral, lastSeen: Date = Date()) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.peripheral = peripheral
        self.lastSeen = lastSeen
    }
}

// MARK: - BLE Client Delegate

protocol MeshtasticBLEClientDelegate: AnyObject {
    func bleClient(_ client: MeshtasticBLEClient, didDiscover device: DiscoveredBLEDevice)
    func bleClient(_ client: MeshtasticBLEClient, didConnect peripheral: CBPeripheral)
    func bleClient(_ client: MeshtasticBLEClient, didDisconnect peripheral: CBPeripheral, error: Error?)
    func bleClient(_ client: MeshtasticBLEClient, didReceiveNodeInfo node: MeshNode)
    func bleClient(_ client: MeshtasticBLEClient, didReceivePosition nodeId: UInt32, position: MeshPosition)
    func bleClient(_ client: MeshtasticBLEClient, didReceiveMessage from: UInt32, text: String)
    func bleClient(_ client: MeshtasticBLEClient, didUpdateMyInfo nodeNum: UInt32, firmwareVersion: String)
    func bleClient(_ client: MeshtasticBLEClient, didReceiveError message: String)
    func bleClient(_ client: MeshtasticBLEClient, bluetoothStateChanged state: CBManagerState)
}

// MARK: - MeshtasticBLEClient

@available(iOS 13.0, *)
class MeshtasticBLEClient: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isScanning: Bool = false
    @Published var isConnected: Bool = false
    @Published var connectionState: ConnectionState = .disconnected
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var discoveredDevices: [DiscoveredBLEDevice] = []
    @Published var connectedPeripheral: CBPeripheral?
    @Published var myNodeNum: UInt32 = 0
    @Published var firmwareVersion: String = ""
    @Published var nodes: [UInt32: MeshNode] = [:]
    @Published var lastError: String?

    enum ConnectionState: String {
        case disconnected = "Disconnected"
        case scanning = "Scanning..."
        case connecting = "Connecting..."
        case discovering = "Discovering Services..."
        case connected = "Connected"
        case failed = "Connection Failed"
    }

    // MARK: - Properties

    weak var delegate: MeshtasticBLEClientDelegate?

    private var centralManager: CBCentralManager!
    private var toRadioCharacteristic: CBCharacteristic?
    private var fromRadioCharacteristic: CBCharacteristic?
    private var fromNumCharacteristic: CBCharacteristic?
    private var receiveBuffer = Data()
    private var pendingPeripheral: CBPeripheral?

    // Timer for periodic FromRadio reads
    private var readTimer: Timer?

    // Flag to prevent operations during shutdown
    private var isShuttingDown = false

    // MARK: - Initialization

    override init() {
        super.init()
        // Use main queue for CBCentralManager to ensure UI updates happen on main thread
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    deinit {
        isShuttingDown = true
        readTimer?.invalidate()
        readTimer = nil
        // Don't call disconnect() in deinit - it can cause crashes
        // The centralManager will be deallocated and clean up automatically
    }

    // MARK: - Scanning

    func startScanning() {
        guard centralManager.state == .poweredOn else {
            DispatchQueue.main.async {
                self.lastError = "Bluetooth is not available"
            }
            return
        }

        DispatchQueue.main.async {
            self.discoveredDevices.removeAll()
            self.isScanning = true
            self.connectionState = .scanning
        }

        centralManager.scanForPeripherals(
            withServices: [MeshtasticBLEUUID.service],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        print("Started scanning for Meshtastic devices...")
    }

    func stopScanning() {
        centralManager.stopScan()
        DispatchQueue.main.async {
            self.isScanning = false
            if !self.isConnected {
                self.connectionState = .disconnected
            }
        }
        print("Stopped scanning")
    }

    // MARK: - Connection Management

    func connect(to device: DiscoveredBLEDevice) {
        stopScanning()

        pendingPeripheral = device.peripheral

        DispatchQueue.main.async {
            self.connectionState = .connecting
            self.lastError = nil
        }

        centralManager.connect(device.peripheral, options: nil)
        print("Connecting to \(device.name)...")
    }

    func connect(peripheral: CBPeripheral) {
        stopScanning()

        pendingPeripheral = peripheral

        DispatchQueue.main.async {
            self.connectionState = .connecting
            self.lastError = nil
        }

        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        guard !isShuttingDown else { return }

        readTimer?.invalidate()
        readTimer = nil

        // Cancel any pending or active connections
        if let peripheral = connectedPeripheral, centralManager != nil {
            centralManager.cancelPeripheralConnection(peripheral)
        } else if let peripheral = pendingPeripheral, centralManager != nil {
            centralManager.cancelPeripheralConnection(peripheral)
        }

        // Reset state on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.isShuttingDown else { return }
            self.isConnected = false
            self.connectionState = .disconnected
            self.connectedPeripheral = nil
            self.toRadioCharacteristic = nil
            self.fromRadioCharacteristic = nil
            self.fromNumCharacteristic = nil
            self.nodes.removeAll()
            self.myNodeNum = 0
            self.firmwareVersion = ""
        }

        pendingPeripheral = nil
        print("Disconnected from Meshtastic device")
    }

    // MARK: - Sending Data

    func requestConfig() {
        guard let peripheral = connectedPeripheral,
              let characteristic = toRadioCharacteristic else {
            print("❌ Cannot request config - not connected or missing characteristic")
            return
        }

        guard peripheral.state == .connected else {
            print("❌ Cannot request config - peripheral not in connected state")
            return
        }

        let configRequest = buildWantConfig()
        print("📤 Sending config request (\(configRequest.count) bytes)")
        sendToRadio(configRequest, peripheral: peripheral, characteristic: characteristic)
    }

    func sendTextMessage(_ text: String, to destination: UInt32 = 0xFFFFFFFF) {
        guard let peripheral = connectedPeripheral,
              let characteristic = toRadioCharacteristic else {
            DispatchQueue.main.async {
                self.lastError = "Not connected"
            }
            return
        }

        let packet = buildTextMessage(text, to: destination)
        sendToRadio(packet, peripheral: peripheral, characteristic: characteristic)
    }

    private func sendToRadio(_ data: Data, peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        // For BLE, we send the raw protobuf data without the TCP framing header
        guard peripheral.state == .connected else {
            print("❌ Cannot send - peripheral not connected")
            return
        }

        // Check if characteristic supports write
        guard characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) else {
            print("❌ Characteristic doesn't support writing")
            return
        }

        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        peripheral.writeValue(data, for: characteristic, type: writeType)
        print("📤 Wrote \(data.count) bytes to \(characteristic.uuid)")
    }

    // MARK: - Building Protobuf Messages

    private func buildWantConfig() -> Data {
        var data = Data()

        // ToRadio message with want_config_id = random
        // Field 3: want_config_id (uint32)
        let configId = UInt32.random(in: 1...UInt32.max)
        data.append(0x18) // Tag: field 3, wire type 0 (varint)
        appendVarint(&data, UInt64(configId))

        return data
    }

    private func buildTextMessage(_ text: String, to destination: UInt32) -> Data {
        var data = Data()

        var meshPacket = Data()

        // to (field 2, fixed32)
        meshPacket.append(0x15) // Tag: field 2, wire type 5
        meshPacket.append(contentsOf: withUnsafeBytes(of: destination.littleEndian) { Array($0) })

        // decoded (field 4, sub-message)
        var decoded = Data()

        // portnum = 1 (TEXT_MESSAGE_APP)
        decoded.append(0x08) // Tag: field 1, wire type 0
        appendVarint(&decoded, 1)

        // payload = text
        if let textData = text.data(using: .utf8) {
            decoded.append(0x12) // Tag: field 2, wire type 2
            appendVarint(&decoded, UInt64(textData.count))
            decoded.append(textData)
        }

        meshPacket.append(0x22) // Tag: field 4, wire type 2
        appendVarint(&meshPacket, UInt64(decoded.count))
        meshPacket.append(decoded)

        // want_ack = true (field 10)
        meshPacket.append(0x50) // Tag: field 10, wire type 0
        meshPacket.append(0x01)

        // Wrap in ToRadio
        data.append(0x0A) // Tag: field 1, wire type 2
        appendVarint(&data, UInt64(meshPacket.count))
        data.append(meshPacket)

        return data
    }

    // MARK: - Parsing FromRadio

    private func parseFromRadio(_ data: Data) {
        guard !data.isEmpty else { return }

        var index = 0
        while index < data.count {
            guard index < data.count else { break }

            let tag = data[index]
            let fieldNumber = (tag >> 3)
            let wireType = (tag & 0x07)
            index += 1

            switch fieldNumber {
            case 5: // my_info
                if let (info, newIndex) = parseMyNodeInfo(data, from: index, wireType: wireType) {
                    index = newIndex
                    DispatchQueue.main.async {
                        self.myNodeNum = info.nodeNum
                        self.firmwareVersion = info.firmwareVersion
                    }
                    delegate?.bleClient(self, didUpdateMyInfo: info.nodeNum, firmwareVersion: info.firmwareVersion)
                } else {
                    index = skipField(data, from: index, wireType: wireType)
                }

            case 6: // node_info
                if let (node, newIndex) = parseNodeInfo(data, from: index, wireType: wireType) {
                    index = newIndex
                    DispatchQueue.main.async {
                        self.nodes[node.id] = node
                    }
                    delegate?.bleClient(self, didReceiveNodeInfo: node)
                } else {
                    index = skipField(data, from: index, wireType: wireType)
                }

            case 2: // packet (MeshPacket)
                if let (packet, newIndex) = parseMeshPacket(data, from: index, wireType: wireType) {
                    index = newIndex
                    handleMeshPacket(packet)
                } else {
                    index = skipField(data, from: index, wireType: wireType)
                }

            default:
                index = skipField(data, from: index, wireType: wireType)
            }
        }
    }

    private func parseMyNodeInfo(_ data: Data, from index: Int, wireType: UInt8) -> ((nodeNum: UInt32, firmwareVersion: String), Int)? {
        guard wireType == 2 else { return nil }

        guard let (length, lengthEnd) = readVarint(data, from: index) else { return nil }
        let messageEnd = min(lengthEnd + Int(length), data.count)

        var nodeNum: UInt32 = 0
        let firmware = "Unknown"
        var idx = lengthEnd

        while idx < messageEnd {
            guard idx < data.count else { break }
            let tag = data[idx]
            let field = (tag >> 3)
            let wire = (tag & 0x07)
            idx += 1

            switch field {
            case 1: // my_node_num
                if wire == 0, let (val, newIdx) = readVarint(data, from: idx) {
                    nodeNum = UInt32(val)
                    idx = min(newIdx, messageEnd)
                } else {
                    idx = skipField(data, from: idx, wireType: wire)
                }
            default:
                idx = skipField(data, from: idx, wireType: wire)
            }
        }

        return ((nodeNum, firmware), messageEnd)
    }

    private func parseNodeInfo(_ data: Data, from index: Int, wireType: UInt8) -> (MeshNode, Int)? {
        guard wireType == 2 else { return nil }

        guard let (length, lengthEnd) = readVarint(data, from: index) else { return nil }
        let messageEnd = min(lengthEnd + Int(length), data.count)

        var nodeNum: UInt32 = 0
        var shortName = ""
        var longName = ""
        var snr: Double? = nil
        var lastHeard: Date? = nil
        var position: MeshPosition? = nil
        var hopDistance: Int? = nil

        var idx = lengthEnd

        while idx < messageEnd {
            guard idx < data.count else { break }
            let tag = data[idx]
            let field = (tag >> 3)
            let wire = (tag & 0x07)
            idx += 1

            switch field {
            case 1: // num
                if wire == 0, let (val, newIdx) = readVarint(data, from: idx) {
                    nodeNum = UInt32(val)
                    idx = min(newIdx, messageEnd)
                } else {
                    idx = skipField(data, from: idx, wireType: wire)
                }
            case 2: // user (sub-message)
                if wire == 2, let (len, lenEnd) = readVarint(data, from: idx) {
                    let userEnd = min(lenEnd + Int(len), data.count)
                    var uIdx = lenEnd
                    while uIdx < userEnd {
                        guard uIdx < data.count else { break }
                        let uTag = data[uIdx]
                        let uField = (uTag >> 3)
                        let uWire = (uTag & 0x07)
                        uIdx += 1

                        if uField == 2 && uWire == 2 { // long_name
                            if let (str, newIdx) = readString(data, from: uIdx) {
                                longName = str
                                uIdx = min(newIdx, userEnd)
                            } else {
                                uIdx = skipField(data, from: uIdx, wireType: uWire)
                            }
                        } else if uField == 3 && uWire == 2 { // short_name
                            if let (str, newIdx) = readString(data, from: uIdx) {
                                shortName = str
                                uIdx = min(newIdx, userEnd)
                            } else {
                                uIdx = skipField(data, from: uIdx, wireType: uWire)
                            }
                        } else {
                            uIdx = skipField(data, from: uIdx, wireType: uWire)
                        }
                    }
                    idx = userEnd
                } else {
                    idx = skipField(data, from: idx, wireType: wire)
                }
            case 4: // position (sub-message)
                if wire == 2, let (len, lenEnd) = readVarint(data, from: idx) {
                    let posEnd = min(lenEnd + Int(len), data.count)
                    if let pos = parsePositionSubmessage(data, from: lenEnd, end: posEnd) {
                        position = pos
                    }
                    idx = posEnd
                } else {
                    idx = skipField(data, from: idx, wireType: wire)
                }
            case 5: // snr
                if wire == 5 && idx + 4 <= data.count {
                    let floatBits = UInt32(data[idx]) | (UInt32(data[idx+1]) << 8) | (UInt32(data[idx+2]) << 16) | (UInt32(data[idx+3]) << 24)
                    snr = Double(Float(bitPattern: floatBits))
                    idx += 4
                } else {
                    idx = skipField(data, from: idx, wireType: wire)
                }
            case 6: // last_heard
                if wire == 0, let (val, newIdx) = readVarint(data, from: idx) {
                    lastHeard = Date(timeIntervalSince1970: Double(val))
                    idx = newIdx
                } else {
                    idx = skipField(data, from: idx, wireType: wire)
                }
            case 7: // hops_away
                if wire == 0, let (val, newIdx) = readVarint(data, from: idx) {
                    hopDistance = Int(val)
                    idx = newIdx
                } else {
                    idx = skipField(data, from: idx, wireType: wire)
                }
            default:
                idx = skipField(data, from: idx, wireType: wire)
            }
        }

        let node = MeshNode(
            id: nodeNum,
            shortName: shortName.isEmpty ? String(format: "%04X", nodeNum & 0xFFFF) : shortName,
            longName: longName.isEmpty ? "Node \(String(format: "%08X", nodeNum))" : longName,
            position: position,
            lastHeard: lastHeard ?? Date(),
            snr: snr,
            hopDistance: hopDistance,
            batteryLevel: nil
        )

        return (node, messageEnd)
    }

    private func parsePositionSubmessage(_ data: Data, from start: Int, end: Int) -> MeshPosition? {
        var lat: Double = 0
        var lon: Double = 0
        var alt: Int? = nil

        var idx = start
        while idx < end {
            guard idx < data.count else { break }
            let tag = data[idx]
            let field = (tag >> 3)
            let wire = (tag & 0x07)
            idx += 1

            switch field {
            case 1: // latitude_i (sfixed32)
                if wire == 5 && idx + 4 <= data.count {
                    let bits = UInt32(data[idx]) | (UInt32(data[idx+1]) << 8) | (UInt32(data[idx+2]) << 16) | (UInt32(data[idx+3]) << 24)
                    lat = Double(Int32(bitPattern: bits)) / 1e7
                    idx += 4
                } else {
                    idx = skipField(data, from: idx, wireType: wire)
                }
            case 2: // longitude_i (sfixed32)
                if wire == 5 && idx + 4 <= data.count {
                    let bits = UInt32(data[idx]) | (UInt32(data[idx+1]) << 8) | (UInt32(data[idx+2]) << 16) | (UInt32(data[idx+3]) << 24)
                    lon = Double(Int32(bitPattern: bits)) / 1e7
                    idx += 4
                } else {
                    idx = skipField(data, from: idx, wireType: wire)
                }
            case 3: // altitude
                if wire == 0, let (val, newIdx) = readVarint(data, from: idx) {
                    alt = Int(Int32(bitPattern: UInt32(val)))
                    idx = newIdx
                } else {
                    idx = skipField(data, from: idx, wireType: wire)
                }
            default:
                idx = skipField(data, from: idx, wireType: wire)
            }
        }

        guard lat != 0 || lon != 0 else { return nil }
        return MeshPosition(latitude: lat, longitude: lon, altitude: alt)
    }

    private func parseMeshPacket(_ data: Data, from index: Int, wireType: UInt8) -> ((from: UInt32, to: UInt32, portNum: Int, payload: Data), Int)? {
        guard wireType == 2 else { return nil }

        guard let (length, lengthEnd) = readVarint(data, from: index) else { return nil }
        let messageEnd = min(lengthEnd + Int(length), data.count)
        guard messageEnd <= data.count else { return nil }

        var fromNode: UInt32 = 0
        var toNode: UInt32 = 0
        var portNum = 0
        var payload = Data()

        var idx = lengthEnd

        while idx < messageEnd {
            guard idx < data.count else { break }
            let tag = data[idx]
            let field = (tag >> 3)
            let wire = (tag & 0x07)
            idx += 1

            switch field {
            case 1: // from
                if wire == 5 && idx + 4 <= data.count {
                    fromNode = UInt32(data[idx]) | (UInt32(data[idx+1]) << 8) | (UInt32(data[idx+2]) << 16) | (UInt32(data[idx+3]) << 24)
                    idx += 4
                } else {
                    idx = skipField(data, from: idx, wireType: wire)
                }
            case 2: // to
                if wire == 5 && idx + 4 <= data.count {
                    toNode = UInt32(data[idx]) | (UInt32(data[idx+1]) << 8) | (UInt32(data[idx+2]) << 16) | (UInt32(data[idx+3]) << 24)
                    idx += 4
                } else {
                    idx = skipField(data, from: idx, wireType: wire)
                }
            case 4: // decoded (Data message)
                if wire == 2, let (len, lenEnd) = readVarint(data, from: idx) {
                    let dataEnd = min(lenEnd + Int(len), data.count)
                    var dIdx = lenEnd
                    while dIdx < dataEnd {
                        guard dIdx < data.count else { break }
                        let dTag = data[dIdx]
                        let dField = (dTag >> 3)
                        let dWire = (dTag & 0x07)
                        dIdx += 1

                        if dField == 1 && dWire == 0 { // portnum
                            if let (val, newIdx) = readVarint(data, from: dIdx) {
                                portNum = Int(val)
                                dIdx = min(newIdx, dataEnd)
                            } else {
                                dIdx = skipField(data, from: dIdx, wireType: dWire)
                            }
                        } else if dField == 2 && dWire == 2 { // payload
                            if let (len2, len2End) = readVarint(data, from: dIdx) {
                                let payloadEnd = min(len2End + Int(len2), data.count)
                                payload = data.subdata(in: len2End..<payloadEnd)
                                dIdx = payloadEnd
                            } else {
                                dIdx = skipField(data, from: dIdx, wireType: dWire)
                            }
                        } else {
                            dIdx = skipField(data, from: dIdx, wireType: dWire)
                        }
                    }
                    idx = dataEnd
                } else {
                    idx = skipField(data, from: idx, wireType: wire)
                }
            default:
                idx = skipField(data, from: idx, wireType: wire)
            }
        }

        return ((fromNode, toNode, portNum, payload), messageEnd)
    }

    private func handleMeshPacket(_ packet: (from: UInt32, to: UInt32, portNum: Int, payload: Data)) {
        // Port numbers from Meshtastic:
        // 1 = TEXT_MESSAGE_APP
        // 3 = POSITION_APP
        // 4 = NODEINFO_APP
        // 72 = ATAK_PLUGIN
        // 257 = ATAK_FORWARDER

        switch packet.portNum {
        case 1: // Text message
            if let text = String(data: packet.payload, encoding: .utf8) {
                delegate?.bleClient(self, didReceiveMessage: packet.from, text: text)
            }

        case 3: // Position
            if let position = parsePositionPayload(packet.payload) {
                DispatchQueue.main.async {
                    if var node = self.nodes[packet.from] {
                        node.position = position
                        self.nodes[packet.from] = node
                    }
                }
                delegate?.bleClient(self, didReceivePosition: packet.from, position: position)
            }

        default:
            break
        }
    }

    private func parsePositionPayload(_ data: Data) -> MeshPosition? {
        guard !data.isEmpty else { return nil }

        var lat: Double = 0
        var lon: Double = 0
        var alt: Int? = nil

        var idx = 0
        while idx < data.count {
            guard idx < data.count else { break }
            let tag = data[idx]
            let field = (tag >> 3)
            let wire = (tag & 0x07)
            idx += 1

            switch field {
            case 1: // latitude_i (sfixed32)
                if wire == 5 && idx + 4 <= data.count {
                    let bits = UInt32(data[idx]) | (UInt32(data[idx+1]) << 8) | (UInt32(data[idx+2]) << 16) | (UInt32(data[idx+3]) << 24)
                    lat = Double(Int32(bitPattern: bits)) / 1e7
                    idx += 4
                } else {
                    idx = skipField(data, from: idx, wireType: wire)
                }
            case 2: // longitude_i (sfixed32)
                if wire == 5 && idx + 4 <= data.count {
                    let bits = UInt32(data[idx]) | (UInt32(data[idx+1]) << 8) | (UInt32(data[idx+2]) << 16) | (UInt32(data[idx+3]) << 24)
                    lon = Double(Int32(bitPattern: bits)) / 1e7
                    idx += 4
                } else {
                    idx = skipField(data, from: idx, wireType: wire)
                }
            case 3: // altitude
                if wire == 0, let (val, newIdx) = readVarint(data, from: idx) {
                    alt = Int(Int32(bitPattern: UInt32(val)))
                    idx = newIdx
                } else {
                    idx = skipField(data, from: idx, wireType: wire)
                }
            default:
                idx = skipField(data, from: idx, wireType: wire)
            }
        }

        guard lat != 0 || lon != 0 else { return nil }
        return MeshPosition(latitude: lat, longitude: lon, altitude: alt)
    }

    // MARK: - Protobuf Helpers

    private func readVarint(_ data: Data, from index: Int) -> (UInt64, Int)? {
        var result: UInt64 = 0
        var shift = 0
        var idx = index

        while idx < data.count {
            let byte = data[idx]
            idx += 1
            result |= UInt64(byte & 0x7F) << shift

            if byte & 0x80 == 0 {
                return (result, idx)
            }

            shift += 7
            if shift >= 64 { return nil }
        }

        return nil
    }

    private func readString(_ data: Data, from index: Int) -> (String, Int)? {
        guard let (length, lengthEnd) = readVarint(data, from: index) else { return nil }
        let stringEnd = lengthEnd + Int(length)
        guard stringEnd <= data.count else { return nil }

        let stringData = data.subdata(in: lengthEnd..<stringEnd)
        guard let str = String(data: stringData, encoding: .utf8) else { return nil }

        return (str, stringEnd)
    }

    private func appendVarint(_ data: inout Data, _ value: UInt64) {
        var v = value
        while v > 0x7F {
            data.append(UInt8((v & 0x7F) | 0x80))
            v >>= 7
        }
        data.append(UInt8(v))
    }

    private func skipField(_ data: Data, from index: Int, wireType: UInt8) -> Int {
        guard index < data.count else { return data.count }

        switch wireType {
        case 0: // Varint
            if let (_, newIdx) = readVarint(data, from: index) {
                return min(newIdx, data.count)
            }
            return min(index + 1, data.count)

        case 1: // 64-bit
            return min(index + 8, data.count)

        case 2: // Length-delimited
            if let (length, lengthEnd) = readVarint(data, from: index) {
                return min(lengthEnd + Int(length), data.count)
            }
            return min(index + 1, data.count)

        case 5: // 32-bit
            return min(index + 4, data.count)

        default:
            return min(index + 1, data.count)
        }
    }
}

// MARK: - CBCentralManagerDelegate

@available(iOS 13.0, *)
extension MeshtasticBLEClient: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        DispatchQueue.main.async {
            self.bluetoothState = central.state
        }

        delegate?.bleClient(self, bluetoothStateChanged: central.state)

        switch central.state {
        case .poweredOn:
            print("Bluetooth is ready")
        case .poweredOff:
            DispatchQueue.main.async {
                self.lastError = "Bluetooth is turned off"
                self.isConnected = false
                self.connectionState = .disconnected
            }
        case .unauthorized:
            DispatchQueue.main.async {
                self.lastError = "Bluetooth permission not granted"
            }
        case .unsupported:
            DispatchQueue.main.async {
                self.lastError = "Bluetooth is not supported on this device"
            }
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let deviceName = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown Meshtastic"

        let device = DiscoveredBLEDevice(
            id: peripheral.identifier,
            name: deviceName,
            rssi: RSSI.intValue,
            peripheral: peripheral
        )

        DispatchQueue.main.async {
            if let existingIndex = self.discoveredDevices.firstIndex(where: { $0.id == device.id }) {
                self.discoveredDevices[existingIndex] = device
            } else {
                self.discoveredDevices.append(device)
            }
        }

        delegate?.bleClient(self, didDiscover: device)
        print("Discovered: \(deviceName) (RSSI: \(RSSI))")
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "device")")

        DispatchQueue.main.async {
            self.connectionState = .discovering
            self.connectedPeripheral = peripheral
        }

        peripheral.delegate = self
        peripheral.discoverServices([MeshtasticBLEUUID.service])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.connectionState = .failed
            self.lastError = error?.localizedDescription ?? "Failed to connect"
        }

        delegate?.bleClient(self, didDisconnect: peripheral, error: error)
        print("Failed to connect: \(error?.localizedDescription ?? "unknown error")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionState = .disconnected
            self.connectedPeripheral = nil
        }

        readTimer?.invalidate()
        readTimer = nil

        delegate?.bleClient(self, didDisconnect: peripheral, error: error)
        print("Disconnected from \(peripheral.name ?? "device")")
    }
}

// MARK: - CBPeripheralDelegate

@available(iOS 13.0, *)
extension MeshtasticBLEClient: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("❌ Service discovery failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.lastError = "Service discovery failed: \(error.localizedDescription)"
            }
            return
        }

        guard let services = peripheral.services else {
            print("❌ No services found")
            return
        }

        print("📡 Found \(services.count) services")
        for service in services {
            print("  - Service: \(service.uuid)")
            if service.uuid == MeshtasticBLEUUID.service {
                print("✅ Found Meshtastic service, discovering ALL characteristics...")
                // Discover ALL characteristics (nil = all) to ensure we get everything
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("❌ Characteristic discovery failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.lastError = "Characteristic discovery failed: \(error.localizedDescription)"
            }
            return
        }

        guard let characteristics = service.characteristics else {
            print("❌ No characteristics found")
            return
        }

        print("📡 Found \(characteristics.count) characteristics:")
        for characteristic in characteristics {
            print("  - Characteristic: \(characteristic.uuid) (properties: \(characteristic.properties.rawValue))")

            switch characteristic.uuid {
            case MeshtasticBLEUUID.toRadio:
                toRadioCharacteristic = characteristic
                print("    ✅ This is toRadio (write)")

            case MeshtasticBLEUUID.fromRadio:
                fromRadioCharacteristic = characteristic
                print("    ✅ This is fromRadio (read)")

            case MeshtasticBLEUUID.fromNum:
                fromNumCharacteristic = characteristic
                print("    ✅ This is fromNum (notify)")
                // Subscribe to notifications for fromNum
                peripheral.setNotifyValue(true, for: characteristic)

            default:
                break
            }
        }

        // Check what we found
        print("📊 Characteristic status:")
        print("  - toRadio: \(toRadioCharacteristic != nil ? "✅" : "❌")")
        print("  - fromRadio: \(fromRadioCharacteristic != nil ? "✅" : "❌")")
        print("  - fromNum: \(fromNumCharacteristic != nil ? "✅" : "❌")")

        // We need at least toRadio to send and fromRadio OR fromNum to receive
        let canSend = toRadioCharacteristic != nil
        let canReceive = fromRadioCharacteristic != nil || fromNumCharacteristic != nil

        if canSend && canReceive {
            print("✅ Ready to communicate with Meshtastic device")

            DispatchQueue.main.async {
                self.isConnected = true
                self.connectionState = .connected
            }

            delegate?.bleClient(self, didConnect: peripheral)

            // Subscribe to fromRadio notifications if available
            if let fromRadio = fromRadioCharacteristic {
                if fromRadio.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: fromRadio)
                    print("📡 Subscribed to fromRadio notifications")
                }
            }

            // Delay config request to let connection stabilize
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self, self.isConnected else { return }
                print("📤 Requesting device config...")
                self.requestConfig()
            }

            // Start periodic reads if we have fromRadio
            if fromRadioCharacteristic != nil {
                startPeriodicReads()
            }
        } else {
            print("❌ Missing required characteristics - cannot communicate")
            DispatchQueue.main.async {
                self.lastError = "Device missing required BLE characteristics"
                self.connectionState = .failed
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ Error reading characteristic \(characteristic.uuid): \(error.localizedDescription)")
            return
        }

        guard let data = characteristic.value, !data.isEmpty else {
            // Empty data is normal - just means no messages waiting
            return
        }

        if characteristic.uuid == MeshtasticBLEUUID.fromRadio {
            print("📥 Received \(data.count) bytes from fromRadio")
            parseFromRadio(data)
        } else if characteristic.uuid == MeshtasticBLEUUID.fromNum {
            print("📥 fromNum notification received")
            // fromNum notified us there's data to read
            if let fromRadio = fromRadioCharacteristic, peripheral.state == .connected {
                peripheral.readValue(for: fromRadio)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.lastError = "Write failed: \(error.localizedDescription)"
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Notification state update failed: \(error.localizedDescription)")
            return
        }

        print("Notification state updated for \(characteristic.uuid): \(characteristic.isNotifying)")
    }

    // MARK: - Periodic Reading

    private func startPeriodicReads() {
        guard !isShuttingDown else { return }

        readTimer?.invalidate()
        readTimer = nil

        guard fromRadioCharacteristic != nil else {
            print("⚠️ Cannot start periodic reads - fromRadio characteristic not available")
            return
        }

        print("📡 Starting periodic reads from fromRadio...")

        // Read fromRadio periodically to get queued messages
        // Use a slower interval (1 second) to reduce load
        readTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self, !self.isShuttingDown else {
                timer.invalidate()
                return
            }

            // Safety checks
            guard self.isConnected,
                  let peripheral = self.connectedPeripheral,
                  peripheral.state == .connected,
                  let fromRadio = self.fromRadioCharacteristic else {
                print("⚠️ Stopping periodic reads - connection lost")
                timer.invalidate()
                self.readTimer = nil
                return
            }

            peripheral.readValue(for: fromRadio)
        }
    }

    private func stopPeriodicReads() {
        readTimer?.invalidate()
        readTimer = nil
        print("📡 Stopped periodic reads")
    }
}
