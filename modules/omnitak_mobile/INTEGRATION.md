# OmniTAK Mobile - Valdi Polyglot Integration Guide

This document explains how the OmniTAK Mobile native library is integrated into the Valdi framework using the polyglot binding system.

## Architecture Overview

The integration follows a three-layer architecture:

```
┌─────────────────────────────────────────┐
│  TypeScript Layer (TakService.ts)      │
│  - High-level API                       │
│  - Connection management                │
│  - Event handling                       │
└────────────┬────────────────────────────┘
             │ Valdi Polyglot Bridge
             ├─────────────┬──────────────┐
             │             │              │
┌────────────▼────┐  ┌────▼─────────┐    │
│  iOS Swift      │  │  Android     │    │
│  Bridge         │  │  Kotlin/JNI  │    │
│                 │  │  Bridge      │    │
└────────┬────────┘  └──────┬───────┘    │
         │                  │             │
         │ C FFI            │ JNI         │
         ├──────────────────┴─────────────┘
         │
┌────────▼──────────────────────────────┐
│  Rust Core (omnitak-mobile)          │
│  - TAK protocol implementation        │
│  - Network I/O                        │
│  - CoT parsing                        │
└───────────────────────────────────────┘
```

## File Structure

```
modules/omnitak_mobile/
├── src/
│   ├── index.ts                          # Module entry point
│   └── valdi/
│       └── omnitak/
│           └── services/
│               ├── TakService.ts         # TypeScript API layer
│               └── CotParser.ts          # CoT parsing utilities
├── ios/
│   └── native/
│       ├── OmniTAKNativeBridge.swift    # iOS Swift bridge
│       ├── omnitak_mobile.h             # C FFI header
│       └── OmniTAKMobile.xcframework/   # Rust library (iOS)
└── android/
    └── native/
        ├── OmniTAKNativeBridge.kt       # Android Kotlin bridge
        ├── omnitak_jni.cpp              # JNI implementation
        ├── CMakeLists.txt               # Native build config
        ├── include/
        │   └── omnitak_mobile.h         # C FFI header
        └── lib/                          # Rust libraries (Android)
            ├── arm64-v8a/
            │   └── libomnitak_mobile.a
            ├── armeabi-v7a/
            │   └── libomnitak_mobile.a
            ├── x86_64/
            │   └── libomnitak_mobile.a
            └── x86/
                └── libomnitak_mobile.a
```

## Component Details

### TypeScript Layer (`TakService.ts`)

The TypeScript layer provides a high-level, type-safe API for the application:

```typescript
// Define the native module interface
export interface OmniTAKNativeModule {
  connect(config: ServerConfig): Promise<number | null>;
  disconnect(connectionId: number): Promise<void>;
  sendCot(connectionId: number, cotXml: string): Promise<boolean>;
  registerCotCallback(connectionId: number, callback: (cotXml: string) => void): void;
  getConnectionStatus(connectionId: number): Promise<ConnectionInfo | null>;
  importCertificate(certPem: string, keyPem: string, caPem?: string): Promise<string | null>;
}

// High-level service wrapper
export class TakService {
  // Manages connections, callbacks, and provides user-friendly API
}
```

**Key Features:**
- Promise-based async API
- Type-safe configuration objects
- Event-based CoT message handling
- Connection lifecycle management
- Certificate management

### iOS Swift Bridge (`OmniTAKNativeBridge.swift`)

The Swift bridge wraps the C FFI from the Rust XCFramework:

**Key Features:**
- Singleton pattern for callback management
- Thread-safe callback storage
- C string conversion utilities
- Async/await support via completion handlers
- Certificate bundle storage
- Proper memory management

**Callback Flow:**
```
Rust Thread → C Callback → Swift Callback → Main Queue → TypeScript
```

**Thread Safety:**
- All callbacks are dispatched to the main queue
- Certificate storage uses thread-safe dictionary
- Initialization uses NSLock

### Android Kotlin/JNI Bridge

The Android bridge consists of two components:

#### 1. Kotlin Bridge (`OmniTAKNativeBridge.kt`)

**Key Features:**
- Singleton pattern with thread safety
- Coroutine-based async API
- JNI native method declarations
- Certificate storage using ConcurrentHashMap
- Callback management with main thread dispatch

#### 2. JNI Layer (`omnitak_jni.cpp`)

**Key Features:**
- String conversion between JNI and C
- Callback bridging from C → JNI → Kotlin
- Thread attachment for callbacks from native threads
- Global reference management
- Comprehensive error logging

