#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

static const char revenant_background_playback_policy_key;

@implementation AVPlayer (RevenantAudiovisualBackgroundPlaybackPolicy15)

- (NSInteger)audiovisualBackgroundPlaybackPolicy
{
    NSNumber *value = objc_getAssociatedObject(self, &revenant_background_playback_policy_key);
    return value ? value.integerValue : 0;
}

- (void)setAudiovisualBackgroundPlaybackPolicy:(NSInteger)policy
{
    objc_setAssociatedObject(self, &revenant_background_playback_policy_key, @(policy), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
