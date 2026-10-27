#import "RevenantNW.h"
#import "RevenantNWSupport.h"
#import "RevenantTLS/RevenantTLSEngine.h"
#import "../Security/RevenantSecProtocolMetadata.h"

#include <assert.h>
#include <errno.h>
#include <mach/mach_time.h>
#include <stdio.h>
#include <netdb.h>
#include <netinet/in.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <netinet/tcp.h>
#include <sys/ioctl.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#include <Security/Security.h>

enum { nw_connection_state_setup = 0 };

@interface RevenantNWConnection : NSObject <OS_nw_connection> {
@public
    RevenantNWEndpointValue *_endpoint;
    RevenantNWParameters *_parameters;
    dispatch_queue_t _queue;
    dispatch_queue_t _connectQueue;
    nw_connection_state_changed_handler_t _state;
    nw_connection_path_event_handler_t _path;
    nw_connection_boolean_event_handler_t _viability;
    nw_connection_boolean_event_handler_t _betterPath;
    nw_connection_state_t _value;
    nw_path_t _currentPath;
    nw_path_monitor_t _monitor;
    RevenantNWEndpointValue *_currentEndpoint;
    BOOL _started, _cancelled, _finished, _secure, _viable, _viableKnown, _connecting;
    int _socket;
    int _acceptedSocket;
    RevenantTLSEngine *_ssl;
    dispatch_source_t _readSource;
    dispatch_source_t _writeSource;
    BOOL _readingSource, _handshaking;
    NSMutableArray *_sends;
    NSMutableArray *_receives;
    NSMutableData *_pendingWrite;
    NSMutableData *_pendingRead;
    uint64_t _sentBytes, _receivedBytes;
    uint64_t _startedAtMilliseconds;
    uint32_t _attempts;
    BOOL _isDatagram;
    RevenantNWProtocolMetadata *_ipMetadata;
    RevenantNWProtocolMetadata *_transportMetadata;
    RevenantNWProtocolMetadata *_secureMetadata;
    RevenantNWFramer *_framer;
    id _lastFramerMessage;
}
@end

@implementation RevenantNWConnection
@end

@interface RevenantNWSend : NSObject {
@public
    NSData *_content;
    nw_content_context_t _context;
    bool _isComplete;
    nw_connection_send_completion_t _completion;
}
@end
@implementation RevenantNWSend
@end

@interface RevenantNWReceive : NSObject {
@public
    uint32_t _minimum;
    uint32_t _maximum;
    nw_connection_receive_completion_t _completion;
}
@end
@implementation RevenantNWReceive
@end

static RevenantNWProtocolOptions *revenant_stack_application(RevenantNWParameters *parameters, NSString *family)
{
    for (RevenantNWProtocolOptions *options in parameters->_stack->_application) {
        if ([options->_definition->_family isEqualToString:family])
            return options;
    }
    return nil;
}

static BOOL revenant_is_datagram(RevenantNWParameters *parameters)
{
    RevenantNWProtocolDefinition *transport = parameters->_stack->_transport ? parameters->_stack->_transport->_definition : nil;
    if (transport)
        return [transport->_family isEqualToString:@"nw_udp"];
    return NO;
}

static BOOL revenant_is_secure(RevenantNWParameters *parameters)
{
    return revenant_stack_application(parameters, @"nw_tls") != nil;
}

static RevenantNWProtocolOptions *revenant_stack_framer(RevenantNWParameters *parameters)
{
    for (RevenantNWProtocolOptions *options in parameters->_stack->_application) {
        if (options->_definition->_payload)
            return options;
    }
    return nil;
}

static void revenant_deliver_received(RevenantNWConnection *connection);
static void revenant_ready(RevenantNWConnection *connection);
static void revenant_tls_pump(RevenantNWConnection *connection);
static void revenant_handshake(RevenantNWConnection *connection);
static void revenant_flush(RevenantNWConnection *connection);
static void revenant_connect_finished(RevenantNWConnection *connection);
static void revenant_install_sources(RevenantNWConnection *connection);
static BOOL revenant_take_connected_socket(RevenantNWConnection *connection, int handle, RevenantNWEndpointValue *endpoint);
static void revenant_stop(RevenantNWConnection *connection, nw_connection_state_t state, RevenantNWError *error);
static void revenant_readable(RevenantNWConnection *connection);
static RevenantSecProtocolOptions *revenant_tls_options(RevenantNWParameters *parameters);

#pragma mark - the state machine

static void revenant_report_state(RevenantNWConnection *connection, nw_connection_state_t state, RevenantNWError *error)
{
    if (getenv("REVENANT_TRACE_CONNECTION"))
        fprintf(stderr, "[%8llu] port: state fd=%d -> %d error=%d/%d\n",
                (unsigned long long)(mach_absolute_time() / 1000000), connection->_socket, state,
                error ? error->_domain : 0, error ? error->_code : 0);
    @synchronized(connection) {
        if (connection->_cancelled && state != nw_connection_state_cancelled)
            return;
        if (connection->_value == state && state != nw_connection_state_failed && state != nw_connection_state_ready)
            return;
        connection->_value = state;
    }
    nw_connection_state_changed_handler_t handler = connection->_state;
    if (handler)
        handler(state, error);
}

static RevenantNWError *revenant_error(nw_error_domain_t domain, int code)
{
    if (!code)
        return nil;
    RevenantNWError *error = [[RevenantNWError alloc] init];
    error->_domain = domain;
    error->_code = code;
    return error;
}

static RevenantNWError *revenant_posix_error(void)
{
    return revenant_error(nw_error_domain_posix, errno);
}

#pragma mark - the socket

