# Changelog

All notable changes to OmniTAK Mobile will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2025-01-20

### Added - Meshtastic Integration

#### Core Features
- **Meshtastic Mesh Network Support**: Complete integration for off-grid TAK communications over LoRa mesh networks
- **New Protocol**: Added `Protocol::Meshtastic` to support mesh networking alongside TCP/UDP/TLS
- **New Crate**: `omnitak-meshtastic` with full protobuf implementation
- **Connection Types**: Serial/USB, Bluetooth LE, and TCP/IP connections to Meshtastic devices
- **Message Translation**: Automatic CoT XML ↔ Meshtastic protobuf conversion
- **Message Chunking**: Automatic splitting and reassembly for messages >200 bytes
- **Position Updates**: PLI (Position Location Information) support through mesh
- **GeoChat**: Text messaging through mesh network
- **FFI Bindings**: C-compatible interface for iOS and Android

#### iOS/SwiftUI Components
- **MeshtasticBridge.swift**: Native FFI wrapper with Swift types
- **MeshtasticManager.swift**: Reactive state management with @Published properties
- **MeshtasticConnectionView.swift**: Main dashboard with connection status, signal quality, and mesh stats
- **MeshtasticDevicePickerView.swift**: Beautiful device discovery and selection UI
- **MeshTopologyView.swift**: Network visualization with Map, Graph, and List modes
- **SignalHistoryView.swift**: Real-time signal strength charts and analytics

#### TypeScript/React Native
- **MeshtasticService.ts**: Cross-platform service with EventEmitter-based reactive API
- Full TypeScript type definitions for all data models
- Device discovery, signal monitoring, and mesh tracking
- Helper methods for signal quality and network health visualization

#### UI/UX Highlights
- Real-time signal strength monitoring (2-second intervals)
- Mesh node discovery and tracking (5-second intervals)
- Interactive network topology visualization (MapKit, force-directed graphs)
- Signal quality indicators with color coding (green→red)
- Network health dashboard with live statistics
- Signal history charts using Swift Charts
- Empty states with helpful setup guides
- Manual device entry for custom configurations

#### Documentation
- **MESHTASTIC_INTEGRATION.md**: Comprehensive technical documentation
- **MESHTASTIC_UI_UX_GUIDE.md**: Complete integration examples for iOS and TypeScript
- Usage examples, best practices, and troubleshooting guides
- Platform-specific notes for iOS, Android, and Web

### Changed
- Updated Cargo workspace version from 0.1.0 to 1.3.0
- Updated splash screen version to 1.3.0
- Enhanced `ConnectionConfig` to support Meshtastic-specific settings
- Extended `TakClient` to handle Meshtastic connections
- Added Meshtastic protocol mapping (4) to FFI layer

### Technical Details
- **Dependencies Added**: prost, prost-types, prost-build, tokio-serial
- **Protobuf Support**: Complete Meshtastic protocol implementation
- **Signal Tracking**: 100-reading circular buffer with automatic pruning
- **Network Stats**: Connected nodes, hops, success rate, utilization tracking
- **Color Coding**: Consistent quality indicators across all components
- **Performance**: Optimized update intervals for battery efficiency

## [1.2.0] - 2025-01-20

### Added
- **British National Grid (BNG)** coordinate system support
  - Complete WGS84 to OSGB36 datum transformation
  - BNG easting/northing using Transverse Mercator projection
  - Grid square letter codes (e.g., SU, TQ, NT)
  - Configurable precision levels (1m to 10km)
  - Added to CoordinateDisplayFormat enum
  - Full UI integration in CoordinateDisplayView

### Changed
- Updated splash screen version to 1.2.0

## [1.1.0] - Previous Release

### Added
- Certificate management integration
- Add Server workflow improvements
- Enhanced splash screen

### Changed
- Updated splash screen version to 1.1.0

---

## Version Numbering

This project uses [Semantic Versioning](https://semver.org/):
- **Major (X.0.0)**: Breaking changes
- **Minor (0.X.0)**: New features, backward compatible
- **Patch (0.0.X)**: Bug fixes

[1.3.0]: https://github.com/engindearing-projects/omniTAK-mobile/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/engindearing-projects/omniTAK-mobile/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/engindearing-projects/omniTAK-mobile/releases/tag/v1.1.0
