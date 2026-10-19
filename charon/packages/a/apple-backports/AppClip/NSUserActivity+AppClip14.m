#import <Foundation/Foundation.h>
#import <AppClip/APActivationPayload.h>

// The system sets the payload of an NSUserActivity when it launches an App Clip by a tag or a
// visual code. iOS 6.1.3 does none of that, so no activity of the release ever carries one and the
// property is nil on every activity there is (facts/AppClip/APActivationPayload.md).

@interface NSUserActivity (CharonAppClip)

@property (nullable, nonatomic, readonly, strong) APActivationPayload *appClipActivationPayload;

@end

@implementation NSUserActivity (CharonAppClip)

@dynamic appClipActivationPayload;

- (APActivationPayload *)appClipActivationPayload
{
    return nil;
}

@end
