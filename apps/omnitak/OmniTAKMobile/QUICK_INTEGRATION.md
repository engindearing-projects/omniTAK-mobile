# Quick Integration Reference

## 30-Second Overview

Add these lines to MapViewController.swift to integrate the Advanced CoT Filtering feature.

## Step 1: Add Properties (line ~8)

```swift
@StateObject private var filterManager = CoTFilterManager()
@StateObject private var filterCriteria = CoTFilterCriteria()
@State private var showFilterPanel = false
@State private var showUnitList = false
@State private var selectedCoTEvent: EnrichedCoTEvent? = nil
```

## Step 2: Replace cotMarkers (line ~45)

```swift
private var cotMarkers: [CoTMarker] {
    filterManager.updateEvents(takService.cotEvents, userLocation: locationManager.location)
    let filteredEvents = filterManager.applyFilters(criteria: filterCriteria)

    return filteredEvents.compactMap { event in
        let marker = CoTMarker(
            uid: event.uid,
            coordinate: event.coordinate,
            type: event.type,
            callsign: event.callsign,
            team: event.team ?? "Unknown"
        )

        if event.type.contains("a-f") && !showFriendly { return nil }
        if event.type.contains("a-h") && !showHostile { return nil }
        if event.type.contains("a-u") && !showUnknown { return nil }

        return marker
    }
}
```

## Step 3: Add Panels to ZStack (after line ~132)

```swift
// Filter Panel
if showFilterPanel {
    HStack {
        Spacer()
        CoTFilterPanel(criteria: filterCriteria, filterManager: filterManager, isExpanded: $showFilterPanel)
            .padding(.trailing, 8)
            .padding(.vertical, isLandscape ? 80 : 120)
            .transition(.move(edge: .trailing))
    }
}

// Unit List
if showUnitList {
    HStack {
        Spacer()
        CoTUnitListView(filterManager: filterManager, criteria: filterCriteria,
                        isExpanded: $showUnitList, selectedEvent: $selectedCoTEvent,
                        mapRegion: $mapRegion)
            .padding(.trailing, 8)
            .padding(.vertical, isLandscape ? 80 : 120)
            .transition(.move(edge: .trailing))
    }
}
```

## Step 4: Update ATAKBottomToolbar (line ~337)

### Add to signature:
```swift
@Binding var showFilterPanel: Bool
@Binding var showUnitList: Bool
```

### Add buttons after Layers button:
```swift
ToolButton(icon: "line.3.horizontal.decrease.circle.fill", label: "Filter") {
    withAnimation(.spring()) {
        showFilterPanel.toggle()
        if showFilterPanel { showUnitList = false; showLayersPanel = false }
    }
}

ToolButton(icon: "list.bullet.rectangle", label: "Units") {
    withAnimation(.spring()) {
        showUnitList.toggle()
        if showUnitList { showFilterPanel = false; showLayersPanel = false }
    }
}
```

### Update toolbar call (line ~101):
```swift
ATAKBottomToolbar(
    mapType: $mapType,
    showLayersPanel: $showLayersPanel,
    showFilterPanel: $showFilterPanel,  // ADD
    showUnitList: $showUnitList,        // ADD
    onCenterUser: centerOnUser,
    onSendCoT: sendSelfPosition,
    onZoomIn: zoomIn,
    onZoomOut: zoomOut
)
```

## Step 5: Add Timer (after .onAppear)

```swift
.onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
    filterManager.updateUserLocation(locationManager.location)
}
```

## Done!

Build and run. You should see:
- Filter button in bottom toolbar
- Units button in bottom toolbar
- Filter panel slides from right
- Unit list slides from right
- All filtering, sorting, and search working

## Files Required

Make sure these are in your Xcode target:
- CoTFilterModel.swift
- CoTFilterCriteria.swift
- CoTFilterManager.swift
- CoTFilterPanel.swift
- CoTUnitListView.swift

## Common Issues

**Panels not showing**: Check bindings have $ prefix
**Build errors**: Verify all 5 files added to target
**No filtering**: Check cotMarkers property replaced
**Timer not working**: Verify .onReceive added after .onAppear

## Full Details

See FILTER_INTEGRATION_GUIDE.md for complete documentation.
