# Changelog

All notable changes to OmniTAK Mobile will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.7.1] - 2025-12-11

### Fixed
- **Meshtastic IP Input Localization**: Fixed IP address input showing commas instead of periods in non-English locales
  - Changed keyboard type from `.decimalPad` to `.URL` for IP address fields
  - Affects MeshtasticTCPConnectionView and MeshtasticDevicePickerView
  - Users can now properly enter IP addresses like `192.168.1.100` regardless of device language
  - Resolves issue #35

## [2.5.2] - 2025-12-01

### Fixed
- **Drawing Edit UI**: Fixed edit dialog not appearing when tapping edit button
  - Changed sheet presentation from `sheet(isPresented:)` to `sheet(item:)` pattern
  - Edit dialog now reliably appears for markers, lines, circles, and polygons

### Changed
- **Map UI Cleanup**: Removed redundant GPS status indicator from top right
  - GPS lock button at bottom left already provides location status
  - Cleaner map interface with less visual clutter

## [2.5.1] - 2025-12-01

### Fixed
- **Callsign Consistency**: All UI elements now use the callsign from Settings
  - Map callsign display, navigation drawer, and geofence alerts sync with settings
  - CoT messages (position broadcasts, chat) update immediately when callsign changes
  - No app restart required for callsign changes to take effect

- **Radial Menu Layers**: Restored Layers button that was accidentally removed
  - All 7 radial menu options now functional: Drop Point, Measure, Draw, Drawings, Layers, R&B Line, Route Here

## [2.5.0] - 2025-12-01

### Added
- **Drawing List Access**: Access saved drawings directly from radial menu
  - Long-press map → "Drawings" option opens list of all drawings
  - Tap any drawing to zoom map to its location
  - Edit drawing properties (name, color, radius for circles)
  - Clear all drawings option

- **Drawing Tools Integration**: Improved radial menu drawing workflow
  - "Draw" option opens drawing tools panel
  - "Drawings" option opens saved drawings list
  - Both accessible from single long-press on map

### Improved
- **Scale Bar Reactivity**: Smooth real-time updates during map zoom
  - Instant scale updates while zooming (no more lag/delay)
  - Rewritten with computed properties for instant reactivity
  - Matches iTAK/TAKAware smooth zoom behavior

- **Scale Bar Positioning**: Repositioned to avoid UI overlap
  - Now positioned above zoom controls (+/- buttons)
  - No longer hidden behind GPS lock button

- **Console Output**: Removed excessive debug logging
  - Removed 25+ debug print statements from MapViewController
  - Removed 35+ debug print statements from RadialMenuActionExecutor
  - Cleaner console output for production use

### Fixed
- **Radial Menu Actions**: Fixed Draw action to properly open drawing tools
  - Changed from custom action to proper `.openDrawingTools` action
  - Notifications correctly trigger panel display

### Technical Details
- ScaleBarView.swift rewritten with computed properties for instant updates
- RadialMenuActionExecutor.swift cleaned of all debug logging
- MapContextMenus.swift updated with proper drawing actions
- DrawingListPanel with zoom-to-drawing and edit functionality

## [2.4.0] - 2025-11-29

### Added
- **Full ATAK Chat Compatibility**: Complete GeoChat interoperability with official TAK clients
  - Group chat works seamlessly with ATAK 5.5+ devices via "All Chat Rooms" channel
  - Direct messaging between OmniTAK and ATAK users
  - Tested with official TAK.gov servers and OpenTAKServer deployments
  - Compatible with TAK protocol specifications for b-t-f (GeoChat) messages

### Fixed
- **Chat Message Parsing**: Fixed multiple issues preventing chat from working with ATAK clients
  - Fixed remarks element extraction regex that was missing message content
  - Fixed duplicate message detection using event UID instead of chatroom name
  - Added TAKService auto-configuration for ChatManager dependency injection
  - Removed malformed XML attributes that caused message rejection

- **Chat Message Generation**: Fixed outgoing message format for ATAK compatibility
  - Changed chatroom name from "All Chat Users" to "All Chat Rooms" to match ATAK standard
  - Fixed event UID format to include chatroom identifier: `GeoChat.{senderUid}.{chatroom}.{messageId}`
  - Removed `<marti>` element from group chat broadcasts (server handles routing)
  - Updated `__chat id` attribute to use chatroom name for proper channel routing

### Changed
- **ChatXMLParser.swift**: Enhanced incoming message parsing
  - Added comprehensive debug logging for troubleshooting
  - Improved group chat detection to recognize both "All Chat Users" and "All Chat Rooms"
  - Added fallback parsing for alternate chat element formats (_chat, chat)

- **ChatXMLGenerator.swift**: Updated outgoing message format
  - Uses `ChatRoom.atakChatroomName` constant for ATAK interoperability
  - Generates proper TAK protocol-compliant GeoChat XML
  - Improved chatgrp element with correct uid0/uid1 mappings