**Callback Flow:**
```
Rust Thread → C Callback → JNI Attach → Kotlin Method → Main Dispatcher → TypeScript
```

**Thread Safety:**
- Global callback map protected by mutex
- Automatic JVM thread attachment/detachment
- Global references for callback objects

## Build Configuration

### iOS Build

The iOS integration uses an XCFramework that contains the compiled Rust library for all iOS architectures:

**XCFramework Structure:**
```
OmniTAKMobile.xcframework/
├── ios-arm64/                   # iPhone/iPad (device)
│   └── libomnitak_mobile.a
├── ios-arm64_x86_64-simulator/  # Simulator (M1 + Intel)
│   └── libomnitak_mobile.a
└── Info.plist
```

**Xcode Integration:**
1. Add `OmniTAKMobile.xcframework` to project frameworks
2. Add `OmniTAKNativeBridge.swift` to project sources
3. Set "Always Embed Swift Standard Libraries" to YES
4. Ensure framework is embedded in app bundle

**Build Settings:**
- Deployment Target: iOS 13.0+
- Swift Version: 5.0+
- Embed Framework: Yes

### Android Build

The Android integration uses CMake to build the JNI bridge and link with Rust static libraries:

**Directory Structure:**
```
android/native/
├── CMakeLists.txt           # Build configuration
├── omnitak_jni.cpp         # JNI source
├── include/
│   └── omnitak_mobile.h    # FFI header
└── lib/
    └── ${ANDROID_ABI}/     # Per-architecture libs
        └── libomnitak_mobile.a
```

**Gradle Integration:**

Add to `app/build.gradle`:

```gradle
android {
    defaultConfig {
        ndk {
            abiFilters 'arm64-v8a', 'armeabi-v7a', 'x86_64', 'x86'
        }
    }

    externalNativeBuild {
        cmake {
            path "../../modules/omnitak_mobile/android/native/CMakeLists.txt"
            version "3.18.1"
        }
    }
}
```

**Build Process:**
1. CMake builds `omnitak_jni.cpp` into `libomnitak_mobile.so`
2. Links with pre-built Rust static library
3. Outputs shared library for each ABI
4. Library loaded via `System.loadLibrary("omnitak_mobile")`

## Building Native Libraries

### Building Rust Library for iOS

From the `omni-TAK` directory:

```bash
# Install iOS targets
rustup target add aarch64-apple-ios
rustup target add aarch64-apple-ios-sim
rustup target add x86_64-apple-ios

# Build for all iOS architectures
cd crates/omnitak-mobile
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim
cargo build --release --target x86_64-apple-ios

# Create XCFramework
xcodebuild -create-xcframework \
  -library target/aarch64-apple-ios/release/libomnitak_mobile.a \
  -library target/aarch64-apple-ios-sim/release/libomnitak_mobile.a \
  -library target/x86_64-apple-ios/release/libomnitak_mobile.a \
  -output target/OmniTAKMobile.xcframework

# Copy to Valdi module
cp -R target/OmniTAKMobile.xcframework \
  ../omni-BASE/modules/omnitak_mobile/ios/native/
```

### Building Rust Library for Android

From the `omni-TAK` directory:

```bash
# Install Android targets
rustup target add aarch64-linux-android
rustup target add armv7-linux-androideabi
rustup target add x86_64-linux-android
rustup target add i686-linux-android

# Set up Android NDK environment
export ANDROID_NDK_HOME=/path/to/android-ndk

# Build for all Android ABIs
cd crates/omnitak-mobile

cargo build --release --target aarch64-linux-android
cargo build --release --target armv7-linux-androideabi
cargo build --release --target x86_64-linux-android
cargo build --release --target i686-linux-android

# Copy to Valdi module
mkdir -p ../../omni-BASE/modules/omnitak_mobile/android/native/lib

cp target/aarch64-linux-android/release/libomnitak_mobile.a \
   ../../omni-BASE/modules/omnitak_mobile/android/native/lib/arm64-v8a/

cp target/armv7-linux-androideabi/release/libomnitak_mobile.a \
   ../../omni-BASE/modules/omnitak_mobile/android/native/lib/armeabi-v7a/

cp target/x86_64-linux-android/release/libomnitak_mobile.a \
   ../../omni-BASE/modules/omnitak_mobile/android/native/lib/x86_64/

cp target/i686-linux-android/release/libomnitak_mobile.a \
   ../../omni-BASE/modules/omnitak_mobile/android/native/lib/x86/
```

## Callback System

