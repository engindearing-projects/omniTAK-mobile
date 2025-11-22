import { Component } from 'valdi_core/src/Component';
import { Label, View } from 'valdi_tsx/src/NativeTemplateElements';
import { Style } from 'valdi_core/src/Style';
import { systemFont } from 'valdi_core/src/SystemFont';
import { takService } from '../services/TakService';
import { parseCotXml, getAffiliation, getAffiliationColor } from '../services/CotParser';
import { MapLibreView, MapMarker, MapCamera, MapTapEvent } from '../components/MapLibreView';
import { Coordinates } from './EnhancedMapScreen';

/**
 * @ViewModel
 * @ExportModel({
 *   ios: 'MapScreenViewModel',
 *   android: 'com.engindearing.omnitak.MapScreenViewModel'
 * })
 */
export interface MapScreenViewModel {
  markerCount: number;
  lastUpdate: string;
  isConnected: boolean;
  markers: MapMarker[];
}

/**
 * @Context
 * @ExportModel({
 *   ios: 'MapScreenContext',
 *   android: 'com.engindearing.omnitak.MapScreenContext'
 * })
 */
export interface MapScreenContext {
  initialCenter?: Coordinates;
  initialZoom?: number;
}

/**
 * @Component
 * @ExportModel({
 *   ios: 'MapScreen',
 *   android: 'com.engindearing.omnitak.MapScreen'
 * })
 *
 * Main map screen with integrated MapLibre GL Native rendering.
 * Displays real-time CoT markers from TAK server connections.
 */
export class MapScreen extends Component<MapScreenViewModel, MapScreenContext> {
  private cotUnsubscribe?: () => void;
  private mapLibreRef?: MapLibreView;

  onCreate(): void {
    console.log('MapScreen onCreate');
    // viewModel will be provided by Valdi framework

    // Subscribe to CoT messages (when connection exists)
    this.subscribeToCot();
  }

  onDestroy(): void {
    console.log('MapScreen onDestroy');
    if (this.cotUnsubscribe) {
      this.cotUnsubscribe();
    }
  }

  onRender(): void {
    const { markerCount, lastUpdate, isConnected, markers } = this.viewModel;
    const { initialCenter, initialZoom } = this.context;

    <view style={styles.container}>
      {/* MapLibre map */}
      <MapLibreView
        options={{
          style: 'https://tiles.openfreemap.org/styles/liberty',
        }}
        camera={{
          latitude: initialCenter?.lat || 38.8977,
          longitude: initialCenter?.lon || -77.0365,
          zoom: initialZoom || 10,
          bearing: 0,
        }}
        markers={markers}
        onCameraChanged={this.handleCameraChange.bind(this)}
        onMapTap={this.handleMapClick.bind(this)}
        onMarkerTap={this.handleMarkerTap.bind(this)}
      />

      {/* Map overlay toolbar */}
      <view style={styles.toolbar}>
        <view style={styles.toolbarItem}>
          <label
            value={`Markers: ${markerCount}`}
            font={systemFont(12)}
            color='#FFFFFF'
          />
        </view>
        <view style={styles.toolbarItem}>
          <label
            value={`Last Update: ${lastUpdate}`}
            font={systemFont(12)}
            color='#FFFFFF'
          />
        </view>
        <view style={styles.toolbarItem}>
          <view
            width={8}
            height={8}
            borderRadius={4}
            backgroundColor={isConnected ? '#00FF00' : '#FF0000'}
            marginRight={4}
          />
          <label
            value={isConnected ? 'Online' : 'Offline'}
            font={systemFont(12)}
            color='#FFFFFF'
          />
        </view>
      </view>

      {/* Action buttons */}
      <view style={styles.actionButtons}>
        <view style={styles.actionButton}>
          <label value='📍' font={systemFont(24)} />
        </view>
        <view style={styles.actionButton}>
          <label value='➕' font={systemFont(24)} />
        </view>
        <view style={styles.actionButton}>
          <label value='🔍' font={systemFont(24)} />
        </view>
      </view>
    </view>;
  }

  private subscribeToCot(): void {
    // Get all connections and subscribe to first one for now
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
      console.log(`Received CoT: ${event.uid} (${event.type})`);

      // Get affiliation and color
      const affiliation = getAffiliation(event.type);
      const color = getAffiliationColor(affiliation);

      // Create or update marker
      const marker: MapMarker = {
        id: event.uid,
        latitude: event.point.lat,
        longitude: event.point.lon,
        title: event.detail?.contact?.callsign || event.uid,
        icon: 'marker-default', // TODO: Use affiliation-based icon
        color: color,
      };

      // Update markers list
      const existingMarkerIndex = this.viewModel.markers.findIndex(m => m.id === event.uid);
      let updatedMarkers: MapMarker[];

      if (existingMarkerIndex >= 0) {
        // Update existing marker
        updatedMarkers = [...this.viewModel.markers];
        updatedMarkers[existingMarkerIndex] = marker;
      } else {
        // Add new marker
        updatedMarkers = [...this.viewModel.markers, marker];
      }

      this.updateViewModel({
        markers: updatedMarkers,
        markerCount: updatedMarkers.length,
        lastUpdate: new Date().toLocaleTimeString(),
      });

      console.log(`  Position: ${event.point.lat}, ${event.point.lon}`);
      console.log(`  Affiliation: ${affiliation} (${color})`);
      if (event.detail?.contact) {
        console.log(`  Callsign: ${event.detail.contact.callsign}`);
      }
    }
  }

  private handleCameraChange(camera: MapCamera): void {
    console.log('Camera changed:', camera);
  }

  private handleMapClick(event: MapTapEvent): void {
    console.log('Map clicked:', event);
  }

  private handleMarkerTap(markerId: string): void {
    console.log('Marker tapped:', markerId);
    // TODO: Show marker details popup
  }

  private handleCenterOnUser(): void {
    console.log('Center on user location');
    // TODO: Get user location and center map
  }

  private handleAddMarker(): void {
    console.log('Add marker at current center');
    // TODO: Add marker at current map center
  }

  private handleZoomIn(): void {
    console.log('Zoom in');
    // TODO: Increase zoom level
  }

  private updateViewModel(updates: Partial<MapScreenViewModel>): void {
    // In Valdi, viewModel is readonly and updated by parent component
    console.log('ViewModel update requested:', updates);
    this.scheduleRender();
  }
}

const styles = {
  container: new Style<View>({
    width: '100%',
    height: '100%',
    backgroundColor: '#EEEEEE',
  }),

  toolbar: new Style<View>({
    position: 'absolute',
    top: 60,
    left: 12,
    right: 12,
    flexDirection: 'row',
    backgroundColor: 'rgba(0, 0, 0, 0.7)',
    borderRadius: 8,
    padding: 12,
    justifyContent: 'space-between',
  }),

  toolbarItem: new Style<View>({
    flexDirection: 'row',
    alignItems: 'center',
  }),

  actionButtons: new Style<View>({
    position: 'absolute',
    bottom: 24,
    right: 12,
    flexDirection: 'column',
  }),

  actionButton: new Style<View>({
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: '#FFFFFF',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 12,
  }),
};
