/*
 * The listener of Network: a real socket, bound and listening, on the queue the program gave.
 *
 * What a listener is here: a stream socket - a listener is a stream in Network, and its parameters say
 * so - bound to the port they name (or to one the system gives when the port is zero), listening,
 * and read by a dispatch source
 * on the listener's own queue - so `accept` happens where every handler of the listener is called, and
 * the connection each accept produces is a real `nw_connection_t` of this library over the accepted
 * socket, started the way a program starts one. A listener with TLS in its stack accepts through the
 * release's own SecureTransport as a server (`SSLContextCreate(kSSLServerSide)`, `SSLSetCertificate`,
 * `SSLSetIOFuncs`, `SSLHandshake`), driven from that connection's own engine, so a TLS listener and a
 * plain one differ in one place.
 *
 * The states are the SDK's: `waiting` while there is no port to bind or no answer from the
 * interface, `ready` once the socket is listening, `failed` with the error that stopped it, and
 * `cancelled` when the program said so. `nw_listener_get_port` answers 0 until the listener is ready,
 * which is what the header says of a listener that has no port yet.
 *
 * The advertisement of a Bonjour service is `NSNetService`: the release's own DNS-SD, reached
 * through the API Apple documents for it (Foundation's NSNetServices.h, exported by the 6.1.3
 * cache), not through a browse or a register of its own.
 */

#import "CharonNW.h"
#include <mach/mach_time.h>
#include <stdio.h>
#import "CharonNWSupport.h"
#import <Foundation/NSNetServices.h>

#include <errno.h>
#include <netdb.h>
#include <netinet/in.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#import <Security/Security.h>
#import <Security/SecureTransport.h>

/* The class is in CharonNW.h: the iOS 16 file of the listener reaches into it. */

/* The listener's class, its state and its implementation are in this one file and nowhere else: with
   the fragile ABI a class's ivar offsets are emitted by every file that sees its @interface, so a header
   the library's other files read would make the link see each of them twice. The iOS 16 file of the
   listener reaches what it needs through the C functions at the end of this file. */
@interface CharonNWListener : NSObject <OS_nw_listener> {
@public
    nw_parameters_t _parameters;
    nw_endpoint_t _endpoint;
    CharonNWEndpoint *_localEndpoint;
    CharonNWAdvertiseDescriptor *_advertise;
    CharonNWEndpoint *_advertisedEndpoint;
    dispatch_queue_t _queue;
    nw_listener_state_changed_handler_t _state;
    nw_listener_new_connection_handler_t _newConnection;
    nw_listener_new_connection_group_handler_t _newConnectionGroup;
    nw_listener_advertised_endpoint_changed_handler_t _advertisedChanged;
    uint32_t _newConnectionLimit;
    uint32_t _accepted;
    nw_listener_state_t _value;
    int _socket;
    dispatch_source_t _acceptSource;
    NSMutableArray *_connections;
    NSNetService *_service;
    BOOL _started, _cancelled, _secure;
}
@end

@implementation CharonNWListener
@end

/* What the listener's iOS 16 file needs, as C functions, for the reason the connection's are C
   functions too: with the fragile ABI a class's ivar offsets are emitted by every file that sees its
   @interface, so the class lives in this one file and its neighbours ask for what they need. */
void CharonNWListenerSetNewConnectionGroup(nw_listener_t value, nw_listener_new_connection_group_handler_t handler)
{
    if (value)
        ((CharonNWListener *)value)->_newConnectionGroup = [handler copy];
}

void CharonNWListenerSetNewConnectionLimit(nw_listener_t value, uint32_t new_connection_limit)
{
    if (value)
        ((CharonNWListener *)value)->_newConnectionLimit = new_connection_limit;
}

uint32_t CharonNWListenerGetNewConnectionLimit(nw_listener_t value)
{
    CharonNWListener *listener = (CharonNWListener *)value;
    return listener ? listener->_newConnectionLimit : 0;
}

static void charon_listener_report(CharonNWListener *listener, nw_listener_state_t state, CharonNWError *error)
{
    @synchronized(listener) {
        if (listener->_cancelled && state != nw_listener_state_cancelled)
            return;
        if (listener->_value == state && state != nw_listener_state_failed && state != nw_listener_state_ready)
            return;
        listener->_value = state;
    }
    nw_listener_state_changed_handler_t handler = listener->_state;
    if (handler)
        handler(state, error);
}

static CharonNWError *charon_listener_posix(void)
{
    CharonNWError *error = [[CharonNWError alloc] init];
    error->_domain = nw_error_domain_posix;
    error->_code = errno;
    return error;
}

static BOOL charon_listener_is_secure(nw_parameters_t parameters)
{
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    for (CharonNWProtocolOptions *options in value->_stack->_application) {
        if ([options->_definition->_family isEqualToString:@"nw_tls"])
            return YES;
    }
    return NO;
}

