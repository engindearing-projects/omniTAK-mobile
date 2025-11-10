# OmniTAK Mobile

Cross-platform TAK (Team Awareness Kit) client built with Valdi framework for native iOS and Android performance.

![iOS Working with Taky Server](../../docs/screenshots/ios-working-taky-connection.png)
*iOS app successfully connecting to Taky server and transmitting CoT messages*

## Status

🚀 **iOS**: Fully functional - connecting to TAK servers, sending/receiving CoT messages
🚧 **Android**: In development - Gradle build complete, networking implementation in progress

## Overview

OmniTAK Mobile is a modern, high-performance situational awareness application that provides full interoperability with TAK servers, ATAK, WinTAK, and iTAK devices. Built using Snap's Valdi framework, it delivers true native performance without sacrificing developer velocity.

## Features

- **Real-time CoT Message Handling**: Send and receive Cursor on Target messages in XML and Protobuf formats
- **Multi-Server Support**: Connect to multiple TAK servers simultaneously via omni-TAK backend
- **Certificate Management**: Secure TLS connections with automatic certificate provisioning
- **Interactive Mapping**: High-performance map rendering with MapLibre GL Native
- **MIL-STD-2525 Compliance**: Full support for military symbology and affiliation codes
- **Offline Capabilities**: Work without internet using cached map tiles and local data
- **Cross-Platform**: Single codebase compiles to native iOS and Android apps

## Architecture

```
┌─────────────────────────────────────────┐
│         TypeScript (Valdi)              │
│  ┌────────────┐  ┌──────────────────┐   │
│  │    UI      │  │   Services       │   │
│  │ Components │  │  - TakService    │   │
│  │            │  │  - CotParser     │   │
│  └────────────┘  └──────────────────┘   │
└────────────┬────────────────┬───────────┘
             │                │
    ┌────────▼───────┐   ┌────▼──────────┐
    │  MapLibre GL   │   │   omni-TAK    │
    │    Native      │   │   Rust FFI    │
    │  (custom-view) │   │               │
    └────────────────┘   └───────┬───────┘
                                 │
                         ┌───────▼───────┐
                         │  omni-TAK     │
                         │    Server     │
                         │  (Rust API)   │
                         └───────────────┘
```

## Project Structure

```
omnitak_mobile/
├── src/
│   ├── index.ts                    # Module entry point
│   └── valdi/omnitak/
│       ├── App.tsx                 # Main application component
│       ├── screens/
│       │   └── MapScreen.tsx       # Main map view
│       ├── components/             # Reusable UI components
│       └── services/
│           ├── TakService.ts       # FFI bridge to Rust
│           └── CotParser.ts        # CoT message handling
├── res/                            # Resources (images, icons)
├── BUILD.bazel                     # Bazel build configuration
├── module.yaml                     # Valdi module configuration
└── tsconfig.json                   # TypeScript configuration
```

## Building

### Prerequisites

- macOS (for iOS builds)
- Xcode 15+ (for iOS)
- Android Studio with NDK (for Android)
- Bazel 7+
- Rust toolchain with mobile targets

### iOS Build

**Option 1: Xcode (Recommended for Development)**

```bash
cd /Users/iesouskurios/Downloads/omni-BASE/apps/omnitak_ios_test

# Build and run on simulator
xcodebuild -scheme OmniTAKTest -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Or open in Xcode
open OmniTAKTest.xcodeproj
```

**Option 2: Bazel (Future - when Valdi integration is complete)**

```bash
cd /Users/iesouskurios/Downloads/omni-BASE

# Build for iOS
bazel build //modules/omnitak_mobile:omnitak_mobile --ios_output_target=release

# Run on simulator
bazel run //apps/ios:OmniTAK --ios_sdk=iphonesimulator
```

### Android Build

```bash
# Build for Android
bazel build //modules/omnitak_mobile:omnitak_mobile --android_output_target=release

# Build APK
bazel build //apps/android:OmniTAK
```

## Development

### Hot Reload

