package soy.engindearing.omnitak.mobile.data

import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import soy.engindearing.omnitak.mobile.domain.ConnectionState
import java.net.InetSocketAddress
import java.net.Socket
import kotlin.coroutines.coroutineContext

/**
 * TCP transport for a Meshtastic-over-WiFi radio. Meshtastic devices
 * expose a framed protobuf stream on port 4403 — the first two bytes
 * of each frame are the magic `0x94 0xC3`, followed by a 16-bit big
 * endian payload length, followed by the FromRadio protobuf payload.
 *
 * This slice wires up the transport (connect / read loop / disconnect)
 * and emits the raw payload slices on [frames] — protobuf decode
 * comes in the follow-up once the meshtastic `.proto` set is wired
 * into the Gradle build.
 */
class MeshtasticTcpClient {

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var connectJob: Job? = null
    private var socket: Socket? = null

    private val _state = MutableStateFlow<ConnectionState>(ConnectionState.Disconnected)
    val state: StateFlow<ConnectionState> = _state.asStateFlow()

    private val _frames = MutableSharedFlow<ByteArray>(extraBufferCapacity = 64)
    val frames: SharedFlow<ByteArray> = _frames.asSharedFlow()

    private val _bytesReceived = MutableStateFlow(0L)
    val bytesReceived: StateFlow<Long> = _bytesReceived.asStateFlow()

    fun connect(host: String, port: Int = 4403) {
        if (connectJob?.isActive == true) return
        _state.value = ConnectionState.Connecting("$host:$port")
        connectJob = scope.launch {
            try {
                val sock = withContext(Dispatchers.IO) {
                    val s = Socket()
                    s.tcpNoDelay = true
                    s.connect(InetSocketAddress(host, port), CONNECT_TIMEOUT_MS)
                    s
                }
                socket = sock
                _state.value = ConnectionState.Connected("$host:$port", useTLS = false)
                Log.i(TAG, "Connected to $host:$port")
                readLoop(sock)
            } catch (t: Throwable) {
                Log.w(TAG, "Connect failed: ${t.javaClass.simpleName}: ${t.message}")
                _state.value = ConnectionState.Failed(t.message ?: t.javaClass.simpleName)
                cleanup()
            }
        }
    }

    fun disconnect() {
        connectJob?.cancel()
        cleanup()
        _state.value = ConnectionState.Disconnected
    }

    /**
     * Encodes + writes a ToRadio protobuf payload. Caller is responsible
     * for the protobuf serialization; we only prepend the Meshtastic
     * framing (0x94 0xC3 + BE16 length).
     */
    fun sendFrame(payload: ByteArray): Boolean {
        val sock = socket ?: return false
        if (_state.value !is ConnectionState.Connected) return false
        return runCatching {
            val header = byteArrayOf(
                MAGIC_BYTE_1.toByte(),
                MAGIC_BYTE_2.toByte(),
                ((payload.size shr 8) and 0xFF).toByte(),
                (payload.size and 0xFF).toByte(),
            )
            val out = sock.getOutputStream()
            out.write(header)
            out.write(payload)
            out.flush()
            true
        }.onFailure { Log.w(TAG, "sendFrame failed: ${it.message}") }.getOrDefault(false)
    }

    private suspend fun readLoop(sock: Socket) {
        val input = sock.getInputStream()
        val buffer = ByteArray(4096)
        try {
            while (coroutineContext.isActive) {
                // Seek magic bytes.
                val m1 = input.read()
                if (m1 == -1) break
                if (m1 != MAGIC_BYTE_1) continue
                val m2 = input.read()
                if (m2 == -1) break
                if (m2 != MAGIC_BYTE_2) continue

                val hi = input.read()
                val lo = input.read()
                if (hi == -1 || lo == -1) break
                val length = (hi shl 8) or lo
                if (length <= 0 || length > MAX_FRAME_BYTES) {
                    Log.w(TAG, "bad frame length=$length — resyncing")
                    continue
                }

                var read = 0
                val frame = ByteArray(length)
                while (read < length) {
                    val n = input.read(frame, read, length - read)
                    if (n == -1) throw java.io.EOFException("short frame")
                    read += n
                }
                _bytesReceived.value += (4 + length).toLong()
                _frames.tryEmit(frame)
            }
        } catch (t: Throwable) {
            Log.w(TAG, "read loop ended: ${t.javaClass.simpleName}: ${t.message}")
        }
        if (_state.value is ConnectionState.Connected) _state.value = ConnectionState.Disconnected
        cleanup()
    }

    private fun cleanup() {
        runCatching { socket?.close() }
        socket = null
    }

    companion object {
        private const val TAG = "MeshTcp"
        private const val CONNECT_TIMEOUT_MS = 10_000
        private const val MAGIC_BYTE_1 = 0x94
        private const val MAGIC_BYTE_2 = 0xC3
        private const val MAX_FRAME_BYTES = 4 * 1024 * 1024  // 4 MiB sanity cap
    }
}
