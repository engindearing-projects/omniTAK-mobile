package soy.engindearing.omnitak.mobile.data

import kotlin.math.asin
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Great-circle math helpers. Good enough for tactical distance /
 * bearing readouts; not meant to replace a proper geodesic library
 * over continental distances.
 */
object GeoMath {
    private const val EARTH_RADIUS_M = 6_371_008.8

    /** Haversine distance between two (lat, lon) pairs, in meters. */
    fun haversineMeters(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = sin(dLat / 2.0).let { it * it } +
            cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) *
            sin(dLon / 2.0).let { it * it }
        val c = 2.0 * asin(sqrt(a))
        return EARTH_RADIUS_M * c
    }

    /** Initial bearing from point 1 to point 2, degrees clockwise from north. */
    fun bearingDegrees(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
        val phi1 = Math.toRadians(lat1)
        val phi2 = Math.toRadians(lat2)
        val lambda = Math.toRadians(lon2 - lon1)
        val y = sin(lambda) * cos(phi2)
        val x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(lambda)
        val theta = atan2(y, x)
        return (Math.toDegrees(theta) + 360.0) % 360.0
    }

    /** "1,234 m" / "12.3 km" formatting for human readouts. */
    fun formatDistance(meters: Double): String = when {
        meters < 1000.0 -> "%.0f m".format(meters)
        meters < 10_000.0 -> "%.2f km".format(meters / 1000.0)
        else -> "%.1f km".format(meters / 1000.0)
    }

    /** "045°" / "123°" — three-digit magnetic-style readout. */
    fun formatBearing(degrees: Double): String = "%03.0f°".format(degrees)
}
