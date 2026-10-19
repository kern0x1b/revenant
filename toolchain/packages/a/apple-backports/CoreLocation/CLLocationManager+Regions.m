#import <CoreLocation/CoreLocation.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation CLLocationManager (CharonRegions)

+ (BOOL)isMonitoringAvailableForClass:(Class)regionClass
{
    if (regionClass == [CLCircularRegion class] || regionClass == [CLRegion class])
        return [self regionMonitoringAvailable];
    return NO;
}

+ (BOOL)isRangingAvailable
{
    return NO;
}

- (NSSet *)rangedRegions
{
    return [NSSet set];
}

@end