/* The connection of an accepted socket, started. It is the same object a program makes with
   nw_connection_create, with the parameters the listener was given, and it is handed over as soon as
   its state is ready - which is what the header says the new connection handler is for. */
static void charon_listener_adopt(CharonNWListener *listener, int handle)
{
    @synchronized(listener) {
        if (listener->_newConnectionLimit != 0 && listener->_accepted >= listener->_newConnectionLimit) {
            close(handle);
            return;
        }
        listener->_accepted++;
    }
    nw_connection_t connection = nw_connection_create(listener->_localEndpoint, listener->_parameters);
    if (!connection) {
        close(handle);
        return;
    }
    /* The accepted socket is the connection's own: the engine takes it over, non-blocking, with the
       listeners and sources it would have made itself, and the connect has already happened. */
    CharonNWConnectionAttach(connection, handle, YES);
    @synchronized(listener) {
        [listener->_connections addObject:(id)connection];
    }
    /* The connection belongs to the listener's queue, so it has one before it is started - a connection
       started with no queue does nothing at all, which is what the header says of a program that
       forgets one. Then the handler, and then the start: a connection that can reach `ready` with no
       handler on it would be handed to nobody. */
    __weak CharonNWListener *weak = listener;
    if (getenv("CHARON_TRACE_CONNECTION")) {
        extern int charon_nw_connection_socket(nw_connection_t connection);
        fprintf(stderr, "[charon] adopt accepted=%d the-connection-holds=%d\n", handle,
                charon_nw_connection_socket(connection));
    }
    if (!CharonNWConnectionHasQueue(connection))
        nw_connection_set_queue(connection, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    nw_connection_set_state_changed_handler(connection, ^(nw_connection_state_t state, nw_error_t error) {
        CharonNWListener *strong = weak;
        if (getenv("CHARON_TRACE_LISTENER"))
            fprintf(stderr, "[charon] listener: state %d on %p queue %p handler %p newConnection %p\n",
                    state, (__bridge void *)listener, strong ? (__bridge void *)strong->_queue : NULL,
                    (__bridge void *)listener, strong ? (__bridge void *)strong->_newConnection : NULL);
        if (state != nw_connection_state_ready || !strong || !strong->_newConnection)
            return;
        strong->_newConnection(connection);
    });
    nw_connection_start(connection);
}

/* How many connections one read of the listening socket may produce. A listener that accepts until the
   kernel says "nothing more" starves everything else on its own queue - and the engines of the
   connections it has just accepted are on that queue - so a burst is taken a batch at a time and the
   rest is left to the next event, which the kernel sends because the listening socket is still
   readable. */
#define CHARON_LISTENER_BATCH 16

static void charon_listener_accept(CharonNWListener *listener)
{
    for (int taken = 0; taken < CHARON_LISTENER_BATCH; taken++) {
        int handle = accept(listener->_socket, NULL, NULL);
        if (handle < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR)
                return;
            if (errno == EMFILE || errno == ENFILE) {
                /* Out of descriptors: the kernel has queued the connection, and the next event will
                   try again, which is what a listener does when it runs out. */
                return;
            }
            charon_listener_report(listener, nw_listener_state_failed, charon_listener_posix());
            return;
        }
        charon_listener_adopt(listener, handle);
    }
}

/* The advertisement: NSNetService is the release's own DNS-SD, and the endpoint it hands back is
   what the program's advertised-endpoint handler is given when the name has been registered. */
static void charon_listener_advertise(CharonNWListener *listener)
{
    CharonNWAdvertiseDescriptor *descriptor = (CharonNWAdvertiseDescriptor *)listener->_advertise;
    if (!descriptor)
        return;
    NSString *name = descriptor->_bonjourName.length ? descriptor->_bonjourName : @"";
    NSString *type = descriptor->_bonjourType ?: @"";
    NSString *domain = descriptor->_bonjourDomain.length ? descriptor->_bonjourDomain : @"local.";
    CharonNWEndpoint *published = [[CharonNWEndpoint alloc] init];
    published->_type = nw_endpoint_type_bonjour_service;
    published->_bonjourName = name;
    published->_bonjourType = type;
    published->_bonjourDomain = domain;
    published->_port = listener->_localEndpoint ? listener->_localEndpoint->_port : @"0";
    if (descriptor->_txtRecordObject || descriptor->_txtRecord.length) {
        nw_txt_record_t record = descriptor->_txtRecordObject
            ? descriptor->_txtRecordObject
            : nw_txt_record_create_with_bytes((const uint8_t *)descriptor->_txtRecord.bytes, descriptor->_txtRecord.length);
        published->_txtRecord = (CharonNWTxtRecord *)record;
    }
    listener->_service = [[NSNetService alloc] initWithDomain:domain type:type name:name];
    if (listener->_service)
        [listener->_service publish];
    listener->_advertisedEndpoint = published;
    if (listener->_advertisedChanged)
        listener->_advertisedChanged((nw_endpoint_t)published, YES);
}

