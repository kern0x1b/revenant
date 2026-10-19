/*
 * The framer of iOS 13: a program's own protocol, put between a connection's transport and its
 * application, and every call of framer_options.h.
 *
 * A framer is given the bytes a connection received and hands back the bytes to send, so the port
 * keeps what it has not parsed yet (`_input`), what the program has produced (`_output`) and the
 * messages it has delivered (`_delivered`), which is where a connection picks the three up. The
 * contract of the three calls that move bytes is the SDK's own: `nw_framer_parse_input` runs the
 * parse block inline exactly once, with a contiguous buffer of at least the minimum asked for or
 * with none, and takes back as many bytes as the block says it read; `nw_framer_deliver_input` hands
 * a whole message on; `nw_framer_write_output` adds what is to be sent.
 *
 * The pass-through flags are the SDK's: once a side is passing through, its bytes are no longer
 * parsed or built but go on as they are, and the framer says so.
 */

#import "CharonNW.h"
#import "CharonNWSupport.h"

#include <string.h>

@class CharonNWProtocolMetadata;

#pragma mark - definition and options

nw_protocol_definition_t nw_framer_create_definition(const char *identifier, uint32_t flags, nw_framer_start_handler_t start_handler)
{
    if (!identifier || !*identifier)
        return NULL;
    CharonNWProtocolDefinition *definition = [[CharonNWProtocolDefinition alloc] init];
    /* A framer is named by the program that writes it, and it is made afresh every time: the start
       handler it was given is what makes it that program's protocol, so two definitions of one name
       and one set of flags are two protocols and do not compare equal. The host's own Network answers
       the same (tests/backports/host/network-objects), and nw_protocol_definition_is_equal is where
       that is decided. */
    definition->_family = @(identifier);
    definition->_identifier = @(identifier);
    definition->_flags = flags;
    definition->_payload = start_handler;
    return definition;
}

nw_protocol_options_t nw_framer_create_options(nw_protocol_definition_t framer_definition)
{
    if (!framer_definition)
        return NULL;
    CharonNWProtocolOptions *options = [[CharonNWProtocolOptions alloc] init];
    options->_definition = (CharonNWProtocolDefinition *)framer_definition;
    options->_values = [NSMutableDictionary dictionary];
    options->_objects = [NSMutableDictionary dictionary];
    return options;
}

#pragma mark - messages

nw_framer_message_t nw_framer_message_create(nw_framer_t framer)
{
    if (!framer)
        return NULL;
    return nw_framer_protocol_create_message(((CharonNWFramer *)framer)->_definition);
}

nw_framer_message_t nw_framer_protocol_create_message(nw_protocol_definition_t definition)
{
    if (!definition)
        return NULL;
    CharonNWProtocolMetadata *message = [[CharonNWProtocolMetadata alloc] init];
    message->_definition = (CharonNWProtocolDefinition *)definition;
    message->_values = [NSMutableDictionary dictionary];
    message->_objects = [NSMutableDictionary dictionary];
    return message;
}

bool nw_protocol_metadata_is_framer_message(nw_protocol_metadata_t metadata)
{
    CharonNWProtocolMetadata *value = (CharonNWProtocolMetadata *)metadata;
    if (!value)
        return false;
    CharonNWProtocolDefinition *definition = value->_definition;
    /* A framer's message is one of two kinds: a message of a protocol a program wrote, whose
       definition carries the start handler, or a WebSocket frame, which the system itself carries as
       one. The messages of the built-in protocols are not. */
    return definition->_payload != nil || [definition->_family isEqualToString:@"nw_ws"];
}

void nw_framer_message_set_value(nw_framer_message_t message, const char *key, void *value, nw_framer_message_dispose_value_t dispose_value)
{
    CharonNWProtocolMetadata *held = (CharonNWProtocolMetadata *)message;
    if (!held || !key)
        return;
    NSString *name = @(key);
    held->_objects[name] = [NSValue valueWithPointer:value];
    /* The block that frees the value is kept under the same name with `dispose:` in front of it,
       and is run when the message goes away: what a value was made with is what frees it. */
    if (dispose_value)
        held->_objects[[@"dispose:" stringByAppendingString:name]] = [dispose_value copy];
}

bool nw_framer_message_access_value(nw_framer_message_t message, const char *key, bool (^access_value)(const void *value))
{
    CharonNWProtocolMetadata *held = (CharonNWProtocolMetadata *)message;
    if (!held || !key || !access_value)
        return false;
    NSValue *boxed = held->_objects[@(key)];
    return access_value(boxed ? (const void *)[boxed pointerValue] : NULL);
}

void nw_framer_message_set_object_value(nw_framer_message_t message, const char *key, id value)
{
    CharonNWProtocolMetadata *held = (CharonNWProtocolMetadata *)message;
    if (!held || !key)
        return;
    if (value)
        held->_objects[@(key)] = value;
    else
        [held->_objects removeObjectForKey:@(key)];
}

