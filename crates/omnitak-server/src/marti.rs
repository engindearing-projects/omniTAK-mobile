//! Marti API endpoints
//!
//! Implements TAK server Marti API for compatibility with official clients

use axum::{
    extract::State,
    routing::get,
    Json, Router,
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;

/// Marti API server state
#[derive(Clone)]
pub struct MartiState {
    pub server_version: String,
}

/// Create Marti API router
pub fn create_router() -> Router {
    let state = MartiState {
        server_version: crate::VERSION.to_string(),
    };

    Router::new()
        .route("/Marti/api/version", get(get_version))
        .route("/Marti/api/clientEndPoints", get(get_client_endpoints))
        .route("/Marti/api/tls/config", get(get_tls_config))
        .with_state(Arc::new(state))
}

/// Get server version
async fn get_version(State(state): State<Arc<MartiState>>) -> Json<VersionResponse> {
    Json(VersionResponse {
        version: state.server_version.clone(),
        r#type: "OmniTAK-Server".to_string(),
        api: "2".to_string(),
        hostname: std::env::var("HOSTNAME").unwrap_or_else(|_| "omnitak-server".to_string()),
    })
}

/// Get connected client endpoints
async fn get_client_endpoints() -> Json<ClientEndpointsResponse> {
    // TODO: Return actual connected clients
    Json(ClientEndpointsResponse {
        clients: vec![],
    })
}

/// Get TLS configuration
async fn get_tls_config() -> Json<TlsConfigResponse> {
    Json(TlsConfigResponse {
        tls_enabled: false,
        client_auth_required: false,
    })
}

/// Version response
#[derive(Debug, Serialize, Deserialize)]
pub struct VersionResponse {
    pub version: String,
    pub r#type: String,
    pub api: String,
    pub hostname: String,
}

/// Client endpoints response
#[derive(Debug, Serialize, Deserialize)]
pub struct ClientEndpointsResponse {
    pub clients: Vec<ClientEndpoint>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ClientEndpoint {
    pub uid: String,
    pub callsign: String,
    pub ip: String,
    pub port: u16,
}

/// TLS configuration response
#[derive(Debug, Serialize, Deserialize)]
pub struct TlsConfigResponse {
    pub tls_enabled: bool,
    pub client_auth_required: bool,
}
