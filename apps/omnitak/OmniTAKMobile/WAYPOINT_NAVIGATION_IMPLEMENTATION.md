# Waypoint and Navigation System Implementation

## Overview

This document describes the complete implementation of the waypoint and navigation systems for OmniTAK iOS, including data models, business logic, persistence, navigation calculations, compass overlay, and CoT message integration.

## Architecture

### Component Structure

```
┌─────────────────────────────────────────────────────────┐
│                    User Interface                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ WaypointList │  │CompassOverlay│  │  MapView     │  │
│  │     View     │  │              │  │ Integration  │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │
└─────────┼──────────────────┼──────────────────┼─────────┘
          │                  │                  │
┌─────────┼──────────────────┼──────────────────┼─────────┐
│         │    Business Logic & Services        │         │
│  ┌──────▼───────┐  ┌──────▼──────────┐  ┌────▼──────┐  │
│  │  Waypoint    │  │   Navigation    │  │    TAK    │  │
│  │   Manager    │  │    Service      │  │  Service  │  │
│  └──────┬───────┘  └──────┬──────────┘  └────┬──────┘  │
└─────────┼──────────────────┼──────────────────┼─────────┘
          │                  │                  │
┌─────────┼──────────────────┼──────────────────┼─────────┐
│         │      Data Layer & Models            │         │
│  ┌──────▼───────┐  ┌──────▼──────────┐  ┌────▼──────┐  │
│  │  Waypoint    │  │  Navigation     │  │   CoT     │  │
│  │   Models     │  │    State        │  │ Messages  │  │
│  └──────┬───────┘  └─────────────────┘  └───────────┘  │
└─────────┼─────────────────────────────────────────────┘
          │
┌─────────▼─────────────────────────────────────────────┐
│           Persistence (UserDefaults)                   │
└────────────────────────────────────────────────────────┘
```

## Files Created

### 1. WaypointModels.swift

**Purpose:** Core data models for waypoint system

**Key Structures:**

- `Waypoint`: Main waypoint data structure
  - Properties: id, name, coordinate, altitude, icon, color, remarks
  - CoT integration: uid, cotType
  - Codable for persistence
  - Navigation metadata: isNavigationTarget

- `WaypointIcon`: Enumeration of waypoint icon types
  - 19 icon types (waypoint, flag, star, house, etc.)
  - Maps to SF Symbols
  - CoT icon type mapping

- `WaypointColor`: Waypoint color options
  - 10 color options
  - UIColor and SwiftUI Color conversion
  - CoT ARGB hex color codes

- `WaypointAnnotation`: MKAnnotation wrapper for map display

- `NavigationState`: Current navigation status
  - Target waypoint
  - Distance, bearing, ETA
  - Average speed tracking

- `CompassData`: Compass and heading information
  - Magnetic and true heading
  - Heading accuracy
  - Cardinal direction formatting

- `WaypointRoute`: Collection of waypoints forming a route
  - Ordered list of waypoint IDs
  - Color and metadata

**Extensions:**
- Distance formatting (meters to km/miles)
- Bearing to cardinal direction conversion

### 2. WaypointManager.swift

**Purpose:** Business logic and CRUD operations for waypoints

**Key Features:**

#### Waypoint CRUD
- `createWaypoint()`: Create new waypoint with validation
- `getWaypoint(id:)`: Retrieve by UUID
- `getWaypoint(uid:)`: Retrieve by CoT UID
- `updateWaypoint()`: Update existing waypoint
- `deleteWaypoint()`: Delete waypoint and clean up routes
- `deleteAllWaypoints()`: Clear all waypoints

#### Search & Filter
- `waypointsSortedByDistance()`: Sort by proximity to location
- `waypointsNear()`: Find waypoints within radius
- `searchWaypoints()`: Full-text search by name/remarks

#### Route Management
- `createRoute()`: Create new route
- `updateRoute()`: Modify route
- `deleteRoute()`: Remove route
- `addWaypointToRoute()`: Add waypoint to route
- `getWaypointsForRoute()`: Get ordered waypoint list
- `createRouteOverlay()`: Generate MKPolyline for map

#### CoT Integration
- `importFromCoT()`: Import waypoint from CoT message
- `exportToCoT()`: Generate CoT XML for waypoint
- Automatic deduplication by UID

#### Map Integration
- `getAllAnnotations()`: Generate MKAnnotations for all waypoints
- `getAnnotations(for:)`: Get specific waypoint annotations

