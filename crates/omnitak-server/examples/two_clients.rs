//! Test with two clients to verify CoT routing/broadcast
//!
//! Client 1 sends a message, Client 2 should receive it

use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use std::time::Duration;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("=== Two-Client Broadcast Test ===\n");

    // Connect both clients
    println!("Connecting Client 1...");
    let mut client1 = TcpStream::connect("127.0.0.1:8087").await?;
    println!("✓ Client 1 connected\n");

    println!("Connecting Client 2...");
    let mut client2 = TcpStream::connect("127.0.0.1:8087").await?;
    println!("✓ Client 2 connected\n");

    // Give the server time to register both clients
    tokio::time::sleep(Duration::from_millis(100)).await;

    // Client 1 sends a CoT message
    let cot_xml = r#"<?xml version="1.0" encoding="UTF-8"?>
<event version="2.0" uid="client-1-marker" type="a-f-G-E-S" time="2025-11-18T21:30:00Z" start="2025-11-18T21:30:00Z" stale="2025-11-18T21:35:00Z" how="m-g">
    <point lat="37.7749" lon="-122.4194" hae="0" ce="9999999" le="9999999"/>
    <detail>
        <contact callsign="CLIENT-ONE"/>
    </detail>
</event>"#;

    println!("Client 1 sending CoT message...");
    client1.write_all(cot_xml.as_bytes()).await?;
    client1.flush().await?;
    println!("✓ Client 1 sent message\n");

    // Client 2 should receive the broadcast
    println!("Client 2 waiting for broadcast...");
    let mut buffer = vec![0u8; 8192];

    tokio::select! {
        result = client2.read(&mut buffer) => {
            match result {
                Ok(n) if n > 0 => {
                    let response = String::from_utf8_lossy(&buffer[..n]);
                    println!("✓ Client 2 received broadcast!");
                    println!("\nBroadcast content:");
                    println!("{}", response);
                    println!("\n✅ Broadcast routing works!");
                }
                Ok(_) => println!("❌ Connection closed by server"),
                Err(e) => eprintln!("❌ Error reading: {}", e),
            }
        }
        _ = tokio::time::sleep(Duration::from_secs(3)) => {
            println!("❌ No broadcast received in 3 seconds - routing may not be working");
        }
    }

    // Now test reverse: Client 2 sends, Client 1 receives
    println!("\n--- Reverse test ---\n");

    let cot_xml_2 = r#"<?xml version="1.0" encoding="UTF-8"?>
<event version="2.0" uid="client-2-marker" type="a-f-G-E-S" time="2025-11-18T21:30:00Z" start="2025-11-18T21:30:00Z" stale="2025-11-18T21:35:00Z" how="m-g">
    <point lat="34.0522" lon="-118.2437" hae="0" ce="9999999" le="9999999"/>
    <detail>
        <contact callsign="CLIENT-TWO"/>
    </detail>
</event>"#;

    println!("Client 2 sending CoT message...");
    client2.write_all(cot_xml_2.as_bytes()).await?;
    client2.flush().await?;
    println!("✓ Client 2 sent message\n");

    println!("Client 1 waiting for broadcast...");
    let mut buffer = vec![0u8; 8192];

    tokio::select! {
        result = client1.read(&mut buffer) => {
            match result {
                Ok(n) if n > 0 => {
                    let response = String::from_utf8_lossy(&buffer[..n]);
                    println!("✓ Client 1 received broadcast!");
                    println!("\nBroadcast content:");
                    println!("{}", response);
                    println!("\n✅ Bidirectional routing works!");
                }
                Ok(_) => println!("❌ Connection closed by server"),
                Err(e) => eprintln!("❌ Error reading: {}", e),
            }
        }
        _ = tokio::time::sleep(Duration::from_secs(3)) => {
            println!("❌ No broadcast received in 3 seconds");
        }
    }

    println!("\n=== Test Complete ===");
    Ok(())
}
