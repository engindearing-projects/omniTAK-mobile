# KML/KMZ Import Integration Guide

## Overview

This guide explains how to integrate the KML/KMZ import functionality into OmniTAK iOS. The implementation provides complete support for parsing KML files, extracting KMZ archives, and displaying geospatial data on the map.

## Files Created

### 1. KMLParser.swift
- **Purpose**: Parse KML XML structure using XMLParser
- **Supported Elements**:
  - `<Document>` - Main container with name, description, styles
  - `<Folder>` - Organizational grouping of placemarks
  - `<Placemark>` - Individual geographic features
  - `<Point>` - Single coordinate locations
  - `<LineString>` - Connected line segments
  - `<Polygon>` - Closed areas with optional inner boundaries (holes)
  - `<MultiGeometry>` - Collections of multiple geometries
  - `<Style>` - Visual styling including colors, line widths, icons
- **Coordinate Format**: Handles "lon,lat,alt" KML format
- **Color Conversion**: Converts KML AABBGGRR to UIColor

### 2. KMZHandler.swift
- **Purpose**: Extract KML data from KMZ (ZIP) archives
- **Features**:
  - Uses custom ZIP archive reader (no external dependencies)
  - Supports both stored and deflate-compressed files
  - Extracts doc.kml and embedded resources (images, icons)
  - Saves extracted resources to documents directory

### 3. KMLOverlayManager.swift
- **Purpose**: Manage KML overlays and coordinate with MapKit
- **Features**:
  - Converts KML geometries to MapKit overlays:
    - Points → KMLPointAnnotation
    - LineStrings → KMLPolylineOverlay
    - Polygons → KMLPolygonOverlay
  - Applies KML styling (colors, line widths, fill options)
  - Manages document visibility toggle
  - Persists imported files to documents directory
  - Provides rendering helpers for MapKit delegate

### 4. KMLImportView.swift
- **Purpose**: SwiftUI user interface for KML management
- **Features**:
  - Document picker using UIDocumentPickerViewController
  - Import progress indicator
  - List of imported KML files with statistics
  - Toggle visibility per file
  - Delete imported files with confirmation
  - Error display for failed imports

### 5. KMLMapIntegration.swift
- **Purpose**: Integration layer between KML and existing map
- **Features**:
  - KMLTacticalMapView - Extended map with KML support
  - Handles KML annotation rendering
  - Routes overlay rendering through KMLOverlayManager
  - KML feature tap handler
  - KMLFeatureDetailView for viewing placemark details

## Integration Steps

### Step 1: Add KMLOverlayManager to Main View

In your main ATAKMapView (MapViewController.swift), add the KML manager as a StateObject:

```swift
struct ATAKMapView: View {
    @StateObject private var kmlManager = KMLOverlayManager()
    @State private var showKMLImport = false
    @State private var selectedKMLFeature: KMLPlacemark?
    @State private var showKMLFeatureDetail = false

    // ... existing state variables
}
```

### Step 2: Replace TacticalMapView with KMLTacticalMapView

Update your map view to use the KML-enabled version:

```swift
var body: some View {
    ZStack {
        // Replace TacticalMapView with KMLTacticalMapView
        KMLTacticalMapView(
            region: $mapRegion,
            mapType: $mapType,
            trackingMode: $trackingMode,
            markers: cotMarkers,
            showsUserLocation: true,
            drawingStore: drawingStore,
            drawingManager: drawingManager,
            kmlManager: kmlManager,
            onMapTap: handleMapTap,
            onKMLFeatureTap: { placemark in
                selectedKMLFeature = placemark
                showKMLFeatureDetail = true
            }
        )
        .ignoresSafeArea()

        // ... rest of your UI
    }
}
```

### Step 3: Add KML Import Button to UI

Add the KML import button to your toolbar or side panel:

```swift
// Option 1: Add to bottom toolbar
ATAKBottomToolbar(
    // ... existing parameters
)

// Add KML button alongside other toolbar buttons
KMLImportButton(
    kmlManager: kmlManager,
    showKMLImport: $showKMLImport
)

// Option 2: Add to side panel
LayerButton(icon: "map.fill", title: "KML Files", isActive: false) {
    showKMLImport = true
}
```

### Step 4: Add Sheet Presentations

Add the sheet modifiers for KML views:

