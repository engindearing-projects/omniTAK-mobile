package soy.engindearing.omnitak.mobile.ui.components

import org.json.JSONArray
import org.json.JSONObject
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.maps.Style
import org.maplibre.android.style.sources.GeoJsonSource
import soy.engindearing.omnitak.mobile.data.CoTAffiliation
import soy.engindearing.omnitak.mobile.data.CoTEvent

/**
 * Helper for the contact-rendering source baked into [OSM_RASTER_STYLE].
 * The source + circle + label layers are declared in the style JSON at
 * load time because programmatic `style.addLayer` / `addSource` after
 * `setStyle(builder, onStyleLoaded)` renders nothing on some emulator
 * GPU configurations — a MapLibre-Android quirk we only caught by
 * comparison. The live source id stays reachable via [SOURCE_ID] so
 * [update] can push fresh feature data without rebuilding layers.
 *
 * Affiliation-to-color mapping follows the ATAK palette:
 *   friend → green, hostile → red, neutral → yellow, unknown → purple.
 */
object ContactLayer {
    const val SOURCE_ID = "contacts-src"
    const val CIRCLE_LAYER_ID = "contacts-circles"
    const val LABEL_LAYER_ID = "contacts-labels"

    fun update(map: MapLibreMap, contacts: Collection<CoTEvent>) {
        val style = map.style ?: return
        val src = style.getSourceAs<GeoJsonSource>(SOURCE_ID) ?: return
        val fc = org.maplibre.geojson.FeatureCollection.fromJson(
            toFeatureCollection(contacts).toString()
        )
        src.setGeoJson(fc)
    }

    private fun toFeatureCollection(contacts: Collection<CoTEvent>): JSONObject {
        val features = JSONArray()
        contacts.forEach { c ->
            val props = JSONObject()
                .put("uid", c.uid)
                .put("type", c.type)
                .put("affiliation", c.affiliation.code.toString())
                .put("callsign", c.callsign ?: c.uid)
            val geom = JSONObject()
                .put("type", "Point")
                .put("coordinates", JSONArray().put(c.lon).put(c.lat))
            features.put(
                JSONObject()
                    .put("type", "Feature")
                    .put("properties", props)
                    .put("geometry", geom)
            )
        }
        return JSONObject()
            .put("type", "FeatureCollection")
            .put("features", features)
    }

    /** Stable color for previewing an affiliation outside the map. */
    fun previewColor(affiliation: CoTAffiliation): Int = when (affiliation) {
        CoTAffiliation.FRIEND -> 0xFF4ADE80.toInt()
        CoTAffiliation.HOSTILE -> 0xFFF44336.toInt()
        CoTAffiliation.NEUTRAL -> 0xFFFFC107.toInt()
        else -> 0xFFB39DDB.toInt()
    }
}
