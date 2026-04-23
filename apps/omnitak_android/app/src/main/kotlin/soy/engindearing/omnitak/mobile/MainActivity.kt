package soy.engindearing.omnitak.mobile

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.toArgb
import soy.engindearing.omnitak.mobile.ui.navigation.AppNav
import soy.engindearing.omnitak.mobile.ui.theme.OmniTAKTheme
import soy.engindearing.omnitak.mobile.ui.theme.TacticalBackground

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(TacticalBackground.toArgb()),
            navigationBarStyle = SystemBarStyle.dark(TacticalBackground.toArgb()),
        )
        setContent {
            OmniTAKTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background,
                ) {
                    AppNav()
                }
            }
        }
    }
}
