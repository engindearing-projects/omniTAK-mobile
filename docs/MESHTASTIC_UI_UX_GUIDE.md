# Meshtastic UI/UX Integration Guide

This guide provides comprehensive examples for integrating the Meshtastic mesh network features into your omniTAK application with beautiful, production-ready user interfaces.

## 📱 iOS/SwiftUI Integration

### Quick Start

The Meshtastic integration provides several SwiftUI views that can be dropped into your app:

```swift
import SwiftUI

struct MyTAKView: View {
    @StateObject private var meshtasticManager = MeshtasticManager()

    var body: some View {
        TabView {
            // Your existing TAK map view
            MapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }

            // Add Meshtastic tab
            MeshtasticConnectionView()
                .tabItem {
                    Label("Mesh", systemImage: "antenna.radiowaves.left.and.right")
                }
        }
    }
}
```

### Connection Management

#### Simple Connection

```swift
import SwiftUI

@MainActor
class TakApp: ObservableObject {
    let meshtastic = MeshtasticManager()

    func setupMeshtastic() {
        // Scan for devices
        meshtastic.scanForDevices()

        // Connect when devices found
        meshtastic.$devices
            .sink { devices in
                if let firstDevice = devices.first {
                    self.meshtastic.connect(to: firstDevice)
                }
            }
            .store(in: &cancellables)
    }
}
```

#### Advanced Connection with Configuration

```swift
// Configure specific connection type
let serialDevice = MeshtasticDevice(
    id: "custom-serial",
    name: "My Meshtastic USB",
    connectionType: .serial,
    devicePath: "/dev/ttyUSB0"
)

let tcpDevice = MeshtasticDevice(
    id: "custom-tcp",
    name: "Network Mesh Node",
    connectionType: .tcp,
    devicePath: "192.168.1.100"
)

// Connect with monitoring
meshtasticManager.connect(to: serialDevice)

// Monitor connection status
meshtasticManager.$connectedDevice
    .sink { device in
        if let device = device {
            print("Connected to: \(device.name)")
            print("Signal: \(device.signalStrength ?? 0) dBm")
        }
    }
    .store(in: &cancellables)
```

### Sending TAK Data Over Mesh

```swift
// Send Position Location Information (PLI)
let pliCoT = """
<?xml version="1.0" encoding="UTF-8"?>
<event version="2.0" uid="MYDEVICE-001" type="a-f-G-U-C"
       time="\(ISO8601DateFormatter().string(from: Date()))"
       start="\(ISO8601DateFormatter().string(from: Date()))"
       stale="\(ISO8601DateFormatter().string(from: Date().addingTimeInterval(300)))"
       how="m-g">
    <point lat="37.7749" lon="-122.4194" hae="10.0" ce="10.0" le="10.0"/>
    <detail>
        <contact callsign="MyCallsign"/>
    </detail>
</event>
"""

let success = meshtasticManager.sendCoT(pliCoT)
if success {
    print("📡 Position sent through mesh!")
}
```

### Real-Time Signal Monitoring

```swift
struct SignalMonitorView: View {
    @ObservedObject var manager: MeshtasticManager

    var body: some View {
        VStack {
            // Current signal strength
            Text("\(manager.connectedDevice?.signalStrength ?? 0) dBm")
                .font(.largeTitle)
                .foregroundColor(signalColor)

            // Quality indicator
            Text(manager.signalQuality.displayText)
                .font(.caption)

            // Signal history chart (automatic updates)
            SignalHistoryView(manager: manager)
        }
    }

    var signalColor: Color {
        Color(manager.signalQuality.color)
    }
}
```

### Mesh Topology Visualization

```swift
// Show mesh network topology
Button("View Network") {
    // Opens beautiful network visualization
    showingTopology = true
}
.sheet(isPresented: $showingTopology) {
    MeshTopologyView(manager: meshtasticManager)
}

// Access mesh nodes programmatically
for node in meshtasticManager.meshNodes {
    print("Node: \(node.longName)")
    print("  Position: \(node.position?.latitude ?? 0), \(node.position?.longitude ?? 0)")
    print("  Hops: \(node.hopDistance ?? 0)")
    print("  SNR: \(node.snr ?? 0) dB")
    print("  Battery: \(node.batteryLevel ?? 0)%")
}
```

