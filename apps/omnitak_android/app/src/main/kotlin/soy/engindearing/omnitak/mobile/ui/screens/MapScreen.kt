package soy.engindearing.omnitak.mobile.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Brush
import androidx.compose.material.icons.filled.Chat
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.Flight
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Straighten
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import soy.engindearing.omnitak.mobile.ui.theme.TacticalAccent
import soy.engindearing.omnitak.mobile.ui.theme.TacticalBackground
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.maplibre.android.geometry.LatLng
import soy.engindearing.omnitak.mobile.OmniTAKApp
import soy.engindearing.omnitak.mobile.data.CoTAffiliation
import soy.engindearing.omnitak.mobile.data.CoTEvent
import soy.engindearing.omnitak.mobile.data.Drawing
import soy.engindearing.omnitak.mobile.data.DrawingKind
import soy.engindearing.omnitak.mobile.data.GeoMath
import soy.engindearing.omnitak.mobile.domain.ConnectionState
import soy.engindearing.omnitak.mobile.ui.components.ATAKStatusBar
import soy.engindearing.omnitak.mobile.ui.components.ContactsPanel
import soy.engindearing.omnitak.mobile.ui.components.LayersDialog
import soy.engindearing.omnitak.mobile.ui.components.MarkerEditSheet
import soy.engindearing.omnitak.mobile.ui.components.RadialAction
import soy.engindearing.omnitak.mobile.ui.components.RadialMenu
import soy.engindearing.omnitak.mobile.ui.components.TacticalMap
import soy.engindearing.omnitak.mobile.ui.components.ToolEntry
import soy.engindearing.omnitak.mobile.ui.components.ToolsDrawer
import soy.engindearing.omnitak.mobile.ui.components.rememberLocationPermission
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun MapScreen(onOpenTab: (String) -> Unit = {}) {
    val app = LocalContext.current.applicationContext as OmniTAKApp
    val active by app.serverManager.activeServer.collectAsState()
    val connState by app.serverManager.connectionState.collectAsState()
    val contacts by app.contactStore.contacts.collectAsState()

    val headerLabel = when (val s = connState) {
        is ConnectionState.Connected -> s.serverName
        is ConnectionState.Connecting -> "Connecting…"
        is ConnectionState.Failed -> "Failed"
        ConnectionState.Disconnected -> active?.name ?: "Offline"
    }

    var nowLabel by remember { mutableStateOf(timeLabel()) }
    LaunchedEffect(Unit) {
        while (true) {
            nowLabel = timeLabel()
            delay(15_000L)
        }
    }

    val locationGranted by rememberLocationPermission()
    var radialAnchor by remember { mutableStateOf<Offset?>(null) }
    var radialLatLng by remember { mutableStateOf<LatLng?>(null) }
    var markerSheetLatLng by remember { mutableStateOf<LatLng?>(null) }
    var editingMarker by remember { mutableStateOf<CoTEvent?>(null) }
    var recenterTick by remember { mutableStateOf(0) }
    var measurementActive by remember { mutableStateOf(false) }
    var measurementPoints by remember { mutableStateOf<List<LatLng>>(emptyList()) }
    var drawingKind by remember { mutableStateOf<DrawingKind?>(null) }
    var drawingPoints by remember { mutableStateOf<List<LatLng>>(emptyList()) }
    var drawingPickerOpen by remember { mutableStateOf(false) }
    var gridEnabled by remember { mutableStateOf(false) }
    var drawingsVisible by remember { mutableStateOf(true) }
    var aircraftVisible by remember { mutableStateOf(true) }
    var contactsVisible by remember { mutableStateOf(true) }
    var layersSheetOpen by remember { mutableStateOf(false) }
    var teamsPanelOpen by remember { mutableStateOf(false) }
    var followMeActive by remember { mutableStateOf(false) }
    var panTarget by remember { mutableStateOf<LatLng?>(null) }
    var panTargetTick by remember { mutableStateOf(0) }
    val adsbService = remember { soy.engindearing.omnitak.mobile.data.AdsbService() }
    val aircraft by adsbService.aircraft.collectAsState()
    val adsbActive by adsbService.active.collectAsState()
    DisposableEffect(adsbService) { onDispose { adsbService.stop() } }
    val drawings by app.drawingStore.drawings.collectAsState()
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    fun toast(msg: String) {
        scope.launch { snackbar.showSnackbar(msg, withDismissAction = true) }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
    ) {
        TacticalMap(
            modifier = Modifier.fillMaxSize(),
            onMapLongPress = { latLng, offset ->
                if (measurementActive) return@TacticalMap
                radialLatLng = latLng
                radialAnchor = offset
            },
            onContactTap = { event ->
                if (measurementActive) return@TacticalMap
                editingMarker = event
                markerSheetLatLng = LatLng(event.lat, event.lon)
            },
            onMapSingleTap = { latLng ->
                when {
                    measurementActive -> {
                        measurementPoints = measurementPoints + latLng
                        true
                    }
                    drawingKind != null -> {
                        drawingPoints = drawingPoints + latLng
                        true
                    }
                    else -> false
                }
            },
            locationEnabled = locationGranted,
            recenterTrigger = recenterTick,
            contacts = if (contactsVisible) contacts.values else emptyList(),
            measurementPoints = measurementPoints,
            drawings = if (drawingsVisible) {
                drawings + buildInProgressDrawing(drawingKind, drawingPoints)
            } else {
                emptyList()
            },
            gridCenter = if (gridEnabled) LatLng(37.42, -122.08) else null,
            aircraft = if (aircraftVisible) aircraft else emptyList(),
            panTarget = panTarget,
            panTargetTick = panTargetTick,
            followMeActive = followMeActive,
        )

        Column(
            modifier = Modifier
                .fillMaxSize()
                .align(Alignment.TopCenter),
        ) {
            ATAKStatusBar(
                serverName = headerLabel,
                isConnected = connState is ConnectionState.Connected,
                messagesReceived = 0,
                messagesSent = 0,
                gpsAccuracyMeters = null,
                timeLabel = nowLabel,
                onServerTap = { /* Slice 6: open server picker */ },
                onMenuTap = { /* Slice 6: open tools drawer */ },
            )
        }

        ToolsDrawer(
            tools = listOf(
                ToolEntry("draw", Icons.Filled.Brush, "Drawing"),
                ToolEntry("measure", Icons.Filled.Straighten, "Measure"),
                ToolEntry("layers", Icons.Filled.Layers, "Layers"),
                ToolEntry("adsb", Icons.Filled.Flight, if (adsbActive) "ADSB on" else "ADSB"),
                ToolEntry("chat", Icons.Filled.Chat, "Chat"),
                ToolEntry("teams", Icons.Filled.Groups, "Teams"),
                ToolEntry(
                    "nav",
                    Icons.Filled.Navigation,
                    if (followMeActive) "Follow on" else "Follow",
                ),
            ),
            onSelect = { tool ->
                when (tool.id) {
                    "measure" -> {
                        measurementActive = true
                        measurementPoints = emptyList()
                        toast("Measure mode — tap map to add points")
                    }
                    "draw" -> drawingPickerOpen = true
                    "layers" -> layersSheetOpen = true
                    "adsb" -> {
                        if (adsbActive) {
                            adsbService.stop()
                            toast("ADSB off")
                        } else {
                            // Bay Area box until we plumb the live camera
                            // center through — matches the emulator's
                            // default Mountain View GPS so aircraft stay
                            // on-screen during dev.
                            adsbService.start(
                                centerLat = 37.42,
                                centerLon = -122.08,
                                halfWidthDegrees = 2.5,
                            )
                            toast("ADSB on — polling OpenSky every 15s")
                        }
                    }
                    "chat" -> onOpenTab("chat")
                    "teams" -> teamsPanelOpen = true
                    "nav" -> {
                        if (!locationGranted) {
                            toast("Follow-me needs location permission")
                        } else {
                            followMeActive = !followMeActive
                            toast(if (followMeActive) "Follow me ON" else "Follow me OFF")
                        }
                    }
                }
            },
            modifier = Modifier.align(Alignment.BottomEnd),
        )

        // Center-on-me FAB — tracks the location component's last fix
        // and recenters the camera. Separate from the tools drawer so
        // it stays reachable without opening the drawer.
        androidx.compose.foundation.layout.Box(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .padding(16.dp)
                .size(48.dp)
                .clip(CircleShape)
                .background(TacticalBackground.copy(alpha = 0.9f))
                .clickable(enabled = locationGranted) { recenterTick++ },
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Filled.MyLocation,
                contentDescription = "Center on me",
                tint = if (locationGranted) TacticalAccent else androidx.compose.ui.graphics.Color.Gray,
            )
        }

        RadialMenu(
            visible = radialAnchor != null,
            anchor = radialAnchor ?: Offset.Zero,
            actions = listOf(
                RadialAction("drop", Icons.Filled.Place, "Drop Marker"),
                RadialAction("measure", Icons.Filled.Straighten, "Measure"),
                RadialAction("nav", Icons.Filled.Navigation, "Navigate"),
                RadialAction("copy", Icons.Filled.LocationOn, "Copy Coords"),
                RadialAction("center", Icons.Filled.Explore, "Center"),
                RadialAction("add", Icons.Filled.Add, "Add"),
            ),
            onSelect = { action ->
                val ll = radialLatLng
                radialAnchor = null
                radialLatLng = null
                when (action.id) {
                    "drop" -> if (ll != null) markerSheetLatLng = ll
                    else -> {
                        val coord = ll?.let { "%.5f, %.5f".format(it.latitude, it.longitude) } ?: ""
                        toast("${action.label}${if (coord.isNotEmpty()) " @ $coord" else ""}")
                    }
                }
            },
            onDismiss = {
                radialAnchor = null
                radialLatLng = null
            },
        )

        MarkerEditSheet(
            visible = markerSheetLatLng != null,
            latLng = markerSheetLatLng,
            initialCallsign = editingMarker?.callsign ?: "Marker ${contacts.size + 1}",
            initialAffiliation = editingMarker?.affiliation ?: CoTAffiliation.FRIEND,
            initialAltitude = editingMarker?.hae?.takeIf { it != 0.0 },
            initialRemarks = editingMarker?.remarks ?: "",
            editing = editingMarker != null,
            onSave = { result ->
                val ll = markerSheetLatLng
                if (ll != null) {
                    val uid = editingMarker?.uid ?: "local-${System.currentTimeMillis()}"
                    app.contactStore.ingest(
                        CoTEvent(
                            uid = uid,
                            type = "a-${result.affiliation.code}-G-U-C",
                            lat = ll.latitude,
                            lon = ll.longitude,
                            hae = result.altitudeMeters ?: 0.0,
                            callsign = result.callsign,
                            remarks = result.remarks,
                        )
                    )
                    val verb = if (editingMarker != null) "Updated" else "Saved"
                    toast("$verb ${result.affiliation.name.lowercase()} marker “${result.callsign}”")
                }
                markerSheetLatLng = null
                editingMarker = null
            },
            onDelete = editingMarker?.let {
                {
                    app.contactStore.remove(it.uid)
                    toast("Deleted marker “${it.callsign ?: it.uid}”")
                    markerSheetLatLng = null
                    editingMarker = null
                }
            },
            onDismiss = {
                markerSheetLatLng = null
                editingMarker = null
            },
        )

        if (drawingKind != null) {
            DrawingOverlay(
                kind = drawingKind!!,
                pointCount = drawingPoints.size,
                onUndo = {
                    if (drawingPoints.isNotEmpty()) {
                        drawingPoints = drawingPoints.dropLast(1)
                    }
                },
                onCancel = {
                    drawingKind = null
                    drawingPoints = emptyList()
                },
                onFinish = {
                    val minPts = when (drawingKind!!) {
                        DrawingKind.LINE -> 2
                        DrawingKind.POLYGON -> 3
                        DrawingKind.CIRCLE -> 2
                    }
                    if (drawingPoints.size >= minPts) {
                        app.drawingStore.add(
                            Drawing(
                                id = "draw-${System.currentTimeMillis()}",
                                kind = drawingKind!!,
                                points = drawingPoints.map { it.latitude to it.longitude },
                            )
                        )
                        toast("Saved ${drawingKind!!.name.lowercase()}")
                    } else {
                        toast("Need at least $minPts points")
                    }
                    drawingKind = null
                    drawingPoints = emptyList()
                },
                modifier = Modifier.align(Alignment.TopStart),
            )
        }

        if (drawingPickerOpen) {
            DrawingKindPicker(
                onPick = { kind ->
                    drawingPickerOpen = false
                    drawingKind = kind
                    drawingPoints = emptyList()
                    toast("Drawing ${kind.name.lowercase()} — tap to add points")
                },
                onDismiss = { drawingPickerOpen = false },
            )
        }

        if (measurementActive) {
            MeasurementOverlay(
                points = measurementPoints,
                onUndo = {
                    if (measurementPoints.isNotEmpty()) {
                        measurementPoints = measurementPoints.dropLast(1)
                    }
                },
                onClose = {
                    measurementActive = false
                    measurementPoints = emptyList()
                },
                modifier = Modifier.align(Alignment.TopStart),
            )
        }

        if (layersSheetOpen) {
            LayersDialog(
                gridEnabled = gridEnabled,
                drawingsVisible = drawingsVisible,
                aircraftVisible = aircraftVisible,
                contactsVisible = contactsVisible,
                onToggleGrid = { gridEnabled = it },
                onToggleDrawings = { drawingsVisible = it },
                onToggleAircraft = { aircraftVisible = it },
                onToggleContacts = { contactsVisible = it },
                onDismiss = { layersSheetOpen = false },
            )
        }

        if (teamsPanelOpen) {
            ContactsPanel(
                contacts = contacts.values.toList(),
                onSelect = { c ->
                    panTarget = LatLng(c.lat, c.lon)
                    panTargetTick += 1
                    if (followMeActive) followMeActive = false
                    teamsPanelOpen = false
                    toast("Panning to ${c.callsign ?: c.uid}")
                },
                onDismiss = { teamsPanelOpen = false },
            )
        }

        SnackbarHost(
            hostState = snackbar,
            modifier = Modifier.align(Alignment.BottomCenter),
        )
    }
}