#### Persistence
- Automatic save on all CRUD operations
- UserDefaults-based storage
- `WaypointPersistence` class for data management

**Singleton Pattern:** `WaypointManager.shared`

### 3. NavigationService.swift

**Purpose:** Navigation calculations and compass heading management

**Key Features:**

#### Location Management
- CLLocationManager integration
- Automatic location updates
- Authorization handling
- Distance filtering (5m threshold)

#### Compass/Heading
- Real-time compass updates
- Magnetic and true heading
- Heading availability detection
- Compass calibration support

#### Navigation Control
- `startNavigation(to:)`: Begin navigation to waypoint
- `stopNavigation()`: End navigation
- `toggleNavigation(to:)`: Toggle navigation state
- Automatic cleanup on stop

#### Calculations
- `calculateBearing()`: Great circle bearing calculation
- `calculateDistance()`: Haversine distance
- `calculateRelativeBearing()`: Bearing relative to heading
- Speed averaging over 10 samples
- ETA calculation based on average speed

#### Compass Display Support
- `compassNeedleRotation()`: Angle for navigation needle
- `compassRoseRotation()`: Angle for compass background
- Real-time updates via @Published properties

#### Helper Methods
- `distance(to:)`: Distance to specific waypoint
- `bearing(to:)`: Bearing to specific waypoint
- `formattedDistance()`: Human-readable distance string
- `formattedBearing()`: Formatted bearing with units
- `formattedETA()`: Time-formatted ETA
- `hasArrivedAtTarget()`: Proximity detection (10m default)

**Singleton Pattern:** `NavigationService.shared`

**CLLocationManagerDelegate:**
- Location updates → current location & navigation data
- Heading updates → compass data
- Authorization changes → automatic handling

### 4. TAKService.swift (Updated)

**Purpose:** Added waypoint CoT message support

**New Methods:**

```swift
func sendWaypoint(_ waypoint: Waypoint, staleTime: TimeInterval = 3600) -> Bool
```
- Exports waypoint to CoT XML
- Sends via existing network connection
- Returns success/failure

```swift
func broadcastWaypoint(name:coordinate:altitude:icon:color:remarks:) -> Bool
```
- Convenience method to create and send waypoint
- Useful for quick waypoint sharing

```swift
func sendRoute(_ route: WaypointRoute) -> Bool
```
- Send all waypoints in a route
- Sequential transmission
- Returns overall success status

**Callback Handler Enhancement:**

Added waypoint CoT message detection in `cotCallback()`:

```swift
else if message.contains("type=\"b-m-p-w\"") || message.contains("<usericon") {
    // Import waypoint into WaypointManager
    WaypointManager.shared.importFromCoT(...)
}
```

- Detects waypoint markers (type "b-m-p-w")
- Detects custom icon metadata
- Automatic import into waypoint system
- Deduplication by UID

### 5. CompassOverlay.swift

**Purpose:** Tactical compass UI for navigation

**Components:**

#### CompassOverlay
- Main overlay view
- Switches between simple and navigating modes
- Expandable details panel
- Tap to show/hide details

#### SimpleCompassView
- Compact heading display
- Rotating north arrow
- Heading in degrees
- Cardinal direction

#### NavigatingCompassView
- 60px compass rose
- Rotating background (north reference)
- Yellow navigation needle (points to target)
- Target waypoint name
- Distance and bearing labels
- ETA display
- Semi-transparent black background
- Cyan accent color (TAK style)

#### NavigationDetailsView
- Expanded navigation panel
- Waypoint details (name, icon, coordinates)
- Navigation stats grid:
  - Distance
  - Bearing
  - Speed
  - ETA
- Stop navigation button
- Dividers and organized sections

#### FullScreenCompassView
- Large 300px compass display
- Outer ring with cardinal directions
- Tick marks every 10° (bold every 90°)
- Heading and cardinal direction text
- Navigation info panel
- Dismiss button

**Visual Design:**
- Dark theme (black backgrounds)
- Cyan primary color
- Yellow navigation indicators
- Semi-transparent overlays
- TAK-style military aesthetic
- Monospaced fonts for numbers

### 6. WaypointListView.swift

**Purpose:** Complete waypoint management UI

**Components:**

#### WaypointListView
- Search bar for filtering
- Sort controls (Name, Distance, Created)
- Waypoint list with swipe actions
- Empty state messaging
- Add waypoint button

