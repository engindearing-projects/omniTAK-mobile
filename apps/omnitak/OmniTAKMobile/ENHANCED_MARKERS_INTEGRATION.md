# Enhanced Markers Feature - Integration Guide

## Overview

The Enhanced Markers feature provides a complete tactical map experience with rich unit information, position history trails, and interactive info panels for the iOS TAK app.

## Components Created

### 1. MarkerInfoPanel.swift
**Location:** `/Users/iesouskurios/Downloads/omni-BASE/apps/omnitak_ios_test/OmniTAKTest/MarkerInfoPanel.swift`

**Features:**
- Bottom sliding panel with three height states (collapsed, half, full)
- Drag gesture support for panel height adjustment
- Action buttons: Center, Message, Track
- Comprehensive information sections:
  - Location (coordinates, altitude, MGRS grid)
  - Movement (speed, course)
  - Accuracy (CE, LE)
  - Team information
  - Device details (device, platform, battery)
  - Remarks
  - Timing information (last update, age, UID, type)
- Distance and bearing calculations from user location
- Battery level with color-coded indicators
- Affiliation and unit type badges
- Stale marker warnings

**Usage:**
```swift
let panel = MarkerInfoPanel(
    marker: enhancedMarker,
    userLocation: locationManager.location,
    onCenter: { /* center on marker */ },
    onMessage: { /* send message */ },
    onTrack: { /* enable tracking */ },
    onDismiss: { /* close panel */ }
)
```

### 2. UnitTrailOverlay.swift
**Location:** `/Users/iesouskurios/Downloads/omni-BASE/apps/omnitak_ios_test/OmniTAKTest/UnitTrailOverlay.swift`

**Features:**
- MKPolyline-based position history trails
- Custom trail renderer with:
  - Affiliation-based colors (cyan for friendly, red for hostile, etc.)
  - Direction arrows along the trail
  - Start marker (green) and end marker (current position)
  - Configurable line width and arrow visibility
- TrailManager for managing multiple unit trails:
  - Position filtering to reduce clutter
  - Maximum trail length limiting
  - Distance-based position filtering
  - Time-based trail retention
- TrailConfiguration for customization:
  - Enable/disable trails per affiliation
  - Trail width and appearance settings
  - Direction arrow visibility
  - Maximum trail duration

**Usage:**
```swift
let trailManager = TrailManager()
trailManager.updateTrail(for: marker)

// Configure
trailManager.maxTrailLength = 100
trailManager.minimumDistanceThreshold = 5.0

// Add overlay to map
if let trail = trailManager.trails[marker.uid] {
    mapView.addOverlay(trail.polyline)
}
```

### 3. TAKService.swift (Enhanced)
**Location:** `/Users/iesouskurios/Downloads/omni-BASE/apps/omnitak_ios_test/OmniTAKTest/TAKService.swift`

**Enhancements:**
- Extended CoTDetail struct with:
  - `speed: Double?` - Movement speed in m/s
  - `course: Double?` - Heading in degrees
  - `remarks: String?` - Additional text notes
  - `battery: Int?` - Battery percentage
  - `device: String?` - Device model
  - `platform: String?` - Platform/OS information
- Enhanced XML parser that extracts:
  - `<track>` element (speed, course)
  - `<remarks>` element
  - `<status>` element (battery)
  - `<takv>` element (device, platform)
  - `<__group>` element (team name)
- EnhancedMarker management:
  - `enhancedMarkers: [String: EnhancedCoTMarker]` - UID-keyed dictionary
  - Automatic position history tracking
  - Smart history filtering (distance and time-based)
  - Configurable history retention
- Callbacks:
  - `onMarkerUpdated: ((EnhancedCoTMarker) -> Void)?` - Per-marker updates
- Helper methods:
  - `removeStaleMarkers()` - Cleanup old markers
  - `getMarker(uid:)` - Retrieve specific marker
  - `getAllMarkers()` - Get all markers as array

**Configuration:**
```swift
takService.maxHistoryPerUnit = 100  // Max positions per unit
takService.historyRetentionTime = 3600  // 1 hour retention
```