private fun buildInProgressDrawing(kind: DrawingKind?, points: List<LatLng>): List<Drawing> {
    if (kind == null || points.isEmpty()) return emptyList()
    return listOf(
        Drawing(
            id = "__in_progress__",
            kind = kind,
            points = points.map { it.latitude to it.longitude },
            colorHex = "#FFC107",  // amber while drafting
        )
    )
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
private fun DrawingKindPicker(
    onPick: (DrawingKind) -> Unit,
    onDismiss: () -> Unit,
) {
    androidx.compose.material3.AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = soy.engindearing.omnitak.mobile.ui.theme.TacticalSurface,
        title = { androidx.compose.material3.Text("Drawing tool", color = MaterialTheme.colorScheme.onBackground) },
        text = {
            androidx.compose.foundation.layout.Column {
                listOf(
                    DrawingKind.LINE to "Line — connected segments",
                    DrawingKind.POLYGON to "Polygon — closed shape",
                    DrawingKind.CIRCLE to "Circle — center + edge",
                ).forEach { (kind, label) ->
                    androidx.compose.material3.TextButton(
                        onClick = { onPick(kind) },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        androidx.compose.material3.Text(
                            label,
                            color = TacticalAccent,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
            }
        },
        confirmButton = {
            androidx.compose.material3.TextButton(onClick = onDismiss) {
                androidx.compose.material3.Text("Cancel", color = TacticalAccent)
            }
        },
    )
}

@Composable
private fun DrawingOverlay(
    kind: DrawingKind,
    pointCount: Int,
    onUndo: () -> Unit,
    onCancel: () -> Unit,
    onFinish: () -> Unit,
    modifier: Modifier = Modifier,
) {
    androidx.compose.foundation.layout.Row(
        modifier = modifier
            .padding(top = 76.dp, start = 12.dp, end = 12.dp)
            .clip(androidx.compose.foundation.shape.RoundedCornerShape(8.dp))
            .background(TacticalBackground.copy(alpha = 0.9f))
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        androidx.compose.material3.Text(
            "${kind.name.lowercase().replaceFirstChar { it.uppercase() }} · $pointCount pt",
            color = TacticalAccent,
            fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
            style = MaterialTheme.typography.bodyMedium,
        )
        androidx.compose.foundation.layout.Spacer(Modifier.width(12.dp))
        androidx.compose.material3.TextButton(onClick = onUndo, enabled = pointCount > 0) {
            androidx.compose.material3.Text("Undo", color = TacticalAccent)
        }
        androidx.compose.material3.TextButton(onClick = onCancel) {
            androidx.compose.material3.Text("Cancel", color = TacticalAccent)
        }
        androidx.compose.material3.TextButton(onClick = onFinish) {
            androidx.compose.material3.Text("Save", color = TacticalAccent)
        }
    }
}

@Composable
private fun MeasurementOverlay(
    points: List<LatLng>,
    onUndo: () -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var totalMeters = 0.0
    for (i in 1 until points.size) {
        totalMeters += GeoMath.haversineMeters(
            points[i - 1].latitude, points[i - 1].longitude,
            points[i].latitude, points[i].longitude,
        )
    }
    val bearing = if (points.size >= 2) {
        val a = points[points.size - 2]
        val b = points[points.size - 1]
        GeoMath.bearingDegrees(a.latitude, a.longitude, b.latitude, b.longitude)
    } else null

    androidx.compose.foundation.layout.Row(
        modifier = modifier
            .padding(top = 76.dp, start = 12.dp, end = 12.dp)
            .clip(androidx.compose.foundation.shape.RoundedCornerShape(8.dp))
            .background(TacticalBackground.copy(alpha = 0.9f))
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        androidx.compose.material3.Text(
            buildString {
                append("${points.size} pt · ")
                append(GeoMath.formatDistance(totalMeters))
                if (bearing != null) append(" · ${GeoMath.formatBearing(bearing)}")
            },
            color = TacticalAccent,
            fontFamily = androidx.compose.ui.text.font.FontFamily.Monospace,
            style = MaterialTheme.typography.bodyMedium,
        )
        androidx.compose.foundation.layout.Spacer(Modifier.width(12.dp))
        androidx.compose.material3.TextButton(onClick = onUndo, enabled = points.isNotEmpty()) {
            androidx.compose.material3.Text("Undo", color = TacticalAccent)
        }
        androidx.compose.material3.TextButton(onClick = onClose) {
            androidx.compose.material3.Text("Done", color = TacticalAccent)
        }
    }
}

private fun timeLabel(): String =
    SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
