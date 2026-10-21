#import <Foundation/Foundation.h>
#import <AppClip/APActivationPayload.h>

@implementation APActivationPayload

@dynamic URL;

- (NSURL *)URL
{
    return nil;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [super init];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (void)confirmAcquiredInRegion:(CLRegion *)region completionHandler:(void (^)(BOOL inRegion, NSError *error))completionHandler
{
    if (completionHandler) {
        completionHandler(NO, [NSError errorWithDomain:APActivationPayloadErrorDomain
                                                 code:APActivationPayloadErrorCodeDisallowed
                                             userInfo:@{NSLocalizedDescriptionKey: @"The App Clip invocation did not come from an NFC tag or a visual code."}]);
    }
}

@end
