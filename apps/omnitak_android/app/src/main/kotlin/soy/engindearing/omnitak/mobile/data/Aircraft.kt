package soy.engindearing.omnitak.mobile.data

/**
 * ADS-B aircraft state vector. Units mirror OpenSky Network:
 * altitude in meters, velocity in m/s, heading in true-north degrees,
 * verticalRate in m/s (positive = climbing).
 *
 * icao24 is the unique 24-bit ICAO transponder address used as the
 * stable key across updates.
 */
data class Aircraft(
    val icao24: String,
    val callsign: String,
    val originCountry: String,
    val lat: Double,
    val lon: Double,
    val altitudeM: Double,
    val velocityMs: Double,
    val headingDeg: Double,
    val verticalRateMs: Double,
    val onGround: Boolean,
    val lastUpdateEpoch: Long,
) {
    val altitudeFt: Int get() = (altitudeM * 3.28084).toInt()
    val speedKt: Int get() = (velocityMs * 1.94384).toInt()
}
