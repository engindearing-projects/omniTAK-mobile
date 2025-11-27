# Changelog

All notable changes to OmniTAK Mobile will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2025-01-27

### Added
- **Intelligent Server Connection Diagnostics**: New ServerValidator service automatically detects and diagnoses TAK server connection issues
  - Port mismatch detection (streaming vs enrollment vs web interface)
  - HTML response detection when server returns error pages instead of binary/API responses
  - Context-aware error analysis for HTTP status codes (401, 403, 404, 500, etc.)
  - Validates server configuration before connection attempts

- **Enhanced Error Messages**: Comprehensive troubleshooting guidance for real TAK server deployments
  - Detailed explanations replacing generic "Server error (500)" messages
  - Step-by-step troubleshooting instructions for common issues
  - Port-specific guidance (8089 for streaming, 8446 for enrollment, 8443 for web)
  - Suggestions for alternative connection methods (Data Packages when CSR fails)

- **Improved Error UI**: Professional error display with scrollable troubleshooting panels
  - Formatted error sections with visual hierarchy
  - Collapsible troubleshooting steps with icons
  - Scrollable error messages for long diagnostic output
  - ImprovedErrorDialog component for reusable error displays

### Changed
- **CSREnrollmentService**: Enhanced error handling with ServerValidator integration
  - Pre-connection validation prevents invalid connection attempts
  - Server response analysis provides actionable error messages
  - Better compatibility with real-world TAK server deployments

- **SimpleEnrollView**: Improved error section with formatted troubleshooting display
  - Parses structured error messages (title, description, steps)
  - Visual distinction between error types and resolution steps
  - Maximum height with scrolling for lengthy error messages

### Fixed
- **Connection Error Clarity**: Users now receive helpful guidance instead of raw HTML error pages
  - Detects when connecting to wrong port (e.g., web interface instead of streaming)
  - Identifies authentication failures with credential verification steps
  - Recognizes disabled enrollment APIs and suggests alternatives
  - Provides server administrator contact recommendations

### Technical Details
- Added `ServerValidator.swift` with comprehensive validation logic
- Added `ImprovedErrorDialog.swift` for reusable error UI component
- Updated error handling in enrollment and connection flows
- Enhanced error message formatting throughout TAK service layer
- Project version updated to MARKETING_VERSION 2.1.0

## [2.0.0] - 2025-01-26

### Release
- **App Store Release**: Version 2.0.0 prepared for iOS App Store submission
- Major version bump reflecting significant architectural improvements and UI refinements

### Changed
- **Dynamic Version Management**: All hardcoded version strings now read from Bundle configuration
  - Updated CoT generators (MarkerCoTGenerator, ChatXMLGenerator) to use CFBundleShortVersionString
  - Position broadcast, emergency beacon, and digital pointer services now report actual app version
  - Map view controllers display current version dynamically
  - Navigation drawer shows live version from Bundle
  - TAK XML version fields now reflect actual app version in all messages

- **UI Layout Improvements**: Enhanced GPS button positioning to prevent interface overlap
  - Increased bottom padding from 80pt to 90pt in normal mode
  - Increased padding from 130pt to 150pt when Quick Action Toolbar is visible
  - Improved clearance from 12pt to 50pt between GPS button and bottom toolbar
  - Ensures GPS lock button remains accessible without obscuring other UI elements

- **Architecture**: Standardized TAKService usage across all views
  - Replaced multiple TAKService instances with shared singleton pattern
  - ContentView and ATAKMapViewEnhanced now use TAKService.shared
  - Ensures consistent service state and reduces memory overhead

### Technical Details
- Project configuration updated to MARKETING_VERSION 2.0.0
- Build number updated to CURRENT_PROJECT_VERSION 2.0.0
- Cleaned up null build file references in Xcode project
- All version strings now centrally managed through Info.plist

## [1.3.8] - 2025-01-22

### Release
- **App Store Release**: Version 1.3.8 is now available on the iOS App Store
- Production-ready build with all previous fixes and features

## [1.3.7] - 2025-01-21

### Fixed
- **High CPU Usage**: Fixed critical performance issue with MapOverlayCoordinator
  - Removed debug print statement from `mgrsGridEnabled` getter that was spamming console on every access
  - Added throttling to MGRS coordinate updates (max 10 updates/second instead of unlimited)
  - Removed redundant `updateCenterMGRS` calls from latitude/longitude onChange handlers
  - Map animations and panning now use significantly less CPU (reduced from ~180% to normal levels)
  - Console spam "[MapOverlayCoordinator] mgrsGridEnabled GET: false" eliminated

### Technical Details
- Added `mgrsUpdateThrottleInterval` (100ms) to limit MGRS coordinate updates during continuous map movements
- Consolidated MGRS updates to single code path through `updateVisibleOverlays` instead of three separate paths
- Prevents excessive SwiftUI view re-renders triggered by rapid `@Published` property updates

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

[2.0.0]: https://github.com/engindearing-projects/omniTAK-mobile/compare/v1.3.8...v2.0.0
[1.3.8]: https://github.com/engindearing-projects/omniTAK-mobile/compare/v1.3.7...v1.3.8
[1.3.7]: https://github.com/engindearing-projects/omniTAK-mobile/compare/v1.3.0...v1.3.7
[1.3.0]: https://github.com/engindearing-projects/omniTAK-mobile/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/engindearing-projects/omniTAK-mobile/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/engindearing-projects/omniTAK-mobile/releases/tag/v1.1.0