```swift
.sheet(isPresented: $showKMLImport) {
    KMLImportView(
        kmlManager: kmlManager,
        isPresented: $showKMLImport
    )
}
.sheet(isPresented: $showKMLFeatureDetail) {
    if let placemark = selectedKMLFeature {
        KMLFeatureDetailView(
            placemark: placemark,
            isPresented: $showKMLFeatureDetail
        )
    }
}
```

### Step 5: Add KML Layer Toggle to Side Panel (Optional)

In ATAKSidePanel, add a section for KML layers:

```swift
Divider()
    .background(Color.white.opacity(0.3))
    .padding(.vertical, 4)

Text("KML LAYERS")
    .font(.system(size: 10, weight: .bold))
    .foregroundColor(.white)
    .padding(.horizontal, 10)

ForEach(kmlManager.documents) { doc in
    LayerButton(
        icon: "map.fill",
        title: doc.name,
        isActive: doc.isVisible,
        compact: true
    ) {
        kmlManager.toggleVisibility(for: doc.id)
    }
}
```

## File Storage

KML files are stored in the app's documents directory:

```
Documents/
├── KMLFiles/
│   ├── {uuid}.kml              # Imported KML data
│   └── ...
├── KMLResources/
│   └── {filename}/
│       ├── icon.png            # Extracted KMZ resources
│       └── ...
└── kml_documents.json          # Persistence metadata
```

## Supported KML Features

### Geometry Types
- **Point**: Single locations displayed as markers
- **LineString**: Connected paths displayed as polylines
- **Polygon**: Closed areas with optional interior holes
- **MultiGeometry**: Nested combinations of the above

### Style Properties
- Line color (AABBGGRR format converted to RGBA)
- Line width
- Polygon fill color and opacity
- Polygon outline toggle
- Icon URLs (stored for future custom icon support)

### Document Structure
- Document name and description
- Folders for organization
- Style definitions (referenced by styleUrl)
- Multiple placemarks per document

## Example KML File

```xml
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>Mission Area</name>
    <description>Tactical overlay for operation</description>

    <Style id="route">
      <LineStyle>
        <color>ff0000ff</color>
        <width>3</width>
      </LineStyle>
    </Style>

    <Style id="zone">
      <PolyStyle>
        <color>4000ff00</color>
        <fill>1</fill>
        <outline>1</outline>
      </PolyStyle>
    </Style>

    <Folder>
      <name>Points of Interest</name>
      <Placemark>
        <name>Command Post</name>
        <Point>
          <coordinates>-77.0365,38.8977,0</coordinates>
        </Point>
      </Placemark>
    </Folder>

    <Placemark>
      <name>Route Alpha</name>
      <styleUrl>#route</styleUrl>
      <LineString>
        <coordinates>
          -77.0365,38.8977,0
          -77.0500,38.9000,0
          -77.0600,38.9100,0
        </coordinates>
      </LineString>
    </Placemark>

    <Placemark>
      <name>Secure Zone</name>
      <styleUrl>#zone</styleUrl>
      <Polygon>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>
              -77.0365,38.8977,0
              -77.0365,38.9077,0
              -77.0465,38.9077,0
              -77.0465,38.8977,0
              -77.0365,38.8977,0
            </coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
    </Placemark>
  </Document>
</kml>
```

## Testing

1. **Create sample KML file**: Use the example above or download from Google Earth
2. **Transfer to device**: Use Files app, AirDrop, or email attachment
3. **Import in app**: Tap KML import button, select file
4. **Verify display**: Check that overlays appear on map
5. **Toggle visibility**: Use file list to show/hide layers
6. **Tap features**: Verify callouts and detail views work

## Performance Considerations

- Large KML files (>1000 placemarks) may take time to parse
- Import is performed asynchronously to avoid UI blocking
- Overlays are cached in memory for quick visibility toggling
- Consider implementing lazy loading for very large datasets

## Future Enhancements

1. **Custom icons**: Load and display custom placemark icons from KMZ
2. **Network links**: Support for `<NetworkLink>` to fetch remote KML
3. **Time-based features**: Support `<TimeSpan>` and `<TimeStamp>`
4. **Export**: Generate KML from drawings and waypoints
5. **Search**: Find placemarks by name within imported files
6. **Zoom to bounds**: Center map on imported KML extent
