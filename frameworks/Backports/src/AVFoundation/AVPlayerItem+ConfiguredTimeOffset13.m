#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

static const char revenant_configured_time_offset_key;

@implementation AVPlayerItem (RevenantConfiguredTimeOffset13)

- (NSTimeInterval)configuredTimeOffsetFromLive
{
    NSNumber *value = objc_getAssociatedObject(self, &revenant_configured_time_offset_key);
    return value ? value.doubleValue : 0;
}

- (void)setConfiguredTimeOffsetFromLive:(NSTimeInterval)offset
{
    objc_setAssociatedObject(self, &revenant_configured_time_offset_key, @(offset), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
