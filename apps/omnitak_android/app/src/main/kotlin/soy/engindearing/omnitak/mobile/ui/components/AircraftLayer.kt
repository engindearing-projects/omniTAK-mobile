package soy.engindearing.omnitak.mobile.ui.components

import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import org.maplibre.android.maps.MapLibreMap
import org.maplibre.android.style.sources.GeoJsonSource
import soy.engindearing.omnitak.mobile.data.Aircraft

/**
 * Pushes ADS-B aircraft state into the pre-baked `aircraft-src`
 * GeoJson source. The style JSON declares a circle layer + a symbol
 * layer for the callsign so that the emulator GL path renders
 * reliably (see ContactLayer for the same reason).
 *
 * Each aircraft point carries `heading` and `callsign` properties
 * so the SymbolLayer can rotate + label.
 */
object AircraftLayer {
    const val SOURCE_ID = "aircraft-src"
    const val CIRCLE_LAYER_ID = "aircraft-circle"
    const val LABEL_LAYER_ID = "aircraft-label"

    fun update(map: MapLibreMap, aircraft: List<Aircraft>) {
        val style = map.style ?: return
        val src = style.getSourceAs<GeoJsonSource>(SOURCE_ID) ?: return
        val fc = toFeatureCollection(aircraft)
        src.setGeoJson(
            org.maplibre.geojson.FeatureCollection.fromJson(fc.toString())
        )
        if (aircraft.isNotEmpty()) {
            Log.i("AircraftLayer", "pushed ${aircraft.size} aircraft to $SOURCE_ID")
        }
    }

    fun clear(map: MapLibreMap) {
        val src = map.style?.getSourceAs<GeoJsonSource>(SOURCE_ID) ?: return
        src.setGeoJson(
            org.maplibre.geojson.FeatureCollection.fromJson(
                """{"type":"FeatureCollection","features":[]}"""
            )
        )
    }

    private fun toFeatureCollection(aircraft: List<Aircraft>): JSONObject {
        val features = JSONArray()
        aircraft.forEach { a ->
            features.put(
                JSONObject()
                    .put("type", "Feature")
                    .put(
                        "properties",
                        JSONObject()
                            .put("icao24", a.icao24)
                            .put("callsign", a.callsign)
                            .put("heading", a.headingDeg)
                            .put("onGround", a.onGround)
                            .put("altitudeFt", a.altitudeFt)
                            .put("speedKt", a.speedKt)
                    )
                    .put(
                        "geometry",
                        JSONObject()
                            .put("type", "Point")
                            .put("coordinates", JSONArray().put(a.lon).put(a.lat))
                    )
            )
        }
        return JSONObject()
            .put("type", "FeatureCollection")
            .put("features", features)
    }
}
