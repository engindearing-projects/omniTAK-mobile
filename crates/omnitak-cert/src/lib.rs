//! # OmniTAK Certificate Management
//!
//! Certificate and TLS configuration handling

use anyhow::{Context, Result};
use rustls::{Certificate, ClientConfig, PrivateKey, RootCertStore};
use rustls_pemfile::{certs, pkcs8_private_keys};
use std::io::BufReader;
use std::sync::Arc;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum CertError {
    #[error("Invalid certificate PEM")]
    InvalidCertPem,

    #[error("Invalid key PEM")]
    InvalidKeyPem,

    #[error("Invalid CA certificate PEM")]
    InvalidCaPem,

    #[error("No certificates found in PEM")]
    NoCertsFound,

    #[error("No private keys found in PEM")]
    NoKeysFound,

    #[error("TLS configuration error: {0}")]
    TlsConfig(String),
}

/// TLS certificate bundle
#[derive(Debug, Clone)]
pub struct CertBundle {
    /// Client certificate PEM
    pub cert_pem: Option<String>,
    /// Client private key PEM
    pub key_pem: Option<String>,
    /// CA certificate PEM
    pub ca_pem: Option<String>,
}

impl CertBundle {
    /// Create a new certificate bundle
    pub fn new(
        cert_pem: Option<String>,
        key_pem: Option<String>,
        ca_pem: Option<String>,
    ) -> Self {
        Self {
            cert_pem,
            key_pem,
            ca_pem,
        }
    }

    /// Check if bundle has client certificates
    pub fn has_client_cert(&self) -> bool {
        self.cert_pem.is_some() && self.key_pem.is_some()
    }

    /// Check if bundle has CA certificate
    pub fn has_ca(&self) -> bool {
        self.ca_pem.is_some()
    }
}

/// Build a TLS client configuration
pub fn build_tls_config(bundle: &CertBundle) -> Result<Arc<ClientConfig>> {
    let mut root_store = RootCertStore::empty();

    // Add CA certificates
    if let Some(ca_pem) = &bundle.ca_pem {
        let ca_certs = parse_certs(ca_pem.as_bytes())
            .context("Failed to parse CA certificates")?;
        for cert in ca_certs {
            root_store
                .add(&cert)
                .map_err(|e| CertError::TlsConfig(format!("Failed to add CA cert: {}", e)))?;
        }
    } else {
        // Use system root certificates
        root_store.add_trust_anchors(webpki_roots::TLS_SERVER_ROOTS.iter().map(|ta| {
            rustls::OwnedTrustAnchor::from_subject_spki_name_constraints(
                ta.subject,
                ta.spki,
                ta.name_constraints,
            )
        }));
    }

    let config = ClientConfig::builder()
        .with_safe_defaults()
        .with_root_certificates(root_store);

    // Add client certificate if present
    let config = if bundle.has_client_cert() {
        let cert_pem = bundle.cert_pem.as_ref().unwrap();
        let key_pem = bundle.key_pem.as_ref().unwrap();

        let certs = parse_certs(cert_pem.as_bytes())
            .context("Failed to parse client certificate")?;
        let mut keys = parse_keys(key_pem.as_bytes())
            .context("Failed to parse private key")?;

        if keys.is_empty() {
            return Err(CertError::NoKeysFound.into());
        }

        config
            .with_client_auth_cert(certs, keys.remove(0))
            .map_err(|e| CertError::TlsConfig(format!("Failed to set client cert: {}", e)))?
    } else {
        config.with_no_client_auth()
    };

    Ok(Arc::new(config))
}

/// Parse PEM certificates
fn parse_certs(pem: &[u8]) -> Result<Vec<Certificate>> {
    let mut reader = BufReader::new(pem);
    let certs: Vec<Certificate> = certs(&mut reader)
        .map_err(|_| CertError::InvalidCertPem)?
        .into_iter()
        .map(Certificate)
        .collect();

    if certs.is_empty() {
        return Err(CertError::NoCertsFound.into());
    }

    Ok(certs)
}

/// Parse PEM private keys
fn parse_keys(pem: &[u8]) -> Result<Vec<PrivateKey>> {
    let mut reader = BufReader::new(pem);
    let keys: Vec<PrivateKey> = pkcs8_private_keys(&mut reader)
        .map_err(|_| CertError::InvalidKeyPem)?
        .into_iter()
        .map(PrivateKey)
        .collect();

    Ok(keys)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cert_bundle() {
        let bundle = CertBundle::new(Some("cert".to_string()), Some("key".to_string()), None);
        assert!(bundle.has_client_cert());
        assert!(!bundle.has_ca());
    }

    #[test]
    fn test_cert_bundle_empty() {
        let bundle = CertBundle::new(None, None, None);
        assert!(!bundle.has_client_cert());
        assert!(!bundle.has_ca());
    }
}