static void revenant_apply_options(RevenantNWConnection *connection)
{
    int handle = connection->_socket;
    RevenantNWParameters *parameters = connection->_parameters;
    RevenantNWProtocolStack *stack = parameters->_stack;
    if (!connection->_isDatagram) {
        RevenantNWProtocolOptions *tcp = stack->_transport;
        NSDictionary *values = tcp ? tcp->_values : nil;
        int on = 1;
        if (revenant_nw_flag((__bridge CFDictionaryRef)values, "no_delay", false))
            setsockopt(handle, IPPROTO_TCP, TCP_NODELAY, &on, sizeof on);
        if (revenant_nw_flag((__bridge CFDictionaryRef)values, "no_options", false))
            setsockopt(handle, IPPROTO_TCP, TCP_NOOPT, &on, sizeof on);
        if (revenant_nw_flag((__bridge CFDictionaryRef)values, "no_push", false))
            setsockopt(handle, IPPROTO_TCP, TCP_NOPUSH, &on, sizeof on);
        if (revenant_nw_flag((__bridge CFDictionaryRef)values, "enable_keepalive", false)) {
            setsockopt(handle, SOL_SOCKET, SO_KEEPALIVE, &on, sizeof on);
            int count = (int)revenant_nw_integer((__bridge CFDictionaryRef)values, "keepalive_count", 0);
            if (count > 0)
                setsockopt(handle, IPPROTO_TCP, TCP_KEEPCNT, &count, sizeof count);
            int idle = (int)revenant_nw_integer((__bridge CFDictionaryRef)values, "keepalive_idle_time", 0);
            if (idle > 0)
                setsockopt(handle, IPPROTO_TCP, TCP_KEEPALIVE, &idle, sizeof idle);
            int interval = (int)revenant_nw_integer((__bridge CFDictionaryRef)values, "keepalive_interval", 0);
            if (interval > 0)
                setsockopt(handle, IPPROTO_TCP, TCP_KEEPINTVL, &interval, sizeof interval);
        }
    }
    RevenantNWProtocolOptions *ip = stack->_internet;
    NSDictionary *values = ip ? ip->_values : nil;
    int on = 1;
    if (revenant_nw_flag((__bridge CFDictionaryRef)values, "disable_multicast_loopback", false))
        setsockopt(handle, IPPROTO_IP, IP_MULTICAST_LOOP, &on, sizeof on);
    if (revenant_nw_flag((__bridge CFDictionaryRef)values, "disable_fragmentation", false))
        setsockopt(handle, IPPROTO_IP, IP_DONTFRAG, &on, sizeof on);
    if (revenant_nw_flag((__bridge CFDictionaryRef)values, "use_minimum_mtu", false))
        setsockopt(handle, IPPROTO_IP, IP_DONTFRAG, &on, sizeof on);
    if (revenant_nw_flag((__bridge CFDictionaryRef)values, "no_delay", false)) {
    }
    RevenantNWEndpointValue *local = parameters->_localEndpoint;
    if (local && local->_address.length) {
        struct sockaddr_storage address;
        memset(&address, 0, sizeof address);
        memcpy(&address, local->_address.bytes, MIN(local->_address.length, sizeof address));
        bind(handle, (const struct sockaddr *)&address, (socklen_t)local->_address.length);
    } else if (local && local->_port.length) {
        uint16_t port = (uint16_t)atoi(local->_port.UTF8String);
        if (port) {
            if (connection->_isDatagram) {
                struct sockaddr_in address;
                memset(&address, 0, sizeof address);
                address.sin_len = sizeof address;
                address.sin_family = AF_INET;
                address.sin_port = htons(port);
                address.sin_addr.s_addr = htonl(INADDR_ANY);
                bind(handle, (const struct sockaddr *)&address, sizeof address);
            } else {
                struct sockaddr_in address;
                memset(&address, 0, sizeof address);
                address.sin_len = sizeof address;
                address.sin_family = AF_INET;
                address.sin_port = htons(port);
                address.sin_addr.s_addr = htonl(INADDR_ANY);
                setsockopt(handle, SOL_SOCKET, SO_REUSEADDR, &on, sizeof on);
                bind(handle, (const struct sockaddr *)&address, sizeof address);
            }
        }
    }
    if (parameters->_reuseLocalAddress) {
        int reuse = 1;
        setsockopt(handle, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof reuse);
    }
}

#pragma mark - the bytes

static void revenant_received(RevenantNWConnection *connection, NSData *bytes)
{
    connection->_receivedBytes += bytes.length;
    if (connection->_framer) {
        [connection->_framer->_input appendData:bytes];
        if (connection->_framer->_inputHandler)
            connection->_framer->_inputHandler((nw_framer_t)connection->_framer);
        revenant_deliver_received(connection);
        return;
    }
    [connection->_pendingRead appendData:bytes];
    revenant_deliver_received(connection);
}

static NSData *revenant_framer_message(RevenantNWConnection *connection, BOOL *isComplete)
{
    RevenantNWFramer *framer = connection->_framer;
    while (framer->_delivered.count) {
        NSArray *entry = framer->_delivered.firstObject;
        [framer->_delivered removeObjectAtIndex:0];
        NSData *bytes = entry[0];
        id message = entry[1];
        id complete = entry[2];
        if (isComplete)
            *isComplete = [complete boolValue];
        if ([message isKindOfClass:[RevenantNWProtocolMetadata class]])
            connection->_lastFramerMessage = message;
        return bytes;
    }
    return nil;
}

static void revenant_deliver_received(RevenantNWConnection *connection)
{
    if (getenv("REVENANT_TRACE_FD"))
        fprintf(stderr, "[revenant] drain: enter connection=%p state=%d receives=%lu pendingRead=%lu framer=%d\n",
                (__bridge void *)connection, connection->_value, (unsigned long)connection->_receives.count,
                (unsigned long)connection->_pendingRead.length, connection->_framer ? 1 : 0);
    for (RevenantNWReceive *receive in [connection->_receives copy]) {
        NSData *message = nil;
        BOOL isComplete = NO;
        if (connection->_framer && connection->_framer->_delivered.count)
            message = revenant_framer_message(connection, &isComplete);
        if (!message)
            break;
        if (message.length < receive->_minimum) {
            [connection->_pendingRead appendData:message];
            continue;
        }
        if (receive->_maximum && message.length > receive->_maximum) {
            [connection->_pendingRead appendData:message];
            continue;
        }
        nw_content_context_t context = nw_content_context_create("received");
        if (context) {
            nw_content_context_set_is_final(context, isComplete);
            if (connection->_lastFramerMessage) {
                nw_content_context_set_metadata_for_protocol(context, (nw_protocol_metadata_t)connection->_lastFramerMessage);
                connection->_lastFramerMessage = nil;
            }
        }
        dispatch_data_t payload = dispatch_data_create((const void *)message.bytes, message.length, connection->_queue,
                                                       DISPATCH_DATA_DESTRUCTOR_DEFAULT);
        [connection->_receives removeObject:receive];
        if (receive->_completion)
            receive->_completion(payload, context, isComplete, NULL);
        break;
    }
    if (connection->_pendingRead.length && !connection->_framer) {
        for (RevenantNWReceive *receive in [connection->_receives copy]) {
            NSUInteger take = connection->_pendingRead.length;
            if (receive->_maximum && take > receive->_maximum)
                take = receive->_maximum;
            if (getenv("REVENANT_TRACE_FD"))
                fprintf(stderr, "[revenant] drain: stream take=%lu min=%u max=%u\n", (unsigned long)take,
                        receive->_minimum, receive->_maximum);
            if (take < receive->_minimum)
                break;
            NSData *message = [connection->_pendingRead subdataWithRange:NSMakeRange(0, take)];
            [connection->_pendingRead replaceBytesInRange:NSMakeRange(0, take) withBytes:NULL length:0];
            BOOL more = connection->_pendingRead.length > 0;
            nw_content_context_t context = nw_content_context_create("received");
            if (context)
                nw_content_context_set_is_final(context, !more);
            dispatch_data_t payload = dispatch_data_create((const void *)message.bytes, message.length, connection->_queue,
                                                           DISPATCH_DATA_DESTRUCTOR_DEFAULT);
            [connection->_receives removeObject:receive];
            if (receive->_completion)
                receive->_completion(payload, context, !more, NULL);
            break;
        }
    }
}

