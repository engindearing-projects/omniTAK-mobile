//! Connection management for mobile clients

use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int, c_void};
use std::sync::Arc;
use parking_lot::Mutex;

use super::{ConnectionStatus, CotCallback};

/// Connection to a TAK server
pub struct Connection {
    id: u64,
    host: String,
    port: u16,
    protocol: Protocol,
    use_tls: bool,
    state: Arc<Mutex<ConnectionState>>,
    callback: Arc<Mutex<Option<CallbackInfo>>>,
}

#[derive(Debug, Clone, Copy)]
pub enum Protocol {
    Tcp = 0,
    Udp = 1,
    Tls = 2,
    WebSocket = 3,
}

impl From<c_int> for Protocol {
    fn from(value: c_int) -> Self {
        match value {
            1 => Protocol::Udp,
            2 => Protocol::Tls,
            3 => Protocol::WebSocket,
            _ => Protocol::Tcp,
        }
    }
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
    pub fn new(
        id: u64,
        host: String,
        port: u16,
        protocol: c_int,
        use_tls: bool,
        _cert: Option<String>,
        _key: Option<String>,
        _ca: Option<String>,
    ) -> Result<Self, Box<dyn std::error::Error>> {
        let protocol = Protocol::from(protocol);

        tracing::info!(
            "Creating connection {} to {}:{} (protocol={:?}, tls={})",
            id,
            host,
            port,
            protocol,
            use_tls
        );

        Ok(Self {
            id,
            host,
            port,
            protocol,
            use_tls,
            state: Arc::new(Mutex::new(ConnectionState {
                is_connected: false,
                messages_sent: 0,
                messages_received: 0,
                last_error: None,
            })),
            callback: Arc::new(Mutex::new(None)),
        })
    }

    pub fn send_cot(&self, xml: &str) -> bool {
        tracing::debug!("Connection {}: Sending CoT: {}", self.id, xml);

        // TODO: Implement actual sending via omnitak-client
        // For now, just update counter
        let mut state = self.state.lock();
        state.messages_sent += 1;

        true
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
        ConnectionStatus {
            is_connected: if state.is_connected { 1 } else { 0 },
            messages_sent: state.messages_sent,
            messages_received: state.messages_received,
            last_error_code: if state.last_error.is_some() { -1 } else { 0 },
        }
    }

    /// Simulate receiving a CoT message (for testing)
    /// In production, this would be called by background thread receiving data
    pub fn simulate_receive(&self, cot_xml: &str) {
        let mut state = self.state.lock();
        state.messages_received += 1;
        drop(state);

        // Invoke callback if registered
        let callback_info = self.callback.lock().clone();
        if let Some(cb_info) = callback_info.as_ref() {
            // Convert to C string
            if let Ok(c_xml) = CString::new(cot_xml) {
                unsafe {
                    (cb_info.callback)(cb_info.user_data, self.id, c_xml.as_ptr());
                }
            }
        }
    }
}

// Need Clone for CallbackInfo
impl Clone for CallbackInfo {
    fn clone(&self) -> Self {
        Self {
            callback: self.callback,
            user_data: self.user_data,
        }
    }
}

impl Drop for Connection {
    fn drop(&mut self) {
        tracing::info!("Dropping connection {} to {}:{}", self.id, self.host, self.port);
    }
}
