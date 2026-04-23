package soy.engindearing.omnitak.mobile.data

import kotlinx.serialization.Serializable
import java.util.UUID

enum class ConnectionProtocol(val wire: String) {
    TCP("tcp"),
    UDP("udp"),
    TLS("tls"),
    WebSocket("ws");

    companion object {
        fun fromWire(s: String): ConnectionProtocol =
            entries.firstOrNull { it.wire.equals(s, ignoreCase = true) } ?: TCP
    }
}

@Serializable
data class TAKServer(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val host: String,
    val port: Int,
    val protocol: String = ConnectionProtocol.TCP.wire,
    val useTLS: Boolean = false,
    val enabled: Boolean = true,
    val isDefault: Boolean = false,
    val certificateName: String? = null,
    val caCertificateName: String? = null,
    val username: String? = null,
) {
    val displayName: String get() = "$name ($host:$port)"

    val protocolEnum: ConnectionProtocol get() = ConnectionProtocol.fromWire(protocol)

    /**
     * Two servers point at the same TAK endpoint when host + port + protocol
     * match (host compared case-insensitively). Credentials and display name
     * are deliberately excluded so re-importing the same server with updated
     * certs is still considered a duplicate — mirrors iOS #42 rule.
     */
    fun matchesEndpoint(other: TAKServer): Boolean =
        host.equals(other.host, ignoreCase = true) &&
                port == other.port &&
                protocol.equals(other.protocol, ignoreCase = true)
}