static void revenant_dump(RevenantNWConnection *connection, const char *where)
{
    if (!getenv("REVENANT_TRACE_CONNECTION"))
        return;
    uintptr_t read_data = connection->_readSource ? dispatch_source_get_data(connection->_readSource) : 0;
    fprintf(stderr, "[revenant] %s fd=%d state=%d queue=%p readSource=%p over=%d writeSource=%p over=%d writing=%d "
                    "started=%d cancelled=%d datagram=%d secure=%d sends=%lu receives=%lu\n",
            where, connection->_socket, connection->_value, (__bridge void *)connection->_queue,
            (__bridge void *)connection->_readSource, (int)read_data, (__bridge void *)connection->_writeSource,
            connection->_writeSource ? (int)dispatch_source_get_data(connection->_writeSource) : 0,
            connection->_readingSource, connection->_started, connection->_cancelled, connection->_isDatagram,
            connection->_secure, (unsigned long)connection->_sends.count, (unsigned long)connection->_receives.count);
}

static void revenant_flush(RevenantNWConnection *connection)
{
    revenant_dump(connection, "flush");
    while (connection->_pendingWrite.length) {
        size_t length = connection->_pendingWrite.length;
        ssize_t put = write(connection->_socket, connection->_pendingWrite.bytes, length);
        if (put > 0)
            length = (size_t)put;
        else if (put < 0 && (errno == EAGAIN || errno == EWOULDBLOCK))
            break;
        else {
            revenant_report_state(connection, nw_connection_state_failed, revenant_posix_error());
            return;
        }
        [connection->_pendingWrite replaceBytesInRange:NSMakeRange(0, length) withBytes:NULL length:0];
    }
    while (connection->_sends.count && !connection->_pendingWrite.length) {
        RevenantNWSend *send = connection->_sends.firstObject;
        NSData *content = send->_content;
        size_t length = content.length;
        nw_connection_send_completion_t completion = send->_completion;
        [connection->_sends removeObjectAtIndex:0];
        if (connection->_ssl) {
            size_t written = 0;
            OSStatus status = RevenantTLSEngineWrite(connection->_ssl, content.bytes, length, &written);
            length = written;
            if (status == errSSLWouldBlock) {
                [connection->_sends insertObject:send atIndex:0];
                break;
            }
            if (status != noErr) {
                if (completion)
                    completion(revenant_error(nw_error_domain_tls, (int)status));
                revenant_report_state(connection, nw_connection_state_failed, revenant_error(nw_error_domain_tls, (int)status));
                return;
            }
        } else {
            ssize_t put = write(connection->_socket, content.bytes, length);
            if (put > 0)
                length = (size_t)put;
            else if (put < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
                [connection->_pendingWrite appendData:content];
                [connection->_sends insertObject:send atIndex:0];
                break;
            } else {
                if (completion)
                    completion(revenant_posix_error());
                revenant_report_state(connection, nw_connection_state_failed, revenant_posix_error());
                return;
            }
        }
        connection->_sentBytes += length;
        if (completion)
            completion(NULL);
    }
    if (connection->_writeSource && !connection->_connecting) {
        if (connection->_pendingWrite.length || connection->_sends.count) {
            if (!connection->_readingSource) {
                dispatch_resume(connection->_writeSource);
                connection->_readingSource = YES;
            }
        } else if (connection->_readingSource) {
            dispatch_suspend(connection->_writeSource);
            connection->_readingSource = NO;
        }
    }
}

static void revenant_tls_pump(RevenantNWConnection *connection)
{
    uint8_t buffer[16384];
    for (;;) {
        size_t length = 0;
        OSStatus status = RevenantTLSEngineRead(connection->_ssl, buffer, sizeof buffer, &length);
        if (status == errSSLWouldBlock)
            return;
        if (status == errSSLClosedGraceful || status == errSSLClosedNoNotify) {
            connection->_finished = YES;
            revenant_deliver_received(connection);
            revenant_report_state(connection, nw_connection_state_cancelled, nil);
            return;
        }
        if (status != noErr) {
            connection->_finished = YES;
            revenant_report_state(connection, nw_connection_state_failed, revenant_error(nw_error_domain_tls, (int)status));
            return;
        }
        revenant_received(connection, [NSData dataWithBytes:buffer length:length]);
    }
}

static void revenant_readable(RevenantNWConnection *connection)
{
    if (getenv("REVENANT_TRACE_FD"))
        fprintf(stderr, "[revenant] readable: fd=%d\n", connection->_socket);
    revenant_dump(connection, "read");
    uint8_t buffer[16384];
    while (YES) {
        ssize_t got = read(connection->_socket, buffer, sizeof buffer);
        if (getenv("REVENANT_TRACE_FD"))
            fprintf(stderr, "[revenant] read: fd=%d connection=%p state=%d got=%zd errno=%d receives=%lu pendingRead=%lu\n",
                    connection->_socket, (__bridge void *)connection, connection->_value, got, got < 0 ? errno : 0,
                    (unsigned long)connection->_receives.count, (unsigned long)connection->_pendingRead.length);
        if (got > 0) {
            revenant_received(connection, [NSData dataWithBytes:buffer length:(NSUInteger)got]);
            if (connection->_cancelled || connection->_finished)
                return;
            if ((NSUInteger)got < sizeof buffer)
                return;
            continue;
        }
        if (got == 0) {
            connection->_finished = YES;
            revenant_deliver_received(connection);
            revenant_report_state(connection, nw_connection_state_cancelled, nil);
            return;
        }
        if (errno == EAGAIN || errno == EWOULDBLOCK)
            return;
        if (errno == EINTR)
            continue;
        revenant_report_state(connection, nw_connection_state_failed, revenant_posix_error());
        return;
    }
}

