package soy.engindearing.omnitak.mobile.ui.components

import android.annotation.SuppressLint
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import org.maplibre.android.MapLibre
import org.maplibre.android.camera.CameraPosition
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.location.LocationComponentActivationOptions
import org.maplibre.android.location.modes.CameraMode
import org.maplibre.android.location.modes.RenderMode
import org.maplibre.android.maps.MapView
import org.maplibre.android.maps.Style
import soy.engindearing.omnitak.mobile.data.CoTEvent

/**
 * MapLibre-backed map surface. Forwards Android lifecycle events to the
 * native MapView — skipping those leaks native GL resources or crashes
 * on rotation.
 *
 * [onMapLongPress] emits the geographic LatLng of the long-press, along
 * with the on-screen pixel offset so overlays (e.g. radial menu) can
 * anchor to the touch point.
 *
 * [locationEnabled] activates MapLibre's built-in LocationComponent —
 * a blue dot for the user's position and a compass arrow for heading.
 * The caller is responsible for ensuring runtime location permission
 * is granted before flipping this to true.
 */
@Composable
fun TacticalMap(
    initialCenter: LatLng = LatLng(47.6588, -117.4260),  // Spokane, WA
    initialZoom: Double = 11.0,
    styleJson: String = OSM_RASTER_STYLE,
    onMapLongPress: ((LatLng, Offset) -> Unit)? = null,
    onContactTap: ((CoTEvent) -> Unit)? = null,
    onMapSingleTap: ((LatLng) -> Boolean)? = null,
    locationEnabled: Boolean = false,
    recenterTrigger: Any? = null,
    contacts: Collection<CoTEvent> = emptyList(),
    measurementPoints: List<LatLng> = emptyList(),
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val currentLongPress by rememberUpdatedState(onMapLongPress)
    val currentContactTap by rememberUpdatedState(onContactTap)
    val currentMapSingleTap by rememberUpdatedState(onMapSingleTap)
    val currentLocationEnabled by rememberUpdatedState(locationEnabled)
    val currentContacts by rememberUpdatedState(contacts)
    val currentMeasurementPoints by rememberUpdatedState(measurementPoints)

    val mapView = remember {
        MapLibre.getInstance(context)
        MapView(context).apply {
            onCreate(null)
            getMapAsync { map ->
                map.cameraPosition = CameraPosition.Builder()
                    .target(initialCenter)
                    .zoom(initialZoom)
                    .build()
                map.setStyle(Style.Builder().fromJson(styleJson)) { style ->
                    ContactLayer.update(map, currentContacts)
                    MeasurementLayer.update(map, currentMeasurementPoints)
                    if (currentLocationEnabled) {
                        activateLocation(map, style, context)
                    }
                }
                map.uiSettings.apply {
                    isCompassEnabled = true
                    isLogoEnabled = false
                    isAttributionEnabled = true
                }
                map.addOnMapLongClickListener { latLng ->
                    val screen = map.projection.toScreenLocation(latLng)
                    currentLongPress?.invoke(latLng, Offset(screen.x, screen.y))
                    true
                }
                map.addOnMapClickListener { latLng ->
                    // Mode-specific tap handler wins when provided
                    // (e.g. measurement mode eats taps to add points).
                    currentMapSingleTap?.let { handler ->
                        if (handler(latLng)) return@addOnMapClickListener true
                    }
                    val cb = currentContactTap ?: return@addOnMapClickListener false
                    val tapPx = map.projection.toScreenLocation(latLng)
                    var best: CoTEvent? = null
                    var bestDist = Float.MAX_VALUE
                    currentContacts.forEach { c ->
                        val px = map.projection.toScreenLocation(LatLng(c.lat, c.lon))
                        val d = kotlin.math.hypot(
                            (px.x - tapPx.x).toDouble(),
                            (px.y - tapPx.y).toDouble(),
                        ).toFloat()
                        if (d < bestDist) {
                            bestDist = d
                            best = c
                        }
                    }
                    if (best != null && bestDist < TAP_HIT_RADIUS_PX) {
                        cb(best!!)
                        true
                    } else {
                        false
                    }
                }
            }
        }
    }

    // Flip the location layer on when permission is granted after the
    // map is already alive.
    DisposableEffect(mapView, locationEnabled) {
        if (locationEnabled) {
            mapView.getMapAsync { map ->
                val style = map.style
                if (style != null && !map.locationComponent.isLocationComponentActivated) {
                    activateLocation(map, style, context)
                }
                if (map.locationComponent.isLocationComponentActivated) {
                    safeEnableLocation(map)
                }
            }
        }
        onDispose { }
    }

    // Each time [recenterTrigger] changes, briefly flip camera to
    // TRACKING to pan to the user, then restore NONE so the user can
    // still pan freely.
    DisposableEffect(mapView, recenterTrigger) {
        if (recenterTrigger != null && locationEnabled) {
            mapView.getMapAsync { map ->
                if (map.locationComponent.isLocationComponentActivated) {
                    map.locationComponent.cameraMode = CameraMode.TRACKING
                    map.locationComponent.zoomWhileTracking(15.0)
                }
            }
        }
        onDispose { }
    }

    // Push contact updates through to the GeoJson source whenever the
    // caller's collection reference changes.
    DisposableEffect(mapView, contacts) {
        mapView.getMapAsync { map ->
            if (map.style != null) ContactLayer.update(map, contacts)
        }
        onDispose { }
    }

    DisposableEffect(mapView, measurementPoints) {
        mapView.getMapAsync { map ->
            if (map.style != null) MeasurementLayer.update(map, measurementPoints)
        }
        onDispose { }
    }

    DisposableEffect(lifecycleOwner, mapView) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> mapView.onStart()
                Lifecycle.Event.ON_RESUME -> mapView.onResume()
                Lifecycle.Event.ON_PAUSE -> mapView.onPause()
                Lifecycle.Event.ON_STOP -> mapView.onStop()
                Lifecycle.Event.ON_DESTROY -> mapView.onDestroy()
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            mapView.onDestroy()
        }
    }

    AndroidView(factory = { mapView }, modifier = modifier)
}

