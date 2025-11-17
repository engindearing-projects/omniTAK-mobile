# Offline Maps Integration Guide

## Files Created

1. **OfflineMapManager.swift** - Core offline map management
2. **TileDownloader.swift** - OSM tile downloading with rate limiting
3. **OfflineTileOverlay.swift** - MKTileOverlay for cached tiles
4. **NetworkMonitor.swift** - Network connectivity monitoring
5. **RegionSelectionView.swift** - UI for selecting map regions to download
6. **OfflineMapsView.swift** - Management UI for downloaded regions

## Modifications Needed to MapViewController.swift

### 1. Add State Variables (around line 19)

Add after line 19:
```swift
@State private var showOfflineMaps = false
@State private var useOfflineTiles = true
```

Add after line 9:
```swift
@StateObject private var offlineMapManager = OfflineMapManager.shared
@StateObject private var networkMonitor = NetworkMonitor.shared
```

### 2. Modify TacticalMapView struct (around line 954)

Add `useOfflineTiles` parameter:
```swift
struct TacticalMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var mapType: MKMapType
    @Binding var trackingMode: MapUserTrackingMode
    let markers: [CoTMarker]
    let showsUserLocation: Bool
    let useOfflineTiles: Bool  // ADD THIS
    @ObservedObject var drawingStore: DrawingStore
    @ObservedObject var drawingManager: DrawingToolsManager
    let onMapTap: (CLLocationCoordinate2D) -> Void
```

### 3. Update TacticalMapView usage (around line 76)

```swift
TacticalMapView(
    region: $mapRegion,
    mapType: $mapType,
    trackingMode: $trackingMode,
    markers: cotMarkers,
    showsUserLocation: true,
    useOfflineTiles: useOfflineTiles,  // ADD THIS
    drawingStore: drawingStore,
    drawingManager: drawingManager,
    onMapTap: handleMapTap
)
```

### 4. Add Offline Tile Overlay in makeUIView (around line 964)

After creating mapView, add:
```swift
// Add offline tile overlay if enabled
if useOfflineTiles {
    let offlineOverlay = OfflineTileOverlay()
    mapView.addOverlay(offlineOverlay, level: .aboveLabels)
}
```

### 5. Add Renderer for Tile Overlay in Coordinator

Add this method to the Coordinator class (after line 1135):
```swift
func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    if let tileOverlay = overlay as? OfflineTileOverlay {
        return MKTileOverlayRenderer(tileOverlay: tileOverlay)
    }

    // Handle drawing overlays
    if let polyline = overlay as? MKPolyline {
        let renderer = MKPolylineRenderer(polyline: polyline)
        renderer.strokeColor = .blue
        renderer.lineWidth = 3
        return renderer
    }

    if let polygon = overlay as? MKPolygon {
        let renderer = MKPolygonRenderer(polygon: polygon)
        renderer.strokeColor = .red
        renderer.fillColor = .red.withAlphaComponent(0.2)
        renderer.lineWidth = 2
        return renderer
    }

    if let circle = overlay as? MKCircle {
        let renderer = MKCircleRenderer(circle: circle)
        renderer.strokeColor = .green
        renderer.fillColor = .green.withAlphaComponent(0.2)
        renderer.lineWidth = 2
        return renderer
    }

    return MKOverlayRenderer(overlay: overlay)
}
```

### 6. Add Helper Method to Coordinator (after line 1135)

```swift
func isDrawingAnnotation(_ annotation: MKAnnotation) -> Bool {
    return annotation is DrawingMarkerAnnotation ||
           annotation is DrawingPointAnnotation
}

@objc func handleMapTap(_ gesture: UITapGestureRecognizer) {
    guard gesture.state == .ended else { return }

    let mapView = gesture.view as! MKMapView
    let point = gesture.location(in: mapView)
    let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

    parent.onMapTap(coordinate)
}
```

### 7. Modify ATAKBottomToolbar (around line 396)

Add binding parameter:
```swift
struct ATAKBottomToolbar: View {
    @Binding var mapType: MKMapType
    @Binding var showLayersPanel: Bool
    @Binding var showDrawingPanel: Bool
    @Binding var showDrawingList: Bool
    @Binding var showOfflineMaps: Bool  // ADD THIS
    let onCenterUser: () -> Void
    let onSendCoT: () -> Void
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
```

