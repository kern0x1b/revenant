#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#import "check.h"

static void *wifi_client;
static void (*wifi_set_power)(void *, Boolean);

static BOOL wifi_open(void)
{
    if (wifi_client)
        return YES;
    void *image = dlopen("/System/Library/PrivateFrameworks/MobileWiFi.framework/MobileWiFi", RTLD_NOW);
    void *(*create)(CFAllocatorRef, int) = image ? dlsym(image, "WiFiManagerClientCreate") : NULL;
    wifi_set_power = image ? dlsym(image, "WiFiManagerClientSetPower") : NULL;
    wifi_client = create ? create(kCFAllocatorDefault, 0) : NULL;
    return wifi_client && wifi_set_power;
}

static void set_network(BOOL up)
{
    if (wifi_open())
        wifi_set_power(wifi_client, up);
}

static void restore_network(void)
{
    set_network(YES);
}

static BOOL wait_until(BOOL (^condition)(void), NSTimeInterval seconds)
{
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (!condition() && [until timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    return condition();
}

static NSString *describe(nw_path_t path)
{
    NSMutableArray *interfaces = [NSMutableArray array];
    nw_path_enumerate_interfaces(path, ^bool(nw_interface_t interface) {
        [interfaces addObject:[NSString stringWithFormat:@"%s/%d", nw_interface_get_name(interface), nw_interface_get_type(interface)]];
        return true;
    });
    return [NSString stringWithFormat:@"status=%d expensive=%d ipv4=%d dns=%d wifi=%d cellular=%d interfaces=%@", nw_path_get_status(path), nw_path_is_expensive(path), nw_path_has_ipv4(path), nw_path_has_dns(path),
            nw_path_uses_interface_type(path, nw_interface_type_wifi), nw_path_uses_interface_type(path, nw_interface_type_cellular), [interfaces componentsJoinedByString:@","]];
}

@interface Log : NSObject
@property (nonatomic, strong) NSMutableArray *paths;
@property (nonatomic, strong) NSMutableArray *descriptions;
@end
@implementation Log
- (instancetype)init { if ((self = [super init])) { _paths = [NSMutableArray array]; _descriptions = [NSMutableArray array]; } return self; }
@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            charon_log_to(@(argv[1]));
        if (argc > 2 && !strcmp(argv[2], "on")) {
            set_network(YES);
            return 0;
        }
        CHECK(wifi_open(), "the Wi-Fi manager can be reached");
        atexit(restore_network);
        const char *image = class_getImageName(objc_getClass("CharonNWPathMonitor"));
        CHECK(image && strstr(image, "libFoundationBackports.dylib"), "the monitor comes from the backports library");
        set_network(YES);
        dispatch_queue_t queue = dispatch_queue_create("nwpath.test", DISPATCH_QUEUE_SERIAL);
        Log *log = [Log new];
        nw_path_monitor_t monitor = nw_path_monitor_create();
        __block int cancelled = 0, wrongQueue = 0;
        nw_path_monitor_set_update_handler(monitor, ^(nw_path_t path) {
            if (dispatch_get_current_queue() != queue)
                wrongQueue++;
            @synchronized (log) {
                [log.paths addObject:path];
                [log.descriptions addObject:describe(path)];
            }
        });
        nw_path_monitor_set_cancel_handler(monitor, ^{ cancelled++; });
        nw_path_monitor_set_queue(monitor, queue);
        nw_path_monitor_start(monitor);
        CHECK(wait_until(^BOOL { @synchronized (log) { return log.paths.count >= 1; } }, 30), "a monitor that starts reports the path");
        NSString *first = log.descriptions.firstObject;
        CHECK_EQUAL(first, @"status=1 expensive=0 ipv4=1 dns=1 wifi=1 cellular=0 interfaces=en0/1", "the path of a Wi-Fi network: satisfied, the interface en0 of type Wi-Fi, an address and a name server");
        printf("first: %s\n", first.UTF8String);

        NSUInteger before = log.paths.count;
        set_network(NO);
        CHECK(wait_until(^BOOL { @synchronized (log) { return log.paths.count > before; } }, 60), "taking the network away is reported");
        NSString *down = log.descriptions.lastObject;
        printf("down: %s\n", down.UTF8String);
        CHECK([down hasPrefix:@"status=2"], "as unsatisfied");
        CHECK(!nw_path_is_equal(log.paths.firstObject, log.paths.lastObject), "and the two paths are not equal");
        nw_path_monitor_t cellular = nw_path_monitor_create_with_type(nw_interface_type_cellular);
        __block NSString *cellularPath = nil;
        nw_path_monitor_set_update_handler(cellular, ^(nw_path_t path) { cellularPath = describe(path); });
        nw_path_monitor_set_queue(cellular, queue);
        nw_path_monitor_start(cellular);
        CHECK(wait_until(^BOOL { return cellularPath != nil; }, 30) && [cellularPath hasPrefix:@"status=2"] && [cellularPath hasSuffix:@"interfaces="], "a monitor of cellular says unsatisfied with no interface");
        nw_path_monitor_cancel(cellular);
        nw_path_monitor_t loopback = nw_path_monitor_create_with_type(nw_interface_type_loopback);
        __block NSString *loopbackPath = nil;
        nw_path_monitor_set_update_handler(loopback, ^(nw_path_t path) { loopbackPath = describe(path); });
        nw_path_monitor_set_queue(loopback, queue);
        nw_path_monitor_start(loopback);
        CHECK(wait_until(^BOOL { return loopbackPath != nil; }, 30) && [loopbackPath hasPrefix:@"status=1"] && [loopbackPath hasSuffix:@"interfaces=lo0/4"], "and one of the loopback says satisfied, with lo0, while the network is away");
        nw_path_monitor_cancel(loopback);

        before = log.paths.count;
        set_network(YES);
        CHECK(wait_until(^BOOL { @synchronized (log) { return log.paths.count > before && [log.descriptions.lastObject hasPrefix:@"status=1"]; } }, 120), "the network coming back is reported as satisfied");
        NSString *up = log.descriptions.lastObject;
        printf("up: %s\n", up.UTF8String);
        CHECK_EQUAL(up, first, "the same path as at first");
        CHECK(nw_path_is_equal(log.paths.firstObject, log.paths.lastObject), "and equal to it");
        CHECK(wrongQueue == 0, "every call is on the queue given");

        nw_path_monitor_cancel(monitor);
        CHECK(wait_until(^BOOL { return cancelled == 1; }, 10), "cancelling calls the cancel handler once");
        NSUInteger count = log.paths.count;
        set_network(NO);
        wait_until(^BOOL { return NO; }, 8);
        set_network(YES);
        wait_until(^BOOL { return NO; }, 3);
        CHECK(log.paths.count == count, "and no path comes after it");
        CHECK(wait_until(^BOOL { return YES; }, 1) && cancelled == 1, "nor a second cancel handler");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
