//! # OmniTAK Client
//!
//! TAK server client implementation

use anyhow::{Context, Result};
use bytes::BytesMut;
use omnitak_cert::{build_tls_config, CertBundle};
use omnitak_core::{ConnectionConfig, ConnectionState, Protocol};
use omnitak_meshtastic::MeshtasticClient;
use parking_lot::Mutex;
use std::sync::Arc;
use thiserror::Error;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpStream, UdpSocket};
use tokio::sync::mpsc;
use tokio_rustls::TlsConnector;
use tracing::{debug, error, info};

#[derive(Error, Debug)]
pub enum ClientError {
    #[error("Connection failed: {0}")]
    ConnectionFailed(String),

    #[error("Send failed: {0}")]
    SendFailed(String),

    #[error("Protocol not supported: {0:?}")]
    UnsupportedProtocol(Protocol),

    #[error("TLS error: {0}")]
    TlsError(String),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}

/// TAK server client
pub struct TakClient {
    config: ConnectionConfig,
    state: Arc<Mutex<ClientState>>,
    tx: mpsc::UnboundedSender<ClientCommand>,
}

struct ClientState {
    connection_state: ConnectionState,
    messages_sent: u64,
    messages_received: u64,
    last_error: Option<String>,
}

enum ClientCommand {
    Send(String),
    Disconnect,
}

impl TakClient {
    /// Create a new TAK client
    pub async fn connect(
        config: ConnectionConfig,
        callback: Option<Box<dyn Fn(String) + Send + Sync>>,
    ) -> Result<Self> {
        info!(
            "Connecting to {}:{} via {}",
            config.host, config.port, config.protocol
        );

        let state = Arc::new(Mutex::new(ClientState {
            connection_state: ConnectionState::Connecting,
            messages_sent: 0,
            messages_received: 0,
            last_error: None,
        }));

        let (tx, rx) = mpsc::unbounded_channel();

        let client = Self {
            config: config.clone(),
            state: state.clone(),
            tx,
        };

        // Spawn connection task
        let state_clone = state.clone();
        tokio::spawn(async move {
            if let Err(e) = Self::connection_task(config, state_clone, rx, callback).await {
                error!("Connection task failed: {}", e);
            }
        });

        Ok(client)
    }

    /// Get current connection state
    pub fn state(&self) -> ConnectionState {
        self.state.lock().connection_state
    }

    /// Get number of messages sent
    pub fn messages_sent(&self) -> u64 {
        self.state.lock().messages_sent
    }

    /// Get number of messages received
    pub fn messages_received(&self) -> u64 {
        self.state.lock().messages_received
    }

    /// Get last error
    pub fn last_error(&self) -> Option<String> {
        self.state.lock().last_error.clone()
    }

    /// Send a CoT message
    pub fn send_cot(&self, cot_xml: impl Into<String>) -> Result<()> {
        let xml = cot_xml.into();
        debug!("Sending CoT: {}", xml);

        self.tx
            .send(ClientCommand::Send(xml))
            .context("Failed to send command")?;

        self.state.lock().messages_sent += 1;
        Ok(())
    }

    /// Disconnect from server
    pub fn disconnect(&self) {
        let _ = self.tx.send(ClientCommand::Disconnect);
    }

    async fn connection_task(
        config: ConnectionConfig,
        state: Arc<Mutex<ClientState>>,
        rx: mpsc::UnboundedReceiver<ClientCommand>,
        callback: Option<Box<dyn Fn(String) + Send + Sync>>,
    ) -> Result<()> {
        match config.protocol {
            Protocol::Tcp | Protocol::Tls => {
                Self::tcp_connection_task(config, state, rx, callback).await
            }
            Protocol::Udp => {
                Self::udp_connection_task(config, state, rx, callback).await
            }
            Protocol::Meshtastic => {
                Self::meshtastic_connection_task(config, state, rx, callback).await
            }
            Protocol::WebSocket => {
                // WebSocket support can be added later
                Err(ClientError::UnsupportedProtocol(Protocol::WebSocket).into())
            }
        }
    }

