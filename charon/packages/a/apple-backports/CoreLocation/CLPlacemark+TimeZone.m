#import <CoreLocation/CoreLocation.h>

@implementation CLPlacemark (CharonTimeZone)

- (NSTimeZone *)timeZone
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSLog(@"CLPlacemark.timeZone is nil on iOS 6: the placemark of the release carries no time zone");
    });
    return nil;
}

@end
