import { Component } from 'valdi_core/src/Component';
import { View } from 'valdi_tsx/src/NativeTemplateElements';
import { Style } from 'valdi_core/src/Style';
import { ViewFactory } from 'valdi_tsx/src/ViewFactory';

/**
 * Map camera configuration.
 * Defines the viewport position and orientation.
 *
 * @ExportModel({
 *   ios: 'MapCamera',
 *   android: 'com.engindearing.omnitak.MapCamera'
 * })
 */
export interface MapCamera {
  /** Center latitude in degrees (-90 to 90) */
  latitude: number;

  /** Center longitude in degrees (-180 to 180) */
  longitude: number;

  /** Zoom level (0 = world, 22 = street level) */
  zoom: number;

  /** Bearing/heading in degrees (0 = north, 90 = east) */
  bearing?: number;

  /** Camera pitch/tilt in degrees (0 = looking straight down, 60 = max) */
  pitch?: number;

  /** Whether to animate camera transitions */
  animated?: boolean;
}

/**
 * Map marker/annotation definition.
 * Represents a point of interest on the map.
 *
 * @ExportModel({
 *   ios: 'MapMarker',
 *   android: 'com.engindearing.omnitak.MapMarker'
 * })
 */
export interface MapMarker {
  /** Unique identifier for the marker */
  id: string;

  /** Marker latitude in degrees */
  latitude: number;

  /** Marker longitude in degrees */
  longitude: number;

  /** Title text shown in callout */
  title?: string;

  /** Subtitle text shown in callout */
  subtitle?: string;

  /** Icon name or color (for future customization) */
  icon?: string;

  /** Marker color (hex string, e.g., '#FF0000') */
  color?: string;
}

/**
 * Map rendering options.
 * Controls map appearance and behavior.
 *
 * @ExportModel({
 *   ios: 'MapLibreViewOptions',
 *   android: 'com.engindearing.omnitak.MapLibreViewOptions'
 * })
 */
export interface MapLibreViewOptions {
  /** Map style URL (e.g., Mapbox Style, OpenStreetMap) */
  style?: string;

  /** Enable user interaction (pan, zoom, rotate) */
  interactive?: boolean;

  /** Show user location blue dot */
  showUserLocation?: boolean;

  /** Show compass control */
  showCompass?: boolean;

  /** Show scale bar */
  showScaleBar?: boolean;

  /** Minimum zoom level */
  minZoom?: number;

  /** Maximum zoom level */
  maxZoom?: number;
}

/**
 * Map tap event data.
 *
 * @ExportModel({
 *   ios: 'MapTapEvent',
 *   android: 'com.engindearing.omnitak.MapTapEvent'
 * })
 */
export interface MapTapEvent {
  /** Tapped latitude */
  latitude: number;

  /** Tapped longitude */
  longitude: number;
}

/**
 * Props for MapLibreView component.
 *
 * @ViewModel
 * @ExportModel({
 *   ios: 'MapLibreViewViewModel',
 *   android: 'com.engindearing.omnitak.MapLibreViewViewModel'
 * })
 */
export interface MapLibreViewViewModel {
  /** Map configuration options */
  options?: MapLibreViewOptions;

  /** Camera position and orientation */
  camera?: MapCamera;

  /** Array of markers to display */
  markers?: MapMarker[];

  /** Callback fired when map finishes loading */
  onMapReady?: () => void;

  /** Callback fired when marker is tapped */
  onMarkerTap?: (markerId: string) => void;

  /** Callback fired when map is tapped */
  onMapTap?: (event: MapTapEvent) => void;

  /** Callback fired when camera moves */
  onCameraChanged?: (camera: MapCamera) => void;
}

/**
 * Context for MapLibreView component.
 *
 * @Context
 * @ExportModel({
 *   ios: 'MapLibreViewContext',
 *   android: 'com.engindearing.omnitak.MapLibreViewContext'
 * })
 */
export interface MapLibreViewContext {
  /** View factory for native MapLibre view (injected by native code) */
  mapLibreViewFactory?: ViewFactory;
}

/**
 * MapLibreView - High-performance native map component for OmniTAK.
 *
 * This component wraps MapLibre GL Native for both iOS and Android,
 * providing a unified TypeScript interface for map rendering, marker
 * management, and user interaction.
 *
 * Features:
 * - Native map rendering with hardware acceleration
 * - Dynamic marker/annotation management
 * - Camera control (pan, zoom, rotate, tilt)
 * - Touch event handling
 * - User location tracking
 * - Custom map styles (Mapbox, OpenStreetMap, etc.)
 *
 * Usage:
 * ```tsx
 * <MapLibreView
 *   options={{
 *     style: 'https://tiles.openfreemap.org/styles/liberty',
 *     interactive: true,
 *     showUserLocation: true
 *   }}
 *   camera={{
 *     latitude: 39.8283,
 *     longitude: -98.5795,
 *     zoom: 4
 *   }}
 *   markers={[
 *     {
 *       id: 'marker-1',
 *       latitude: 37.7749,
 *       longitude: -122.4194,
 *       title: 'San Francisco',
 *       color: '#FF0000'
 *     }
 *   ]}
 *   onMapReady={() => console.log('Map ready')}
 *   onMarkerTap={(id) => console.log('Marker tapped:', id)}
 * />
 * ```
 *
 * @Component
 * @ExportModel({
 *   ios: 'MapLibreView',
 *   android: 'com.engindearing.omnitak.MapLibreView'
 * })
 */
