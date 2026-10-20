#import "RevenantNEHotspot.h"

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
}

- (void)removeConfigurationForHS20DomainName:(NSString *)domainName
{
}

- (void)getConfiguredSSIDsWithCompletionHandler:(void (^)(NSArray<NSString *> * __nullable))completionHandler
{
    dispatch_async(dispatch_get_main_queue(), ^{ completionHandler(nil); });
}

@end
