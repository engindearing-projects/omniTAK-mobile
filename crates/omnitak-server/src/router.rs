//! CoT message router
//!
//! Broadcasts CoT messages from one client to all other connected clients

use crate::client::ClientId;
use dashmap::DashMap;
use std::sync::Arc;
use tokio::sync::mpsc;
use tracing::{debug, info, warn};

/// CoT message router
///
/// Receives messages from clients and broadcasts them to all other clients
pub struct CotRouter {
    /// Map of client ID to broadcast sender
    clients: Arc<DashMap<ClientId, mpsc::Sender<Arc<String>>>>,

    /// Debug mode - log all CoT messages
    debug: bool,

    /// Statistics
    total_messages: Arc<std::sync::atomic::AtomicU64>,
}

impl CotRouter {
    /// Create a new router
    pub fn new(debug: bool) -> Self {
        Self {
            clients: Arc::new(DashMap::new()),
            debug,
            total_messages: Arc::new(std::sync::atomic::AtomicU64::new(0)),
        }
    }

    /// Register a new client
    ///
    /// Returns a receiver for broadcast messages
    pub fn register_client(&self, client_id: ClientId) -> mpsc::Receiver<Arc<String>> {
        let (tx, rx) = mpsc::channel(100);
        self.clients.insert(client_id, tx);
        info!("[Router] Registered client {}, total clients: {}", client_id, self.clients.len());
        rx
    }

    /// Unregister a client
    pub fn unregister_client(&self, client_id: ClientId) {
        self.clients.remove(&client_id);
        info!("[Router] Unregistered client {}, total clients: {}", client_id, self.clients.len());
    }

    /// Route a CoT message from one client to all others
    pub async fn route_message(&self, from_client_id: ClientId, cot_xml: String) {
        if self.debug {
            info!("[Router] Message from client {}: {}", from_client_id, cot_xml);
        }

        // Increment total message counter
        self.total_messages
            .fetch_add(1, std::sync::atomic::Ordering::Relaxed);

        // Wrap in Arc for efficient broadcasting
        let message = Arc::new(cot_xml);

        // Broadcast to all clients except sender
        let mut disconnected_clients = Vec::new();

        for entry in self.clients.iter() {
            let client_id = *entry.key();
            let sender = entry.value();

            // Don't send back to originator
            if client_id == from_client_id {
                continue;
            }

            // Try to send, mark for removal if channel closed
            if let Err(_) = sender.send(Arc::clone(&message)).await {
                warn!("[Router] Client {} channel closed, marking for removal", client_id);
                disconnected_clients.push(client_id);
            } else {
                debug!("[Router] Broadcasted to client {}", client_id);
            }
        }

        // Clean up disconnected clients
        for client_id in disconnected_clients {
            self.unregister_client(client_id);
        }
    }

    /// Get number of connected clients
    pub fn client_count(&self) -> usize {
        self.clients.len()
    }

    /// Get total messages routed
    pub fn total_messages(&self) -> u64 {
        self.total_messages.load(std::sync::atomic::Ordering::Relaxed)
    }

    /// Handle router messages
    ///
    /// Runs in a loop processing messages from clients
    pub async fn run(self: Arc<Self>, mut rx: mpsc::Receiver<(ClientId, String)>) {
        info!("[Router] Started");

        while let Some((client_id, cot_xml)) = rx.recv().await {
            self.route_message(client_id, cot_xml).await;
        }

        info!("[Router] Stopped");
    }
}
