//! # OmniTAK Meshtastic Integration
//!
//! This crate provides Meshtastic mesh network connectivity for OmniTAK,
//! enabling TAK devices to communicate over long-range radio frequencies
//! without cellular or WiFi networks.
//!
//! ## Features
//! - CoT message conversion to/from Meshtastic protobuf format
//! - Serial, Bluetooth, and TCP connection support
//! - Automatic message chunking for large payloads
//! - Position Location Information (PLI) support
//! - GeoChat message support
//! - Mesh network routing

use anyhow::{Context, Result};
use bytes::{Buf, BufMut, BytesMut};
use omnitak_core::{ConnectionConfig, ConnectionState, MeshtasticConnectionType};
use omnitak_cot::CotMessage;
use parking_lot::Mutex;
use prost::Message as ProstMessage;
use std::collections::HashMap;
use std::sync::Arc;
use thiserror::Error;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::sync::mpsc;
use tokio_serial::SerialPortBuilderExt;
use tracing::{debug, error, info, warn};

// Include generated protobuf code
pub mod proto {
    include!(concat!(env!("OUT_DIR"), "/meshtastic.rs"));
}

use proto::*;

/// Maximum payload size for Meshtastic (233 bytes - excluding 16 byte LoRa header)
pub const MAX_PAYLOAD_SIZE: usize = 233;

/// Maximum data payload after protobuf overhead
pub const MAX_DATA_SIZE: usize = 200;

/// Streaming protocol frame markers
const START1: u8 = 0x94;
const START2: u8 = 0xC3;

#[derive(Error, Debug)]
pub enum MeshtasticError {
    #[error("Connection failed: {0}")]
    ConnectionFailed(String),

    #[error("Send failed: {0}")]
    SendFailed(String),

    #[error("Protocol error: {0}")]
    ProtocolError(String),

    #[error("Conversion error: {0}")]
    ConversionError(String),