@SuppressLint("MissingPermission")
private fun activateLocation(
    map: org.maplibre.android.maps.MapLibreMap,
    style: Style,
    context: android.content.Context,
) {
    val options = LocationComponentActivationOptions.builder(context, style)
        .useDefaultLocationEngine(true)
        .build()
    map.locationComponent.activateLocationComponent(options)
    safeEnableLocation(map)
}

@SuppressLint("MissingPermission")
private fun safeEnableLocation(map: org.maplibre.android.maps.MapLibreMap) {
    map.locationComponent.isLocationComponentEnabled = true
    map.locationComponent.renderMode = RenderMode.COMPASS
    map.locationComponent.cameraMode = CameraMode.NONE
}

/**
 * Inline raster OSM style. Reliable on emulators where the demotiles
 * vector-tile style had GL issues. Same raster-layer shape swaps in
 * any XYZ tile URL (satellite, topo, custom TAK tile server) later.
 */
/**
 * Screen-space radius (pixels) used to decide whether a map tap lands
 * on a contact marker. ~48dp ≈ finger-tip tolerance on a mid-density
 * device; we stay in px here because MapLibre's projection returns
 * pixels directly.
 */
private const val TAP_HIT_RADIUS_PX = 72f

/**
 * Contact source + layers are declared inline in the style JSON. On
 * the API 36 emulator, `style.addSource` / `style.addLayer` called from
 * the `setStyle(builder, onStyleLoaded)` callback occasionally renders
 * nothing despite the calls reporting success and the source/layer
 * appearing in the style — a MapLibre-Android GL quirk we haven't
 * root-caused. Declaring everything in the style JSON avoids that
 * path entirely; `ContactLayer.update` pushes fresh feature data to
 * the existing source via `setGeoJson`.
 */
const val OSM_RASTER_STYLE = """
{
  "version": 8,
  "name": "OmniTAK OSM",
  "sources": {
    "osm": {
      "type": "raster",
      "tiles": ["https://tile.openstreetmap.org/{z}/{x}/{y}.png"],
      "tileSize": 256,
      "maxzoom": 19,
      "attribution": "© OpenStreetMap contributors"
    },
    "contacts-src": {
      "type": "geojson",
      "data": {"type": "FeatureCollection", "features": []}
    },
    "measurement-src": {
      "type": "geojson",
      "data": {"type": "FeatureCollection", "features": []}
    }
  },
  "layers": [
    {"id": "osm-tiles", "type": "raster", "source": "osm"},
    {
      "id": "measurement-line",
      "type": "line",
      "source": "measurement-src",
      "filter": ["==", ["get", "kind"], "line"],
      "paint": {
        "line-color": "#4ADE80",
        "line-width": 3,
        "line-dasharray": [2, 1]
      }
    },
    {
      "id": "measurement-points",
      "type": "circle",
      "source": "measurement-src",
      "filter": ["==", ["get", "kind"], "vertex"],
      "paint": {
        "circle-radius": 6,
        "circle-color": "#4ADE80",
        "circle-stroke-width": 2,
        "circle-stroke-color": "#0A1628"
      }
    },
    {
      "id": "measurement-labels",
      "type": "symbol",
      "source": "measurement-src",
      "filter": ["==", ["get", "kind"], "vertex"],
      "layout": {
        "text-field": ["get", "label"],
        "text-size": 12,
        "text-offset": [0, -1.4],
        "text-allow-overlap": true
      },
      "paint": {
        "text-color": "#FFFFFF",
        "text-halo-color": "#0A1628",
        "text-halo-width": 1.5
      }
    },
    {
      "id": "contacts-circles",
      "type": "circle",
      "source": "contacts-src",
      "paint": {
        "circle-radius": 10,
        "circle-stroke-width": 2,
        "circle-stroke-color": "#0A1628",
        "circle-color": [
          "match",
          ["get", "affiliation"],
          "f", "#4ADE80",
          "h", "#F44336",
          "n", "#FFC107",
          "u", "#B39DDB",
          "#B39DDB"
        ]
      }
    },
    {
      "id": "contacts-labels",
      "type": "symbol",
      "source": "contacts-src",
      "layout": {
        "text-field": ["get", "callsign"],
        "text-size": 11,
        "text-offset": [0, 1.4],
        "text-allow-overlap": false
      },
      "paint": {
        "text-color": "#FFFFFF",
        "text-halo-color": "#0A1628",
        "text-halo-width": 1.5
      }
    }
  ]
}
"""