export class MapLibreView extends Component<
  MapLibreViewViewModel,
  MapLibreViewContext
> {
  onCreate(): void {
    console.log('MapLibreView onCreate');
    // viewModel will be provided by Valdi framework with default values
  }

  onRender(): void {
    const {
      options,
      camera,
      markers,
      onMapReady,
      onMarkerTap,
      onMapTap,
      onCameraChanged,
    } = this.viewModel;

    // If no view factory is provided in context, use class mapping as fallback
    if (this.context.mapLibreViewFactory) {
      // Use ViewFactory from context (recommended approach)
      <custom-view
        style={styles.map}
        viewFactory={this.context.mapLibreViewFactory}
        options={options}
        camera={camera}
        markers={markers}
        onMapReady={onMapReady}
        onMarkerTap={onMarkerTap}
        onMapTap={onMapTap}
        onCameraChanged={onCameraChanged}
      />;
    } else {
      // Fallback to class mapping
      <custom-view
        style={styles.map}
        iosClass='SCMapLibreMapView'
        androidClass='com.engindearing.omnitak.MapLibreMapView'
        options={options}
        camera={camera}
        markers={markers}
        onMapReady={onMapReady}
        onMarkerTap={onMarkerTap}
        onMapTap={onMapTap}
        onCameraChanged={onCameraChanged}
      />;
    }
  }

  /**
   * Update camera position programmatically.
   */
  setCamera(camera: MapCamera): void {
    // In Valdi, viewModel is readonly - camera updates should come from parent
    console.log('Camera update requested:', camera);
    this.scheduleRender();
  }

  /**
   * Add a marker to the map.
   */
  addMarker(_marker: MapMarker): void {
    // In Valdi, viewModel is readonly - markers should be updated by parent
    console.log('Add marker requested:', _marker);
  }

  /**
   * Remove a marker from the map by ID.
   */
  removeMarker(markerId: string): void {
    // In Valdi, viewModel is readonly - markers should be updated by parent
    console.log('Remove marker requested:', markerId);
  }

  /**
   * Update an existing marker.
   */
  updateMarker(markerId: string, updates: Partial<MapMarker>): void {
    // In Valdi, viewModel is readonly - markers should be updated by parent
    console.log('Update marker requested:', markerId, updates);
  }

  /**
   * Clear all markers from the map.
   */
  clearMarkers(): void {
    // In Valdi, viewModel is readonly - markers should be updated by parent
    console.log('Clear markers requested');
  }

  /**
   * Update map options.
   */
  setOptions(options: MapLibreViewOptions): void {
    // In Valdi, viewModel is readonly - options should be updated by parent
    console.log('Set options requested:', options);
  }
}

const styles = {
  map: new Style<View>({
    width: '100%',
    height: '100%',
  }),
};

/**
 * Helper function to create a marker from CoT event data.
 *
 * @param uid - CoT event UID (unique identifier)
 * @param lat - Latitude
 * @param lon - Longitude
 * @param callsign - Callsign/title
 * @param type - CoT type (for determining icon/color)
 * @returns MapMarker object
 */
export function createMarkerFromCot(
  uid: string,
  lat: number,
  lon: number,
  callsign?: string,
  type?: string
): MapMarker {
  return {
    id: uid,
    latitude: lat,
    longitude: lon,
    title: callsign || uid,
    subtitle: type,
  };
}

/**
 * Helper function to create camera centered on markers.
 *
 * @param markers - Array of markers to include in bounds
 * @param padding - Padding factor (default 1.2 for 20% padding)
 * @returns Camera configuration
 */
export function createCameraFromMarkers(
  markers: MapMarker[],
  padding: number = 1.2
): MapCamera | null {
  if (markers.length === 0) {
    return null;
  }

  // Calculate bounds
  let minLat = markers[0].latitude;
  let maxLat = markers[0].latitude;
  let minLon = markers[0].longitude;
  let maxLon = markers[0].longitude;

  for (const marker of markers) {
    minLat = Math.min(minLat, marker.latitude);
    maxLat = Math.max(maxLat, marker.latitude);
    minLon = Math.min(minLon, marker.longitude);
    maxLon = Math.max(maxLon, marker.longitude);
  }

  // Calculate center
  const centerLat = (minLat + maxLat) / 2;
  const centerLon = (minLon + maxLon) / 2;

  // Calculate zoom level based on bounds
  const latDiff = (maxLat - minLat) * padding;
  const lonDiff = (maxLon - minLon) * padding;
  const maxDiff = Math.max(latDiff, lonDiff);

  // Rough zoom calculation (can be refined)
  let zoom = 10;
  if (maxDiff < 0.1) zoom = 12;
  else if (maxDiff < 0.5) zoom = 10;
  else if (maxDiff < 2) zoom = 8;
  else if (maxDiff < 10) zoom = 6;
  else zoom = 4;

  return {
    latitude: centerLat,
    longitude: centerLon,
    zoom,
    animated: true,
  };
}
