//! # OmniTAK CoT
//!
//! Cursor on Target (CoT) message parsing and generation

use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::fmt;
use uuid::Uuid;

/// CoT message
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CotMessage {
    /// Message UID
    pub uid: String,
    /// Event type (e.g., "a-f-G-U-C" for friendly ground unit)
    pub event_type: String,
    /// How the data was generated
    pub how: String,
    /// When the event was generated
    pub time: DateTime<Utc>,
    /// When the event starts
    pub start: DateTime<Utc>,
    /// When the event becomes stale
    pub stale: DateTime<Utc>,
    /// Point location
    pub point: Point,
    /// Additional detail information
    pub detail: Option<String>,
}

/// Geographic point
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct Point {
    /// Latitude in degrees
    pub lat: f64,
    /// Longitude in degrees
    pub lon: f64,
    /// Height above ellipsoid in meters
    pub hae: f64,
    /// Circular error in meters
    pub ce: f64,
    /// Linear error in meters
    pub le: f64,
}

impl CotMessage {
    /// Create a new CoT message
    pub fn new(uid: impl Into<String>, event_type: impl Into<String>, point: Point) -> Self {
        let now = Utc::now();
        let stale = now + chrono::Duration::minutes(1);

        Self {
            uid: uid.into(),
            event_type: event_type.into(),
            how: "m-g".to_string(), // machine-generated
            time: now,
            start: now,
            stale,
            point,
            detail: None,
        }
    }

    /// Create a CoT message with a random UID
    pub fn with_random_uid(event_type: impl Into<String>, point: Point) -> Self {
        let uid = Uuid::new_v4().to_string();
        Self::new(uid, event_type, point)
    }

    /// Set the detail section
    pub fn with_detail(mut self, detail: impl Into<String>) -> Self {
        self.detail = Some(detail.into());
        self
    }

    /// Set the stale time
    pub fn with_stale(mut self, stale: DateTime<Utc>) -> Self {
        self.stale = stale;
        self
    }

    /// Convert to XML string
    pub fn to_xml(&self) -> Result<String> {
        let time_str = self.time.to_rfc3339_opts(chrono::SecondsFormat::Millis, true);
        let start_str = self.start.to_rfc3339_opts(chrono::SecondsFormat::Millis, true);
        let stale_str = self.stale.to_rfc3339_opts(chrono::SecondsFormat::Millis, true);

        let mut xml = format!(
            r#"<?xml version="1.0" encoding="UTF-8"?><event version="2.0" uid="{}" type="{}" how="{}" time="{}" start="{}" stale="{}"><point lat="{}" lon="{}" hae="{}" ce="{}" le="{}"/>"#,
            self.uid,
            self.event_type,
            self.how,
            time_str,
            start_str,
            stale_str,
            self.point.lat,
            self.point.lon,
            self.point.hae,
            self.point.ce,
            self.point.le
        );

        if let Some(detail) = &self.detail {
            xml.push_str("<detail>");
            xml.push_str(detail);
            xml.push_str("</detail>");
        }

        xml.push_str("</event>");

        Ok(xml)
    }

    /// Parse from XML string
    pub fn from_xml(xml: &str) -> Result<Self> {
        // Basic XML parsing - in production, use quick-xml for robust parsing
        // For now, we'll implement a simple parser

        let uid = extract_attribute(xml, "uid")?;
        let event_type = extract_attribute(xml, "type")?;
        let how = extract_attribute(xml, "how").unwrap_or_else(|_| "h-e".to_string());
        let time = parse_datetime(&extract_attribute(xml, "time")?)?;
        let start = parse_datetime(&extract_attribute(xml, "start")?)?;
        let stale = parse_datetime(&extract_attribute(xml, "stale")?)?;

        // Extract point attributes
        let lat = extract_point_attribute(xml, "lat")?.parse::<f64>()
            .context("Invalid latitude")?;
        let lon = extract_point_attribute(xml, "lon")?.parse::<f64>()
            .context("Invalid longitude")?;
        let hae = extract_point_attribute(xml, "hae")?.parse::<f64>()
            .context("Invalid HAE")?;
        let ce = extract_point_attribute(xml, "ce")?.parse::<f64>()
            .context("Invalid CE")?;
        let le = extract_point_attribute(xml, "le")?.parse::<f64>()
            .context("Invalid LE")?;

        let point = Point { lat, lon, hae, ce, le };

        // Extract detail if present
        let detail = extract_detail(xml);

        Ok(Self {
            uid,
            event_type,
            how,
            time,
            start,
            stale,
            point,
            detail,
        })
    }
}

impl fmt::Display for CotMessage {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "CoT[uid={}, type={}, lat={}, lon={}]",
            self.uid, self.event_type, self.point.lat, self.point.lon
        )
    }
}

// Helper functions for XML parsing
fn extract_attribute(xml: &str, attr: &str) -> Result<String> {
    let pattern = format!(r#"{}=""#, attr);
    let start = xml.find(&pattern)
        .with_context(|| format!("Attribute '{}' not found", attr))?;
    let start = start + pattern.len();
    let end = xml[start..].find('"')
        .context("Closing quote not found")?;
    Ok(xml[start..start + end].to_string())
}

fn extract_point_attribute(xml: &str, attr: &str) -> Result<String> {
    // Find the <point> tag first
    let point_start = xml.find("<point")
        .context("Point tag not found")?;
    let point_end = xml[point_start..].find("/>")
        .context("Point tag closing not found")?;
    let point_section = &xml[point_start..point_start + point_end];

    extract_attribute(point_section, attr)
}

fn extract_detail(xml: &str) -> Option<String> {
    let start = xml.find("<detail>")?;
    let end = xml.find("</detail>")?;
    Some(xml[start + 8..end].to_string())
}

fn parse_datetime(s: &str) -> Result<DateTime<Utc>> {
    DateTime::parse_from_rfc3339(s)
        .map(|dt| dt.with_timezone(&Utc))
        .context("Failed to parse datetime")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_cot_message() {
        let point = Point {
            lat: 37.7749,
            lon: -122.4194,
            hae: 10.0,
            ce: 9999999.0,
            le: 9999999.0,
        };

        let msg = CotMessage::new("test-uid", "a-f-G-U-C", point);
        assert_eq!(msg.uid, "test-uid");
        assert_eq!(msg.event_type, "a-f-G-U-C");
        assert_eq!(msg.point.lat, 37.7749);
    }

    #[test]
    fn test_to_xml() {
        let point = Point {
            lat: 37.7749,
            lon: -122.4194,
            hae: 10.0,
            ce: 9999999.0,
            le: 9999999.0,
        };

        let msg = CotMessage::new("test-uid", "a-f-G-U-C", point);
        let xml = msg.to_xml().unwrap();

        assert!(xml.contains("uid=\"test-uid\""));
        assert!(xml.contains("type=\"a-f-G-U-C\""));
        assert!(xml.contains("lat=\"37.7749\""));
    }

    #[test]
    fn test_roundtrip() {
        let point = Point {
            lat: 37.7749,
            lon: -122.4194,
            hae: 10.0,
            ce: 9999999.0,
            le: 9999999.0,
        };

        let original = CotMessage::new("test-uid", "a-f-G-U-C", point);
        let xml = original.to_xml().unwrap();
        let parsed = CotMessage::from_xml(&xml).unwrap();

        assert_eq!(parsed.uid, original.uid);
        assert_eq!(parsed.event_type, original.event_type);
        assert_eq!(parsed.point.lat, original.point.lat);
    }
}
