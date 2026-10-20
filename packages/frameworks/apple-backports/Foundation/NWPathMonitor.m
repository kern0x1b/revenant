#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <net/if.h>
#include <sys/ioctl.h>
#include <string.h>
#import "RevenantNWPathMonitor.h"
#import <dlfcn.h>
#import <netinet/in.h>
#import <resolv.h>
#import <sys/socket.h>

@interface RevenantNWInterface : REVENANT_NW_OBJECT(OS_nw_interface)
@end


@implementation RevenantNWInterface {
@public
    NSString *_name;
    uint32_t _index;
    nw_interface_type_t _type;
}
@end

@implementation RevenantNWPath {
@public
    nw_path_status_t _status;
    BOOL _expensive, _ipv4, _ipv6, _dns;
    NSArray<RevenantNWInterface *> *_interfaces;
}
@end

@implementation RevenantNWPathMonitor
@end

#define REVENANT_IFI_TYPE_OTHER       1
#define REVENANT_IFI_TYPE_ETHERNET    6
#define REVENANT_IFI_TYPE_SOFT_LOOPBACK 24
#define REVENANT_IFI_TYPE_CELLULAR    0xff

static BOOL revenant_path_wants(nw_interface_type_t required, nw_interface_type_t type, BOOL reachable, BOOL cellular,
                              BOOL hasAddress)
{
    if (required != nw_interface_type_other)
        return type == required;
    if (type == nw_interface_type_loopback)
        return NO;
    if (!reachable)
        return NO;
    if (type == nw_interface_type_other)
        return hasAddress;
    return (type == nw_interface_type_cellular) == cellular;
}

static nw_interface_type_t revenant_type_of(const struct ifaddrs *item)
{
    for (const struct ifaddrs *link = item; link; link = link->ifa_next) {
        if (!link->ifa_addr || link->ifa_addr->sa_family != AF_LINK || !link->ifa_data || strcmp(link->ifa_name, item->ifa_name) != 0)
            continue;
        const struct if_data *data = (const struct if_data *)link->ifa_data;
        switch (data->ifi_type) {
        case REVENANT_IFI_TYPE_SOFT_LOOPBACK:
            return nw_interface_type_loopback;
        case REVENANT_IFI_TYPE_CELLULAR:
            return nw_interface_type_cellular;
        case REVENANT_IFI_TYPE_ETHERNET:
            return nw_interface_type_wifi;
        default:
            return nw_interface_type_other;
        }
    }
    if (item->ifa_flags & IFF_POINTOPOINT) {
        int probe = socket(AF_INET, SOCK_DGRAM, 0);
        BOOL gateway = NO;
        if (probe >= 0) {
            struct ifreq request;
            memset(&request, 0, sizeof request);
            strncpy(request.ifr_name, item->ifa_name, IFNAMSIZ - 1);
            gateway = ioctl(probe, SIOCGIFDSTADDR, &request) == 0;
            close(probe);
        }
        return gateway ? nw_interface_type_cellular : nw_interface_type_other;
    }
    if (item->ifa_flags & IFF_LOOPBACK)
        return nw_interface_type_loopback;
    return nw_interface_type_wifi;
}

nw_interface_type_t revenant_path_interface_type(const struct ifaddrs *item);

static BOOL revenant_usable_v4(const struct sockaddr *address)
{
    const struct sockaddr_in *v4 = (const struct sockaddr_in *)address;
    uint32_t host = ntohl(v4->sin_addr.s_addr);
    return (host >> 16) != 0xA9FE && host != 0;
}

static BOOL revenant_usable_v6(const struct sockaddr *address)
{
    const struct sockaddr_in6 *v6 = (const struct sockaddr_in6 *)address;
    return !IN6_IS_ADDR_LINKLOCAL(&v6->sin6_addr) && !IN6_IS_ADDR_UNSPECIFIED(&v6->sin6_addr) && !IN6_IS_ADDR_LOOPBACK(&v6->sin6_addr);
}

static BOOL revenant_has_nameserver(void)
{
    static int (*initialise)(struct __res_state *);
    static void (*destroy)(struct __res_state *);
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *image = dlopen("/usr/lib/libresolv.dylib", RTLD_NOW);
        initialise = image ? dlsym(image, "res_9_ninit") : NULL;
        destroy = image ? dlsym(image, "res_9_ndestroy") : NULL;
    });
    if (!initialise || !destroy)
        return NO;
    struct __res_state state;
    memset(&state, 0, sizeof state);
    if (initialise(&state) != 0)
        return NO;
    BOOL has = state.nscount > 0;
    destroy(&state);
    return has;
}

static RevenantNWInterface *revenant_interface(const char *name, nw_interface_type_t type)
{
    RevenantNWInterface *interface = [[RevenantNWInterface alloc] init];
    interface->_name = @(name);
    interface->_index = if_nametoindex(name);
    interface->_type = type;
    return interface;
}

