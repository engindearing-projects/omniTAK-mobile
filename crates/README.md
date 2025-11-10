# OmniTAK Rust Crates

This directory contains the Rust implementation of the OmniTAK mobile FFI bridge.

## Structure

```
crates/
├── Cargo.toml              # Workspace configuration
├── build_ios.sh            # iOS build script
├── omnitak-core/           # Core types and utilities
├── omnitak-cot/            # CoT message parsing/generation
├── omnitak-cert/           # Certificate and TLS handling
├── omnitak-client/         # TAK server client implementation
└── omnitak-mobile/         # FFI bridge for iOS/Android
    ├── src/
    │   ├── lib.rs          # Main FFI interface
    │   ├── connection.rs   # Connection management
    │   ├── callbacks.rs    # Callback utilities
    │   └── error.rs        # Error types
    └── include/
        └── omnitak_mobile.h  # C header file
```

## Crates

### omnitak-core

Core types and utilities used across all crates:
- `Protocol` enum (TCP, UDP, TLS, WebSocket)
- `ConnectionConfig` for connection parameters
- `ConnectionState` enum

### omnitak-cot

Cursor on Target (CoT) message handling:
- `CotMessage` struct for representing CoT events
- `Point` struct for geographic coordinates
- XML parsing and generation
- Support for event types, timestamps, and details

### omnitak-cert

Certificate and TLS configuration:
- `CertBundle` for managing certificates
- TLS client configuration builder
- PEM certificate parsing
- Support for client certificates and CA certs

### omnitak-client

TAK server client implementation:
- `TakClient` for managing connections
- Support for TCP, UDP, and TLS protocols
- Async I/O with tokio
- Callback-based message reception
- Thread-safe connection state management

### omnitak-mobile

FFI bridge for mobile platforms:
- C-compatible interface
- Connection management with global state
- Callback system for receiving CoT messages
- Status reporting
- Thread-safe with parking_lot and dashmap

## Building

### Prerequisites

1. **Rust Toolchain**
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source $HOME/.cargo/env
   ```

2. **iOS Targets** (for iOS builds)
   ```bash
   rustup target add aarch64-apple-ios
   rustup target add aarch64-apple-ios-sim
   rustup target add x86_64-apple-ios
   ```

3. **Android NDK** (for Android builds)
   ```bash
   rustup target add aarch64-linux-android
   rustup target add armv7-linux-androideabi
   rustup target add i686-linux-android
   rustup target add x86_64-linux-android
   ```

### Build for iOS

```bash
cd crates
./build_ios.sh
```

This will:
1. Build for all iOS architectures (arm64 device, arm64 + x86_64 simulator)
2. Create a universal simulator binary
3. Package into an XCFramework
4. Copy to `modules/omnitak_mobile/ios/native/`

### Build for Android

```bash
cd crates/omnitak-mobile
cargo build --release --target aarch64-linux-android
cargo build --release --target armv7-linux-androideabi
cargo build --release --target i686-linux-android
cargo build --release --target x86_64-linux-android
```

Libraries will be in `../../target/<arch>/release/libomnitak_mobile.so`

### Development Build

For faster iteration during development:

```bash
cd crates
cargo build
```

### Testing

Run all tests:

```bash
cd crates
cargo test
```

Run tests for a specific crate:

```bash
cd crates/omnitak-core
cargo test
```

## FFI Interface

The FFI interface is defined in `omnitak-mobile/include/omnitak_mobile.h` and includes:

### Initialization

```c
int32_t omnitak_init(void);
void omnitak_shutdown(void);
```

### Connection Management

```c
uint64_t omnitak_connect(
    const char* host,
    uint16_t port,
    int32_t protocol,
    int32_t use_tls,
    const char* cert_pem,
    const char* key_pem,
    const char* ca_pem
);

int32_t omnitak_disconnect(uint64_t connection_id);
```

### Messaging

```c
int32_t omnitak_send_cot(uint64_t connection_id, const char* cot_xml);

int32_t omnitak_register_callback(
    uint64_t connection_id,
    CotCallback callback,
    void* user_data
);
```

### Status

```c
int32_t omnitak_get_status(
    uint64_t connection_id,
    ConnectionStatus* status_out
);

const char* omnitak_version(void);
```

## Architecture

### Threading Model

- **Main Thread**: FFI calls from Swift/Java
- **Tokio Runtime**: Background thread pool for async I/O
- **Callback Thread**: Background thread invoking user callbacks

All FFI functions are thread-safe and can be called from any thread.

### Memory Management

- **Strings**: Rust owns all string memory
  - Input strings are copied on FFI boundary
  - Output strings are either static or owned by Rust
- **Callbacks**: User data pointer is opaque to Rust
  - User must ensure validity until callback is unregistered
- **Connections**: Automatically cleaned up on disconnect or shutdown

### Error Handling

FFI functions return:
- `0` for success
- `-1` for errors
- `0` for invalid connection ID

Detailed errors are logged via `tracing` and can be retrieved via `omnitak_get_status`.

## Dependencies

Key dependencies:
- **tokio**: Async runtime for I/O
- **rustls**: TLS implementation
- **dashmap**: Concurrent hashmap
- **parking_lot**: Efficient synchronization primitives
- **tracing**: Logging
- **serde**: Serialization

See `Cargo.toml` for complete dependency list.

## Example Usage

See `../modules/omnitak_mobile/ios/native/README.md` for Swift integration examples.

## Troubleshooting

### Build Errors

**Missing target**: Install with `rustup target add <target>`

**Linker errors**: Ensure Xcode Command Line Tools are installed

**TLS errors**: Check certificate format (PEM required)

### Runtime Errors

**Connection fails**: Check network connectivity and firewall settings

**Callback not invoked**: Ensure callback is registered before messages arrive

**Memory issues**: Verify callback user_data lifetime

## Performance

### Binary Size

- iOS (device): ~2-3 MB per architecture
- iOS (simulator): ~4-6 MB (universal)
- Android: ~2-3 MB per architecture

Optimizations enabled in release builds:
- Size optimization (`opt-level = "z"`)
- Link-time optimization (LTO)
- Symbol stripping
- Panic abort

### Runtime Performance

- Zero-copy message forwarding where possible
- Async I/O prevents blocking
- Connection pooling with DashMap
- Lock-free operations where possible

## Contributing

When adding new features:

1. Add types to appropriate crate (core, cot, cert, client)
2. Update FFI interface in `omnitak-mobile`
3. Update C header in `include/omnitak_mobile.h`
4. Add tests
5. Update documentation

## License

See LICENSE.md in repository root.
