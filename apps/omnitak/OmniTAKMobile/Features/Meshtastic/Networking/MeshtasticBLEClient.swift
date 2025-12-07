//
//  MeshtasticBLEClient.swift
//  OmniTAK Mobile
//
//  Bluetooth Low Energy client for Meshtastic device communication
//  Implements the Meshtastic BLE protocol using CoreBluetooth
//

import Foundation
import CoreBluetooth
import Combine

// MARK: - Meshtastic BLE UUIDs

struct MeshtasticBLEUUIDs {
    /// Main Meshtastic service UUID
    static let service = CBUUID(string: "6ba1b218-15a8-461f-9fa8-5dcae273eafd")

    /// Write packets to the radio (ToRadio protobuf)
    static let toRadio = CBUUID(string: "f75c76d2-129e-4dad-a1dd-7866124401e7")

    /// Read packets from the radio (FromRadio protobuf)
    static let fromRadio = CBUUID(string: "2c55e69e-4993-11ed-b878-0242ac120002")

    /// Notification when new data is available (triggers read from fromRadio)
    static let fromNum = CBUUID(string: "ed9da18c-a800-4f66-a670-aa7547e34453")
}

// MARK: - BLE Client Delegate

protocol MeshtasticBLEClientDelegate: AnyObject {
    func bleClient(_ client: MeshtasticBLEClient, didDiscover device: MeshtasticBLEDevice)
    func bleClient(_ client: MeshtasticBLEClient, didConnect device: MeshtasticBLEDevice)
    func bleClient(_ client: MeshtasticBLEClient, didDisconnect device: MeshtasticBLEDevice, error: Error?)
    func bleClient(_ client: MeshtasticBLEClient, didReceiveNodeInfo node: MeshNode)
    func bleClient(_ client: MeshtasticBLEClient, didReceivePosition nodeId: UInt32, position: MeshPosition)
    func bleClient(_ client: MeshtasticBLEClient, didReceiveMessage from: UInt32, text: String)
    func bleClient(_ client: MeshtasticBLEClient, didUpdateMyInfo nodeNum: UInt32, firmwareVersion: String)
    func bleClient(_ client: MeshtasticBLEClient, didReceiveError message: String)
}

// MARK: - Discovered BLE Device

public struct MeshtasticBLEDevice: Identifiable {
    public let id: UUID
    let peripheral: CBPeripheral
    public var name: String
    public var rssi: Int
    public var lastSeen: Date

    init(peripheral: CBPeripheral, rssi: Int) {
        self.id = peripheral.identifier
        self.peripheral = peripheral
        self.name = peripheral.name ?? "Meshtastic Device"
        self.rssi = rssi
        self.lastSeen = Date()
    }
}

// MARK: - MeshtasticBLEClient

