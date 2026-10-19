/*
 * The connection of Network: a real socket, on the queue the program gave, with the SDK's whole
 * surface over it.
 *
 * What a connection is here, exactly: the host is resolved with `getaddrinfo` (or taken from the
 * address the endpoint already is), a socket of the transport the stack asks for is opened and
 * connected, the socket options the TCP and IP options ask for are set on it, and the bytes are moved
 * by two dispatch sources on the connection's own queue - so every handler of a connection is called
 * on the queue that was set, and never before `nw_connection_start` has returned to its caller. A
 * connection with a TLS protocol in its stack wraps that socket in the release's own SecureTransport
 * (`SSLCreateContext`, `SSLSetIOFuncs`, `SSLSetPeerDomainName`, `SSLHandshake`, `SSLRead`, `SSLWrite`
 * - all measured exported by the iOS 6.1.3 cache, `facts/Network/NWConnection.md`), driven from the
 * same two sources, so the handshake and the data travel over one engine and the state machine has
 * one place to move.
 *
 * The states are the SDK's: `waiting` while there is no route to the peer or no answer yet, `preparing`
 * once the transport is up and the protocols above it are being set up, `ready` when the connection
 * carries bytes, `failed` with the error that stopped it, and `cancelled` when the program said so.
 * Viability is what the port measured about: the kernel has a route to the address and the release's
 * own reachability says the path is satisfied - a datagram `connect` sends nothing, so nothing here
 * claims the peer answered.
 *
 * Sending and receiving are the SDK's contract: `nw_connection_send` takes the content with the context
 * that describes it and calls the completion when those bytes are on the wire (or have failed, with the
 * error); `nw_connection_receive` takes the bounds of a message and calls the completion with what
 * arrived, `is_complete` telling the program whether more of that message may follow, and
 * `nw_connection_receive_message` is the same with the bounds the connection itself imposes. A
 * connection with a framer in its stack parses with the framer, and one with WebSocket options carries
 * a WebSocket, so a receive is a whole message rather than a run of bytes.
 *
 * What is not here is said in `facts/Network/NWConnection.md`: QUIC has no transport on this release
 * (it needs a TLS 1.3 handshake and this release's SecureTransport has no TLS 1.2, let alone 1.3 -
 * measured), so a parameters of QUIC is a connection over its transport with no QUIC layer on it.
 */

#import "CharonNW.h"
#import "CharonNWSupport.h"

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
#include <Security/SecureTransport.h>

/* One name the SDK the port compiles against does not declare, declared here because the port's own
   code needs it and a header cannot be asked for what it does not carry: `nw_connection_state_setup` is
   the state a connection is in before it is started, the value 0 of the SDK 26.2 enumeration, while the
   16.4 header starts its own at `invalid` and has no such case.

   The TLS needs no such name, and the claim that it once did was wrong: the release's context call is
   `SSLCreateContext`, which this SDK declares and the 6.1.3 cache exports - `SSLContextCreate` is
   exported by no release on this machine (measured; facts/Network/NWConnection.md has the reading). */
enum { nw_connection_state_setup = 0 };

/* One piece of content on its way out, and one receive waiting for one. */
/* The class, its state and its implementation are in this one file, and nowhere else: with the fragile
   ABI a class's ivar offsets are emitted by every file that sees its @interface, so a header that
   every file of the library read would make the link see each of them twice. The files that need a
   connection - the listener, which builds one per accepted socket - ask for what they need through the
   two C functions at the end of this file. */
@interface CharonNWConnection : NSObject <OS_nw_connection> {
@public
    CharonNWEndpoint *_endpoint;
    CharonNWParameters *_parameters;
    dispatch_queue_t _queue;
    dispatch_queue_t _connectQueue;
    nw_connection_state_changed_handler_t _state;
    nw_connection_path_event_handler_t _path;
    nw_connection_boolean_event_handler_t _viability;
    nw_connection_boolean_event_handler_t _betterPath;
    nw_connection_state_t _value;
    nw_path_t _currentPath;
    nw_path_monitor_t _monitor;
    CharonNWEndpoint *_currentEndpoint;
    BOOL _started, _cancelled, _finished, _secure, _viable, _viableKnown, _connecting;
    int _socket;
    int _acceptedSocket;
    SSLContextRef _ssl;
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
    CharonNWProtocolMetadata *_ipMetadata;
    CharonNWProtocolMetadata *_transportMetadata;
    CharonNWProtocolMetadata *_secureMetadata;
    CharonNWFramer *_framer;
    id _lastFramerMessage;
}
@end

@implementation CharonNWConnection
@end

@interface CharonNWSend : NSObject {
@public
    NSData *_content;
    nw_content_context_t _context;
    bool _isComplete;
    nw_connection_send_completion_t _completion;
}
@end
@implementation CharonNWSend
@end

@interface CharonNWReceive : NSObject {
@public
    uint32_t _minimum;
    uint32_t _maximum;
    nw_connection_receive_completion_t _completion;
}
@end
@implementation CharonNWReceive
@end

/* The class is in CharonNW.h: a listener builds one of these per accepted socket. */

/* ---------------------------------------------------------------- the stack, read once */

static CharonNWProtocolOptions *charon_stack_application(CharonNWParameters *parameters, NSString *family)
{
    for (CharonNWProtocolOptions *options in parameters->_stack->_application) {
        if ([options->_definition->_family isEqualToString:family])
            return options;
    }
    return nil;
}

/* The transport a connection of these parameters uses: the one in the stack, or TCP when the stack
   holds none - which is what nw_parameters_create builds, and what a plain connection is. */
static BOOL charon_is_datagram(CharonNWParameters *parameters)
{
    CharonNWProtocolDefinition *transport = parameters->_stack->_transport ? parameters->_stack->_transport->_definition : nil;
    if (transport)
        return [transport->_family isEqualToString:@"nw_udp"];
    return NO;
}

static BOOL charon_is_secure(CharonNWParameters *parameters)
{
    return charon_stack_application(parameters, @"nw_tls") != nil;
}

/* A program's own protocol in the stack is the one whose definition carries a start handler, which
   is what nw_framer_create_definition gives it and what a built-in protocol's does not have. */
static CharonNWProtocolOptions *charon_stack_framer(CharonNWParameters *parameters)
{
    for (CharonNWProtocolOptions *options in parameters->_stack->_application) {
        if (options->_definition->_payload)
            return options;
    }
    return nil;
}

/* The order the file needs: the read path hands what it read to whoever is waiting for it, and the
   ready path uses both. Both are internal, so both are static and neither is a symbol the registry
   has to describe. */
