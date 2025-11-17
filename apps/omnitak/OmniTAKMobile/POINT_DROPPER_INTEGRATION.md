# Point Dropper / Hostile Marking Integration Guide

## Overview

The Point Dropper feature provides tactical marker placement for OmniTAK iOS, enabling quick hostile/friendly/unknown/neutral marker placement with SALUTE report generation and CoT message broadcasting.

## Files Created

1. **PointMarkerModels.swift** - Core data models
2. **PointDropperService.swift** - Service layer for CRUD and CoT operations
3. **MarkerCoTGenerator.swift** - CoT XML message generation
4. **SALUTEReportView.swift** - SALUTE report form interface
5. **PointDropperView.swift** - Main UI interface
6. **MarkerAnnotationView.swift** - Custom map annotations

## Integration Steps

### 1. Initialize Service in App

```swift
// In your app initialization or main view
@StateObject private var pointDropperService = PointDropperService.shared

// Configure with TAKService for broadcasting
pointDropperService.configure(takService: takService)
```

### 2. Add Point Dropper Button to Bottom Toolbar

In `MapViewController.swift` or your main map view, add the Point Dropper button:

```swift
// In ATAKBottomToolbar or your toolbar
@State private var showPointDropper = false

// Add button
PointDropperButton {
    showPointDropper = true
}

// Present sheet
.sheet(isPresented: $showPointDropper) {
    PointDropperView(
        service: pointDropperService,
        isPresented: $showPointDropper,
        currentLocation: locationManager.location?.coordinate,
        mapCenter: mapRegion.center
    )
}
```

### 3. Integrate Long-Press Gesture on Map

Add long-press gesture recognizer to your map view:

```swift
// In TacticalMapView or your MKMapView setup
func makeUIView(context: Context) -> MKMapView {
    let mapView = MKMapView()

    // Add long press gesture for marker placement
    let longPressGesture = UILongPressGestureRecognizer(
        target: context.coordinator,
        action: #selector(Coordinator.handleLongPress(_:))
    )
    longPressGesture.minimumPressDuration = 0.5
    mapView.addGestureRecognizer(longPressGesture)

    return mapView
}

// In Coordinator
@objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    guard gesture.state == .began else { return }
    guard let mapView = gesture.view as? MKMapView else { return }

    let location = gesture.location(in: mapView)
    LongPressMarkerGesture.handleLongPress(
        at: location,
        in: mapView,
        service: PointDropperService.shared
    )
}
```

### 4. Display Point Markers on Map

Register custom annotation views:

```swift
// In your map delegate setup
func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    // Handle point marker annotations
    if let markerAnnotation = annotation as? PointMarkerAnnotation {
        var annotationView = mapView.dequeueReusableAnnotationView(
            withIdentifier: PointMarkerAnnotationView.reuseIdentifier
        ) as? PointMarkerAnnotationView

        if annotationView == nil {
            annotationView = PointMarkerAnnotationView(
                annotation: annotation,
                reuseIdentifier: PointMarkerAnnotationView.reuseIdentifier
            )
        }

        annotationView?.configure(with: markerAnnotation)
        return annotationView
    }

    // Handle clustering
    if let cluster = annotation as? MKClusterAnnotation {
        return PointMarkerClusterAnnotationView(
            annotation: annotation,
            reuseIdentifier: PointMarkerClusterAnnotationView.reuseIdentifier
        )
    }

    return nil
}
```

Update map annotations when markers change:

```swift
// Subscribe to marker changes
pointDropperService.$markers
    .receive(on: DispatchQueue.main)
    .sink { markers in
        updateMapAnnotations(markers)
    }
    .store(in: &cancellables)

func updateMapAnnotations(_ markers: [PointMarker]) {
    // Remove old point marker annotations
    let oldAnnotations = mapView.annotations.filter { $0 is PointMarkerAnnotation }
    mapView.removeAnnotations(oldAnnotations)

    // Add new annotations
    let newAnnotations = markers.map { $0.createAnnotation() }
    mapView.addAnnotations(newAnnotations)
}
```

### 5. Add to Tools Menu

In `ATAKToolsView.swift`, add Point Dropper option:

```swift
NavigationLink(destination: {
    PointDropperView(
        service: PointDropperService.shared,
        isPresented: .constant(true),
        currentLocation: nil,
        mapCenter: nil
    )
}) {
    ToolMenuItem(
        icon: "scope",
        title: "Point Dropper",
        subtitle: "Place tactical markers"
    )
}
```

### 6. Handle Marker Events

Listen for marker events:

