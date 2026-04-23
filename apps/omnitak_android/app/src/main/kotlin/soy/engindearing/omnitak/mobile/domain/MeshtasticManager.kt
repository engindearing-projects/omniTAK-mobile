package soy.engindearing.omnitak.mobile.domain

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import soy.engindearing.omnitak.mobile.data.MeshNode
import soy.engindearing.omnitak.mobile.data.MeshtasticTcpClient

/**
 * Application-scoped Meshtastic state holder. Owns the TCP client and
 * exposes node-table + connection state to screens via StateFlow.
 *
 * Node ingestion from protobuf frames is wired up as a TODO — the
 * [MeshtasticTcpClient.frames] sharedFlow collector is in place, and
 * once we add the proto set it slots in with a single parse call per
 * frame. Manual injection via [upsertNode] is available for tests and
 * CoT bridge validation in the interim.
 */
class MeshtasticManager {

    private val scope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    private val _nodes = MutableStateFlow<Map<Long, MeshNode>>(emptyMap())
    val nodes: StateFlow<Map<Long, MeshNode>> = _nodes.asStateFlow()

    val tcpClient = MeshtasticTcpClient()

    private var frameCollector: Job? = null

    val state get() = tcpClient.state
    val bytesReceived get() = tcpClient.bytesReceived

    fun connectTcp(host: String, port: Int = 4403) {
        frameCollector?.cancel()
        frameCollector = scope.launch {
            tcpClient.frames.collect { frame ->
                // TODO(protobuf): decode FromRadio here, extract NodeInfo
                // + Position + Telemetry messages, then call upsertNode.
                // For now we only track byte counts on the client's counter.
                android.util.Log.d("MeshtasticManager", "frame received: ${frame.size} bytes")
            }
        }
        tcpClient.connect(host, port)
    }

    fun disconnect() {
        tcpClient.disconnect()
        frameCollector?.cancel()
        frameCollector = null
    }

    fun upsertNode(node: MeshNode) {
        _nodes.value = _nodes.value + (node.id to node)
    }

    fun clearNodes() {
        _nodes.value = emptyMap()
    }
}
