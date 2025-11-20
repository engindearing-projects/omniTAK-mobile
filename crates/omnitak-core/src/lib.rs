//! # OmniTAK Core
//!
//! Core types and utilities for OmniTAK

use serde::{Deserialize, Serialize};
use std::fmt;

/// Meshtastic connection type
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum MeshtasticConnectionType {
    /// Serial/USB connection (e.g., /dev/ttyUSB0, COM3)
    Serial(String),
    /// Bluetooth connection (device address)
    Bluetooth(String),
    /// TCP connection (for network-connected Meshtastic devices)
    Tcp,
}

/// Meshtastic-specific configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MeshtasticConfig {
    /// Connection type
    pub connection_type: MeshtasticConnectionType,
    /// Optional node ID for direct messaging (if None, broadcasts to mesh)
    pub node_id: Option<u32>,
    /// Device name (for display purposes)
    pub device_name: Option<String>,
}

/// Protocol type for TAK server connections
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Protocol {
    /// TCP connection
    Tcp,
    /// UDP connection
    Udp,
    /// TLS-secured TCP connection
    Tls,
    /// WebSocket connection
    WebSocket,
    /// Meshtastic mesh network connection
    Meshtastic,
}

impl fmt::Display for Protocol {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Protocol::Tcp => write!(f, "tcp"),
            Protocol::Udp => write!(f, "udp"),
            Protocol::Tls => write!(f, "tls"),
            Protocol::WebSocket => write!(f, "ws"),
            Protocol::Meshtastic => write!(f, "meshtastic"),
        }
    }
}

impl From<&str> for Protocol {
    fn from(s: &str) -> Self {
        match s.to_lowercase().as_str() {
            "udp" => Protocol::Udp,
            "tls" | "ssl" => Protocol::Tls,
            "ws" | "websocket" => Protocol::WebSocket,
            "meshtastic" | "mesh" => Protocol::Meshtastic,
            _ => Protocol::Tcp,
        }
    }
}

/// Connection configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConnectionConfig {
    /// Server hostname or IP address
    pub host: String,
    /// Server port
    pub port: u16,
    /// Connection protocol
    pub protocol: Protocol,
    /// Whether to use TLS encryption
    pub use_tls: bool,
    /// Client certificate PEM (optional)
    pub cert_pem: Option<String>,
    /// Client private key PEM (optional)
    pub key_pem: Option<String>,
    /// CA certificate PEM (optional)
    pub ca_pem: Option<String>,
    /// Meshtastic-specific configuration (when protocol is Meshtastic)
    pub meshtastic_config: Option<MeshtasticConfig>,
}

impl ConnectionConfig {
    /// Create a new connection configuration
    pub fn new(host: impl Into<String>, port: u16, protocol: Protocol) -> Self {
        Self {
            host: host.into(),
            port,
            protocol,
            use_tls: false,
            cert_pem: None,
            key_pem: None,
            ca_pem: None,
            meshtastic_config: None,
        }
    }

    /// Create a new Meshtastic connection configuration
    pub fn new_meshtastic(meshtastic_config: MeshtasticConfig) -> Self {
        Self {
            host: String::new(),
            port: 0,
            protocol: Protocol::Meshtastic,
            use_tls: false,
            cert_pem: None,
            key_pem: None,
            ca_pem: None,
            meshtastic_config: Some(meshtastic_config),
        }
    }

    /// Enable TLS with optional certificates
    pub fn with_tls(
        mut self,
        cert_pem: Option<String>,
        key_pem: Option<String>,
        ca_pem: Option<String>,
    ) -> Self {
        self.use_tls = true;
        self.cert_pem = cert_pem;
        self.key_pem = key_pem;
        self.ca_pem = ca_pem;
        self
    }
}

/// Connection state
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ConnectionState {
    /// Not connected
    Disconnected,
    /// Connecting to server
    Connecting,
    /// Connected and ready
    Connected,
    /// Connection failed
    Failed,
}

impl fmt::Display for ConnectionState {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ConnectionState::Disconnected => write!(f, "disconnected"),
            ConnectionState::Connecting => write!(f, "connecting"),
            ConnectionState::Connected => write!(f, "connected"),
            ConnectionState::Failed => write!(f, "failed"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_protocol_from_string() {
        assert_eq!(Protocol::from("tcp"), Protocol::Tcp);
        assert_eq!(Protocol::from("udp"), Protocol::Udp);
        assert_eq!(Protocol::from("tls"), Protocol::Tls);
        assert_eq!(Protocol::from("ws"), Protocol::WebSocket);
    }

    #[test]
    fn test_connection_config() {
        let config = ConnectionConfig::new("192.168.1.100", 8087, Protocol::Tcp);
        assert_eq!(config.host, "192.168.1.100");
        assert_eq!(config.port, 8087);
        assert_eq!(config.protocol, Protocol::Tcp);
        assert!(!config.use_tls);
    }
}
