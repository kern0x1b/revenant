#import "CharonNEHotspot.h"

@implementation NEHotspotHelper

+ (BOOL)registerWithOptions:(NSDictionary<NSString *, NSObject *> * __nullable)options queue:(dispatch_queue_t)queue handler:(NEHotspotHelperHandler)handler
{
    return NO;
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

@implementation NSMutableURLRequest (HotspotHelper)

- (void)bindToHotspotHelperCommand:(NEHotspotHelperCommand *)command
{
}

@end
