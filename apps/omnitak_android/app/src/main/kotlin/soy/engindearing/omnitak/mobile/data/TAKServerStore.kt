package soy.engindearing.omnitak.mobile.data

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

private val Context.serverDataStore by preferencesDataStore(name = "tak_servers")

/**
 * Persists the TAK server list as a single JSON blob in a Preferences
 * DataStore. Mirrors the iOS UserDefaults+JSONEncoder scheme so both apps
 * stay read-compatible if we later share the format.
 */
class TAKServerStore(private val context: Context) {
    private val serversKey = stringPreferencesKey("servers_json")
    private val activeKey = stringPreferencesKey("active_server_id")

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    val servers: Flow<List<TAKServer>> = context.serverDataStore.data.map { prefs ->
        val raw = prefs[serversKey] ?: return@map emptyList()
        runCatching { json.decodeFromString<List<TAKServer>>(raw) }.getOrElse { emptyList() }
    }

    val activeServerId: Flow<String?> = context.serverDataStore.data.map { it[activeKey] }

    suspend fun saveServers(list: List<TAKServer>) {
        val raw = json.encodeToString(list)
        context.serverDataStore.edit { it[serversKey] = raw }
    }

    suspend fun saveActiveServerId(id: String?) {
        context.serverDataStore.edit { prefs ->
            if (id == null) prefs.remove(activeKey) else prefs[activeKey] = id
        }
    }
}
