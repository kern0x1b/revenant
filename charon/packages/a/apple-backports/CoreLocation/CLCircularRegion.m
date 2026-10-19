#import <CoreLocation/CoreLocation.h>
#import <objc/message.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation CLCircularRegion

- (instancetype)initWithCenter:(CLLocationCoordinate2D)center radius:(CLLocationDistance)radius identifier:(NSString *)identifier
{
    typedef id (*initializer)(id, SEL, CLLocationCoordinate2D, CLLocationDistance, NSString *);
    return ((initializer)objc_msgSend)(self, sel_registerName("initCircularRegionWithCenter:radius:identifier:"), center, radius, identifier);
}

- (CLLocationCoordinate2D)center
{
    return [super center];
}

- (CLLocationDistance)radius
{
    return [super radius];
}

- (BOOL)containsCoordinate:(CLLocationCoordinate2D)coordinate
{
    return [super containsCoordinate:coordinate];
}

@end
