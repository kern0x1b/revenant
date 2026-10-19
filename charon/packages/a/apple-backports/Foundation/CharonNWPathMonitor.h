/*
 * The path monitor of the Foundation library, declared for the files that reach into it.
 *
 * The monitor itself is in NWPathMonitor.m with the calls that arrived in iOS 12; a call of a later
 * release is in a file of its own - modules/apple/backports.lua splits an object that exports the
 * symbols of two introductions - and needs the monitor's own state to answer, which is what this
 * header is for. The interface is declared here, the implementation is there.
 */

#import <Foundation/Foundation.h>
#import <Network/Network.h>

/* The same two spellings the Network library takes, for the same reason: above iOS 6.0 an nw_object is
   an NSObject adopting the type's protocol (nw_object.h:28) and below it is a plain C struct pointer
   with no protocol declared by any header (nw_object.h:32), so a path or a monitor is an NSObject here
   on both sides and nothing below 6.0 names a protocol that does not exist. */
#if OS_OBJECT_USE_OBJC
#define CHARON_NW_OBJECT(protocol) NSObject <protocol>
#else
#define CHARON_NW_OBJECT(protocol) NSObject
#endif
#import <SystemConfiguration/SystemConfiguration.h>

@interface CharonNWPath : CHARON_NW_OBJECT(OS_nw_path)
@end

@interface CharonNWPathMonitor : CHARON_NW_OBJECT(OS_nw_path_monitor) {
@public
    nw_interface_type_t _required;
    NSMutableArray *_prohibitedTypes;
    dispatch_queue_t _queue;
    nw_path_monitor_update_handler_t _update;
    nw_path_monitor_cancel_handler_t _cancel;
    SCNetworkReachabilityRef _reachability;
    CharonNWPath *_last;
    BOOL _started, _cancelled;
    int _generation;
}
@end

/* A seam: the library exports it for the Swift Network module, which links against it on the device, so the gate keeps it in the
   dylib (modules/apple/backports.lua, seam_symbols). The interface a zone names (`en0` in `fe80::1%en0`), nil when the kernel has
   none of that name. The Swift value types of Network's addresses read it (NWPathMonitor.m, charon_interface_named). */
#ifndef CHARON_SEAM
#define CHARON_SEAM __attribute__((visibility("default")))
#endif
CHARON_SEAM nw_interface_t charon_interface_named(const char *name);
