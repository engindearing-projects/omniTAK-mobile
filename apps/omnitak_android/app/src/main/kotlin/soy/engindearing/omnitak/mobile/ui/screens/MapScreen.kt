package soy.engindearing.omnitak.mobile.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import soy.engindearing.omnitak.mobile.ui.theme.TacticalAccent
import soy.engindearing.omnitak.mobile.ui.theme.TacticalSurface

@Composable
fun MapScreen() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                "OmniTAK",
                style = MaterialTheme.typography.displaySmall,
                color = TacticalAccent,
                fontWeight = FontWeight.Bold,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                "Tactical map coming online in the next slice.",
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.7f),
            )
            Spacer(Modifier.height(24.dp))
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .background(TacticalSurface)
                    .padding(horizontal = 16.dp, vertical = 12.dp),
            ) {
                Text(
                    "v0.1.0 — scaffold",
                    style = MaterialTheme.typography.labelMedium,
                    color = TacticalAccent,
                )
            }
        }
    }
}
