package soy.engindearing.omnitak.mobile.ui.components

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import androidx.compose.ui.platform.LocalContext

/**
 * Observes runtime location-permission state and emits true once the
 * user has granted either fine or coarse location. Requests the pair
 * at first composition if neither is granted. The result is a single
 * [State]<Boolean> the caller can use to gate map features.
 *
 * The permission launcher survives configuration changes via
 * [rememberLauncherForActivityResult]; the granted flag flips true on
 * the first successful callback and never flips back (Android only
 * revokes permissions outside the process).
 */
@Composable
fun rememberLocationPermission(): State<Boolean> {
    val context = LocalContext.current
    val grantedState = remember { mutableStateOf(hasLocationPermission(context)) }

    val launcher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { result ->
        val granted = result[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
            result[Manifest.permission.ACCESS_COARSE_LOCATION] == true
        if (granted) grantedState.value = true
    }

    LaunchedEffect(Unit) {
        if (!grantedState.value) {
            launcher.launch(
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                )
            )
        }
    }

    return grantedState
}

private fun hasLocationPermission(context: android.content.Context): Boolean {
    val fine = ContextCompat.checkSelfPermission(
        context, Manifest.permission.ACCESS_FINE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED
    val coarse = ContextCompat.checkSelfPermission(
        context, Manifest.permission.ACCESS_COARSE_LOCATION
    ) == PackageManager.PERMISSION_GRANTED
    return fine || coarse
}
