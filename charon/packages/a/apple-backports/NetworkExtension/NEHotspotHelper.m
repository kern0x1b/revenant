#import "CharonNEHotspot.h"

/* The helper that an application registers to be handed Wi-Fi commands. No command is ever delivered by the
   port: registration answers NO, the handler is never called, and the other class methods answer as the host
   answers them (tests/backports/host/netext-hotspot/, facts/NetworkExtension/Hotspot.md). */
@implementation NEHotspotHelper

+ (BOOL)registerWithOptions:(NSDictionary<NSString *, NSObject *> * __nullable)options queue:(dispatch_queue_t)queue handler:(NEHotspotHelperHandler)handler
{
    return NO; /* registerWithOptions: answers NO on the host, so no command is ever delivered */
}

+ (BOOL)logoff:(NEHotspotNetwork *)network
{
    return NO;
}

+ (nullable NSArray *)supportedNetworkInterfaces
{
    return nil;
}

@end

/* The (HotspotHelper) category of NSMutableURLRequest: binding a request to a command that is never delivered
   changes nothing, as the host's answer measured for a fresh command shows. */
@implementation NSMutableURLRequest (HotspotHelper)

- (void)bindToHotspotHelperCommand:(NEHotspotHelperCommand *)command
{
    /* binds nothing */
}

@end
