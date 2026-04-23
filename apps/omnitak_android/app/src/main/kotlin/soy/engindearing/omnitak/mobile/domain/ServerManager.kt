package soy.engindearing.omnitak.mobile.domain

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import soy.engindearing.omnitak.mobile.data.ChatXml
import soy.engindearing.omnitak.mobile.data.CoTParser
import soy.engindearing.omnitak.mobile.data.TAKConnection
import soy.engindearing.omnitak.mobile.data.TAKServer
import soy.engindearing.omnitak.mobile.data.TAKServerStore

/**
 * Application-scoped TAK server registry. Exposes [servers] and
 * [activeServer] as StateFlows so Compose screens can observe reactively.
 *
 * Mirrors iOS ServerManager behavior:
 *  - addServer is idempotent on host + port + protocol (iOS #42)
 *  - toggling/disabling the active server hands off to the next enabled
 *    server so the UI doesn't keep pointing at a disabled one (iOS #41)
 *  - newly added enabled server becomes active when no enabled active exists
 */
class ServerManager(
    private val store: TAKServerStore,
    private val contactStore: ContactStore? = null,
    private val chatStore: ChatStore? = null,
) {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    private val _servers = MutableStateFlow<List<TAKServer>>(emptyList())
    val servers: StateFlow<List<TAKServer>> = _servers.asStateFlow()

    private val _activeServer = MutableStateFlow<TAKServer?>(null)
    val activeServer: StateFlow<TAKServer?> = _activeServer.asStateFlow()

    private val _connectionState = MutableStateFlow<ConnectionState>(ConnectionState.Disconnected)
    val connectionState: StateFlow<ConnectionState> = _connectionState.asStateFlow()

    private var currentConnection: TAKConnection? = null
    private var connectionCollectorJob: kotlinx.coroutines.Job? = null
    private var receivedCollectorJob: kotlinx.coroutines.Job? = null

    init { scope.launch { hydrate() } }

    /** Tear down any existing connection and open a new one to [server]. */
    fun connect(server: TAKServer) {
        disconnect()
        val conn = TAKConnection(server)
        currentConnection = conn
        connectionCollectorJob = scope.launch {
            conn.state.collect { _connectionState.value = it }
        }
        receivedCollectorJob = scope.launch {
            conn.received.collect { xml ->
                // A frame is either a chat event or a contact/marker event,
                // depending on the CoT type. Parsing chat first is cheap
                // (string probe) and avoids double-ingesting as a contact.
                val chat = ChatXml.parse(xml)
                if (chat != null) {
                    chatStore?.ingest(chat)
                } else {
                    CoTParser.parse(xml)?.let { contactStore?.ingest(it) }
                }
            }
        }
        conn.connect()
    }

    /** Send a CoT XML payload on the active connection. */
    fun sendCoT(xml: String): Boolean = currentConnection?.send(xml) ?: false

    /** Disconnect the current connection if any. */
    fun disconnect() {
        currentConnection?.disconnect()
        currentConnection = null
        connectionCollectorJob?.cancel()
        connectionCollectorJob = null
        receivedCollectorJob?.cancel()
        receivedCollectorJob = null
        _connectionState.value = ConnectionState.Disconnected
    }

    private suspend fun hydrate() {
        var initial: List<TAKServer> = emptyList()
        store.servers.collect { loaded ->
            _servers.value = loaded
            if (initial.isEmpty() && loaded.isNotEmpty()) {
                initial = loaded
                val activeId = peekActiveId()
                _activeServer.value = loaded.firstOrNull { it.id == activeId }
                    ?: loaded.firstOrNull { it.enabled }
                    ?: loaded.firstOrNull()
            }
        }
    }

    private suspend fun peekActiveId(): String? {
        var out: String? = null
        store.activeServerId.collect { out = it; return@collect }
        return out
    }

    fun addServer(server: TAKServer): TAKServer {
        val existing = _servers.value.firstOrNull { it.matchesEndpoint(server) }
        if (existing != null) return existing

        val updated = _servers.value + server
        _servers.value = updated
        if (server.enabled && (_activeServer.value == null || _activeServer.value?.enabled != true)) {
            _activeServer.value = server
            persistActive(server.id)
        }
        persist(updated)
        return server
    }

    fun updateServer(server: TAKServer) {
        val idx = _servers.value.indexOfFirst { it.id == server.id }
        if (idx < 0) return
        val updated = _servers.value.toMutableList().apply { this[idx] = server }
        _servers.value = updated
        if (_activeServer.value?.id == server.id) _activeServer.value = server
        persist(updated)
    }

    fun deleteServer(id: String) {
        val updated = _servers.value.filterNot { it.id == id }
        _servers.value = updated
        if (_activeServer.value?.id == id) {
            val next = updated.firstOrNull { it.enabled }
            _activeServer.value = next
            persistActive(next?.id)
        }
        persist(updated)
    }

    fun toggleEnabled(id: String) {
        val updated = _servers.value.map {
            if (it.id == id) it.copy(enabled = !it.enabled) else it
        }
        _servers.value = updated

        val toggled = updated.firstOrNull { it.id == id }
        if (_activeServer.value?.id == id) {
            if (toggled?.enabled == true) {
                _activeServer.value = toggled
            } else {
                val next = updated.firstOrNull { it.enabled }
                _activeServer.value = next
                persistActive(next?.id)
            }
        }
        persist(updated)
    }

    fun setActive(id: String) {
        val target = _servers.value.firstOrNull { it.id == id } ?: return
        _activeServer.value = target
        persistActive(target.id)
    }

    private fun persist(list: List<TAKServer>) {
        scope.launch { store.saveServers(list) }
    }

    private fun persistActive(id: String?) {
        scope.launch { store.saveActiveServerId(id) }
    }
}
