#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>

static const char CharonVolumeWarningSliderImageKey;

@implementation MPVolumeView (Charon70)

- (nullable UIImage *)volumeWarningSliderImage {
    return objc_getAssociatedObject(self, &CharonVolumeWarningSliderImageKey);
}

- (void)setVolumeWarningSliderImage:(nullable UIImage *)volumeWarningSliderImage {
    objc_setAssociatedObject(self, &CharonVolumeWarningSliderImageKey, volumeWarningSliderImage,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
