package soy.engindearing.omnitak.mobile.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable

private val DarkTacticalScheme = darkColorScheme(
    primary = TacticalAccent,
    onPrimary = TacticalBackground,
    secondary = TacticalPrimary,
    onSecondary = TacticalOnSurface,
    background = TacticalBackground,
    onBackground = TacticalOnSurface,
    surface = TacticalSurface,
    onSurface = TacticalOnSurface,
    error = HostileRed,
)

@Composable
fun OmniTAKTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = DarkTacticalScheme,
        typography = TacticalTypography,
        content = content,
    )
}
