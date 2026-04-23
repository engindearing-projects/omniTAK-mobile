package soy.engindearing.omnitak.mobile.ui.components

import org.json.JSONArray
import org.json.JSONObject
import org.maplibre.android.geometry.LatLng
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.style.sources.GeoJsonSource

/**
 * Updates the measurement source baked into [OSM_RASTER_STYLE]. The
 * source contains:
 *   - a single LineString feature connecting all waypoints
 *   - one Point feature per waypoint (for the vertex dots)
 * Layers (measurement-line / measurement-points) style them.
 */
object MeasurementLayer {
    const val SOURCE_ID = "measurement-src"
    const val LINE_LAYER_ID = "measurement-line"
    const val POINTS_LAYER_ID = "measurement-points"

    fun update(map: MapLibreMap, points: List<LatLng>) {
        val style = map.style ?: return
        val src = style.getSourceAs<GeoJsonSource>(SOURCE_ID) ?: return
        src.setGeoJson(
            org.maplibre.geojson.FeatureCollection.fromJson(toFeatureCollection(points).toString())
        )
    }

    private fun toFeatureCollection(points: List<LatLng>): JSONObject {
        val features = JSONArray()

        if (points.size >= 2) {
            val coords = JSONArray()
            points.forEach { ll ->
                coords.put(JSONArray().put(ll.longitude).put(ll.latitude))
            }
            features.put(
                JSONObject()
                    .put("type", "Feature")
                    .put("properties", JSONObject().put("kind", "line"))
                    .put(
                        "geometry",
                        JSONObject().put("type", "LineString").put("coordinates", coords)
                    )
            )
        }

        points.forEachIndexed { i, ll ->
            features.put(
                JSONObject()
                    .put("type", "Feature")
                    .put(
                        "properties",
                        JSONObject()
                            .put("kind", "vertex")
                            .put("index", i)
                            .put("label", if (i == 0) "A" else "${('A' + i)}")
                    )
                    .put(
                        "geometry",
                        JSONObject()
                            .put("type", "Point")
                            .put(
                                "coordinates",
                                JSONArray().put(ll.longitude).put(ll.latitude)
                            )
                    )
            )
        }

        return JSONObject()
            .put("type", "FeatureCollection")
            .put("features", features)
    }
}
