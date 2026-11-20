#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

static const char revenant_preferred_forward_buffer_duration_key;

@implementation AVPlayerItem (RevenantPreferredForwardBufferDuration10)

- (NSTimeInterval)preferredForwardBufferDuration
{
    NSNumber *value = objc_getAssociatedObject(self, &revenant_preferred_forward_buffer_duration_key);
    return value ? value.doubleValue : 0;
}

- (void)setPreferredForwardBufferDuration:(NSTimeInterval)duration
{
    objc_setAssociatedObject(self, &revenant_preferred_forward_buffer_duration_key, @(duration), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
