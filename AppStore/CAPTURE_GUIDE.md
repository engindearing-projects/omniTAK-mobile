# OmniTAK App Store Capture Guide

## 🚀 Automated Capture (Recommended)

### Run All Screenshots Automatically
```bash
cd ~/omniTAK-Mobile/AppStore
./run_screenshot_tests.sh
```

### Record App Previews with UI Automation
```bash
./record_with_test.sh testCorePreview      # Core functionality (~20s)
./record_with_test.sh testTeamPreview      # Team coordination (~20s)
./record_with_test.sh testTacticalPreview  # Tactical features (~20s)
```

### Run Specific Screenshot Tests
```bash
./run_screenshot_tests.sh testMapOnly           # Just the map
./run_screenshot_tests.sh testMilitaryFeatures  # SALUTE, MEDEVAC
./run_screenshot_tests.sh testMeshtasticFeatures
```

---

## 📸 Manual Capture Commands

### Quick Screenshots
```bash
./screenshot.sh [name] [6.5|6.7]
./screenshot.sh map_view           # Captures current sim screen
```

### Manual Video Recording
```bash
./record_preview.sh [name] [6.5|6.7]   # Ctrl+C to stop
```

---

## Screenshots to Capture (10 max)

| # | Screen | Auto Test | Description |
|---|--------|-----------|-------------|
| 1 | Map Overview | ✅ | Main map with markers/units |
| 2 | Radial Menu | ✅ | Long-press context menu |
| 3 | Team Tracking | ✅ | Blue force tracking view |
| 4 | Chat | ✅ | Team messaging |
| 5 | Quick Connect | ✅ | Server connection UI |
| 6 | Settings | ✅ | Clean settings view |
| 7 | Offline Maps | ✅ | Downloaded regions |
| 8 | 3D Map | ✅ | 3D terrain view |
| 9 | Route Planning | ✅ | Navigation/waypoints |
| 10 | Measurement | ✅ | Distance/elevation tools |

### Additional Features (manual capture)
- **Military Reports**: SALUTE, MEDEVAC, CAS, SPOTREP
- **Meshtastic**: Mesh network topology
- **Data Packages**: KML import, mission sync
- **Emergency Beacon**: SOS functionality

---

## 🎬 App Previews (3 max, 15-30 sec each)

| Preview | Test Name | Content |
|---------|-----------|---------|
| Core | `testCorePreview` | Map → Marker → Radial menu |
| Team | `testTeamPreview` | Connect → Team → Chat |
| Tactical | `testTacticalPreview` | 3D → Measure → Route → Offline |

---

## App Store Requirements

### Screenshots
- **6.5"**: 1242 × 2688px (portrait) or 2688 × 1242px (landscape)
- **6.7"**: 1284 × 2778px (portrait) or 2778 × 1284px (landscape)
- Up to 10 screenshots per device size

### App Previews (Video)
- **Format**: H.264, 30fps
- **Duration**: 15-30 seconds
- Same resolution requirements as screenshots
- Up to 3 previews per device size

---

## Tips for Best Results

### Before Capturing
1. **Clean state**: Reset simulator if needed: `xcrun simctl erase booted`
2. **Demo data**: Pre-load sample markers/teams
3. **Clean status bar**: Scripts automatically set 9:41 AM, full battery, clean carrier

### Customizing Tests
Edit these files to adjust navigation:
- `OmniTAKMobileUITests/AppStoreScreenshotTests.swift` - Screenshot logic
- `OmniTAKMobileUITests/AppPreviewRecordingTests.swift` - Video scripts
- `OmniTAKMobileUITests/ScreenshotTestCase.swift` - Helper methods

### Accessibility Identifiers
For more reliable automation, add accessibility identifiers to UI elements:
```swift
Button("Settings")
    .accessibilityIdentifier("settingsButton")
```

---

## File Locations

```
~/omniTAK-Mobile/AppStore/
├── Screenshots/
│   ├── 6.5-inch/        # 1242 × 2688px
│   └── 6.7-inch/        # 1284 × 2778px (auto-saved here)
├── Previews/
│   ├── 6.5-inch/
│   └── 6.7-inch/        # Video recordings
├── run_screenshot_tests.sh   # Automated screenshots
├── record_with_test.sh       # Automated video + test
├── screenshot.sh             # Manual screenshot
└── record_preview.sh         # Manual video
```
