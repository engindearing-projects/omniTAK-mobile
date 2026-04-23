package soy.engindearing.omnitak.mobile.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import soy.engindearing.omnitak.mobile.data.CoTAffiliation
import soy.engindearing.omnitak.mobile.data.CoTEvent
import soy.engindearing.omnitak.mobile.ui.theme.TacticalAccent
import soy.engindearing.omnitak.mobile.ui.theme.TacticalBackground
import soy.engindearing.omnitak.mobile.ui.theme.TacticalSurface

/**
 * Bottom-sheet list of every tracked CoT contact. Tap a row to pan
 * the map onto that contact; tap outside or the handle to dismiss.
 *
 * Rows are sorted with friendlies first, then neutrals, then hostiles
 * so the most common ATAK workflow — "where's my team?" — lines up
 * without scrolling.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ContactsPanel(
    contacts: List<CoTEvent>,
    onSelect: (CoTEvent) -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = false)
    val sorted = contacts.sortedWith(
        compareBy(
            { affiliationSortKey(it.affiliation) },
            { it.callsign ?: it.uid },
        ),
    )

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = TacticalBackground,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                "TEAMS",
                color = TacticalAccent,
                fontFamily = FontFamily.Monospace,
                fontWeight = FontWeight.SemiBold,
                style = MaterialTheme.typography.labelLarge,
            )
            Text(
                "${sorted.size} contact${if (sorted.size == 1) "" else "s"}",
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
                style = MaterialTheme.typography.bodySmall,
            )

            if (sorted.isEmpty()) {
                Text(
                    "No contacts yet. Connect to a TAK server or drop a marker to start populating this list.",
                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(vertical = 12.dp),
                )
            } else {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = 360.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    items(sorted, key = { it.uid }) { c -> ContactRow(c, onSelect) }
                }
            }
        }
    }
}

@Composable
private fun ContactRow(contact: CoTEvent, onSelect: (CoTEvent) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(androidx.compose.foundation.shape.RoundedCornerShape(6.dp))
            .background(TacticalSurface)
            .clickable { onSelect(contact) }
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(12.dp)
                .clip(CircleShape)
                .background(affiliationColor(contact.affiliation)),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                contact.callsign?.takeIf { it.isNotBlank() } ?: contact.uid,
                color = MaterialTheme.colorScheme.onBackground,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                "%.5f, %.5f".format(contact.lat, contact.lon) + " · " +
                    contact.affiliation.name.lowercase(),
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
                style = MaterialTheme.typography.labelSmall,
                fontFamily = FontFamily.Monospace,
            )
        }
    }
}

private fun affiliationSortKey(a: CoTAffiliation): Int = when (a) {
    CoTAffiliation.FRIEND -> 0
    CoTAffiliation.NEUTRAL -> 1
    CoTAffiliation.UNKNOWN, CoTAffiliation.PENDING, CoTAffiliation.ASSUMED -> 2
    CoTAffiliation.SUSPECT -> 3
    CoTAffiliation.HOSTILE -> 4
    CoTAffiliation.EXERCISE -> 5
}

private fun affiliationColor(a: CoTAffiliation): Color = when (a) {
    CoTAffiliation.FRIEND -> Color(0xFF4ADE80)
    CoTAffiliation.HOSTILE -> Color(0xFFF44336)
    CoTAffiliation.NEUTRAL -> Color(0xFFFFC107)
    CoTAffiliation.SUSPECT -> Color(0xFFFF9800)
    CoTAffiliation.EXERCISE -> Color(0xFF9C27B0)
    else -> Color(0xFFB39DDB)
}
