//! # OmniTAK Mobile FFI Bridge
//!
//! Cross-platform FFI interface for iOS and Android integration.
//! Exposes C-compatible functions for TAK server connections and CoT messaging.
//!
//! ## Architecture
//!
//! - Static library (.a) for iOS (linked into Swift/Objective-C)
//! - Dynamic library (.so) for Android (loaded via JNI)
//! - Thread-safe connection management with tokio runtime
//! - Callback-based async event handling

use std::ffi::CStr;
use std::os::raw::{c_char, c_int, c_void};
use std::sync::Arc;
use parking_lot::Mutex;
use dashmap::DashMap;
use tokio::runtime::Runtime;

mod connection;
mod callbacks;
mod error;
mod enrollment_ffi;

pub use connection::*;
pub use callbacks::*;
pub use error::*;
pub use enrollment_ffi::*;

/// Global state management
pub struct OmniTAKMobile {
    runtime: Runtime,
    connections: Arc<DashMap<u64, Connection>>,
    next_id: Arc<Mutex<u64>>,
}

lazy_static::lazy_static! {
    static ref GLOBAL: Mutex<Option<OmniTAKMobile>> = Mutex::new(None);
}

/// Initialize the omniTAK mobile library
///
/// Must be called before any other functions.
/// Safe to call multiple times (subsequent calls are no-op).
///
/// # Safety
/// This function is thread-safe and can be called from any thread.
#[no_mangle]
pub extern "C" fn omnitak_init() -> c_int {
    let mut global = GLOBAL.lock();
    if global.is_some() {
        return 0; // Already initialized
    }

    match Runtime::new() {
        Ok(runtime) => {
            *global = Some(OmniTAKMobile {
                runtime,
                connections: Arc::new(DashMap::new()),
                next_id: Arc::new(Mutex::new(1)),
            });
            0 // Success
        }
        Err(e) => {
            eprintln!("Failed to initialize omniTAK mobile: {}", e);
            -1 // Error
        }
    }
}

/// Shutdown the omniTAK mobile library
///
/// Disconnects all connections and cleans up resources.
///
/// # Safety
/// Should be called when the app is shutting down.
/// No omnitak_* functions should be called after this.
#[no_mangle]
pub extern "C" fn omnitak_shutdown() {
    let mut global = GLOBAL.lock();
    if let Some(omnitak) = global.take() {
        // Disconnect all connections
        omnitak.connections.clear();
        // Runtime will be dropped automatically
    }
}

/// Connect to a TAK server
///
/// # Parameters
/// - `host`: Null-terminated C string with hostname or IP
/// - `port`: Server port number
/// - `protocol`: Protocol type (0=TCP, 1=UDP, 2=TLS, 3=WebSocket)
/// - `use_tls`: Whether to use TLS (1=yes, 0=no)
/// - `cert_pem`: Optional PEM-encoded certificate (null for none)
/// - `key_pem`: Optional PEM-encoded private key (null for none)
/// - `ca_pem`: Optional PEM-encoded CA cert (null for none)
///
/// # Returns
/// Connection ID on success, 0 on failure
///
/// # Safety
/// - All string pointers must be valid null-terminated C strings or null
/// - Strings must remain valid for duration of call
#[no_mangle]
pub unsafe extern "C" fn omnitak_connect(
    host: *const c_char,
    port: u16,
    protocol: c_int,
    use_tls: c_int,
    cert_pem: *const c_char,
    key_pem: *const c_char,
    ca_pem: *const c_char,
) -> u64 {
    if host.is_null() {
        eprintln!("omnitak_connect: host is null");
        return 0;
    }

    let host_str = match CStr::from_ptr(host).to_str() {
        Ok(s) => s.to_string(),
        Err(e) => {
            eprintln!("omnitak_connect: invalid host string: {}", e);
            return 0;
        }
    };

    let cert = if !cert_pem.is_null() {
        Some(CStr::from_ptr(cert_pem).to_str().unwrap_or("").to_string())
    } else {
        None
    };

    let key = if !key_pem.is_null() {
        Some(CStr::from_ptr(key_pem).to_str().unwrap_or("").to_string())
    } else {
        None
    };

    let ca = if !ca_pem.is_null() {
        Some(CStr::from_ptr(ca_pem).to_str().unwrap_or("").to_string())
    } else {
        None
    };

    let mut global = GLOBAL.lock();
    if let Some(omnitak) = global.as_mut() {
        let connection_id = {
            let mut next_id = omnitak.next_id.lock();
            let id = *next_id;
            *next_id += 1;
            id
        };

        match Connection::new(
            connection_id,
            &omnitak.runtime,
            host_str,
            port,
            protocol,
            use_tls != 0,
            cert,
            key,
            ca,
        ) {
            Ok(conn) => {
                omnitak.connections.insert(connection_id, conn);
                connection_id
            }
            Err(e) => {
                eprintln!("Failed to create connection: {}", e);
                0
            }
        }
    } else {
        eprintln!("omnitak_connect: library not initialized");
        0
    }
}

