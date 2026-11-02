#import <dispatch/dispatch.h>

#ifdef __cplusplus
extern "C" {
#endif
static inline dispatch_queue_t RNHostGlobalQueue(long identifier, unsigned long flags)
{
    switch (identifier) {
    case 0x21:
    case 0x19:
        return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, flags);
    case 0x11:
        return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, flags);
    case 0x09:
        return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, flags);
    case 0x15:
        return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, flags);
    default:
        return dispatch_get_global_queue(identifier, flags);
    }
}
#ifdef __cplusplus
}
#endif

#define dispatch_get_global_queue(identifier, flags) RNHostGlobalQueue((identifier), (flags))
