#import <Foundation/Foundation.h>
#import <AppClip/APActivationPayload.h>

// iOS 6.1.3 launches no App Clip: there is no App Clip binary, no registered App Clip URL, no
// invocation by NFC tag or visual code, and no service that confirms where one happened. So no
// payload is ever made, every payload has no URL, and a confirmation is refused with the error the
// framework documents for exactly this case - an invocation that did not come from a tag or a code
// (facts/AppClip/APActivationPayload.md).

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
    // Nothing of a payload of this release is there to archive: the release launches no App Clip, so
    // it never holds a URL.
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
