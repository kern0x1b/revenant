/*
 * The WebSocket options, metadata, request and response of ws_options.h.
 *
 * These are the four objects a WebSocket connection is configured and described with: the options a
 * program sets (the subprotocols it will speak, the headers it adds, the largest message it will
 * take, whether it answers the handshake itself and whether it answers a ping by itself), the
 * metadata that describes one message of a connection (its opcode, its close code, the pong handler
 * a ping is answered with, the response the server sent for the client's request), and the request
 * and response objects of that handshake.
 *
 * What the port does not have is the WebSocket layer itself: see facts/Network/NWWebSocket.md. These
 * objects are the configuration and the description a program reads and writes, and they keep what
 * they are given and answer it as the SDK documents; a connection of WebSocket options carries no
 * WebSocket layer, which is stated there rather than hidden.
 */

#import "CharonNW.h"
#import "CharonNWSupport.h"

#include <string.h>

#pragma mark - options

nw_protocol_options_t nw_ws_create_options(nw_ws_version_t version)
{
    CharonNWProtocolOptions *options = [[CharonNWProtocolOptions alloc] init];
    options->_definition = (CharonNWProtocolDefinition *)nw_protocol_copy_ws_definition();
    options->_values = [NSMutableDictionary dictionary];
    options->_objects = [NSMutableDictionary dictionary];
    charon_nw_set_integer((__bridge CFMutableDictionaryRef)options->_values, "version", version);
    NSMutableArray *subprotocols = [NSMutableArray array];
    NSMutableArray *names = [NSMutableArray array];
    NSMutableArray *values = [NSMutableArray array];
    options->_objects[@"subprotocols"] = subprotocols;
    options->_objects[@"header_names"] = names;
    options->_objects[@"header_values"] = values;
    return options;
}

void nw_ws_options_add_subprotocol(nw_protocol_options_t options, const char *subprotocol)
{
    if (!subprotocol || !*subprotocol)
        return;
    NSArray *held = ((CharonNWProtocolOptions *)options)->_objects[@"subprotocols"];
    [(NSMutableArray *)held addObject:@(subprotocol)];
}

void nw_ws_options_add_additional_header(nw_protocol_options_t options, const char *name, const char *value)
{
    if (!name || !*name)
        return;
    CharonNWProtocolOptions *held = (CharonNWProtocolOptions *)options;
    [(NSMutableArray *)held->_objects[@"header_names"] addObject:@(name)];
    [(NSMutableArray *)held->_objects[@"header_values"] addObject:value ? @(value) : @""];
}