### 4. EnhancedMapViewController.swift
**Location:** `/Users/iesouskurios/Downloads/omni-BASE/apps/omnitak_ios_test/OmniTAKTest/EnhancedMapViewController.swift`

**Features:**
- Complete UIKit-based map controller using MKMapView
- Custom marker annotations with EnhancedCoTMarker data
- Tap gesture handling for marker selection
- Info panel integration with SwiftUI hosting
- Trail overlay rendering and management
- User location tracking
- Map type switching (standard/satellite/hybrid)
- Zoom controls
- Annotation tracking by UID
- Automatic marker and trail updates via Combine

**Public Methods:**
```swift
func centerOnUser()          // Center map on current location
func toggleMapType()         // Cycle through map types
func toggleTrails()          // Show/hide position trails
func zoomIn()               // Zoom in one level
func zoomOut()              // Zoom out one level
```

**Integration:**
```swift
let mapVC = EnhancedMapViewController(takService: takService)
// Add as child view controller or present
```

### 5. CustomMarkerAnnotation.swift (Fixed)
**Location:** `/Users/iesouskurios/Downloads/omni-BASE/apps/omnitak_ios_test/OmniTAKTest/CustomMarkerAnnotation.swift`

**Fix Applied:**
- Corrected typo: `setup View()` → `setupView()` on line 25

## Integration Steps

### Step 1: Add New Files to Xcode Project
1. Open your Xcode project
2. Add the following new files:
   - `MarkerInfoPanel.swift`
   - `UnitTrailOverlay.swift`
   - `EnhancedMapViewController.swift`
3. Ensure they're added to the correct target

### Step 2: Update Existing Files
The following files have been updated with new functionality:
- `TAKService.swift` - Enhanced with full field parsing and history tracking
- `CustomMarkerAnnotation.swift` - Fixed typo

### Step 3: Integrate into Your App

#### Option A: Replace Existing Map View
If using the SwiftUI `MapViewController.swift`, you can integrate the enhanced controller:

```swift
import SwiftUI

struct EnhancedMapView: UIViewControllerRepresentable {
    @ObservedObject var takService: TAKService

    func makeUIViewController(context: Context) -> EnhancedMapViewController {
        return EnhancedMapViewController(takService: takService)
    }

    func updateUIViewController(_ uiViewController: EnhancedMapViewController, context: Context) {
        // Updates handled automatically via Combine
    }
}
```

#### Option B: Use in Existing View Hierarchy
```swift
let mapVC = EnhancedMapViewController(takService: takService)
addChild(mapVC)
view.addSubview(mapVC.view)
mapVC.view.frame = view.bounds
mapVC.didMove(toParent: self)
```

### Step 4: Configure Trail Settings (Optional)
```swift
// In your app setup or settings screen
takService.maxHistoryPerUnit = 100
takService.historyRetentionTime = 3600

// Trail appearance
let mapVC = EnhancedMapViewController(takService: takService)
// Trails are enabled by default
// Use mapVC.toggleTrails() to turn on/off
```

### Step 5: Add Control Buttons
Integrate the map controls into your UI:

```swift
// Example toolbar
let centerButton = UIBarButtonItem(
    image: UIImage(systemName: "location.fill"),
    style: .plain,
    target: mapVC,
    action: #selector(mapVC.centerOnUser)
)

let trailButton = UIBarButtonItem(
    image: UIImage(systemName: "arrow.triangle.turn.up.right.diamond"),
    style: .plain,
    target: mapVC,
    action: #selector(mapVC.toggleTrails)
)

navigationItem.rightBarButtonItems = [centerButton, trailButton]
```

## Feature Details

### Marker Selection Flow
1. User taps marker on map
2. Haptic feedback triggers
3. Info panel slides up from bottom
4. Panel shows marker details in sections
5. User can:
   - Drag panel to expand/collapse
   - Tap Center to focus on marker
   - Tap Message to send message (TODO)
   - Tap Track to follow marker
   - Tap X or swipe down to dismiss

### Trail Rendering
1. TAKService receives CoT update
2. Position added to marker's history if:
   - Distance > 5m from last position, OR
   - Time > 30s since last position
3. TrailManager creates/updates trail overlay
4. Map renders polyline with:
   - Color based on affiliation
   - Direction arrows every N points
   - Start marker (green dot)
   - End marker (larger, affiliation color)

