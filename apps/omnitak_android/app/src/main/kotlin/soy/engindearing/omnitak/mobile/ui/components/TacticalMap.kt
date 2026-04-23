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
    locationEnabled: Boolean = false,
    recenterTrigger: Any? = null,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val currentLongPress by rememberUpdatedState(onMapLongPress)
    val currentLocationEnabled by rememberUpdatedState(locationEnabled)

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
const val OSM_RASTER_STYLE = """
{
  "version": 8,
  "name": "OmniTAK OSM",
  "sources": {
    "osm": {
      "type": "raster",
      "tiles": [
        "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
      ],
      "tileSize": 256,
      "maxzoom": 19,
      "attribution": "© OpenStreetMap contributors"
    }
  },
  "layers": [
    {
      "id": "osm-tiles",
      "type": "raster",
      "source": "osm"
    }
  ]
}
"""
