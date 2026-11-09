#import "RevenantPhotosPicker.h"

@implementation PHPickerFilter (RevenantFilter16)

+ (PHPickerFilter *)depthEffectPhotosFilter
{
    return [PHPickerFilter revenant_filterOfSubtype:PHAssetMediaSubtypePhotoDepthEffect];
}

+ (PHPickerFilter *)burstsFilter
{
    return [PHPickerFilter livePhotosFilter];
}

+ (PHPickerFilter *)cinematicVideosFilter
{
    return [PHPickerFilter revenant_filterOfSubtype:PHAssetMediaSubtypeVideoCinematic];
}

@end