/// Connect to a Meshtastic device
///
/// # Parameters
/// - `connection_type`: Connection type (0=Serial, 1=Bluetooth, 2=TCP)
/// - `device_path`: For Serial: device path (e.g., "/dev/ttyUSB0", "COM3")
///                  For Bluetooth: device address (e.g., "00:11:22:33:44:55")
///                  For TCP: hostname/IP
/// - `port`: Port number (for TCP connections, 0 for Serial/Bluetooth)
/// - `node_id`: Optional destination node ID (0 for broadcast to all nodes)
/// - `device_name`: Optional device name for display (null for auto)
///
/// # Returns
/// Connection ID on success, 0 on failure
///
/// # Safety
/// - `device_path` must be a valid null-terminated C string
/// - `device_name` must be a valid null-terminated C string or null
#[no_mangle]
pub unsafe extern "C" fn omnitak_connect_meshtastic(
    connection_type: c_int,
    device_path: *const c_char,
    port: u16,
    node_id: u32,
    device_name: *const c_char,
) -> u64 {
    use omnitak_core::MeshtasticConnectionType;

    if device_path.is_null() {
        eprintln!("omnitak_connect_meshtastic: device_path is null");
        return 0;
    }

    let device_path_str = match CStr::from_ptr(device_path).to_str() {
        Ok(s) => s.to_string(),
        Err(e) => {
            eprintln!("omnitak_connect_meshtastic: invalid device_path string: {}", e);
            return 0;
        }
    };

    let device_name_opt = if !device_name.is_null() {
        Some(CStr::from_ptr(device_name).to_str().unwrap_or("").to_string())
    } else {
        None
    };

    let conn_type = match connection_type {
        0 => MeshtasticConnectionType::Serial(device_path_str.clone()),
        1 => MeshtasticConnectionType::Bluetooth(device_path_str.clone()),
        2 => MeshtasticConnectionType::Tcp,
        _ => {
            eprintln!("omnitak_connect_meshtastic: invalid connection_type: {}", connection_type);
            return 0;
        }
    };

    let mut global = GLOBAL.lock();
    if let Some(omnitak) = global.as_mut() {
        let connection_id = {
            let mut next_id = omnitak.next_id.lock();
            let id = *next_id;
            *next_id += 1;
            id
        };

        let node_id_opt = if node_id == 0 { None } else { Some(node_id) };

        match Connection::new_meshtastic(
            connection_id,
            &omnitak.runtime,
            conn_type,
            node_id_opt,
            device_name_opt,
        ) {
            Ok(conn) => {
                omnitak.connections.insert(connection_id, conn);
                connection_id
            }
            Err(e) => {
                eprintln!("Failed to create Meshtastic connection: {}", e);
                0
            }
        }
    } else {
        eprintln!("omnitak_connect_meshtastic: library not initialized");
        0
    }
}

/// Disconnect from a TAK server
///
/// # Parameters
/// - `connection_id`: Connection ID returned from omnitak_connect
///
/// # Returns
/// 0 on success, -1 on error
#[no_mangle]
pub extern "C" fn omnitak_disconnect(connection_id: u64) -> c_int {
    let global = GLOBAL.lock();
    if let Some(omnitak) = global.as_ref() {
        if omnitak.connections.remove(&connection_id).is_some() {
            0 // Success
        } else {
            eprintln!("omnitak_disconnect: connection {} not found", connection_id);
            -1
        }
    } else {
        eprintln!("omnitak_disconnect: library not initialized");
        -1
    }
}

