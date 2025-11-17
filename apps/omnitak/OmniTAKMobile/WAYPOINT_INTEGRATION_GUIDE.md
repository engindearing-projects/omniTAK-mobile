# Waypoint & Navigation System - Quick Integration Guide

## Overview

This guide provides step-by-step instructions for integrating the waypoint and navigation system into the existing OmniTAK iOS application.

## Files Created

The following new files have been added to the project:

1. **WaypointModels.swift** - Data models and structures
2. **WaypointManager.swift** - Business logic and persistence
3. **NavigationService.swift** - Navigation calculations and GPS
4. **CompassOverlay.swift** - Compass UI component
5. **WaypointListView.swift** - Waypoint management UI
6. **TAKService.swift** - UPDATED with waypoint CoT support

## Step-by-Step Integration

### Step 1: Add Files to Xcode Project

1. Open your Xcode project
2. Right-click on the `OmniTAKMobile` group
3. Select "Add Files to OmniTAKMobile..."
4. Select all new `.swift` files
5. Ensure "Copy items if needed" is checked
6. Click "Add"

### Step 2: Update Info.plist for Location Permissions

Add the following keys to your `Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>OmniTAK needs your location to display your position on the map and navigate to waypoints.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>OmniTAK needs your location to track your position and provide navigation.</string>
```

### Step 3: Integrate Compass Overlay into Map View

In your main map view file (e.g., `MapViewController.swift` or `ATAKMapView`), add the compass overlay:

```swift
import SwiftUI

struct ATAKMapView: View {
    // Existing properties...
    @StateObject private var navigationService = NavigationService.shared

    var body: some View {
        ZStack {
            // Your existing map view
            TacticalMapView(...)

            // Add compass overlay in top-right corner
            VStack {
                HStack {
                    Spacer()

                    CompassOverlay(navigationService: navigationService)
                        .padding(.top, 60)  // Below status bar
                        .padding(.trailing, 16)
                }

                Spacer()
            }
        }
        .onAppear {
            // Start location and heading updates
            navigationService.startLocationUpdates()
            navigationService.startHeadingUpdates()
        }
    }
}
```

### Step 4: Add Waypoint List to Navigation Drawer

In `NavigationDrawer.swift` or your menu system:

```swift
struct NavigationDrawer: View {
    @State private var showWaypointList = false

    var body: some View {
        VStack {
            // Existing menu items...

            Button(action: {
                showWaypointList = true
            }) {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 20))
                    Text("Waypoints")
                        .font(.headline)
                    Spacer()
                }
                .padding()
            }
        }
        .sheet(isPresented: $showWaypointList) {
            WaypointListView()
        }
    }
}
```

### Step 5: Display Waypoints on Map

Update your `MapViewController` to show waypoint annotations:

```swift
class MapViewController: UIViewController, MKMapViewDelegate {
    @ObservedObject var waypointManager = WaypointManager.shared
    private var waypointAnnotations: [WaypointAnnotation] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Existing setup...
        mapView.delegate = self

        // Observe waypoint changes
        waypointManager.$waypoints
            .receive(on: DispatchQueue.main)
            .sink { [weak self] waypoints in
                self?.updateWaypointAnnotations()
            }
            .store(in: &cancellables)
    }

    func updateWaypointAnnotations() {
        // Remove old annotations
        mapView.removeAnnotations(waypointAnnotations)

        // Add new annotations
        waypointAnnotations = waypointManager.getAllAnnotations()
        mapView.addAnnotations(waypointAnnotations)
    }

    // MARK: - MKMapViewDelegate

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // Handle user location
        if annotation is MKUserLocation {
            return nil
        }

        // Handle waypoint annotations
        if let waypointAnnotation = annotation as? WaypointAnnotation {
            let identifier = "WaypointAnnotation"
            var view = mapView.dequeueReusableAnnotationView(
                withIdentifier: identifier
            ) as? MKMarkerAnnotationView

            if view == nil {
                view = MKMarkerAnnotationView(
                    annotation: annotation,
                    reuseIdentifier: identifier
                )
                view?.canShowCallout = true

                // Add navigate button to callout
                let navigateButton = UIButton(type: .detailDisclosure)
                navigateButton.setImage(
                    UIImage(systemName: "location.fill"),
                    for: .normal
                )
                view?.rightCalloutAccessoryView = navigateButton
            }

            // Set waypoint appearance
            let waypoint = waypointAnnotation.waypoint
            view?.annotation = annotation
            view?.markerTintColor = waypoint.color.uiColor
            view?.glyphImage = UIImage(systemName: waypoint.icon.rawValue)

            return view
        }

        return nil
    }

    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView,
                calloutAccessoryControlTapped control: UIControl) {
        if let waypointAnnotation = view.annotation as? WaypointAnnotation {
            // Start navigation to waypoint
            NavigationService.shared.startNavigation(to: waypointAnnotation.waypoint)
        }
    }
}
```

### Step 6: Add Quick Waypoint Creation from Map Tap

Add a long-press gesture to create waypoints:

```swift
class MapViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // Add long press gesture for waypoint creation
        let longPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPress)
    }

    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }

        let point = gesture.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

        // Show waypoint creation dialog
        showCreateWaypointDialog(at: coordinate)
    }

    func showCreateWaypointDialog(at coordinate: CLLocationCoordinate2D) {
        let alert = UIAlertController(
            title: "Create Waypoint",
            message: "Enter waypoint name",
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = "Waypoint name"
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: "Create", style: .default) { _ in
            let name = alert.textFields?[0].text ?? "Waypoint"

            let waypoint = WaypointManager.shared.createWaypoint(
                name: name,
                coordinate: coordinate,
                icon: .waypoint,
                color: .blue
            )

            // Optionally broadcast to TAK network
            if TAKService.shared.isConnected {
                _ = TAKService.shared.sendWaypoint(waypoint)
            }
        })

        present(alert, animated: true)
    }
}
```