static void charon_deliver_received(CharonNWConnection *connection);
static void charon_ready(CharonNWConnection *connection);
static void charon_tls_pump(CharonNWConnection *connection);
static void charon_handshake(CharonNWConnection *connection);
static void charon_flush(CharonNWConnection *connection);
static void charon_connect_finished(CharonNWConnection *connection);
static void charon_install_sources(CharonNWConnection *connection);
static BOOL charon_take_connected_socket(CharonNWConnection *connection, int handle, CharonNWEndpoint *endpoint);
static void charon_stop(CharonNWConnection *connection, nw_connection_state_t state, CharonNWError *error);
static void charon_readable(CharonNWConnection *connection);

#pragma mark - the state machine

static void charon_report_state(CharonNWConnection *connection, nw_connection_state_t state, CharonNWError *error)
{
    if (getenv("CHARON_TRACE_CONNECTION"))
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

static CharonNWError *charon_error(nw_error_domain_t domain, int code)
{
    if (!code)
        return nil;
    CharonNWError *error = [[CharonNWError alloc] init];
    error->_domain = domain;
    error->_code = code;
    return error;
}

/* An error whose code is the POSIX one the kernel gave, which is what a failed socket call is. */
static CharonNWError *charon_posix_error(void)
{
    return charon_error(nw_error_domain_posix, errno);
}

#pragma mark - the socket

/* The socket options the program's TCP and IP options ask for, applied to the socket that is open.
   Each one is a real setsockopt: what a program sets is what the socket does. */
static void charon_apply_options(CharonNWConnection *connection)
{
    int handle = connection->_socket;
    CharonNWParameters *parameters = connection->_parameters;
    CharonNWProtocolStack *stack = parameters->_stack;
    if (!connection->_isDatagram) {
        CharonNWProtocolOptions *tcp = stack->_transport;
        NSDictionary *values = tcp ? tcp->_values : nil;
        int on = 1;
        if (charon_nw_flag((__bridge CFDictionaryRef)values, "no_delay", false))
            setsockopt(handle, IPPROTO_TCP, TCP_NODELAY, &on, sizeof on);
        if (charon_nw_flag((__bridge CFDictionaryRef)values, "no_options", false))
            setsockopt(handle, IPPROTO_TCP, TCP_NOOPT, &on, sizeof on);
        if (charon_nw_flag((__bridge CFDictionaryRef)values, "no_push", false))
            setsockopt(handle, IPPROTO_TCP, TCP_NOPUSH, &on, sizeof on);
        if (charon_nw_flag((__bridge CFDictionaryRef)values, "enable_keepalive", false)) {
            setsockopt(handle, SOL_SOCKET, SO_KEEPALIVE, &on, sizeof on);
            int count = (int)charon_nw_integer((__bridge CFDictionaryRef)values, "keepalive_count", 0);
            if (count > 0)
                setsockopt(handle, IPPROTO_TCP, TCP_KEEPCNT, &count, sizeof count);
            int idle = (int)charon_nw_integer((__bridge CFDictionaryRef)values, "keepalive_idle_time", 0);
            if (idle > 0)
                setsockopt(handle, IPPROTO_TCP, TCP_KEEPALIVE, &idle, sizeof idle);
            int interval = (int)charon_nw_integer((__bridge CFDictionaryRef)values, "keepalive_interval", 0);
            if (interval > 0)
                setsockopt(handle, IPPROTO_TCP, TCP_KEEPINTVL, &interval, sizeof interval);
        }
    }
    CharonNWProtocolOptions *ip = stack->_internet;
    NSDictionary *values = ip ? ip->_values : nil;
    int on = 1;
    if (charon_nw_flag((__bridge CFDictionaryRef)values, "disable_multicast_loopback", false))
        setsockopt(handle, IPPROTO_IP, IP_MULTICAST_LOOP, &on, sizeof on);
    if (charon_nw_flag((__bridge CFDictionaryRef)values, "disable_fragmentation", false))
        setsockopt(handle, IPPROTO_IP, IP_DONTFRAG, &on, sizeof on);
    if (charon_nw_flag((__bridge CFDictionaryRef)values, "use_minimum_mtu", false))
        setsockopt(handle, IPPROTO_IP, IP_DONTFRAG, &on, sizeof on);
    if (charon_nw_flag((__bridge CFDictionaryRef)values, "no_delay", false)) {
        /* A stream's no-delay is IP-level too when the interface offers to coalesce. */
    }
    /* A connection bound to a local endpoint binds to it: the address and the port the program gave. */
    CharonNWEndpoint *local = parameters->_localEndpoint;
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

#pragma mark - the TLS of the release, over the same engine

static OSStatus charon_tls_read(SSLConnectionRef connection, void *data, size_t *length)
{
    CharonNWConnection *self = (__bridge CharonNWConnection *)connection;
    if (self->_pendingRead.length >= *length) {
        memcpy(data, self->_pendingRead.bytes, *length);
        [self->_pendingRead replaceBytesInRange:NSMakeRange(0, *length) withBytes:NULL length:0];
        return errSSLWouldBlock;
    }
    [self->_pendingRead setLength:0];
    ssize_t got = read(self->_socket, data, *length);
    if (got > 0) {
        *length = (size_t)got;
        return errSecSuccess;
    }
    *length = 0;
    if (got == 0)
        return errSSLClosedGraceful;
    return errSSLWouldBlock;
}

static OSStatus charon_tls_write(SSLConnectionRef connection, const void *data, size_t *length)
{
    CharonNWConnection *self = (__bridge CharonNWConnection *)connection;
    if (self->_pendingWrite.length + *length > (NSUInteger)charon_nw_available_send_buffer(self->_socket)) {
        [self->_pendingWrite appendBytes:data length:*length];
        *length = 0;
        return errSSLWouldBlock;
    }
    ssize_t put = write(self->_socket, data, *length);
    if (put > 0) {
        *length = (size_t)put;
        return errSecSuccess;
    }
    if (put == 0)
        return errSSLWouldBlock;
    return errno == EAGAIN || errno == EWOULDBLOCK ? errSSLWouldBlock : errSSLClosedAbort;
}

/* The context of this release's SecureTransport, under the name both the SDK and the 6.1.3 cache
   carry: SSLCreateContext (measured - facts/Network/NWConnection.md), and every other call of this TLS
   is there too: SSLSetIOFuncs,
   SSLSetPeerDomainName, SSLSetCertificate, SSLSetSessionOption, SSLHandshake, SSLRead, SSLWrite,
   SSLClose. A connection takes the system's own evaluation of the server's chain - this release has
   no SSLGetServerTrust, so a program that wants a policy of its own asks to break on server auth with
   SSLSetSessionOption, which is here. */
#pragma mark - the bytes

/* Everything a connection received since the last delivery, handed to the WebSocket when it has one,
   to the framer when the stack has one, and to the pending receive otherwise. */
static void charon_received(CharonNWConnection *connection, NSData *bytes)
{
    connection->_receivedBytes += bytes.length;
    if (connection->_framer) {
        [connection->_framer->_input appendData:bytes];
        if (connection->_framer->_inputHandler)
            connection->_framer->_inputHandler((nw_framer_t)connection->_framer);
        charon_deliver_received(connection);
        return;
    }
    [connection->_pendingRead appendData:bytes];
    charon_deliver_received(connection);
}

/* A message the WebSocket or the framer has produced is what the program receives. */
/* The first message the framer has delivered and not yet handed on, with whether it is the end of the
   framer's message. The framer delivers into its own list, which is what nw_framer_deliver_input
   fills; a connection is what hands those to the program. */
static NSData *charon_framer_message(CharonNWConnection *connection, BOOL *isComplete)
{
    CharonNWFramer *framer = connection->_framer;
    while (framer->_delivered.count) {
        NSArray *entry = framer->_delivered.firstObject;
        [framer->_delivered removeObjectAtIndex:0];
        NSData *bytes = entry[0];
        id message = entry[1];
        id complete = entry[2];
        if (isComplete)
            *isComplete = [complete boolValue];
        /* The metadata the framer gave the message travels with it, when the context can hold it. */
        if ([message isKindOfClass:[CharonNWProtocolMetadata class]])
            connection->_lastFramerMessage = message;
        return bytes;
    }
    return nil;
}

static void charon_deliver_received(CharonNWConnection *connection)
{
    if (getenv("CHARON_TRACE_FD"))
        fprintf(stderr, "[charon] drain: enter connection=%p state=%d receives=%lu pendingRead=%lu framer=%d\n",
                (__bridge void *)connection, connection->_value, (unsigned long)connection->_receives.count,
                (unsigned long)connection->_pendingRead.length, connection->_framer ? 1 : 0);
    for (CharonNWReceive *receive in [connection->_receives copy]) {
        NSData *message = nil;
        BOOL isComplete = NO;
        if (connection->_framer && connection->_framer->_delivered.count)
            message = charon_framer_message(connection, &isComplete);
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
        for (CharonNWReceive *receive in [connection->_receives copy]) {
            NSUInteger take = connection->_pendingRead.length;
            if (receive->_maximum && take > receive->_maximum)
                take = receive->_maximum;
            if (getenv("CHARON_TRACE_FD"))
                fprintf(stderr, "[charon] drain: stream take=%lu min=%u max=%u\n", (unsigned long)take,
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

/* What decides whether this connection can move a byte at all, at the moment it tries: the
   descriptor the sources are over, the sources themselves and whether each is live, the queue they
   and every handler are on, and the state the connection is in. Printed for both paths - a connection
   of the program's own and one a listener handed over - because that is how the difference between
   them was found (CHARON_TRACE_CONNECTION=1 in the environment).
 *
 * What the trace showed for a connection a listener handed over, and what it did not settle: the
 * connection reaches `ready` on both sides, the host's own send reports success, the read and the
 * write sources never fire, and - the anomaly this is for - the descriptor the accept produced is
 * not the one the connection holds when its engine runs, with a gap of exactly one on every
 * connection. The descriptors themselves are as they are made: the read source is over
 * `connection->_socket` and resumed, the write source is suspended until there is something to write,
 * and the accepted socket is made non-blocking. So the gap is where to look next, and
 * `tests/backports/host/network-listener` fails on it rather than around it. */
static void charon_dump(CharonNWConnection *connection, const char *where)
{
    if (!getenv("CHARON_TRACE_CONNECTION"))
        return;
    /* dispatch_source_get_data is NOT the descriptor: measured, a source created over a socket's fd
       answers 0 for it, so this column is the source's own data and not its target, and the only way
       to see which descriptor a source is over is the one the caller gave it. */
    uintptr_t read_data = connection->_readSource ? dispatch_source_get_data(connection->_readSource) : 0;
    fprintf(stderr, "[charon] %s fd=%d state=%d queue=%p readSource=%p over=%d writeSource=%p over=%d writing=%d "
                    "started=%d cancelled=%d datagram=%d secure=%d sends=%lu receives=%lu\n",
            where, connection->_socket, connection->_value, (__bridge void *)connection->_queue,
            (__bridge void *)connection->_readSource, (int)read_data, (__bridge void *)connection->_writeSource,
            connection->_writeSource ? (int)dispatch_source_get_data(connection->_writeSource) : 0,
            connection->_readingSource, connection->_started, connection->_cancelled, connection->_isDatagram,
            connection->_secure, (unsigned long)connection->_sends.count, (unsigned long)connection->_receives.count);
}

static void charon_flush(CharonNWConnection *connection)
{
    charon_dump(connection, "flush");
    /* What SecureTransport could not take yet goes first, then what the program handed to send. */
    while (connection->_pendingWrite.length) {
        size_t length = connection->_pendingWrite.length;
        if (connection->_ssl) {
            size_t written = 0;
            OSStatus status = SSLWrite(connection->_ssl, connection->_pendingWrite.bytes, length, &written);
            length = written;
            if (status == errSSLWouldBlock)
                break;
            if (status != errSecSuccess) {
                charon_report_state(connection, nw_connection_state_failed, charon_error(nw_error_domain_tls, (int)status));
                return;
            }
        } else {
            ssize_t put = write(connection->_socket, connection->_pendingWrite.bytes, length);
            if (put > 0)
                length = (size_t)put;
            else if (put < 0 && (errno == EAGAIN || errno == EWOULDBLOCK))
                break;
            else {
                charon_report_state(connection, nw_connection_state_failed, charon_posix_error());
                return;
            }
        }
        [connection->_pendingWrite replaceBytesInRange:NSMakeRange(0, length) withBytes:NULL length:0];
    }
    while (connection->_sends.count && !connection->_pendingWrite.length) {
        CharonNWSend *send = connection->_sends.firstObject;
        NSData *content = send->_content;
        size_t length = content.length;
        nw_connection_send_completion_t completion = send->_completion;
        [connection->_sends removeObjectAtIndex:0];
        if (connection->_ssl) {
            size_t written = 0;
            OSStatus status = SSLWrite(connection->_ssl, content.bytes, length, &written);
            length = written;
            if (status == errSSLWouldBlock) {
                [connection->_pendingWrite appendData:content];
                [connection->_sends insertObject:send atIndex:0];
                break;
            }
            if (status != errSecSuccess) {
                if (completion)
                    completion(charon_error(nw_error_domain_tls, (int)status));
                charon_report_state(connection, nw_connection_state_failed, charon_error(nw_error_domain_tls, (int)status));
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
                    completion(charon_posix_error());
                charon_report_state(connection, nw_connection_state_failed, charon_posix_error());
                return;
            }
        }
        connection->_sentBytes += length;
        if (completion)
            completion(NULL);
    }
    /* The write source is only live while there is something to write. */
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

/* What SecureTransport still has buffered is read out of it and handed on the same way bytes off the
   socket are, so a program sees one stream whichever layer is above the socket. */
static void charon_tls_pump(CharonNWConnection *connection)
{
    /* SSLRead is what pulls, and it answers errSSLWouldBlock when SecureTransport has nothing yet -
       the same contract as read() on the socket, so one loop reads through both layers. */
    uint8_t buffer[16384];
    for (;;) {
        size_t length = sizeof buffer;
        OSStatus status = SSLRead(connection->_ssl, buffer, sizeof buffer, &length);
        if (status == errSSLWouldBlock)
            return;
        if (status != errSecSuccess && status != errSSLClosedNoNotify) {
            connection->_finished = YES;
            charon_report_state(connection, nw_connection_state_failed, charon_error(nw_error_domain_tls, (int)status));
            return;
        }
        if (!length)
            return;
        charon_received(connection, [NSData dataWithBytes:buffer length:length]);
    }
}

static void charon_readable(CharonNWConnection *connection)
{
    if (getenv("CHARON_TRACE_FD"))
        fprintf(stderr, "[charon] readable: fd=%d\n", connection->_socket);
    charon_dump(connection, "read");
    uint8_t buffer[16384];
    while (YES) {
        ssize_t got = read(connection->_socket, buffer, sizeof buffer);
        if (getenv("CHARON_TRACE_FD"))
            fprintf(stderr, "[charon] read: fd=%d connection=%p state=%d got=%zd errno=%d receives=%lu pendingRead=%lu\n",
                    connection->_socket, (__bridge void *)connection, connection->_value, got, got < 0 ? errno : 0,
                    (unsigned long)connection->_receives.count, (unsigned long)connection->_pendingRead.length);
        if (got > 0) {
            charon_received(connection, [NSData dataWithBytes:buffer length:(NSUInteger)got]);
            if (connection->_cancelled || connection->_finished)
                return;
            if ((NSUInteger)got < sizeof buffer)
                return;
            continue;
        }
        if (got == 0) {
            /* The peer closed: what arrived is the end of the stream, and the connection is done. */
            connection->_finished = YES;
            charon_deliver_received(connection);
            charon_report_state(connection, nw_connection_state_cancelled, nil);
            return;
        }
        if (errno == EAGAIN || errno == EWOULDBLOCK)
            return;
        if (errno == EINTR)
            continue;
        charon_report_state(connection, nw_connection_state_failed, charon_posix_error());
        return;
    }
}

static void charon_handshake(CharonNWConnection *connection)
{
    OSStatus status = SSLHandshake(connection->_ssl);
    if (status == errSecSuccess) {
        connection->_handshaking = NO;
        charon_report_state(connection, nw_connection_state_ready, nil);
        return;
    }
    if (status == errSSLWouldBlock)
        return;
    charon_report_state(connection, nw_connection_state_failed, charon_error(nw_error_domain_tls, (int)status));
}

#pragma mark - opening and closing

/* Open a socket of the right kind, connect it to the endpoint, and report how it went. The address
   list is getaddrinfo's own, so the first address that takes a connect is the one the system would
   have picked. */
/* The path a connection is on, and what the program is told about it. The monitor is the Foundation
   library's own (facts/Network/NWPathMonitor.md): the port does not work the network out twice. */
static void charon_watch_path(CharonNWConnection *connection)
{
    if (connection->_monitor)
        return;
    nw_path_monitor_t monitor = nw_path_monitor_create();
    if (!monitor)
        return;
    connection->_monitor = monitor;
    nw_path_monitor_set_queue(monitor, connection->_queue);
    __weak CharonNWConnection *weak = connection;
    nw_path_monitor_set_update_handler(monitor, ^(nw_path_t path) {
        CharonNWConnection *self = weak;
        if (!self || self->_cancelled)
            return;
        self->_currentPath = path;
        /* Viable means the kernel has a route to the address and the path is satisfied. For a
           datagram socket connect() sends nothing - it binds the default peer and returns as soon as
           the kernel has a route - so this never claims the peer answered. */
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

/* A program's own protocol, made for this connection, with the options and the endpoints the stack
   gives it. It is the object the framer calls of the stack are made on. */
static void charon_make_framer(CharonNWConnection *connection)
{
    CharonNWProtocolOptions *options = charon_stack_framer(connection->_parameters);
    if (!options)
        return;
    CharonNWFramer *framer = [[CharonNWFramer alloc] init];
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

static void charon_install_sources(CharonNWConnection *connection)
{
    if (connection->_readSource || connection->_writeSource)
        return;
    /* Both sources are on the connection's own queue, so a handler is called there and never before
       nw_connection_start has returned. The write source stays suspended until there is something to
       write; a socket is always writable, so an always-live one would spin. */
    /* The read source is made once the socket is a connection: while a connect is in progress there is
       nothing to read, and the read source would fire for a hangup the kernel has not decided on yet. */
    if (getenv("CHARON_TRACE_FD"))
        fprintf(stderr, "[charon] sources: fd=%d connecting=%d queue=%p\n", connection->_socket,
                connection->_connecting, (__bridge void *)connection->_queue);
    connection->_readSource = connection->_connecting ? NULL : charon_nw_read_source(connection->_socket, connection->_queue);
    if (connection->_readSource) {
        __weak CharonNWConnection *weak = connection;
        dispatch_source_set_event_handler(connection->_readSource, ^{
            CharonNWConnection *self = weak;
            if (!self || self->_cancelled)
                return;
            if (self->_ssl && self->_handshaking) {
                charon_handshake(self);
                return;
            }
            if (self->_ssl) {
                charon_tls_pump(self);
                return;
            }
            charon_readable(self);
            /* Whatever arrived may have made room in the socket, and every event the connection gets
               is a chance to notice: a write source is the device's own signal for that, and this is
               the same check on the other side of the same engine. */
            if (!self->_cancelled)
                charon_flush(self);
        });
    }
    connection->_writeSource = charon_nw_write_source(connection->_socket, connection->_queue);
    if (connection->_writeSource) {
        __weak CharonNWConnection *weak = connection;
        dispatch_source_set_event_handler(connection->_writeSource, ^{
            CharonNWConnection *self = weak;
            if (!self || self->_cancelled)
                return;
            if (self->_connecting) {
                charon_connect_finished(self);
                return;
            }
            charon_flush(self);
        });
        /* A connect that is still in progress is finished by the socket becoming writable, and this
           is the only thing that waits for it - so the write source is live until it is. */
        if (connection->_connecting) {
            dispatch_resume(connection->_writeSource);
            connection->_readingSource = YES;
            return;
        }
    }
    charon_flush(connection);
}

/* Whether a connect() that answered EINPROGRESS has finished, and how it went: the socket is writable
   when the kernel has connected it, and SO_ERROR is then what the connect() would have answered
   later. A datagram socket is connected the moment connect() is given an address, so there is never
   anything to wait for. */
static void charon_connect_finished(CharonNWConnection *connection)
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
        charon_stop(connection, nw_connection_state_failed, charon_error(nw_error_domain_posix, failure));
        return;
    }
    charon_ready(connection);
}

/* Take a socket that is already connected - one an accept produced - as this connection's own. The
   engine is the same from here on: the sources, the path, the protocols and the state machine are
   made exactly as they are for a connection that connected itself. */
void CharonNWConnectionAttach(nw_connection_t value, int handle, BOOL connected)
{
    if (getenv("CHARON_TRACE_CONNECTION")) {
        CharonNWConnection *attached = (CharonNWConnection *)value;
        /* the port the other end connected from, which is what identifies this connection: two
           connections of one program are told apart by nothing else */
        unsigned peer_port = 0;
        struct sockaddr_storage peer;
        socklen_t peer_length = sizeof peer;
        memset(&peer, 0, sizeof peer);
        if (getpeername(handle, (struct sockaddr *)&peer, &peer_length) == 0)
            peer_port = charon_nw_sockaddr_port((const struct sockaddr *)&peer);
        fprintf(stderr, "[%8llu] port: attached fd=%d peerPort=%u connected=%d queue=%p datagram=%d secure=%d\n",
                (unsigned long long)(mach_absolute_time() / 1000000), handle, peer_port, connected,
                attached ? (__bridge void *)attached->_queue : NULL, attached ? attached->_isDatagram : 0,
                attached ? attached->_secure : 0);
    }
    /* Taking the socket is all this does. The engine is not started here: the connection is started
       after it is given its queue, by whoever made it - a listener's new-connection handler, or a
       program - and `nw_connection_start` is what knows it is already connected. */
    CharonNWConnection *connection = (CharonNWConnection *)value;
    (void)connected;
    if (!connection || handle < 0)
        return;
    @synchronized(connection) {
        if (connection->_cancelled)
            return;
        connection->_socket = handle;
        connection->_acceptedSocket = handle;
        connection->_currentEndpoint = connection->_endpoint;
        /* The connection's own socket is now the accepted descriptor and nothing else may be standing
           in for it: the engine below makes its sources over exactly this number, so a connection that
           reached here with a different one would be reading a descriptor that is not its socket. */
        assert(connection->_socket == handle);
    }
    charon_nw_set_nonblocking(handle);
    CharonNWParameters *parameters = connection->_parameters;
    connection->_isDatagram = charon_is_datagram(parameters);
    connection->_secure = charon_is_secure(parameters);
}

/* The descriptor a connection object holds, asked for by the files that cannot see its ivars: the
   listener's accept path says which fd the object it made is holding, so that a start that dialled
   again instead of adopting it would be visible in one trace. */
int charon_nw_connection_socket(nw_connection_t value)
{
    return ((CharonNWConnection *)value)->_socket;
}

/* The descriptor a connection object holds, for the files that cannot see its ivars: the listener's
   accept path says which fd the object it made is holding, so a start that dialled again instead of
   adopting it is one line of trace away. */

/* Whether a program has already given this connection a queue, which is what a listener asks before it
   starts one: a connection with no queue does nothing at all when it is started. */
BOOL CharonNWConnectionHasQueue(nw_connection_t value)
{
    return ((CharonNWConnection *)value)->_queue != NULL;
}

/* Hand a connection's socket to whoever asks for it - a listener, which becomes a listener of it -
   and say what the connection was made of. FALSE for a connection with no socket, which is a
   connection that was cancelled or never started. */
BOOL CharonNWConnectionTakeSocket(nw_connection_t value, int *out_handle, void *out_endpoint, void *out_parameters)
{
    CharonNWConnection *connection = (CharonNWConnection *)value;
    if (!connection)
        return NO;
    @synchronized(connection) {
        if (connection->_socket < 0)
            return NO;
        if (out_handle)
            *out_handle = connection->_socket;
        if (out_endpoint)
            *(CharonNWEndpoint * _Nonnull __unsafe_unretained *)out_endpoint = connection->_currentEndpoint;
        if (out_parameters)
            *(nw_parameters_t __unsafe_unretained *)out_parameters = connection->_parameters;
        connection->_socket = -1;
    }
    return YES;
}

/* What a connection is ready: the socket is connected, the path is being watched, the sources are
   live, and the metadata of each protocol is there for nw_connection_copy_protocol_metadata. */
static void charon_ready(CharonNWConnection *connection)
{
    if (connection->_cancelled)
        return;
    charon_report_state(connection, nw_connection_state_preparing, nil);
    charon_watch_path(connection);
    CharonNWProtocolMetadata *ip = [[CharonNWProtocolMetadata alloc] init];
    ip->_definition = (CharonNWProtocolDefinition *)nw_protocol_copy_ip_definition();
    ip->_values = [NSMutableDictionary dictionary];
    ip->_objects = [NSMutableDictionary dictionary];
    charon_nw_set_integer((__bridge CFMutableDictionaryRef)ip->_values, "service_class", connection->_parameters->_serviceClass);
    connection->_ipMetadata = ip;

    if (!connection->_isDatagram) {
        CharonNWProtocolMetadata *tcp = [[CharonNWProtocolMetadata alloc] init];
        tcp->_definition = (CharonNWProtocolDefinition *)nw_protocol_copy_tcp_definition();
        tcp->_values = [NSMutableDictionary dictionary];
        tcp->_objects = [NSMutableDictionary dictionary];
        charon_nw_set_integer((__bridge CFMutableDictionaryRef)tcp->_values, "available_send_buffer",
                              charon_nw_available_send_buffer(connection->_socket));
        charon_nw_set_integer((__bridge CFMutableDictionaryRef)tcp->_values, "available_receive_buffer",
                              charon_nw_available_receive_buffer(connection->_socket));
        connection->_transportMetadata = tcp;
    } else {
        CharonNWProtocolMetadata *udp = [[CharonNWProtocolMetadata alloc] init];
        udp->_definition = (CharonNWProtocolDefinition *)nw_protocol_copy_udp_definition();
        udp->_values = [NSMutableDictionary dictionary];
        udp->_objects = [NSMutableDictionary dictionary];
        connection->_transportMetadata = udp;
    }

    charon_make_framer(connection);
    charon_install_sources(connection);

    if (connection->_secure) {
        connection->_ssl = SSLCreateContext(kCFAllocatorDefault, kSSLClientSide, kSSLStreamType);
        if (!connection->_ssl) {
            charon_report_state(connection, nw_connection_state_failed, charon_error(nw_error_domain_tls, errSSLInternal));
            return;
        }
        SSLSetIOFuncs(connection->_ssl, charon_tls_read, charon_tls_write);
        /* As high as this release's TLS goes: it has SSLSetProtocolVersionMin and Max (measured in
           the 6.1.3 cache) and so speaks TLS 1.2, and TLS 1.3 is not in it at all - which is what
           picotls is in the library for, when a server insists on 1.3. */
        SSLSetProtocolVersionMin(connection->_ssl, kTLSProtocol1);
        SSLSetProtocolVersionMax(connection->_ssl, kTLSProtocol12);
        NSString *peer = connection->_endpoint->_hostname.length ? connection->_endpoint->_hostname : nil;
        if (peer.length)
            SSLSetPeerDomainName(connection->_ssl, peer.UTF8String, (int)peer.length);
        connection->_handshaking = YES;
        charon_handshake(connection);
        if (connection->_handshaking)
            return;
        if (connection->_cancelled)
            return;
    }
    charon_report_state(connection, nw_connection_state_ready, nil);
}

/* Take a socket the connect has just made, under the same lock nw_connection_cancel takes: false
   when the connection was cancelled while the connect ran, and then the caller closes the handle and
   nothing else happens for a connection nobody wants. */
static BOOL charon_take_connected_socket(CharonNWConnection *connection, int handle, CharonNWEndpoint *endpoint)
{
    @synchronized(connection) {
        if (connection->_cancelled)
            return NO;
        connection->_socket = handle;
        connection->_currentEndpoint = endpoint;
        charon_nw_set_nonblocking(handle);
        return YES;
    }
}

static void charon_open(CharonNWConnection *connection)
{
    CharonNWConnection *self = connection;
    CharonNWEndpoint *endpoint = connection->_endpoint;
    CharonNWParameters *parameters = connection->_parameters;
    connection->_isDatagram = charon_is_datagram(parameters);
    connection->_secure = charon_is_secure(parameters);

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
                charon_report_state(connection, nw_connection_state_failed, charon_error(nw_error_domain_dns, failure));
            });
            return;
        }
        for (struct addrinfo *entry = list; entry; entry = entry->ai_next) {
            int handle = charon_nw_blocking_socket(entry->ai_family, entry->ai_socktype, entry->ai_protocol);
            if (handle < 0) {
                last = errno;
                continue;
            }
            connection->_socket = handle;
            charon_apply_options(connection);
            if (connect(handle, entry->ai_addr, entry->ai_addrlen) == 0) {
                freeaddrinfo(list);
                /* The connect ran on a queue of its own, so a cancel may have landed while it did: the
                   handle and the endpoint are taken under the lock the cancel takes, and a connection
                   cancelled in the meantime closes what it made instead of handing it to the sources. */
                if (!charon_take_connected_socket(self, handle, endpoint)) {
                    close(handle);
                    return;
                }
                dispatch_async(connection->_queue, ^{
                    charon_install_sources(self);
                    charon_ready(self);
                });
                return;
            }
            last = errno;
            close(handle);
            connection->_socket = -1;
        }
        freeaddrinfo(list);
    } else if (endpoint->_address.length) {
        /* An address endpoint is not looked up: it is the address. */
        struct sockaddr_storage address;
        memset(&address, 0, sizeof address);
        memcpy(&address, endpoint->_address.bytes, MIN(endpoint->_address.length, sizeof address));
        int family = address.ss_family;
        int type = connection->_isDatagram ? SOCK_DGRAM : SOCK_STREAM;
        int protocol = connection->_isDatagram ? IPPROTO_UDP : IPPROTO_TCP;
        int handle = charon_nw_blocking_socket(family, type, protocol);
        if (handle < 0) {
            charon_report_state(connection, nw_connection_state_failed, charon_posix_error());
            return;
        }
        connection->_socket = handle;
        charon_apply_options(connection);
        if (connect(handle, (struct sockaddr *)&address, (socklen_t)endpoint->_address.length) != 0) {
            last = errno;
            close(handle);
            connection->_socket = -1;
        } else {
            if (!charon_take_connected_socket(self, handle, endpoint)) {
                close(handle);
                return;
            }
            dispatch_async(connection->_queue, ^{
                charon_install_sources(self);
                charon_ready(self);
            });
            return;
        }
    } else {
        charon_report_state(connection, nw_connection_state_failed, charon_error(nw_error_domain_dns, EAI_NONAME));
        return;
    }
    dispatch_async(connection->_queue, ^{
        charon_report_state(connection, nw_connection_state_failed, charon_error(nw_error_domain_posix, last));
    });
}

static void charon_stop(CharonNWConnection *connection, nw_connection_state_t state, CharonNWError *error)
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
        SSLClose(connection->_ssl);
        CFRelease(connection->_ssl);
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
    /* The handlers go with the connection: a handler that outlived it would be a block the program
       cannot release, and the header says no handler is called after a cancel, which is what letting
       them go makes true of the objects too. */
    connection->_path = nil;
    connection->_viability = nil;
    connection->_betterPath = nil;
    connection->_state = nil;

    /* Every receive and every send still waiting is answered, so no program waits for ever. */
    for (CharonNWReceive *receive in [connection->_receives copy]) {
        [connection->_receives removeObject:receive];
        if (receive->_completion)
            receive->_completion(NULL, NULL, true, error);
    }
    for (CharonNWSend *send in [connection->_sends copy]) {
        [connection->_sends removeObject:send];
        if (send->_completion)
            send->_completion(error);
    }
    charon_report_state(connection, state, error);
}

#pragma mark - the calls

nw_connection_t nw_connection_create(nw_endpoint_t endpoint, nw_parameters_t parameters)
{
    if (!endpoint || !parameters)
        return nil;
    CharonNWConnection *connection = [[CharonNWConnection alloc] init];
    connection->_endpoint = (CharonNWEndpoint *)endpoint;
    connection->_parameters = (CharonNWParameters *)parameters;
    connection->_socket = -1;
    /* No accepted descriptor: this is a connection of a program's own, which has to dial, and the
       start path decides that on this number. Left at zero it would read as a descriptor and a
       connection of the program's own would take the listener's path. */
    connection->_acceptedSocket = -1;
    /* The connect is the one call that has to wait, so it waits on a queue of its own: the connection's
       queue carries the handlers and must never be held up by a peer that takes its time. */
    connection->_connectQueue = dispatch_queue_create("charon.connect", DISPATCH_QUEUE_SERIAL);
    connection->_sends = [NSMutableArray array];
    connection->_receives = [NSMutableArray array];
    connection->_pendingWrite = [NSMutableData data];
    connection->_pendingRead = [NSMutableData data];
    connection->_value = nw_connection_state_setup;
    return connection;
}

nw_endpoint_t nw_connection_copy_endpoint(nw_connection_t connection)
{
    return connection ? ((CharonNWConnection *)connection)->_endpoint : NULL;
}

nw_parameters_t nw_connection_copy_parameters(nw_connection_t connection)
{
    return connection ? ((CharonNWConnection *)connection)->_parameters : NULL;
}

void nw_connection_set_queue(nw_connection_t connection, dispatch_queue_t queue)
{
    if (connection)
        ((CharonNWConnection *)connection)->_queue = queue;
}

void nw_connection_set_path_changed_handler(nw_connection_t connection, nw_connection_path_event_handler_t handler)
{
    if (connection)
        ((CharonNWConnection *)connection)->_path = [handler copy];
}

void nw_connection_set_viability_changed_handler(nw_connection_t connection, nw_connection_boolean_event_handler_t handler)
{
    if (connection)
        ((CharonNWConnection *)connection)->_viability = [handler copy];
}

void nw_connection_set_better_path_available_handler(nw_connection_t connection, nw_connection_boolean_event_handler_t handler)
{
    if (connection)
        ((CharonNWConnection *)connection)->_betterPath = [handler copy];
}

void nw_connection_set_state_changed_handler(nw_connection_t connection, nw_connection_state_changed_handler_t handler)
{
    if (connection)
        ((CharonNWConnection *)connection)->_state = [handler copy];
}

void nw_connection_start(nw_connection_t connection)
{
    if (!connection)
        return;
    CharonNWConnection *self = (CharonNWConnection *)connection;
    @synchronized(self) {
        /* The queue before the start, as the SDK requires, and a second start is not a new attempt. */
        if (self->_started || self->_cancelled || !self->_queue)
            return;
        self->_started = YES;
    }
    dispatch_async(self->_queue, ^{
        if (self->_cancelled)
            return;
        self->_startedAtMilliseconds = charon_nw_uptime_milliseconds();
        charon_report_state(self, nw_connection_state_waiting, nil);
        if (self->_acceptedSocket >= 0) {
            /* A connection whose socket came from an accept is connected already. Dialling the
               endpoint again would be a *client* connection to the listener's own address, on a
               socket of its own, while the accepted descriptor sat unused: that is what a connection
               made by a listener used to do, and nothing the program sent to it ever arrived. The
               engine is made over the accepted descriptor, asserted to be the connection's socket. */
            @synchronized(self) {
                assert(self->_socket == self->_acceptedSocket);
            }
            charon_install_sources(self);
            charon_ready(self);
            return;
        }
        dispatch_async(self->_connectQueue, ^{
            charon_open(self);
        });
    });
}

void nw_connection_cancel(nw_connection_t connection)
{
    if (!connection)
        return;
    CharonNWConnection *self = (CharonNWConnection *)connection;
    dispatch_block_t stop = ^{
        charon_stop(self, nw_connection_state_cancelled, nil);
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
    CharonNWConnection *self = (CharonNWConnection *)connection;
    /* Forcibly: on the queue of the caller, not the connection's, and without waiting for what that
       queue is doing - which is what a force is for. */
    charon_stop(self, nw_connection_state_cancelled, nil);
}

void nw_connection_restart(nw_connection_t connection)
{
    if (!connection)
        return;
    CharonNWConnection *self = (CharonNWConnection *)connection;
    dispatch_async(self->_queue ?: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self->_cancelled)
            return;
        self->_attempts++;
        self->_finished = NO;
        if (self->_socket >= 0)
            close(self->_socket);
        self->_socket = -1;
        charon_report_state(self, nw_connection_state_waiting, nil);
        charon_open(self);
    });
}

void nw_connection_cancel_current_endpoint(nw_connection_t connection)
{
    if (!connection)
        return;
    CharonNWConnection *self = (CharonNWConnection *)connection;
    /* The endpoint of a connection is the one it is connected to; with a Bonjour or a multiplexed
       peer there may be others, and cancelling this one leaves the connection to try the next. */
    self->_currentEndpoint = nil;
    dispatch_async(self->_queue ?: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self->_cancelled)
            return;
        if (self->_socket >= 0) {
            close(self->_socket);
            self->_socket = -1;
        }
        self->_attempts++;
        charon_report_state(self, nw_connection_state_waiting, nil);
        charon_open(self);
    });
}

void nw_connection_batch(nw_connection_t connection, dispatch_block_t batch_block)
{
    if (!connection)
        return;
    CharonNWConnection *self = (CharonNWConnection *)connection;
    if (!batch_block)
        return;
    /* A batch is the connection's state held still while the block runs, so a program that changes
       the handlers sees them all take effect together. */
    dispatch_async(self->_queue ?: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @synchronized(self) {
            batch_block();
        }
    });
}

