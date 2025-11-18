# OmniTAK Mobile iOS - Setup Summary

Complete iOS build configuration has been created for OmniTAK Mobile. This document provides a quick reference for building and running the iOS app.

## What Was Created

### 1. iOS App Structure

```
/Users/iesouskurios/Downloads/omni-BASE/apps/omnitak_mobile_ios/
├── BUILD.bazel                               Bazel build configuration
├── README.md                                 Project documentation
├── IOS_BUILD_GUIDE.md                        Comprehensive build guide
├── SETUP_SUMMARY.md                          This file
│
├── src/ios/
│   ├── AppDelegate.swift                     App lifecycle
│   └── ViewController.swift                  Main UI with demo
│
├── app_assets/ios/
│   ├── Info.plist                           App permissions
│   └── LaunchScreen.storyboard              Launch screen
│
└── tests/ios/
    └── OmniTAKTests.swift                   Unit tests
```

### 2. Native Module Configuration

```
/Users/iesouskurios/Downloads/omni-BASE/modules/omnitak_mobile/ios/
├── native/
│   ├── BUILD.bazel                          XCFramework linking
│   ├── OmniTAKNativeBridge.swift          (existing)
│   ├── omnitak_mobile.h                   (existing)
│   └── OmniTAKMobile.xcframework/         (existing)
│
└── maplibre/
    ├── BUILD.bazel                          MapLibre config
    ├── SCMapLibreMapView.h                (existing)
    └── SCMapLibreMapView.m                (existing)
```

### 3. Build Scripts

```
/Users/iesouskurios/Downloads/omni-BASE/scripts/
├── build_ios.sh                             Build for iOS
├── run_ios_simulator.sh                     Run on simulator
└── test_ios.sh                              Run tests
```

### 4. Bazel Configuration

```
/Users/iesouskurios/Downloads/omni-BASE/
└── .bazelrc.ios                             iOS-specific Bazel config
```

## Prerequisites Checklist

Before building, ensure you have:

- [ ] macOS 12.0+ (Monterey or later)
- [ ] Xcode 14.0+ installed
- [ ] Xcode Command Line Tools (`xcode-select --install`)
- [ ] Bazel 6.0+ (`brew install bazel`)
- [ ] Rust toolchain with iOS targets
- [ ] OmniTAKMobile.xcframework built (see below)

### Install Rust iOS Targets

```bash
rustup target add aarch64-apple-ios
rustup target add aarch64-apple-ios-sim
rustup target add x86_64-apple-ios
```

### Build XCFramework (if not already done)

The XCFramework should already exist at:
```
/Users/iesouskurios/Downloads/omni-BASE/modules/omnitak_mobile/ios/native/OmniTAKMobile.xcframework
```

If it's missing, build it from the Rust crate:

```bash
# Navigate to Rust project
cd /Users/iesouskurios/Downloads/omni-TAK

# Build for iOS targets
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim
cargo build --release --target x86_64-apple-ios

# Create XCFramework (you'll need a script for this)
# See the Rust project's iOS build documentation
```

## Quick Start Commands

### 1. Build and Run on Simulator (Fastest)

```bash
cd /Users/iesouskurios/Downloads/omni-BASE

# One command to build, install, and run
./scripts/run_ios_simulator.sh
```

This will:
-  Build the app for iOS simulator
-  Boot the iPhone 15 Pro simulator
-  Install the app
-  Launch and show console output

### 2. Build Only

```bash
# Debug build for simulator
./scripts/build_ios.sh simulator debug

# Release build for simulator
./scripts/build_ios.sh simulator release

# Debug build for device
./scripts/build_ios.sh device debug

# Release build for device
./scripts/build_ios.sh device release
```

### 3. Run Tests

```bash
# All tests
./scripts/test_ios.sh

# Specific test class
./scripts/test_ios.sh OmniTAKNativeBridgeTests

# Specific test method
./scripts/test_ios.sh testGetVersion
```

### 4. Manual Simulator Control