static void revenant_tls_publish_metadata(RevenantNWConnection *connection)
{
    if (!connection->_secureMetadata)
        return;
    RevenantSecProtocolMetadata *metadata = (RevenantSecProtocolMetadata *)nw_tls_copy_sec_protocol_metadata((nw_protocol_metadata_t)connection->_secureMetadata);
    if (!metadata)
        return;
    metadata.negotiatedVersion = RevenantTLSEngineNegotiatedVersion(connection->_ssl);
    metadata.negotiatedCipherSuite = RevenantTLSEngineNegotiatedCipherSuite(connection->_ssl);
    size_t length = 0;
    const uint8_t *protocol = RevenantTLSEngineNegotiatedProtocol(connection->_ssl, &length);
    metadata.negotiatedProtocol = protocol ? [[NSString alloc] initWithBytes:protocol length:length encoding:NSUTF8StringEncoding] : nil;
    const uint8_t *ocsp = RevenantTLSEngineOCSPResponse(connection->_ssl, &length);
    metadata.ocspResponse = ocsp ? [NSData dataWithBytes:ocsp length:length] : nil;
}

static void revenant_handshake(RevenantNWConnection *connection)
{
    OSStatus status = RevenantTLSEngineHandshake(connection->_ssl);
    if (status == noErr) {
        connection->_handshaking = NO;
        revenant_tls_publish_metadata(connection);
        revenant_report_state(connection, nw_connection_state_ready, nil);
        return;
    }
    if (status == errSSLWouldBlock)
        return;
    revenant_report_state(connection, nw_connection_state_failed, revenant_error(nw_error_domain_tls, (int)status));
}

#pragma mark - opening and closing

static void revenant_watch_path(RevenantNWConnection *connection)
{
    if (connection->_monitor)
        return;
    nw_path_monitor_t monitor = nw_path_monitor_create();
    if (!monitor)
        return;
    connection->_monitor = monitor;
    nw_path_monitor_set_queue(monitor, connection->_queue);
    __weak RevenantNWConnection *weak = connection;
    nw_path_monitor_set_update_handler(monitor, ^(nw_path_t path) {
        RevenantNWConnection *self = weak;
        if (!self || self->_cancelled)
            return;
        self->_currentPath = path;
        BOOL satisfied = nw_path_get_status(path) == nw_path_status_satisfied;
        if (self->_path)
            self->_path(path);
        if (!self->_viableKnown || self->_viable != satisfied) {
            self->_viable = satisfied;
            self->_viableKnown = YES;
            if (self->_viability)
                self->_viability(satisfied);
        }
    });
    nw_path_monitor_start(monitor);
}

static void revenant_make_framer(RevenantNWConnection *connection)
{
    RevenantNWProtocolOptions *options = revenant_stack_framer(connection->_parameters);
    if (!options)
        return;
    RevenantNWFramer *framer = [[RevenantNWFramer alloc] init];
    framer->_definition = options->_definition;
    framer->_options = options;
    framer->_parameters = connection->_parameters;
    framer->_localEndpoint = connection->_parameters->_localEndpoint;
    framer->_remoteEndpoint = connection->_endpoint;
    framer->_queue = connection->_queue;
    framer->_input = [NSMutableData data];
    framer->_output = [NSMutableData data];
    framer->_delivered = [NSMutableArray array];
    framer->_pendingWakeups = [NSMutableArray array];
    connection->_framer = framer;
}

static void revenant_install_sources(RevenantNWConnection *connection)
{
    if (connection->_readSource || connection->_writeSource)
        return;
    if (getenv("REVENANT_TRACE_FD"))
        fprintf(stderr, "[revenant] sources: fd=%d connecting=%d queue=%p\n", connection->_socket,
                connection->_connecting, (__bridge void *)connection->_queue);
    connection->_readSource = connection->_connecting ? NULL : revenant_nw_read_source(connection->_socket, connection->_queue);
    if (connection->_readSource) {
        __weak RevenantNWConnection *weak = connection;
        dispatch_source_set_event_handler(connection->_readSource, ^{
            RevenantNWConnection *self = weak;
            if (!self || self->_cancelled)
                return;
            if (self->_ssl && self->_handshaking) {
                revenant_handshake(self);
                return;
            }
            if (self->_ssl) {
                revenant_tls_pump(self);
                return;
            }
            revenant_readable(self);
            if (!self->_cancelled)
                revenant_flush(self);
        });
    }
    connection->_writeSource = revenant_nw_write_source(connection->_socket, connection->_queue);
    if (connection->_writeSource) {
        __weak RevenantNWConnection *weak = connection;
        dispatch_source_set_event_handler(connection->_writeSource, ^{
            RevenantNWConnection *self = weak;
            if (!self || self->_cancelled)
                return;
            if (self->_connecting) {
                revenant_connect_finished(self);
                return;
            }
            revenant_flush(self);
        });
        if (connection->_connecting) {
            dispatch_resume(connection->_writeSource);
            connection->_readingSource = YES;
            return;
        }
    }
    revenant_flush(connection);
}

static void revenant_connect_finished(RevenantNWConnection *connection)
{
    if (connection->_readSource)
        return;
    int failure = 0;
    socklen_t length = sizeof failure;
    if (getsockopt(connection->_socket, SOL_SOCKET, SO_ERROR, &failure, &length) != 0)
        failure = errno;
    connection->_connecting = NO;
    if (connection->_writeSource && connection->_readingSource) {
        dispatch_suspend(connection->_writeSource);
        connection->_readingSource = NO;
    }
    if (failure) {
        revenant_stop(connection, nw_connection_state_failed, revenant_error(nw_error_domain_posix, failure));
        return;
    }
    revenant_ready(connection);
}

void RevenantNWConnectionAttach(nw_connection_t value, int handle, BOOL connected)
{
    if (getenv("REVENANT_TRACE_CONNECTION")) {
        RevenantNWConnection *attached = (RevenantNWConnection *)value;
        unsigned peer_port = 0;
        struct sockaddr_storage peer;
        socklen_t peer_length = sizeof peer;
        memset(&peer, 0, sizeof peer);
        if (getpeername(handle, (struct sockaddr *)&peer, &peer_length) == 0)
            peer_port = revenant_nw_sockaddr_port((const struct sockaddr *)&peer);
        fprintf(stderr, "[%8llu] port: attached fd=%d peerPort=%u connected=%d queue=%p datagram=%d secure=%d\n",
                (unsigned long long)(mach_absolute_time() / 1000000), handle, peer_port, connected,
                attached ? (__bridge void *)attached->_queue : NULL, attached ? attached->_isDatagram : 0,
                attached ? attached->_secure : 0);
    }
    RevenantNWConnection *connection = (RevenantNWConnection *)value;
    (void)connected;
    if (!connection || handle < 0)
        return;
    @synchronized(connection) {
        if (connection->_cancelled)
            return;
        connection->_socket = handle;
        connection->_acceptedSocket = handle;
        connection->_currentEndpoint = connection->_endpoint;
        assert(connection->_socket == handle);
    }
    revenant_nw_set_nonblocking(handle);
    RevenantNWParameters *parameters = connection->_parameters;
    connection->_isDatagram = revenant_is_datagram(parameters);
    connection->_secure = revenant_is_secure(parameters);
}