### Custom Device Picker

```swift
struct CustomMeshSetup: View {
    @ObservedObject var manager: MeshtasticManager
    @State private var showingPicker = false

    var body: some View {
        VStack {
            if manager.isConnected {
                // Connected state
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(manager.connectionStatus)
                    Spacer()
                    Button("Disconnect") {
                        manager.disconnect()
                    }
                }
            } else {
                // Not connected
                Button("Connect to Mesh") {
                    showingPicker = true
                }
            }
        }
        .sheet(isPresented: $showingPicker) {
            MeshtasticDevicePickerView(manager: manager)
        }
    }
}
```

## 🌐 TypeScript/React Native Integration

### Setup

```typescript
import { MeshtasticService } from './services/MeshtasticService';
import { useEffect, useState } from 'react';

// Initialize service
const meshtasticService = new MeshtasticService(nativeModule);

function App() {
    const [devices, setDevices] = useState([]);
    const [isConnected, setIsConnected] = useState(false);

    useEffect(() => {
        // Listen for events
        meshtasticService.on('devicesUpdated', setDevices);
        meshtasticService.on('connected', () => setIsConnected(true));
        meshtasticService.on('disconnected', () => setIsConnected(false));

        // Scan for devices
        meshtasticService.scanForDevices();

        return () => {
            meshtasticService.removeAllListeners();
        };
    }, []);

    return (
        <View>
            <MeshtasticConnectionPanel
                service={meshtasticService}
                devices={devices}
                isConnected={isConnected}
            />
        </View>
    );
}
```

### React Native Device List

```tsx
import React from 'react';
import { View, Text, FlatList, TouchableOpacity } from 'react-native';

interface DeviceListProps {
    service: MeshtasticService;
    devices: MeshtasticDevice[];
}

export const DeviceList: React.FC<DeviceListProps> = ({ service, devices }) => {
    return (
        <FlatList
            data={devices}
            keyExtractor={(item) => item.id}
            renderItem={({ item }) => (
                <TouchableOpacity
                    onPress={() => service.connect(item)}
                    style={styles.deviceItem}
                >
                    <View>
                        <Text style={styles.deviceName}>{item.name}</Text>
                        <Text style={styles.devicePath}>{item.devicePath}</Text>
                    </View>

                    {item.isConnected && (
                        <Text style={styles.connected}>Connected ✓</Text>
                    )}

                    {item.signalStrength && (
                        <Text style={styles.signal}>
                            {item.signalStrength} dBm
                        </Text>
                    )}
                </TouchableOpacity>
            )}
        />
    );
};
```

### Signal Strength Component

```tsx
import React, { useEffect, useState } from 'react';
import { View, Text } from 'react-native';

export const SignalStrengthIndicator: React.FC<{ service: MeshtasticService }> = ({
    service,
}) => {
    const [signal, setSignal] = useState<number | null>(null);

    useEffect(() => {
        const handler = (reading: SignalStrengthReading) => {
            setSignal(reading.rssi);
        };

        service.on('signalUpdated', handler);
        return () => service.off('signalUpdated', handler);
    }, [service]);

    const quality = service.signalQuality;
    const color = service.getSignalQualityColor(quality);

    return (
        <View style={[styles.container, { borderColor: color }]}>
            <Text style={[styles.rssi, { color }]}>
                {signal !== null ? `${signal} dBm` : '--'}
            </Text>
            <Text style={styles.quality}>{quality.toUpperCase()}</Text>
        </View>
    );
};
```

### Mesh Network Map

