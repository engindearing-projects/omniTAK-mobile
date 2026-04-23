package soy.engindearing.omnitak.mobile.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import soy.engindearing.omnitak.mobile.ui.theme.TacticalAccent
import soy.engindearing.omnitak.mobile.ui.theme.TacticalBackground

data class ToolEntry(
    val id: String,
    val icon: ImageVector,
    val label: String,
    val enabled: Boolean = true,
)

/**
 * Expanding tool rail anchored to the bottom-right of the map. Tapping
 * the main FAB toggles the vertical icon stack (drawing, measure,
 * layers, chat, etc.). [onSelect] fires with the tool id.
 *
 * The drawer only renders itself when its host allows — callers place it
 * in a Box on top of the map.
 */
@Composable
fun ToolsDrawer(
    tools: List<ToolEntry>,
    onSelect: (ToolEntry) -> Unit,
    modifier: Modifier = Modifier,
) {
    var expanded by remember { mutableStateOf(false) }

    Column(
        modifier = modifier.padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // Tool stack — visible when expanded.
        tools.forEach { tool ->
            AnimatedVisibility(
                visible = expanded,
                enter = fadeIn(tween(120)) + scaleIn(tween(120)),
                exit = fadeOut(tween(120)) + scaleOut(tween(120)),
            ) {
                ToolIcon(tool) {
                    expanded = false
                    onSelect(tool)
                }
            }
        }

        // Main FAB — always visible; swaps to a close icon when expanded.
        Box(
            modifier = Modifier
                .size(56.dp)
                .clip(CircleShape)
                .background(TacticalAccent)
                .clickable { expanded = !expanded },
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = if (expanded) Icons.Filled.Close else Icons.Filled.Menu,
                contentDescription = if (expanded) "Close tools" else "Open tools",
                tint = TacticalBackground,
            )
        }
    }
}

@Composable
private fun ToolIcon(tool: ToolEntry, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(48.dp)
            .clip(CircleShape)
            .background(TacticalBackground.copy(alpha = 0.9f))
            .clickable(enabled = tool.enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = tool.icon,
            contentDescription = tool.label,
            tint = if (tool.enabled) TacticalAccent else Color.Gray,
        )
    }
}