int revenant_nw_connection_socket(nw_connection_t value)
{
    return ((RevenantNWConnection *)value)->_socket;
}

BOOL RevenantNWConnectionHasQueue(nw_connection_t value)
{
    return ((RevenantNWConnection *)value)->_queue != NULL;
}

BOOL RevenantNWConnectionTakeSocket(nw_connection_t value, int *out_handle, void *out_endpoint, void *out_parameters)
{
    RevenantNWConnection *connection = (RevenantNWConnection *)value;
    if (!connection)
        return NO;
    @synchronized(connection) {
        if (connection->_socket < 0)
            return NO;
        if (out_handle)
            *out_handle = connection->_socket;
        if (out_endpoint)
            *(RevenantNWEndpointValue * _Nonnull __unsafe_unretained *)out_endpoint = connection->_currentEndpoint;
        if (out_parameters)
            *(nw_parameters_t __unsafe_unretained *)out_parameters = connection->_parameters;
        connection->_socket = -1;
    }
    return YES;
}

static void revenant_ready(RevenantNWConnection *connection)
{
    if (connection->_cancelled)
        return;
    revenant_report_state(connection, nw_connection_state_preparing, nil);
    revenant_watch_path(connection);
    RevenantNWProtocolMetadata *ip = [[RevenantNWProtocolMetadata alloc] init];
    ip->_definition = (RevenantNWProtocolDefinition *)nw_protocol_copy_ip_definition();
    ip->_values = [NSMutableDictionary dictionary];
    ip->_objects = [NSMutableDictionary dictionary];
    revenant_nw_set_integer((__bridge CFMutableDictionaryRef)ip->_values, "service_class", connection->_parameters->_serviceClass);
    connection->_ipMetadata = ip;

    if (!connection->_isDatagram) {
        RevenantNWProtocolMetadata *tcp = [[RevenantNWProtocolMetadata alloc] init];
        tcp->_definition = (RevenantNWProtocolDefinition *)nw_protocol_copy_tcp_definition();
        tcp->_values = [NSMutableDictionary dictionary];
        tcp->_objects = [NSMutableDictionary dictionary];
        revenant_nw_set_integer((__bridge CFMutableDictionaryRef)tcp->_values, "available_send_buffer",
                              revenant_nw_available_send_buffer(connection->_socket));
        revenant_nw_set_integer((__bridge CFMutableDictionaryRef)tcp->_values, "available_receive_buffer",
                              revenant_nw_available_receive_buffer(connection->_socket));
        connection->_transportMetadata = tcp;
    } else {
        RevenantNWProtocolMetadata *udp = [[RevenantNWProtocolMetadata alloc] init];
        udp->_definition = (RevenantNWProtocolDefinition *)nw_protocol_copy_udp_definition();
        udp->_values = [NSMutableDictionary dictionary];
        udp->_objects = [NSMutableDictionary dictionary];
        connection->_transportMetadata = udp;
    }

    revenant_make_framer(connection);
    revenant_install_sources(connection);

    if (connection->_secure) {
        RevenantNWProtocolMetadata *tls = [[RevenantNWProtocolMetadata alloc] init];
        tls->_definition = (RevenantNWProtocolDefinition *)nw_protocol_copy_tls_definition();
        tls->_values = [NSMutableDictionary dictionary];
        tls->_objects = [NSMutableDictionary dictionary];
        connection->_secureMetadata = tls;
        RevenantSecProtocolOptions *secOptions = revenant_tls_options(connection->_parameters) ?: [[RevenantSecProtocolOptions alloc] init];
        NSString *hostname = connection->_endpoint->_hostname.length ? connection->_endpoint->_hostname : nil;
        char reason[512] = "";
        OSStatus status = noErr;
        connection->_ssl = RevenantTLSEngineCreate((__bridge const void *)secOptions, connection->_socket, hostname.UTF8String, false,
                                                   reason, sizeof reason, &status);
        if (!connection->_ssl) {
            fprintf(stderr, "Network: TLS setting refused: %s\n", reason);
            revenant_report_state(connection, nw_connection_state_failed, revenant_error(nw_error_domain_tls, (int)status));
            return;
        }
        connection->_handshaking = YES;
        revenant_handshake(connection);
        if (connection->_handshaking)
            return;
        if (connection->_cancelled)
            return;
    }
    revenant_report_state(connection, nw_connection_state_ready, nil);
}

static BOOL revenant_take_connected_socket(RevenantNWConnection *connection, int handle, RevenantNWEndpointValue *endpoint)
{
    @synchronized(connection) {
        if (connection->_cancelled)
            return NO;
        connection->_socket = handle;
        connection->_currentEndpoint = endpoint;
        revenant_nw_set_nonblocking(handle);
        return YES;
    }
}

static RevenantSecProtocolOptions *revenant_tls_options(RevenantNWParameters *parameters)
{
    RevenantNWProtocolOptions *tls = revenant_stack_application(parameters, @"nw_tls");
    return tls ? tls->_objects[@"sec_protocol_options"] : nil;
}

