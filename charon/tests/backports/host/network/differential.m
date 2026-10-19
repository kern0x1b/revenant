#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <pthread.h>
#import "check.h"

extern nw_path_monitor_t charonhost_nw_path_monitor_create(void);
extern nw_path_monitor_t charonhost_nw_path_monitor_create_with_type(nw_interface_type_t);
extern void charonhost_nw_path_monitor_set_cancel_handler(nw_path_monitor_t, nw_path_monitor_cancel_handler_t);
extern void charonhost_nw_path_monitor_set_update_handler(nw_path_monitor_t, nw_path_monitor_update_handler_t);
extern void charonhost_nw_path_monitor_set_queue(nw_path_monitor_t, dispatch_queue_t);
extern void charonhost_nw_path_monitor_start(nw_path_monitor_t);
extern void charonhost_nw_path_monitor_cancel(nw_path_monitor_t);
extern nw_path_status_t charonhost_nw_path_get_status(nw_path_t);
extern void charonhost_nw_path_enumerate_interfaces(nw_path_t, nw_path_enumerate_interfaces_block_t);
extern bool charonhost_nw_path_is_equal(nw_path_t, nw_path_t);
extern bool charonhost_nw_path_is_expensive(nw_path_t);
extern bool charonhost_nw_path_has_ipv4(nw_path_t);
extern bool charonhost_nw_path_has_ipv6(nw_path_t);
extern bool charonhost_nw_path_has_dns(nw_path_t);
extern bool charonhost_nw_path_uses_interface_type(nw_path_t, nw_interface_type_t);
extern nw_endpoint_t charonhost_nw_path_copy_effective_local_endpoint(nw_path_t);
extern nw_endpoint_t charonhost_nw_path_copy_effective_remote_endpoint(nw_path_t);
extern nw_interface_type_t charonhost_nw_interface_get_type(nw_interface_t);
extern const char *charonhost_nw_interface_get_name(nw_interface_t);
extern uint32_t charonhost_nw_interface_get_index(nw_interface_t);

static const char *label(NSString *format, ...)
{
    static NSMutableArray *keep;
    if (!keep)
        keep = [NSMutableArray array];
    va_list arguments;
    va_start(arguments, format);
    NSString *string = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    [keep addObject:string];
    return string.UTF8String;
}

typedef struct {
    nw_path_monitor_t (*create)(void);
    nw_path_monitor_t (*create_typed)(nw_interface_type_t);
    void (*set_cancel)(nw_path_monitor_t, nw_path_monitor_cancel_handler_t);
    void (*set_update)(nw_path_monitor_t, nw_path_monitor_update_handler_t);
    void (*set_queue)(nw_path_monitor_t, dispatch_queue_t);
    void (*start)(nw_path_monitor_t);
    void (*cancel)(nw_path_monitor_t);
    nw_path_status_t (*status)(nw_path_t);
    void (*enumerate)(nw_path_t, nw_path_enumerate_interfaces_block_t);
    bool (*equal)(nw_path_t, nw_path_t);
    bool (*expensive)(nw_path_t);
    bool (*ipv4)(nw_path_t);
    bool (*ipv6)(nw_path_t);
    bool (*dns)(nw_path_t);
    bool (*uses)(nw_path_t, nw_interface_type_t);
    nw_endpoint_t (*local)(nw_path_t);
    nw_endpoint_t (*remote)(nw_path_t);
    nw_interface_type_t (*itype)(nw_interface_t);
    const char *(*iname)(nw_interface_t);
    uint32_t (*iindex)(nw_interface_t);
} API;

static API system_api(void)
{
    return (API){(void *)nw_path_monitor_create, (void *)nw_path_monitor_create_with_type, (void *)(void *)nw_path_monitor_set_cancel_handler, (void *)nw_path_monitor_set_update_handler, (void *)nw_path_monitor_set_queue, (void *)nw_path_monitor_start, (void *)nw_path_monitor_cancel, (void *)nw_path_get_status, (void *)nw_path_enumerate_interfaces, (void *)nw_path_is_equal, (void *)nw_path_is_expensive, (void *)nw_path_has_ipv4, (void *)nw_path_has_ipv6, (void *)nw_path_has_dns, (void *)nw_path_uses_interface_type, (void *)nw_path_copy_effective_local_endpoint, (void *)nw_path_copy_effective_remote_endpoint, (void *)nw_interface_get_type, (void *)nw_interface_get_name, (void *)nw_interface_get_index};
}