```tsx
import React, { useEffect, useState } from 'react';
import MapView, { Marker } from 'react-native-maps';

export const MeshNetworkMap: React.FC<{ service: MeshtasticService }> = ({
    service,
}) => {
    const [nodes, setNodes] = useState<MeshNode[]>([]);

    useEffect(() => {
        const handler = (updatedNodes: MeshNode[]) => {
            setNodes(updatedNodes);
        };

        service.on('nodesUpdated', handler);
        return () => service.off('nodesUpdated', handler);
    }, [service]);

    return (
        <MapView
            initialRegion={{
                latitude: 37.7749,
                longitude: -122.4194,
                latitudeDelta: 0.1,
                longitudeDelta: 0.1,
            }}
        >
            {nodes.map((node) =>
                node.position ? (
                    <Marker
                        key={node.id}
                        coordinate={{
                            latitude: node.position.latitude,
                            longitude: node.position.longitude,
                        }}
                        title={node.longName}
                        description={`Hops: ${node.hopDistance || 0}, SNR: ${node.snr || 0} dB`}
                    />
                ) : null
            )}
        </MapView>
    );
};
```

### Sending Messages

```typescript
// Send position update
const sendPositionUpdate = async (lat: number, lon: number, alt: number) => {
    const cotXML = `<?xml version="1.0" encoding="UTF-8"?>
<event version="2.0" uid="MOBILE-${Date.now()}" type="a-f-G-U-C"
       time="${new Date().toISOString()}"
       start="${new Date().toISOString()}"
       stale="${new Date(Date.now() + 300000).toISOString()}"
       how="m-g">
    <point lat="${lat}" lon="${lon}" hae="${alt}" ce="10.0" le="10.0"/>
    <detail>
        <contact callsign="MobileUser"/>
    </detail>
</event>`;

    const success = await meshtasticService.sendCoT(cotXML);
    console.log('Position sent:', success);
};

// Send chat message
const sendChatMessage = async (message: string) => {
    const cotXML = `<?xml version="1.0" encoding="UTF-8"?>
<event version="2.0" uid="${uuidv4()}" type="b-t-f"
       time="${new Date().toISOString()}"
       start="${new Date().toISOString()}"
       stale="${new Date(Date.now() + 600000).toISOString()}"
       how="h-e">
    <point lat="0.0" lon="0.0" hae="0.0" ce="999999.0" le="999999.0"/>
    <detail>
        <__chat id="${uuidv4()}" chatroom="All Chat Rooms">
            <chatgrp uid0="ME" uid1="All Chat Rooms" id="All Chat Rooms"/>
        </__chat>
        <remarks>${message}</remarks>
    </detail>
</event>`;

    return await meshtasticService.sendCoT(cotXML);
};
```

## 🎨 UI/UX Best Practices

### Color Coding

The integration uses consistent color coding:

- **Green**: Excellent signal / Connected / Healthy
- **Blue**: Good signal / Normal operation
- **Yellow/Orange**: Fair signal / Warning
- **Red**: Poor signal / Error
- **Gray**: No signal / Disconnected

### Signal Quality Indicators

```swift
// Swift
let quality = manager.signalQuality
let icon = quality.iconName  // SF Symbol name
let color = Color(quality.color)

// TypeScript
const quality = service.signalQuality;
const color = service.getSignalQualityColor(quality);
```

### Real-Time Updates

All views automatically update when:
- Signal strength changes (every 2 seconds)
- New nodes discovered (every 5 seconds)
- Connection state changes
- Network stats update

### Error Handling

```swift
// Swift
if let error = manager.lastError {
    Alert(
        title: Text("Meshtastic Error"),
        message: Text(error),
        dismissButton: .default(Text("OK"))
    )
}

// TypeScript
service.on('error', (error) => {
    Alert.alert('Meshtastic Error', error.message);
});
```

## 📊 Network Statistics

### Accessing Stats

```swift
// Swift
let stats = manager.networkStats
print("Connected nodes: \(stats.connectedNodes)/\(stats.totalNodes)")
print("Average hops: \(stats.averageHops)")
print("Success rate: \(stats.packetSuccessRate * 100)%")
print("Utilization: \(stats.networkUtilization * 100)%")

// TypeScript
const stats = service.getNetworkStats();
console.log(`Nodes: ${stats.connectedNodes}/${stats.totalNodes}`);
console.log(`Success: ${stats.packetSuccessRate * 100}%`);
```

