//! # OmniTAK Server
//!
//! A lightweight, high-performance TAK (Team Awareness Kit) server implementation in Rust.
//!
//! ## Features
//!
//! - TCP and TLS CoT message routing
//! - Client certificate authentication
//! - Marti API compatibility
//! - Data Package Server (DPS)
//! - Certificate enrollment endpoint
//! - Debug logging mode
//!
//! ## Architecture
//!
//! The server uses asynchronous I/O with tokio for high performance:
//! - Single-threaded event loop handles all clients efficiently
//! - Broadcast channels for message distribution
//! - DashMap for thread-safe client registry
//! - Zero-copy message forwarding where possible

pub mod server;
pub mod client;
pub mod router;
pub mod config;
pub mod marti;
pub mod error;

pub use server::TakServer;
pub use client::{Client, ClientId};
pub use router::CotRouter;
pub use config::ServerConfig;
pub use error::{ServerError, Result};

/// Server version
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Default server port for TCP
pub const DEFAULT_TCP_PORT: u16 = 8087;

/// Default server port for TLS
pub const DEFAULT_TLS_PORT: u16 = 8089;

/// Default Marti API port
pub const DEFAULT_MARTI_PORT: u16 = 8443;
