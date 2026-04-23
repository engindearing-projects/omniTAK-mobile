package soy.engindearing.omnitak.mobile.data

/**
 * Persistent map drawing. [points] is vertex-ordered; for [DrawingKind.POLYGON]
 * the first and last points are implicitly connected and don't need
 * to be duplicated. For [DrawingKind.CIRCLE] the list is
 * [center, edge] — a single radius point.
 */
data class Drawing(
    val id: String,
    val kind: DrawingKind,
    val name: String = "",
    val points: List<Pair<Double, Double>>,  // (lat, lon) pairs
    val colorHex: String = "#4ADE80",
    val widthPx: Float = 3f,
)

enum class DrawingKind {
    LINE, POLYGON, CIRCLE;
}