```bash
# List available simulators
xcrun simctl list devices available | grep iPhone

# Boot a specific simulator
xcrun simctl boot "iPhone 15 Pro"

# Install app
xcrun simctl install booted \
    bazel-bin/apps/omnitak_mobile_ios/OmniTAKMobile-Simulator.app

# Launch app
xcrun simctl launch --console booted \
    com.engindearing.omnitak.mobile

# View logs
xcrun simctl spawn booted log stream \
    --predicate 'processImagePath contains "OmniTAK"'
```

## Bazel Direct Commands

If you prefer using Bazel directly:

### Build

```bash
# Simulator (arm64 - Apple Silicon)
bazel build //apps/omnitak_mobile_ios:OmniTAKMobile-Simulator \
    --config=ios_sim_arm64 \
    --compilation_mode=dbg

# Simulator (x86_64 - Intel)
bazel build //apps/omnitak_mobile_ios:OmniTAKMobile-Simulator \
    --config=ios_sim_x86_64 \
    --compilation_mode=dbg

# Device
bazel build //apps/omnitak_mobile_ios:OmniTAKMobile \
    --config=ios_arm64 \
    --compilation_mode=dbg
```

### Test

```bash
# Run all tests
bazel test //apps/omnitak_mobile_ios:OmniTAKMobileTests \
    --config=ios_sim_debug \
    --test_output=all

# Verbose output
bazel test //apps/omnitak_mobile_ios:OmniTAKMobileTests \
    --config=ios_sim_debug \
    --test_output=all \
    -s
```

### Query

```bash
# Show all dependencies
bazel query 'deps(//apps/omnitak_mobile_ios:OmniTAKMobile-Simulator)' \
    --output=tree

# Show build graph
bazel query 'deps(//apps/omnitak_mobile_ios:OmniTAKMobile-Simulator)' \
    --output=graph > deps.dot
dot -Tpng deps.dot > deps.png
```

## Configuration Files

### Import iOS Bazel Config

Add this line to `/Users/iesouskurios/Downloads/omni-BASE/.bazelrc`:

```bash
try-import %workspace%/.bazelrc.ios
```

This will enable iOS-specific build configurations.

### Update Bundle ID (Optional)

To use your own bundle identifier, edit:
```
apps/omnitak_mobile_ios/BUILD.bazel
```

Change:
```python
bundle_id = "com.engindearing.omnitak.mobile",
```

To:
```python
bundle_id = "com.yourcompany.omnitak.mobile",
```

### Configure TAK Server

Edit `apps/omnitak_mobile_ios/src/ios/ViewController.swift`, line ~130:

```swift
let config: [String: Any] = [
    "host": "your-tak-server.example.com",  // ← Update this
    "port": 8089,
    "protocol": "tcp",
    "useTls": false,
    "reconnect": true,
    "reconnectDelayMs": 5000
]
```

## Features Demonstrated in the App

The iOS app demonstrates all OmniTAK Mobile capabilities:

1. **TAK Server Connection**
   - TCP/UDP/TLS/WebSocket protocols
   - Automatic reconnection
   - Connection status monitoring

2. **CoT Messaging**
   - Send cursor-on-target messages
   - Receive and parse CoT messages
   - Callback-based event handling

3. **MapLibre Integration**
   - Interactive map rendering
   - Camera positioning
   - Marker/annotation support
   - Touch event handling

4. **Native Bridge**
   - Rust ↔ Swift interop via C FFI
   - Thread-safe callback handling
   - Memory-safe string passing

## Testing the App

### 1. Launch the App

```bash
./scripts/run_ios_simulator.sh
```

### 2. Test Features

The app UI has three buttons:

1. **Connect to TAK Server**
   - Click to connect to the configured server
   - Status label shows connection state
   - Button changes to "Disconnect" when connected

2. **Send Test CoT**
   - Enabled after connection
   - Sends a sample CoT message
   - Status shows success/failure

3. **Map View**
   - Displays an interactive MapLibre map
   - Pan, zoom, and rotate gestures
   - Shows initial position (center of USA)

### 3. Expected Output

Console should show:
```
[OmniTAK] Application launched successfully
[OmniTAK] iOS Version: 17.0
[OmniTAK] Device Model: iPhone
[OmniTAK] ViewController loaded
[OmniTAK] Native bridge initialized, version: 0.1.0
[MapLibre] Map style loaded successfully
[OmniTAK] Connected successfully, ID: 1
[OmniTAK] Test CoT sent successfully
[OmniTAK] Received CoT: <event...>
```

