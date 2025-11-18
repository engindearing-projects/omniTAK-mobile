//! Client connection management

use crate::error::{Result, ServerError};
use bytes::BytesMut;
use std::net::SocketAddr;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::sync::mpsc;
use tokio::time::{timeout, Duration};
use tracing::{debug, error, info, warn};

/// Unique client identifier
pub type ClientId = u64;

static NEXT_CLIENT_ID: AtomicU64 = AtomicU64::new(1);

/// Generate next client ID
fn next_client_id() -> ClientId {
    NEXT_CLIENT_ID.fetch_add(1, Ordering::Relaxed)
}

/// Client connection state
#[derive(Debug, Clone)]
pub struct ClientInfo {
    pub id: ClientId,
    pub addr: SocketAddr,
    pub callsign: Option<String>,
    pub uid: Option<String>,
    pub connected_at: chrono::DateTime<chrono::Utc>,
    pub messages_sent: Arc<AtomicU64>,
    pub messages_received: Arc<AtomicU64>,
}

impl ClientInfo {
    pub fn new(id: ClientId, addr: SocketAddr) -> Self {
        Self {
            id,
            addr,
            callsign: None,
            uid: None,
            connected_at: chrono::Utc::now(),
            messages_sent: Arc::new(AtomicU64::new(0)),
            messages_received: Arc::new(AtomicU64::new(0)),
        }
    }

    pub fn increment_sent(&self) {
        self.messages_sent.fetch_add(1, Ordering::Relaxed);
    }

    pub fn increment_received(&self) {
        self.messages_received.fetch_add(1, Ordering::Relaxed);
    }

    pub fn get_sent(&self) -> u64 {
        self.messages_sent.load(Ordering::Relaxed)
    }

    pub fn get_received(&self) -> u64 {
        self.messages_received.load(Ordering::Relaxed)
    }
}

/// Client connection handler
pub struct Client {
    pub info: ClientInfo,
    pub stream: TcpStream,
    pub rx_broadcast: mpsc::Receiver<Arc<String>>,
    pub read_timeout: Duration,
}

impl Client {
    /// Create a new client connection
    pub fn new(
        stream: TcpStream,
        addr: SocketAddr,
        rx_broadcast: mpsc::Receiver<Arc<String>>,
        timeout_secs: u64,
    ) -> Self {
        let id = next_client_id();
        let info = ClientInfo::new(id, addr);

        info!("[Client {}] Connected from {}", info.id, info.addr);

        Self {
            info,
            stream,
            rx_broadcast,
            read_timeout: Duration::from_secs(timeout_secs),
        }
    }

    /// Get client info
    pub fn info(&self) -> &ClientInfo {
        &self.info
    }

    /// Handle client connection
    ///
    /// Returns when the client disconnects or an error occurs
    pub async fn handle(
        mut self,
        tx_router: mpsc::Sender<(ClientId, String)>,
    ) -> Result<()> {
        let mut read_buf = BytesMut::with_capacity(8192);
        let mut partial_message = String::new();

        loop {
            tokio::select! {
                // Read from client
                result = timeout(self.read_timeout, self.stream.read_buf(&mut read_buf)) => {
                    match result {
                        Ok(Ok(0)) => {
                            // Client disconnected
                            info!("[Client {}] Disconnected", self.info.id);
                            return Ok(());
                        }
                        Ok(Ok(n)) => {
                            debug!("[Client {}] Read {} bytes", self.info.id, n);

                            // Process received data
                            if let Err(e) = self.process_received_data(
                                &mut read_buf,
                                &mut partial_message,
                                &tx_router,
                            ).await {
                                error!("[Client {}] Error processing data: {}", self.info.id, e);
                                return Err(e);
                            }
                        }
                        Ok(Err(e)) => {
                            error!("[Client {}] Read error: {}", self.info.id, e);
                            return Err(e.into());
                        }
                        Err(_) => {
                            warn!("[Client {}] Read timeout", self.info.id);
                            return Err(ServerError::ConnectionClosed);
                        }
                    }
                }

                // Receive broadcast messages from router
                Some(cot_xml) = self.rx_broadcast.recv() => {
                    if let Err(e) = self.send_message(&cot_xml).await {
                        error!("[Client {}] Error sending broadcast: {}", self.info.id, e);
                        return Err(e);
                    }
                }
            }
        }
    }

    /// Process received data from client
    async fn process_received_data(
        &mut self,
        read_buf: &mut BytesMut,
        partial_message: &mut String,
        tx_router: &mpsc::Sender<(ClientId, String)>,
    ) -> Result<()> {
        // Convert bytes to string
        let data = String::from_utf8_lossy(&read_buf).to_string();
        read_buf.clear();

        // Append to partial message
        partial_message.push_str(&data);

        // Extract complete XML messages
        while let Some(message) = self.extract_complete_message(partial_message) {
            debug!("[Client {}] Received CoT message", self.info.id);

            // Update client info from CoT
            self.update_info_from_cot(&message);

            // Increment received counter
            self.info.increment_received();

            // Send to router for broadcast
            if let Err(e) = tx_router.send((self.info.id, message)).await {
                error!("[Client {}] Failed to send to router: {}", self.info.id, e);
                return Err(ServerError::Client("Router channel closed".into()));
            }
        }

        Ok(())
    }

    /// Extract a complete XML message from the buffer
    ///
    /// CoT messages are complete XML documents, typically ending with </event>
    fn extract_complete_message(&self, buffer: &mut String) -> Option<String> {
        // Look for complete event tag
        if let Some(end_pos) = buffer.find("</event>") {
            let end_index = end_pos + "</event>".len();
            let message = buffer[..end_index].to_string();
            *buffer = buffer[end_index..].to_string();
            return Some(message);
        }

        None
    }

    /// Update client info from CoT message
    fn update_info_from_cot(&mut self, cot_xml: &str) {
        // Simple XML parsing to extract uid and callsign
        // In production, use proper XML parser

        // Extract uid from event tag
        if self.info.uid.is_none() {
            if let Some(start) = cot_xml.find("uid=\"") {
                if let Some(end) = cot_xml[start + 5..].find('"') {
                    let uid = &cot_xml[start + 5..start + 5 + end];
                    self.info.uid = Some(uid.to_string());
                    debug!("[Client {}] UID: {}", self.info.id, uid);
                }
            }
        }

        // Extract callsign from contact tag
        if self.info.callsign.is_none() {
            if let Some(start) = cot_xml.find("callsign=\"") {
                if let Some(end) = cot_xml[start + 10..].find('"') {
                    let callsign = &cot_xml[start + 10..start + 10 + end];
                    self.info.callsign = Some(callsign.to_string());
                    info!("[Client {}] Callsign: {}", self.info.id, callsign);
                }
            }
        }
    }

    /// Send a message to the client
    async fn send_message(&mut self, message: &str) -> Result<()> {
        self.stream.write_all(message.as_bytes()).await?;
        self.stream.flush().await?;
        self.info.increment_sent();
        debug!("[Client {}] Sent CoT message", self.info.id);
        Ok(())
    }
}
