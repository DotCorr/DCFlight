/*
 * Copyright (c) Dotcorr Studio. and affiliates.
 *
 * Licensed under the PolyForm Noncommercial License 1.0.0.
 * Commercial use requires a license from DotCorr.
 */

#ifndef DCFLIGHT_FFI_H
#define DCFLIGHT_FFI_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Event callback function pointer type
// Signature: void callback(int32_t viewId, const char* eventType, const char* eventDataJson)
typedef void (*DCFlightEventCallback)(int32_t viewId, const char* eventType, const char* eventDataJson);

// Screen dimensions callback function pointer type
// Signature: void callback(const char* dimensionsJson)
typedef void (*DCFlightScreenDimensionsCallback)(const char* dimensionsJson);

// Initialize the DCFlight bridge
bool dcflight_initialize(void);

// View operations
bool dcflight_create_view(int32_t viewId, const char* viewType, const char* propsJson);
bool dcflight_update_view(int32_t viewId, const char* propsJson);
bool dcflight_delete_view(int32_t viewId);
bool dcflight_detach_view(int32_t childId);
bool dcflight_attach_view(int32_t childId, int32_t parentId, int32_t index);
bool dcflight_set_children(int32_t viewId, const int32_t* childrenIds, int32_t childrenCount);

// Event listeners
bool dcflight_add_event_listeners(int32_t viewId, const char* eventTypes);
bool dcflight_remove_event_listeners(int32_t viewId, const char* eventTypes);

// Batch updates
bool dcflight_start_batch_update(void);
bool dcflight_commit_batch_update(const char* operationsJson);
bool dcflight_cancel_batch_update(void);

// Tunnel mechanism
bool dcflight_tunnel(const char* componentType, const char* method, const char* paramsJson, char* resultJson, int32_t resultSize);

// Event callback management
void dcflight_set_event_callback(DCFlightEventCallback callback);
DCFlightEventCallback dcflight_get_event_callback(void);
void dcflight_send_event(int32_t viewId, const char* eventType, const char* eventDataJson);
const char* dcflight_get_queued_events(void);
void dcflight_process_event_queue(void);

// Screen dimensions
bool dcflight_get_screen_dimensions(char* resultJson, int32_t resultSize);
void dcflight_set_screen_dimensions_callback(DCFlightScreenDimensionsCallback callback);
void dcflight_send_screen_dimensions_changed(const char* dimensionsJson);
const char* dcflight_get_queued_screen_dimensions(void);
void dcflight_process_screen_dimensions_queue(void);

// Hot restart
bool dcflight_get_session_token(char* resultJson, int32_t resultSize);
bool dcflight_create_session_token(char* resultJson, int32_t resultSize);
void dcflight_clear_session_token(void);
void dcflight_cleanup_views(void);

#ifdef __cplusplus
}
#endif

#endif // DCFLIGHT_FFI_H
