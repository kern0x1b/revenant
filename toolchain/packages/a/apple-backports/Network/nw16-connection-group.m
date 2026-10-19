#import "CharonNW.h"
#import "CharonNWSupport.h"

#include <arpa/inet.h>
#include <errno.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netinet/in.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

@interface CharonNWGroupMessage : NSObject {
@public
    CharonNWEndpoint *_remote;
    CharonNWEndpoint *_local;
    nw_path_t _path;
    CharonNWProtocolMetadata *_ip;
    CharonNWProtocolMetadata *_udp;
    BOOL _answered;
}
@end

@implementation CharonNWGroupMessage
@end

@interface CharonNWConnectionGroup : NSObject <OS_nw_connection_group> {
@public
    CharonNWGroupDescriptor *_descriptor;
    CharonNWParameters *_parameters;
    dispatch_queue_t _queue;
    nw_connection_group_state_changed_handler_t _state;
    nw_connection_group_receive_handler_t _receive;
    nw_connection_group_state_t _value;
    CharonNWEndpoint *_local;
    NSMutableArray *_members;
    nw_path_monitor_t _monitor;
    nw_path_t _path;
    NSMutableDictionary *_inbound;
    uint32_t _maximum;
    BOOL _rejectOversized;
    BOOL _started;
    BOOL _cancelled;
    BOOL _multicast;
    int _socket;
    dispatch_source_t _source;
}
@end

@implementation CharonNWConnectionGroup
@end

static void charon_group_report(CharonNWConnectionGroup *group, nw_connection_group_state_t state,
                                CharonNWError *error)
{
    @synchronized(group) {
        if (group->_cancelled && state != nw_connection_group_state_cancelled)
            return;
        if (group->_value == state && state != nw_connection_group_state_failed && state != nw_connection_group_state_ready)
            return;
        group->_value = state;
    }
    nw_connection_group_state_changed_handler_t handler = group->_state;
    if (handler)
        handler(state, (nw_error_t)error);
}

static CharonNWError *charon_group_error(int code)
{
    CharonNWError *error = [[CharonNWError alloc] init];
    error->_domain = nw_error_domain_posix;
    error->_code = code;
    return error;
}

static struct sockaddr_storage charon_group_address(CharonNWEndpoint *endpoint, socklen_t *out_length)
{
    struct sockaddr_storage address;
    memset(&address, 0, sizeof address);
    socklen_t length = 0;
    if (!endpoint || endpoint->_type != nw_endpoint_type_address)
        return address;
    const struct sockaddr *stored = charon_nw_sockaddr_of((__bridge CFDataRef)endpoint->_address, &length);
    if (!stored || !length)
        return address;
    memcpy(&address, stored, length);
    if (out_length)
        *out_length = length;
    return address;
}

static NSArray *charon_group_members(CharonNWConnectionGroup *group)
{
    NSMutableArray *members = [NSMutableArray array];
    NSMutableArray *endpoints = [NSMutableArray array];
    if (group->_descriptor->_multicastGroup)
        [endpoints addObject:group->_descriptor->_multicastGroup];
    [endpoints addObjectsFromArray:group->_descriptor->_endpoints];
    for (CharonNWEndpoint *endpoint in endpoints) {
        socklen_t length = 0;
        struct sockaddr_storage address = charon_group_address(endpoint, &length);
        if (length)
            [members addObject:[NSData dataWithBytes:&address length:length]];
    }
    return members;
}

static NSData *charon_group_destination(CharonNWConnectionGroup *group)
{
    for (NSData *member in group->_members) {
        const struct sockaddr_in *address = (const struct sockaddr_in *)member.bytes;
        if (address->sin_family != AF_INET)
            continue;
        struct sockaddr_storage destination = *((const struct sockaddr_storage *)member.bytes);
        struct sockaddr_in *out = (struct sockaddr_in *)&destination;
        out->sin_port = htons(group->_local ? (uint16_t)atoi(group->_local->_port.UTF8String) : 0);
        return [NSData dataWithBytes:&destination length:sizeof destination];
    }
    return group->_members.firstObject;
}

