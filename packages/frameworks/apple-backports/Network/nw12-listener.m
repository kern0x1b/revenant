#import "RevenantNW.h"
#include <mach/mach_time.h>
#include <stdio.h>
#import "RevenantNWSupport.h"
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

@interface RevenantNWListener : NSObject <OS_nw_listener> {
@public
    nw_parameters_t _parameters;
    nw_endpoint_t _endpoint;
    RevenantNWEndpoint *_localEndpoint;
    RevenantNWAdvertiseDescriptor *_advertise;
    RevenantNWEndpoint *_advertisedEndpoint;
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

@implementation RevenantNWListener
@end

void RevenantNWListenerSetNewConnectionGroup(nw_listener_t value, nw_listener_new_connection_group_handler_t handler)
{
    if (value)
        ((RevenantNWListener *)value)->_newConnectionGroup = [handler copy];
}

void RevenantNWListenerSetNewConnectionLimit(nw_listener_t value, uint32_t new_connection_limit)
{
    if (value)
        ((RevenantNWListener *)value)->_newConnectionLimit = new_connection_limit;
}

uint32_t RevenantNWListenerGetNewConnectionLimit(nw_listener_t value)
{
    RevenantNWListener *listener = (RevenantNWListener *)value;
    return listener ? listener->_newConnectionLimit : 0;
}

static void revenant_listener_report(RevenantNWListener *listener, nw_listener_state_t state, RevenantNWError *error)
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

static RevenantNWError *revenant_listener_posix(void)
{
    RevenantNWError *error = [[RevenantNWError alloc] init];
    error->_domain = nw_error_domain_posix;
    error->_code = errno;
    return error;
}

static BOOL revenant_listener_is_secure(nw_parameters_t parameters)
{
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    for (RevenantNWProtocolOptions *options in value->_stack->_application) {
        if ([options->_definition->_family isEqualToString:@"nw_tls"])
            return YES;
    }
    return NO;
}

static void revenant_listener_adopt(RevenantNWListener *listener, int handle)
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
    RevenantNWConnectionAttach(connection, handle, YES);
    @synchronized(listener) {
        [listener->_connections addObject:(id)connection];
    }
    __weak RevenantNWListener *weak = listener;
    if (getenv("REVENANT_TRACE_CONNECTION")) {
        extern int revenant_nw_connection_socket(nw_connection_t connection);
        fprintf(stderr, "[revenant] adopt accepted=%d the-connection-holds=%d\n", handle,
                revenant_nw_connection_socket(connection));
    }
    if (!RevenantNWConnectionHasQueue(connection))
        nw_connection_set_queue(connection, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    nw_connection_set_state_changed_handler(connection, ^(nw_connection_state_t state, nw_error_t error) {
        RevenantNWListener *strong = weak;
        if (getenv("REVENANT_TRACE_LISTENER"))
            fprintf(stderr, "[revenant] listener: state %d on %p queue %p handler %p newConnection %p\n",
                    state, (__bridge void *)listener, strong ? (__bridge void *)strong->_queue : NULL,
                    (__bridge void *)listener, strong ? (__bridge void *)strong->_newConnection : NULL);
        if (state != nw_connection_state_ready || !strong || !strong->_newConnection)
            return;
        strong->_newConnection(connection);
    });
    nw_connection_start(connection);
}

#define REVENANT_LISTENER_BATCH 16

static void revenant_listener_accept(RevenantNWListener *listener)
{
    for (int taken = 0; taken < REVENANT_LISTENER_BATCH; taken++) {
        int handle = accept(listener->_socket, NULL, NULL);
        if (handle < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR)
                return;
            if (errno == EMFILE || errno == ENFILE) {
                return;
            }
            revenant_listener_report(listener, nw_listener_state_failed, revenant_listener_posix());
            return;
        }
        revenant_listener_adopt(listener, handle);
    }
}