## Troubleshooting

### Issue: XCFramework Not Found

**Error**: `No such file or directory: OmniTAKMobile.xcframework`

**Solution**: Build the Rust library first and ensure the XCFramework is in the correct location:

```bash
# Check if XCFramework exists
ls -la /Users/iesouskurios/Downloads/omni-BASE/modules/omnitak_mobile/ios/native/OmniTAKMobile.xcframework

# If missing, build it from the Rust project
cd /Users/iesouskurios/Downloads/omni-TAK
# Follow Rust project's iOS build instructions
```

### Issue: Simulator Not Found

**Error**: `No iPhone simulators found`

**Solution**: Install iOS simulators via Xcode:
```
Xcode > Preferences > Components > Download additional iOS versions
```

Or list all available devices:
```bash
xcrun simctl list devices
```

### Issue: Code Signing Failed

**Error**: `Code signing failed`

**Solution**: For testing, use ad-hoc signing:

Edit `.bazelrc.ios`:
```bash
build:ios --ios_signing_cert_name=-
```

Or configure your Apple Developer certificate in Xcode.

### Issue: MapLibre Dependency Not Found

**Error**: `Cannot find MapLibre framework`

**Solution**: Ensure MapLibre is configured in your Bazel workspace. Check `MODULE.bazel` or `WORKSPACE` for MapLibre dependency.

### Issue: Build Takes Too Long

**Solution**: Use local caching and incremental builds:
```bash
# Clean if necessary
bazel clean

# Build with local disk cache
bazel build //apps/omnitak_mobile_ios:OmniTAKMobile-Simulator \
    --config=ios_sim_debug \
    --disk_cache=~/.bazel_cache
```

## Next Steps

After successfully building and running:

1. **Configure Your TAK Server**
   - Update connection settings in `ViewController.swift`
   - Test with your actual TAK server
   - Import TLS certificates if needed

2. **Customize the UI**
   - Modify `ViewController.swift` for your use case
   - Add more map features (layers, markers, etc.)
   - Integrate with Valdi for TypeScript UI

3. **Add Advanced Features**
   - Implement marker management
   - Add CoT message parsing and display
   - Integrate background location tracking
   - Add settings/preferences

4. **Deploy to Device**
   - Configure code signing
   - Build for device
   - Test on physical iPhone/iPad
   - Prepare for TestFlight/App Store

5. **Integrate with Valdi**
   - Set up Valdi framework
   - Use TypeScript for UI logic
   - Connect native modules
   - Build hybrid app

## Documentation

- **[IOS_BUILD_GUIDE.md](IOS_BUILD_GUIDE.md)** - Comprehensive build documentation
- **[README.md](README.md)** - Project overview and usage
- **[Build Scripts](../../scripts/)** - Automated build tools
- **[OmniTAK Mobile Docs](../../modules/omnitak_mobile/)** - Module documentation

## Support

For issues or questions:

1. Check this setup summary
2. Review [IOS_BUILD_GUIDE.md](IOS_BUILD_GUIDE.md)
3. Check console logs for errors
4. Review Bazel build output
5. Open an issue on the project repository

## Success Criteria

You'll know everything is working when:

-  `./scripts/run_ios_simulator.sh` launches the app successfully
-  App displays the MapLibre map
-  Console shows "OmniTAK v0.1.0" or similar
-  Tests pass with `./scripts/test_ios.sh`
-  App can connect to TAK server (when configured)
-  CoT messages can be sent and received

## Quick Reference Card

```bash
# Most common commands:

# Build and run
./scripts/run_ios_simulator.sh

# Build only
./scripts/build_ios.sh simulator debug

# Run tests
./scripts/test_ios.sh

# Clean build
bazel clean --expunge
./scripts/build_ios.sh simulator debug

# View logs
xcrun simctl spawn booted log stream \
    --predicate 'processImagePath contains "OmniTAK"'
```

---

**Created**: 2024-11-08
**Status**: Ready for testing
**Platform**: iOS 14.0+
**Architecture**: arm64, x86_64
**Build System**: Bazel 6.0+
