//! Server configuration

use crate::error::{Result, ServerError};
use serde::{Deserialize, Serialize};
use std::net::IpAddr;
use std::path::PathBuf;

/// Server configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerConfig {
    /// Server bind address
    #[serde(default = "default_bind_address")]
    pub bind_address: IpAddr,

    /// TCP port (0 to disable)
    #[serde(default = "default_tcp_port")]
    pub tcp_port: u16,

    /// TLS port (0 to disable)
    #[serde(default)]
    pub tls_port: u16,

    /// Marti API port (0 to disable)
    #[serde(default)]
    pub marti_port: u16,

    /// TLS configuration
    #[serde(default)]
    pub tls: Option<TlsConfig>,

    /// Enable debug logging for all CoT messages
    #[serde(default = "default_debug")]
    pub debug: bool,

    /// Maximum number of clients
    #[serde(default = "default_max_clients")]
    pub max_clients: usize,

    /// Client timeout in seconds
    #[serde(default = "default_client_timeout")]
    pub client_timeout_secs: u64,

    /// Data package storage directory
    #[serde(default)]
    pub data_package_dir: Option<PathBuf>,
}

/// TLS configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TlsConfig {
    /// Path to server certificate PEM file
    pub cert_path: PathBuf,

    /// Path to server private key PEM file
    pub key_path: PathBuf,

    /// Path to CA certificate PEM file (for client cert verification)
    pub ca_path: Option<PathBuf>,

    /// Require client certificates
    #[serde(default)]
    pub require_client_cert: bool,
}

impl Default for ServerConfig {
    fn default() -> Self {
        Self {
            bind_address: default_bind_address(),
            tcp_port: default_tcp_port(),
            tls_port: 0,
            marti_port: 0,
            tls: None,
            debug: default_debug(),
            max_clients: default_max_clients(),
            client_timeout_secs: default_client_timeout(),
            data_package_dir: None,
        }
    }
}

impl ServerConfig {
    /// Create a new debug server configuration
    ///
    /// TCP on port 8087, debug logging enabled
    pub fn debug() -> Self {
        Self {
            tcp_port: 8087,
            debug: true,
            ..Default::default()
        }
    }

    /// Create a production server configuration
    ///
    /// TLS on port 8089, client certs required
    pub fn production(tls_config: TlsConfig) -> Self {
        Self {
            tcp_port: 0,
            tls_port: 8089,
            marti_port: 8443,
            tls: Some(tls_config),
            debug: false,
            ..Default::default()
        }
    }

    /// Validate configuration
    pub fn validate(&self) -> Result<()> {
        if self.tcp_port == 0 && self.tls_port == 0 {
            return Err(ServerError::Config(
                "At least one of tcp_port or tls_port must be non-zero".into(),
            ));
        }

        if self.tls_port > 0 && self.tls.is_none() {
            return Err(ServerError::Config(
                "TLS configuration required when tls_port is set".into(),
            ));
        }

        if self.max_clients == 0 {
            return Err(ServerError::Config(
                "max_clients must be greater than 0".into(),
            ));
        }

        Ok(())
    }
}

fn default_bind_address() -> IpAddr {
    "0.0.0.0".parse().unwrap()
}

fn default_tcp_port() -> u16 {
    8087
}

fn default_debug() -> bool {
    true
}

fn default_max_clients() -> usize {
    1000
}

fn default_client_timeout() -> u64 {
    300 // 5 minutes
}
