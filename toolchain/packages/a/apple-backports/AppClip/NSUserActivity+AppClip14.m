#import <Foundation/Foundation.h>
#import <AppClip/APActivationPayload.h>

@interface NSUserActivity (RevenantAppClip)

@property (nullable, nonatomic, readonly, strong) APActivationPayload *appClipActivationPayload;

@end

@implementation NSUserActivity (RevenantAppClip)

@dynamic appClipActivationPayload;

- (APActivationPayload *)appClipActivationPayload
{
    return nil;
}

@end
