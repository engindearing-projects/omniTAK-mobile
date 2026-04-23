package soy.engindearing.omnitak.mobile.data

import android.util.Xml
import org.xmlpull.v1.XmlPullParser
import java.io.StringReader

/**
 * Lightweight XmlPullParser-based CoT event parser. Only pulls the
 * fields OmniTAK renders today (uid, type, time, stale, point, contact
 * callsign). Silently returns null on malformed input rather than
 * throwing — the read loop can't afford to die on a single bad event.
 *
 * Usage:
 *   CoTParser.parse("<event …><point …/><detail><contact callsign=…/></detail></event>")
 */
object CoTParser {
    fun parse(xml: String): CoTEvent? = runCatching {
        val parser: XmlPullParser = Xml.newPullParser()
        parser.setFeature(XmlPullParser.FEATURE_PROCESS_NAMESPACES, false)
        parser.setInput(StringReader(xml))

        var uid: String? = null
        var type: String? = null
        var timeIso: String? = null
        var staleIso: String? = null
        var lat: Double? = null
        var lon: Double? = null
        var hae: Double = 0.0
        var ce: Double = 9_999_999.0
        var le: Double = 9_999_999.0
        var callsign: String? = null

        var ev = parser.eventType
        while (ev != XmlPullParser.END_DOCUMENT) {
            if (ev == XmlPullParser.START_TAG) {
                when (parser.name) {
                    "event" -> {
                        uid = parser.getAttributeValue(null, "uid")
                        type = parser.getAttributeValue(null, "type")
                        timeIso = parser.getAttributeValue(null, "time")
                        staleIso = parser.getAttributeValue(null, "stale")
                    }
                    "point" -> {
                        lat = parser.getAttributeValue(null, "lat")?.toDoubleOrNull()
                        lon = parser.getAttributeValue(null, "lon")?.toDoubleOrNull()
                        hae = parser.getAttributeValue(null, "hae")?.toDoubleOrNull() ?: 0.0
                        ce = parser.getAttributeValue(null, "ce")?.toDoubleOrNull() ?: 9_999_999.0
                        le = parser.getAttributeValue(null, "le")?.toDoubleOrNull() ?: 9_999_999.0
                    }
                    "contact" -> {
                        callsign = parser.getAttributeValue(null, "callsign") ?: callsign
                    }
                }
            }
            ev = parser.next()
        }

        if (uid == null || type == null || lat == null || lon == null) return@runCatching null
        CoTEvent(
            uid = uid,
            type = type,
            lat = lat,
            lon = lon,
            hae = hae,
            ce = ce,
            le = le,
            timeIso = timeIso,
            staleIso = staleIso,
            callsign = callsign,
            rawXml = xml,
        )
    }.getOrNull()
}
