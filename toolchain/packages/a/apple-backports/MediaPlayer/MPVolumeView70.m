#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <objc/runtime.h>

static const char RevenantVolumeWarningSliderImageKey;

@implementation MPVolumeView (Revenant70)

- (nullable UIImage *)volumeWarningSliderImage {
    return objc_getAssociatedObject(self, &RevenantVolumeWarningSliderImageKey);
}

- (void)setVolumeWarningSliderImage:(nullable UIImage *)volumeWarningSliderImage {
    objc_setAssociatedObject(self, &RevenantVolumeWarningSliderImageKey, volumeWarningSliderImage,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
