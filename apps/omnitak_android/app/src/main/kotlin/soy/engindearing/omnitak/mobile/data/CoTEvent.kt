package soy.engindearing.omnitak.mobile.data

/**
 * MIL-STD-2525 affiliation parsed from a CoT event `type` attribute
 * (the second token after "a-", e.g. `a-f-…` → Friend). Colors roughly
 * follow the ATAK palette — green/cyan/red/yellow.
 */
enum class CoTAffiliation(val code: Char) {
    FRIEND('f'),
    HOSTILE('h'),
    NEUTRAL('n'),
    UNKNOWN('u'),
    PENDING('p'),
    ASSUMED('a'),
    SUSPECT('s'),
    EXERCISE('j');

    companion object {
        fun fromCode(c: Char?): CoTAffiliation = entries.firstOrNull { it.code == c } ?: UNKNOWN
    }
}

/**
 * A parsed Cursor-on-Target event. Mirrors the subset of fields OmniTAK
 * renders on the map — uid, geographic position, affiliation, callsign,
 * timestamps. Unknown fields stay raw on [rawXml] for debug inspection.
 */
data class CoTEvent(
    val uid: String,
    val type: String,
    val lat: Double,
    val lon: Double,
    val hae: Double = 0.0,
    val ce: Double = 9_999_999.0,
    val le: Double = 9_999_999.0,
    val timeIso: String? = null,
    val staleIso: String? = null,
    val callsign: String? = null,
    val remarks: String = "",
    val rawXml: String? = null,
) {
    val affiliation: CoTAffiliation
        get() {
            val parts = type.split('-')
            return CoTAffiliation.fromCode(parts.getOrNull(1)?.firstOrNull())
        }
}