static void revenant_listener_advertise(RevenantNWListener *listener)
{
    RevenantNWAdvertiseDescriptor *descriptor = (RevenantNWAdvertiseDescriptor *)listener->_advertise;
    if (!descriptor)
        return;
    NSString *name = descriptor->_bonjourName.length ? descriptor->_bonjourName : @"";
    NSString *type = descriptor->_bonjourType ?: @"";
    NSString *domain = descriptor->_bonjourDomain.length ? descriptor->_bonjourDomain : @"local.";
    RevenantNWEndpoint *published = [[RevenantNWEndpoint alloc] init];
    published->_type = nw_endpoint_type_bonjour_service;
    published->_bonjourName = name;
    published->_bonjourType = type;
    published->_bonjourDomain = domain;
    published->_port = listener->_localEndpoint ? listener->_localEndpoint->_port : @"0";
    if (descriptor->_txtRecordObject || descriptor->_txtRecord.length) {
        nw_txt_record_t record = descriptor->_txtRecordObject
            ? descriptor->_txtRecordObject
            : nw_txt_record_create_with_bytes((const uint8_t *)descriptor->_txtRecord.bytes, descriptor->_txtRecord.length);
        published->_txtRecord = (RevenantNWTxtRecord *)record;
    }
    listener->_service = [[NSNetService alloc] initWithDomain:domain type:type name:name];
    if (listener->_service)
        [listener->_service publish];
    listener->_advertisedEndpoint = published;
    if (listener->_advertisedChanged)
        listener->_advertisedChanged((nw_endpoint_t)published, YES);
}

static void revenant_listener_withdraw(RevenantNWListener *listener)
{
    if (!listener->_service)
        return;
    [listener->_service stop];
    listener->_service = nil;
    if (listener->_advertisedChanged && listener->_advertisedEndpoint)
        listener->_advertisedChanged((nw_endpoint_t)listener->_advertisedEndpoint, NO);
    listener->_advertisedEndpoint = nil;
}

static void revenant_listener_open(RevenantNWListener *listener)
{
    RevenantNWParameters *parameters = (RevenantNWParameters *)listener->_parameters;
    listener->_secure = revenant_listener_is_secure(listener->_parameters);
    uint16_t port = 0;
    RevenantNWEndpoint *local = parameters->_localEndpoint;
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
        revenant_listener_report(listener, nw_listener_state_failed, revenant_listener_posix());
        return;
    }
    int last = EADDRNOTAVAIL;
    for (struct addrinfo *entry = list; entry; entry = entry->ai_next) {
        int handle = revenant_nw_blocking_socket(entry->ai_family, entry->ai_socktype, entry->ai_protocol);
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
        revenant_nw_sockaddr_text((const struct sockaddr *)&bound, text, sizeof text);
        revenant_nw_sockaddr_port((const struct sockaddr *)&bound);
        if (getsockname(handle, (struct sockaddr *)&bound, &length) == 0) {
            RevenantNWEndpoint *endpoint = [[RevenantNWEndpoint alloc] init];
            endpoint->_type = nw_endpoint_type_address;
            endpoint->_address = (__bridge_transfer NSData *)
                revenant_nw_sockaddr_data((const struct sockaddr *)&bound, (socklen_t)length);
            char address[INET6_ADDRSTRLEN + 4] = {0};
            if (revenant_nw_sockaddr_text((const struct sockaddr *)&bound, address, sizeof address))
                endpoint->_hostname = @(address);
            uint16_t bound_port = revenant_nw_sockaddr_port((const struct sockaddr *)&bound);
            endpoint->_port = [NSString stringWithFormat:@"%u", bound_port];
            listener->_localEndpoint = endpoint;
        }
        revenant_nw_set_nonblocking(handle);
        listener->_socket = handle;
        freeaddrinfo(list);
        return;
    }
    freeaddrinfo(list);
    errno = last;
    revenant_listener_report(listener, nw_listener_state_failed, revenant_listener_posix());
}

