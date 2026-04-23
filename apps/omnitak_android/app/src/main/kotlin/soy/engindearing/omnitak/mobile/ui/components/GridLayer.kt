package soy.engindearing.omnitak.mobile.ui.components

import org.json.JSONArray
import org.json.JSONObject
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.style.sources.GeoJsonSource
import kotlin.math.ceil
import kotlin.math.floor

/**
 * Renders a lat/lon graticule inside the `grid-src` source defined
 * in the style JSON. This is a tactical shortcut — it is not true
 * MGRS (which needs UTM zone + 100 km square computation); a proper
 * MGRS conversion lands alongside the coordinate-display work in
 * the settings slice.
 *
 * [update] takes a center point and emits lines covering a box
 * around it at [stepDegrees] spacing. Callers should nudge the
 * step based on zoom — e.g. 1.0° at world view, 0.1° at ~zoom 10,
 * 0.01° at ~zoom 14.
 */
object GridLayer {
    const val SOURCE_ID = "grid-src"
    const val LINE_LAYER_ID = "grid-line"
    const val LABEL_LAYER_ID = "grid-label"

    fun update(
        map: MapLibreMap,
        center: LatLng,
        halfWidthDegrees: Double = 2.0,
        stepDegrees: Double = 0.1,
    ) {
        val style = map.style ?: return
        val src = style.getSourceAs<GeoJsonSource>(SOURCE_ID) ?: return
        src.setGeoJson(
            org.maplibre.geojson.FeatureCollection.fromJson(
                toFeatureCollection(center, halfWidthDegrees, stepDegrees).toString()
            )
        )
    }

    fun clear(map: MapLibreMap) {
        val src = map.style?.getSourceAs<GeoJsonSource>(SOURCE_ID) ?: return
        src.setGeoJson(
            org.maplibre.geojson.FeatureCollection.fromJson(
                """{"type":"FeatureCollection","features":[]}"""
            )
        )
    }

    private fun toFeatureCollection(
        center: LatLng,
        halfWidth: Double,
        step: Double,
    ): JSONObject {
        val features = JSONArray()
        val latMin = floor((center.latitude - halfWidth) / step) * step
        val latMax = ceil((center.latitude + halfWidth) / step) * step
        val lonMin = floor((center.longitude - halfWidth) / step) * step
        val lonMax = ceil((center.longitude + halfWidth) / step) * step

        // Horizontal lines (constant lat).
        var lat = latMin
        while (lat <= latMax + 1e-9) {
            val coords = JSONArray()
                .put(JSONArray().put(lonMin).put(lat))
                .put(JSONArray().put(lonMax).put(lat))
            features.put(
                JSONObject()
                    .put("type", "Feature")
                    .put(
                        "properties",
                        JSONObject()
                            .put("kind", "lat")
                            .put("label", "%.2f".format(lat))
                    )
                    .put(
                        "geometry",
                        JSONObject().put("type", "LineString").put("coordinates", coords)
                    )
            )
            lat += step
        }

        // Vertical lines (constant lon).
        var lon = lonMin
        while (lon <= lonMax + 1e-9) {
            val coords = JSONArray()
                .put(JSONArray().put(lon).put(latMin))
                .put(JSONArray().put(lon).put(latMax))
            features.put(
                JSONObject()
                    .put("type", "Feature")
                    .put(
                        "properties",
                        JSONObject()
                            .put("kind", "lon")
                            .put("label", "%.2f".format(lon))
                    )
                    .put(
                        "geometry",
                        JSONObject().put("type", "LineString").put("coordinates", coords)
                    )
            )
            lon += step
        }

        return JSONObject()
            .put("type", "FeatureCollection")
            .put("features", features)
    }
}