/// Send a CoT message to the server
///
/// # Parameters
/// - `connection_id`: Connection ID
/// - `cot_xml`: Null-terminated C string containing CoT XML
///
/// # Returns
/// 0 on success, -1 on error
///
/// # Safety
/// `cot_xml` must be a valid null-terminated C string
#[no_mangle]
pub unsafe extern "C" fn omnitak_send_cot(
    connection_id: u64,
    cot_xml: *const c_char,
) -> c_int {
    if cot_xml.is_null() {
        eprintln!("omnitak_send_cot: cot_xml is null");
        return -1;
    }

    let xml_str = match CStr::from_ptr(cot_xml).to_str() {
        Ok(s) => s,
        Err(e) => {
            eprintln!("omnitak_send_cot: invalid XML string: {}", e);
            return -1;
        }
    };

    let global = GLOBAL.lock();
    if let Some(omnitak) = global.as_ref() {
        if let Some(conn) = omnitak.connections.get(&connection_id) {
            if conn.send_cot(xml_str) {
                0
            } else {
                -1
            }
        } else {
            eprintln!("omnitak_send_cot: connection {} not found", connection_id);
            -1
        }
    } else {
        eprintln!("omnitak_send_cot: library not initialized");
        -1
    }
}

/// Callback function type for receiving CoT messages
///
/// # Parameters
/// - `user_data`: Opaque pointer passed to omnitak_register_callback
/// - `connection_id`: Connection that received the message
/// - `cot_xml`: Null-terminated C string containing CoT XML
pub type CotCallback = extern "C" fn(
    user_data: *mut c_void,
    connection_id: u64,
    cot_xml: *const c_char,
);

/// Register a callback for receiving CoT messages
///
/// # Parameters
/// - `connection_id`: Connection ID
/// - `callback`: Function to call when CoT received
/// - `user_data`: Opaque pointer passed to callback
///
/// # Returns
/// 0 on success, -1 on error
///
/// # Safety
/// - `callback` must be a valid function pointer
/// - `user_data` must remain valid until callback is unregistered
/// - Callback will be called from background thread
#[no_mangle]
pub unsafe extern "C" fn omnitak_register_callback(
    connection_id: u64,
    callback: CotCallback,
    user_data: *mut c_void,
) -> c_int {
    let global = GLOBAL.lock();
    if let Some(omnitak) = global.as_ref() {
        if let Some(mut conn) = omnitak.connections.get_mut(&connection_id) {
            conn.set_callback(Some(callback), user_data);
            0
        } else {
            eprintln!("omnitak_register_callback: connection {} not found", connection_id);
            -1
        }
    } else {
        eprintln!("omnitak_register_callback: library not initialized");
        -1
    }
}

/// Unregister CoT callback
///
/// # Parameters
/// - `connection_id`: Connection ID
///
/// # Returns
/// 0 on success, -1 on error
#[no_mangle]
pub extern "C" fn omnitak_unregister_callback(connection_id: u64) -> c_int {
    let global = GLOBAL.lock();
    if let Some(omnitak) = global.as_ref() {
        if let Some(mut conn) = omnitak.connections.get_mut(&connection_id) {
            conn.set_callback(None, std::ptr::null_mut());
            0
        } else {
            -1
        }
    } else {
        -1
    }
}

/// Get connection status
///
/// # Parameters
/// - `connection_id`: Connection ID
/// - `status_out`: Pointer to ConnectionStatus struct to fill
///
/// # Returns
/// 0 on success, -1 on error
///
/// # Safety
/// `status_out` must be a valid pointer to ConnectionStatus
#[repr(C)]
pub struct ConnectionStatus {
    pub is_connected: c_int,
    pub messages_sent: u64,
    pub messages_received: u64,
    pub last_error_code: c_int,
}

#[no_mangle]
pub unsafe extern "C" fn omnitak_get_status(
    connection_id: u64,
    status_out: *mut ConnectionStatus,
) -> c_int {
    if status_out.is_null() {
        return -1;
    }

    let global = GLOBAL.lock();
    if let Some(omnitak) = global.as_ref() {
        if let Some(conn) = omnitak.connections.get(&connection_id) {
            let status = conn.get_status();
            *status_out = status;
            0
        } else {
            -1
        }
    } else {
        -1
    }
}

/// Get library version string
///
/// Returns a null-terminated C string with version.
/// String is statically allocated and does not need to be freed.
#[no_mangle]
pub extern "C" fn omnitak_version() -> *const c_char {
    static VERSION: &str = concat!(env!("CARGO_PKG_VERSION"), "\0");
    VERSION.as_ptr() as *const c_char
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_init_shutdown() {
        assert_eq!(omnitak_init(), 0);
        omnitak_shutdown();
    }

    #[test]
    fn test_version() {
        let version = unsafe { CStr::from_ptr(omnitak_version()) };
        assert!(version.to_str().unwrap().starts_with("0."));
    }
}
