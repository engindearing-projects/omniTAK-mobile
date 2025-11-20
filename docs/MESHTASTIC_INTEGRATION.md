# Meshtastic Integration for omniTAK

This document describes the Meshtastic mesh network integration for omniTAK-mobile, enabling TAK devices to communicate over long-range radio frequencies without cellular or WiFi networks.

## Overview

Meshtastic is a project that enables low-power, long-range communication using LoRa radio technology. The integration allows omniTAK users to:

- Send and receive CoT (Cursor on Target) messages over Meshtastic mesh networks
- Exchange Position Location Information (PLI) with other mesh nodes
- Send GeoChat messages through the mesh
- Operate completely off-grid without internet connectivity
- Achieve communication ranges of several kilometers (or more with proper setup)

## Features

### ✅ Implemented
- **CoT Message Translation**: Automatic conversion between TAK CoT XML and Meshtastic protobuf format
- **Connection Types**: Serial/USB, TCP (Bluetooth support structure in place)
- **Message Chunking**: Automatic splitting of large messages (>200 bytes) into chunks
- **Position Updates**: PLI (Position Location Information) transmission and reception
- **GeoChat**: Text messaging through mesh network
- **Multi-protocol Support**: Meshtastic works alongside existing TCP/UDP/TLS connections
- **FFI Bindings**: C-compatible interface for iOS and Android

### 🚧 Ready for Testing
- Serial/USB device connections
- TCP connections to network-enabled Meshtastic devices
- Position and chat message exchange

### 📋 Future Enhancements
- Bluetooth Low Energy (BLE) connections
- Advanced routing options
- Mesh topology visualization
- Device discovery UI
- Signal strength and mesh statistics

## Architecture

### Crate Structure

```
crates/
├── omnitak-core/          # Core types with Meshtastic protocol support
├── omnitak-meshtastic/    # Meshtastic-specific implementation
│   ├── proto/            # Protobuf definitions
│   ├── src/lib.rs        # Client and conversion logic
│   └── build.rs          # Protobuf compilation
├── omnitak-client/        # Unified client with Meshtastic support
└── omnitak-mobile/        # FFI bridge with Meshtastic bindings
```

### Protocol Flow

1. **Outgoing Messages**:
   ```
   App → CoT XML → MeshtasticClient → Protobuf encoding →
   → Chunking (if needed) → ToRadio frame → Serial/TCP → Meshtastic device
   ```

2. **Incoming Messages**:
   ```
   Meshtastic device → Serial/TCP → FromRadio frame →
   → Protobuf decoding → Chunk reassembly → CoT XML → App callback
   ```

### Message Types

The integration supports several Meshtastic message types:

- **ATAK_FORWARDER** (Port 257): Full CoT XML forwarding
- **ATAK_PLUGIN** (Port 72): ATAK plugin compatibility
- **POSITION_APP** (Port 3): Position updates converted to PLI
- **TEXT_MESSAGE_APP** (Port 1): Chat messages converted to GeoChat

## Usage

### FFI Interface (C/Swift/Java)

#### Initialize

```c
omnitak_init();
```

#### Connect to Meshtastic Device

**Serial Connection:**
```c
uint64_t conn_id = omnitak_connect_meshtastic(
    0,                      // connection_type: 0 = Serial
    "/dev/ttyUSB0",        // device_path (Linux/Mac)
    // "COM3",             // device_path (Windows)
    0,                      // port (not used for serial)
    0,                      // node_id (0 = broadcast to all)
    "My Meshtastic Device" // device_name (optional)
);
```

**TCP Connection:**
```c
uint64_t conn_id = omnitak_connect_meshtastic(
    2,                  // connection_type: 2 = TCP
    "192.168.1.100",   // hostname/IP of Meshtastic device
    4403,              // TCP port
    0,                 // node_id (0 = broadcast)
    "TCP Mesh Node"    // device_name
);
```

**Bluetooth Connection (Structure ready, implementation pending):**
```c
uint64_t conn_id = omnitak_connect_meshtastic(
    1,                      // connection_type: 1 = Bluetooth
    "00:11:22:33:44:55",   // Bluetooth MAC address
    0,                      // port (not used for Bluetooth)
    0,                      // node_id
    "BLE Mesh Device"      // device_name
);
```

#### Send CoT Message

```c
const char* cot_xml = "<?xml version=\"1.0\"?><event>...</event>";
int result = omnitak_send_cot(conn_id, cot_xml);
```

#### Register Callback for Incoming Messages

```c
void cot_callback(void* user_data, uint64_t conn_id, const char* cot_xml) {
    printf("Received CoT: %s\n", cot_xml);
}

omnitak_register_callback(conn_id, cot_callback, NULL);
```

#### Disconnect

```c
omnitak_disconnect(conn_id);
```

### Rust Interface