**Features:**
- Real-time search filtering
- Multiple sort modes
- Distance sorting requires GPS
- Swipe to delete
- Swipe to navigate
- Tap for details
- Sheet presentations

#### WaypointRowView
- Icon with color
- Name and remarks
- Distance and bearing (if GPS available)
- Navigation indicator (green when active)
- Consistent padding and spacing

#### AddWaypointView
- Form-based input
- Name and description fields
- Location options:
  - Use current location
  - Manual coordinate entry
- Altitude input (optional)
- Icon picker (horizontal scroll, 19 options)
- Color picker (10 colors)
- Validation before save
- Cancel/Save buttons

#### WaypointDetailView
- Large icon display
- Name and remarks
- Detailed coordinates
- Altitude (if available)
- Distance from current location
- Bearing from current location
- Action buttons:
  - Navigate Here
  - Share via CoT
- Monospaced coordinate display

#### Supporting Views
- `SearchBar`: Reusable search component
- `DetailRow`: Labeled value display
- `EmptyWaypointsView`: Empty state UI

**User Experience:**
- Dark theme consistency
- Intuitive gestures
- Clear visual hierarchy
- Immediate feedback
- Validation and error prevention

## Data Flow

### Creating a Waypoint

```
User Input (WaypointListView)
    ↓
WaypointManager.createWaypoint()
    ↓
Waypoint model created
    ↓
WaypointPersistence.saveWaypoints()
    ↓
UserDefaults storage
    ↓
@Published waypoints array updated
    ↓
UI automatically refreshes
```

### Navigation Flow

```
User selects waypoint
    ↓
NavigationService.startNavigation(to: waypoint)
    ↓
Location & heading updates start
    ↓
CLLocationManager delegate callbacks
    ↓
NavigationService updates navigationState
    ↓
@Published properties trigger UI updates
    ↓
CompassOverlay displays live navigation data
```

### CoT Message Flow (Sending)

```
User shares waypoint
    ↓
WaypointManager.exportToCoT(waypoint)
    ↓
XML generation with CoT format
    ↓
TAKService.sendWaypoint(waypoint)
    ↓
DirectTCPSender.send(xml)
    ↓
Network transmission to TAK server
```

### CoT Message Flow (Receiving)

```
TAK Server sends CoT message
    ↓
DirectTCPSender receives data
    ↓
cotCallback() function invoked
    ↓
Message type detection (b-m-p-w)
    ↓
parseCoT(xml) extracts data
    ↓
WaypointManager.importFromCoT()
    ↓
Deduplication by UID
    ↓
WaypointPersistence.saveWaypoints()
    ↓
@Published waypoints updated
    ↓
UI shows new waypoint
```

## Integration Points

### 1. MapView Integration

To display waypoints on the map:

```swift
// In your MapView or MapViewController
@ObservedObject var waypointManager = WaypointManager.shared

// Get annotations
let waypointAnnotations = waypointManager.getAllAnnotations()

// Add to map
mapView.addAnnotations(waypointAnnotations)

// Handle annotation view
func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    if let waypointAnnotation = annotation as? WaypointAnnotation {
        let identifier = "WaypointAnnotation"
        var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

        if view == nil {
            view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        }

        view?.annotation = annotation
        view?.markerTintColor = waypointAnnotation.waypoint.color.uiColor
        view?.glyphImage = UIImage(systemName: waypointAnnotation.waypoint.icon.rawValue)

        return view
    }
    return nil
}
```

### 2. Compass Overlay Integration

Add to your main map view:

```swift
ZStack {
    // Your map view
    MapView(...)

    // Top overlay area
    VStack {
        HStack {
            Spacer()

            // Compass overlay
            CompassOverlay(navigationService: NavigationService.shared)
                .padding()
        }

        Spacer()
    }
}
```

### 3. Navigation Drawer Integration

Add waypoint list to navigation drawer:

```swift
// In NavigationDrawer or similar
Button(action: {
    // Present waypoint list
    showWaypointList = true
}) {
    Label("Waypoints", systemImage: "mappin.circle")
}
.sheet(isPresented: $showWaypointList) {
    WaypointListView()
}
```

### 4. TAK Service Integration

Already integrated in TAKService.swift. No additional code needed.

### 5. GPS Tracking Integration

NavigationService uses existing CLLocationManager. To start:

```swift
// In your app initialization or map view
NavigationService.shared.startLocationUpdates()
NavigationService.shared.startHeadingUpdates()
```