### Technical Details
- Added `ChatRoom.atakChatroomName = "All Chat Rooms"` constant for ATAK compatibility
- ChatManager now auto-configures TAKService reference on connection
- All chat messages use event UID as unique identifier instead of chatroom name
- Group chat broadcasts exclude `<marti>` element (server handles routing to all clients)
- Project version updated to MARKETING_VERSION 2.4.0

## [2.2.0] - 2025-11-27

### Added
- **Enhanced Team Color Support**: Added comprehensive team color system for ATAK compatibility
  - 12 team color options: Cyan, Blue, Green, Yellow, Orange, Red, Purple, Magenta, White, Dark Blue, Maroon, Teal
  - Team colors now properly display in ATAK via signed 32-bit ARGB integer format
  - Color selection persists across app sessions

### Fixed
- **ATAK Icon Display**: Fixed position markers showing as incorrect icons in ATAK
  - Changed UID prefix from "ANDROID-" to "IOS-" for proper iOS device identification
  - Added `<usericon iconsetpath>` element to CoT messages for correct icon rendering
  - ATAK now displays OmniTAK devices with proper iOS icons instead of generic squares

- **CoT Message Color Format**: Fixed marker colors not displaying in ATAK
  - Changed marker color format from `<color value>` to `<color argb>`
  - Added hexToARGB converter for proper signed 32-bit integer color values
  - Team colors now properly synchronized between OmniTAK and ATAK clients

### Changed
- **Position Broadcast Service**: Enhanced CoT XML generation for full ATAK compatibility
  - Added `<usericon iconsetpath="COT_MAPPING_2525B/a-f/a-f-G-U-C"/>` for friendly ground units
  - Added `<color argb>` with proper team color values
  - Improved CoT message structure to match ATAK standards

- **Marker CoT Generator**: Updated marker generation for proper ATAK display
  - Fixed color attribute from `value` to `argb` format
  - Added support for ARGB color conversion from hex strings
  - Enhanced marker visibility across TAK ecosystem

### Technical Details
- Updated `PositionBroadcastService.swift` with iOS UID prefix and proper CoT elements (lines 87-88, 194-215)
- Added `getARGBForTeamColor()` helper function with 12 color mappings (lines 309-338)
- Updated `MarkerCoTGenerator.swift` color format and added `hexToARGB()` converter (lines 28-39, 176-187)
- Project version updated to MARKETING_VERSION 2.2.0
- All CoT messages now fully compliant with ATAK display standards

## [2.1.1] - 2025-01-27

### Fixed
- **Data Package Import Connection Failures**: Fixed critical certificate matching bug preventing successful connections after data package import
  - Certificate labels now stored without file extensions (e.g., "omnitak_test" instead of "omnitak_test.p12")
  - Server configuration now correctly extracts certificate name from preferences
  - Certificate password properly passed to server configuration
  - Fixed hardcoded "administrator" certificate name that prevented imported certificates from being found

- **Settings Import Button**: Fixed non-functional "Import Data Package" button in Settings
  - Changed from empty action to proper NavigationLink to DataPackageImportView
  - Users can now import data packages from both Servers view and Settings view

### Changed
- **Certificate Import Consistency**: Improved certificate labeling consistency across keychain storage
  - PEM certificates also stored without file extensions for uniform naming
  - Better debug logging shows actual certificate labels being stored and retrieved

### Technical Details
- Updated `DataPackageImportManager.swift` to strip file extensions when storing certificates in keychain
- Updated `parsePreferences()` to extract actual certificate name from preference file instead of hardcoding
- Added certificate password parameter to TAKServer initialization from data package import
- Fixed SettingsView data package import button implementation

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

[2.4.0]: https://github.com/engindearing-projects/omniTAK-mobile/compare/v2.2.0...v2.4.0
[2.2.0]: https://github.com/engindearing-projects/omniTAK-mobile/compare/v2.1.1...v2.2.0
[2.1.1]: https://github.com/engindearing-projects/omniTAK-mobile/compare/v2.1.0...v2.1.1
[2.1.0]: https://github.com/engindearing-projects/omniTAK-mobile/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/engindearing-projects/omniTAK-mobile/compare/v1.3.8...v2.0.0
[1.3.8]: https://github.com/engindearing-projects/omniTAK-mobile/compare/v1.3.7...v1.3.8
[1.3.7]: https://github.com/engindearing-projects/omniTAK-mobile/compare/v1.3.0...v1.3.7
[1.3.0]: https://github.com/engindearing-projects/omniTAK-mobile/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/engindearing-projects/omniTAK-mobile/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/engindearing-projects/omniTAK-mobile/releases/tag/v1.1.0
