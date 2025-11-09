import { Component } from 'valdi_core/src/Component';
import { Label, View } from 'valdi_tsx/src/NativeTemplateElements';
import { Style } from 'valdi_core/src/Style';
import { systemFont } from 'valdi_core/src/SystemFont';
import { takService } from '../services/TakService';
import { parseCotXml, getAffiliation, getAffiliationColor } from '../services/CotParser';
import { MapLibreView, MapMarker, MapCamera, MapTapEvent } from '../components/MapLibreView';

export type MeasureMode = 'none' | 'distance' | 'area';

/**
 * @ViewModel
 * @ExportModel({
 *   ios: 'EnhancedMapScreenViewModel',
 *   android: 'com.engindearing.omnitak.EnhancedMapScreenViewModel'
 * })
 */
export interface EnhancedMapScreenViewModel {
  markerCount: number;
  lastUpdate: string;
  isConnected: boolean;
  markers: MapMarker[];
  camera: MapCamera;
  isLocked: boolean;
  orientation: 'portrait' | 'landscape';
  northUp: boolean;
  measureMode: MeasureMode;
  measurePoints: Array<{ lat: number; lon: number }>;
  measureDistance?: number;
}

/**
 * @Context
 * @ExportModel({
 *   ios: 'EnhancedMapScreenContext',
 *   android: 'com.engindearing.omnitak.EnhancedMapScreenContext'
 * })
 */
export interface EnhancedMapScreenContext {
  onOpenMenu?: () => void;
  onOverflowMenu?: () => void;
  initialCenter?: { lat: number; lon: number };
  initialZoom?: number;
}

/**
 * @Component
 * @ExportModel({
 *   ios: 'EnhancedMapScreen',
 *   android: 'com.engindearing.omnitak.EnhancedMapScreen'
 * })
 *
 * Enhanced map screen with ATAK-style controls and functionality.
 * Includes toolbar, map controls, measure tool, and full navigation.
 */
export class EnhancedMapScreen extends Component<
  EnhancedMapScreenViewModel,
  EnhancedMapScreenContext