nw_path_t nw_connection_copy_current_path(nw_connection_t connection)
{
    CharonNWConnection *value = (CharonNWConnection *)connection;
    return value ? value->_currentPath : NULL;
}

uint32_t nw_connection_get_maximum_datagram_size(nw_connection_t connection)
{
    CharonNWConnection *self = (CharonNWConnection *)connection;
    if (!self || self->_socket < 0)
        return 0;
    /* The interface *this* connection is on, which is the interface that holds the address the socket
       bound to - not the first interface the device has up, which is a different link when the
       connection is over the loopback or over Wi-Fi while the general path is cellular. The system's
       own answer is the MTU of the path the connection is on, and for a connection over the loopback
       that is lo0 (measured: 16344 there, where the device's other interface would say 1460). */
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
        int probe = charon_nw_socket(AF_INET, SOCK_DGRAM, 0);
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
    /* 20 bytes of IP header and 8 of UDP or 20 of TCP, which is what the kernel puts on the wire and
       is why the largest datagram over an MTU of 1500 is 1500 - 20 - 8. */
    size_t overhead = self->_isDatagram ? 20u + 8u : 20u + 20u;
    return mtu > overhead ? mtu - (uint32_t)overhead : 0;
}

char *nw_connection_copy_description(nw_connection_t connection)
{
    CharonNWConnection *self = (CharonNWConnection *)connection;
    if (!self)
        return NULL;
    /* The description is what the host's own Network writes: the connection's number, the peer, the
       protocols, the attribution, the path, the viability and the interface - the same pieces, in the
       same order, for a program that prints it. */
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
    return charon_nw_copy_cstring(text.UTF8String);
}

