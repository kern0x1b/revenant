#import <Foundation/Foundation.h>
#import <DeviceCheck/DeviceCheck.h>

// App Attest is the Secure Enclave's own service: it mints a key pair in hardware and has Apple
// certify it. An iPhone 4S and an iPad 2 have no Secure Enclave - it came with the A7 of the iPhone 5s
// - and no daemon of the release runs the service, so the questions are answered as a device without
// it answers them: not supported, no key, and the error the framework documents (facts/DeviceCheck/
// DCAppAttestService.md). The class sits beside DCDevice in the Foundation library, which is where the
// port's other DeviceCheck class is carried.
//
// Every completion is called from a background queue after the method has returned, with the error
// the framework documents, the way the release's own DCDevice token path does (see
// Foundation/DCDevice.m) and the way the host answers where the service does not run.

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
    // DCErrorFeatureUnsupported, which the header defines as DeviceCheck being unavailable on this device.
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
    // DCErrorInvalidInput, which is what the host answers for any key a caller can name when the
    // service does not run: a well-formed key id and a 32 byte hash come back with this code, because
    // no key of a device that never made one is a key that can be attested.
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