Valdi supports instant hot reload for rapid development:

```bash
# Start dev server
npm run dev

# Changes to .ts/.tsx files reload instantly
```

### Debugging

Use VSCode with Valdi's Hermes debugger integration:

1. Set breakpoints in TypeScript code
2. Launch app in debug mode
3. Debugger attaches automatically

## Distribution & Testing

### iOS - Creating a Testable Build

To create an iOS build that can be installed on physical devices for testing:

#### Option 1: TestFlight (Requires Apple Developer Account - $99/year)

1. Archive the app in Xcode:
   ```bash
   cd /Users/iesouskurios/Downloads/omni-BASE/apps/omnitak_ios_test
   xcodebuild -scheme OmniTAKTest -archivePath ./build/OmniTAK.xcarchive archive
   ```

2. Export for TestFlight:
   ```bash
   xcodebuild -exportArchive -archivePath ./build/OmniTAK.xcarchive \
     -exportPath ./build/TestFlight \
     -exportOptionsPlist ExportOptions.plist
   ```

3. Upload to TestFlight:
   ```bash
   xcrun altool --upload-app --type ios --file ./build/TestFlight/OmniTAKTest.ipa \
     --username "your-apple-id@email.com" --password "app-specific-password"
   ```

4. Share TestFlight link with testers

#### Option 2: Development Build (Free - Requires Xcode)

1. Connect your iPhone via USB
2. Open the project in Xcode:
   ```bash
   open OmniTAKTest.xcodeproj
   ```
3. Select your device from the device menu
4. Click Run (⌘R)
5. Trust the developer certificate on your device (Settings > General > VPN & Device Management)

**Note**: Development builds expire after 7 days (free account) or 1 year (paid account)

#### Option 3: Ad-Hoc Distribution (Requires Apple Developer Account)