### Position History Management
- Maximum 100 positions per unit (configurable)
- Positions older than 1 hour removed automatically
- Distance filtering prevents clutter from stationary units
- Time filtering ensures regular updates even when stationary

### Stale Marker Handling
- Markers not updated for 15+ minutes marked as stale
- Red "STALE" badge shown in info panel
- Visual indication on map (future enhancement)
- Automatic removal with `removeStaleMarkers()`

## Customization

### Change Trail Colors
Edit `UnitTrailOverlay.swift`, line ~32:
```swift
var trailColor: UIColor {
    switch affiliation {
    case .friendly, .assumedFriend:
        return UIColor.cyan  // Change to your color
    // ... etc
    }
}
```

### Adjust Panel Height States
Edit `MarkerInfoPanel.swift`, line ~19:
```swift
enum PanelHeight: CGFloat {
    case collapsed = 150  // Adjust heights
    case half = 400
    case full = 600
}
```

### Configure Trail Filtering
```swift
trailManager.maxTrailLength = 50  // Fewer points
trailManager.minimumDistanceThreshold = 10.0  // Larger gaps
```

### Disable Direction Arrows
```swift
var trailConfig = TrailConfiguration()
trailConfig.showDirectionArrows = false
```

## Testing

### Test Marker Info Panel
1. Connect to TAK server with active units
2. Tap any marker on map
3. Verify panel appears with correct data
4. Test drag gesture (up/down)
5. Test action buttons
6. Verify distance/bearing calculations

### Test Position Trails
1. Connect to TAK server
2. Wait for unit movement (or simulate)
3. Verify trail appears behind moving units
4. Check trail color matches affiliation
5. Verify direction arrows point correctly
6. Confirm start/end markers visible

### Test History Tracking
1. Monitor a unit over time
2. Verify position history grows
3. Confirm old positions removed after 1 hour
4. Check stationary units don't spam history

## Known Limitations

1. **MGRS Grid:** Currently returns "N/A" - requires MGRS conversion library
2. **Messaging:** Placeholder implementation - needs TAK chat protocol
3. **Tracking:** Basic implementation - could add follow mode
4. **Trail Persistence:** Trails cleared on app restart
5. **3D Terrain:** Not supported, altitude shown as text only

## Future Enhancements

- [ ] MGRS coordinate conversion
- [ ] TAK chat/messaging integration
- [ ] Persistent trail storage
- [ ] Trail playback (rewind time)
- [ ] Altitude profile graph
- [ ] Speed graph over time
- [ ] Route prediction
- [ ] Geofencing alerts
- [ ] Custom marker symbols
- [ ] Night vision mode colors
- [ ] Export trail as KML/GPX

## Troubleshooting

### Markers not appearing
- Check `takService.enhancedMarkers` is populated
- Verify map region includes marker coordinates
- Confirm annotations added to mapView

### Trails not rendering
- Ensure `showTrails` is true
- Check trail has 2+ positions
- Verify polyline added as overlay
- Confirm renderer delegate implemented

### Info panel not showing
- Check gesture recognizer added to map
- Verify marker tap detection (44pt radius)
- Confirm SwiftUI hosting controller added

### Performance issues with many markers
- Reduce `maxHistoryPerUnit` (e.g., 50)
- Increase `minimumDistanceThreshold` (e.g., 10m)
- Disable direction arrows on trails
- Implement view frustum culling

## Support

For issues or questions:
1. Check console logs for errors
2. Verify TAKService receiving CoT messages
3. Inspect marker data in debugger
4. Review MapKit delegate callbacks

## File Summary

| File | Lines | Purpose |
|------|-------|---------|
| MarkerInfoPanel.swift | ~400 | SwiftUI info panel with marker details |
| UnitTrailOverlay.swift | ~350 | Trail rendering and management |
| TAKService.swift | ~450 | Enhanced CoT parsing with history |
| EnhancedMapViewController.swift | ~400 | Complete map integration |
| CustomMarkerAnnotation.swift | ~110 | Custom marker views (fixed) |

**Total:** ~1,710 lines of production-ready code

## License

Part of OmniTAK iOS Test Application
