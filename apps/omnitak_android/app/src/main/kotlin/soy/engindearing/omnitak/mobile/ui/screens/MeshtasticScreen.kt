package soy.engindearing.omnitak.mobile.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import soy.engindearing.omnitak.mobile.OmniTAKApp
import soy.engindearing.omnitak.mobile.data.MeshNode
import soy.engindearing.omnitak.mobile.domain.ConnectionState
import soy.engindearing.omnitak.mobile.ui.theme.TacticalAccent
import soy.engindearing.omnitak.mobile.ui.theme.TacticalBackground
import soy.engindearing.omnitak.mobile.ui.theme.TacticalSurface

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MeshtasticScreen() {
    val app = LocalContext.current.applicationContext as OmniTAKApp
    val mesh = app.meshtastic
    val connectionState by mesh.state.collectAsState()
    val bytes by mesh.bytesReceived.collectAsState()
    val nodes by mesh.nodes.collectAsState()

    var host by remember { mutableStateOf("192.168.1.100") }
    var port by remember { mutableStateOf("4403") }

    val stateLabel = when (val s = connectionState) {
        ConnectionState.Disconnected -> "Disconnected"
        is ConnectionState.Connecting -> "Connecting to ${s.serverName}…"
        is ConnectionState.Connected -> "Connected to ${s.serverName}"
        is ConnectionState.Failed -> "Failed: ${s.reason}"
    }
    val connected = connectionState is ConnectionState.Connected

    Scaffold(
        containerColor = TacticalBackground,
        topBar = {
            TopAppBar(
                title = { Text("Meshtastic", color = MaterialTheme.colorScheme.onBackground) },
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
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            SectionHeader("TCP gateway")
            Text(
                "Point this at a Meshtastic device running the WiFi/TCP proxy (default port 4403). Protobuf decode lands in a follow-up slice; this slice wires up the framed transport and keeps raw frame counts.",
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
                style = MaterialTheme.typography.bodySmall,
            )
            OutlinedTextField(
                value = host,
                onValueChange = { host = it },
                label = { Text("Host / IP") },
                singleLine = true,
                enabled = !connected,
                colors = meshFieldColors(),
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = port,
                onValueChange = { port = it.filter { c -> c.isDigit() }.take(5) },
                label = { Text("Port") },
                singleLine = true,
                enabled = !connected,
                colors = meshFieldColors(),
                modifier = Modifier.fillMaxWidth(),
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                if (!connected) {
                    Button(
                        onClick = {
                            val p = port.toIntOrNull() ?: 4403
                            mesh.connectTcp(host.trim(), p)
                        },
                        enabled = host.isNotBlank(),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = TacticalAccent,
                            contentColor = androidx.compose.ui.graphics.Color.Black,
                        ),
                        modifier = Modifier.weight(1f),
                    ) { Text("Connect") }
                } else {
                    OutlinedButton(
                        onClick = { mesh.disconnect() },
                        modifier = Modifier.weight(1f),
                    ) { Text("Disconnect") }
                }
            }

            HorizontalDivider(color = TacticalSurface)

            SectionHeader("Link")
            KeyValueRow(label = "State", value = stateLabel)
            KeyValueRow(label = "Bytes RX", value = "$bytes")
            KeyValueRow(label = "Nodes", value = "${nodes.size}")

            HorizontalDivider(color = TacticalSurface)

            SectionHeader("Nodes")
            if (nodes.isEmpty()) {
                Text(
                    "No nodes yet. Once protobuf decode ships, NodeInfo frames will populate this list automatically.",
                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
                    style = MaterialTheme.typography.bodySmall,
                )
            } else {
                NodeList(nodes.values.sortedByDescending { it.lastHeardEpoch })
            }
            Spacer(Modifier.height(16.dp))
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
        modifier = Modifier.padding(top = 4.dp, bottom = 2.dp),
    )
}

@Composable
private fun KeyValueRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            label,
            modifier = Modifier.weight(1f),
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.7f),
            style = MaterialTheme.typography.bodyMedium,
        )
        Text(
            value,
            color = MaterialTheme.colorScheme.onBackground,
            fontFamily = FontFamily.Monospace,
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}

@Composable
private fun NodeList(nodes: List<MeshNode>) {
    LazyColumn(
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        items(nodes, key = { it.id }) { n -> NodeRow(n) }
    }
}

@Composable
private fun NodeRow(node: MeshNode) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(6.dp))
            .background(TacticalSurface)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                node.longName.ifBlank { node.shortName.ifBlank { node.idHex } },
                color = MaterialTheme.colorScheme.onBackground,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                "id ${node.idHex}" +
                    (node.snr?.let { " · SNR ${"%.1f".format(it)}" } ?: "") +
                    (node.hopDistance?.let { " · hop $it" } ?: ""),
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
                style = MaterialTheme.typography.labelSmall,
                fontFamily = FontFamily.Monospace,
            )
        }
        node.batteryLevel?.let { Text("$it%", color = TacticalAccent) }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun meshFieldColors() = TextFieldDefaults.colors(
    focusedTextColor = MaterialTheme.colorScheme.onBackground,
    unfocusedTextColor = MaterialTheme.colorScheme.onBackground,
    disabledTextColor = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f),
    focusedContainerColor = TacticalSurface,
    unfocusedContainerColor = TacticalSurface,
    disabledContainerColor = TacticalSurface,
    focusedIndicatorColor = TacticalAccent,
    unfocusedIndicatorColor = TacticalAccent.copy(alpha = 0.4f),
    focusedLabelColor = TacticalAccent,
    unfocusedLabelColor = TacticalAccent.copy(alpha = 0.6f),
    cursorColor = TacticalAccent,
)