static void charon_group_bind_source(CharonNWConnectionGroup *group, struct sockaddr_storage *bound)
{
    socklen_t length = 0;
    struct sockaddr_storage source = charon_group_address(group->_descriptor->_specificSource, &length);
    if (!length)
        return;
    if (source.ss_family == AF_INET && bound->ss_family == AF_INET)
        ((struct sockaddr_in *)bound)->sin_addr = ((struct sockaddr_in *)&source)->sin_addr;
    else if (source.ss_family == AF_INET6 && bound->ss_family == AF_INET6)
        ((struct sockaddr_in6 *)bound)->sin6_addr = ((struct sockaddr_in6 *)&source)->sin6_addr;
}

static int charon_group_type_of_service(nw_content_context_t context)
{
    if (!context)
        return 0;
    __block int value = 0;
    nw_content_context_foreach_protocol_metadata(context, ^(nw_protocol_definition_t definition, nw_protocol_metadata_t metadata) {
        if (nw_protocol_metadata_is_ip(metadata))
            value = (int)nw_ip_metadata_get_service_class(metadata) << 2;
    });
    return value;
}

static void charon_group_send(CharonNWConnectionGroup *group, const struct sockaddr *to, socklen_t length,
                              const void *bytes, size_t size, int service)
{
    if (!bytes || !size || !length)
        return;
    if (!service) {
        (void)sendto(group->_socket, bytes, size, 0, to, length);
        return;
    }
    struct msghdr message;
    struct iovec vector;
    uint8_t control[CMSG_SPACE(sizeof(int))];
    memset(&message, 0, sizeof message);
    memset(control, 0, sizeof control);
    vector.iov_base = (void *)bytes;
    vector.iov_len = size;
    message.msg_name = (void *)to;
    message.msg_namelen = length;
    message.msg_iov = &vector;
    message.msg_iovlen = 1;
    message.msg_control = control;
    message.msg_controllen = sizeof control;
    struct cmsghdr *header = CMSG_FIRSTHDR(&message);
    header->cmsg_level = IPPROTO_IP;
    header->cmsg_type = IP_TOS;
    header->cmsg_len = CMSG_LEN(sizeof(int));
    memcpy(CMSG_DATA(header), &service, sizeof service);
    (void)sendmsg(group->_socket, &message, 0);
}

