package soy.engindearing.omnitak.mobile.domain

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
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
class ServerManager(private val store: TAKServerStore) {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    private val _servers = MutableStateFlow<List<TAKServer>>(emptyList())
    val servers: StateFlow<List<TAKServer>> = _servers.asStateFlow()

    private val _activeServer = MutableStateFlow<TAKServer?>(null)
    val activeServer: StateFlow<TAKServer?> = _activeServer.asStateFlow()

    init { scope.launch { hydrate() } }

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