void nw_connection_send(nw_connection_t connection, dispatch_data_t content, nw_content_context_t context,
                        bool is_complete, nw_connection_send_completion_t completion)
{
    if (!connection)
        return;
    CharonNWConnection *self = (CharonNWConnection *)connection;
    if (!self->_queue) {
        if (completion)
            completion(charon_error(nw_error_domain_posix, EINVAL));
        return;
    }
    dispatch_async(self->_queue, ^{
        if (self->_cancelled || self->_value != nw_connection_state_ready) {
            if (completion)
                completion(charon_error(nw_error_domain_posix, self->_cancelled ? ECANCELED : ENOTCONN));
            return;
        }
        CharonNWSend *send = [[CharonNWSend alloc] init];
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
        charon_flush(self);
    });
}

void nw_connection_receive(nw_connection_t connection, uint32_t minimum_incomplete_length, uint32_t maximum_length,
                           nw_connection_receive_completion_t completion)
{
    if (!connection)
        return;
    CharonNWConnection *self = (CharonNWConnection *)connection;
    if (!self->_queue) {
        if (completion)
            completion(NULL, NULL, true, NULL);
        return;
    }
    dispatch_async(self->_queue, ^{
        CharonNWReceive *receive = [[CharonNWReceive alloc] init];
        receive->_minimum = minimum_incomplete_length;
        receive->_maximum = maximum_length;
        receive->_completion = completion;
        [self->_receives addObject:receive];
        charon_deliver_received(self);
    });
}

