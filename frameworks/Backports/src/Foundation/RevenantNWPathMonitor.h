#import <Foundation/Foundation.h>
#import <Network/Network.h>

#if OS_OBJECT_USE_OBJC
#define REVENANT_NW_OBJECT(protocol) NSObject <protocol>
#else
#define REVENANT_NW_OBJECT(protocol) NSObject
#endif
#import <SystemConfiguration/SystemConfiguration.h>

@interface RevenantNWPathValue : REVENANT_NW_OBJECT(OS_nw_path)
@end

@interface RevenantNWPathMonitor : REVENANT_NW_OBJECT(OS_nw_path_monitor) {
@public
    nw_interface_type_t _required;
    NSMutableArray *_prohibitedTypes;
    dispatch_queue_t _queue;
    nw_path_monitor_update_handler_t _update;
    nw_path_monitor_cancel_handler_t _cancel;
    SCNetworkReachabilityRef _reachability;
    RevenantNWPathValue *_last;
    BOOL _started, _cancelled;
    int _generation;
}
@end

#ifndef REVENANT_SEAM
#define REVENANT_SEAM __attribute__((visibility("default")))
#endif
REVENANT_SEAM nw_interface_t revenant_interface_named(const char *name);