id nw_framer_message_copy_object_value(nw_framer_message_t message, const char *key)
{
    CharonNWProtocolMetadata *held = (CharonNWProtocolMetadata *)message;
    if (!held || !key)
        return nil;
    return held->_objects[@(key)];
}

#pragma mark - the framer's own state

nw_parameters_t nw_framer_copy_parameters(nw_framer_t framer)
{
    return framer ? ((CharonNWFramer *)framer)->_parameters : NULL;
}

nw_endpoint_t nw_framer_copy_local_endpoint(nw_framer_t framer)
{
    return framer ? ((CharonNWFramer *)framer)->_localEndpoint : NULL;
}

nw_endpoint_t nw_framer_copy_remote_endpoint(nw_framer_t framer)
{
    return framer ? ((CharonNWFramer *)framer)->_remoteEndpoint : NULL;
}

void nw_framer_set_input_handler(nw_framer_t framer, nw_framer_input_handler_t input_handler)
{
    CharonNWFramer *value = (CharonNWFramer *)framer;
    if (value)
        value->_inputHandler = [input_handler copy];
}

void nw_framer_set_output_handler(nw_framer_t framer, nw_framer_output_handler_t output_handler)
{
    CharonNWFramer *value = (CharonNWFramer *)framer;
    if (value)
        value->_outputHandler = [output_handler copy];
}

void nw_framer_set_stop_handler(nw_framer_t framer, nw_framer_stop_handler_t stop_handler)
{
    CharonNWFramer *value = (CharonNWFramer *)framer;
    if (value)
        value->_stopHandler = [stop_handler copy];
}

void nw_framer_set_cleanup_handler(nw_framer_t framer, nw_framer_cleanup_handler_t cleanup_handler)
{
    CharonNWFramer *value = (CharonNWFramer *)framer;
    if (value)
        value->_cleanupHandler = [cleanup_handler copy];
}

void nw_framer_set_wakeup_handler(nw_framer_t framer, nw_framer_wakeup_handler_t wakeup_handler)
{
    CharonNWFramer *value = (CharonNWFramer *)framer;
    if (value)
        value->_wakeupHandler = [wakeup_handler copy];
}

void nw_framer_async(nw_framer_t framer, nw_framer_block_t async_block)
{
    CharonNWFramer *value = (CharonNWFramer *)framer;
    if (!value || !async_block)
        return;
    if (value->_queue)
        dispatch_async(value->_queue, async_block);
    else
        async_block();
}

void nw_framer_mark_ready(nw_framer_t framer)
{
    CharonNWFramer *value = (CharonNWFramer *)framer;
    if (value)
        value->_ready = YES;
}

void nw_framer_mark_failed_with_error(nw_framer_t framer, int error_code)
{
    CharonNWFramer *value = (CharonNWFramer *)framer;
    if (!value)
        return;
    value->_failed = YES;
    value->_errorCode = error_code;
}

void nw_framer_pass_through_input(nw_framer_t framer)
{
    CharonNWFramer *value = (CharonNWFramer *)framer;
    if (value)
        value->_inputPassThrough = YES;
}

void nw_framer_pass_through_output(nw_framer_t framer)
{
    CharonNWFramer *value = (CharonNWFramer *)framer;
    if (value)
        value->_outputPassThrough = YES;
}

bool nw_framer_prepend_application_protocol(nw_framer_t framer, nw_protocol_options_t protocol_options)
{
    CharonNWFramer *value = (CharonNWFramer *)framer;
    CharonNWProtocolOptions *protocol = (CharonNWProtocolOptions *)protocol_options;
    if (!value || !protocol)
        return false;
    /* Only an application protocol can go above a framer: a transport or an internet protocol is
       part of the connection itself, and the header refuses those. */
    NSString *family = protocol->_definition ? protocol->_definition->_family : nil;
    if (!family || [family isEqualToString:@"nw_tcp"] || [family isEqualToString:@"nw_udp"] || [family isEqualToString:@"nw_ip"])
        return false;
    NSMutableArray *stack = value->_parameters ? value->_parameters->_stack->_application : nil;
    if (stack)
        [stack insertObject:protocol atIndex:0];
    return true;
}

void nw_framer_schedule_wakeup(nw_framer_t framer, uint64_t milliseconds)
{
    CharonNWFramer *value = (CharonNWFramer *)framer;
    if (!value)
        return;
    uint64_t generation = ++value->_wakeupGeneration;
    if (milliseconds == UINT64_MAX) {
        /* The SDK's way of taking a wakeup back: the largest number there is. */
        [value->_pendingWakeups removeAllObjects];
        return;
    }
    [value->_pendingWakeups addObject:@[@(milliseconds), @(generation)]];
    if (!value->_queue)
        return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(milliseconds * NSEC_PER_MSEC)), value->_queue, ^{
        if (generation != value->_wakeupGeneration)
            return;
        [value->_pendingWakeups removeAllObjects];
        if (value->_wakeupHandler)
            value->_wakeupHandler(framer);
    });
}