REVENANT_SEAM nw_interface_t revenant_interface_named(const char *name)
{
    if (if_nametoindex(name) == 0)
        return nil;
    nw_interface_type_t type = nw_interface_type_other;
    struct ifaddrs *list = NULL;
    if (getifaddrs(&list) == 0) {
        for (const struct ifaddrs *item = list; item; item = item->ifa_next) {
            if (strcmp(item->ifa_name, name) == 0) {
                type = revenant_type_of(item);
                break;
            }
        }
        freeifaddrs(list);
    }
    return (nw_interface_t)revenant_interface(name, type);
}

static RevenantNWPath *revenant_path(SCNetworkReachabilityRef reachability, RevenantNWPathMonitor *monitor)
{
    RevenantNWPath *path = [[RevenantNWPath alloc] init];
    SCNetworkReachabilityFlags flags = 0;
    SCNetworkReachabilityGetFlags(reachability, &flags);
    BOOL reachable = (flags & kSCNetworkReachabilityFlagsReachable) != 0;
    BOOL required = (flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0;
    BOOL cellular = NO;
#if TARGET_OS_IPHONE
    cellular = (flags & kSCNetworkReachabilityFlagsIsWWAN) != 0;
#endif
    NSMutableArray *interfaces = [NSMutableArray array];
    BOOL v4 = NO, v6 = NO;
    struct ifaddrs *list = NULL;
    if (getifaddrs(&list) == 0) {
        NSMutableSet *seen = [NSMutableSet set];
        for (struct ifaddrs *item = list; item; item = item->ifa_next) {
            if (!item->ifa_addr || !(item->ifa_flags & IFF_UP) || !(item->ifa_flags & IFF_RUNNING))
                continue;
            nw_interface_type_t type = revenant_type_of(item);
            for (NSNumber *prohibited in monitor->_prohibitedTypes) {
                if ((nw_interface_type_t)prohibited.unsignedIntegerValue == type)
                    goto next;
            }
            BOOL address4 = item->ifa_addr->sa_family == AF_INET && revenant_usable_v4(item->ifa_addr);
            BOOL address6 = item->ifa_addr->sa_family == AF_INET6 && revenant_usable_v6(item->ifa_addr);
            if (!revenant_path_wants(monitor->_required, type, reachable, cellular, address4 || address6))
                continue;
            if (!address4 && !address6)
                continue;
            if (type != nw_interface_type_loopback) {
                v4 = v4 || address4;
                v6 = v6 || address6;
            }
            if (![seen containsObject:@(item->ifa_name)]) {
                [seen addObject:@(item->ifa_name)];
                [interfaces addObject:revenant_interface(item->ifa_name, type)];
            }
        next:;
        }
        freeifaddrs(list);
    }
    path->_interfaces = interfaces;
    path->_ipv4 = v4;
    path->_ipv6 = v6;
    path->_dns = interfaces.count && monitor->_required != nw_interface_type_loopback && revenant_has_nameserver();
    path->_expensive = interfaces.count && cellular;
    if (!interfaces.count)
        path->_status = reachable && required ? nw_path_status_satisfiable : nw_path_status_unsatisfied;
    else
        path->_status = required ? nw_path_status_satisfiable : nw_path_status_satisfied;
    return path;
}

nw_path_monitor_t nw_path_monitor_create(void)
{
    RevenantNWPathMonitor *monitor = [[RevenantNWPathMonitor alloc] init];
    monitor->_required = nw_interface_type_other;
    monitor->_prohibitedTypes = [NSMutableArray array];
    return monitor;
}

nw_path_monitor_t nw_path_monitor_create_with_type(nw_interface_type_t required_interface_type)
{
    RevenantNWPathMonitor *monitor = (RevenantNWPathMonitor *)nw_path_monitor_create();
    monitor->_required = required_interface_type;
    return monitor;
}

void nw_path_monitor_set_cancel_handler(nw_path_monitor_t monitor, nw_path_monitor_cancel_handler_t cancel_handler)
{
    ((RevenantNWPathMonitor *)monitor)->_cancel = [cancel_handler copy];
}

void nw_path_monitor_set_update_handler(nw_path_monitor_t monitor, nw_path_monitor_update_handler_t update_handler)
{
    ((RevenantNWPathMonitor *)monitor)->_update = [update_handler copy];
}

void nw_path_monitor_set_queue(nw_path_monitor_t monitor, dispatch_queue_t queue)
{
    ((RevenantNWPathMonitor *)monitor)->_queue = queue;
}

static void revenant_deliver(RevenantNWPathMonitor *monitor, int generation, BOOL always)
{
    if (monitor->_cancelled || generation != monitor->_generation || !monitor->_reachability)
        return;
    RevenantNWPath *path = revenant_path(monitor->_reachability, monitor);
    if (!always && monitor->_last && nw_path_is_equal(monitor->_last, path))
        return;
    monitor->_last = path;
    if (monitor->_update)
        monitor->_update(path);
}

static void revenant_reachability_callback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info)
{
    RevenantNWPathMonitor *monitor = (__bridge RevenantNWPathMonitor *)info;
    revenant_deliver(monitor, monitor->_generation, NO);
}

