package soy.engindearing.omnitak.mobile.ui.navigation

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Chat
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Router
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import soy.engindearing.omnitak.mobile.ui.screens.AboutScreen
import soy.engindearing.omnitak.mobile.ui.screens.AddServerScreen
import soy.engindearing.omnitak.mobile.ui.screens.ChatScreen
import soy.engindearing.omnitak.mobile.ui.screens.MapScreen
import soy.engindearing.omnitak.mobile.ui.screens.MeshtasticScreen
import soy.engindearing.omnitak.mobile.ui.screens.ServersScreen
import soy.engindearing.omnitak.mobile.ui.screens.SettingsScreen

private sealed class Dest(val route: String, val label: String, val icon: ImageVector) {
    data object Map : Dest("map", "Map", Icons.Filled.Map)
    data object Chat : Dest("chat", "Chat", Icons.AutoMirrored.Filled.Chat)
    data object Servers : Dest("servers", "Servers", Icons.Filled.Storage)
    data object Mesh : Dest("mesh", "Mesh", Icons.Filled.Router)
    data object Settings : Dest("settings", "Settings", Icons.Filled.Settings)
    data object About : Dest("about", "About", Icons.Filled.Info)
}

private val Destinations = listOf(
    Dest.Map, Dest.Chat, Dest.Servers, Dest.Mesh, Dest.Settings, Dest.About,
)

@Composable
fun AppNav() {
    val nav = rememberNavController()
    val backStack by nav.currentBackStackEntryAsState()
    val currentRoute = backStack?.destination?.route

    Scaffold(
        bottomBar = {
            NavigationBar {
                Destinations.forEach { d ->
                    NavigationBarItem(
                        selected = currentRoute?.hierarchyMatches(d.route) == true,
                        onClick = {
                            nav.navigate(d.route) {
                                popUpTo(nav.graph.startDestinationId) { saveState = true }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = { Icon(d.icon, contentDescription = d.label) },
                        label = { Text(d.label) },
                    )
                }
            }
        },
    ) { inner: PaddingValues ->
        NavHost(
            navController = nav,
            startDestination = Dest.Map.route,
            modifier = Modifier.padding(inner),
        ) {
            composable(Dest.Map.route) {
                MapScreen(
                    onOpenTab = { route ->
                        nav.navigate(route) {
                            popUpTo(nav.graph.startDestinationId) { saveState = true }
                            launchSingleTop = true
                            restoreState = true
                        }
                    },
                )
            }
            composable(Dest.Servers.route) {
                ServersScreen(onAdd = { nav.navigate("servers/add") })
            }
            composable("servers/add") {
                AddServerScreen(onDone = { nav.popBackStack() })
            }
            composable(Dest.Chat.route) { ChatScreen() }
            composable(Dest.Mesh.route) { MeshtasticScreen() }
            composable(Dest.Settings.route) { SettingsScreen() }
            composable(Dest.About.route) { AboutScreen() }
        }
    }
}

private fun String.hierarchyMatches(route: String): Boolean = this == route