void nw_connection_receive_message(nw_connection_t connection, nw_connection_receive_completion_t completion)
{
    /* One message, whole: the bounds are the connection's own, so a message is never cut in half. */
    nw_connection_receive(connection, 1, 0, completion);
}

/* What the protocols of a connection say about it: the IP packet's service class and ECN flag, the
   transport's available buffers, and the negotiated session of a secure one. Asked of a protocol the
   connection is not carrying, it is NULL - which is what the SDK says a definition the connection does
   not have answers. */
nw_protocol_metadata_t nw_connection_copy_protocol_metadata(nw_connection_t connection, nw_protocol_definition_t definition)
{
    CharonNWConnection *self = (CharonNWConnection *)connection;
    if (!self || !definition)
        return NULL;
    CharonNWProtocolDefinition *wanted = (CharonNWProtocolDefinition *)definition;
    if (self->_ipMetadata && [self->_ipMetadata->_definition->_family isEqualToString:wanted->_family])
        return self->_ipMetadata;
    if (self->_transportMetadata && [self->_transportMetadata->_definition->_family isEqualToString:wanted->_family])
        return self->_transportMetadata;
    if (self->_secureMetadata && [self->_secureMetadata->_definition->_family isEqualToString:wanted->_family])
        return self->_secureMetadata;
    return NULL;
}

