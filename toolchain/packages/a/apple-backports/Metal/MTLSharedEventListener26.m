#import "RevenantMetal.h"


@implementation MTLSharedEventListener (Shared)

+ (MTLSharedEventListener *)sharedListener
{
    static MTLSharedEventListener *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[MTLSharedEventListener alloc] initWithDispatchQueue:dispatch_queue_create("revenant.MTLSharedEventListener", DISPATCH_QUEUE_SERIAL)];
    });
    return shared;
}

@end
