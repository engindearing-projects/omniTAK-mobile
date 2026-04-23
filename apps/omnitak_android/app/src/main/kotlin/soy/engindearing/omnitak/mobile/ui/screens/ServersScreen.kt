package soy.engindearing.omnitak.mobile.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import soy.engindearing.omnitak.mobile.OmniTAKApp
import soy.engindearing.omnitak.mobile.data.TAKServer
import soy.engindearing.omnitak.mobile.domain.ConnectionState
import soy.engindearing.omnitak.mobile.ui.theme.HostileRed
import soy.engindearing.omnitak.mobile.ui.theme.NeutralYellow
import soy.engindearing.omnitak.mobile.ui.theme.TacticalAccent
import soy.engindearing.omnitak.mobile.ui.theme.TacticalBackground
import soy.engindearing.omnitak.mobile.ui.theme.TacticalSurface

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ServersScreen(onAdd: () -> Unit) {
    val app = LocalContext.current.applicationContext as OmniTAKApp
    val manager = app.serverManager
    val servers by manager.servers.collectAsState()
    val active by manager.activeServer.collectAsState()
    val connState by manager.connectionState.collectAsState()

    Scaffold(
        containerColor = TacticalBackground,
        topBar = {
            TopAppBar(
                title = {
                    Text("TAK Servers", color = MaterialTheme.colorScheme.onBackground)
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = TacticalBackground,
                    titleContentColor = MaterialTheme.colorScheme.onBackground,
                ),
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = onAdd,
                containerColor = TacticalAccent,
                contentColor = TacticalBackground,
            ) {
                Icon(Icons.Filled.Add, contentDescription = "Add server")
            }
        },
    ) { inner: PaddingValues ->
        if (servers.isEmpty()) {
            EmptyServers(Modifier.padding(inner))
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(inner),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                items(items = servers, key = { it.id }) { server ->
                    val connectedToThis = active?.id == server.id && (
                        connState is ConnectionState.Connected || connState is ConnectionState.Connecting
                    )
                    ServerCard(
                        server = server,
                        isActive = active?.id == server.id,
                        connState = if (active?.id == server.id) connState else ConnectionState.Disconnected,
                        onTap = { manager.setActive(server.id) },
                        onToggle = { manager.toggleEnabled(server.id) },
                        onDelete = { manager.deleteServer(server.id) },
                        onConnectToggle = {
                            if (connectedToThis) manager.disconnect() else {
                                manager.setActive(server.id)
                                manager.connect(server)
                            }
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun EmptyServers(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            Icons.Filled.Storage,
            contentDescription = null,
            modifier = Modifier.size(48.dp),
            tint = TacticalAccent.copy(alpha = 0.6f),
        )
        Spacer(Modifier.height(16.dp))
        Text(
            "No TAK servers configured",
            style = MaterialTheme.typography.titleLarge,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            "Tap the + button to add your first server.",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.7f),
        )
    }
}

@Composable
private fun ServerCard(
    server: TAKServer,
    isActive: Boolean,
    connState: ConnectionState,
    onTap: () -> Unit,
    onToggle: () -> Unit,
    onDelete: () -> Unit,
    onConnectToggle: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(TacticalSurface)
            .clickable(onClick = onTap)
            .padding(start = 0.dp, end = 12.dp, top = 12.dp, bottom = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        // Left accent stripe — bright when active, dim otherwise
        Box(
            modifier = Modifier
                .width(4.dp)
                .height(56.dp)
                .background(if (isActive) TacticalAccent else Color.Transparent),
        )
        Spacer(Modifier.width(12.dp))

        // Connection dot — reflects live connection state when this card is active
        Box(
            modifier = Modifier
                .size(10.dp)
                .clip(CircleShape)
                .background(
                    when {
                        !server.enabled -> Color.Gray.copy(alpha = 0.5f)
                        connState is ConnectionState.Connected -> TacticalAccent
                        connState is ConnectionState.Connecting -> NeutralYellow
                        connState is ConnectionState.Failed -> HostileRed
                        isActive -> TacticalAccent.copy(alpha = 0.5f)
                        else -> Color.Gray
                    }
                ),
        )
        Spacer(Modifier.width(12.dp))

        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    server.name,
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onBackground,
                    fontWeight = FontWeight.SemiBold,
                )
                if (server.useTLS) {
                    Spacer(Modifier.width(6.dp))
                    Icon(
                        Icons.Filled.Lock,
                        contentDescription = "TLS",
                        modifier = Modifier.size(12.dp),
                        tint = TacticalAccent,
                    )
                }
            }
            Text(
                "${server.host}:${server.port}  ·  ${server.protocol.uppercase()}",
                style = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace),
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.65f),
            )
        }

        val isLive = connState is ConnectionState.Connected || connState is ConnectionState.Connecting
        IconButton(
            onClick = onConnectToggle,
            enabled = server.enabled,
        ) {
            Icon(
                if (isLive) Icons.Filled.Stop else Icons.Filled.PlayArrow,
                contentDescription = if (isLive) "Disconnect" else "Connect",
                tint = if (isLive) HostileRed else TacticalAccent,
            )
        }

        Switch(
            checked = server.enabled,
            onCheckedChange = { onToggle() },
            colors = SwitchDefaults.colors(
                checkedThumbColor = TacticalBackground,
                checkedTrackColor = TacticalAccent,
            ),
        )

        IconButton(onClick = onDelete) {
            Icon(
                Icons.Filled.Delete,
                contentDescription = "Delete ${server.name}",
                tint = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
            )
        }
    }
}