void nw_ws_options_set_auto_reply_ping(nw_protocol_options_t options, bool auto_reply_ping)
{
    charon_nw_set_flag((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "auto_reply_ping", auto_reply_ping);
}

void nw_ws_options_set_maximum_message_size(nw_protocol_options_t options, size_t maximum_message_size)
{
    charon_nw_set_integer((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "maximum_message_size", (int64_t)maximum_message_size);
}

void nw_ws_options_set_skip_handshake(nw_protocol_options_t options, bool skip_handshake)
{
    charon_nw_set_flag((__bridge CFMutableDictionaryRef)((CharonNWProtocolOptions *)options)->_values, "skip_handshake", skip_handshake);
}

void nw_ws_options_set_client_request_handler(nw_protocol_options_t options, dispatch_queue_t client_queue, nw_ws_client_request_handler_t handler)
{
    CharonNWProtocolOptions *value = (CharonNWProtocolOptions *)options;
    value->_objects[@"client_request_queue"] = client_queue;
    value->_objects[@"client_request_handler"] = handler;
}

#pragma mark - metadata

nw_protocol_metadata_t nw_ws_create_metadata(nw_ws_opcode_t opcode)
{
    CharonNWProtocolMetadata *metadata = [[CharonNWProtocolMetadata alloc] init];
    metadata->_definition = (CharonNWProtocolDefinition *)nw_protocol_copy_ws_definition();
    metadata->_values = [NSMutableDictionary dictionary];
    metadata->_objects = [NSMutableDictionary dictionary];
    charon_nw_set_integer((__bridge CFMutableDictionaryRef)metadata->_values, "opcode", opcode);
    charon_nw_set_integer((__bridge CFMutableDictionaryRef)metadata->_values, "close_code", nw_ws_close_code_no_status_received);
    return metadata;
}

nw_ws_opcode_t nw_ws_metadata_get_opcode(nw_protocol_metadata_t metadata)
{
    if (!nw_protocol_metadata_is_ws(metadata))
        return nw_ws_opcode_invalid;
    CharonNWProtocolMetadata *value = (CharonNWProtocolMetadata *)metadata;
    return (nw_ws_opcode_t)charon_nw_integer((__bridge CFDictionaryRef)value->_values, "opcode", nw_ws_opcode_invalid);
}

nw_ws_close_code_t nw_ws_metadata_get_close_code(nw_protocol_metadata_t metadata)
{
    if (!nw_protocol_metadata_is_ws(metadata))
        return nw_ws_close_code_no_status_received;
    CharonNWProtocolMetadata *value = (CharonNWProtocolMetadata *)metadata;
    return (nw_ws_close_code_t)charon_nw_integer((__bridge CFDictionaryRef)value->_values, "close_code", nw_ws_close_code_no_status_received);
}

void nw_ws_metadata_set_close_code(nw_protocol_metadata_t metadata, nw_ws_close_code_t close_code)
{
    if (!nw_protocol_metadata_is_ws(metadata))
        return;
    charon_nw_set_integer((__bridge CFMutableDictionaryRef)((CharonNWProtocolMetadata *)metadata)->_values, "close_code", close_code);
}

void nw_ws_metadata_set_pong_handler(nw_protocol_metadata_t metadata, dispatch_queue_t client_queue, nw_ws_pong_handler_t pong_handler)
{
    if (!nw_protocol_metadata_is_ws(metadata))
        return;
    CharonNWProtocolMetadata *value = (CharonNWProtocolMetadata *)metadata;
    value->_objects[@"pong_queue"] = client_queue;
    value->_objects[@"pong_handler"] = pong_handler;
}

nw_ws_response_t nw_ws_metadata_copy_server_response(nw_protocol_metadata_t metadata)
{
    if (!nw_protocol_metadata_is_ws(metadata))
        return NULL;
    CharonNWProtocolMetadata *value = (CharonNWProtocolMetadata *)metadata;
    return (nw_ws_response_t)value->_objects[@"server_response"];
}

#pragma mark - request

nw_ws_response_t nw_ws_response_create(nw_ws_response_status_t status, const char *selected_subprotocol)
{
    CharonNWWebSocketResponse *response = [[CharonNWWebSocketResponse alloc] init];
    response->_status = status;
    response->_selectedSubprotocol = selected_subprotocol ? @(selected_subprotocol) : nil;
    response->_headerNames = [NSMutableArray array];
    response->_headerValues = [NSMutableArray array];
    return response;
}

nw_ws_response_status_t nw_ws_response_get_status(nw_ws_response_t response)
{
    CharonNWWebSocketResponse *value = (CharonNWWebSocketResponse *)response;
    return value ? value->_status : (nw_ws_response_status_t)0;
}

const char *nw_ws_response_get_selected_subprotocol(nw_ws_response_t response)
{
    CharonNWWebSocketResponse *value = (CharonNWWebSocketResponse *)response;
    if (!value || !value->_selectedSubprotocol)
        return NULL;
    return value->_selectedSubprotocol.UTF8String;
}

void nw_ws_response_add_additional_header(nw_ws_response_t response, const char *name, const char *value)
{
    CharonNWWebSocketResponse *held = (CharonNWWebSocketResponse *)response;
    if (!held || !name || !*name)
        return;
    [held->_headerNames addObject:@(name)];
    [held->_headerValues addObject:value ? @(value) : @""];
}

bool nw_ws_response_enumerate_additional_headers(nw_ws_response_t response, nw_ws_additional_header_enumerator_t enumerator)
{
    CharonNWWebSocketResponse *value = (CharonNWWebSocketResponse *)response;
    if (!value || !enumerator)
        return false;
    for (NSUInteger index = 0; index < value->_headerNames.count; index++) {
        if (!enumerator(((NSString *)value->_headerNames[index]).UTF8String,
                        ((NSString *)value->_headerValues[index]).UTF8String))
            return false;
    }
    return true;
}

bool nw_ws_request_enumerate_subprotocols(nw_ws_request_t request, nw_ws_subprotocol_enumerator_t enumerator)
{
    CharonNWWebSocketRequest *value = (CharonNWWebSocketRequest *)request;
    if (!value || !enumerator)
        return false;
    for (NSString *subprotocol in value->_subprotocols) {
        if (!enumerator(subprotocol.UTF8String))
            return false;
    }
    return true;
}

bool nw_ws_request_enumerate_additional_headers(nw_ws_request_t request, nw_ws_additional_header_enumerator_t enumerator)
{
    CharonNWWebSocketRequest *value = (CharonNWWebSocketRequest *)request;
    if (!value || !enumerator)
        return false;
    for (NSUInteger index = 0; index < value->_headerNames.count; index++) {
        if (!enumerator(((NSString *)value->_headerNames[index]).UTF8String,
                        ((NSString *)value->_headerValues[index]).UTF8String))
            return false;
    }
    return true;
}