> {
  private cotUnsubscribe?: () => void;
  private mapLibreRef?: MapLibreView;

  onCreate(): void {
    console.log('EnhancedMapScreen onCreate');
    this.subscribeToCot();
  }

  onDestroy(): void {
    console.log('EnhancedMapScreen onDestroy');
    if (this.cotUnsubscribe) {
      this.cotUnsubscribe();
    }
  }

  onRender(): void {
    const {
      markerCount,
      lastUpdate,
      isConnected,
      markers,
      camera,
      isLocked,
      orientation,
      northUp,
      measureMode,
      measurePoints,
      measureDistance,
    } = this.viewModel;

    const { initialCenter, initialZoom } = this.context;

    <view style={styles.container}>
      {/* MapLibre map */}
      <MapLibreView
        options={{
          style: 'https://demotiles.maplibre.org/style.json',
        }}
        camera={camera || {
          latitude: initialCenter?.lat || 38.8977,
          longitude: initialCenter?.lon || -77.0365,
          zoom: initialZoom || 10,
          bearing: northUp ? 0 : camera?.bearing || 0,
        }}
        markers={markers}
        onCameraChanged={this.handleCameraChange.bind(this)}
        onMapTap={this.handleMapClick.bind(this)}
        onMarkerTap={this.handleMarkerTap.bind(this)}
      />

      {/* Top Toolbar */}
      <view style={styles.topToolbar}>
        <view
          style={styles.menuButton}
          onClick={this.handleOpenMenu.bind(this)}
        >
          <label value="☰" font={systemFont(24)} color="#FFFFFF" />
        </view>

        <view style={styles.toolbarCenter}>
          <label
            value="iTAK"
            font={systemFont(18, 'bold')}
            color="#FFFC00"
          />
          <view style={styles.statusIndicator}>
            <view
              width={6}
              height={6}
              borderRadius={3}
              backgroundColor={isConnected ? '#4CAF50' : '#FF5252'}
              marginLeft={8}
            />
          </view>
        </view>

        <view
          style={styles.overflowButton}
          onClick={this.handleOverflowMenu.bind(this)}
        >
          <label value="⋮" font={systemFont(24)} color="#FFFFFF" />
        </view>
      </view>

      {/* Info bar */}
      <view style={styles.infoBar}>
        <label
          value={`Markers: ${markerCount}`}
          font={systemFont(12)}
          color="#FFFFFF"
        />
        <label
          value={`Last: ${lastUpdate}`}
          font={systemFont(12)}
          color="#CCCCCC"
          marginLeft={12}
        />
        {measureMode !== 'none' && measureDistance && (
          <label
            value={`Distance: ${measureDistance.toFixed(2)}m`}
            font={systemFont(12, 'bold')}
            color="#FFFC00"
            marginLeft={12}
          />
        )}
      </view>

      {/* North Arrow / Compass - Top Right */}
      <view style={styles.compassContainer}>
        <view
          style={styles.compassButton}
          onClick={this.handleCompass.bind(this)}
        >
          <label
            value="⬆"
            font={systemFont(24)}
            color="#FFFFFF"
            style={{
              transform: `rotate(${northUp ? 0 : -(camera?.bearing || 0)}deg)`,
            }}
          />
          <label
            value="N"
            font={systemFont(10, 'bold')}
            color="#FFFC00"
          />
        </view>
      </view>

      {/* Right Side Controls */}
      <view style={styles.rightControls}>
        {/* Orientation Toggle */}
        <view
          style={styles.controlButton}
          onClick={this.handleOrientationToggle.bind(this)}
        >
          <label
            value={orientation === 'portrait' ? '📱' : '🖥️'}
            font={systemFont(20)}
          />
        </view>

        {/* Zoom In */}
        <view
          style={styles.controlButton}
          onClick={this.handleZoomIn.bind(this)}
        >
          <label value="+" font={systemFont(24)} color="#FFFFFF" />
        </view>

        {/* Zoom Out */}
        <view
          style={styles.controlButton}
          onClick={this.handleZoomOut.bind(this)}
        >
          <label value="−" font={systemFont(24)} color="#FFFFFF" />
        </view>

        {/* Lock to Self */}
        <view
          style={isLocked ? styles.controlButtonActive : styles.controlButton}
          onClick={this.handleToggleLock.bind(this)}
        >
          <label
            value={isLocked ? '🔒' : '🔓'}
            font={systemFont(20)}
          />
        </view>

        {/* Center on Self */}
        <view
          style={styles.controlButton}
          onClick={this.handleCenterOnSelf.bind(this)}
        >
          <label value="◎" font={systemFont(24)} color="#FFFFFF" />
        </view>
      </view>

      {/* Bottom Action Buttons */}
      <view style={styles.bottomControls}>
        {/* Measure Tool */}
        <view
          style={measureMode !== 'none' ? styles.actionButtonActive : styles.actionButton}
          onClick={this.handleMeasureTool.bind(this)}
        >
          <label value="📏" font={systemFont(20)} />
          <label
            value="Measure"
            font={systemFont(10)}
            color={measureMode !== 'none' ? '#FFFC00' : '#FFFFFF'}
            marginTop={2}
          />
        </view>

        {/* Add Marker */}
        <view
          style={styles.actionButton}
          onClick={this.handleAddMarker.bind(this)}
        >
          <label value="📍" font={systemFont(20)} />
          <label
            value="Marker"
            font={systemFont(10)}
            color="#FFFFFF"
            marginTop={2}
          />
        </view>

        {/* Draw */}
        <view
          style={styles.actionButton}
          onClick={this.handleDraw.bind(this)}
        >
          <label value="✏️" font={systemFont(20)} />
          <label
            value="Draw"
            font={systemFont(10)}
            color="#FFFFFF"
            marginTop={2}
          />
        </view>

        {/* Search */}
        <view
          style={styles.actionButton}
          onClick={this.handleSearch.bind(this)}
        >
          <label value="🔍" font={systemFont(20)} />
          <label
            value="Search"
            font={systemFont(10)}
            color="#FFFFFF"
            marginTop={2}
          />
        </view>
      </view>

      {/* Measure Mode Info */}
      {measureMode !== 'none' && (
        <view style={styles.measureInfo}>
          <label
            value={`Measure Mode: ${measureMode === 'distance' ? 'Distance' : 'Area'}`}
            font={systemFont(14, 'bold')}
            color="#FFFC00"
          />
          <label
            value={`Points: ${measurePoints.length}`}
            font={systemFont(12)}
            color="#FFFFFF"
            marginTop={4}
          />
          <view
            style={styles.measureClearButton}
            onClick={this.handleClearMeasure.bind(this)}
          >
            <label
              value="Clear"
              font={systemFont(12)}
              color="#FF5252"
            />
          </view>
        </view>
      )}
    </view>;
  }

  private subscribeToCot(): void {
    const connections = takService.getConnections();
    if (connections.length > 0) {
      const connectionId = connections[0];
      this.cotUnsubscribe = takService.onCotReceived(
        connectionId,
        this.handleCotMessage.bind(this)
      );
      this.updateViewModel({ isConnected: true });
    }
  }

  private handleCotMessage(xml: string): void {
    const event = parseCotXml(xml);
    if (event) {
      const affiliation = getAffiliation(event.type);
      const color = getAffiliationColor(affiliation);

      const marker: MapMarker = {
        id: event.uid,
        latitude: event.point.lat,
        longitude: event.point.lon,
        title: event.detail?.contact?.callsign || event.uid,
        icon: 'marker-default',
        color: color,
      };

      const existingMarkerIndex = this.viewModel.markers.findIndex(
        (m) => m.id === event.uid
      );
      let updatedMarkers: MapMarker[];

      if (existingMarkerIndex >= 0) {
        updatedMarkers = [...this.viewModel.markers];
        updatedMarkers[existingMarkerIndex] = marker;
      } else {
        updatedMarkers = [...this.viewModel.markers, marker];
      }

      this.updateViewModel({
        markers: updatedMarkers,
        markerCount: updatedMarkers.length,
        lastUpdate: new Date().toLocaleTimeString(),
      });
    }
  }

  private handleCameraChange(camera: MapCamera): void {
    console.log('Camera changed:', camera);
    this.updateViewModel({ camera });
  }

  private handleMapClick(event: MapTapEvent): void {
    console.log('Map clicked:', event);

    // If in measure mode, add point
    if (this.viewModel.measureMode !== 'none') {
      this.addMeasurePoint(event.latitude, event.longitude);
    }
  }

  private handleMarkerTap(markerId: string): void {
    console.log('Marker tapped:', markerId);
    // TODO: Show marker details popup
  }

  private handleOpenMenu(): void {
    console.log('Open navigation menu');
    if (this.context.onOpenMenu) {
      this.context.onOpenMenu();
    }
  }

  private handleOverflowMenu(): void {
    console.log('Open overflow menu');
    if (this.context.onOverflowMenu) {
      this.context.onOverflowMenu();
    }
  }

  private handleCompass(): void {
    console.log('Toggle north up');
    const newNorthUp = !this.viewModel.northUp;
    this.updateViewModel({
      northUp: newNorthUp,
      camera: {
        ...this.viewModel.camera,
        bearing: newNorthUp ? 0 : this.viewModel.camera.bearing,
      },
    });
  }

  private handleOrientationToggle(): void {
    console.log('Toggle orientation');
    const newOrientation =
      this.viewModel.orientation === 'portrait' ? 'landscape' : 'portrait';
    this.updateViewModel({ orientation: newOrientation });
    // TODO: Actually rotate screen
  }

  private handleZoomIn(): void {
    console.log('Zoom in');
    const currentZoom = this.viewModel.camera?.zoom || 10;
    this.updateViewModel({
      camera: {
        ...this.viewModel.camera,
        zoom: Math.min(currentZoom + 1, 22),
      },
    });
  }

  private handleZoomOut(): void {
    console.log('Zoom out');
    const currentZoom = this.viewModel.camera?.zoom || 10;
    this.updateViewModel({
      camera: {
        ...this.viewModel.camera,
        zoom: Math.max(currentZoom - 1, 0),
      },
    });
  }

  private handleToggleLock(): void {
    console.log('Toggle lock to self');
    this.updateViewModel({ isLocked: !this.viewModel.isLocked });
  }

  private handleCenterOnSelf(): void {
    console.log('Center on self marker');
    // TODO: Get user location and center map
    // For now, center on DC
    this.updateViewModel({
      camera: {
        ...this.viewModel.camera,
        latitude: 38.8977,
        longitude: -77.0365,
      },
    });
  }

  private handleMeasureTool(): void {
    console.log('Toggle measure tool');
    const currentMode = this.viewModel.measureMode;
    const newMode: MeasureMode =
      currentMode === 'none' ? 'distance' : 'none';

    this.updateViewModel({
      measureMode: newMode,
      measurePoints: newMode === 'none' ? [] : this.viewModel.measurePoints,
      measureDistance: newMode === 'none' ? undefined : this.viewModel.measureDistance,
    });
  }

  private handleAddMarker(): void {
    console.log('Add marker');
    // TODO: Add marker at current map center
    const center = this.viewModel.camera;
    if (center) {
      const newMarker: MapMarker = {
        id: `user-marker-${Date.now()}`,
        latitude: center.latitude,
        longitude: center.longitude,
        title: 'New Marker',
        icon: 'marker-default',
        color: '#FF5252',
      };

      this.updateViewModel({
        markers: [...this.viewModel.markers, newMarker],
        markerCount: this.viewModel.markers.length + 1,
      });
    }
  }

  private handleDraw(): void {
    console.log('Open drawing tools');
    // TODO: Implement drawing tools
  }

  private handleSearch(): void {
    console.log('Open search');
    // TODO: Implement search
  }

  private addMeasurePoint(lat: number, lon: number): void {
    const newPoints = [...this.viewModel.measurePoints, { lat, lon }];

    // Calculate distance if we have at least 2 points
    let distance = 0;
    if (newPoints.length >= 2) {
      distance = this.calculateTotalDistance(newPoints);
    }

    this.updateViewModel({
      measurePoints: newPoints,
      measureDistance: distance,
    });

    console.log(`Added measure point: ${lat}, ${lon}`);
    console.log(`Total distance: ${distance}m`);
  }

  private handleClearMeasure(): void {
    console.log('Clear measure points');
    this.updateViewModel({
      measurePoints: [],
      measureDistance: undefined,
    });
  }

  private calculateTotalDistance(
    points: Array<{ lat: number; lon: number }>
  ): number {
    let total = 0;
    for (let i = 1; i < points.length; i++) {
      total += this.haversineDistance(
        points[i - 1].lat,
        points[i - 1].lon,
        points[i].lat,
        points[i].lon
      );
    }
    return total;
  }

  private haversineDistance(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number
  ): number {
    const R = 6371e3; // Earth radius in meters
    const φ1 = (lat1 * Math.PI) / 180;
    const φ2 = (lat2 * Math.PI) / 180;
    const Δφ = ((lat2 - lat1) * Math.PI) / 180;
    const Δλ = ((lon2 - lon1) * Math.PI) / 180;

    const a =
      Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
      Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c;
  }

  private updateViewModel(updates: Partial<EnhancedMapScreenViewModel>): void {
    console.log('ViewModel update requested:', updates);
    this.scheduleRender();
  }
}