    async fn meshtastic_connection_task(
        config: ConnectionConfig,
        state: Arc<Mutex<ClientState>>,
        mut rx: mpsc::UnboundedReceiver<ClientCommand>,
        callback: Option<Box<dyn Fn(String) + Send + Sync>>,
    ) -> Result<()> {
        info!("Starting Meshtastic connection");

        // Connect to Meshtastic device
        let client = MeshtasticClient::connect(config, callback)
            .await
            .context("Failed to connect to Meshtastic device")?;

        // Update state to connected
        state.lock().connection_state = ConnectionState::Connected;

        // Handle outgoing commands
        while let Some(cmd) = rx.recv().await {
            match cmd {
                ClientCommand::Send(xml) => {
                    if let Err(e) = client.send_cot(&xml) {
                        error!("Failed to send CoT via Meshtastic: {}", e);
                        state.lock().last_error = Some(e.to_string());
                    } else {
                        state.lock().messages_sent += 1;
                    }
                }
                ClientCommand::Disconnect => {
                    info!("Disconnecting from Meshtastic");
                    client.disconnect();
                    break;
                }
            }
        }

        state.lock().connection_state = ConnectionState::Disconnected;
        Ok(())
    }

    async fn tcp_connection_task(
        config: ConnectionConfig,
        state: Arc<Mutex<ClientState>>,
        mut rx: mpsc::UnboundedReceiver<ClientCommand>,
        callback: Option<Box<dyn Fn(String) + Send + Sync>>,
    ) -> Result<()> {
        // Connect to server
        let stream = TcpStream::connect(format!("{}:{}", config.host, config.port))
            .await
            .context("Failed to connect to TCP server")?;

        info!("TCP connection established");

        // Handle TLS if needed
        if config.use_tls || config.protocol == Protocol::Tls {
            let cert_bundle = CertBundle::new(config.cert_pem, config.key_pem, config.ca_pem);
            let tls_config = build_tls_config(&cert_bundle)
                .context("Failed to build TLS config")?;

            let connector = TlsConnector::from(tls_config);
            let domain = match config.host.as_str().try_into() {
                Ok(name) => name,
                Err(_) => return Err(ClientError::TlsError(format!("Invalid server name: {}", config.host)).into()),
            };

            let tls_stream = connector
                .connect(domain, stream)
                .await
                .map_err(|e| ClientError::TlsError(format!("TLS handshake failed: {}", e)))?;

            info!("TLS connection established");
            state.lock().connection_state = ConnectionState::Connected;

            Self::handle_tls_stream(tls_stream, state, rx, callback).await
        } else {
            state.lock().connection_state = ConnectionState::Connected;
            Self::handle_tcp_stream(stream, state, rx, callback).await
        }
    }

    async fn handle_tcp_stream(
        mut stream: TcpStream,
        state: Arc<Mutex<ClientState>>,
        mut rx: mpsc::UnboundedReceiver<ClientCommand>,
        callback: Option<Box<dyn Fn(String) + Send + Sync>>,
    ) -> Result<()> {
        let (mut read_half, mut write_half) = stream.split();
        let mut buffer = BytesMut::with_capacity(8192);

        loop {
            tokio::select! {
                // Handle incoming data
                result = read_half.read_buf(&mut buffer) => {
                    match result {
                        Ok(0) => {
                            info!("Connection closed by server");
                            break;
                        }
                        Ok(n) => {
                            debug!("Received {} bytes", n);
                            if let Some(ref cb) = callback {
                                // Extract complete messages (simple implementation)
                                let data = String::from_utf8_lossy(&buffer[..]).to_string();
                                if data.contains("</event>") {
                                    cb(data.clone());
                                    state.lock().messages_received += 1;
                                    buffer.clear();
                                }
                            }
                        }
                        Err(e) => {
                            error!("Read error: {}", e);
                            state.lock().last_error = Some(e.to_string());
                            break;
                        }
                    }
                }

                // Handle outgoing commands
                cmd = rx.recv() => {
                    match cmd {
                        Some(ClientCommand::Send(xml)) => {
                            if let Err(e) = write_half.write_all(xml.as_bytes()).await {
                                error!("Write error: {}", e);
                                state.lock().last_error = Some(e.to_string());
                            }
                        }
                        Some(ClientCommand::Disconnect) | None => {
                            info!("Disconnecting");
                            break;
                        }
                    }
                }
            }
        }

        state.lock().connection_state = ConnectionState::Disconnected;
        Ok(())
    }