static void charon_group_open(CharonNWConnectionGroup *group)
{
    if (!group->_multicast) {
        charon_group_report(group, nw_connection_group_state_failed, charon_group_error(EPROTONOSUPPORT));
        return;
    }
    socklen_t length = 0;
    struct sockaddr_storage address = charon_group_address(group->_descriptor->_multicastGroup, &length);
    if (!length) {
        charon_group_report(group, nw_connection_group_state_failed, charon_group_error(EINVAL));
        return;
    }
    uint16_t port = group->_descriptor->_multicastGroup->_port.length
        ? (uint16_t)atoi(group->_descriptor->_multicastGroup->_port.UTF8String) : 0;
    int handle = charon_nw_socket(address.ss_family, SOCK_DGRAM, IPPROTO_UDP);
    if (handle < 0) {
        charon_group_report(group, nw_connection_group_state_failed, charon_group_error(errno));
        return;
    }
    int on = 1;
    setsockopt(handle, SOL_SOCKET, SO_REUSEADDR, &on, sizeof on);
    if (address.ss_family == AF_INET) {
        setsockopt(handle, IPPROTO_IP, IP_PKTINFO, &on, sizeof on);
        struct ifaddrs *list = NULL;
        if (getifaddrs(&list) == 0) {
            for (struct ifaddrs *item = list; item; item = item->ifa_next) {
                if (!item->ifa_addr || item->ifa_addr->sa_family != AF_INET)
                    continue;
                if (!(item->ifa_flags & IFF_UP) || (item->ifa_flags & IFF_LOOPBACK))
                    continue;
                struct ip_mreqn request;
                memset(&request, 0, sizeof request);
                memcpy(&request.imr_multiaddr, &((struct sockaddr_in *)&address)->sin_addr, sizeof request.imr_multiaddr);
                request.imr_address.s_addr = htonl(INADDR_ANY);
                setsockopt(handle, IPPROTO_IP, IP_ADD_MEMBERSHIP, &request, sizeof request);
            }
            freeifaddrs(list);
        }
    } else {
        struct ifaddrs *list = NULL;
        if (getifaddrs(&list) == 0) {
            for (struct ifaddrs *item = list; item; item = item->ifa_next) {
                if (!item->ifa_addr || item->ifa_addr->sa_family != AF_INET6)
                    continue;
                if (!(item->ifa_flags & IFF_UP) || (item->ifa_flags & IFF_LOOPBACK))
                    continue;
                struct ipv6_mreq request;
                memset(&request, 0, sizeof request);
                memcpy(&request.ipv6mr_multiaddr, &((struct sockaddr_in6 *)&address)->sin6_addr, sizeof request.ipv6mr_multiaddr);
                request.ipv6mr_interface = if_nametoindex(item->ifa_name);
                setsockopt(handle, IPPROTO_IPV6, IPV6_JOIN_GROUP, &request, sizeof request);
            }
            freeifaddrs(list);
        }
    }
    struct sockaddr_storage bound;
    memset(&bound, 0, sizeof bound);
    socklen_t bound_length = sizeof bound;
    if (address.ss_family == AF_INET) {
        ((struct sockaddr_in *)&bound)->sin_len = sizeof(struct sockaddr_in);
        ((struct sockaddr_in *)&bound)->sin_family = AF_INET;
        ((struct sockaddr_in *)&bound)->sin_port = htons(port);
    } else {
        ((struct sockaddr_in6 *)&bound)->sin6_len = sizeof(struct sockaddr_in6);
        ((struct sockaddr_in6 *)&bound)->sin6_family = AF_INET6;
        ((struct sockaddr_in6 *)&bound)->sin6_port = htons(port);
    }
    charon_group_bind_source(group, &bound);
    if (bind(handle, (struct sockaddr *)&bound, bound_length) != 0) {
        int failure = errno;
        close(handle);
        charon_group_report(group, nw_connection_group_state_failed, charon_group_error(failure));
        return;
    }
    charon_nw_set_nonblocking(handle);
    memset(&bound, 0, sizeof bound);
    bound_length = sizeof bound;
    if (getsockname(handle, (struct sockaddr *)&bound, &bound_length) == 0) {
        CharonNWEndpoint *local = [[CharonNWEndpoint alloc] init];
        local->_type = nw_endpoint_type_address;
        local->_address = (__bridge_transfer NSData *)
            charon_nw_sockaddr_data((struct sockaddr *)&bound, bound_length);
        char text[INET6_ADDRSTRLEN + 4] = {0};
        if (charon_nw_sockaddr_text((struct sockaddr *)&bound, text, sizeof text))
            local->_hostname = @(text);
        local->_port = [NSString stringWithFormat:@"%u", charon_nw_sockaddr_port((struct sockaddr *)&bound)];
        group->_local = local;
    }
    group->_members = [charon_group_members(group) mutableCopy];
    group->_socket = handle;
}

static const void *charon_group_bytes(dispatch_data_t content, size_t *out_size)
{
    *out_size = 0;
    if (!content)
        return NULL;
    *out_size = dispatch_data_get_size(content);
    if (!*out_size)
        return NULL;
    const void *bytes = NULL;
    size_t size = 0;
    if (!dispatch_data_create_map(content, &bytes, &size) || !bytes)
        return NULL;
    *out_size = size;
    return bytes;
}

void nw_connection_group_reply(nw_connection_group_t group, nw_content_context_t inbound_message,
                          nw_content_context_t outbound_message, dispatch_data_t content);

