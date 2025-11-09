# OmniTAK iOS Test App

Simple native iOS test app for testing the omnitak-mobile XCFramework on a real iPhone.

## Quick Setup

### Option 1: Use Xcode (Recommended)

1. **Open Xcode** and create a new iOS App project:
   - File → New → Project → iOS → App
   - Product Name: `OmniTAKTest`
   - Organization Identifier: `com.engindearing.omnitak`
   - Interface: SwiftUI
   - Language: Swift
   - Save in: `apps/omnitak_ios_test/`

2. **Replace the generated files** with the ones in `OmniTAKTest/` directory:
   - OmniTAKTestApp.swift
   - ContentView.swift
   - TAKService.swift
   - Info.plist

3. **Add the XCFramework**:
   - Drag `OmniTAKMobile.xcframework` into your project navigator
   - Check "Copy items if needed"
   - Add to target: OmniTAKTest
   - In target settings → General → "Frameworks, Libraries, and Embedded Content"
     - Set to "Embed & Sign"

4. **Configure signing**:
   - Select your target → Signing & Capabilities
   - Check "Automatically manage signing"
   - Select your Team

5. **Connect your iPhone** and select it as the run destination

6. **Build and Run** (⌘R)

### Option 2: Use the Setup Script

```bash
cd apps/omnitak_ios_test
./setup_xcode.sh
open OmniTAKTest.xcodeproj
```

## Testing TAK Connectivity

1. **Launch the app** on your iPhone

2. **Configure the server**:
   - Default server: `204.48.30.216:8087` (FreeTAKServer)
   - Protocol: TCP (default) or TLS
   - Tap "Connect"

3. **Monitor connection status**:
   - Green "Connected" when successful
   - Red error message if connection fails

4. **Send test CoT messages**:
   - Tap "Send Test CoT" when connected
   - Monitor "Messages Sent" counter

5. **Receive CoT messages**:
   - "Messages Received" counter increments when server sends data
   - Last message preview shows in the UI

## Troubleshooting

### "Failed to connect"
- Check iPhone is connected to internet
- Verify server is reachable: `nc -zv 204.48.30.216 8087`
- Try different protocol (TCP vs TLS)

### "Code signing error"
- Select your Team in Xcode Signing settings
- Update Bundle Identifier if needed: `com.yourdomain.omnitak`

### "Framework not found"
- Verify OmniTAKMobile.xcframework is in project
- Check "Embed & Sign" is selected for the framework
- Clean build folder: Product → Clean Build Folder

## Architecture

```
OmniTAKTest (SwiftUI)
    ↓
TAKService (Swift Observable Object)
    ↓
omnitak_mobile FFI (C API)
    ↓
OmniTAKMobile.xcframework (Rust)
    ↓
TAK Server (TCP/TLS/WebSocket)
```

## Features

- ✅ TCP/TLS/WebSocket connections
- ✅ Send CoT messages (XML)
- ✅ Receive CoT messages
- ✅ Connection status monitoring
- ✅ Message counters
- ⏳ CoT parsing and display (TODO)
- ⏳ Map visualization (TODO)

## Next Steps

After testing basic connectivity:
1. Add CoT message parsing
2. Integrate MapLibre for visualization
3. Add certificate management for TLS
4. Implement reconnection logic
5. Add location tracking and self-SA
