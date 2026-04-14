# MapLibre Native Setup Guide

## Overview

MapLibre Native provides real 3D terrain visualization with DEM (Digital Elevation Model) data.
This replaces the limited MapKit 3D implementation that couldn't properly render terrain exaggeration.

## Step 1: Add MapLibre via Swift Package Manager

1. Open `OmniTAKMobile.xcodeproj` in Xcode
2. Go to **File → Add Package Dependencies...**
3. Enter the MapLibre package URL:
   ```
   https://github.com/maplibre/maplibre-gl-native-distribution
   ```
4. Select version **6.4.0** or later
5. Click **Add Package**
6. Select **MapLibre** when prompted for target

## Step 2: Get a Free MapTiler API Key

MapTiler provides free tiles including terrain DEM data:

1. Go to [https://cloud.maptiler.com/account/keys/](https://cloud.maptiler.com/account/keys/)
2. Create a free account (100,000 requests/month free)
3. Create an API key
4. Copy the key

## Step 3: Configure the API Key

Open `MapLibreService.swift` and replace the placeholder:

```swift
private let mapTilerKey: String = "YOUR_MAPTILER_API_KEY"
```

With your actual MapTiler API key:

```swift
private let mapTilerKey: String = "abc123xyz..."
```

**Security Note**: For production, consider using environment variables or a secure configuration file instead of hardcoding the key.

## Step 4: Add Files to Xcode Project

Make sure these files are added to the Xcode project:
- `MapLibre3DView.swift`
- `MapLibreService.swift`
- `MapLibre3DSettingsView.swift`

## Features Included

### Working Features
- ✅ Real 3D terrain from DEM data
- ✅ Terrain exaggeration (0.5x to 3.0x)
- ✅ Camera pitch/tilt control (0° to 85°)
- ✅ Camera bearing/heading control
- ✅ Multiple map styles (Outdoor, Satellite, Hybrid, Streets, Topo, Dark)
- ✅ Hillshade visualization
- ✅ Sky/atmosphere layer
- ✅ Flyover animation along routes
- ✅ Marker and route support

### Map Styles Available
1. **Outdoor** - Best for terrain visualization with trails
2. **Satellite** - Aerial imagery
3. **Hybrid** - Satellite with labels
4. **Streets** - Standard street map
5. **Topographic** - Contour lines and elevation
6. **Dark** - Night mode tactical style

## Usage

### Basic 3D Map View

```swift
import SwiftUI

struct MyMapView: View {
    @StateObject private var mapService = MapLibreService()
    @State private var camera: MapLibreCamera = .terrain3DCamera

    var body: some View {
        MapLibre3DView(service: mapService, camera: $camera)
            .onAppear {
                mapService.set3DMode(enabled: true)
            }
    }
}
```

### Enable 3D Terrain

```swift
// Enable 3D mode with terrain
mapService.set3DMode(enabled: true)

// Adjust terrain exaggeration (1.0 = normal, 2.0 = 2x height)
mapService.setTerrainExaggeration(1.5)
```

### Camera Controls

```swift
// Set camera pitch (tilt)
mapService.setCameraPitch(60) // 0-85 degrees

// Set camera bearing (rotation)
mapService.setCameraBearing(45) // 0-360 degrees

// Fly to location
mapService.flyTo(
    coordinate: CLLocationCoordinate2D(latitude: 38.89, longitude: -77.03),
    zoom: 15,
    pitch: 60,
    bearing: 45,
    duration: 2.0
)
```

### Flyover Animation

```swift
let routeCoordinates: [CLLocationCoordinate2D] = [
    // Your route points
]

mapService.startFlyover(along: routeCoordinates, altitude: 500, duration: 30)
```

## Troubleshooting

### "No such module 'MapLibre'"
- Ensure you've added the SPM package correctly
- Clean build folder (Cmd+Shift+K) and rebuild

### Map not loading / blank
- Check your MapTiler API key is correct
- Verify network connectivity
- Check console for error messages

### Terrain not showing
- Ensure 3D mode is enabled: `service.set3DMode(enabled: true)`
- Terrain DEM only covers land areas at certain zoom levels
- Try zooming in to level 10-15 for best terrain detail

## Tile Usage Limits

MapTiler free tier includes:
- 100,000 tile requests per month
- Terrain RGB tiles for 3D
- All map styles

For higher usage, consider:
- MapTiler paid plans
- Self-hosted tiles with OpenMapTiles
- Other tile providers (Stadia, etc.)