static void charon_group_read(CharonNWConnectionGroup *group)
{
    for (int taken = 0; taken < 32; taken++) {
        uint8_t buffer[65536];
        struct sockaddr_storage from;
        struct iovec vector;
        struct msghdr message;
        uint8_t control[256];
        memset(&message, 0, sizeof message);
        memset(&from, 0, sizeof from);
        vector.iov_base = buffer;
        vector.iov_len = sizeof buffer;
        message.msg_name = &from;
        message.msg_namelen = sizeof from;
        message.msg_iov = &vector;
        message.msg_iovlen = 1;
        message.msg_control = control;
        message.msg_controllen = sizeof control;
        ssize_t received = recvmsg(group->_socket, &message, 0);
        if (received < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR)
                return;
            charon_group_report(group, nw_connection_group_state_failed, charon_group_error(errno));
            return;
        }
        socklen_t from_length = from.ss_family == AF_INET ? sizeof(struct sockaddr_in) : sizeof(struct sockaddr_in6);
        CharonNWEndpoint *remote = [[CharonNWEndpoint alloc] init];
        remote->_type = nw_endpoint_type_address;
        remote->_address = (__bridge_transfer NSData *)charon_nw_sockaddr_data((struct sockaddr *)&from, from_length);
        char text[INET6_ADDRSTRLEN + 4] = {0};
        if (charon_nw_sockaddr_text((struct sockaddr *)&from, text, sizeof text))
            remote->_hostname = @(text);
        remote->_port = [NSString stringWithFormat:@"%u", charon_nw_sockaddr_port((struct sockaddr *)&from)];
        CharonNWEndpoint *local = nil;
        BOOL ours = NO;
        for (struct cmsghdr *header = (struct cmsghdr *)control; header && CMSG_FIRSTHDR(&message);
             header = CMSG_NXTHDR(&message, header)) {
            if (header->cmsg_level != IPPROTO_IP || header->cmsg_type != IP_PKTINFO)
                continue;
            struct in_pktinfo *info = (struct in_pktinfo *)CMSG_DATA(header);
            local = [[CharonNWEndpoint alloc] init];
            local->_type = nw_endpoint_type_address;
            struct sockaddr_in destination;
            memset(&destination, 0, sizeof destination);
            destination.sin_len = sizeof destination;
            destination.sin_family = AF_INET;
            destination.sin_addr = info->ipi_spec_dst;
            destination.sin_port = group->_local
                ? htons((uint16_t)atoi(group->_local->_port.UTF8String)) : 0;
            local->_address = (__bridge_transfer NSData *)
                charon_nw_sockaddr_data((struct sockaddr *)&destination, sizeof destination);
            local->_hostname = @(inet_ntoa(info->ipi_spec_dst));
            local->_port = group->_local ? group->_local->_port : remote->_port;
            for (NSData *member in group->_members) {
                const struct sockaddr_in *address = member.bytes;
                if (address->sin_family == AF_INET &&
                    memcmp(&address->sin_addr, &info->ipi_spec_dst, sizeof info->ipi_spec_dst) == 0)
                    ours = YES;
            }
        }
        if (!local)
            local = group->_local;
        if (group->_descriptor->_disableUnicastTraffic && !ours)
            continue;
        CharonNWContentContext *context = [[CharonNWContentContext alloc] init];
        context->_identifier = @"";
        context->_metadata = [NSMutableDictionary dictionary];
        context->_relativePriority = 0.5;
        CharonNWGroupMessage *record = [[CharonNWGroupMessage alloc] init];
        record->_remote = remote;
        record->_local = local;
        record->_path = group->_path;
        record->_ip = (CharonNWProtocolMetadata *)nw_ip_create_metadata();
        record->_udp = (CharonNWProtocolMetadata *)nw_udp_create_metadata();
        BOOL complete = (uint32_t)received <= group->_maximum;
        if (!complete && group->_rejectOversized) {
            group->_inbound[(id)context] = record;
            nw_connection_group_reply(group, (nw_content_context_t)context, NULL, NULL);
            [group->_inbound removeObjectForKey:(id)context];
            continue;
        }
        group->_inbound[(id)context] = record;
        nw_connection_group_receive_handler_t handler = group->_receive;
        if (!handler)
            continue;
        dispatch_data_t content = dispatch_data_create(buffer, complete ? (size_t)received : group->_maximum,
                                                       group->_queue, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
        handler(content, (nw_content_context_t)context, complete);
    }
}

nw_connection_group_t nw_connection_group_create(nw_group_descriptor_t group_descriptor,
                                                nw_parameters_t parameters)
{
    if (!group_descriptor || !parameters)
        return NULL;
    CharonNWGroupDescriptor *descriptor = (CharonNWGroupDescriptor *)group_descriptor;
    if (!descriptor->_kind)
        return NULL;
    CharonNWConnectionGroup *group = [[CharonNWConnectionGroup alloc] init];
    group->_descriptor = descriptor;
    group->_parameters = (CharonNWParameters *)parameters;
    group->_members = [NSMutableArray array];
    group->_inbound = [NSMutableDictionary dictionary];
    group->_maximum = UINT32_MAX;
    group->_socket = -1;
    group->_value = nw_connection_group_state_invalid;
    group->_multicast = [descriptor->_kind isEqualToString:@"multicast"];
    return group;
}

nw_group_descriptor_t nw_connection_group_copy_descriptor(nw_connection_group_t group)
{
    return group ? (nw_group_descriptor_t)((CharonNWConnectionGroup *)group)->_descriptor : NULL;
}

