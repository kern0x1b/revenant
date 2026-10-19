#import "CharonNEHotspot.h"

/* The manager of the configurations an application applies. The port never applies one: the join is the private
   WiFiUtils route, which the coordinator has not ruled on (facts/NetworkExtension/Hotspot.md). So an application
   gets what the host gives one without the hotspot entitlement, measured in tests/backports/host/netext-hotspot/:
   applyConfiguration fails once, on the main queue, with NEHotspotConfigurationErrorInternal; the remove calls
   return and change nothing; getConfiguredSSIDs answers nil, once, on the main queue. */
@implementation NEHotspotConfigurationManager

+ (NEHotspotConfigurationManager *)sharedManager
{
    static NEHotspotConfigurationManager *manager;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        manager = [[NEHotspotConfigurationManager alloc] init];
    });
    return manager;
}

- (void)applyConfiguration:(NEHotspotConfiguration *)configuration completionHandler:(void (^)(NSError * __nullable))completionHandler
{
    NSError *error = [NSError errorWithDomain:NEHotspotConfigurationErrorDomain code:NEHotspotConfigurationErrorInternal userInfo:nil];
    dispatch_async(dispatch_get_main_queue(), ^{ completionHandler(error); });
}

- (void)removeConfigurationForSSID:(NSString *)SSID
{
    /* Nothing is applied, so nothing is saved to remove. */
}

- (void)removeConfigurationForHS20DomainName:(NSString *)domainName
{
    /* Nothing is applied, so nothing is saved to remove. */
}

- (void)getConfiguredSSIDsWithCompletionHandler:(void (^)(NSArray<NSString *> * __nullable))completionHandler
{
    dispatch_async(dispatch_get_main_queue(), ^{ completionHandler(nil); });
}

@end