Add offline maps button before "Drawing List" button (around line 446):
```swift
// Offline Maps
ToolButton(icon: "arrow.down.circle", label: "Maps") {
    showOfflineMaps.toggle()
    showLayersPanel = false
    showDrawingPanel = false
    showDrawingList = false
}
```

### 8. Update ATAKBottomToolbar usage (around line 108)

```swift
ATAKBottomToolbar(
    mapType: $mapType,
    showLayersPanel: $showLayersPanel,
    showDrawingPanel: $showDrawingPanel,
    showDrawingList: $showDrawingList,
    showOfflineMaps: $showOfflineMaps,  // ADD THIS
    onCenterUser: centerOnUser,
    onSendCoT: sendSelfPosition,
    onZoomIn: zoomIn,
    onZoomOut: zoomOut
)
```

### 9. Add Sheet for Offline Maps View (around line 184)

Add after the ServerConfigView sheet:
```swift
.sheet(isPresented: $showOfflineMaps) {
    OfflineMapsView()
}
```

### 10. Add Network Status Indicator to Status Bar (optional, around line 332)

Modify ATAKStatusBar to include network status:
```swift
struct ATAKStatusBar: View {
    let connectionStatus: String
    let isConnected: Bool
    let messagesReceived: Int
    let messagesSent: Int
    let gpsAccuracy: Double
    let serverName: String?
    let networkStatus: NetworkMonitor.ConnectionType  // ADD THIS
    let isNetworkConnected: Bool  // ADD THIS
    let onServerTap: () -> Void
```

Add network indicator in the HStack (around line 372):
```swift
// Network Status (before GPS Status)
HStack(spacing: 4) {
    Image(systemName: networkStatus.icon)
        .font(.system(size: 10))
    Text(isNetworkConnected ? "ON" : "OFF")
        .font(.system(size: 11, weight: .semibold))
}
.foregroundColor(isNetworkConnected ? .green : .gray)
```

Update ATAKStatusBar usage (around line 91):
```swift
ATAKStatusBar(
    connectionStatus: takService.connectionStatus,
    isConnected: takService.isConnected,
    messagesReceived: takService.messagesReceived,
    messagesSent: takService.messagesSent,
    gpsAccuracy: locationManager.accuracy,
    serverName: ServerManager.shared.activeServer?.name,
    networkStatus: networkMonitor.connectionType,  // ADD THIS
    isNetworkConnected: networkMonitor.isConnected,  // ADD THIS
    onServerTap: { showServerConfig = true }
)
```

## Required Info.plist Changes

Add the following to Info.plist:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>OmniTAK needs your location to display your position on the map and download regional maps.</string>
```

## Usage Instructions

1. **Download a Region:**
   - Tap the "Maps" button in the bottom toolbar
   - Tap the "+" button to add a new region
   - Pan and zoom the map to select your desired area
   - Adjust min/max zoom levels (10-15 recommended)
   - Enter a name for the region
   - Tap "Download Region"

2. **View Downloaded Maps:**
   - Tap the "Maps" button to see all downloaded regions
   - View download progress for active downloads
   - Delete regions you no longer need

3. **Offline Operation:**
   - Downloaded tiles are automatically used when available
   - When offline, only cached tiles are shown
   - When online, missing tiles are downloaded on-demand

## Architecture

### Directory Structure
```
Documents/
└── OfflineMaps/
    ├── regions.json (metadata)
    └── {region-uuid}/
        ├── progress.json (download resume data)
        └── tiles/
            └── {z}/
                └── {x}/
                    └── {y}.png
```

### Key Components

- **OfflineMapManager**: Singleton managing regions, downloads, and tile access
- **TileDownloader**: Concurrent tile downloader with rate limiting (250ms/tile)
- **OfflineTileOverlay**: MKTileOverlay that loads cached tiles or falls back to online
- **NetworkMonitor**: Tracks network connectivity and type (WiFi/Cellular)

### Features

- Resume interrupted downloads
- Automatic fallback to online tiles
- Placeholder tiles for missing data
- Network status monitoring
- Storage management
- Download progress tracking
- Concurrent downloads (4 simultaneous)
- Rate limiting for OSM compliance

## Notes

- OSM tile server has rate limits - respect the 250ms delay between requests
- Large downloads can take significant time (estimate shown in UI)
- Use WiFi for large downloads to avoid cellular data charges
- Recommended zoom range: 10-15 for balance of detail and storage
- Average tile size: ~25KB
- Maximum recommended tiles per region: 100,000
