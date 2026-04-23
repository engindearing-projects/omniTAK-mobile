package soy.engindearing.omnitak.mobile.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import org.maplibre.android.geometry.LatLng
import soy.engindearing.omnitak.mobile.data.CoTAffiliation
import soy.engindearing.omnitak.mobile.ui.theme.TacticalAccent
import soy.engindearing.omnitak.mobile.ui.theme.TacticalBackground
import soy.engindearing.omnitak.mobile.ui.theme.TacticalSurface

/** Result payload emitted when the user saves a marker sheet. */
data class MarkerEditResult(
    val callsign: String,
    val affiliation: CoTAffiliation,
    val altitudeMeters: Double?,
    val remarks: String,
)

/**
 * Bottom sheet for editing a newly-dropped or existing point marker.
 * Fields shipped in this slice: callsign + affiliation. Remarks and
 * altitude arrive in the full marker-edit UI (Slice 11).
 *
 * [initialCallsign] seeds the input; [latLng] is shown read-only so the
 * operator can sanity-check where the marker will land.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MarkerEditSheet(
    visible: Boolean,
    latLng: LatLng?,
    initialCallsign: String = "",
    initialAffiliation: CoTAffiliation = CoTAffiliation.FRIEND,
    initialAltitude: Double? = null,
    initialRemarks: String = "",
    editing: Boolean = false,
    onSave: (MarkerEditResult) -> Unit,
    onDelete: (() -> Unit)? = null,
    onDismiss: () -> Unit,
) {
    if (!visible) return
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    var callsign by remember(initialCallsign) { mutableStateOf(initialCallsign) }
    var affiliation by remember(initialAffiliation) { mutableStateOf(initialAffiliation) }
    var altitudeText by remember(initialAltitude) {
        mutableStateOf(initialAltitude?.let { "%.0f".format(it) } ?: "")
    }
    var remarks by remember(initialRemarks) { mutableStateOf(initialRemarks) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = state,
        containerColor = TacticalSurface,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 8.dp),
        ) {
            Text(
                if (editing) "Edit Marker" else "Drop Marker",
                color = MaterialTheme.colorScheme.onBackground,
                fontWeight = FontWeight.Bold,
                style = MaterialTheme.typography.titleLarge,
            )

            Spacer(Modifier.height(4.dp))
            latLng?.let {
                Text(
                    "%.5f, %.5f".format(it.latitude, it.longitude),
                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.7f),
                    fontFamily = FontFamily.Monospace,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }

            Spacer(Modifier.height(16.dp))
            OutlinedTextField(
                value = callsign,
                onValueChange = { callsign = it },
                label = { Text("Callsign") },
                singleLine = true,
                colors = TextFieldDefaults.colors(
                    focusedTextColor = MaterialTheme.colorScheme.onBackground,
                    unfocusedTextColor = MaterialTheme.colorScheme.onBackground,
                    focusedContainerColor = TacticalBackground,
                    unfocusedContainerColor = TacticalBackground,
                    focusedIndicatorColor = TacticalAccent,
                    unfocusedIndicatorColor = TacticalAccent.copy(alpha = 0.4f),
                    focusedLabelColor = TacticalAccent,
                    unfocusedLabelColor = TacticalAccent.copy(alpha = 0.6f),
                    cursorColor = TacticalAccent,
                ),
                modifier = Modifier.fillMaxWidth(),
            )

            Spacer(Modifier.height(16.dp))
            Text(
                "Affiliation",
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.7f),
                style = MaterialTheme.typography.labelLarge,
            )
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(
                    CoTAffiliation.FRIEND,
                    CoTAffiliation.HOSTILE,
                    CoTAffiliation.NEUTRAL,
                    CoTAffiliation.UNKNOWN,
                ).forEach { a ->
                    AffiliationChip(
                        affiliation = a,
                        selected = affiliation == a,
                        onClick = { affiliation = a },
                    )
                }
            }

            Spacer(Modifier.height(16.dp))
            OutlinedTextField(
                value = altitudeText,
                onValueChange = { altitudeText = it.filter { ch -> ch.isDigit() || ch == '.' || ch == '-' } },
                label = { Text("Altitude (m HAE)") },
                singleLine = true,
                colors = tacticalFieldColors(),
                modifier = Modifier.fillMaxWidth(),
            )

            Spacer(Modifier.height(12.dp))
            OutlinedTextField(
                value = remarks,
                onValueChange = { remarks = it },
                label = { Text("Remarks") },
                colors = tacticalFieldColors(),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(96.dp),
            )

            Spacer(Modifier.height(24.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (editing && onDelete != null) {
                    TextButton(
                        onClick = onDelete,
                        colors = ButtonDefaults.textButtonColors(
                            contentColor = soy.engindearing.omnitak.mobile.ui.theme.HostileRed,
                        ),
                    ) { Text("Delete") }
                }
                Spacer(Modifier.weight(1f))
                TextButton(onClick = onDismiss) { Text("Cancel") }
                Spacer(Modifier.width(8.dp))
                Button(
                    onClick = {
                        onSave(
                            MarkerEditResult(
                                callsign = callsign.trim().ifEmpty { "Marker" },
                                affiliation = affiliation,
                                altitudeMeters = altitudeText.toDoubleOrNull(),
                                remarks = remarks.trim(),
                            )
                        )
                    },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = TacticalAccent,
                        contentColor = TacticalBackground,
                    ),
                ) { Text(if (editing) "Save" else "Drop") }
            }
            Spacer(Modifier.height(16.dp))
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun tacticalFieldColors() = TextFieldDefaults.colors(
    focusedTextColor = MaterialTheme.colorScheme.onBackground,
    unfocusedTextColor = MaterialTheme.colorScheme.onBackground,
    focusedContainerColor = TacticalBackground,
    unfocusedContainerColor = TacticalBackground,
    focusedIndicatorColor = TacticalAccent,
    unfocusedIndicatorColor = TacticalAccent.copy(alpha = 0.4f),
    focusedLabelColor = TacticalAccent,
    unfocusedLabelColor = TacticalAccent.copy(alpha = 0.6f),
    cursorColor = TacticalAccent,
)

@Composable
private fun AffiliationChip(
    affiliation: CoTAffiliation,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val color = Color(ContactLayer.previewColor(affiliation))
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(if (selected) color.copy(alpha = 0.25f) else TacticalBackground)
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        androidx.compose.foundation.layout.Box(
            Modifier
                .size(10.dp)
                .clip(CircleShape)
                .background(color),
        )
        Spacer(Modifier.width(6.dp))
        Text(
            affiliation.name.lowercase().replaceFirstChar { it.uppercase() },
            color = if (selected) color else MaterialTheme.colorScheme.onBackground.copy(alpha = 0.8f),
            fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
        )
    }
}
