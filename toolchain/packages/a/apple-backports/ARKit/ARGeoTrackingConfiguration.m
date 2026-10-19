#import <ARKit/ARKit.h>

#import "RevenantARKitPrivate.h"

#pragma clang diagnostic ignored "-Wunguarded-availability-new"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

@implementation ARGeoTrackingConfiguration

- (instancetype)init
{
    self = [super initRevenantCommon];
    return self;
}

+ (instancetype)new { return [[self alloc] init]; }

+ (BOOL)isSupported
{
    return NO;
}

@end