```rust
use omnitak_core::{ConnectionConfig, MeshtasticConfig, MeshtasticConnectionType};
use omnitak_meshtastic::MeshtasticClient;

// Create config
let meshtastic_config = MeshtasticConfig {
    connection_type: MeshtasticConnectionType::Serial("/dev/ttyUSB0".to_string()),
    node_id: None, // Broadcast to all nodes
    device_name: Some("My Device".to_string()),
};

let config = ConnectionConfig::new_meshtastic(meshtastic_config);

// Connect
let client = MeshtasticClient::connect(config, Some(Box::new(|cot_xml| {
    println!("Received: {}", cot_xml);
}))).await?;

// Send CoT
client.send_cot(r#"<?xml version="1.0"?>
<event version="2.0" uid="TEST-001" type="a-f-G-U-C"
       time="2024-01-01T00:00:00Z" start="2024-01-01T00:00:00Z"
       stale="2024-01-01T00:05:00Z" how="m-g">
    <point lat="37.7749" lon="-122.4194" hae="10.0" ce="10.0" le="10.0"/>
    <detail>
        <contact callsign="TEST-001"/>
    </detail>
</event>"#)?;
```

## CoT Message Handling

### Automatic Conversions

#### Position Updates → CoT PLI
Meshtastic position messages are automatically converted to TAK Position Location Information:

```xml
<event version="2.0" uid="MESHTASTIC-12345678" type="a-f-G-U-C" ...>
    <point lat="37.7749" lon="-122.4194" hae="100.0" ce="10.0" le="10.0"/>
    <detail>
        <contact callsign="Mesh-12345678"/>
        <uid Droid="Mesh-12345678"/>
        <track course="0.0" speed="0.0"/>
    </detail>
</event>
```

#### Text Messages → CoT GeoChat
Meshtastic text messages become GeoChat messages:

```xml
<event version="2.0" uid="..." type="b-t-f" ...>
    <detail>
        <__chat id="..." chatroom="All Chat Rooms">
            <chatgrp uid0="MESHTASTIC-12345678" uid1="All Chat Rooms" .../>
        </__chat>
        <remarks>Hello from the mesh!</remarks>
    </detail>
</event>
```

#### Full CoT → Meshtastic TAKPacket
Complete CoT messages are encapsulated in Meshtastic TAKPacket protobuf messages for transmission through the mesh.

### Message Size Limits

- **Maximum single packet**: 233 bytes (LoRa limitation)
- **Automatic chunking**: Messages >200 bytes are split
- **Chunk reassembly**: Automatic reconstruction of chunked messages
- **Recommended**: Keep CoT messages concise for mesh transmission

## Hardware Setup

### Supported Devices

Any Meshtastic-compatible device:
- **RAK WisBlock** (RAK4631, RAK11200, etc.)
- **Heltec** LoRa boards (V2, V3, Wireless Stick)
- **TTGO** T-Beam, T-Echo
- **LilyGO** devices
- Custom ESP32 + LoRa module builds

### Connection Methods

#### Serial/USB
1. Connect Meshtastic device via USB
2. Identify device path:
   - **Linux/Mac**: `/dev/ttyUSB0`, `/dev/ttyACM0`, `/dev/cu.usbserial-*`
   - **Windows**: `COM3`, `COM4`, etc.
3. Device communicates at 38400 baud (handled automatically)

#### TCP/IP
1. Configure Meshtastic device with network module
2. Enable TCP server on device
3. Connect to device's IP address and port (default: 4403)
4. Useful for Ethernet or WiFi-enabled Meshtastic nodes

#### Bluetooth (Coming Soon)
1. Pair Meshtastic device with mobile device
2. Use device's Bluetooth MAC address
3. iOS: Use Core Bluetooth framework
4. Android: Use Bluetooth Classic or BLE

## Configuration

### Meshtastic Device Settings

For optimal TAK integration, configure your Meshtastic device:

```bash
# Set device role (recommended: TAK or CLIENT)
meshtastic --set device.role TAK

# Configure LoRa region (required)
meshtastic --set lora.region US  # or EU_868, etc.

# Enable position broadcasts
meshtastic --set position.position_broadcast_secs 300

# Optional: Increase transmit power (check local regulations)
meshtastic --set lora.tx_power 22
```

### Channel Configuration

Ensure all devices are on the same channel:

```bash
# View current channel settings
meshtastic --ch-index 0 --ch-get

# Set channel name
meshtastic --ch-index 0 --ch-set name "TAK-OPS"
```

## Testing Without Hardware

For development without a Meshtastic device:

1. **Use the TCP connection mode** with a simulated Meshtastic device
2. **Install Meshtastic Python CLI** and create a virtual device:
   ```bash
   pip install meshtastic
   meshtastic --host localhost --port 4403
   ```

3. **Use Meshtastic Simulator** (community tool)

## Troubleshooting

### Connection Issues

**Problem**: Can't connect to serial device
- **Check**: Device path is correct (`ls /dev/tty*` on Unix)
- **Check**: User has permissions (`sudo usermod -a -G dialout $USER`)
- **Check**: Device is not in use by another application
- **Check**: Meshtastic firmware is up to date

