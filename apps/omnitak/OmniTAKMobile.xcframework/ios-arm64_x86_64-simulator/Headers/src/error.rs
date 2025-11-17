//! Error types for mobile FFI

use thiserror::Error;

#[derive(Error, Debug)]
pub enum MobileError {
    #[error("Not initialized")]
    NotInitialized,

    #[error("Connection not found: {0}")]
    ConnectionNotFound(u64),

    #[error("Invalid parameter: {0}")]
    InvalidParameter(String),

    #[error("Connection error: {0}")]
    ConnectionError(String),

    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),

    #[error("Serialization error: {0}")]
    SerializationError(String),

    #[error("Runtime error: {0}")]
    RuntimeError(String),
}

/// Result type for mobile operations
pub type Result<T> = std::result::Result<T, MobileError>;

/// Convert MobileError to C error code
impl MobileError {
    pub fn to_error_code(&self) -> i32 {
        match self {
            MobileError::NotInitialized => -1,
            MobileError::ConnectionNotFound(_) => -2,
            MobileError::InvalidParameter(_) => -3,
            MobileError::ConnectionError(_) => -4,
            MobileError::IoError(_) => -5,
            MobileError::SerializationError(_) => -6,
            MobileError::RuntimeError(_) => -7,
        }
    }
}