nw_listener_t nw_listener_create(nw_parameters_t parameters)
{
    if (!parameters)
        return NULL;
    RevenantNWListener *listener = [[RevenantNWListener alloc] init];
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
    RevenantNWParameters *value = (RevenantNWParameters *)parameters;
    RevenantNWEndpoint *local = [[RevenantNWEndpoint alloc] init];
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
    RevenantNWEndpoint *remote = NULL;
    nw_parameters_t connection_parameters = NULL;
    (void)remote;
    if (!RevenantNWConnectionTakeSocket(connection, &handle, &remote, &connection_parameters))
        return NULL;
    RevenantNWListener *listener = (RevenantNWListener *)nw_listener_create(connection_parameters ? connection_parameters : parameters);
    if (!listener) {
        close(handle);
        return NULL;
    }
    revenant_nw_set_nonblocking(handle);
    listener->_socket = handle;
    listener->_localEndpoint = remote;
    if (listener->_socket >= 0)
        listen(listener->_socket, SOMAXCONN);
    return listener;
}

void nw_listener_set_queue(nw_listener_t listener, dispatch_queue_t queue)
{
    if (listener)
        ((RevenantNWListener *)listener)->_queue = queue;
}

void nw_listener_set_state_changed_handler(nw_listener_t listener, nw_listener_state_changed_handler_t handler)
{
    if (listener)
        ((RevenantNWListener *)listener)->_state = [handler copy];
}

void nw_listener_set_new_connection_handler(nw_listener_t listener, nw_listener_new_connection_handler_t handler)
{
    if (listener)
        ((RevenantNWListener *)listener)->_newConnection = [handler copy];
}


void nw_listener_set_advertised_endpoint_changed_handler(nw_listener_t listener, nw_listener_advertised_endpoint_changed_handler_t handler)
{
    if (listener)
        ((RevenantNWListener *)listener)->_advertisedChanged = [handler copy];
}

void nw_listener_set_advertise_descriptor(nw_listener_t listener, nw_advertise_descriptor_t advertise_descriptor)
{
    if (listener)
        ((RevenantNWListener *)listener)->_advertise = (RevenantNWAdvertiseDescriptor *)advertise_descriptor;
}

uint16_t nw_listener_get_port(nw_listener_t listener)
{
    RevenantNWListener *value = (RevenantNWListener *)listener;
    if (!value || !value->_localEndpoint || !value->_localEndpoint->_port.length)
        return 0;
    return (uint16_t)atoi(value->_localEndpoint->_port.UTF8String);
}

void nw_listener_start(nw_listener_t listener)
{
    if (!listener)
        return;
    RevenantNWListener *self = (RevenantNWListener *)listener;
    @synchronized(self) {
        if (self->_started || self->_cancelled || !self->_queue)
            return;
        self->_started = YES;
    }
    dispatch_async(self->_queue, ^{
        if (self->_cancelled)
            return;
        revenant_listener_report(self, nw_listener_state_waiting, nil);
        revenant_listener_open(self);
        if (self->_cancelled || self->_socket < 0)
            return;
        self->_acceptSource = revenant_nw_read_source(self->_socket, self->_queue);
        if (self->_acceptSource) {
            __weak RevenantNWListener *weak = self;
            dispatch_source_set_event_handler(self->_acceptSource, ^{
                RevenantNWListener *strong = weak;
                if (strong && !strong->_cancelled)
                    revenant_listener_accept(strong);
            });
        }
        revenant_listener_advertise(self);
        revenant_listener_report(self, nw_listener_state_ready, nil);
    });
}

void nw_listener_cancel(nw_listener_t listener)
{
    if (!listener)
        return;
    RevenantNWListener *self = (RevenantNWListener *)listener;
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
        revenant_listener_withdraw(self);
        for (nw_connection_t connection in [self->_connections copy]) {
            nw_connection_cancel(connection);
        }
        [self->_connections removeAllObjects];
        self->_state = nil;
        self->_newConnection = nil;
        self->_newConnectionGroup = nil;
        self->_advertisedChanged = nil;
        revenant_listener_report(self, nw_listener_state_cancelled, nil);
    };
    if (self->_queue)
        dispatch_async(self->_queue, stop);
    else
        stop();
}