### Callback Architecture

The callback system bridges from Rust background threads to TypeScript:

```
┌─────────────────────────────────────────────┐
│ Rust Thread (Background)                    │
│  - Receives CoT from network                │
│  - Calls C callback function                │
└────────────┬────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────┐
│ Platform Bridge (Swift/JNI)                 │
│  - Receives C callback                      │
│  - Attaches to platform thread (if needed)  │
│  - Dispatches to main queue/dispatcher      │
└────────────┬────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────┐
│ TypeScript (Main Thread)                    │
│  - Receives callback via Valdi bridge       │
│  - Invokes user-registered handlers         │
└─────────────────────────────────────────────┘
```

### iOS Callback Implementation

```swift
// C callback function (runs on Rust thread)
let cCallback: @convention(c) (UnsafeMutableRawPointer?, UInt64, UnsafePointer<CChar>) -> Void = {
    userDataPtr, connId, xmlPtr in

    let xml = String(cString: xmlPtr)

    // Dispatch to main queue
    DispatchQueue.main.async {
        // Call Swift callback
        bridge.callbacks[connId]?(xml)
    }
}

// Register with Rust
omnitak_register_callback(connectionId, cCallback, userDataPtr)
```

### Android Callback Implementation

```cpp
// C callback function (runs on Rust thread)
static void cot_callback_bridge(void* user_data, uint64_t connection_id, const char* cot_xml) {
    // Attach to JVM if needed
    JNIEnv* env = attachToJVM();

    // Call Kotlin method
    env->CallVoidMethod(bridgeInstance, onCotReceivedMethod,
                        (jlong)connection_id,
                        env->NewStringUTF(cot_xml));

    // Detach if we attached
    detachFromJVM();
}
```

```kotlin
// Kotlin callback handler (called from JNI)
private fun onCotReceived(connectionId: Long, cotXml: String) {
    // Dispatch to main thread
    scope.launch(Dispatchers.Main) {
        callbacks[connectionId]?.invoke(cotXml)
    }
}
```

## Memory Management

### iOS Memory Management

**C Strings:**
- Swift strings converted to C strings using `withCString`
- C strings from Rust converted using `String(cString:)`
- No manual deallocation needed for static strings from Rust

**Callbacks:**
- Swift closures stored in dictionary with connection ID key
- Removed on disconnect
- Bridge singleton manages lifetime

**Certificates:**
- Stored in Swift dictionary
- Strings copied, not referenced
- Cleaned up with certificate ID

### Android Memory Management

**JNI References:**
- Global references created for callback objects
- Deleted when callback unregistered
- Map stores global refs with mutex protection

**Strings:**
- JNI strings converted to C++ std::string
- C strings converted to JNI strings
- Proper UTF release with `ReleaseStringUTFChars`

**Thread Lifecycle:**
- Threads attached to JVM when needed
- Detached after callback completes
- JavaVM pointer cached globally

## Error Handling

### Error Codes

From C FFI (`omnitak_mobile.h`):
```c
#define OMNITAK_SUCCESS  0
#define OMNITAK_ERROR   -1
```

### TypeScript Error Handling

```typescript
async connect(config: ServerConfig): Promise<number | null> {
  try {
    const connectionId = await this.native.connect(config);
    if (connectionId === null) {
      console.error('Failed to connect to TAK server');
      return null;
    }
    return connectionId;
  } catch (error) {
    console.error('Connect exception:', error);
    return null;
  }
}
```

### iOS Error Handling

```swift
let result = omnitak_disconnect(connectionId)
if result == 0 {
    print("[OmniTAK] Disconnected successfully")
} else {
    print("[OmniTAK] Disconnect failed: \(result)")
}
```

### Android Error Handling

```kotlin
val result = nativeDisconnect(connectionId)
if (result == 0) {
    Log.i(TAG, "Disconnected successfully")
} else {
    Log.e(TAG, "Disconnect failed: $result")
}
```

## Testing

### Unit Tests

**TypeScript:**
```typescript
// Mock the native module
const mockNative: OmniTAKNativeModule = {
  connect: jest.fn(),
  disconnect: jest.fn(),
  // ... other methods
};

const service = new TakService();
service.initialize(mockNative);
```

**iOS:**
```swift
// Create test instance
let bridge = OmniTAKNativeBridge()

// Test connection
bridge.connect(config: testConfig) { connectionId in
    XCTAssertNotNil(connectionId)
}
```