### 6. Quick Waypoint Creation from Map

Add tap gesture to map:

```swift
func handleMapTap(at coordinate: CLLocationCoordinate2D) {
    let waypoint = WaypointManager.shared.createWaypoint(
        name: "Waypoint \(Date())",
        coordinate: coordinate,
        icon: .waypoint,
        color: .blue
    )

    // Optionally broadcast to TAK network
    TAKService.shared.sendWaypoint(waypoint)
}
```

## CoT Message Format

### Waypoint CoT XML Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<event version="2.0"
       uid="waypoint-[UUID]"
       type="b-m-p-w"
       time="2024-01-15T12:30:45.123Z"
       start="2024-01-15T12:30:45.123Z"
       stale="2024-01-15T13:30:45.123Z">
    <point lat="38.8977" lon="-77.0365" hae="0.0" ce="10.0" le="10.0"/>
    <detail>
        <contact callsign="Target Alpha"/>
        <usericon iconsetpath="waypoint"/>
        <color value="FF0000FF"/>
        <remarks>Important location</remarks>
    </detail>
</event>
```

**Field Descriptions:**
- `uid`: Unique identifier (format: "waypoint-[UUID]")
- `type`: "b-m-p-w" (marker, point, waypoint)
- `time`: Creation timestamp (ISO8601)
- `start`: Start validity time
- `stale`: Expiration time (1 hour default)
- `lat/lon`: WGS84 coordinates
- `hae`: Height Above Ellipsoid (meters)
- `ce/le`: Circular/Linear error (accuracy)
- `callsign`: Waypoint name
- `iconsetpath`: Icon type identifier
- `color`: ARGB hex color
- `remarks`: Optional description

## Persistence Schema

### UserDefaults Keys

```swift
"WaypointManager.waypoints"  // JSON array of Waypoint objects
"WaypointManager.routes"     // JSON array of WaypointRoute objects
```

### Storage Format

Waypoints and routes are encoded to JSON using Swift's Codable protocol:

```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "name": "Checkpoint Alpha",
  "remarks": "Rally point",
  "latitude": 38.8977,
  "longitude": -77.0365,
  "altitude": 125.5,
  "icon": "flag",
  "color": "Red",
  "createdAt": "2024-01-15T12:00:00Z",
  "modifiedAt": "2024-01-15T12:30:00Z",
  "createdBy": "EAGLE-1",
  "isNavigationTarget": false,
  "uid": "waypoint-123e4567-e89b-12d3-a456-426614174000",
  "cotType": "b-m-p-w"
}
```

## Testing Checklist

### Unit Testing
- [ ] Waypoint CRUD operations
- [ ] Route management
- [ ] Navigation calculations (bearing, distance)
- [ ] CoT XML parsing and generation
- [ ] Persistence (save/load)
- [ ] Search and filtering

### Integration Testing
- [ ] GPS location updates
- [ ] Compass heading updates
- [ ] Navigation state transitions
- [ ] CoT message send/receive
- [ ] Map annotation display
- [ ] UI interaction flows

### User Testing
- [ ] Create waypoint from current location
- [ ] Create waypoint with manual coordinates
- [ ] Navigate to waypoint
- [ ] View compass overlay
- [ ] Search and sort waypoints
- [ ] Share waypoint via CoT
- [ ] Receive waypoint from another TAK client
- [ ] Edit waypoint properties
- [ ] Delete waypoint
- [ ] Create and manage routes

## Usage Examples

### Example 1: Create Waypoint at Current Location

```swift
let navService = NavigationService.shared
let waypointMgr = WaypointManager.shared

if let location = navService.currentLocation {
    let waypoint = waypointMgr.createWaypoint(
        name: "My Location",
        coordinate: location.coordinate,
        altitude: location.altitude,
        icon: .flag,
        color: .red
    )

    print("Created waypoint: \(waypoint.name)")
}
```

### Example 2: Navigate to Nearest Waypoint

```swift
let navService = NavigationService.shared
let waypointMgr = WaypointManager.shared

if let location = navService.currentLocation {
    let sorted = waypointMgr.waypointsSortedByDistance(from: location)
    if let nearest = sorted.first {
        navService.startNavigation(to: nearest)
        print("Navigating to: \(nearest.name)")
    }
}
```

### Example 3: Share Waypoint via CoT

```swift
let takService = TAKService()
let waypointMgr = WaypointManager.shared