1. Get device UDIDs from testers
2. Register devices in Apple Developer Portal
3. Create an Ad-Hoc provisioning profile
4. Build and export IPA with Ad-Hoc profile
5. Distribute IPA file via:
   - [Diawi](https://www.diawi.com/) - Simple drag & drop hosting
   - Email/Cloud storage - Users install via Apple Configurator or Xcode
   - [AltStore](https://altstore.io/) - Sideloading without USB (requires setup)

#### Option 4: Sideloading (Free - Advanced Users)

Users can sideload the IPA using:

**AltStore** (Easiest):
1. Install [AltStore](https://altstore.io/)
2. Download the `.ipa` file
3. Open in AltStore and install
4. Refresh weekly (free account limitation)

**Sideloadly**:
1. Install [Sideloadly](https://sideloadly.io/)
2. Connect iPhone to Mac
3. Load the `.ipa` file
4. Sign with your Apple ID

**Xcode** (Direct):
```bash
# Export IPA for development
xcodebuild -scheme OmniTAKTest \
  -archivePath ./build/OmniTAK.xcarchive \
  -exportPath ./build/Development \
  -exportOptionsPlist ExportOptions-Development.plist \
  -allowProvisioningUpdates

# Install on connected device
ios-deploy --bundle ./build/Development/OmniTAKTest.app
```

### Android - Creating a Testable Build

Android builds can be distributed more easily:

```bash
cd /Users/iesouskurios/Downloads/omnitak-android-gradle

# Build debug APK (can be installed on any device)
./gradlew assembleDebug

# APK location:
# app/build/outputs/apk/debug/app-debug.apk
```

Users can install by:
1. Download the APK file
2. Enable "Install from Unknown Sources" in Settings
3. Tap the APK to install

For production releases:
- Use Google Play Console
- Or distribute via Firebase App Distribution
- Or host APK directly (requires signing key management)

### CI/CD with GitLab

For automated builds, you can set up GitLab CI to build and distribute apps automatically. See the [GitLab Mobile DevOps guide](https://docs.gitlab.com/ci/mobile_devops/) for iOS and Android pipelines.

**Example `.gitlab-ci.yml` for iOS:**

```yaml
ios_build:
  stage: build
  tags:
    - macos
  script:
    - cd apps/omnitak_ios_test
    - xcodebuild -scheme OmniTAKTest -archivePath OmniTAK.xcarchive archive
    - xcodebuild -exportArchive -archivePath OmniTAK.xcarchive -exportPath ./ipa -exportOptionsPlist ExportOptions.plist
  artifacts:
    paths:
      - apps/omnitak_ios_test/ipa/OmniTAKTest.ipa
    expire_in: 30 days
```

## Dependencies

- **Valdi Core**: UI framework and component system
- **Valdi TSX**: Native template elements
- **omni-TAK Rust SDK**: TAK server connectivity and CoT processing
- **MapLibre GL Native**: Cross-platform map rendering
- **Platform Specific**:
  - iOS: Swift bindings, Keychain integration
  - Android: JNI bindings, Android Keystore

## Integration with omni-TAK

OmniTAK Mobile integrates with the omni-TAK Rust server for:

1. **Connection Aggregation**: Connect to multiple TAK servers through single API
2. **Certificate Management**: Auto-provision certificates from server
3. **Message Federation**: Centralized CoT message routing
4. **Metrics and Monitoring**: Real-time connection health and performance stats

### FFI Bridge

The Rust FFI bridge (`omnitak-mobile` crate) exposes C-compatible functions:

```rust
#[no_mangle]
pub extern "C" fn omnitak_connect(
    host: *const c_char,
    port: u16,
    cert_pem: *const c_char
) -> *mut Connection
```

TypeScript bindings are generated using Valdi's polyglot annotations:

```typescript
/**
 * @PolyglotModule
 * @ExportModel({
 *   ios: 'OmniTAKNative',
 *   android: 'com.engindearing.omnitak.native.OmniTAKNative'
 * })
 */
export interface OmniTAKNativeModule {
  connect(config: ServerConfig): Promise<number | null>;
  sendCot(connectionId: number, cotXml: string): Promise<boolean>;
}
```

## Roadmap

### Phase 1: Foundation (Complete)
- [x] Valdi project setup
- [x] TypeScript application skeleton
- [x] CoT parser and data structures
- [x] TakService FFI interface design

### Phase 2: Core Functionality (✅ iOS Complete, 🚧 Android In Progress)
- [x] **iOS**: Swift Network framework direct TCP/UDP/TLS sender (bypasses incomplete Rust FFI)
- [x] **iOS**: MapLibre integration complete
- [x] **iOS**: Basic map rendering working
- [x] **iOS**: CoT marker display with full MIL-STD-2525 symbology
- [x] **iOS**: Position history tracking and breadcrumb trails
- [ ] **Android**: Native network implementation
- [ ] **Android**: MapLibre integration
- [x] Rust FFI bridge architecture (implementation pending completion)

### Phase 3: TAK Integration (✅ iOS Working)
- [x] **iOS**: Server connection management (TCP, UDP, TLS support)
- [x] **iOS**: Real-time CoT message transmission and reception
- [x] **iOS**: Tested with Taky server
- [ ] Certificate auto-provisioning
- [ ] Multi-server support

### Phase 4: Advanced Features
- [ ] Offline maps
- [ ] Drawing tools
- [ ] Geofencing
- [ ] File attachments
- [ ] Video feeds

### Phase 5: Polish & Release
- [ ] Performance optimization
- [ ] Field testing
- [ ] App Store submission
- [ ] Documentation

## Contributing

This project is part of the omni-TAK ecosystem. See the main [omni-TAK repository](https://github.com/engindearing-projects/omni-TAK) for contribution guidelines.

## License

MIT License - See LICENSE file for details

## Related Projects

- [omni-TAK](https://github.com/engindearing-projects/omni-TAK) - Rust TAK server aggregator
- [omni-COT](https://github.com/engindearing-projects/omni-COT) - ATAK plugin for affiliation management
- [Valdi](https://github.com/Snapchat/valdi) - Cross-platform UI framework
