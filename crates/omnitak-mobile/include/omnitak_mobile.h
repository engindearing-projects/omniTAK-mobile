/*
 * OmniTAK Mobile - C FFI Header
 *
 * Cross-platform interface for iOS and Android
 */

#ifndef OMNITAK_MOBILE_H
#define OMNITAK_MOBILE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Protocol types */
#define OMNITAK_PROTOCOL_TCP 0
#define OMNITAK_PROTOCOL_UDP 1
#define OMNITAK_PROTOCOL_TLS 2
#define OMNITAK_PROTOCOL_WEBSOCKET 3

/* Connection status structure */
typedef struct {
    int32_t is_connected;
    uint64_t messages_sent;
    uint64_t messages_received;
    int32_t last_error_code;
} ConnectionStatus;

/* Callback function type for receiving CoT messages */
typedef void (*CotCallback)(
    void* user_data,
    uint64_t connection_id,
    const char* cot_xml
);

/*
 * Initialize the omniTAK mobile library
 *
 * Must be called before any other functions.
 * Safe to call multiple times (subsequent calls are no-op).
 *
 * Returns: 0 on success, -1 on error
 */
int32_t omnitak_init(void);

/*
 * Shutdown the omniTAK mobile library
 *
 * Disconnects all connections and cleans up resources.
 * No omnitak_* functions should be called after this.
 */
void omnitak_shutdown(void);

/*
 * Connect to a TAK server
 *
 * Parameters:
 *   host - Null-terminated C string with hostname or IP
 *   port - Server port number
 *   protocol - Protocol type (0=TCP, 1=UDP, 2=TLS, 3=WebSocket)
 *   use_tls - Whether to use TLS (1=yes, 0=no)
 *   cert_pem - Optional PEM-encoded certificate (NULL for none)
 *   key_pem - Optional PEM-encoded private key (NULL for none)
 *   ca_pem - Optional PEM-encoded CA cert (NULL for none)
 *
 * Returns: Connection ID on success, 0 on failure
 */
uint64_t omnitak_connect(
    const char* host,
    uint16_t port,
    int32_t protocol,
    int32_t use_tls,
    const char* cert_pem,
    const char* key_pem,
    const char* ca_pem
);

/*
 * Disconnect from a TAK server
 *
 * Parameters:
 *   connection_id - Connection ID returned from omnitak_connect
 *
 * Returns: 0 on success, -1 on error
 */
int32_t omnitak_disconnect(uint64_t connection_id);

/*
 * Send a CoT message to the server
 *
 * Parameters:
 *   connection_id - Connection ID
 *   cot_xml - Null-terminated C string containing CoT XML
 *
 * Returns: 0 on success, -1 on error
 */
int32_t omnitak_send_cot(
    uint64_t connection_id,
    const char* cot_xml
);

/*
 * Register a callback for receiving CoT messages
 *
 * Parameters:
 *   connection_id - Connection ID
 *   callback - Function to call when CoT received
 *   user_data - Opaque pointer passed to callback
 *
 * Returns: 0 on success, -1 on error
 *
 * Note: Callback will be called from background thread
 */
int32_t omnitak_register_callback(
    uint64_t connection_id,
    CotCallback callback,
    void* user_data
);

/*
 * Unregister CoT callback
 *
 * Parameters:
 *   connection_id - Connection ID
 *
 * Returns: 0 on success, -1 on error
 */
int32_t omnitak_unregister_callback(uint64_t connection_id);

/*
 * Get connection status
 *
 * Parameters:
 *   connection_id - Connection ID
 *   status_out - Pointer to ConnectionStatus struct to fill
 *
 * Returns: 0 on success, -1 on error
 */
int32_t omnitak_get_status(
    uint64_t connection_id,
    ConnectionStatus* status_out
);

/*
 * Get library version string
 *
 * Returns: Null-terminated C string with version
 *          String is statically allocated and does not need to be freed
 */
const char* omnitak_version(void);

#ifdef __cplusplus
}
#endif

#endif /* OMNITAK_MOBILE_H */