nw_parameters_t nw_connection_group_copy_parameters(nw_connection_group_t group)
{
    return group ? (nw_parameters_t)((CharonNWConnectionGroup *)group)->_parameters : NULL;
}

void nw_connection_group_set_queue(nw_connection_group_t group, dispatch_queue_t queue)
{
    if (group)
        ((CharonNWConnectionGroup *)group)->_queue = queue;
}

void nw_connection_group_set_state_changed_handler(nw_connection_group_t group,
                                                   nw_connection_group_state_changed_handler_t handler)
{
    if (group)
        ((CharonNWConnectionGroup *)group)->_state = [handler copy];
}

void nw_connection_group_set_receive_handler(nw_connection_group_t group, uint32_t maximum_message_size,
                                             bool reject_oversized_messages,
                                             nw_connection_group_receive_handler_t receive_handler)
{
    CharonNWConnectionGroup *value = (CharonNWConnectionGroup *)group;
    if (!value)
        return;
    value->_maximum = maximum_message_size;
    value->_rejectOversized = reject_oversized_messages;
    value->_receive = [receive_handler copy];
}

void nw_connection_group_start(nw_connection_group_t group)
{
    if (!group)
        return;
    CharonNWConnectionGroup *self = (CharonNWConnectionGroup *)group;
    @synchronized(self) {
        if (self->_started || self->_cancelled || !self->_queue)
            return;
        self->_started = YES;
    }
    dispatch_async(self->_queue, ^{
        if (self->_cancelled)
            return;
        charon_group_report(self, nw_connection_group_state_waiting, nil);
        charon_group_open(self);
        if (self->_cancelled)
            return;
        if (self->_socket < 0) {
            if (self->_value != nw_connection_group_state_failed)
                charon_group_report(self, nw_connection_group_state_failed, charon_group_error(errno));
            return;
        }
        __weak CharonNWConnectionGroup *weak = self;
        self->_monitor = nw_path_monitor_create();
        nw_path_monitor_set_queue(self->_monitor, self->_queue);
        nw_path_monitor_set_update_handler(self->_monitor, ^(nw_path_t path) {
            CharonNWConnectionGroup *strong = weak;
            if (strong && !strong->_cancelled)
                strong->_path = path;
        });
        nw_path_monitor_start(self->_monitor);
        self->_source = charon_nw_read_source(self->_socket, self->_queue);
        if (!self->_source) {
            charon_group_report(self, nw_connection_group_state_failed, charon_group_error(errno));
            return;
        }
        dispatch_source_set_event_handler(self->_source, ^{
            CharonNWConnectionGroup *strong = weak;
            if (strong && !strong->_cancelled)
                charon_group_read(strong);
        });
        charon_group_report(self, nw_connection_group_state_ready, nil);
    });
}

void nw_connection_group_cancel(nw_connection_group_t group)
{
    if (!group)
        return;
    CharonNWConnectionGroup *self = (CharonNWConnectionGroup *)group;
    dispatch_block_t stop = ^{
        @synchronized(self) {
            if (self->_cancelled)
                return;
            self->_cancelled = YES;
        }
        if (self->_source) {
            dispatch_source_cancel(self->_source);
            self->_source = nil;
            self->_socket = -1;
        }
        if (self->_monitor) {
            nw_path_monitor_cancel(self->_monitor);
            self->_monitor = NULL;
        }
        [self->_inbound removeAllObjects];
        self->_state = nil;
        self->_receive = nil;
        charon_group_report(self, nw_connection_group_state_cancelled, nil);
    };
    if (self->_queue)
        dispatch_async(self->_queue, stop);
    else
        stop();
}

static CharonNWGroupMessage *charon_group_message(nw_connection_group_t group, nw_content_context_t context)
{
    if (!group || !context)
        return NULL;
    return ((CharonNWConnectionGroup *)group)->_inbound[(id)context];
}

nw_endpoint_t nw_connection_group_copy_remote_endpoint_for_message(nw_connection_group_t group,
                                                                   nw_content_context_t context)
{
    CharonNWGroupMessage *message = charon_group_message(group, context);
    return message ? (nw_endpoint_t)message->_remote : NULL;
}

nw_endpoint_t nw_connection_group_copy_local_endpoint_for_message(nw_connection_group_t group,
                                                                  nw_content_context_t context)
{
    CharonNWGroupMessage *message = charon_group_message(group, context);
    return message ? (nw_endpoint_t)message->_local : NULL;
}