static void revenant_open(RevenantNWConnection *connection)
{
    RevenantNWConnection *self = connection;
    RevenantNWEndpointValue *endpoint = connection->_endpoint;
    RevenantNWParameters *parameters = connection->_parameters;
    connection->_isDatagram = revenant_is_datagram(parameters);
    connection->_secure = revenant_is_secure(parameters);

    struct addrinfo hints;
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = connection->_isDatagram ? SOCK_DGRAM : SOCK_STREAM;
    hints.ai_protocol = connection->_isDatagram ? IPPROTO_UDP : IPPROTO_TCP;
    const char *host = endpoint->_hostname.UTF8String;
    const char *service = endpoint->_port.length ? endpoint->_port.UTF8String : NULL;

    int last = ECONNREFUSED;
    if (host) {
        struct addrinfo *list = NULL;
        int failure = getaddrinfo(host, service, &hints, &list);
        if (failure != 0 || !list) {
            last = failure ? failure : EAI_NONAME;
            dispatch_async(connection->_queue, ^{
                revenant_report_state(connection, nw_connection_state_failed, revenant_error(nw_error_domain_dns, failure));
            });
            return;
        }
        for (struct addrinfo *entry = list; entry; entry = entry->ai_next) {
            int handle = revenant_nw_blocking_socket(entry->ai_family, entry->ai_socktype, entry->ai_protocol);
            if (handle < 0) {
                last = errno;
                continue;
            }
            connection->_socket = handle;
            revenant_apply_options(connection);
            if (connect(handle, entry->ai_addr, entry->ai_addrlen) == 0) {
                freeaddrinfo(list);
                if (!revenant_take_connected_socket(self, handle, endpoint)) {
                    close(handle);
                    return;
                }
                dispatch_async(connection->_queue, ^{
                    revenant_install_sources(self);
                    revenant_ready(self);
                });
                return;
            }
            last = errno;
            close(handle);
            connection->_socket = -1;
        }
        freeaddrinfo(list);
    } else if (endpoint->_address.length) {
        struct sockaddr_storage address;
        memset(&address, 0, sizeof address);
        memcpy(&address, endpoint->_address.bytes, MIN(endpoint->_address.length, sizeof address));
        int family = address.ss_family;
        int type = connection->_isDatagram ? SOCK_DGRAM : SOCK_STREAM;
        int protocol = connection->_isDatagram ? IPPROTO_UDP : IPPROTO_TCP;
        int handle = revenant_nw_blocking_socket(family, type, protocol);
        if (handle < 0) {
            revenant_report_state(connection, nw_connection_state_failed, revenant_posix_error());
            return;
        }
        connection->_socket = handle;
        revenant_apply_options(connection);
        if (connect(handle, (struct sockaddr *)&address, (socklen_t)endpoint->_address.length) != 0) {
            last = errno;
            close(handle);
            connection->_socket = -1;
        } else {
            if (!revenant_take_connected_socket(self, handle, endpoint)) {
                close(handle);
                return;
            }
            dispatch_async(connection->_queue, ^{
                revenant_install_sources(self);
                revenant_ready(self);
            });
            return;
        }
    } else {
        revenant_report_state(connection, nw_connection_state_failed, revenant_error(nw_error_domain_dns, EAI_NONAME));
        return;
    }
    dispatch_async(connection->_queue, ^{
        revenant_report_state(connection, nw_connection_state_failed, revenant_error(nw_error_domain_posix, last));
    });
}

static void revenant_stop(RevenantNWConnection *connection, nw_connection_state_t state, RevenantNWError *error)
{
    @synchronized(connection) {
        if (connection->_cancelled && state != nw_connection_state_cancelled)
            return;
        connection->_cancelled = state == nw_connection_state_cancelled;
    }
    if (connection->_readSource) {
        dispatch_source_cancel(connection->_readSource);
        connection->_readSource = nil;
        connection->_socket = -1;
    }
    if (connection->_writeSource) {
        if (connection->_readingSource)
            dispatch_resume(connection->_writeSource);
        dispatch_source_cancel(connection->_writeSource);
        connection->_writeSource = nil;
        connection->_readingSource = NO;
    }
    if (connection->_ssl) {
        RevenantTLSEngineClose(connection->_ssl);
        RevenantTLSEngineFree(connection->_ssl);
        connection->_ssl = NULL;
    }
    if (connection->_socket >= 0) {
        close(connection->_socket);
        connection->_socket = -1;
    }
    if (connection->_monitor) {
        nw_path_monitor_cancel(connection->_monitor);
        connection->_monitor = nil;
    }
    connection->_path = nil;
    connection->_viability = nil;
    connection->_betterPath = nil;
    connection->_state = nil;

    for (RevenantNWReceive *receive in [connection->_receives copy]) {
        [connection->_receives removeObject:receive];
        if (receive->_completion)
            receive->_completion(NULL, NULL, true, error);
    }
    for (RevenantNWSend *send in [connection->_sends copy]) {
        [connection->_sends removeObject:send];
        if (send->_completion)
            send->_completion(error);
    }
    revenant_report_state(connection, state, error);
}

#pragma mark - the calls

nw_connection_t nw_connection_create(nw_endpoint_t endpoint, nw_parameters_t parameters)
{
    if (!endpoint || !parameters)
        return nil;
    RevenantNWConnection *connection = [[RevenantNWConnection alloc] init];
    connection->_endpoint = (RevenantNWEndpointValue *)endpoint;
    connection->_parameters = (RevenantNWParameters *)parameters;
    connection->_socket = -1;
    connection->_acceptedSocket = -1;
    connection->_connectQueue = dispatch_queue_create("revenant.connect", DISPATCH_QUEUE_SERIAL);
    connection->_sends = [NSMutableArray array];
    connection->_receives = [NSMutableArray array];
    connection->_pendingWrite = [NSMutableData data];
    connection->_pendingRead = [NSMutableData data];
    connection->_value = nw_connection_state_setup;
    return connection;
}

nw_endpoint_t nw_connection_copy_endpoint(nw_connection_t connection)
{
    return connection ? ((RevenantNWConnection *)connection)->_endpoint : NULL;
}

nw_parameters_t nw_connection_copy_parameters(nw_connection_t connection)
{
    return connection ? ((RevenantNWConnection *)connection)->_parameters : NULL;
}

void nw_connection_set_queue(nw_connection_t connection, dispatch_queue_t queue)
{
    if (connection)
        ((RevenantNWConnection *)connection)->_queue = queue;
}

void nw_connection_set_path_changed_handler(nw_connection_t connection, nw_connection_path_event_handler_t handler)
{
    if (connection)
        ((RevenantNWConnection *)connection)->_path = [handler copy];
}

void nw_connection_set_viability_changed_handler(nw_connection_t connection, nw_connection_boolean_event_handler_t handler)
{
    if (connection)
        ((RevenantNWConnection *)connection)->_viability = [handler copy];
}

void nw_connection_set_better_path_available_handler(nw_connection_t connection, nw_connection_boolean_event_handler_t handler)
{
    if (connection)
        ((RevenantNWConnection *)connection)->_betterPath = [handler copy];
}

void nw_connection_set_state_changed_handler(nw_connection_t connection, nw_connection_state_changed_handler_t handler)
{
    if (connection)
        ((RevenantNWConnection *)connection)->_state = [handler copy];
}

void nw_connection_start(nw_connection_t connection)
{
    if (!connection)
        return;
    RevenantNWConnection *self = (RevenantNWConnection *)connection;
    @synchronized(self) {
        if (self->_started || self->_cancelled || !self->_queue)
            return;
        self->_started = YES;
    }
    dispatch_async(self->_queue, ^{
        if (self->_cancelled)
            return;
        self->_startedAtMilliseconds = revenant_nw_uptime_milliseconds();
        revenant_report_state(self, nw_connection_state_waiting, nil);
        if (self->_acceptedSocket >= 0) {
            @synchronized(self) {
                assert(self->_socket == self->_acceptedSocket);
            }
            revenant_install_sources(self);
            revenant_ready(self);
            return;
        }
        dispatch_async(self->_connectQueue, ^{
            revenant_open(self);
        });
    });
}

