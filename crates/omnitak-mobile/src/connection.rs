//! Connection management for mobile clients

use std::ffi::CString;
use std::os::raw::{c_int, c_void};
use std::sync::Arc;
use parking_lot::Mutex;
use tokio::runtime::Runtime;

use omnitak_core::{ConnectionConfig, Protocol, MeshtasticConfig, MeshtasticConnectionType};
use omnitak_client::TakClient;

use super::{ConnectionStatus, CotCallback};

/// Connection to a TAK server
pub struct Connection {
    id: u64,
    client: Option<TakClient>,
    state: Arc<Mutex<ConnectionState>>,
    callback: Arc<Mutex<Option<CallbackInfo>>>,
}

#[derive(Debug)]
struct ConnectionState {
    is_connected: bool,
    messages_sent: u64,
    messages_received: u64,
    last_error: Option<String>,
}

struct CallbackInfo {
    callback: CotCallback,
    user_data: *mut c_void,
}

// CallbackInfo must be Send because it's shared across threads
unsafe impl Send for CallbackInfo {}
unsafe impl Sync for CallbackInfo {}

impl Connection {
    /// Create a new Meshtastic connection
    pub fn new_meshtastic(
        id: u64,
        runtime: &Runtime,
        connection_type: MeshtasticConnectionType,
        node_id: Option<u32>,
        device_name: Option<String>,
    ) -> Result<Self, Box<dyn std::error::Error>> {
        tracing::info!(
            "Creating Meshtastic connection {} (type={:?}, node_id={:?})",
            id,
            connection_type,
            node_id
        );

        let state = Arc::new(Mutex::new(ConnectionState {
            is_connected: false,
            messages_sent: 0,
            messages_received: 0,
            last_error: None,
        }));

        let callback: Arc<Mutex<Option<CallbackInfo>>> = Arc::new(Mutex::new(None));

        // Create Meshtastic config
        let meshtastic_config = MeshtasticConfig {
            connection_type,
            node_id,
            device_name,
        };

        let config = ConnectionConfig::new_meshtastic(meshtastic_config);

        // Create callback wrapper
        let callback_clone = callback.clone();
        let connection_id = id;
        let state_clone = state.clone();

        let callback_fn = Box::new(move |cot_xml: String| {
            // Update received count
            state_clone.lock().messages_received += 1;

            // Invoke user callback if registered
            let cb = callback_clone.lock();
            if let Some(ref cb_info) = *cb {
                if let Ok(c_xml) = CString::new(cot_xml) {
                    unsafe {
                        (cb_info.callback)(cb_info.user_data, connection_id, c_xml.as_ptr());
                    }
                }
            }
        });

        // Connect to Meshtastic device
        let client = runtime.block_on(async {
            TakClient::connect(config, Some(callback_fn)).await
        })?;

        // Update state
        state.lock().is_connected = true;

        Ok(Self {
            id,
            client: Some(client),
            state,
            callback,
        })
    }

    pub fn new(
        id: u64,
        runtime: &Runtime,
        host: String,
        port: u16,
        protocol: c_int,
        use_tls: bool,
        cert: Option<String>,
        key: Option<String>,
        ca: Option<String>,
    ) -> Result<Self, Box<dyn std::error::Error>> {
        let protocol = match protocol {
            1 => Protocol::Udp,
            2 => Protocol::Tls,
            3 => Protocol::WebSocket,
            4 => Protocol::Meshtastic,
            _ => Protocol::Tcp,
        };

        tracing::info!(
            "Creating connection {} to {}:{} (protocol={:?}, tls={})",
            id,
            host,
            port,
            protocol,
            use_tls
        );

        let state = Arc::new(Mutex::new(ConnectionState {
            is_connected: false,
            messages_sent: 0,
            messages_received: 0,
            last_error: None,
        }));

        let callback: Arc<Mutex<Option<CallbackInfo>>> = Arc::new(Mutex::new(None));

        // Create connection config
        let config = if use_tls || protocol == Protocol::Tls {
            ConnectionConfig::new(host, port, protocol).with_tls(cert, key, ca)
        } else {
            ConnectionConfig::new(host, port, protocol)
        };

        // Create callback wrapper
        let callback_clone = callback.clone();
        let connection_id = id;
        let state_clone = state.clone();

        let callback_fn = Box::new(move |cot_xml: String| {
            // Update received count
            state_clone.lock().messages_received += 1;

            // Invoke user callback if registered
            let cb = callback_clone.lock();
            if let Some(ref cb_info) = *cb {
                if let Ok(c_xml) = CString::new(cot_xml) {
                    unsafe {
                        (cb_info.callback)(cb_info.user_data, connection_id, c_xml.as_ptr());
                    }
                }
            }
        });

        // Connect to server
        let client = runtime.block_on(async {
            TakClient::connect(config, Some(callback_fn)).await
        })?;

        // Update state
        state.lock().is_connected = true;

        Ok(Self {
            id,
            client: Some(client),
            state,
            callback,
        })
    }

    pub fn send_cot(&self, xml: &str) -> bool {
        tracing::debug!("Connection {}: Sending CoT: {}", self.id, xml);

        if let Some(ref client) = self.client {
            match client.send_cot(xml) {
                Ok(_) => {
                    self.state.lock().messages_sent += 1;
                    true
                }
                Err(e) => {
                    tracing::error!("Failed to send CoT: {}", e);
                    self.state.lock().last_error = Some(e.to_string());
                    false
                }
            }
        } else {
            tracing::error!("Connection {} not initialized", self.id);
            false
        }
    }

    pub fn set_callback(&mut self, callback: Option<CotCallback>, user_data: *mut c_void) {
        let mut cb = self.callback.lock();
        *cb = callback.map(|c| CallbackInfo {
            callback: c,
            user_data,
        });
    }

    pub fn get_status(&self) -> ConnectionStatus {
        let state = self.state.lock();

        // Get client state if available
        let (is_connected, messages_sent, messages_received) = if let Some(ref client) = self.client {
            (
                client.state() == omnitak_core::ConnectionState::Connected,
                client.messages_sent(),
                client.messages_received(),
            )
        } else {
            (state.is_connected, state.messages_sent, state.messages_received)
        };

        ConnectionStatus {
            is_connected: if is_connected { 1 } else { 0 },
            messages_sent,
            messages_received,
            last_error_code: if state.last_error.is_some() { -1 } else { 0 },
        }
    }
}

impl Drop for Connection {
    fn drop(&mut self) {
        tracing::info!("Dropping connection {}", self.id);
        if let Some(client) = self.client.take() {
            client.disconnect();
        }
    }
}