static API port_api(void)
{
    return (API){(void *)charonhost_nw_path_monitor_create, (void *)charonhost_nw_path_monitor_create_with_type, (void *)charonhost_nw_path_monitor_set_cancel_handler, (void *)charonhost_nw_path_monitor_set_update_handler, (void *)charonhost_nw_path_monitor_set_queue, (void *)charonhost_nw_path_monitor_start, (void *)charonhost_nw_path_monitor_cancel, (void *)charonhost_nw_path_get_status, (void *)charonhost_nw_path_enumerate_interfaces, (void *)charonhost_nw_path_is_equal, (void *)charonhost_nw_path_is_expensive, (void *)charonhost_nw_path_has_ipv4, (void *)charonhost_nw_path_has_ipv6, (void *)charonhost_nw_path_has_dns, (void *)charonhost_nw_path_uses_interface_type, (void *)charonhost_nw_path_copy_effective_local_endpoint, (void *)charonhost_nw_path_copy_effective_remote_endpoint, (void *)charonhost_nw_interface_get_type, (void *)charonhost_nw_interface_get_name, (void *)charonhost_nw_interface_get_index};
}

static NSString *describe(API api, nw_path_t path)
{
    NSMutableSet *interfaces = [NSMutableSet set];
    api.enumerate(path, ^bool(nw_interface_t interface) {
        [interfaces addObject:[NSString stringWithFormat:@"%s/%u/%d", api.iname(interface), api.iindex(interface), api.itype(interface)]];
        return true;
    });
    NSMutableString *out = [NSMutableString stringWithFormat:@"status=%d expensive=%d ipv4=%d ipv6=%d dns=%d", api.status(path), api.expensive(path), api.ipv4(path), api.ipv6(path), api.dns(path)];
    for (int type = 0; type <= 4; type++)
        [out appendFormat:@" uses%d=%d", type, api.uses(path, (nw_interface_type_t)type)];
    [out appendFormat:@" interfaces=%@ local=%d remote=%d", [[[interfaces allObjects] sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","], api.local(path) != nil, api.remote(path) != nil];
    return out;
}

typedef struct {
    NSMutableArray *updates;
    NSMutableArray *queues;
    int cancelled;
} Recording;

static NSString *run(API api, nw_interface_type_t type, BOOL typed, int prohibited, BOOL startTwice, BOOL cancelBeforeUpdate, NSString **log, int *delivered)
{
    dispatch_queue_t queue = dispatch_queue_create("network.test", DISPATCH_QUEUE_SERIAL);
    nw_path_monitor_t monitor = typed ? api.create_typed(type) : api.create();
    NSMutableArray *updates = [NSMutableArray array];
    __block int inline_calls = 0, cancels = 0, wrongQueue = 0;
    pthread_t caller = pthread_self();
    api.set_update(monitor, ^(nw_path_t path) {
        if (pthread_equal(pthread_self(), caller))
            inline_calls++;
        if (dispatch_get_current_queue() != queue)
            wrongQueue++;
        @synchronized (updates) {
            [updates addObject:describe(api, path)];
        }
    });
    api.set_cancel(monitor, ^{
        if (dispatch_get_current_queue() != queue)
            wrongQueue++;
        cancels++;
    });
    api.set_queue(monitor, queue);
    api.start(monitor);
    if (startTwice) {
        usleep(600000);
        api.start(monitor);
    }
    if (!cancelBeforeUpdate)
        usleep(1200000);
    api.cancel(monitor);
    api.cancel(monitor);
    usleep(600000);
    int after;
    @synchronized (updates) {
        after = (int)updates.count;
    }
    usleep(300000);
    @synchronized (updates) {
        *delivered = (int)updates.count;
        *log = [NSString stringWithFormat:@"inline=%d cancels=%d wrongQueue=%d quietAfterCancel=%d", inline_calls, cancels, wrongQueue, after == (int)updates.count];
        return updates.count ? updates.lastObject : @"none";
    }
}

int main(void)
{
    @autoreleasepool {
        API system = system_api(), port = port_api();
        struct { const char *name; nw_interface_type_t type; BOOL typed; int prohibited; BOOL twice; BOOL early; int floor; } cases[] = {
            {"general", 0, NO, -1, NO, NO, -1}, {"general twice", 0, NO, -1, YES, NO, 2}, {"general cancelled at once", 0, NO, -1, NO, YES, -1},
            {"type other", nw_interface_type_other, YES, -1, NO, NO, 1}, {"type wifi", nw_interface_type_wifi, YES, -1, NO, NO, 1}, {"type cellular", nw_interface_type_cellular, YES, -1, NO, NO, -1},
            {"type wired", nw_interface_type_wired, YES, -1, NO, NO, -1}, {"type loopback", nw_interface_type_loopback, YES, -1, NO, NO, -1},
        };
        for (size_t index = 0; index < sizeof cases / sizeof cases[0]; index++) {
            NSString *systemLog, *portLog;
            int systemDelivered = 0, portDelivered = 0;
            NSString *systemLast = run(system, cases[index].type, cases[index].typed, cases[index].prohibited, cases[index].twice, cases[index].early, &systemLog, &systemDelivered);
            NSString *portLast = run(port, cases[index].type, cases[index].typed, cases[index].prohibited, cases[index].twice, cases[index].early, &portLog, &portDelivered);
            CHECK_EQUAL(portLast, systemLast, label(@"%s: the path", cases[index].name));
            CHECK_EQUAL(portLog, systemLog, label(@"%s: the calls", cases[index].name));
            if (cases[index].floor < 0)
                CHECK(portDelivered == systemDelivered, label(@"%s: the updates: port %d, host %d", cases[index].name, portDelivered, systemDelivered));
            else
                CHECK(portDelivered == cases[index].floor && systemDelivered >= cases[index].floor,
                      label(@"%s: the updates: port %d, host %d, floor %d", cases[index].name, portDelivered, systemDelivered, cases[index].floor));
        }
        {
            nw_path_monitor_t a = nw_path_monitor_create(), b = charonhost_nw_path_monitor_create();
            dispatch_queue_t q = dispatch_queue_create("network.equal", DISPATCH_QUEUE_SERIAL);
            __block nw_path_t first = nil, second = nil;
            dispatch_semaphore_t got = dispatch_semaphore_create(0);
            charonhost_nw_path_monitor_set_update_handler(b, ^(nw_path_t p) { if (!first) first = p; else second = p; dispatch_semaphore_signal(got); });
            charonhost_nw_path_monitor_set_queue(b, q);
            charonhost_nw_path_monitor_start(b);
            dispatch_semaphore_wait(got, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
            charonhost_nw_path_monitor_start(b);
            dispatch_semaphore_wait(got, dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC));
            CHECK(first && second && charonhost_nw_path_is_equal(first, second) && charonhost_nw_path_is_equal(first, first), "paths of the same network are equal");
            CHECK(!charonhost_nw_path_is_equal(first, nil), "and not equal to nothing");
            (void)a;
        }
        {
            dispatch_queue_t q = dispatch_queue_create("network.late", DISPATCH_QUEUE_SERIAL);
            nw_path_monitor_t monitor = charonhost_nw_path_monitor_create();
            __block int count = 0;
            charonhost_nw_path_monitor_set_update_handler(monitor, ^(nw_path_t p) { count++; });
            charonhost_nw_path_monitor_start(monitor);
            usleep(500000);
            CHECK(count == 0, "a monitor with no queue reports nothing");
            charonhost_nw_path_monitor_set_queue(monitor, q);
            charonhost_nw_path_monitor_start(monitor);
            usleep(1200000);
            CHECK(count == 1, "and starts once it has one");
            charonhost_nw_path_monitor_cancel(monitor);
        }
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
