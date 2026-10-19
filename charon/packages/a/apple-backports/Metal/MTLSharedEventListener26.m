#import "CharonMetal.h"


// The shared listener of 26.0: one listener for short notifications, on a serial queue of its own,
// built once and kept. A listener is a dispatch queue and nothing else, so this is the same object a
// caller gets from -initWithDispatchQueue:, made once.

@implementation MTLSharedEventListener (Shared)

+ (MTLSharedEventListener *)sharedListener
{
    static MTLSharedEventListener *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[MTLSharedEventListener alloc] initWithDispatchQueue:dispatch_queue_create("charon.MTLSharedEventListener", DISPATCH_QUEUE_SERIAL)];
    });
    return shared;
}

@end
