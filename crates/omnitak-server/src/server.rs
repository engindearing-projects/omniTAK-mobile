//! Main TAK server implementation

use crate::client::{Client, ClientId};
use crate::config::ServerConfig;
use crate::error::Result;
use crate::router::CotRouter;
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::net::TcpListener;
use tokio::sync::mpsc;
use tokio::task::JoinHandle;
use tracing::{error, info, warn};

/// TAK Server
pub struct TakServer {
    config: ServerConfig,
    router: Arc<CotRouter>,
    router_tx: mpsc::Sender<(ClientId, String)>,
    router_handle: Option<JoinHandle<()>>,
    tcp_handle: Option<JoinHandle<Result<()>>>,
}

impl TakServer {
    /// Create a new TAK server
    pub fn new(config: ServerConfig) -> Result<Self> {
        config.validate()?;

        // Create router
        let router = Arc::new(CotRouter::new(config.debug));

        // Create router channel
        let (router_tx, router_rx) = mpsc::channel(1000);

        // Spawn router task
        let router_clone = Arc::clone(&router);
        let router_handle = tokio::spawn(async move {
            router_clone.run(router_rx).await;
        });

        Ok(Self {
            config,
            router,
            router_tx,
            router_handle: Some(router_handle),
            tcp_handle: None,
        })
    }

    /// Start the server
    pub async fn start(&mut self) -> Result<()> {
        info!("Starting OmniTAK Server v{}", crate::VERSION);
        info!("Configuration: {:?}", self.config);

        // Start TCP listener if enabled
        if self.config.tcp_port > 0 {
            let addr = SocketAddr::new(self.config.bind_address, self.config.tcp_port);
            let listener = TcpListener::bind(addr).await?;
            info!("TCP listener bound to {}", addr);

            let router = Arc::clone(&self.router);
            let router_tx = self.router_tx.clone();
            let timeout_secs = self.config.client_timeout_secs;
            let max_clients = self.config.max_clients;

            let handle = tokio::spawn(async move {
                Self::accept_loop(listener, router, router_tx, timeout_secs, max_clients).await
            });

            self.tcp_handle = Some(handle);
        }

        // TODO: Start TLS listener if enabled
        // TODO: Start Marti API server if enabled

        info!("Server started successfully");
        Ok(())
    }

    /// Accept incoming connections
    async fn accept_loop(
        listener: TcpListener,
        router: Arc<CotRouter>,
        router_tx: mpsc::Sender<(ClientId, String)>,
        timeout_secs: u64,
        max_clients: usize,
    ) -> Result<()> {
        loop {
            // Check client limit
            if router.client_count() >= max_clients {
                warn!("Max clients ({}) reached, waiting...", max_clients);
                tokio::time::sleep(tokio::time::Duration::from_secs(1)).await;
                continue;
            }

            // Accept new connection
            match listener.accept().await {
                Ok((stream, addr)) => {
                    info!("Accepted connection from {}", addr);

                    // Create client handler (which assigns ID)
                    let client = Client::new(stream, addr, mpsc::channel(100).1, timeout_secs);
                    let client_id = client.info().id;

                    // Register with router using actual client ID
                    let rx_broadcast = router.register_client(client_id);

                    // Create client with proper broadcast receiver
                    let client = Client {
                        info: client.info,
                        stream: client.stream,
                        rx_broadcast,
                        read_timeout: client.read_timeout,
                    };

                    let router_tx_clone = router_tx.clone();
                    let router_clone = Arc::clone(&router);

                    // Spawn client handler
                    tokio::spawn(async move {
                        let client_id = client.info().id;

                        match client.handle(router_tx_clone).await {
                            Ok(_) => info!("[Client {}] Disconnected normally", client_id),
                            Err(e) => error!("[Client {}] Disconnected with error: {}", client_id, e),
                        }

                        // Unregister from router
                        router_clone.unregister_client(client_id);
                    });
                }
                Err(e) => {
                    error!("Failed to accept connection: {}", e);
                }
            }
        }
    }

    /// Stop the server
    pub async fn stop(&mut self) -> Result<()> {
        info!("Stopping server...");

        // Stop TCP listener
        if let Some(handle) = self.tcp_handle.take() {
            handle.abort();
        }

        // Stop router
        if let Some(handle) = self.router_handle.take() {
            handle.abort();
        }

        info!("Server stopped");
        Ok(())
    }

    /// Get server statistics
    pub fn stats(&self) -> ServerStats {
        ServerStats {
            client_count: self.router.client_count(),
            total_messages: self.router.total_messages(),
        }
    }

    /// Wait for the server to stop
    pub async fn wait(&mut self) -> Result<()> {
        // Wait for TCP handle
        if let Some(handle) = self.tcp_handle.take() {
            match handle.await {
                Ok(Ok(_)) => {}
                Ok(Err(e)) => return Err(e),
                Err(e) => error!("TCP listener task panicked: {}", e),
            }
        }

        Ok(())
    }
}

impl Drop for TakServer {
    fn drop(&mut self) {
        // Abort any remaining tasks
        if let Some(handle) = self.tcp_handle.take() {
            handle.abort();
        }
        if let Some(handle) = self.router_handle.take() {
            handle.abort();
        }
    }
}

/// Server statistics
#[derive(Debug, Clone)]
pub struct ServerStats {
    pub client_count: usize,
    pub total_messages: u64,
}
