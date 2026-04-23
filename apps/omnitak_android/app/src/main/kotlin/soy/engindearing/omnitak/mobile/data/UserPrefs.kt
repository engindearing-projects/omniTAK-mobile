package soy.engindearing.omnitak.mobile.data

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.userPrefsDataStore by preferencesDataStore(name = "user_prefs")

enum class DistanceUnit { METRIC, IMPERIAL }
enum class CoordFormat { LATLON_DECIMAL, LATLON_DMS, MGRS }
enum class MapProvider { OSM_RASTER, SATELLITE_HINT, TOPO_HINT }

/**
 * Operator preferences — callsign, units, coord format, tile choice.
 * All string-backed in DataStore so the schema stays trivial; enum
 * cases round-trip by name.
 */
data class UserPrefs(
    val callsign: String = "OMNI-1",
    val team: String = "CYAN",
    val distanceUnit: DistanceUnit = DistanceUnit.METRIC,
    val coordFormat: CoordFormat = CoordFormat.LATLON_DECIMAL,
    val mapProvider: MapProvider = MapProvider.OSM_RASTER,
)

class UserPrefsStore(private val context: Context) {
    private val KEY_CALLSIGN = stringPreferencesKey("callsign")
    private val KEY_TEAM = stringPreferencesKey("team")
    private val KEY_DIST = stringPreferencesKey("distance_unit")
    private val KEY_COORD = stringPreferencesKey("coord_format")
    private val KEY_MAP = stringPreferencesKey("map_provider")

    val prefs: Flow<UserPrefs> = context.userPrefsDataStore.data.map { p ->
        UserPrefs(
            callsign = p[KEY_CALLSIGN] ?: "OMNI-1",
            team = p[KEY_TEAM] ?: "CYAN",
            distanceUnit = p[KEY_DIST]?.let { runCatching { DistanceUnit.valueOf(it) }.getOrNull() }
                ?: DistanceUnit.METRIC,
            coordFormat = p[KEY_COORD]?.let { runCatching { CoordFormat.valueOf(it) }.getOrNull() }
                ?: CoordFormat.LATLON_DECIMAL,
            mapProvider = p[KEY_MAP]?.let { runCatching { MapProvider.valueOf(it) }.getOrNull() }
                ?: MapProvider.OSM_RASTER,
        )
    }

    suspend fun update(block: (UserPrefs) -> UserPrefs) {
        context.userPrefsDataStore.edit { p ->
            val current = UserPrefs(
                callsign = p[KEY_CALLSIGN] ?: "OMNI-1",
                team = p[KEY_TEAM] ?: "CYAN",
                distanceUnit = p[KEY_DIST]?.let { runCatching { DistanceUnit.valueOf(it) }.getOrNull() }
                    ?: DistanceUnit.METRIC,
                coordFormat = p[KEY_COORD]?.let { runCatching { CoordFormat.valueOf(it) }.getOrNull() }
                    ?: CoordFormat.LATLON_DECIMAL,
                mapProvider = p[KEY_MAP]?.let { runCatching { MapProvider.valueOf(it) }.getOrNull() }
                    ?: MapProvider.OSM_RASTER,
            )
            val next = block(current)
            p[KEY_CALLSIGN] = next.callsign
            p[KEY_TEAM] = next.team
            p[KEY_DIST] = next.distanceUnit.name
            p[KEY_COORD] = next.coordFormat.name
            p[KEY_MAP] = next.mapProvider.name
        }
    }
}