**Android:**
```kotlin
// Test with instrumentation
@Test
fun testConnect() = runBlocking {
    val bridge = OmniTAKNativeBridge.getInstance()
    val config = ServerConfig(
        host = "localhost",
        port = 8087,
        protocol = "tcp",
        useTls = false
    )
    val connectionId = bridge.connect(config)
    assertNotNull(connectionId)
}
```

### Integration Tests

1. **Connection Test:**
   - Connect to TAK server
   - Verify connection ID returned
   - Check status shows connected

2. **Send/Receive Test:**
   - Send CoT message
   - Register callback
   - Verify callback receives messages

3. **Certificate Test:**
   - Import certificate bundle
   - Connect with TLS
   - Verify secure connection

## Troubleshooting

### iOS Issues

**XCFramework not found:**
```
Error: Framework not found OmniTAKMobile
```
**Solution:** Ensure XCFramework is in `ios/native/` and added to Xcode project

**Swift bridge not compiled:**
```
Error: Use of unresolved identifier 'OmniTAKNativeBridge'
```
**Solution:** Add `OmniTAKNativeBridge.swift` to Xcode project sources

**Callback not firing:**
- Check that callback is registered before messages arrive
- Verify main queue is not blocked
- Check Rust library is receiving messages

### Android Issues

**Native library not loaded:**
```
java.lang.UnsatisfiedLinkError: couldn't find DSO to load: libomnitak_mobile.so
```
**Solution:**
- Verify CMakeLists.txt path in build.gradle
- Check Rust libraries are in `lib/${ABI}/` directories
- Rebuild native code

**JNI method not found:**
```
java.lang.UnsatisfiedLinkError: No implementation found for int nativeInit()
```
**Solution:**
- Check JNI function signatures match Kotlin declarations
- Verify package name in JNI function names
- Clean and rebuild

**Callback crashes:**
- Check thread attachment to JVM
- Verify global references are valid
- Check for exceptions in JNI

### General Issues

**Callback thread safety:**
- Always dispatch callbacks to main thread/queue
- Use thread-safe collections for callback storage
- Protect shared state with locks/mutexes

**Memory leaks:**
- Verify callbacks are unregistered on disconnect
- Check global references are deleted (Android)
- Monitor memory usage with profilers

**Performance:**
- Avoid blocking main thread in callbacks
- Process CoT messages on background threads
- Use connection pooling for multiple servers

## Best Practices

### TypeScript

1. Always check for null returns from native methods
2. Provide default values in configuration
3. Use TypeScript's strict mode
4. Document callback behavior clearly

### iOS

1. Use weak self in callbacks to avoid retain cycles
2. Always dispatch to main queue for UI updates
3. Handle nil cases for optional parameters
4. Use proper error logging

### Android

1. Use coroutines for async operations
2. Properly handle lifecycle events
3. Clean up resources in onDestroy
4. Use proper logging levels

## Performance Considerations

### Connection Pooling

For multiple TAK servers:
```typescript
const connections = await Promise.all([
  takService.connect(server1Config),
  takService.connect(server2Config),
  takService.connect(server3Config)
]);
```

### Message Batching

For high-frequency CoT updates:
```typescript
const batch: string[] = [];

onCotReceived((xml) => {
  batch.push(xml);

  if (batch.length >= 100) {
    processBatch(batch.splice(0));
  }
});
```

### Thread Management

- Native operations run on background threads
- Callbacks dispatched to main thread
- Heavy processing should be offloaded

## Security Considerations

### Certificate Handling

1. Never log certificate contents
2. Store certificates securely (iOS Keychain, Android KeyStore)
3. Validate certificate chains
4. Use TLS 1.2+ only

### Input Validation

1. Validate all user inputs before passing to native layer
2. Sanitize CoT XML before sending
3. Limit message sizes
4. Rate-limit connections

## Version Compatibility

| Component | Minimum Version |
|-----------|----------------|
| iOS | 13.0 |
| Android | API 21 (Lollipop) |
| Swift | 5.0 |
| Kotlin | 1.7 |
| CMake | 3.18.1 |
| NDK | r21+ |
| Rust | 1.70+ |

## Resources

- [Valdi Documentation](https://snap.com/valdi)
- [OmniTAK Rust Crate](https://github.com/engindearing-projects/omni-TAK)
- [TAK Protocol Specification](https://tak.gov)
- [CoT XML Schema](https://tak.gov/cot)

## Support

For issues or questions:
1. Check this integration guide
2. Review troubleshooting section
3. Check logs (Xcode Console / Android Logcat)
4. File issue with reproduction steps