static void charon_listener_withdraw(CharonNWListener *listener)
{
    if (!listener->_service)
        return;
    [listener->_service stop];
    listener->_service = nil;
    if (listener->_advertisedChanged && listener->_advertisedEndpoint)
        listener->_advertisedChanged((nw_endpoint_t)listener->_advertisedEndpoint, NO);
    listener->_advertisedEndpoint = nil;
}

/* Bind and listen, then report. The port is the one the parameters' local endpoint names, or one
   the system gives when it names none - which is how a program asks for any port. */
static void charon_listener_open(CharonNWListener *listener)
{
    CharonNWParameters *parameters = (CharonNWParameters *)listener->_parameters;
    listener->_secure = charon_listener_is_secure(listener->_parameters);
    uint16_t port = 0;
    CharonNWEndpoint *local = parameters->_localEndpoint;
    if (local && local->_port.length)
        port = (uint16_t)atoi(local->_port.UTF8String);

    struct addrinfo hints;
    memset(&hints, 0, sizeof hints);
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;
    hints.ai_flags = AI_PASSIVE;
    struct addrinfo *list = NULL;
    int failure = getaddrinfo(NULL, port ? [[NSString stringWithFormat:@"%u", port] UTF8String] : "0", &hints, &list);
    if (failure != 0 || !list) {
        charon_listener_report(listener, nw_listener_state_failed, charon_listener_posix());
        return;
    }
    int last = EADDRNOTAVAIL;
    for (struct addrinfo *entry = list; entry; entry = entry->ai_next) {
        int handle = charon_nw_blocking_socket(entry->ai_family, entry->ai_socktype, entry->ai_protocol);
        if (handle < 0) {
            last = errno;
            continue;
        }
        int on = 1;
        setsockopt(handle, SOL_SOCKET, SO_REUSEADDR, &on, sizeof on);
        if (bind(handle, entry->ai_addr, entry->ai_addrlen) != 0) {
            last = errno;
            close(handle);
            continue;
        }
        if (listen(handle, SOMAXCONN) != 0) {
            last = errno;
            close(handle);
            continue;
        }
        struct sockaddr_storage bound;
        memset(&bound, 0, sizeof bound);
        socklen_t length = sizeof bound;
        char text[INET6_ADDRSTRLEN + 4] = {0};
        charon_nw_sockaddr_text((const struct sockaddr *)&bound, text, sizeof text);
        charon_nw_sockaddr_port((const struct sockaddr *)&bound);
        if (getsockname(handle, (struct sockaddr *)&bound, &length) == 0) {
            CharonNWEndpoint *endpoint = [[CharonNWEndpoint alloc] init];
            endpoint->_type = nw_endpoint_type_address;
            endpoint->_address = (__bridge_transfer NSData *)
                charon_nw_sockaddr_data((const struct sockaddr *)&bound, (socklen_t)length);
            char address[INET6_ADDRSTRLEN + 4] = {0};
            if (charon_nw_sockaddr_text((const struct sockaddr *)&bound, address, sizeof address))
                endpoint->_hostname = @(address);
            uint16_t bound_port = charon_nw_sockaddr_port((const struct sockaddr *)&bound);
            endpoint->_port = [NSString stringWithFormat:@"%u", bound_port];
            listener->_localEndpoint = endpoint;
        }
        charon_nw_set_nonblocking(handle);
        listener->_socket = handle;
        freeaddrinfo(list);
        return;
    }
    freeaddrinfo(list);
    errno = last;
    charon_listener_report(listener, nw_listener_state_failed, charon_listener_posix());
}

nw_listener_t nw_listener_create(nw_parameters_t parameters)
{
    if (!parameters)
        return NULL;
    CharonNWListener *listener = [[CharonNWListener alloc] init];
    listener->_parameters = parameters;
    listener->_socket = -1;
    listener->_connections = [NSMutableArray array];
    listener->_newConnectionLimit = UINT32_MAX;
    listener->_value = nw_listener_state_invalid;
    return listener;
}

nw_listener_t nw_listener_create_with_port(const char *port, nw_parameters_t parameters)
{
    if (!port || !parameters)
        return NULL;
    nw_listener_t listener = nw_listener_create(parameters);
    if (!listener)
        return NULL;
    CharonNWParameters *value = (CharonNWParameters *)parameters;
    CharonNWEndpoint *local = [[CharonNWEndpoint alloc] init];
    local->_type = nw_endpoint_type_address;
    local->_port = @(port);
    value->_localEndpoint = local;
    return listener;
}

