import SwiftUI

struct ContentView: View {
    @StateObject private var takService = TAKService()
    @State private var serverHost = "127.0.0.1"
    @State private var serverPort = "8087"
    @State private var useTLS = false
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Server Configuration")) {
                    TextField("Host", text: $serverHost)
                        .autocapitalization(.none)
                    TextField("Port", text: $serverPort)
                        .keyboardType(.numberPad)
                    Toggle("Use TLS", isOn: $useTLS)
                }

                Section(header: Text("Connection Status")) {
                    HStack {
                        Text("Status:")
                        Spacer()
                        Text(takService.connectionStatus)
                            .foregroundColor(takService.isConnected ? .green : .red)
                    }

                    if !takService.lastError.isEmpty {
                        Text(takService.lastError)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Section(header: Text("CoT Messages")) {
                    Text("Received: \(takService.messagesReceived)")
                    Text("Sent: \(takService.messagesSent)")

                    if !takService.lastMessage.isEmpty {
                        VStack(alignment: .leading) {
                            Text("Last Message:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(takService.lastMessage)
                                .font(.caption)
                                .lineLimit(3)
                        }
                    }
                }

                Section {
                    Button(action: connectToServer) {
                        HStack {
                            Spacer()
                            if takService.isConnected {
                                Text("Disconnect")
                                    .foregroundColor(.red)
                            } else {
                                Text("Connect")
                            }
                            Spacer()
                        }
                    }

                    Button(action: sendTestMessage) {
                        HStack {
                            Spacer()
                            Text("Send Test CoT")
                            Spacer()
                        }
                    }
                    .disabled(!takService.isConnected)
                }
            }
            .navigationTitle("OmniTAK Test")
        }
        .alert("TAK Service", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private func connectToServer() {
        if takService.isConnected {
            takService.disconnect()
        } else {
            guard let port = UInt16(serverPort) else {
                alertMessage = "Invalid port number"
                showingAlert = true
                return
            }

            takService.connect(
                host: serverHost,
                port: port,
                protocolType: "tcp",
                useTLS: useTLS
            )
        }
    }

    private func sendTestMessage() {
        let testCoT = """
        <?xml version="1.0" encoding="UTF-8"?>
        <event version="2.0" uid="test-\(UUID().uuidString)" type="a-f-G" time="\(ISO8601DateFormatter().string(from: Date()))" start="\(ISO8601DateFormatter().string(from: Date()))" stale="\(ISO8601DateFormatter().string(from: Date().addingTimeInterval(300)))">
            <point lat="38.8977" lon="-77.0365" hae="0.0" ce="10.0" le="10.0"/>
            <detail>
                <contact callsign="OmniTAK-iOS-Test"/>
            </detail>
        </event>
        """

        if takService.sendCoT(xml: testCoT) {
            alertMessage = "CoT message sent successfully"
        } else {
            alertMessage = "Failed to send CoT message"
        }
        showingAlert = true
    }
}

#Preview {
    ContentView()
}