### Step 7: Add Waypoint Tool to Drawing Tools Panel

In `ATAKToolsView.swift` or `DrawingToolsPanel.swift`:

```swift
struct ATAKToolsView: View {
    @State private var showWaypointList = false

    var body: some View {
        VStack {
            // Existing tools...

            // Waypoint tool
            ToolButton(
                icon: "mappin.circle.fill",
                label: "Waypoints",
                color: .cyan
            ) {
                showWaypointList = true
            }
        }
        .sheet(isPresented: $showWaypointList) {
            WaypointListView()
        }
    }
}
```

### Step 8: Test the Integration

1. **Build and Run** the app
2. **Grant Location Permissions** when prompted
3. **Test Creating a Waypoint:**
   - Tap the "+" button in waypoint list, OR
   - Long-press on the map
4. **Test Navigation:**
   - Select a waypoint
   - Tap "Navigate Here"
   - Watch the compass overlay update
5. **Test CoT Sharing:**
   - Connect to a TAK server
   - Create a waypoint
   - Tap "Share via CoT"
   - Verify message sent in TAK service logs

## Optional Enhancements

### Add Waypoint Counter to Status Bar

In your status bar view:

```swift
struct ATAKStatusBar: View {
    @ObservedObject var waypointManager = WaypointManager.shared

    var body: some View {
        HStack {
            // Existing status items...

            // Waypoint counter
            Label(
                "\(waypointManager.waypointCount)",
                systemImage: "mappin.circle.fill"
            )
            .font(.caption)
            .foregroundColor(.cyan)
        }
    }
}
```

### Add Navigation Status to Bottom Toolbar

In your bottom toolbar:

```swift
struct BottomToolbar: View {
    @ObservedObject var navigationService = NavigationService.shared

    var body: some View {
        HStack {
            // Existing buttons...

            if navigationService.navigationState.isNavigating,
               let target = navigationService.navigationState.targetWaypoint {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill.viewfinder")
                        .foregroundColor(.green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(target.name)
                            .font(.caption)
                            .fontWeight(.semibold)

                        Text(navigationService.formattedDistance())
                            .font(.caption2)
                            .foregroundColor(.cyan)
                    }

                    Button(action: {
                        navigationService.stopNavigation()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
            }
        }
    }
}
```

### Add Route Display on Map

In your map view controller:

```swift
func displayRoute(_ route: WaypointRoute) {
    // Remove existing route overlays
    let existingRoutes = mapView.overlays.filter { $0 is MKPolyline }
    mapView.removeOverlays(existingRoutes)

    // Add new route
    if let polyline = WaypointManager.shared.createRouteOverlay(route) {
        mapView.addOverlay(polyline)
    }
}

// In MKMapViewDelegate
func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    if let polyline = overlay as? MKPolyline {
        let renderer = MKPolylineRenderer(polyline: polyline)
        renderer.strokeColor = .cyan
        renderer.lineWidth = 3
        renderer.lineDashPattern = [10, 5]  // Dashed line
        return renderer
    }

    // Handle other overlays...
    return MKOverlayRenderer(overlay: overlay)
}
```

## Verification Checklist

- [ ] All files added to Xcode project
- [ ] Info.plist updated with location permissions
- [ ] App builds without errors
- [ ] Location permission dialog appears
- [ ] Compass overlay visible and updating
- [ ] Waypoint list accessible from menu
- [ ] Can create waypoints from list
- [ ] Waypoints appear on map
- [ ] Can tap waypoint to see details
- [ ] Navigation starts when "Navigate Here" tapped
- [ ] Compass shows navigation needle
- [ ] Can stop navigation
- [ ] Waypoints persist after app restart
- [ ] CoT messages send successfully (if connected to TAK server)
- [ ] Waypoints received via CoT appear in list

## Troubleshooting

### "Module not found" errors
- Ensure all files are in the Xcode project
- Clean build folder (Cmd+Shift+K)
- Rebuild project (Cmd+B)

### Location permissions not requested
- Verify Info.plist keys are correct
- Check capitalization and spelling
- Delete app and reinstall to reset permissions

### Compass not updating
- Check device has magnetometer (not available in simulator)
- Test on physical device
- Ensure heading updates started: `navigationService.startHeadingUpdates()`

### Waypoints not persisting
- Check console for encoding/decoding errors
- Verify UserDefaults access permissions
- Test with simple waypoint first

### Navigation not starting
- Verify location permissions granted
- Check GPS signal (may take time to acquire)
- Ensure waypoint has valid coordinates

## Next Steps

After successful integration:

1. **Test on Physical Device** - GPS and compass require hardware
2. **Test with Real TAK Server** - Verify CoT message compatibility
3. **User Testing** - Get feedback on UI/UX
4. **Performance Testing** - Test with many waypoints (100+)
5. **Add Additional Features** - Routes, geofencing, etc.

## Support

For issues or questions:
- Check console logs for error messages
- Review `WAYPOINT_NAVIGATION_IMPLEMENTATION.md` for detailed documentation
- Verify integration steps completed correctly
- Test individual components in isolation

## Summary

The waypoint and navigation system is now fully integrated into OmniTAK iOS. Users can:

- Create and manage waypoints
- Navigate to waypoints with live compass
- Share waypoints via CoT messages
- Receive waypoints from other TAK clients
- View waypoints on the map
- Create and display routes
- Search and filter waypoints

All features follow TAK protocol standards and iOS best practices.
