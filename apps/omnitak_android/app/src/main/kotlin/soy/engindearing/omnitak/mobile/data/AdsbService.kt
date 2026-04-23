package soy.engindearing.omnitak.mobile.data

import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import java.net.HttpURLConnection
import java.net.URL
import kotlin.coroutines.coroutineContext

/**
 * OpenSky Network ADS-B poller. No API key required — the anonymous
 * tier is rate-limited to ~100 requests/day, good enough for tactical
 * situational awareness.
 *
 * Call [start] with a center point; the service re-polls every
 * [refreshSeconds] for aircraft inside a bounding box of
 * ±[halfWidthDegrees] around the center. Results land on [aircraft].
 *
 * Not backed by a long-lived connection — each tick opens a short HTTP
 * request and parses the states array. If the network is flaky we just
 * log + keep the last good frame.
 */
class AdsbService {

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var pollJob: Job? = null

    private val _aircraft = MutableStateFlow<List<Aircraft>>(emptyList())
    val aircraft: StateFlow<List<Aircraft>> = _aircraft.asStateFlow()

    private val _active = MutableStateFlow(false)
    val active: StateFlow<Boolean> = _active.asStateFlow()

    private val _lastError = MutableStateFlow<String?>(null)
    val lastError: StateFlow<String?> = _lastError.asStateFlow()

    fun start(
        centerLat: Double,
        centerLon: Double,
        halfWidthDegrees: Double = 1.5,
        refreshSeconds: Long = 15L,
    ) {
        stop()
        _active.value = true
        pollJob = scope.launch {
            while (coroutineContext.isActive) {
                runCatching { fetchOnce(centerLat, centerLon, halfWidthDegrees) }
                    .onFailure { t ->
                        Log.w(TAG, "ADSB fetch failed: ${t.javaClass.simpleName}: ${t.message}")
                        _lastError.value = t.message ?: t.javaClass.simpleName
                    }
                delay(refreshSeconds * 1000L)
            }
        }
    }

    fun stop() {
        pollJob?.cancel()
        pollJob = null
        _active.value = false
        _aircraft.value = emptyList()
    }

    private suspend fun fetchOnce(
        centerLat: Double,
        centerLon: Double,
        halfWidth: Double,
    ) {
        val minLat = centerLat - halfWidth
        val maxLat = centerLat + halfWidth
        val minLon = centerLon - halfWidth
        val maxLon = centerLon + halfWidth
        val url = URL(
            "https://opensky-network.org/api/states/all" +
                "?lamin=$minLat&lomin=$minLon&lamax=$maxLat&lomax=$maxLon"
        )

        val body = withContext(Dispatchers.IO) {
            val conn = (url.openConnection() as HttpURLConnection).apply {
                connectTimeout = 15_000
                readTimeout = 30_000
                requestMethod = "GET"
                setRequestProperty("User-Agent", "omniTAK-Android")
            }
            try {
                conn.inputStream.bufferedReader().use { it.readText() }
            } finally {
                conn.disconnect()
            }
        }
        val parsed = parseOpenSkyStates(body)
        Log.i(TAG, "OpenSky fetch ok: ${parsed.size} aircraft")
        _aircraft.value = parsed
        _lastError.value = null
    }

    companion object {
        private const val TAG = "AdsbService"

        /**
         * OpenSky /states/all returns: { "time": Long, "states": [[...], [...], ...] }
         * Each state is a 17-element array. We read only the fields we use today;
         * any nulls collapse to sensible defaults.
         */
        fun parseOpenSkyStates(json: String): List<Aircraft> {
            val root = org.json.JSONObject(json)
            val states: JSONArray = root.optJSONArray("states") ?: return emptyList()
            val out = mutableListOf<Aircraft>()
            for (i in 0 until states.length()) {
                val row = states.optJSONArray(i) ?: continue
                val icao24 = row.optString(0).trim()
                if (icao24.isEmpty()) continue
                val callsign = row.optString(1).trim()
                val originCountry = row.optString(2).trim()
                val timePos = row.optLongOrNull(3) ?: continue
                val lon = row.optDoubleOrNull(5) ?: continue
                val lat = row.optDoubleOrNull(6) ?: continue
                val baroAltitude = row.optDoubleOrNull(7) ?: 0.0
                val onGround = row.optBoolean(8, false)
                val velocity = row.optDoubleOrNull(9) ?: 0.0
                val heading = row.optDoubleOrNull(10) ?: 0.0
                val vRate = row.optDoubleOrNull(11) ?: 0.0
                val geoAltitude = row.optDoubleOrNull(13) ?: baroAltitude
                out += Aircraft(
                    icao24 = icao24,
                    callsign = callsign.ifEmpty { icao24 },
                    originCountry = originCountry,
                    lat = lat,
                    lon = lon,
                    altitudeM = geoAltitude,
                    velocityMs = velocity,
                    headingDeg = heading,
                    verticalRateMs = vRate,
                    onGround = onGround,
                    lastUpdateEpoch = timePos,
                )
            }
            return out
        }

        private fun JSONArray.optDoubleOrNull(index: Int): Double? =
            if (isNull(index)) null else optDouble(index).takeUnless { it.isNaN() }

        private fun JSONArray.optLongOrNull(index: Int): Long? =
            if (isNull(index)) null else optLong(index)
    }
}