if let waypoint = waypointMgr.waypoints.first {
    let success = takService.sendWaypoint(waypoint)
    if success {
        print("Waypoint shared successfully")
    }
}
```

### Example 4: Create Route

```swift
let waypointMgr = WaypointManager.shared

// Create waypoints
let wp1 = waypointMgr.createWaypoint(
    name: "Start",
    coordinate: CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365)
)

let wp2 = waypointMgr.createWaypoint(
    name: "Checkpoint",
    coordinate: CLLocationCoordinate2D(latitude: 38.9000, longitude: -77.0400)
)

let wp3 = waypointMgr.createWaypoint(
    name: "End",
    coordinate: CLLocationCoordinate2D(latitude: 38.9050, longitude: -77.0450)
)

// Create route
var route = waypointMgr.createRoute(name: "Mission Route", color: .cyan)
waypointMgr.addWaypointToRoute(waypointId: wp1.id, routeId: route.id)
waypointMgr.addWaypointToRoute(waypointId: wp2.id, routeId: route.id)
waypointMgr.addWaypointToRoute(waypointId: wp3.id, routeId: route.id)

// Display on map
if let overlay = waypointMgr.createRouteOverlay(route) {
    mapView.addOverlay(overlay)
}
```

## Performance Considerations

### Memory Management
- Waypoints stored in memory as array (efficient for small-medium datasets)
- Routes reference waypoints by ID (no duplication)
- Automatic cleanup of stale navigation data

### Update Frequency
- Location updates: Every 5 meters
- Heading updates: Continuous (when navigating)
- Navigation calculations: On location/heading change
- UI updates: Via Combine @Published (automatic batching)

### Storage
- UserDefaults appropriate for < 1000 waypoints
- For larger datasets, consider Core Data migration
- Current JSON encoding is human-readable

### Network
- CoT messages are small (~500 bytes typical)
- Batching not required for waypoint sharing
- Route transmission is sequential (consider batching for large routes)

## Future Enhancements

### Planned Features
1. **Waypoint Categories/Groups**
   - Organize waypoints into folders
   - Filter by category
   - Bulk operations

2. **Import/Export**
   - GPX file import/export
   - KML/KMZ support
   - CSV export for analysis

3. **Advanced Navigation**
   - Multi-waypoint route navigation
   - Turn-by-turn guidance
   - Off-route detection and rerouting

4. **Geofencing**
   - Proximity alerts for waypoints
   - Entry/exit notifications
   - Custom radius per waypoint

5. **Waypoint Sharing Enhancements**
   - Share entire routes as single CoT package
   - Subscribe to waypoint feeds
   - Collaborative waypoint editing

6. **Core Data Migration**
   - Better performance for large datasets
   - Relationship management
   - Advanced querying

7. **Compass Enhancements**
   - Augmented Reality compass overlay
   - Night mode
   - Customizable appearance

8. **Map Integration**
   - Waypoint clustering at high zoom
   - Heatmaps of waypoint density
   - Waypoint labels on map

## Troubleshooting

### Waypoints Not Persisting
- Check UserDefaults quota (unlikely issue)
- Verify Codable implementation
- Check for encoding/decoding errors in console

### Navigation Not Starting
- Verify location permissions granted
- Check GPS signal availability
- Ensure waypoint has valid coordinates

### Compass Not Updating
- Check heading availability: `CLLocationManager.headingAvailable()`
- Verify device has magnetometer
- Check for magnetic interference
- Calibration may be needed

### CoT Messages Not Sending
- Verify TAK service connection
- Check network connectivity
- Validate XML format
- Review TAK server logs

### Distance/Bearing Inaccurate
- Check GPS accuracy (horizontalAccuracy)
- Allow time for GPS lock
- Verify coordinate system (WGS84)

## API Reference

See individual file headers for detailed API documentation.

### Key Classes

- `Waypoint`: Core waypoint model
- `WaypointManager`: Singleton manager
- `NavigationService`: Singleton navigation service
- `CompassOverlay`: SwiftUI compass view
- `WaypointListView`: SwiftUI waypoint browser

### Key Protocols

- `Identifiable`: Waypoint, WaypointRoute
- `Codable`: All data models
- `ObservableObject`: Manager and service classes
- `MKAnnotation`: WaypointAnnotation

## Credits

Implementation follows TAK protocol specifications and iOS best practices for location services and navigation.
