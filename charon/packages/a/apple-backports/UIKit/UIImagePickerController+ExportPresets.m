#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static const char CharonImageExportPresetKey;
static const char CharonVideoExportPresetKey;

@implementation UIImagePickerController (CharonExportPresets)

- (UIImagePickerControllerImageURLExportPreset)imageExportPreset
{
    return (UIImagePickerControllerImageURLExportPreset)[objc_getAssociatedObject(self, &CharonImageExportPresetKey) integerValue];
}

- (void)setImageExportPreset:(UIImagePickerControllerImageURLExportPreset)imageExportPreset
{
    objc_setAssociatedObject(self, &CharonImageExportPresetKey, @(imageExportPreset), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)videoExportPreset
{
    return objc_getAssociatedObject(self, &CharonVideoExportPresetKey);
}

- (void)setVideoExportPreset:(NSString *)videoExportPreset
{
    if (videoExportPreset) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSLog(@"UIImagePickerController.videoExportPreset is kept and not applied on iOS 6: the picker transcodes a movie by its videoQuality and takes no export preset");
        });
    }
    objc_setAssociatedObject(self, &CharonVideoExportPresetKey, [videoExportPreset copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