#pragma mark - the bytes

bool nw_framer_parse_input(nw_framer_t framer, size_t minimum_incomplete_length, size_t maximum_length, uint8_t *temp_buffer, nw_framer_parse_completion_t parse)
{
    CharonNWFramer *value = (CharonNWFramer *)framer;
    if (!value || !parse)
        return false;
    size_t available = value->_input.length;
    /* The parse block is run inline exactly once, with a contiguous buffer of at least the minimum
       asked for, or with none when there is not that much - which is what the header says a framer
       that has not enough does. */
    size_t length = available < maximum_length ? available : maximum_length;
    if (length < minimum_incomplete_length) {
        parse(temp_buffer, 0, false);
        return false;
    }
    uint8_t *bytes = value->_input.mutableBytes;
    if (temp_buffer) {
        memcpy(temp_buffer, bytes, length);
        bytes = temp_buffer;
    }
    size_t consumed = parse(bytes, length, false);
    if (consumed > length)
        consumed = length;
    [value->_input replaceBytesInRange:NSMakeRange(0, consumed) withBytes:NULL length:0];
    return true;
}

void nw_framer_deliver_input(nw_framer_t framer, const uint8_t *input_buffer, size_t input_length, nw_framer_message_t message, bool is_complete)
{
    CharonNWFramer *value = (CharonNWFramer *)framer;
    if (!value || !input_buffer || !input_length)
        return;
    [value->_delivered addObject:@[(id)[NSData dataWithBytes:input_buffer length:input_length],
                                              message ? (id)message : [NSNull null], @(is_complete)]];
}

bool nw_framer_deliver_input_no_copy(nw_framer_t framer, size_t input_length, nw_framer_message_t message, bool is_complete)
{
    CharonNWFramer *value = (CharonNWFramer *)framer;
    if (!value || !input_length || input_length > value->_input.length)
        return false;
    nw_framer_deliver_input(framer, (const uint8_t *)value->_input.bytes, input_length, message, is_complete);
    [value->_input replaceBytesInRange:NSMakeRange(0, input_length) withBytes:NULL length:0];
    return true;
}

void nw_framer_write_output(nw_framer_t framer, const uint8_t *output_buffer, size_t output_length)
{
    CharonNWFramer *value = (CharonNWFramer *)framer;
    if (!value || !output_length)
        return;
    [value->_output appendBytes:output_buffer length:output_length];
}

void nw_framer_write_output_data(nw_framer_t framer, dispatch_data_t output_data)
{
    CharonNWFramer *value = (CharonNWFramer *)framer;
    if (!value || !output_data)
        return;
    size_t length = dispatch_data_get_size(output_data);
    if (!length)
        return;
    /* The data is copied out region by region, which is what a dispatch_data_t is: a list of
       disjoint ranges of bytes that together are the message. */
    __block size_t written = 0;
    dispatch_data_apply(output_data, ^bool(dispatch_data_t region, size_t offset, const void *buffer, size_t size) {
        [value->_output appendBytes:buffer length:size];
        written += size;
        return true;
    });
    (void)written;
}

bool nw_framer_write_output_no_copy(nw_framer_t framer, size_t output_length)
{
    CharonNWFramer *value = (CharonNWFramer *)framer;
    if (!value || !output_length)
        return false;
    /* The room is made here and the program writes into it, which is what a write without a copy is:
       the framer's output is its own and grows, so there is room for as much as the program asks for,
       and the answer is whether the connection is still there to take it. The framer is torn down when
       the connection stops using it (nw_framer_set_stop_handler), and a stopped framer has nowhere to
       put the bytes, which is the one way this is false. */
    if (value->_failed)
        return false;
    [value->_output increaseLengthBy:output_length];
    return true;
}

#pragma mark - output

bool nw_framer_parse_output(nw_framer_t framer, size_t minimum_incomplete_length, size_t maximum_length, uint8_t *temp_buffer, nw_framer_parse_completion_t parse)
{
    CharonNWFramer *value = (CharonNWFramer *)framer;
    if (!value || !parse)
        return false;
    /* The same contract as the input side, over what the program has written and the connection has
       not sent yet: the parse block is run inline exactly once, with a contiguous buffer of at least
       the minimum asked for or with none. */
    size_t available = value->_output.length;
    size_t length = available < maximum_length ? available : maximum_length;
    if (length < minimum_incomplete_length) {
        parse(temp_buffer, 0, false);
        return false;
    }
    uint8_t *bytes = value->_output.mutableBytes;
    if (temp_buffer) {
        memcpy(temp_buffer, bytes, length);
        bytes = temp_buffer;
    }
    size_t consumed = parse(bytes, length, false);
    if (consumed > length)
        consumed = length;
    [value->_output replaceBytesInRange:NSMakeRange(0, consumed) withBytes:NULL length:0];
    return true;
}
