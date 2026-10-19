#import <Foundation/Foundation.h>
#import <AppClip/APActivationPayload.h>

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
