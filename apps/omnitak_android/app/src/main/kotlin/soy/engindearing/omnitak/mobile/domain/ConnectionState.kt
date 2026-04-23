package soy.engindearing.omnitak.mobile.domain

/**
 * Overall state of the TAK connection attached to the active server.
 * Mirrors the iOS ConnectionStateSnapshot sealed cases.
 */
sealed interface ConnectionState {
    data object Disconnected : ConnectionState
    data class Connecting(val serverName: String) : ConnectionState
    data class Connected(val serverName: String, val useTLS: Boolean) : ConnectionState
    data class Failed(val reason: String) : ConnectionState
}