void nw_connection_cancel(nw_connection_t connection)
{
    if (!connection)
        return;
    RevenantNWConnection *self = (RevenantNWConnection *)connection;
    dispatch_block_t stop = ^{
        revenant_stop(self, nw_connection_state_cancelled, nil);
    };
    if (self->_queue)
        dispatch_async(self->_queue, stop);
    else
        stop();
}

void nw_connection_force_cancel(nw_connection_t connection)
{
    if (!connection)
        return;
    RevenantNWConnection *self = (RevenantNWConnection *)connection;
    revenant_stop(self, nw_connection_state_cancelled, nil);
}

void nw_connection_restart(nw_connection_t connection)
{
    if (!connection)
        return;
    RevenantNWConnection *self = (RevenantNWConnection *)connection;
    dispatch_async(self->_queue ?: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self->_cancelled)
            return;
        self->_attempts++;
        self->_finished = NO;
        if (self->_socket >= 0)
            close(self->_socket);
        self->_socket = -1;
        revenant_report_state(self, nw_connection_state_waiting, nil);
        revenant_open(self);
    });
}

void nw_connection_cancel_current_endpoint(nw_connection_t connection)
{
    if (!connection)
        return;
    RevenantNWConnection *self = (RevenantNWConnection *)connection;
    self->_currentEndpoint = nil;
    dispatch_async(self->_queue ?: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self->_cancelled)
            return;
        if (self->_socket >= 0) {
            close(self->_socket);
            self->_socket = -1;
        }
        self->_attempts++;
        revenant_report_state(self, nw_connection_state_waiting, nil);
        revenant_open(self);
    });
}

void nw_connection_batch(nw_connection_t connection, dispatch_block_t batch_block)
{
    if (!connection)
        return;
    RevenantNWConnection *self = (RevenantNWConnection *)connection;
    if (!batch_block)
        return;
    dispatch_async(self->_queue ?: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @synchronized(self) {
            batch_block();
        }
    });
}

nw_path_t nw_connection_copy_current_path(nw_connection_t connection)
{
    RevenantNWConnection *value = (RevenantNWConnection *)connection;
    return value ? value->_currentPath : NULL;
}

uint32_t nw_connection_get_maximum_datagram_size(nw_connection_t connection)
{
    RevenantNWConnection *self = (RevenantNWConnection *)connection;
    if (!self || self->_socket < 0)
        return 0;
    struct sockaddr_storage local;
    memset(&local, 0, sizeof local);
    socklen_t length = sizeof local;
    if (getsockname(self->_socket, (struct sockaddr *)&local, &length) != 0)
        return 0;
    struct ifaddrs *list = NULL;
    if (getifaddrs(&list) != 0 || !list)
        return 0;
    const void *wanted = local.ss_family == AF_INET ? (const void *)&((struct sockaddr_in *)&local)->sin_addr
                                                    : (const void *)&((struct sockaddr_in6 *)&local)->sin6_addr;
    size_t family = local.ss_family == AF_INET ? sizeof(struct in_addr) : sizeof(struct in6_addr);
    uint32_t mtu = 1500;
    for (struct ifaddrs *item = list; item; item = item->ifa_next) {
        if (!item->ifa_addr)
            continue;
        BOOL matches = NO;
        if (item->ifa_addr->sa_family == AF_INET)
            matches = !memcmp(&((struct sockaddr_in *)item->ifa_addr)->sin_addr, wanted, family);
        else if (item->ifa_addr->sa_family == AF_INET6)
            matches = !memcmp(&((struct sockaddr_in6 *)item->ifa_addr)->sin6_addr, wanted, family);
        if (!matches)
            continue;
        int probe = revenant_nw_socket(AF_INET, SOCK_DGRAM, 0);
        if (probe >= 0) {
            struct ifreq request;
            memset(&request, 0, sizeof request);
            strncpy(request.ifr_name, item->ifa_name, IFNAMSIZ - 1);
            if (ioctl(probe, SIOCGIFMTU, &request) == 0 && request.ifr_mtu > 0)
                mtu = (uint32_t)request.ifr_mtu;
            close(probe);
        }
        break;
    }
    freeifaddrs(list);
    size_t overhead = self->_isDatagram ? 20u + 8u : 20u + 20u;
    return mtu > overhead ? mtu - (uint32_t)overhead : 0;
}

char *nw_connection_copy_description(nw_connection_t connection)
{
    RevenantNWConnection *self = (RevenantNWConnection *)connection;
    if (!self)
        return NULL;
    NSMutableString *text = [NSMutableString string];
    [text appendFormat:@"[C1 %@ ", self->_endpoint->_hostname.length ? self->_endpoint->_hostname : @"?"];
    if (self->_endpoint->_port.length)
        [text appendFormat:@":%@", self->_endpoint->_port];
    [text appendString:self->_isDatagram ? @" udp" : @" tcp"];
    if (self->_secure)
        [text appendString:@", tls"];
    if (self->_framer)
        [text appendFormat:@", %@", self->_framer->_definition->_family];
    [text appendFormat:@", attribution: %@", self->_parameters->_attribution == nw_parameters_attribution_user ? @"user" : @"developer"];
    if (self->_currentPath) {
        nw_path_status_t status = nw_path_get_status(self->_currentPath);
        [text appendFormat:@", path %@", status == nw_path_status_satisfied ? @"satisfied" :
                                      status == nw_path_status_satisfiable ? @"satisfiable" : @"unsatisfied"];
        __block NSString *interface = nil;
        nw_path_enumerate_interfaces(self->_currentPath, ^bool(nw_interface_t found) {
            interface = @(nw_interface_get_name(found) ?: "?");
            return false;
        });
        if (interface)
            [text appendFormat:@", interface: %@", interface];
    }
    if (self->_viableKnown)
        [text appendFormat:@", viable"];
    [text appendString:@"]"];
    return revenant_nw_copy_cstring(text.UTF8String);
}

