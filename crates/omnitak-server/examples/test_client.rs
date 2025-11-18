//! Simple test client to send CoT messages to the server
//!
//! Usage:
//!   cargo run --example test_client

use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use std::time::Duration;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("Connecting to TAK server at localhost:8087...");

    let mut stream = TcpStream::connect("127.0.0.1:8087").await?;
    println!("Connected!");

    // Send a test CoT message
    let cot_xml = r#"<?xml version="1.0" encoding="UTF-8"?>
<event version="2.0" uid="test-client-1" type="a-f-G-E-S" time="2025-11-18T21:30:00Z" start="2025-11-18T21:30:00Z" stale="2025-11-18T21:35:00Z" how="m-g">
    <point lat="37.7749" lon="-122.4194" hae="0" ce="9999999" le="9999999"/>
    <detail>
        <contact callsign="TEST-CLIENT-1"/>
    </detail>
</event>"#;

    println!("Sending CoT message...");
    stream.write_all(cot_xml.as_bytes()).await?;
    stream.flush().await?;
    println!("CoT sent!");

    // Wait a bit to receive any broadcast messages
    println!("Listening for broadcasts...");

    let mut buffer = vec![0u8; 8192];
    tokio::select! {
        result = stream.read(&mut buffer) => {
            match result {
                Ok(n) if n > 0 => {
                    let response = String::from_utf8_lossy(&buffer[..n]);
                    println!("Received broadcast:\n{}", response);
                }
                Ok(_) => println!("Connection closed by server"),
                Err(e) => eprintln!("Error reading: {}", e),
            }
        }
        _ = tokio::time::sleep(Duration::from_secs(5)) => {
            println!("No broadcasts received in 5 seconds");
        }
    }

    println!("Test complete!");
    Ok(())
}