void nw_path_monitor_start(nw_path_monitor_t handle)
{
    RevenantNWPathMonitor *monitor = (RevenantNWPathMonitor *)handle;
    @synchronized (monitor) {
        if (monitor->_cancelled || !monitor->_queue)
            return;
        int generation = ++monitor->_generation;
        if (!monitor->_reachability) {
            struct sockaddr_in zero;
            memset(&zero, 0, sizeof zero);
            zero.sin_len = sizeof zero;
            zero.sin_family = AF_INET;
            monitor->_reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)&zero);
            SCNetworkReachabilityContext context = {0, (__bridge void *)monitor, CFRetain, CFRelease, NULL};
            SCNetworkReachabilitySetCallback(monitor->_reachability, revenant_reachability_callback, &context);
            SCNetworkReachabilitySetDispatchQueue(monitor->_reachability, monitor->_queue);
        }
        monitor->_started = YES;
        RevenantNWPath *initial = revenant_path(monitor->_reachability, monitor);
        dispatch_async(monitor->_queue, ^{
            if (generation != monitor->_generation)
                return;
            monitor->_last = initial;
            if (monitor->_update)
                monitor->_update(initial);
        });
    }
}

void nw_path_monitor_cancel(nw_path_monitor_t handle)
{
    RevenantNWPathMonitor *monitor = (RevenantNWPathMonitor *)handle;
    dispatch_queue_t queue;
    nw_path_monitor_cancel_handler_t cancel;
    @synchronized (monitor) {
        if (monitor->_cancelled)
            return;
        monitor->_cancelled = YES;
        if (monitor->_reachability) {
            SCNetworkReachabilitySetDispatchQueue(monitor->_reachability, NULL);
            SCNetworkReachabilitySetCallback(monitor->_reachability, NULL, NULL);
            CFRelease(monitor->_reachability);
            monitor->_reachability = NULL;
        }
        queue = monitor->_queue;
        cancel = monitor->_cancel;
    }
    if (queue && cancel)
        dispatch_async(queue, cancel);
}

nw_path_status_t nw_path_get_status(nw_path_t path)
{
    return ((RevenantNWPath *)path)->_status;
}

void nw_path_enumerate_interfaces(nw_path_t path, nw_path_enumerate_interfaces_block_t enumerate_block)
{
    for (RevenantNWInterface *interface in ((RevenantNWPath *)path)->_interfaces) {
        if (!enumerate_block(interface))
            break;
    }
}

bool nw_path_is_equal(nw_path_t first, nw_path_t second)
{
    RevenantNWPath *a = (RevenantNWPath *)first, *b = (RevenantNWPath *)second;
    if (a == b)
        return true;
    if (!a || !b || a->_status != b->_status || a->_expensive != b->_expensive || a->_ipv4 != b->_ipv4 || a->_ipv6 != b->_ipv6 || a->_dns != b->_dns || a->_interfaces.count != b->_interfaces.count)
        return false;
    for (NSUInteger index = 0; index < a->_interfaces.count; index++) {
        if (![a->_interfaces[index]->_name isEqualToString:b->_interfaces[index]->_name])
            return false;
    }
    return true;
}

bool nw_path_is_expensive(nw_path_t path)
{
    return ((RevenantNWPath *)path)->_expensive;
}

bool nw_path_has_ipv4(nw_path_t path)
{
    return ((RevenantNWPath *)path)->_ipv4;
}

bool nw_path_has_ipv6(nw_path_t path)
{
    return ((RevenantNWPath *)path)->_ipv6;
}

bool nw_path_has_dns(nw_path_t path)
{
    return ((RevenantNWPath *)path)->_dns;
}

bool nw_path_uses_interface_type(nw_path_t path, nw_interface_type_t interface_type)
{
    for (RevenantNWInterface *interface in ((RevenantNWPath *)path)->_interfaces) {
        if (interface->_type == interface_type)
            return true;
    }
    return false;
}

nw_endpoint_t nw_path_copy_effective_local_endpoint(nw_path_t path)
{
    return nil;
}

nw_endpoint_t nw_path_copy_effective_remote_endpoint(nw_path_t path)
{
    return nil;
}

nw_interface_type_t nw_interface_get_type(nw_interface_t interface)
{
    return ((RevenantNWInterface *)interface)->_type;
}

const char *nw_interface_get_name(nw_interface_t interface)
{
    return ((RevenantNWInterface *)interface)->_name.UTF8String;
}

uint32_t nw_interface_get_index(nw_interface_t interface)
{
    return ((RevenantNWInterface *)interface)->_index;
}

nw_interface_type_t revenant_path_interface_type(const struct ifaddrs *item)
{
    return revenant_type_of(item);
}

BOOL revenant_path_wants_interface(nw_interface_type_t required, nw_interface_type_t type, BOOL reachable, BOOL cellular,
                                 BOOL hasAddress)
{
    return revenant_path_wants(required, type, reachable, cellular, hasAddress);
}
