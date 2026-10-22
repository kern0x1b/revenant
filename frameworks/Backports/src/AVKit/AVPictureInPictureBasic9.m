#import <AVKit/AVKit.h>
#import <objc/runtime.h>

static const char revenant_pip_active_key;
static const char revenant_pip_possible_key;
static const char revenant_pip_suspended_key;

@interface AVPictureInPictureController (RevenantBasic9)

- (instancetype)initRevenantWithPlayerLayer:(AVPlayerLayer *)playerLayer;

@end

@implementation AVPictureInPictureController (RevenantBasic9)

- (instancetype)initRevenantWithPlayerLayer:(AVPlayerLayer *)playerLayer
{
    if ((self = [super init])) {
        objc_setAssociatedObject(self, &revenant_pip_active_key, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, &revenant_pip_possible_key, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, &revenant_pip_suspended_key, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return self;
}

- (BOOL)isPictureInPictureActive
{
    return [objc_getAssociatedObject(self, &revenant_pip_active_key) boolValue];
}

- (BOOL)isPictureInPicturePossible
{
    return [objc_getAssociatedObject(self, &revenant_pip_possible_key) boolValue];
}

- (BOOL)isPictureInPictureSuspended
{
    return [objc_getAssociatedObject(self, &revenant_pip_suspended_key) boolValue];
}

- (void)startPictureInPicture
{
    objc_setAssociatedObject(self, &revenant_pip_active_key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)stopPictureInPicture
{
    objc_setAssociatedObject(self, &revenant_pip_active_key, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &revenant_pip_suspended_key, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation AVPlayerViewController (RevenantBasic9)

- (BOOL)showsTimecodes
{
    return NO;
}

- (void)setShowsTimecodes:(BOOL)showsTimecodes
{
}

- (BOOL)allowsVideoFrameAnalysis
{
    return NO;
}

- (void)setAllowsVideoFrameAnalysis:(BOOL)allowsVideoFrameAnalysis
{
}

- (BOOL)canStartPictureInPictureAutomaticallyFromInline
{
    return NO;
}

- (void)setCanStartPictureInPictureAutomaticallyFromInline:(BOOL)canStart
{
}

- (BOOL)canStopPictureInPicture
{
    return YES;
}

- (BOOL)skipBackwardEnabled
{
    return NO;
}

- (void)setSkipBackwardEnabled:(BOOL)enabled
{
}

- (BOOL)skipForwardEnabled
{
    return NO;
}

- (void)setSkipForwardEnabled:(BOOL)enabled
{
}

@end