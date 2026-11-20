#import <AVKit/AVKit.h>
#import <objc/runtime.h>

static const char revenant_shows_timecodes_key;

@implementation AVPlayerViewController (RevenantShowsTimecodes13)

- (BOOL)showsTimecodes
{
    NSNumber *value = objc_getAssociatedObject(self, &revenant_shows_timecodes_key);
    return value ? value.boolValue : NO;
}

- (void)setShowsTimecodes:(BOOL)showsTimecodes
{
    objc_setAssociatedObject(self, &revenant_shows_timecodes_key, @(showsTimecodes), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
