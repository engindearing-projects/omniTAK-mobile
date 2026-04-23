package soy.engindearing.omnitak.mobile.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.delay
import soy.engindearing.omnitak.mobile.OmniTAKApp
import soy.engindearing.omnitak.mobile.ui.components.ATAKStatusBar
import soy.engindearing.omnitak.mobile.ui.components.TacticalMap
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun MapScreen() {
    val app = LocalContext.current.applicationContext as OmniTAKApp
    val active by app.serverManager.activeServer.collectAsState()

    var nowLabel by remember { mutableStateOf(timeLabel()) }
    LaunchedEffect(Unit) {
        while (true) {
            nowLabel = timeLabel()
            delay(15_000L)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
    ) {
        TacticalMap(modifier = Modifier.fillMaxSize())

        Column(
            modifier = Modifier
                .fillMaxSize()
                .align(Alignment.TopCenter),
        ) {
            ATAKStatusBar(
                serverName = active?.name ?: "Offline",
                isConnected = false,  // wired up in Slice 4 when JNI lands
                messagesReceived = 0,
                messagesSent = 0,
                gpsAccuracyMeters = null,
                timeLabel = nowLabel,
                onServerTap = { /* Slice 6: open server picker */ },
                onMenuTap = { /* Slice 6: open tools drawer */ },
            )
        }
    }
}

private fun timeLabel(): String =
    SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