    #[error("Chunking error: {0}")]
    ChunkingError(String),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Protobuf decode error: {0}")]
    DecodeError(#[from] prost::DecodeError),
}

/// Meshtastic client for mesh network communication
pub struct MeshtasticClient {
    config: ConnectionConfig,
    state: Arc<Mutex<ClientState>>,
    tx: mpsc::UnboundedSender<ClientCommand>,
    node_id: Arc<Mutex<Option<u32>>>,
}

struct ClientState {
    connection_state: ConnectionState,
    messages_sent: u64,
    messages_received: u64,
    last_error: Option<String>,
    chunk_reassembly: HashMap<u32, ChunkReassembler>,
}

struct ChunkReassembler {
    chunks: HashMap<u32, Vec<u8>>,
    total_chunks: u32,
    created_at: std::time::Instant,
}

enum ClientCommand {
    Send(Vec<u8>),
    SendCot(String),
    Disconnect,
}

impl MeshtasticClient {
    /// Create a new Meshtastic client
    pub async fn connect(
        config: ConnectionConfig,
        callback: Option<Box<dyn Fn(String) + Send + Sync>>,
    ) -> Result<Self> {
        let meshtastic_config = config
            .meshtastic_config
            .as_ref()
            .ok_or_else(|| MeshtasticError::ConnectionFailed("Missing Meshtastic config".into()))?;

        info!(
            "Connecting to Meshtastic device: {:?}",
            meshtastic_config.connection_type
        );

        let state = Arc::new(Mutex::new(ClientState {
            connection_state: ConnectionState::Connecting,
            messages_sent: 0,
            messages_received: 0,
            last_error: None,
            chunk_reassembly: HashMap::new(),
        }));

        let (tx, rx) = mpsc::unbounded_channel();

        let node_id = Arc::new(Mutex::new(meshtastic_config.node_id));

        let client = Self {
            config: config.clone(),
            state: state.clone(),
            tx,
            node_id,
        };

        // Spawn connection task based on connection type
        let state_clone = state.clone();
        tokio::spawn(async move {
            if let Err(e) = Self::connection_task(config, state_clone, rx, callback).await {
                error!("Meshtastic connection task failed: {}", e);
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

    /// Send a CoT message over Meshtastic
    pub fn send_cot(&self, cot_xml: impl Into<String>) -> Result<()> {
        let xml = cot_xml.into();
        debug!("Sending CoT via Meshtastic: {}", xml);

        self.tx
            .send(ClientCommand::SendCot(xml))
            .context("Failed to send command")?;

        self.state.lock().messages_sent += 1;
        Ok(())
    }

    /// Disconnect from Meshtastic device
    pub fn disconnect(&self) {
        let _ = self.tx.send(ClientCommand::Disconnect);
    }

    async fn connection_task(
        config: ConnectionConfig,
        state: Arc<Mutex<ClientState>>,
        rx: mpsc::UnboundedReceiver<ClientCommand>,
        callback: Option<Box<dyn Fn(String) + Send + Sync>>,
    ) -> Result<()> {
        let meshtastic_config = config
            .meshtastic_config
            .as_ref()
            .ok_or_else(|| MeshtasticError::ConnectionFailed("Missing Meshtastic config".into()))?;

        match &meshtastic_config.connection_type {
            MeshtasticConnectionType::Serial(port) => {
                Self::serial_connection_task(port.clone(), state, rx, callback).await
            }
            MeshtasticConnectionType::Bluetooth(address) => {
                // Bluetooth support can be added later
                Err(MeshtasticError::ConnectionFailed(format!(
                    "Bluetooth not yet implemented: {}",
                    address
                ))
                .into())
            }
            MeshtasticConnectionType::Tcp => {
                Self::tcp_connection_task(config, state, rx, callback).await
            }
        }
    }

    async fn serial_connection_task(
        port_name: String,
        state: Arc<Mutex<ClientState>>,
        mut rx: mpsc::UnboundedReceiver<ClientCommand>,
        callback: Option<Box<dyn Fn(String) + Send + Sync>>,
    ) -> Result<()> {
        info!("Opening serial port: {}", port_name);

        // Open serial port
        let mut port = tokio_serial::new(&port_name, 38400)
            .open_native_async()
            .context("Failed to open serial port")?;

        info!("Serial connection established");
        state.lock().connection_state = ConnectionState::Connected;

        let mut buffer = BytesMut::with_capacity(8192);
        let mut read_buf = vec![0u8; 1024];

        loop {
            tokio::select! {
                // Read from serial port
                result = port.read(&mut read_buf) => {
                    match result {
                        Ok(n) if n > 0 => {
                            buffer.extend_from_slice(&read_buf[..n]);

                            // Process all complete frames in buffer
                            while let Some(from_radio) = Self::extract_frame(&mut buffer)? {
                                Self::handle_from_radio(from_radio, &state, &callback)?;
                            }
                        }
                        Ok(_) => {
                            warn!("Serial port closed");
                            break;
                        }
                        Err(e) => {
                            error!("Serial read error: {}", e);
                            state.lock().connection_state = ConnectionState::Failed;
                            return Err(e.into());
                        }
                    }
                }

                // Handle outgoing commands
                Some(cmd) = rx.recv() => {
                    match cmd {
                        ClientCommand::Send(data) => {
                            if let Err(e) = port.write_all(&data).await {
                                error!("Failed to write to serial port: {}", e);
                                state.lock().last_error = Some(e.to_string());
                            }
                        }
                        ClientCommand::SendCot(cot_xml) => {
                            match Self::cot_to_meshtastic(&cot_xml, None) {
                                Ok(packets) => {
                                    for packet in packets {
                                        let to_radio = ToRadio {
                                            payload_variant: Some(to_radio::PayloadVariant::Packet(packet)),
                                        };

                                        let frame = Self::encode_frame(&to_radio)?;
                                        if let Err(e) = port.write_all(&frame).await {
                                            error!("Failed to send CoT: {}", e);
                                            state.lock().last_error = Some(e.to_string());
                                        }
                                    }
                                }
                                Err(e) => {
                                    error!("Failed to convert CoT: {}", e);
                                    state.lock().last_error = Some(e.to_string());
                                }
                            }
                        }
                        ClientCommand::Disconnect => {
                            info!("Disconnecting from Meshtastic");
                            break;
                        }
                    }
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
        info!("Connecting to Meshtastic via TCP: {}:{}", config.host, config.port);

        let mut stream = TcpStream::connect(format!("{}:{}", config.host, config.port))
            .await
            .context("Failed to connect to Meshtastic TCP")?;

        info!("TCP connection established");
        state.lock().connection_state = ConnectionState::Connected;

        let (mut read_half, mut write_half) = stream.split();
        let mut buffer = BytesMut::with_capacity(8192);
        let mut read_buf = vec![0u8; 1024];

        loop {
            tokio::select! {
                result = read_half.read(&mut read_buf) => {
                    match result {
                        Ok(n) if n > 0 => {
                            buffer.extend_from_slice(&read_buf[..n]);

                            // Process all complete frames
                            while let Some(from_radio) = Self::extract_frame(&mut buffer)? {
                                Self::handle_from_radio(from_radio, &state, &callback)?;
                            }
                        }
                        Ok(_) => {
                            warn!("TCP connection closed");
                            break;
                        }
                        Err(e) => {
                            error!("TCP read error: {}", e);
                            state.lock().connection_state = ConnectionState::Failed;
                            return Err(e.into());
                        }
                    }
                }

                Some(cmd) = rx.recv() => {
                    match cmd {
                        ClientCommand::Send(data) => {
                            if let Err(e) = write_half.write_all(&data).await {
                                error!("Failed to write to TCP: {}", e);
                                state.lock().last_error = Some(e.to_string());
                            }
                        }
                        ClientCommand::SendCot(cot_xml) => {
                            match Self::cot_to_meshtastic(&cot_xml, None) {
                                Ok(packets) => {
                                    for packet in packets {
                                        let to_radio = ToRadio {
                                            payload_variant: Some(to_radio::PayloadVariant::Packet(packet)),
                                        };

                                        let frame = Self::encode_frame(&to_radio)?;
                                        if let Err(e) = write_half.write_all(&frame).await {
                                            error!("Failed to send CoT: {}", e);
                                            state.lock().last_error = Some(e.to_string());
                                        }
                                    }
                                }
                                Err(e) => {
                                    error!("Failed to convert CoT: {}", e);
                                    state.lock().last_error = Some(e.to_string());
                                }
                            }
                        }
                        ClientCommand::Disconnect => {
                            info!("Disconnecting from Meshtastic TCP");
                            break;
                        }
                    }
                }
            }
        }

        state.lock().connection_state = ConnectionState::Disconnected;
        Ok(())
    }

    /// Extract a complete frame from the buffer
    fn extract_frame(buffer: &mut BytesMut) -> Result<Option<FromRadio>> {
        // Look for frame start markers
        let mut start_idx = None;
        for i in 0..buffer.len().saturating_sub(3) {
            if buffer[i] == START1 && buffer[i + 1] == START2 {
                start_idx = Some(i);
                break;
            }
        }

        let start = match start_idx {
            Some(idx) => {
                // Discard any data before the frame start
                buffer.advance(idx);
                idx
            }
            None => {
                // Keep last byte in case it's START1
                if buffer.len() > 1 {
                    buffer.advance(buffer.len() - 1);
                }
                return Ok(None);
            }
        };

        // Check if we have the full header (4 bytes: START1, START2, MSB_LEN, LSB_LEN)
        if buffer.len() < 4 {
            return Ok(None);
        }

        // Extract length (big-endian)
        let len = u16::from_be_bytes([buffer[2], buffer[3]]) as usize;

        // Validate length
        if len > 512 {
            warn!("Invalid frame length: {}, skipping", len);
            buffer.advance(4);
            return Self::extract_frame(buffer);
        }

        // Check if we have the complete frame
        if buffer.len() < 4 + len {
            return Ok(None);
        }

        // Extract the frame payload
        buffer.advance(4); // Skip header
        let frame_data = buffer.split_to(len);

        // Decode protobuf
        let from_radio = FromRadio::decode(&frame_data[..])?;

        Ok(Some(from_radio))
    }

    /// Encode a ToRadio message as a frame
    fn encode_frame(to_radio: &ToRadio) -> Result<Vec<u8>> {
        let mut payload = Vec::new();
        to_radio.encode(&mut payload)?;

        let len = payload.len() as u16;
        let mut frame = Vec::with_capacity(4 + payload.len());

        // Add frame header
        frame.put_u8(START1);
        frame.put_u8(START2);
        frame.put_u16(len); // Big-endian length

        // Add payload
        frame.extend_from_slice(&payload);

        Ok(frame)
    }

    /// Handle incoming FromRadio message
    fn handle_from_radio(
        from_radio: FromRadio,
        state: &Arc<Mutex<ClientState>>,
        callback: &Option<Box<dyn Fn(String) + Send + Sync>>,
    ) -> Result<()> {
        if let Some(from_radio::PayloadVariant::Packet(packet)) = from_radio.payload_variant {
            debug!("Received mesh packet from node: {}", packet.from);

            state.lock().messages_received += 1;

            // Handle decoded packet
            if let Some(mesh_packet::PayloadVariant::Decoded(data)) = packet.payload_variant {
                // Check if this is a TAK packet
                if data.portnum() == PortNum::AtakForwarder || data.portnum() == PortNum::AtakPlugin
                {
                    if let Ok(cot_xml) = Self::meshtastic_to_cot(&data.payload, &packet) {
                        if let Some(ref cb) = callback {
                            cb(cot_xml);
                        }
                    }
                }
                // Handle position updates
                else if data.portnum() == PortNum::PositionApp {
                    if let Ok(position) = Position::decode(&data.payload[..]) {
                        if let Ok(cot_xml) = Self::position_to_cot(&position, packet.from) {
                            if let Some(ref cb) = callback {
                                cb(cot_xml);
                            }
                        }
                    }
                }
                // Handle text messages (GeoChat)
                else if data.portnum() == PortNum::TextMessageApp {
                    if let Ok(text) = String::from_utf8(data.payload.clone()) {
                        if let Ok(cot_xml) = Self::chat_to_cot(&text, packet.from) {
                            if let Some(ref cb) = callback {
                                cb(cot_xml);
                            }
                        }
                    }
                }
            }
        }

        Ok(())
    }

    /// Convert CoT XML to Meshtastic packet(s)
    pub fn cot_to_meshtastic(cot_xml: &str, dest_node: Option<u32>) -> Result<Vec<MeshPacket>> {
        // Parse CoT message
        let cot = CotMessage::from_xml(cot_xml)
            .map_err(|e| MeshtasticError::ConversionError(e.to_string()))?;

        // Create TAKPacket
        let tak_packet = tak_packet::PliLocation {
            latitude: cot.point.lat,
            longitude: cot.point.lon,
            altitude: cot.point.hae as i32,
            speed: 0.0,
            course: 0.0,
        };

        let tak_msg = TakPacket {
            is_compressed: false,
            contact_callsign: cot.uid.clone(),
            contact_uid: cot.uid.clone(),
            pli_location: Some(tak_packet),
            group: 0,
            status: 0,
            cot: cot_xml.as_bytes().to_vec(),
        };

        let mut payload = Vec::new();
        tak_msg.encode(&mut payload)?;

        // Check if we need to chunk the message
        if payload.len() <= MAX_DATA_SIZE {
            // Single packet
            let data = Data {
                portnum: PortNum::AtakForwarder.into(),
                payload,
                want_response: false,
                dest: dest_node.unwrap_or(0xFFFFFFFF),
                source: 0, // Will be set by device
                request_id: 0,
                reply_id: 0,
                emoji: 0,
            };

            let packet = MeshPacket {
                from: 0, // Will be set by device
                to: dest_node.unwrap_or(0xFFFFFFFF),
                channel: 0,
                payload_variant: Some(mesh_packet::PayloadVariant::Decoded(data)),
                id: rand::random(),
                rx_time: 0,
                rx_snr: 0.0,
                hop_limit: 3,
                want_ack: false,
                priority: Priority::Default.into(),
                rx_rssi: 0,
            };

            Ok(vec![packet])
        } else {
            // Need to chunk
            Self::chunk_payload(&payload, dest_node)
        }
    }

    /// Chunk a large payload into multiple packets
    fn chunk_payload(payload: &[u8], dest_node: Option<u32>) -> Result<Vec<MeshPacket>> {
        let chunk_size = MAX_DATA_SIZE - 20; // Leave room for ChunkedPayload overhead
        let chunk_count = (payload.len() + chunk_size - 1) / chunk_size;
        let payload_id: u32 = rand::random();

        let mut packets = Vec::new();

        for (i, chunk) in payload.chunks(chunk_size).enumerate() {
            let chunked = ChunkedPayload {
                payload_id,
                chunk_count: chunk_count as u32,
                chunk_index: i as u32,
                payload_chunk: chunk.to_vec(),
            };

            let mut chunk_data = Vec::new();
            chunked.encode(&mut chunk_data)?;

            let data = Data {
                portnum: PortNum::AtakForwarder.into(),
                payload: chunk_data,
                want_response: false,
                dest: dest_node.unwrap_or(0xFFFFFFFF),
                source: 0,
                request_id: 0,
                reply_id: 0,
                emoji: 0,
            };

            let packet = MeshPacket {
                from: 0,
                to: dest_node.unwrap_or(0xFFFFFFFF),
                channel: 0,
                payload_variant: Some(mesh_packet::PayloadVariant::Decoded(data)),
                id: rand::random(),
                rx_time: 0,
                rx_snr: 0.0,
                hop_limit: 3,
                want_ack: true, // Request ack for chunked messages
                priority: Priority::Reliable.into(),
                rx_rssi: 0,
            };

            packets.push(packet);
        }

        Ok(packets)
    }

    /// Convert Meshtastic TAK packet to CoT XML
    fn meshtastic_to_cot(payload: &[u8], packet: &MeshPacket) -> Result<String> {
        // Try to decode as TAKPacket
        if let Ok(tak_packet) = TakPacket::decode(payload) {
            // If we have the full CoT, return it
            if !tak_packet.cot.is_empty() {
                return String::from_utf8(tak_packet.cot)
                    .map_err(|e| MeshtasticError::ConversionError(e.to_string()).into());
            }

            // Otherwise, reconstruct from PLI
            if let Some(pli) = tak_packet.pli_location {
                return Self::build_pli_cot(
                    &tak_packet.contact_uid,
                    &tak_packet.contact_callsign,
                    pli.latitude,
                    pli.longitude,
                    pli.altitude as f64,
                );
            }
        }

        Err(MeshtasticError::ConversionError("Failed to decode TAK packet".into()).into())
    }

    /// Convert Meshtastic Position to CoT XML
    fn position_to_cot(position: &Position, node_id: u32) -> Result<String> {
        let lat = position.latitude_i as f64 / 1e7;
        let lon = position.longitude_i as f64 / 1e7;
        let alt = position.altitude as f64;

        let uid = format!("MESHTASTIC-{}", node_id);
        let callsign = format!("Mesh-{:08X}", node_id);

        Self::build_pli_cot(&uid, &callsign, lat, lon, alt)
    }

    /// Convert text message to CoT GeoChat
    fn chat_to_cot(text: &str, from_node: u32) -> Result<String> {
        let uid = format!("MESHTASTIC-{}", from_node);
        let callsign = format!("Mesh-{:08X}", from_node);

        let now = chrono::Utc::now();
        let stale = now + chrono::Duration::minutes(10);

        let cot = format!(
            r#"<?xml version="1.0" encoding="UTF-8"?>
<event version="2.0" uid="{}" type="b-t-f" time="{}" start="{}" stale="{}" how="h-e">
    <point lat="0.0" lon="0.0" hae="0.0" ce="999999.0" le="999999.0" />
    <detail>
        <__chat id="{}" chatroom="All Chat Rooms">
            <chatgrp uid0="{}" uid1="All Chat Rooms" id="All Chat Rooms"/>
        </__chat>
        <link uid="{}" relation="p-p" type="a-f-G-U-C"/>
        <remarks source="BAO.F.ATAK.{}" time="{}">
            {}
        </remarks>
    </detail>
</event>"#,
            uuid::Uuid::new_v4(),
            now.to_rfc3339(),
            now.to_rfc3339(),
            stale.to_rfc3339(),
            uuid::Uuid::new_v4(),
            uid,
            uid,
            callsign,
            now.to_rfc3339(),
            text
        );

        Ok(cot)
    }

    /// Build a PLI (Position Location Information) CoT message
    fn build_pli_cot(
        uid: &str,
        callsign: &str,
        lat: f64,
        lon: f64,
        alt: f64,
    ) -> Result<String> {
        let now = chrono::Utc::now();
        let stale = now + chrono::Duration::minutes(5);

        let cot = format!(
            r#"<?xml version="1.0" encoding="UTF-8"?>
<event version="2.0" uid="{}" type="a-f-G-U-C" time="{}" start="{}" stale="{}" how="m-g">
    <point lat="{}" lon="{}" hae="{}" ce="10.0" le="10.0" />
    <detail>
        <contact callsign="{}" />
        <uid Droid="{}"/>
        <precisionlocation altsrc="???" geopointsrc="???"/>
        <track course="0.0" speed="0.0"/>
        <status battery="100"/>
    </detail>
</event>"#,
            uid,
            now.to_rfc3339(),
            now.to_rfc3339(),
            stale.to_rfc3339(),
            lat,
            lon,
            alt,
            callsign,
            callsign
        );

        Ok(cot)
    }
}

// Add rand crate for random IDs
use std::collections::hash_map::RandomState;
use std::hash::{BuildHasher, Hash, Hasher};

mod rand {
    use super::*;

    pub fn random<T: Hash + Default>() -> u32 {
        let s = RandomState::new();
        let mut hasher = s.build_hasher();
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
            .hash(&mut hasher);
        hasher.finish() as u32
    }
}