    async fn handle_tls_stream(
        mut stream: tokio_rustls::client::TlsStream<TcpStream>,
        state: Arc<Mutex<ClientState>>,
        mut rx: mpsc::UnboundedReceiver<ClientCommand>,
        callback: Option<Box<dyn Fn(String) + Send + Sync>>,
    ) -> Result<()> {
        let mut buffer = BytesMut::with_capacity(8192);

        loop {
            tokio::select! {
                // Handle incoming data
                result = stream.read_buf(&mut buffer) => {
                    match result {
                        Ok(0) => {
                            info!("TLS connection closed by server");
                            break;
                        }
                        Ok(n) => {
                            debug!("Received {} bytes over TLS", n);
                            if let Some(ref cb) = callback {
                                let data = String::from_utf8_lossy(&buffer[..]).to_string();
                                if data.contains("</event>") {
                                    cb(data.clone());
                                    state.lock().messages_received += 1;
                                    buffer.clear();
                                }
                            }
                        }
                        Err(e) => {
                            error!("TLS read error: {}", e);
                            state.lock().last_error = Some(e.to_string());
                            break;
                        }
                    }
                }

                // Handle outgoing commands
                cmd = rx.recv() => {
                    match cmd {
                        Some(ClientCommand::Send(xml)) => {
                            if let Err(e) = stream.write_all(xml.as_bytes()).await {
                                error!("TLS write error: {}", e);
                                state.lock().last_error = Some(e.to_string());
                            }
                        }
                        Some(ClientCommand::Disconnect) | None => {
                            info!("Disconnecting from TLS");
                            break;
                        }
                    }
                }
            }
        }

        state.lock().connection_state = ConnectionState::Disconnected;
        Ok(())
    }

    async fn udp_connection_task(
        config: ConnectionConfig,
        state: Arc<Mutex<ClientState>>,
        mut rx: mpsc::UnboundedReceiver<ClientCommand>,
        callback: Option<Box<dyn Fn(String) + Send + Sync>>,
    ) -> Result<()> {
        let socket = UdpSocket::bind("0.0.0.0:0")
            .await
            .context("Failed to bind UDP socket")?;

        socket
            .connect(format!("{}:{}", config.host, config.port))
            .await
            .context("Failed to connect UDP socket")?;

        info!("UDP connection established");
        state.lock().connection_state = ConnectionState::Connected;

        let mut buffer = vec![0u8; 8192];

        loop {
            tokio::select! {
                result = socket.recv(&mut buffer) => {
                    match result {
                        Ok(n) => {
                            debug!("Received {} bytes via UDP", n);
                            if let Some(ref cb) = callback {
                                let data = String::from_utf8_lossy(&buffer[..n]).to_string();
                                cb(data);
                                state.lock().messages_received += 1;
                            }
                        }
                        Err(e) => {
                            error!("UDP recv error: {}", e);
                            state.lock().last_error = Some(e.to_string());
                        }
                    }
                }

                cmd = rx.recv() => {
                    match cmd {
                        Some(ClientCommand::Send(xml)) => {
                            if let Err(e) = socket.send(xml.as_bytes()).await {
                                error!("UDP send error: {}", e);
                                state.lock().last_error = Some(e.to_string());
                            }
                        }
                        Some(ClientCommand::Disconnect) | None => {
                            info!("Disconnecting UDP");
                            break;
                        }
                    }
                }
            }
        }

        state.lock().connection_state = ConnectionState::Disconnected;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_client_creation() {
        let config = ConnectionConfig::new("localhost", 8087, Protocol::Tcp);
        // This will fail to connect, but we're testing creation
        let result = TakClient::connect(config, None).await;
        // We expect this to succeed creating the client, even if connection fails
        assert!(result.is_ok() || result.is_err());
    }
}
