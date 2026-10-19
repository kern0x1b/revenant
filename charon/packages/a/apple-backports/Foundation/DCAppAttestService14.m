#import <Foundation/Foundation.h>
#import <DeviceCheck/DeviceCheck.h>

@implementation DCAppAttestService

@dynamic sharedService;

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

- (void)generateKeyWithCompletionHandler:(void (^)(NSString *keyId, NSError *error))completionHandler
{
    if (!completionHandler) {
        return;
    }
    NSError *error = [NSError errorWithDomain:DCErrorDomain code:DCErrorFeatureUnsupported userInfo:nil];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completionHandler(nil, error);
    });
}

- (void)attestKey:(NSString *)keyId clientDataHash:(NSData *)clientDataHash completionHandler:(void (^)(NSData *attestationObject, NSError *error))completionHandler
{
    if (!completionHandler) {
        return;
    }
    NSError *error = [NSError errorWithDomain:DCErrorDomain code:DCErrorInvalidInput userInfo:nil];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completionHandler(nil, error);
    });
}

- (void)generateAssertion:(NSString *)keyId clientDataHash:(NSData *)clientDataHash completionHandler:(void (^)(NSData *assertionObject, NSError *error))completionHandler
{
    if (!completionHandler) {
        return;
    }
    NSError *error = [NSError errorWithDomain:DCErrorDomain code:DCErrorInvalidInput userInfo:nil];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completionHandler(nil, error);
    });
}

@end