### Network Health

```swift
// Swift
switch manager.networkHealth {
case .excellent:
    statusText = "Network is operating optimally"
case .good:
    statusText = "Network is performing well"
case .fair:
    statusText = "Network experiencing some issues"
case .poor:
    statusText = "Network has significant problems"
case .disconnected:
    statusText = "Not connected to mesh"
}

// TypeScript
const health = service.networkHealth;
const healthColor = service.getNetworkHealthColor(health);
```

## 🔧 Advanced Usage

### Custom Device Discovery

```swift
// Add your own device discovery logic
meshtasticManager.devices.append(
    MeshtasticDevice(
        id: "custom-1",
        name: "My Custom Meshtastic",
        connectionType: .tcp,
        devicePath: "meshtastic.local"
    )
)
```

### Filtering Signal History

```typescript
// Get last 5 minutes of signal data
const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
const recentReadings = service
    .getSignalHistory()
    .filter((reading) => reading.timestamp >= fiveMinutesAgo);

// Calculate average RSSI
const avgRSSI =
    recentReadings.reduce((sum, r) => sum + r.rssi, 0) / recentReadings.length;
```

### Node Filtering and Sorting

```swift
// Get nodes by hop distance
let nearbyNodes = manager.meshNodes.filter { ($0.hopDistance ?? 999) <= 2 }

// Sort by signal strength
let sortedBySignal = manager.meshNodes.sorted { lhs, rhs in
    (lhs.snr ?? -999) > (rhs.snr ?? -999)
}

// Find nodes with low battery
let lowBatteryNodes = manager.meshNodes.filter { ($0.batteryLevel ?? 100) < 25 }
```

## 🎯 Complete Example App

```swift
import SwiftUI

@main
struct MeshtasticTAKApp: App {
    @StateObject private var meshtastic = MeshtasticManager()

    var body: some Scene {
        WindowGroup {
            TabView {
                // Main map with TAK data
                MapView()
                    .environmentObject(meshtastic)
                    .tabItem {
                        Label("Map", systemImage: "map")
                    }

                // Meshtastic connection and mesh network
                MeshtasticConnectionView()
                    .environmentObject(meshtastic)
                    .tabItem {
                        Label("Mesh", systemImage: "antenna.radiowaves.left.and.right")
                    }

                // Settings
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
            .onAppear {
                // Auto-scan on launch
                meshtastic.scanForDevices()
            }
        }
    }
}
```

## 📱 Platform-Specific Notes

### iOS
- Serial connections require MFi certification
- Bluetooth requires `NSBluetoothAlwaysUsageDescription` in Info.plist
- Background operation requires `bluetooth-central` background mode

### Android
- Serial requires USB host mode
- Bluetooth requires `BLUETOOTH` and `BLUETOOTH_CONNECT` permissions
- Location permission needed for Bluetooth scanning on Android 12+

### Web
- Requires Web Serial API (Chrome, Edge)
- Must use HTTPS (except localhost)
- User must grant permission for each device

## 🚀 Performance Tips

1. **Signal monitoring**: 2-second intervals are optimal
2. **Node discovery**: 5-second intervals prevent excessive traffic
3. **Signal history**: Keep last 100 readings (auto-managed)
4. **Mesh updates**: Batch position updates every 30 seconds minimum

## 🎉 Result

With this integration, you have:

- ✅ Beautiful, native device discovery UI
- ✅ Real-time signal strength monitoring
- ✅ Mesh network topology visualization
- ✅ Automatic CoT message translation
- ✅ Production-ready error handling
- ✅ Cross-platform TypeScript/Swift support
- ✅ Comprehensive statistics and health indicators

Your users can now seamlessly connect to Meshtastic devices and communicate over mesh networks with the same ease as regular TAK servers!
