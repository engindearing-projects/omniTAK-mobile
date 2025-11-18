//! Simple TAK server CLI example
//!
//! Starts a TAK server in debug mode on port 8087
//!
//! Usage:
//!   cargo run --example server
//!   cargo run --example server -- --port 8088

use omnitak_server::{ServerConfig, TakServer};
use tracing::info;
use tracing_subscriber::{fmt, prelude::*, EnvFilter};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Initialize logging
    tracing_subscriber::registry()
        .with(fmt::layer())
        .with(
            EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| EnvFilter::new("info,omnitak_server=debug")),
        )
        .init();

    info!("OmniTAK Server - Rust TAK Server Implementation");

    // Parse command line arguments
    let args: Vec<String> = std::env::args().collect();
    let port = if args.len() > 2 && args[1] == "--port" {
        args[2].parse::<u16>().unwrap_or(8087)
    } else {
        8087
    };

    // Create debug configuration
    let mut config = ServerConfig::debug();
    config.tcp_port = port;

    info!("Starting server on TCP port {}", port);
    info!("Debug logging enabled - all CoT messages will be logged");
    info!("Press Ctrl+C to stop");

    // Create and start server
    let mut server = TakServer::new(config)?;
    server.start().await?;

    // Wait for Ctrl+C
    tokio::signal::ctrl_c().await?;

    info!("Shutting down...");
    server.stop().await?;

    // Print final statistics
    let stats = server.stats();
    info!("Final statistics:");
    info!("  Total messages routed: {}", stats.total_messages);
    info!("  Clients connected at shutdown: {}", stats.client_count);

    Ok(())
}
