import Foundation
import Combine

class TAKService: ObservableObject {
    @Published var connectionStatus = "Disconnected"
    @Published var isConnected = false
    @Published var lastError = ""
    @Published var messagesReceived: Int = 0
    @Published var messagesSent: Int = 0
    @Published var lastMessage = ""

    private var connectionHandle: Int32 = -1
    private var receiveTimer: Timer?

    init() {
        // Initialize the omnitak-mobile library
        omnitak_mobile_init()
    }

    deinit {
        disconnect()
        omnitak_mobile_cleanup()
    }

    func connect(host: String, port: UInt16, protocol: String, useTLS: Bool) {
        // Create server config
        let config = ServerConfig(
            host: host,
            port: port,
            protocol: protocol,
            use_tls: useTLS,
            certificate_id: nil,
            reconnect: false,
            reconnect_delay_ms: 5000
        )

        // Convert to C strings
        let hostCStr = host.cString(using: .utf8)!
        let protocolCStr = protocol.cString(using: .utf8)!

        // Call FFI connect function
        let result = omnitak_mobile_connect(
            hostCStr,
            port,
            protocolCStr,
            useTLS,
            nil,
            false,
            5000
        )

        if result >= 0 {
            connectionHandle = result
            isConnected = true
            connectionStatus = "Connected"
            lastError = ""

            // Start polling for messages
            startReceiving()

            print("✅ Connected to TAK server: \(host):\(port)")
        } else {
            connectionStatus = "Connection Failed"
            lastError = "Failed to connect to \(host):\(port)"
            print("❌ Connection failed: \(result)")
        }
    }

    func disconnect() {
        guard connectionHandle >= 0 else { return }

        stopReceiving()

        omnitak_mobile_disconnect(connectionHandle)
        connectionHandle = -1
        isConnected = false
        connectionStatus = "Disconnected"

        print("🔌 Disconnected from TAK server")
    }

    func sendCoT(xml: String) -> Bool {
        guard connectionHandle >= 0 else {
            print("❌ Not connected")
            return false
        }

        let xmlCStr = xml.cString(using: .utf8)!
        let result = omnitak_mobile_send_cot(connectionHandle, xmlCStr)

        if result {
            messagesSent += 1
            print("📤 Sent CoT message")
            return true
        } else {
            print("❌ Failed to send CoT message")
            return false
        }
    }

    private func startReceiving() {
        // Poll for incoming messages every 100ms
        receiveTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkForMessages()
        }
    }

    private func stopReceiving() {
        receiveTimer?.invalidate()
        receiveTimer = nil
    }

    private func checkForMessages() {
        guard connectionHandle >= 0 else { return }

        // Allocate buffer for incoming message
        let bufferSize = 64 * 1024 // 64KB buffer
        var buffer = [Int8](repeating: 0, count: bufferSize)

        let bytesRead = omnitak_mobile_receive_cot(
            connectionHandle,
            &buffer,
            Int32(bufferSize)
        )

        if bytesRead > 0 {
            // Convert to Swift String
            if let message = String(bytes: buffer.prefix(Int(bytesRead)), encoding: .utf8) {
                DispatchQueue.main.async {
                    self.messagesReceived += 1
                    self.lastMessage = message
                    print("📥 Received CoT: \(message.prefix(100))...")
                }
            }
        }
    }
}

// Server configuration struct
struct ServerConfig {
    let host: String
    let port: UInt16
    let protocol: String
    let use_tls: Bool
    let certificate_id: String?
    let reconnect: Bool
    let reconnect_delay_ms: Int
}