@available(iOS 13.0, *)
class MeshtasticBLEClient: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isScanning: Bool = false
    @Published var isConnected: Bool = false
    @Published var connectionState: ConnectionState = .disconnected
    @Published var discoveredDevices: [MeshtasticBLEDevice] = []
    @Published var connectedDevice: MeshtasticBLEDevice?
    @Published var myNodeNum: UInt32 = 0
    @Published var firmwareVersion: String = ""
    @Published var nodes: [UInt32: MeshNode] = [:]
    @Published var lastError: String?

    enum ConnectionState: String {
        case disconnected = "Disconnected"
        case scanning = "Scanning..."
        case connecting = "Connecting..."
        case discoveringServices = "Discovering Services..."
        case connected = "Connected"
        case failed = "Connection Failed"
    }

    // MARK: - Properties

    weak var delegate: MeshtasticBLEClientDelegate?

    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var toRadioCharacteristic: CBCharacteristic?
    private var fromRadioCharacteristic: CBCharacteristic?
    private var fromNumCharacteristic: CBCharacteristic?

    private var receiveBuffer = Data()
    private let queue = DispatchQueue(label: "com.omnitak.meshtastic.ble", qos: .userInitiated)

    // MARK: - Protocol Constants

    private let maxPacketSize = 512

    // MARK: - Initialization

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: queue)
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
            withServices: [MeshtasticBLEUUIDs.service],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )

        print("MeshtasticBLE: Started scanning for devices")
    }

    func stopScanning() {
        centralManager.stopScan()
        DispatchQueue.main.async {
            self.isScanning = false
            if self.connectionState == .scanning {
                self.connectionState = .disconnected
            }
        }
        print("MeshtasticBLE: Stopped scanning")
    }

    // MARK: - Connection

    func connect(to device: MeshtasticBLEDevice) {
        stopScanning()

        DispatchQueue.main.async {
            self.connectionState = .connecting
            self.lastError = nil
        }

        centralManager.connect(device.peripheral, options: nil)
        print("MeshtasticBLE: Connecting to \(device.name)")
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }

        cleanup()

        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionState = .disconnected
            self.connectedDevice = nil
            self.nodes.removeAll()
            self.myNodeNum = 0
            self.firmwareVersion = ""
        }

        print("MeshtasticBLE: Disconnected")
    }

    private func cleanup() {
        connectedPeripheral = nil
        toRadioCharacteristic = nil
        fromRadioCharacteristic = nil
        fromNumCharacteristic = nil
        receiveBuffer.removeAll()
    }

    // MARK: - Sending Data

    func requestConfig() {
        guard let characteristic = toRadioCharacteristic,
              let peripheral = connectedPeripheral else {
            return
        }

        let data = buildWantConfig()
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        print("MeshtasticBLE: Sent config request")
    }

    func sendTextMessage(_ text: String, to destination: UInt32 = 0xFFFFFFFF) {
        guard let characteristic = toRadioCharacteristic,
              let peripheral = connectedPeripheral else {
            DispatchQueue.main.async {
                self.lastError = "Not connected"
            }
            return
        }

        let data = buildTextMessage(text, to: destination)
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        print("MeshtasticBLE: Sent message: \(text)")
    }

    // MARK: - Protobuf Building

    private func buildWantConfig() -> Data {
        var data = Data()
        let configId = UInt32.random(in: 1...UInt32.max)
        data.append(0x18) // Field 3, wire type 0 (varint)
        appendVarint(&data, UInt64(configId))
        return data
    }

    private func buildTextMessage(_ text: String, to destination: UInt32) -> Data {
        var data = Data()
        var meshPacket = Data()

        // to (field 2, fixed32)
        meshPacket.append(0x15)
        meshPacket.append(contentsOf: withUnsafeBytes(of: destination.littleEndian) { Array($0) })

        // decoded (field 4, sub-message)
        var decoded = Data()
        decoded.append(0x08) // portnum field 1
        appendVarint(&decoded, 1) // TEXT_MESSAGE_APP

        if let textData = text.data(using: .utf8) {
            decoded.append(0x12) // payload field 2
            appendVarint(&decoded, UInt64(textData.count))
            decoded.append(textData)
        }

        meshPacket.append(0x22) // field 4, wire type 2
        appendVarint(&meshPacket, UInt64(decoded.count))
        meshPacket.append(decoded)

        // want_ack
        meshPacket.append(0x50)
        meshPacket.append(0x01)

        // Wrap in ToRadio
        data.append(0x0A)
        appendVarint(&data, UInt64(meshPacket.count))
        data.append(meshPacket)

        return data
    }

    // MARK: - Protobuf Parsing

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
            case 1:
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
            case 2: // user
                if wire == 2, let (len, lenEnd) = readVarint(data, from: idx) {
                    let userEnd = min(lenEnd + Int(len), data.count)
                    var uIdx = lenEnd
                    while uIdx < userEnd {
                        guard uIdx < data.count else { break }
                        let uTag = data[uIdx]
                        let uField = (uTag >> 3)
                        let uWire = (uTag & 0x07)
                        uIdx += 1

                        if uField == 2 && uWire == 2 {
                            if let (str, newIdx) = readString(data, from: uIdx) {
                                longName = str
                                uIdx = min(newIdx, userEnd)
                            } else {
                                uIdx = skipField(data, from: uIdx, wireType: uWire)
                            }
                        } else if uField == 3 && uWire == 2 {
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
            case 3: // position
                if wire == 2, let (len, lenEnd) = readVarint(data, from: idx) {
                    let posEnd = min(lenEnd + Int(len), data.count)
                    let posData = data.subdata(in: lenEnd..<posEnd)
                    position = parsePositionPayload(posData)
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
            case 4: // decoded
                if wire == 2, let (len, lenEnd) = readVarint(data, from: idx) {
                    let dataEnd = min(lenEnd + Int(len), data.count)
                    var dIdx = lenEnd
                    while dIdx < dataEnd {
                        guard dIdx < data.count else { break }
                        let dTag = data[dIdx]
                        let dField = (dTag >> 3)
                        let dWire = (dTag & 0x07)
                        dIdx += 1

                        if dField == 1 && dWire == 0 {
                            if let (val, newIdx) = readVarint(data, from: dIdx) {
                                portNum = Int(val)
                                dIdx = min(newIdx, dataEnd)
                            } else {
                                dIdx = skipField(data, from: dIdx, wireType: dWire)
                            }
                        } else if dField == 2 && dWire == 2 {
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
            case 1: // latitude_i
                if wire == 5 && idx + 4 <= data.count {
                    let bits = UInt32(data[idx]) | (UInt32(data[idx+1]) << 8) | (UInt32(data[idx+2]) << 16) | (UInt32(data[idx+3]) << 24)
                    lat = Double(Int32(bitPattern: bits)) / 1e7
                    idx += 4
                } else {
                    idx = skipField(data, from: idx, wireType: wire)
                }
            case 2: // longitude_i
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
        case 0:
            if let (_, newIdx) = readVarint(data, from: index) {
                return min(newIdx, data.count)
            }
            return min(index + 1, data.count)
        case 1:
            return min(index + 8, data.count)
        case 2:
            if let (length, lengthEnd) = readVarint(data, from: index) {
                return min(lengthEnd + Int(length), data.count)
            }
            return min(index + 1, data.count)
        case 5:
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
        switch central.state {
        case .poweredOn:
            print("MeshtasticBLE: Bluetooth powered on")
        case .poweredOff:
            DispatchQueue.main.async {
                self.lastError = "Bluetooth is powered off"
                self.connectionState = .disconnected
            }
        case .unauthorized:
            DispatchQueue.main.async {
                self.lastError = "Bluetooth access not authorized"
            }
        case .unsupported:
            DispatchQueue.main.async {
                self.lastError = "Bluetooth not supported on this device"
            }
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let device = MeshtasticBLEDevice(peripheral: peripheral, rssi: RSSI.intValue)

        DispatchQueue.main.async {
            // Update existing or add new
            if let index = self.discoveredDevices.firstIndex(where: { $0.id == device.id }) {
                self.discoveredDevices[index].rssi = device.rssi
                self.discoveredDevices[index].lastSeen = Date()
            } else {
                self.discoveredDevices.append(device)
                print("MeshtasticBLE: Discovered \(device.name) (RSSI: \(device.rssi))")
            }
        }

        delegate?.bleClient(self, didDiscover: device)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("MeshtasticBLE: Connected to \(peripheral.name ?? "device")")

        connectedPeripheral = peripheral
        peripheral.delegate = self

        DispatchQueue.main.async {
            self.connectionState = .discoveringServices
        }

        peripheral.discoverServices([MeshtasticBLEUUIDs.service])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("MeshtasticBLE: Failed to connect: \(error?.localizedDescription ?? "unknown")")

        DispatchQueue.main.async {
            self.connectionState = .failed
            self.lastError = error?.localizedDescription ?? "Failed to connect"
        }

        cleanup()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("MeshtasticBLE: Disconnected: \(error?.localizedDescription ?? "normal disconnect")")

        let device = connectedDevice
        cleanup()

        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionState = .disconnected
            self.connectedDevice = nil
        }

        if let device = device {
            delegate?.bleClient(self, didDisconnect: device, error: error)
        }
    }
}

// MARK: - CBPeripheralDelegate

@available(iOS 13.0, *)
extension MeshtasticBLEClient: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.lastError = "Service discovery failed: \(error.localizedDescription)"
                self.connectionState = .failed
            }
            return
        }

        guard let services = peripheral.services else { return }

        for service in services {
            if service.uuid == MeshtasticBLEUUIDs.service {
                peripheral.discoverCharacteristics(
                    [MeshtasticBLEUUIDs.toRadio, MeshtasticBLEUUIDs.fromRadio, MeshtasticBLEUUIDs.fromNum],
                    for: service
                )
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.lastError = "Characteristic discovery failed: \(error.localizedDescription)"
            }
            return
        }

        guard let characteristics = service.characteristics else { return }

        for characteristic in characteristics {
            switch characteristic.uuid {
            case MeshtasticBLEUUIDs.toRadio:
                toRadioCharacteristic = characteristic
                print("MeshtasticBLE: Found toRadio characteristic")

            case MeshtasticBLEUUIDs.fromRadio:
                fromRadioCharacteristic = characteristic
                print("MeshtasticBLE: Found fromRadio characteristic")

            case MeshtasticBLEUUIDs.fromNum:
                fromNumCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                print("MeshtasticBLE: Found fromNum characteristic, subscribed to notifications")

            default:
                break
            }
        }

        // Check if we have all required characteristics
        if toRadioCharacteristic != nil && fromRadioCharacteristic != nil && fromNumCharacteristic != nil {
            let device = MeshtasticBLEDevice(peripheral: peripheral, rssi: 0)

            DispatchQueue.main.async {
                self.isConnected = true
                self.connectionState = .connected
                self.connectedDevice = device
            }

            delegate?.bleClient(self, didConnect: device)

            // Request configuration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.requestConfig()
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("MeshtasticBLE: Read error: \(error.localizedDescription)")
            return
        }

        if characteristic.uuid == MeshtasticBLEUUIDs.fromNum {
            // New data notification - read from fromRadio
            if let fromRadio = fromRadioCharacteristic {
                peripheral.readValue(for: fromRadio)
            }
        } else if characteristic.uuid == MeshtasticBLEUUIDs.fromRadio {
            // Received data from radio
            if let data = characteristic.value, !data.isEmpty {
                parseFromRadio(data)
                // Continue reading until empty
                peripheral.readValue(for: characteristic)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.lastError = "Write error: \(error.localizedDescription)"
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("MeshtasticBLE: Notification setup error: \(error.localizedDescription)")
        } else {
            print("MeshtasticBLE: Notifications enabled for \(characteristic.uuid)")
        }
    }
}
