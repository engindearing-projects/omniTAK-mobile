# ATAK-Style Menu System for iTAK

## Overview

This document describes the comprehensive ATAK-style menu system implemented for iTAK. The implementation closely mirrors the Android Team Awareness Kit (ATAK) interface to provide a familiar experience for tactical operators while leveraging iOS capabilities for superior map rendering.

## Research Summary

Based on extensive research of ATAK's interface design:

### ATAK Menu Structure
- **Navigation Drawer**: Side menu with Settings, Network Connections, Plugins, Tools, and About
- **Top Toolbar**: Title bar with hamburger menu, connection status, and overflow menu (⋮)
- **Map Controls**: North arrow/compass, orientation toggle, zoom controls, center on self, lock to self
- **Specialized Tools**: Measure tool, drawing tools, marker management

### Key Features from ATAK
1. **Toolbar**: 15 customizable positions for plugins/tools
2. **Settings**: Organized into sections (General, Display, Network, Location)
3. **Network Connections**: Server management with connection status widgets
4. **Plugins**: Side drawer listing with enable/disable functionality
5. **Orientation Support**: Toggle between portrait and landscape modes
6. **North Up/Track Up**: Compass control for map rotation

## Implementation Architecture

### Component Structure

```
AppController.tsx (Main Navigation Controller)
├── NavigationDrawer.tsx (Side Menu)
├── EnhancedMapScreen.tsx (ATAK-style Map)
├── SettingsScreen.tsx (Settings Management)
├── ServerManagementScreen.tsx (Network Connections)
└── PluginManagementScreen.tsx (Plugin Management)
```

### File Locations

All files are located in `/home/user/omni-BASE/modules/omnitak_mobile/src/valdi/omnitak/`

- **AppController.tsx**: Main application controller with navigation logic
- **components/NavigationDrawer.tsx**: ATAK-style navigation drawer
- **screens/EnhancedMapScreen.tsx**: Enhanced map with full ATAK controls
- **screens/SettingsScreen.tsx**: Settings management screen
- **screens/ServerManagementScreen.tsx**: Server/network connection management
- **screens/PluginManagementScreen.tsx**: Plugin installation and management

## Component Details

### 1. NavigationDrawer Component

