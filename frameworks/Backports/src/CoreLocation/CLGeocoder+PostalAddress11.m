#import <CoreLocation/CoreLocation.h>
#import <Contacts/Contacts.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface RevenantContacts : NSObject
+ (NSDictionary *)addressBookAddressWithPostalAddress:(CNPostalAddress *)address;
@end

@implementation CLGeocoder (RevenantPostalAddress11)

- (void)geocodePostalAddress:(CNPostalAddress *)postalAddress completionHandler:(CLGeocodeCompletionHandler)completionHandler
{
    [self geocodePostalAddress:postalAddress preferredLocale:nil completionHandler:completionHandler];
}

- (void)geocodePostalAddress:(CNPostalAddress *)postalAddress preferredLocale:(NSLocale *)locale completionHandler:(CLGeocodeCompletionHandler)completionHandler
{
    [self geocodeAddressDictionary:[RevenantContacts addressBookAddressWithPostalAddress:postalAddress] completionHandler:completionHandler];
}

@end
