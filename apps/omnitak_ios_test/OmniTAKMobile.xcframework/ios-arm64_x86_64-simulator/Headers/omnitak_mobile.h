/**
 * @file omnitak_mobile.h
 * @brief C FFI interface for OmniTAK Mobile SDK
 *
 * Cross-platform TAK client library for iOS and Android.
 * Provides TAK server connectivity and CoT message handling.
 */

#ifndef OMNITAK_MOBILE_H
#define OMNITAK_MOBILE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Protocol types */
#define OMNITAK_PROTOCOL_TCP       0
#define OMNITAK_PROTOCOL_UDP       1
#define OMNITAK_PROTOCOL_TLS       2
#define OMNITAK_PROTOCOL_WEBSOCKET 3

/* Error codes */
#define OMNITAK_SUCCESS            0
#define OMNITAK_ERROR             -1

/**
 * Connection status structure
 */
typedef struct {
    int32_t is_connected;
    uint64_t messages_sent;
    uint64_t messages_received;
    int32_t last_error_code;
} ConnectionStatus;

/**
 * Callback function type for receiving CoT messages
 *
 * @param user_data Opaque pointer passed to omnitak_register_callback
 * @param connection_id Connection that received the message
 * @param cot_xml Null-terminated C string containing CoT XML
 */
typedef void (*CotCallback)(
    void* user_data,
    uint64_t connection_id,
    const char* cot_xml
);

/**
 * Initialize the omniTAK mobile library
 *
 * Must be called before any other functions.
 * Safe to call multiple times (subsequent calls are no-op).
 *
 * @return OMNITAK_SUCCESS on success, OMNITAK_ERROR on failure
 */
int32_t omnitak_init(void);

/**
 * Shutdown the omniTAK mobile library
 *
 * Disconnects all connections and cleans up resources.
 * No omnitak_* functions should be called after this.
 */
void omnitak_shutdown(void);

/**
 * Connect to a TAK server
 *
 * @param host Null-terminated C string with hostname or IP
 * @param port Server port number
 * @param protocol Protocol type (OMNITAK_PROTOCOL_*)
 * @param use_tls Whether to use TLS (1=yes, 0=no)
 * @param cert_pem Optional PEM-encoded certificate (NULL for none)
 * @param key_pem Optional PEM-encoded private key (NULL for none)
 * @param ca_pem Optional PEM-encoded CA cert (NULL for none)
 * @return Connection ID on success, 0 on failure
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

/**
 * Disconnect from a TAK server
 *
 * @param connection_id Connection ID returned from omnitak_connect
 * @return OMNITAK_SUCCESS on success, OMNITAK_ERROR on failure
 */
int32_t omnitak_disconnect(uint64_t connection_id);

/**
 * Send a CoT message to the server
 *
 * @param connection_id Connection ID
 * @param cot_xml Null-terminated C string containing CoT XML
 * @return OMNITAK_SUCCESS on success, OMNITAK_ERROR on failure
 */
int32_t omnitak_send_cot(uint64_t connection_id, const char* cot_xml);

/**
 * Register a callback for receiving CoT messages
 *
 * @param connection_id Connection ID
 * @param callback Function to call when CoT received
 * @param user_data Opaque pointer passed to callback
 * @return OMNITAK_SUCCESS on success, OMNITAK_ERROR on failure
 *
 * @note Callback will be called from background thread
 * @note user_data must remain valid until callback is unregistered
 */
int32_t omnitak_register_callback(
    uint64_t connection_id,
    CotCallback callback,
    void* user_data
);

/**
 * Unregister CoT callback
 *
 * @param connection_id Connection ID
 * @return OMNITAK_SUCCESS on success, OMNITAK_ERROR on failure
 */
int32_t omnitak_unregister_callback(uint64_t connection_id);

/**
 * Get connection status
 *
 * @param connection_id Connection ID
 * @param status_out Pointer to ConnectionStatus struct to fill
 * @return OMNITAK_SUCCESS on success, OMNITAK_ERROR on failure
 */
int32_t omnitak_get_status(uint64_t connection_id, ConnectionStatus* status_out);

/**
 * Get library version string
 *
 * @return Null-terminated C string with version (statically allocated)
 */
const char* omnitak_version(void);

#ifdef __cplusplus
}
#endif

#endif /* OMNITAK_MOBILE_H */
