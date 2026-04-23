package soy.engindearing.omnitak.mobile.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import soy.engindearing.omnitak.mobile.ui.theme.TacticalAccent
import soy.engindearing.omnitak.mobile.ui.theme.TacticalBackground
import soy.engindearing.omnitak.mobile.ui.theme.TacticalSurface

/**
 * Map overlay visibility picker. One switch per toggleable layer;
 * caller owns the backing state and handles persistence.
 */
@Composable
fun LayersDialog(
    gridEnabled: Boolean,
    drawingsVisible: Boolean,
    aircraftVisible: Boolean,
    contactsVisible: Boolean,
    onToggleGrid: (Boolean) -> Unit,
    onToggleDrawings: (Boolean) -> Unit,
    onToggleAircraft: (Boolean) -> Unit,
    onToggleContacts: (Boolean) -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = TacticalSurface,
        title = {
            Text(
                "Map layers",
                color = MaterialTheme.colorScheme.onBackground,
                fontFamily = FontFamily.Monospace,
            )
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                LayerRow("Contacts", contactsVisible, onToggleContacts)
                LayerRow("Drawings", drawingsVisible, onToggleDrawings)
                LayerRow("Aircraft (ADSB)", aircraftVisible, onToggleAircraft)
                LayerRow("Lat/Lon grid", gridEnabled, onToggleGrid)
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("Done", color = TacticalAccent)
            }
        },
    )
}

@Composable
private fun LayerRow(label: String, checked: Boolean, onToggle: (Boolean) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            label,
            color = MaterialTheme.colorScheme.onBackground,
            modifier = Modifier.weight(1f),
        )
        Switch(
            checked = checked,
            onCheckedChange = onToggle,
            colors = SwitchDefaults.colors(
                checkedThumbColor = TacticalBackground,
                checkedTrackColor = TacticalAccent,
                uncheckedThumbColor = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
                uncheckedTrackColor = TacticalBackground,
            ),
        )
    }
}