**Problem**: No messages received
- **Check**: Callback is registered before sending
- **Check**: Devices are on same channel and region
- **Check**: LoRa frequency settings match
- **Check**: Devices are within range (LoRa range varies greatly)

### Message Issues

**Problem**: Messages not arriving
- **Check**: Message size (<200 bytes recommended)
- **Check**: Mesh network has connectivity
- **Check**: Node IDs are correct (use 0 for broadcast)
- **Check**: Channel encryption keys match

**Problem**: Chunked messages incomplete
- **Check**: Mesh reliability (weak signals may drop chunks)
- **Solution**: Use hop_limit and want_ack for reliable delivery
- **Solution**: Reduce message size

### Performance

**Slow message delivery**:
- LoRa is designed for long-range, not low-latency
- Typical message times: 1-5 seconds per transmission
- Mesh routing adds delay (0.5-2s per hop)
- Use appropriate `hop_limit` (default: 3)

## Protocol Details

### Protobuf Messages

Key message structures (see `proto/meshtastic.proto`):

```protobuf
message MeshPacket {
    fixed32 from = 1;           // Sender node ID
    fixed32 to = 2;             // Destination (0xFFFFFFFF = broadcast)
    uint32 channel = 3;         // Channel index
    Data decoded = 4;           // Decoded payload
    bytes encrypted = 5;        // Or encrypted payload
    fixed32 id = 6;             // Unique packet ID
    uint32 hop_limit = 9;       // Hops remaining
    bool want_ack = 10;         // Request acknowledgment
}

message TAKPacket {
    bool is_compressed = 1;
    string contact_callsign = 2;
    string contact_uid = 3;
    PLILocation pli_location = 4;
    bytes cot = 7;              // Full CoT XML
}
```

### Frame Format

Streaming transport uses a 4-byte header:
```
[START1: 0x94] [START2: 0xC3] [LENGTH_MSB] [LENGTH_LSB] [PROTOBUF_PAYLOAD...]
```

## Integration with ATAK/WinTAK/iTAK

Your Meshtastic-enabled omniTAK device can:
- Relay CoT messages from ATAK to mesh network
- Forward mesh messages to TAK servers
- Act as an off-grid TAK gateway
- Provide emergency communications when infrastructure is down

## Best Practices

1. **Keep messages small**: <200 bytes for single-packet delivery
2. **Use broadcasts wisely**: Direct messaging (node_id) when possible
3. **Monitor battery**: LoRa transmission uses significant power
4. **Plan your mesh**: Consider line-of-sight and node placement
5. **Test range**: LoRa range varies greatly with environment
6. **Update firmware**: Keep Meshtastic firmware current
7. **Secure your mesh**: Use channel encryption for operations

## Example Use Cases

### Disaster Response
- First responders coordinate with no cell service
- Mesh extends beyond damaged infrastructure
- Multiple teams share positions and status

### Military Operations
- Covert communications with minimal RF signature
- Long-range coordination in remote areas
- Mesh resilience against jamming

### Search and Rescue
- Teams maintain contact in wilderness
- Position sharing across large search areas
- Relay messages through sparse network

### Remote Operations
- Field teams in areas without coverage
- Cost-effective alternative to satcom
- Local mesh with occasional backhaul

## API Reference

### FFI Functions

```c
// Initialize library
int omnitak_init(void);

// Connect to Meshtastic device
// connection_type: 0=Serial, 1=Bluetooth, 2=TCP
// Returns: connection ID or 0 on error
uint64_t omnitak_connect_meshtastic(
    int connection_type,
    const char* device_path,
    uint16_t port,
    uint32_t node_id,
    const char* device_name
);

// Send CoT message
int omnitak_send_cot(uint64_t connection_id, const char* cot_xml);

// Register callback for incoming messages
typedef void (*CotCallback)(void* user_data, uint64_t conn_id, const char* cot_xml);
int omnitak_register_callback(uint64_t connection_id, CotCallback callback, void* user_data);

// Disconnect
int omnitak_disconnect(uint64_t connection_id);

// Shutdown library
void omnitak_shutdown(void);
```

## Contributing

To extend the Meshtastic integration:

1. **Add new message types**: Extend protobuf definitions and converters
2. **Improve chunking**: Optimize for mesh bandwidth
3. **Add BLE support**: Implement Bluetooth connection handler
4. **Device discovery**: Add automatic Meshtastic device detection
5. **Mesh visualization**: Show network topology and signal strength

## Resources

- **Meshtastic Documentation**: https://meshtastic.org/docs/
- **Meshtastic GitHub**: https://github.com/meshtastic/
- **TAK Protocol**: https://tak.gov/
- **LoRa Technology**: https://lora-alliance.org/

## License

This integration follows the omniTAK-mobile license (MIT OR Apache-2.0).

## Support

For issues specific to Meshtastic integration:
1. Check device firmware version
2. Review this documentation
3. Test with Meshtastic Python CLI
4. Open an issue with logs and device info

---

**Note**: This is experimental integration for off-grid TAK communications. Test thoroughly before operational use.
