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
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Layers
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Navigation
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Straighten
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
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
import soy.engindearing.omnitak.mobile.domain.ConnectionState
import soy.engindearing.omnitak.mobile.ui.components.ATAKStatusBar
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
fun MapScreen() {
    val app = LocalContext.current.applicationContext as OmniTAKApp
    val active by app.serverManager.activeServer.collectAsState()
    val connState by app.serverManager.connectionState.collectAsState()

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
    var recenterTick by remember { mutableStateOf(0) }
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
                radialLatLng = latLng
                radialAnchor = offset
            },
            locationEnabled = locationGranted,
            recenterTrigger = recenterTick,
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
                ToolEntry("chat", Icons.Filled.Chat, "Chat"),
                ToolEntry("teams", Icons.Filled.Groups, "Teams"),
                ToolEntry("nav", Icons.Filled.Navigation, "Navigate"),
            ),
            onSelect = { tool -> toast("${tool.label} — coming soon") },
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
                val coord = ll?.let { "%.5f, %.5f".format(it.latitude, it.longitude) } ?: ""
                toast("${action.label}${if (coord.isNotEmpty()) " @ $coord" else ""}")
            },
            onDismiss = {
                radialAnchor = null
                radialLatLng = null
            },
        )

        SnackbarHost(
            hostState = snackbar,
            modifier = Modifier.align(Alignment.BottomCenter),
        )
    }
}

private fun timeLabel(): String =
    SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
