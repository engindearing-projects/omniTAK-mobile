package soy.engindearing.omnitak.mobile.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.launch
import soy.engindearing.omnitak.mobile.OmniTAKApp
import soy.engindearing.omnitak.mobile.data.CoordFormat
import soy.engindearing.omnitak.mobile.data.DistanceUnit
import soy.engindearing.omnitak.mobile.data.MapProvider
import soy.engindearing.omnitak.mobile.data.UserPrefs
import soy.engindearing.omnitak.mobile.ui.theme.TacticalAccent
import soy.engindearing.omnitak.mobile.ui.theme.TacticalBackground
import soy.engindearing.omnitak.mobile.ui.theme.TacticalSurface

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen() {
    val app = LocalContext.current.applicationContext as OmniTAKApp
    val prefs by app.userPrefsStore.prefs.collectAsState(initial = UserPrefs())
    val scope = rememberCoroutineScope()

    fun mutate(block: (UserPrefs) -> UserPrefs) {
        scope.launch {
            app.userPrefsStore.update { current -> block(current) }
        }
    }

    Scaffold(
        containerColor = TacticalBackground,
        topBar = {
            TopAppBar(
                title = { Text("Settings", color = MaterialTheme.colorScheme.onBackground) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = TacticalBackground,
                    titleContentColor = MaterialTheme.colorScheme.onBackground,
                ),
            )
        },
    ) { inner: PaddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(inner)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            SectionHeader("Identity")
            OutlinedTextField(
                value = prefs.callsign,
                onValueChange = { v -> mutate { it.copy(callsign = v) } },
                label = { Text("Callsign") },
                singleLine = true,
                colors = settingsFieldColors(),
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = prefs.team,
                onValueChange = { v -> mutate { it.copy(team = v.uppercase()) } },
                label = { Text("Team") },
                singleLine = true,
                colors = settingsFieldColors(),
                modifier = Modifier.fillMaxWidth(),
            )

            SectionHeader("Units")
            SegmentedRow(
                options = listOf(
                    DistanceUnit.METRIC to "Metric",
                    DistanceUnit.IMPERIAL to "Imperial",
                ),
                selected = prefs.distanceUnit,
                onSelect = { v -> mutate { it.copy(distanceUnit = v) } },
            )

            SectionHeader("Coordinates")
            SegmentedRow(
                options = listOf(
                    CoordFormat.LATLON_DECIMAL to "Lat/Lon",
                    CoordFormat.LATLON_DMS to "DMS",
                    CoordFormat.MGRS to "MGRS",
                ),
                selected = prefs.coordFormat,
                onSelect = { v -> mutate { it.copy(coordFormat = v) } },
            )

            SectionHeader("Map tiles")
            SegmentedRow(
                options = listOf(
                    MapProvider.OSM_RASTER to "OSM",
                    MapProvider.SATELLITE_HINT to "Satellite",
                    MapProvider.TOPO_HINT to "Topo",
                ),
                selected = prefs.mapProvider,
                onSelect = { v -> mutate { it.copy(mapProvider = v) } },
            )
            Text(
                "Only OSM is wired today. Satellite and Topo ship when we have an approved tile source with an offline cache path.",
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
                style = MaterialTheme.typography.bodySmall,
            )

            Spacer(Modifier.height(8.dp))
        }
    }
}

@Composable
private fun SectionHeader(text: String) {
    Text(
        text.uppercase(),
        color = TacticalAccent,
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.SemiBold,
        style = MaterialTheme.typography.labelLarge,
        modifier = Modifier.padding(top = 6.dp, bottom = 2.dp),
    )
}

@Composable
private fun <T> SegmentedRow(
    options: List<Pair<T, String>>,
    selected: T,
    onSelect: (T) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(TacticalSurface),
    ) {
        options.forEachIndexed { idx, (value, label) ->
            val isSelected = value == selected
            Row(
                modifier = Modifier
                    .weight(1f)
                    .height(44.dp)
                    .background(if (isSelected) TacticalAccent.copy(alpha = 0.2f) else Color.Transparent)
                    .clickable { onSelect(value) },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center,
            ) {
                Text(
                    label,
                    color = if (isSelected) TacticalAccent else MaterialTheme.colorScheme.onBackground.copy(alpha = 0.8f),
                    fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
            if (idx < options.size - 1) {
                Row(modifier = Modifier.width(1.dp).height(44.dp).background(TacticalBackground)) { }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun settingsFieldColors() = TextFieldDefaults.colors(
    focusedTextColor = MaterialTheme.colorScheme.onBackground,
    unfocusedTextColor = MaterialTheme.colorScheme.onBackground,
    focusedContainerColor = TacticalSurface,
    unfocusedContainerColor = TacticalSurface,
    focusedIndicatorColor = TacticalAccent,
    unfocusedIndicatorColor = TacticalAccent.copy(alpha = 0.4f),
    focusedLabelColor = TacticalAccent,
    unfocusedLabelColor = TacticalAccent.copy(alpha = 0.6f),
    cursorColor = TacticalAccent,
)