void nw_connection_send(nw_connection_t connection, dispatch_data_t content, nw_content_context_t context,
                        bool is_complete, nw_connection_send_completion_t completion)
{
    if (!connection)
        return;
    RevenantNWConnection *self = (RevenantNWConnection *)connection;
    if (!self->_queue) {
        if (completion)
            completion(revenant_error(nw_error_domain_posix, EINVAL));
        return;
    }
    dispatch_async(self->_queue, ^{
        if (self->_cancelled || self->_value != nw_connection_state_ready) {
            if (completion)
                completion(revenant_error(nw_error_domain_posix, self->_cancelled ? ECANCELED : ENOTCONN));
            return;
        }
        RevenantNWSend *send = [[RevenantNWSend alloc] init];
        size_t length = content ? dispatch_data_get_size(content) : 0;
        NSMutableData *bytes = [NSMutableData dataWithLength:length];
        if (length) {
            __block size_t written = 0;
            dispatch_data_apply(content, ^bool(dispatch_data_t region, size_t offset, const void *buffer, size_t size) {
                memcpy((uint8_t *)bytes.mutableBytes + offset, buffer, size);
                written += size;
                return true;
            });
            (void)written;
        }
        send->_content = bytes;
        send->_context = context;
        send->_isComplete = is_complete;
        send->_completion = completion;
        [self->_sends addObject:send];
        revenant_flush(self);
    });
}

void nw_connection_receive(nw_connection_t connection, uint32_t minimum_incomplete_length, uint32_t maximum_length,
                           nw_connection_receive_completion_t completion)
{
    if (!connection)
        return;
    RevenantNWConnection *self = (RevenantNWConnection *)connection;
    if (!self->_queue) {
        if (completion)
            completion(NULL, NULL, true, NULL);
        return;
    }
    dispatch_async(self->_queue, ^{
        RevenantNWReceive *receive = [[RevenantNWReceive alloc] init];
        receive->_minimum = minimum_incomplete_length;
        receive->_maximum = maximum_length;
        receive->_completion = completion;
        [self->_receives addObject:receive];
        revenant_deliver_received(self);
    });
}

void nw_connection_receive_message(nw_connection_t connection, nw_connection_receive_completion_t completion)
{
    nw_connection_receive(connection, 1, 0, completion);
}

nw_protocol_metadata_t nw_connection_copy_protocol_metadata(nw_connection_t connection, nw_protocol_definition_t definition)
{
    RevenantNWConnection *self = (RevenantNWConnection *)connection;
    if (!self || !definition)
        return NULL;
    RevenantNWProtocolDefinition *wanted = (RevenantNWProtocolDefinition *)definition;
    if (self->_ipMetadata && [self->_ipMetadata->_definition->_family isEqualToString:wanted->_family])
        return self->_ipMetadata;
    if (self->_transportMetadata && [self->_transportMetadata->_definition->_family isEqualToString:wanted->_family])
        return self->_transportMetadata;
    if (self->_secureMetadata && [self->_secureMetadata->_definition->_family isEqualToString:wanted->_family])
        return self->_secureMetadata;
    return NULL;
}

nw_establishment_report_t RevenantNWConnectionEstablishmentReport(nw_connection_t connection)
{
    RevenantNWConnection *self = (RevenantNWConnection *)connection;
    if (!self)
        return NULL;
    RevenantNWEstablishmentReport *report = [[RevenantNWEstablishmentReport alloc] init];
    report->_protocols = [NSMutableArray array];
    report->_protocolHandshakeMilliseconds = [NSMutableArray array];
    report->_protocolHandshakeRTTMilliseconds = [NSMutableArray array];
    report->_resolutions = [NSMutableArray array];
    report->_resolutionReports = [NSMutableArray array];
    report->_durationMilliseconds = self->_startedAtMilliseconds
        ? revenant_nw_uptime_milliseconds() - self->_startedAtMilliseconds : 0;
    report->_previousAttemptCount = self->_attempts;
    [report->_protocols addObject:(RevenantNWProtocolDefinition *)nw_protocol_copy_udp_definition()];
    if (!self->_isDatagram)
        [report->_protocols addObject:(RevenantNWProtocolDefinition *)nw_protocol_copy_tcp_definition()];
    if (self->_secure)
        [report->_protocols addObject:(RevenantNWProtocolDefinition *)nw_protocol_copy_tls_definition()];
    [report->_protocols addObject:(RevenantNWProtocolDefinition *)nw_protocol_copy_ip_definition()];
    while (report->_protocolHandshakeMilliseconds.count < report->_protocols.count) {
        [report->_protocolHandshakeMilliseconds addObject:@(0)];
        [report->_protocolHandshakeRTTMilliseconds addObject:@(0)];
    }
    if (self->_currentEndpoint) {
        [report->_resolutions addObject:self->_currentEndpoint];
        RevenantNWResolutionReport *resolution = [[RevenantNWResolutionReport alloc] init];
        resolution->_endpoints = [NSMutableArray arrayWithObject:self->_currentEndpoint];
        resolution->_endpointCount = 1;
        resolution->_milliseconds = report->_durationMilliseconds;
        resolution->_protocol = self->_isDatagram ? nw_report_resolution_protocol_udp
            : (self->_secure ? nw_report_resolution_protocol_tls : nw_report_resolution_protocol_tcp);
        resolution->_source = nw_report_resolution_source_query;
        resolution->_successful = self->_currentEndpoint;
        resolution->_preferred = self->_currentEndpoint;
        [report->_resolutionReports addObject:resolution];
    }
    return report;
}

nw_data_transfer_report_t RevenantNWConnectionDataTransferReport(nw_connection_t connection)
{
    RevenantNWConnection *self = (RevenantNWConnection *)connection;
    if (!self)
        return NULL;
    RevenantNWDataTransferReport *report = [[RevenantNWDataTransferReport alloc] init];
    report->_sentApplicationBytes = self->_sentBytes;
    report->_receivedApplicationBytes = self->_receivedBytes;
    report->_sentTransportBytes = self->_sentBytes;
    report->_receivedTransportBytes = self->_receivedBytes;
    report->_durationMilliseconds = self->_startedAtMilliseconds
        ? revenant_nw_uptime_milliseconds() - self->_startedAtMilliseconds : 0;
    if (self->_socket >= 0 && !self->_isDatagram) {
        uint64_t smoothed = 0, minimum = 0, variance = 0;
        if (revenant_nw_tcp_round_trips(self->_socket, &smoothed, &minimum, &variance)) {
            report->_smoothedRTTMilliseconds = smoothed;
            report->_minimumRTTMilliseconds = minimum;
            report->_rttVarianceMilliseconds = variance;
        }
    }
    if (self->_currentPath) {
        __block nw_interface_t interface = NULL;
        nw_path_enumerate_interfaces(self->_currentPath, ^bool(nw_interface_t found) {
            interface = found;
            return false;
        });
        report->_interface = interface;
    }
    return report;
}