const styles = {
  container: new Style<View>({
    width: '100%',
    height: '100%',
    backgroundColor: '#1E1E1E',
  }),

  topToolbar: new Style<View>({
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: 64,
    paddingTop: 20, // Status bar
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: 'rgba(30, 30, 30, 0.95)',
    paddingHorizontal: 8,
    zIndex: 100,
  }),

  menuButton: new Style<View>({
    width: 48,
    height: 48,
    alignItems: 'center',
    justifyContent: 'center',
    cursor: 'pointer',
  }),

  toolbarCenter: new Style<View>({
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  }),

  statusIndicator: new Style<View>({
    flexDirection: 'row',
    alignItems: 'center',
  }),

  overflowButton: new Style<View>({
    width: 48,
    height: 48,
    alignItems: 'center',
    justifyContent: 'center',
    cursor: 'pointer',
  }),

  infoBar: new Style<View>({
    position: 'absolute',
    top: 64,
    left: 8,
    right: 8,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(0, 0, 0, 0.7)',
    borderRadius: 4,
    paddingHorizontal: 12,
    paddingVertical: 6,
    zIndex: 90,
  }),

  compassContainer: new Style<View>({
    position: 'absolute',
    top: 100,
    right: 12,
    zIndex: 80,
  }),

  compassButton: new Style<View>({
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: 'rgba(30, 30, 30, 0.9)',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: '#FFFC00',
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
    cursor: 'pointer',
  }),

  rightControls: new Style<View>({
    position: 'absolute',
    top: 170,
    right: 12,
    flexDirection: 'column',
    gap: 8,
    zIndex: 70,
  }),

  controlButton: new Style<View>({
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: 'rgba(30, 30, 30, 0.9)',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: '#3A3A3A',
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
    cursor: 'pointer',
  }),

  controlButtonActive: new Style<View>({
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: 'rgba(255, 252, 0, 0.2)',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: '#FFFC00',
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
    cursor: 'pointer',
  }),

  bottomControls: new Style<View>({
    position: 'absolute',
    bottom: 20,
    left: 0,
    right: 0,
    flexDirection: 'row',
    justifyContent: 'center',
    gap: 12,
    paddingHorizontal: 12,
    zIndex: 60,
  }),

  actionButton: new Style<View>({
    width: 70,
    height: 70,
    borderRadius: 35,
    backgroundColor: 'rgba(30, 30, 30, 0.95)',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: '#3A3A3A',
    shadowColor: '#000000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.4,
    shadowRadius: 6,
    cursor: 'pointer',
  }),

  actionButtonActive: new Style<View>({
    width: 70,
    height: 70,
    borderRadius: 35,
    backgroundColor: 'rgba(255, 252, 0, 0.2)',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 2,
    borderColor: '#FFFC00',
    shadowColor: '#FFFC00',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.6,
    shadowRadius: 8,
    cursor: 'pointer',
  }),

  measureInfo: new Style<View>({
    position: 'absolute',
    bottom: 110,
    left: 12,
    right: 12,
    backgroundColor: 'rgba(30, 30, 30, 0.95)',
    borderRadius: 8,
    padding: 12,
    borderWidth: 2,
    borderColor: '#FFFC00',
    zIndex: 50,
  }),

  measureClearButton: new Style<View>({
    marginTop: 8,
    paddingVertical: 6,
    paddingHorizontal: 12,
    backgroundColor: 'rgba(255, 82, 82, 0.2)',
    borderRadius: 4,
    borderWidth: 1,
    borderColor: '#FF5252',
    alignSelf: 'flex-start',
    cursor: 'pointer',
  }),
};