```swift
pointDropperService.onEvent = { event in
    switch event {
    case .markerCreated(let marker):
        print("Marker created: \(marker.name)")
        // Update map, show notification, etc.

    case .markerBroadcast(let marker):
        print("Marker broadcast: \(marker.name)")
        // Show confirmation

    case .saluteReportGenerated(let marker):
        print("SALUTE report added to: \(marker.name)")
        // Update UI

    default:
        break
    }
}
```

## Usage Examples

### Quick Drop Hostile Marker

```swift
let location = CLLocationCoordinate2D(latitude: 38.8977, longitude: -77.0365)
let marker = pointDropperService.quickDrop(at: location, broadcast: true)
```

### Create Marker with SALUTE Report

```swift
let salute = SALUTEReport(
    size: "Squad (9-13)",
    activity: "Moving North",
    location: "38°53'51\"N 77°02'11\"W",
    unit: "Infantry",
    time: Date(),
    equipment: "Small arms, RPG, Technical vehicle"
)

let marker = pointDropperService.createMarker(
    name: "HOS-CONTACT-1",
    affiliation: .hostile,
    coordinate: location,
    saluteReport: salute,
    broadcast: true
)
```

### Generate CoT Message Manually

```swift
let cotXML = MarkerCoTGenerator.generateCoT(for: marker, staleTime: 3600)
takService.sendCoT(xml: cotXML)
```

### Filter Markers

```swift
// Get all hostile markers
let hostileMarkers = pointDropperService.markers(for: .hostile)

// Search markers
let results = pointDropperService.searchMarkers(query: "contact")

// Get nearby markers
let nearbyMarkers = pointDropperService.markersNear(
    location: currentLocation,
    radius: 1000  // 1km
)
```

## CoT Message Format

Generated CoT messages follow TAK standards:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<event version="2.0" uid="marker-UUID" type="a-h-G-U-C"
       time="2025-11-15T20:00:00.000Z"
       start="2025-11-15T20:00:00.000Z"
       stale="2025-11-15T21:00:00.000Z"
       how="h-g-i-g-o">
    <point lat="38.8977" lon="-77.0365" hae="0.0" ce="10.0" le="10.0"/>
    <detail>
        <contact callsign="HOS-1-2000"/>
        <usericon iconsetpath="COT_MAPPING_SPOTMAP/hostile_point"/>
        <color value="FFFF0000"/>
        <affiliation value="Hostile"/>
        <__salute__>
            <size>Squad (9-13)</size>
            <activity>Moving North</activity>
            <location>38°53'51"N 77°02'11"W</location>
            <unit>Infantry</unit>
            <time>152000Z NOV 25</time>
            <equipment>Small arms, RPG</equipment>
        </__salute__>
        <remarks>SALUTE: Squad (9-13) Infantry - Moving North</remarks>
        <precisionlocation altsrc="GPS" geopointsrc="User"/>
        <status readiness="true"/>
        <_marker_>HOS</_marker_>
        <takv device="iPhone" platform="OmniTAK" os="iOS" version="1.0.0"/>
    </detail>
</event>
```

## Affiliation Types

- **Friendly (a-f)**: Cyan color, shield icon
- **Hostile (a-h)**: Red color, triangle warning icon
- **Unknown (a-u)**: Yellow color, question mark icon
- **Neutral (a-n)**: Green color, circle icon

## SALUTE Report Options

### Size
- Individual, Fire Team, Squad, Platoon, Company, Battalion, Regiment, Brigade, Division

### Activity
- Stationary, Moving (N/S/E/W), Attacking, Defending, Withdrawing, Reconnoitering, Patrolling

### Unit Type
- Infantry, Armor, Artillery, Cavalry, Air Defense, Engineer, Signal, Medical, Logistics, Special Forces, Militia, Irregular Forces

## UI Theme

The interface uses the ATAK dark theme:
- Background: #1E1E1E
- Accent: #FFFC00 (ATAK Yellow)
- Hostile: Red
- Friendly: Cyan
- Unknown: Yellow
- Neutral: Green

## Persistence

Markers are automatically persisted to UserDefaults and restored on app launch.

## Statistics

Track marker counts:

```swift
let stats = pointDropperService.markerCountByAffiliation()
let hostileCount = stats[.hostile] ?? 0
let broadcastCount = pointDropperService.broadcastedCount
let saluteCount = pointDropperService.withSALUTECount
```

## Best Practices

1. **Quick Drops**: Use long-press on map for rapid marker placement
2. **SALUTE Reports**: Add to hostile markers for intelligence value
3. **Broadcasting**: Enable auto-broadcast for immediate team awareness
4. **Naming**: Use auto-generated names (HOS-1-2000) for consistency
5. **Remarks**: Add context in remarks field for additional details

## iOS Compatibility

- Minimum iOS 15.0+
- Uses SwiftUI and UIKit interop
- MapKit integration for MKAnnotationView
- SF Symbols for icons