**Features:**
- User profile header with callsign and connection status
- Menu items: Map, Settings, Network Connections, Plugins, Tools, About
- Active item highlighting with yellow accent (#FFFC00)
- Connection status indicator
- ATAK-style dark theme (#1E1E1E background)

**Key Methods:**
- `handleNavigate(screen)`: Navigate to different screens
- `handleOverlayClick()`: Close drawer when clicking outside
- `getConnectionColor/Text()`: Dynamic connection status display

### 2. EnhancedMapScreen Component

**Features:**
- **Top Toolbar**: Hamburger menu, iTAK title, connection status, overflow menu
- **Info Bar**: Marker count, last update time, measure distance
- **North Arrow/Compass**: Rotates to show north, toggles north-up mode
- **Right Side Controls**:
  - Orientation toggle (📱/🖥️)
  - Zoom in (+)
  - Zoom out (−)
  - Lock to self (🔒/🔓)
  - Center on self (◎)
- **Bottom Action Buttons**:
  - Measure tool (📏) - **FULLY FUNCTIONAL**
  - Add marker (📍)
  - Draw (✏️)
  - Search (🔍)

**Measure Tool Implementation:**
- Click "Measure" button to activate
- Tap map to add measurement points
- Real-time distance calculation using Haversine formula
- Clear button to reset measurements
- Visual feedback with yellow accent when active
- Distance displayed in meters

**Key Methods:**
- `handleMeasureTool()`: Toggle measure mode
- `addMeasurePoint()`: Add point to measurement
- `calculateTotalDistance()`: Calculate total distance between points
- `haversineDistance()`: Accurate geodesic distance calculation
- `handleZoomIn/Out()`: Zoom controls
- `handleCenterOnSelf()`: Center map on user location
- `handleToggleLock()`: Lock map to user position
- `handleCompass()`: Toggle north-up mode

### 3. SettingsScreen Component

**Features:**
- Organized settings sections (General, Display, Network, Location)
- Toggle switches for boolean settings
- Option selectors for value settings
- Action items for navigation to sub-screens
- Back button navigation
- ATAK-style dark theme

**Default Settings:**
- Callsign: ALPHA-1
- UID: iTAK-001
- Dark Mode: ON
- Show Grid: OFF
- Auto-connect: ON
- GPS Enabled: ON
- Share Location: ON

**Key Methods:**
- `handleToggle()`: Toggle boolean settings
- `handleBack()`: Return to map

### 4. ServerManagementScreen Component

**Features:**
- Server list with connection status (connected/disconnected/connecting/error)
- Add server dialog with form inputs
- Connection controls (Connect/Disconnect buttons)
- Edit and delete server actions
- Protocol selection (TCP, SSL, UDP)
- Connection status badges with color coding
- Empty state messaging

**Default Servers:**
- TAK Server (Local): 192.168.1.100:8087 (TCP)
- TAK Server (Cloud): tak.example.com:8089 (SSL)

**Key Methods:**
- `handleConnect/Disconnect()`: Server connection management
- `handleAddServer()`: Add new server configuration
- `handleEditServer()`: Modify existing server
- `handleDeleteServer()`: Remove server from list

### 5. PluginManagementScreen Component

**Features:**
- Tabbed interface (Installed / Available)
- Plugin cards with metadata (version, author, category)
- Enable/Disable toggle for installed plugins
- Install/Uninstall actions
- Plugin settings access
- Category icons (🗺️ mapping, 🛠️ tools, 📡 communication, 📊 sensors)
- Active status badges

**Default Plugins:**
- Weather Overlay (installed, enabled)
- Route Planning (installed, disabled)
- Voice Chat (available)
- Sensor Integration (available)

**Key Methods:**
- `handleEnablePlugin()`: Enable installed plugin
- `handleDisablePlugin()`: Disable installed plugin
- `handleInstallPlugin()`: Install from available plugins
- `handleUninstallPlugin()`: Remove installed plugin
- `handlePluginSettings()`: Access plugin configuration

### 6. AppController Component

**Features:**
- Centralized navigation management
- State management for all screens
- Data initialization for settings, servers, and plugins
- Screen routing logic
- Drawer open/close control
- Connection status tracking

**Navigation Flow:**
```
Map Screen ←→ Drawer Menu
    ↓
Settings Screen
Server Management Screen
Plugin Management Screen
Tools Screen (placeholder)
About Screen (placeholder)
```

## Color Scheme (ATAK-Style)

Following ATAK's tactical color scheme:

- **Primary Background**: #1E1E1E (dark gray)
- **Secondary Background**: #2A2A2A (lighter dark gray)
- **Accent Color**: #FFFC00 (tactical yellow)
- **Text Primary**: #FFFFFF (white)
- **Text Secondary**: #CCCCCC (light gray)
- **Text Tertiary**: #999999 (medium gray)
- **Border/Divider**: #3A3A3A (subtle gray)
- **Success**: #4CAF50 (green)
- **Warning**: #FFA500 (orange)
- **Error**: #FF5252 (red)

## Button Functionality Status

### ✅ Fully Functional

1. **Measure Tool** - Distance measurement with point plotting
   - Activates measurement mode
   - Adds points on map tap
   - Calculates real-time distances
   - Displays measurement info panel
   - Clear measurements function

2. **Zoom Controls** - Zoom in/out buttons
   - Zoom in: Increases zoom level (max 22)
   - Zoom out: Decreases zoom level (min 0)

3. **Center on Self** - Centers map on user location
   - Updates camera position to user coordinates

4. **Lock to Self** - Locks map to follow user
   - Visual feedback with lock/unlock icon
   - Active state highlighting

5. **North Arrow/Compass** - Map rotation control
   - Toggles north-up mode
   - Visual rotation indicator

6. **Orientation Toggle** - Portrait/landscape switch
   - Toggles between portrait and landscape modes

7. **Add Marker** - Places marker on map
   - Adds marker at current map center
   - Assigns unique ID and timestamp

### 🚧 Partially Implemented

8. **Navigation Drawer** - All menu items functional
   - ✅ Map navigation
   - ✅ Settings navigation
   - ✅ Server management navigation
   - ✅ Plugin management navigation
   - ⚠️ Tools (placeholder screen)
   - ⚠️ About (placeholder screen)

9. **Server Management** - Core features working
   - ✅ List servers
   - ✅ Add server dialog
   - ✅ Connection status display
   - ⚠️ Actual TAK server connection (requires backend integration)

10. **Plugin System** - UI complete
    - ✅ List plugins
    - ✅ Install/uninstall UI
    - ✅ Enable/disable UI
    - ⚠️ Actual plugin loading (requires plugin architecture)

### 📝 Planned (Placeholders)

11. **Draw Tool** - Sketching on map
12. **Search** - Search for locations/markers
13. **Overflow Menu** - Additional tools menu

## Portrait vs Landscape Support

The implementation includes orientation-aware design:

### Portrait Mode
- Vertical button layout on right side
- Bottom action bar with 4 primary actions
- Compact toolbar at top
- Drawer slides from left

### Landscape Mode
- Horizontal optimization of controls
- Wider info bar for more data
- Adjusted button positioning
- Full-width drawer overlay

**Note**: Actual screen rotation requires platform-specific implementation in Valdi framework.

## Integration with Existing Code

The new menu system integrates with existing iTAK services:

- **TakService**: Server connection management
- **CotParser**: CoT message parsing for markers
- **MarkerManager**: Marker lifecycle management
- **MapLibreIntegration**: Map rendering and interaction

## Usage Example

```typescript
// Initialize the app with AppController
<AppController
  viewModel={{
    currentScreen: 'map',
    drawerOpen: false,
    // ... other state
  }}
  context={{
    isDebugMode: false,
  }}
/>
```

## Testing Checklist

- [x] Navigation drawer opens/closes
- [x] All menu items navigate correctly
- [x] Settings toggles work
- [x] Server list displays
- [x] Add server dialog opens
- [x] Plugin tabs switch
- [x] Measure tool activates
- [x] Measure points add on tap
- [x] Distance calculates correctly
- [x] Zoom controls function
- [x] Center on self works
- [x] Lock toggle works
- [x] Compass rotates
- [x] Orientation toggle updates
- [x] Add marker places marker
- [ ] Actual TAK server connection
- [ ] Real GPS location integration
- [ ] Plugin loading system
- [ ] Draw tool implementation
- [ ] Search functionality

## Differences from ATAK

While closely mirroring ATAK, iTAK includes iOS-optimized enhancements:

1. **Map Rendering**: Uses MapLibre GL Native for superior iOS performance
2. **Touch Gestures**: iOS-native gesture handling
3. **UI Animations**: Smooth iOS-style transitions
4. **Platform Integration**: Apple Maps integration (optional)
5. **Design Polish**: iOS Human Interface Guidelines compliance

## Future Enhancements

1. **Custom Plugins**: Plugin architecture for extensibility
2. **Offline Maps**: Download and cache map tiles
3. **Advanced Drawing**: Polylines, polygons, circles
4. **Route Planning**: Multi-point navigation
5. **Team Management**: Group chat and coordination
6. **File Sharing**: Share data packages
7. **Video Streaming**: Live video feeds
8. **Sensor Integration**: Connect external devices

## References

- ATAK User Manual v5.3 (November 2024)
- ATAK User Manual v4.0 (March 2020)
- CivTAK Documentation (https://www.civtak.org)
- TAK.gov Official Documentation
- MapLibre GL Native Documentation
- iOS Human Interface Guidelines

## Contributors

Implementation based on ATAK research and iTAK architecture.

---

**Last Updated**: 2025-11-09
**Version**: 1.0.0
**Status**: Feature Complete (UI), Backend Integration Pending
