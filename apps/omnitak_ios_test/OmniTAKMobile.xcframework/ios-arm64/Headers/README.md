# omnitak-mobile

Cross-platform FFI bridge for iOS and Android integration with omni-TAK.

## Overview

`omnitak-mobile` provides a C-compatible FFI interface to the omni-TAK Rust libraries, enabling native iOS and Android applications to connect to TAK servers and handle CoT messages.

## Features

- **Cross-platform FFI**: C-compatible interface for iOS (Swift/Objective-C) and Android (JNI/Kotlin)
- **TAK Server Connectivity**: TCP, UDP, TLS, and WebSocket protocols
- **CoT Message Handling**: Send and receive Cursor on Target messages
- **Thread-safe**: Built on Tokio async runtime with safe concurrency primitives
- **Minimal Dependencies**: Optimized for mobile with small binary size

## Building

### Prerequisites

- Rust 1.70+ with iOS and Android targets
- Xcode (for iOS)
- Android NDK (for Android)
- cargo-ndk (install with `cargo install cargo-ndk`)

### iOS

```bash
./build_ios.sh
```

This creates an XCFramework at `../../target/OmniTAKMobile.xcframework` containing:
- `aarch64-apple-ios` - iOS devices (iPhone/iPad)
- Universal simulator library (ARM64 + x86_64)

### Android

```bash
export ANDROID_NDK_HOME=~/Library/Android/sdk/ndk/27.0.12077973
./build_android.sh
```

This creates JNI libraries at `../../target/android-jniLibs/` for:
- `arm64-v8a` - Modern ARM devices
- `armeabi-v7a` - Older ARM devices
- `x86_64` - Emulators
- `x86` - Older emulators

## API Reference

See [omnitak_mobile.h](./omnitak_mobile.h) for the complete C API.

### Quick Start (iOS - Swift)

```swift
import Foundation

// Initialize library
omnitak_init()

// Connect to TAK server
let host = "tak.example.com"
let connectionId = omnitak_connect(
    host,
    8089,
    OMNITAK_PROTOCOL_TLS,
    1, // use TLS
    certPem,
    keyPem,
    caPem
)

// Register callback for incoming CoT
func cotCallback(userData: UnsafeMutableRawPointer?,
                 connectionId: UInt64,
                 cotXml: UnsafePointer<CChar>?) {
    guard let xmlPtr = cotXml else { return }
    let xml = String(cString: xmlPtr)
    print("Received CoT: \\(xml)")
}

omnitak_register_callback(connectionId, cotCallback, nil)

// Send CoT message
let cot = """
<?xml version="1.0"?>
<event version="2.0" uid="my-uid" type="a-f-G-E-S" ...>
  <point lat="38.0" lon="-77.0" hae="0" ce="10" le="10"/>
</event>
"""
omnitak_send_cot(connectionId, cot)

// Get status
var status = ConnectionStatus()
omnitak_get_status(connectionId, &status)
print("Messages sent: \\(status.messages_sent)")

// Cleanup
omnitak_disconnect(connectionId)
omnitak_shutdown()
```

### Quick Start (Android - Kotlin)

```kotlin
class OmniTAKNative {
    companion object {
        init {
            System.loadLibrary("omnitak_mobile")
        }
    }

    external fun omnitak_init(): Int
    external fun omnitak_connect(
        host: String,
        port: Short,
        protocol: Int,
        useTls: Int,
        certPem: String?,
        keyPem: String?,
        caPem: String?
    ): Long
    external fun omnitak_send_cot(connectionId: Long, cotXml: String): Int
    external fun omnitak_disconnect(connectionId: Long): Int
    external fun omnitak_shutdown()
}

// Usage
val native = OmniTAKNative()
native.omnitak_init()

val connectionId = native.omnitak_connect(
    "tak.example.com",
    8089,
    2, // TLS
    1, // use TLS
    certPem,
    keyPem,
    caPem
)

native.omnitak_send_cot(connectionId, cotXml)
native.omnitak_disconnect(connectionId)
native.omnitak_shutdown()
```

## Integration with Valdi

The TypeScript interface in `omni-BASE/modules/omnitak_mobile/` uses Valdi's polyglot module system to call these FFI functions:

```typescript
// TypeScript (Valdi)
import { takService } from './services/TakService';

const connectionId = await takService.connect({
  host: 'tak.example.com',
  port: 8089,
  protocol: 'tls',
  useTls: true,
  certificateId: 'my-cert',
  reconnect: true,
  reconnectDelayMs: 5000,
});

takService.onCotReceived(connectionId, (xml) => {
  console.log('Received CoT:', xml);
});

await takService.sendCot(connectionId, cotXml);
```

Valdi automatically generates the platform-specific bridge code:
- iOS: Swift wrapper calling C functions
- Android: JNI wrapper calling native library

## Architecture

```
┌─────────────────────────────────────────┐
│      Valdi TypeScript Application       │
│                                         │
│  TakService.ts  →  OmniTAKNativeModule  │
└─────────────────┬───────────────────────┘
                  │
         ┌────────▼────────┐
         │  Valdi Polyglot │
         │    Generator    │
         └────┬──────┬─────┘
              │      │
     ┌────────▼──┐ ┌▼─────────┐
     │iOS Bridge │ │Android   │
     │  (Swift)  │ │Bridge    │
     │           │ │(JNI/Kt)  │
     └─────┬─────┘ └──┬───────┘
           │          │
     ┌─────▼──────────▼───────┐
     │   libomnitak_mobile    │
     │      (Rust FFI)        │
     │                        │
     │  ┌──────────────────┐  │
     │  │  omnitak-client  │  │
     │  │  omnitak-cot     │  │
     │  │  omnitak-cert    │  │
     │  └──────────────────┘  │
     └────────────────────────┘
```

## Thread Safety

All FFI functions are thread-safe. The library uses:
- `DashMap` for concurrent connection storage
- `Mutex` for callback management
- Tokio runtime for async operations

Callbacks are invoked from background threads. Ensure proper synchronization in your callback implementations.

## Memory Management

- **Strings**: All strings must be null-terminated C strings
- **Ownership**: The library does NOT take ownership of input strings
- **Callbacks**: `user_data` pointer must remain valid until callback is unregistered
- **Cleanup**: Call `omnitak_shutdown()` to free all resources

## Error Handling

Functions return:
- `0` on success, `-1` on error (for `int32_t` returns)
- `0` on error, `connection_id > 0` on success (for `uint64_t` returns)
- Check `ConnectionStatus.last_error_code` for detailed errors

## Performance

- **Binary Size**: ~2MB per architecture (stripped, with LTO)
- **Memory**: ~50KB base + ~100KB per connection
- **Latency**: <1ms for send, callback invoked within <10ms of receive
- **Throughput**: 10,000+ messages/second

## Testing

```bash
cargo test -p omnitak-mobile
```

## License

MIT OR Apache-2.0 (dual-licensed)

## Related

- [omni-TAK](https://github.com/engindearing-projects/omni-TAK) - Main repository
- [omni-BASE](https://github.com/jfuginay/omni-BASE) - Valdi framework integration
- [omni-COT](https://github.com/engindearing-projects/omni-COT) - Android ATAK plugin
