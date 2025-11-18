# OmniTAK Server

A lightweight, high-performance TAK (Team Awareness Kit) server implementation in Rust.

## Features

✅ **Implemented:**
- TCP CoT (Cursor on Target) message routing
- Multi-client broadcast (messages from one client broadcast to all others)
- Client identification (UID and callsign extraction)
- Debug logging mode
- Graceful connection handling
- High performance with async I/O (tokio)

🚧 **Planned:**
- TLS with client certificate authentication
- Marti API compatibility endpoints
- Data Package Server (DPS) for file sharing
- Certificate enrollment endpoint
- WebSocket support
- UDP support

## Quick Start

### Run the server:

```bash
cd crates
cargo run --release --example server
```

Server will start on **TCP port 8087** with debug logging enabled.

### Test with example clients:

```bash
# Single client test
cargo run --release --example test_client

# Two-client broadcast test
cargo run --release --example two_clients
```

## Configuration

The server supports flexible configuration via `ServerConfig`:

```rust
use omnitak_server::{ServerConfig, TakServer};

// Debug configuration (default)
let config = ServerConfig::debug();

// Production configuration
let config = ServerConfig::production(tls_config);

// Custom configuration
let config = ServerConfig {
    bind_address: "0.0.0.0".parse().unwrap(),
    tcp_port: 8087,
    tls_port: 8089,
    debug: true,
    max_clients: 1000,
    client_timeout_secs: 300,
    ..Default::default()
};

// Start server
let mut server = TakServer::new(config)?;
server.start().await?;
```

## Architecture

The server uses modern Rust async patterns for high performance:

- **Tokio runtime**: Asynchronous I/O event loop
- **DashMap**: Thread-safe concurrent client registry
- **MPSC channels**: Message passing between router and clients
- **Zero-copy routing**: Arc-wrapped messages for efficient broadcast
- **Structured logging**: tracing framework with log levels

### Components

1. **TakServer** (`server.rs`): Main server, handles TCP listener and spawns client tasks
2. **CotRouter** (`router.rs`): Message routing engine, broadcasts CoT between clients
3. **Client** (`client.rs`): Per-client connection handler, extracts UID/callsign
4. **ServerConfig** (`config.rs`): Configuration management

## Performance

Designed for high throughput:
- Asynchronous I/O (no blocking)
- Lock-free client registry (DashMap)
- Message broadcasting with Arc (no copying)
- Configurable buffer sizes and timeouts

**Expected performance:** 1000+ messages/second on modest hardware

## Comparison to Taky

This is a Rust reimplementation inspired by [Taky](https://github.com/tkuester/taky):

| Feature | Taky (Python) | OmniTAK Server (Rust) |
|---------|---------------|----------------------|
| Language | Python 3.6+ | Rust (async) |
| Lines of Code | ~2,000 | ~1,200 (core) |
| Performance | 1,000 msg/s | 1,000+ msg/s |
| Memory | Leak in XML parser | Safe (no leaks) |
| Dependencies | Python runtime | Single binary |
| Mobile | No | Yes (embeddable) |

## Integration

The server can be:
- **Standalone**: Run as CLI binary
- **GUI embedded**: Start/stop from omni-TAK desktop app
- **Mobile embedded**: Run on iOS/Android for offline testing

## Examples

See `examples/` directory:
- `server.rs`: Simple CLI server
- `test_client.rs`: Single client sending CoT
- `two_clients.rs`: Bidirectional broadcast test

## License

MIT OR Apache-2.0
