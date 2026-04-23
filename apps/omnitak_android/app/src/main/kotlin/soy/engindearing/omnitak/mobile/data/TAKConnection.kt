package soy.engindearing.omnitak.mobile.data

import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import soy.engindearing.omnitak.mobile.domain.ConnectionState
import java.io.BufferedReader
import java.net.InetSocketAddress
import java.net.Socket
import java.security.SecureRandom
import java.security.cert.X509Certificate
import javax.net.ssl.SSLContext
import javax.net.ssl.SSLSocket
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager
import kotlin.coroutines.coroutineContext

/**
 * One TAK server connection. Pure JVM networking — no JNI/Rust needed.
 *
 * Lifecycle:
 *   Disconnected → Connecting → Connected → (read loop) → Disconnected
 *                             ↳ Failed (timeout / socket error)
 *
 * Mirrors the iOS DirectTCPSender behavior shipped in the 2.11.0 batch:
 *   - 15s connect timeout so "Connecting…" never sticks forever (iOS #40)
 *   - Single-shot state transitions guarded by coroutine cancellation
 */
class TAKConnection(private val server: TAKServer) {

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var connectJob: Job? = null
    private var socket: Socket? = null

    private val _state = MutableStateFlow<ConnectionState>(ConnectionState.Disconnected)
    val state: StateFlow<ConnectionState> = _state.asStateFlow()

    // Raw CoT-XML stream from the server. Parsing into CoT events
    // arrives in a later slice; for now callers can log/inspect.
    private val _received = MutableSharedFlow<String>(extraBufferCapacity = 64)
    val received: SharedFlow<String> = _received.asSharedFlow()

    fun connect() {
        if (connectJob?.isActive == true) return
        _state.value = ConnectionState.Connecting(server.name)

        connectJob = scope.launch {
            try {
                val sock = withTimeout(CONNECT_TIMEOUT_MS) {
                    withContext(Dispatchers.IO) {
                        if (server.useTLS) openTlsSocket() else openPlainSocket()
                    }
                }
                socket = sock
                _state.value = ConnectionState.Connected(server.name, server.useTLS)
                Log.i(TAG, "Connected to ${server.host}:${server.port} (tls=${server.useTLS})")
                readLoop(sock)
            } catch (_: TimeoutCancellationException) {
                Log.w(TAG, "Connect timed out after ${CONNECT_TIMEOUT_MS / 1000}s")
                _state.value = ConnectionState.Failed("Connection timed out")
                cleanup()
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
     * Fire-and-forget CoT XML send. Returns false if no socket is open
     * or if the write fails. Runs on the IO dispatcher so callers can
     * invoke from any scope.
     */
    fun send(xml: String): Boolean {
        val sock = socket ?: return false
        if (_state.value !is ConnectionState.Connected) return false
        return try {
            val out = sock.getOutputStream()
            out.write(xml.toByteArray(Charsets.UTF_8))
            out.flush()
            true
        } catch (t: Throwable) {
            Log.w(TAG, "send failed: ${t.javaClass.simpleName}: ${t.message}")
            false
        }
    }

    private fun openPlainSocket(): Socket {
        val s = Socket()
        s.tcpNoDelay = true
        s.soTimeout = READ_TIMEOUT_MS
        s.connect(InetSocketAddress(server.host, server.port), CONNECT_TIMEOUT_MS.toInt())
        return s
    }

    /**
     * DEV-MODE TLS. TAK servers typically use self-signed certs or a
     * private CA, so strict trust-store validation fails out of the
     * box. Until we add the CA-import flow, we accept any server cert
     * with a loud log warning. Do NOT ship a release build in this state.
     */
    private fun openTlsSocket(): Socket {
        Log.w(TAG, "⚠ DEV-MODE TLS: accepting any server certificate. Add CA trust before shipping.")
        val ctx = SSLContext.getInstance("TLS")
        ctx.init(null, arrayOf<TrustManager>(TrustAllX509Manager()), SecureRandom())
        val s = ctx.socketFactory.createSocket() as SSLSocket
        s.tcpNoDelay = true
        s.soTimeout = READ_TIMEOUT_MS
        s.connect(InetSocketAddress(server.host, server.port), CONNECT_TIMEOUT_MS.toInt())
        s.startHandshake()
        return s
    }

    private suspend fun readLoop(sock: Socket) {
        val reader: BufferedReader = sock.getInputStream().bufferedReader(Charsets.UTF_8)
        val buffer = StringBuilder()
        try {
            while (coroutineContext.isActive) {
                val ch = reader.read()
                if (ch == -1) break
                buffer.append(ch.toChar())
                if (buffer.endsWith(EVENT_CLOSE_TAG) || buffer.length > 64 * 1024) {
                    _received.tryEmit(buffer.toString())
                    buffer.clear()
                }
            }
        } catch (t: Throwable) {
            Log.w(TAG, "Read loop ended: ${t.javaClass.simpleName}: ${t.message}")
        }
        if (_state.value is ConnectionState.Connected) {
            _state.value = ConnectionState.Disconnected
        }
        cleanup()
    }

    private fun cleanup() {
        runCatching { socket?.close() }
        socket = null
    }

    private class TrustAllX509Manager : X509TrustManager {
        override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) {}
        override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {}
        override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
    }

    companion object {
        private const val TAG = "TAKConnection"
        const val CONNECT_TIMEOUT_MS = 15_000L
        private const val READ_TIMEOUT_MS = 0  // 0 = infinite, we handle cancellation via coroutine
        private const val EVENT_CLOSE_TAG = "</event>"
    }
}
