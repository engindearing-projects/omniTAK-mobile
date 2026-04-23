package soy.engindearing.omnitak.mobile.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import soy.engindearing.omnitak.mobile.ui.theme.TacticalAccent
import soy.engindearing.omnitak.mobile.ui.theme.TacticalBackground
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * One slice of a [RadialMenu]. [color] overrides the default neon accent;
 * [enabled] false dims the item but keeps it visible.
 */
data class RadialAction(
    val id: String,
    val icon: ImageVector,
    val label: String,
    val color: Color = TacticalAccent,
    val enabled: Boolean = true,
)

/**
 * ATAK-style radial / wheel menu. Renders a ring of [actions] around
 * [anchor] when [visible] is true. Tapping an item invokes [onSelect];
 * tapping outside the ring invokes [onDismiss]. Items are laid out
 * starting at 12 o'clock and proceeding clockwise.
 *
 * [anchor] is in map-surface pixels, typically from
 * `TacticalMap(onMapLongPress)`. The ring is clamped inside the overlay
 * bounds so it stays visible near screen edges.
 */
@Composable
fun RadialMenu(
    visible: Boolean,
    anchor: Offset,
    actions: List<RadialAction>,
    onSelect: (RadialAction) -> Unit,
    onDismiss: () -> Unit,
    radiusDp: Int = 90,
    itemSizeDp: Int = 56,
    modifier: Modifier = Modifier,
) {
    if (!visible || actions.isEmpty()) return

    val density = LocalDensity.current
    val radiusPx = with(density) { radiusDp.dp.toPx() }
    val itemPx = with(density) { itemSizeDp.dp.toPx() }
    val scale by animateFloatAsState(
        targetValue = if (visible) 1f else 0f,
        animationSpec = tween(durationMillis = 160),
        label = "radial-scale",
    )

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.35f))
            .clickable(indication = null, interactionSource = null, onClick = onDismiss),
    ) {
        // Ring items, evenly spaced starting from top (−π/2).
        val count = actions.size
        actions.forEachIndexed { index, action ->
            val angle = -Math.PI / 2.0 + (2.0 * Math.PI * index / count)
            val dx = (radiusPx * cos(angle)).toFloat()
            val dy = (radiusPx * sin(angle)).toFloat()
            val cx = (anchor.x + dx - itemPx / 2f).roundToInt()
            val cy = (anchor.y + dy - itemPx / 2f).roundToInt()

            val ringTint = if (action.enabled) action.color else Color.Gray
            Box(
                modifier = Modifier
                    .offset { IntOffset(cx, cy) }
                    .size(itemSizeDp.dp)
                    .graphicsLayer {
                        scaleX = scale
                        scaleY = scale
                    }
                    .clip(CircleShape)
                    .background(TacticalBackground)
                    .border(2.dp, ringTint, CircleShape)
                    .clickable(enabled = action.enabled) {
                        onSelect(action)
                    },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    action.icon,
                    contentDescription = action.label,
                    tint = ringTint,
                )
            }
        }

        // Center cancel button on the anchor.
        val cancelPx = with(density) { 48.dp.toPx() }
        val cx = (anchor.x - cancelPx / 2f).roundToInt()
        val cy = (anchor.y - cancelPx / 2f).roundToInt()
        Box(
            modifier = Modifier
                .offset { IntOffset(cx, cy) }
                .size(48.dp)
                .clip(CircleShape)
                .background(TacticalBackground)
                .clickable(onClick = onDismiss),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Filled.Close,
                contentDescription = "Close menu",
                tint = TacticalAccent,
            )
        }
    }
}

/** Small text caption shown under a radial ring for one-tap context. */
@Composable
fun RadialCaption(text: String, modifier: Modifier = Modifier) {
    Text(
        text,
        color = TacticalAccent,
        fontSize = 12.sp,
        fontWeight = FontWeight.Medium,
        modifier = modifier,
    )
}
