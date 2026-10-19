#import <Foundation/Foundation.h>
#import <Network/Network.h>

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

#ifndef CHARON_SEAM
#define CHARON_SEAM __attribute__((visibility("default")))
#endif
CHARON_SEAM nw_interface_t charon_interface_named(const char *name);
