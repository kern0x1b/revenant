#import <CoreLocation/CoreLocation.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation CLGeocoder (CharonPreferredLocale)

- (void)geocodeAddressString:(NSString *)addressString inRegion:(CLRegion *)region preferredLocale:(NSLocale *)locale completionHandler:(CLGeocodeCompletionHandler)completionHandler
{
    [self geocodeAddressString:addressString inRegion:region completionHandler:completionHandler];
}

- (void)reverseGeocodeLocation:(CLLocation *)location preferredLocale:(NSLocale *)locale completionHandler:(CLGeocodeCompletionHandler)completionHandler
{
    [self reverseGeocodeLocation:location completionHandler:completionHandler];
}

@end
