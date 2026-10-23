#import "RevenantDeviceCheck.h"

@implementation DCAppAttestService

+ (DCAppAttestService *)sharedService
{
    static DCAppAttestService *service;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        service = [[DCAppAttestService alloc] init];
    });
    return service;
}

- (BOOL)isSupported
{
    return NO;
}

- (void)generateKeyWithCompletionHandler:(void (^)(NSString *, NSError *))completionHandler
{
    NSError *error = revenant_device_check_unsupported();
    dispatch_async(dispatch_get_main_queue(), ^{
        completionHandler(nil, error);
    });
}

- (void)attestKey:(NSString *)keyId clientDataHash:(NSData *)clientDataHash completionHandler:(void (^)(NSData *, NSError *))completionHandler
{
    NSError *error = revenant_device_check_unsupported();
    dispatch_async(dispatch_get_main_queue(), ^{
        completionHandler(nil, error);
    });
}

- (void)generateAssertion:(NSString *)keyId clientDataHash:(NSData *)clientDataHash completionHandler:(void (^)(NSData *, NSError *))completionHandler
{
    NSError *error = revenant_device_check_unsupported();
    dispatch_async(dispatch_get_main_queue(), ^{
        completionHandler(nil, error);
    });
}

@end