nw_listener_t nw_listener_create_with_connection(nw_connection_t connection, nw_parameters_t parameters)
{
    if (!connection)
        return NULL;
    int handle = -1;
    CharonNWEndpoint *remote = NULL;
    nw_parameters_t connection_parameters = NULL;
    (void)remote;
    if (!CharonNWConnectionTakeSocket(connection, &handle, &remote, &connection_parameters))
        return NULL;
    /* A listener of a connection is a listener of the socket that connection already has: the handle is
       taken over, and the connection itself is left with nothing to listen on. */
    CharonNWListener *listener = (CharonNWListener *)nw_listener_create(connection_parameters ? connection_parameters : parameters);
    if (!listener) {
        close(handle);
        return NULL;
    }
    charon_nw_set_nonblocking(handle);
    listener->_socket = handle;
    listener->_localEndpoint = remote;
    if (listener->_socket >= 0)
        listen(listener->_socket, SOMAXCONN);
    return listener;
}

void nw_listener_set_queue(nw_listener_t listener, dispatch_queue_t queue)
{
    if (listener)
        ((CharonNWListener *)listener)->_queue = queue;
}

void nw_listener_set_state_changed_handler(nw_listener_t listener, nw_listener_state_changed_handler_t handler)
{
    if (listener)
        ((CharonNWListener *)listener)->_state = [handler copy];
}

void nw_listener_set_new_connection_handler(nw_listener_t listener, nw_listener_new_connection_handler_t handler)
{
    if (listener)
        ((CharonNWListener *)listener)->_newConnection = [handler copy];
}


void nw_listener_set_advertised_endpoint_changed_handler(nw_listener_t listener, nw_listener_advertised_endpoint_changed_handler_t handler)
{
    if (listener)
        ((CharonNWListener *)listener)->_advertisedChanged = [handler copy];
}

void nw_listener_set_advertise_descriptor(nw_listener_t listener, nw_advertise_descriptor_t advertise_descriptor)
{
    if (listener)
        ((CharonNWListener *)listener)->_advertise = (CharonNWAdvertiseDescriptor *)advertise_descriptor;
}

uint16_t nw_listener_get_port(nw_listener_t listener)
{
    CharonNWListener *value = (CharonNWListener *)listener;
    if (!value || !value->_localEndpoint || !value->_localEndpoint->_port.length)
        return 0;
    return (uint16_t)atoi(value->_localEndpoint->_port.UTF8String);
}

void nw_listener_start(nw_listener_t listener)
{
    if (!listener)
        return;
    CharonNWListener *self = (CharonNWListener *)listener;
    @synchronized(self) {
        if (self->_started || self->_cancelled || !self->_queue)
            return;
        self->_started = YES;
    }
    dispatch_async(self->_queue, ^{
        if (self->_cancelled)
            return;
        charon_listener_report(self, nw_listener_state_waiting, nil);
        charon_listener_open(self);
        if (self->_cancelled || self->_socket < 0)
            return;
        self->_acceptSource = charon_nw_read_source(self->_socket, self->_queue);
        if (self->_acceptSource) {
            __weak CharonNWListener *weak = self;
            dispatch_source_set_event_handler(self->_acceptSource, ^{
                CharonNWListener *strong = weak;
                if (strong && !strong->_cancelled)
                    charon_listener_accept(strong);
            });
        }
        charon_listener_advertise(self);
        charon_listener_report(self, nw_listener_state_ready, nil);
    });
}

void nw_listener_cancel(nw_listener_t listener)
{
    if (!listener)
        return;
    CharonNWListener *self = (CharonNWListener *)listener;
    dispatch_block_t stop = ^{
        @synchronized(self) {
            if (self->_cancelled)
                return;
            self->_cancelled = YES;
        }
        if (self->_acceptSource) {
            dispatch_source_cancel(self->_acceptSource);
            self->_acceptSource = nil;
            self->_socket = -1;
        }
        if (self->_socket >= 0) {
            close(self->_socket);
            self->_socket = -1;
        }
        charon_listener_withdraw(self);
        /* Every connection this listener produced is cancelled with it, which is what the header's
           "no handler is called after it" means for the connections it handed over. */
        for (nw_connection_t connection in [self->_connections copy]) {
            nw_connection_cancel(connection);
        }
        [self->_connections removeAllObjects];
        self->_state = nil;
        self->_newConnection = nil;
        self->_newConnectionGroup = nil;
        self->_advertisedChanged = nil;
        charon_listener_report(self, nw_listener_state_cancelled, nil);
    };
    if (self->_queue)
        dispatch_async(self->_queue, stop);
    else
        stop();
}
