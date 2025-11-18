//! Error types for the TAK server

use thiserror::Error;

pub type Result<T> = std::result::Result<T, ServerError>;

#[derive(Error, Debug)]
pub enum ServerError {
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("TLS error: {0}")]
    Tls(String),

    #[error("Client error: {0}")]
    Client(String),

    #[error("CoT parsing error: {0}")]
    CotParse(String),

    #[error("Configuration error: {0}")]
    Config(String),

    #[error("Marti API error: {0}")]
    Marti(String),

    #[error("Certificate error: {0}")]
    Certificate(String),

    #[error("Connection closed")]
    ConnectionClosed,

    #[error("Server not running")]
    NotRunning,

    #[error(transparent)]
    Other(#[from] anyhow::Error),
}
