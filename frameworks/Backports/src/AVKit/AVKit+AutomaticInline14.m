#import <AVKit/AVKit.h>
#import <objc/runtime.h>

static const char revenant_can_start_picture_in_picture_automatically_key;

@implementation AVPictureInPictureController (RevenantAutomaticInline14)

- (BOOL)canStartPictureInPictureAutomaticallyFromInline
{
    NSNumber *value = objc_getAssociatedObject(self, &revenant_can_start_picture_in_picture_automatically_key);
    return value ? value.boolValue : NO;
}

- (void)setCanStartPictureInPictureAutomaticallyFromInline:(BOOL)automatic
{
    objc_setAssociatedObject(self, &revenant_can_start_picture_in_picture_automatically_key, @(automatic), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation AVPlayerViewController (RevenantAutomaticInline14)

- (BOOL)canStartPictureInPictureAutomaticallyFromInline
{
    NSNumber *value = objc_getAssociatedObject(self, &revenant_can_start_picture_in_picture_automatically_key);
    return value ? value.boolValue : NO;
}

- (void)setCanStartPictureInPictureAutomaticallyFromInline:(BOOL)automatic
{
    objc_setAssociatedObject(self, &revenant_can_start_picture_in_picture_automatically_key, @(automatic), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