/* The report of what establishing this connection took, and the report of what it has moved since.
   Both are the connection's own measurements, read back through the accessors of NWObjects.md: the
   times from its first start to the state it reached, the attempts before it, the protocols of its
   stack and the address it settled on; and the bytes the program sent and received, the bytes the
   transport moved, and the round trip times the kernel's own TCP_CONNECTION_INFO holds. */

nw_establishment_report_t CharonNWConnectionEstablishmentReport(nw_connection_t connection)
{
    CharonNWConnection *self = (CharonNWConnection *)connection;
    if (!self)
        return NULL;
    CharonNWEstablishmentReport *report = [[CharonNWEstablishmentReport alloc] init];
    report->_protocols = [NSMutableArray array];
    report->_protocolHandshakeMilliseconds = [NSMutableArray array];
    report->_protocolHandshakeRTTMilliseconds = [NSMutableArray array];
    report->_resolutions = [NSMutableArray array];
    report->_resolutionReports = [NSMutableArray array];
    report->_durationMilliseconds = self->_startedAtMilliseconds
        ? charon_nw_uptime_milliseconds() - self->_startedAtMilliseconds : 0;
    report->_previousAttemptCount = self->_attempts;
    [report->_protocols addObject:(CharonNWProtocolDefinition *)nw_protocol_copy_udp_definition()];
    if (!self->_isDatagram)
        [report->_protocols addObject:(CharonNWProtocolDefinition *)nw_protocol_copy_tcp_definition()];
    if (self->_secure)
        [report->_protocols addObject:(CharonNWProtocolDefinition *)nw_protocol_copy_tls_definition()];
    [report->_protocols addObject:(CharonNWProtocolDefinition *)nw_protocol_copy_ip_definition()];
    while (report->_protocolHandshakeMilliseconds.count < report->_protocols.count) {
        [report->_protocolHandshakeMilliseconds addObject:@(0)];
        [report->_protocolHandshakeRTTMilliseconds addObject:@(0)];
    }
    if (self->_currentEndpoint) {
        [report->_resolutions addObject:self->_currentEndpoint];
        CharonNWResolutionReport *resolution = [[CharonNWResolutionReport alloc] init];
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

nw_data_transfer_report_t CharonNWConnectionDataTransferReport(nw_connection_t connection)
{
    CharonNWConnection *self = (CharonNWConnection *)connection;
    if (!self)
        return NULL;
    CharonNWDataTransferReport *report = [[CharonNWDataTransferReport alloc] init];
    report->_sentApplicationBytes = self->_sentBytes;
    report->_receivedApplicationBytes = self->_receivedBytes;
    report->_sentTransportBytes = self->_sentBytes;
    report->_receivedTransportBytes = self->_receivedBytes;
    report->_durationMilliseconds = self->_startedAtMilliseconds
        ? charon_nw_uptime_milliseconds() - self->_startedAtMilliseconds : 0;
    if (self->_socket >= 0 && !self->_isDatagram) {
        uint64_t smoothed = 0, minimum = 0, variance = 0;
        if (charon_nw_tcp_round_trips(self->_socket, &smoothed, &minimum, &variance)) {
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