nw_path_t nw_connection_group_copy_path_for_message(nw_connection_group_t group, nw_content_context_t context)
{
    CharonNWGroupMessage *message = charon_group_message(group, context);
    return message ? message->_path : NULL;
}

nw_connection_t nw_connection_group_extract_connection_for_message(nw_connection_group_t group,
                                                                  nw_content_context_t context)
{
    CharonNWGroupMessage *message = charon_group_message(group, context);
    if (!message)
        return NULL;
    CharonNWConnectionGroup *self = (CharonNWConnectionGroup *)group;
    [self->_inbound removeObjectForKey:(id)context];
    nw_connection_t connection = nw_connection_create((nw_endpoint_t)message->_remote,
                                                      (nw_parameters_t)self->_parameters);
    if (connection && self->_queue)
        nw_connection_set_queue(connection, self->_queue);
    return connection;
}

void nw_connection_group_reply(nw_connection_group_t group, nw_content_context_t inbound_message,
                               nw_content_context_t outbound_message, dispatch_data_t content)
{
    CharonNWGroupMessage *message = charon_group_message(group, inbound_message);
    if (!message || message->_answered)
        return;
    message->_answered = YES;
    size_t size = 0;
    const void *bytes = charon_group_bytes(content, &size);
    socklen_t length = 0;
    struct sockaddr_storage to = charon_group_address(message->_remote, &length);
    charon_group_send((CharonNWConnectionGroup *)group, (struct sockaddr *)&to, length, bytes, size,
                      charon_group_type_of_service(outbound_message));
    if (nw_content_context_get_is_final(inbound_message))
        [((CharonNWConnectionGroup *)group)->_inbound removeObjectForKey:(id)inbound_message];
}

void nw_connection_group_send_message(nw_connection_group_t group, dispatch_data_t content,
                                      nw_endpoint_t endpoint, nw_content_context_t context,
                                      nw_connection_group_send_completion_t completion)
{
    CharonNWConnectionGroup *self = (CharonNWConnectionGroup *)group;
    if (!self || self->_socket < 0) {
        if (completion)
            completion((nw_error_t)charon_group_error(ENOTCONN));
        return;
    }
    size_t size = 0;
    const void *bytes = charon_group_bytes(content, &size);
    NSMutableArray *targets = [NSMutableArray array];
    if (endpoint) {
        socklen_t length = 0;
        struct sockaddr_storage address = charon_group_address((CharonNWEndpoint *)endpoint, &length);
        if (length)
            [targets addObject:[NSData dataWithBytes:&address length:length]];
    } else {
        NSData *destination = charon_group_destination(self);
        if (destination)
            [targets addObject:destination];
        [targets addObjectsFromArray:self->_members];
    }
    for (NSData *target in targets) {
        charon_group_send(self, target.bytes, (socklen_t)target.length, bytes, size,
                          charon_group_type_of_service(context));
    }
    if (completion)
        completion(NULL);
}

nw_protocol_metadata_t nw_connection_group_copy_protocol_metadata(nw_connection_group_t group,
                                                                  nw_protocol_definition_t definition)
{
    CharonNWConnectionGroup *value = (CharonNWConnectionGroup *)group;
    if (!value || value->_socket < 0 || !definition)
        return NULL;
    if (nw_protocol_definition_is_equal(definition, nw_protocol_copy_ip_definition()))
        return (nw_protocol_metadata_t)nw_ip_create_metadata();
    if (nw_protocol_definition_is_equal(definition, nw_protocol_copy_udp_definition()))
        return (nw_protocol_metadata_t)nw_udp_create_metadata();
    return NULL;
}

nw_protocol_metadata_t nw_connection_group_copy_protocol_metadata_for_message(nw_connection_group_t group,
                                                                             nw_content_context_t context,
                                                                             nw_protocol_definition_t definition)
{
    CharonNWGroupMessage *message = charon_group_message(group, context);
    if (!message || !definition)
        return NULL;
    if (nw_protocol_definition_is_equal(definition, nw_protocol_copy_ip_definition()))
        return (nw_protocol_metadata_t)message->_ip;
    if (nw_protocol_definition_is_equal(definition, nw_protocol_copy_udp_definition()))
        return (nw_protocol_metadata_t)message->_udp;
    return NULL;
}
