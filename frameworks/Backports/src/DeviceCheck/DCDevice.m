#import "RevenantDeviceCheck.h"

NSErrorDomain const DCErrorDomain = @"com.apple.devicecheck.error";

NSError *revenant_device_check_unsupported(void)
{
    return [NSError errorWithDomain:DCErrorDomain code:DCErrorFeatureUnsupported userInfo:nil];
}

@implementation DCDevice

+ (DCDevice *)currentDevice
{
    static DCDevice *device;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        device = [[DCDevice alloc] init];
    });
    return device;
}

- (BOOL)isSupported
{
    return NO;
}

- (void)generateTokenWithCompletionHandler:(void (^)(NSData *, NSError *))completionHandler
{
    NSError *error = revenant_device_check_unsupported();
    dispatch_async(dispatch_get_main_queue(), ^{
        completionHandler(nil, error);
    });
}

@end
