#import <DeviceCheck/DeviceCheck.h>

@implementation DCDevice

@dynamic supported;

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
    return YES;
}

- (void)generateTokenWithCompletionHandler:(void (^)(NSData *token, NSError *error))completion
{
    if (!completion)
        return;
    NSError *error = [NSError errorWithDomain:DCErrorDomain code:DCErrorFeatureUnsupported userInfo:nil];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        completion(nil, error);
    });
}

@end
