#import "RevenantPhotosPicker.h"

@implementation PHPickerFilter (RevenantFilter16)

+ (PHPickerFilter *)depthEffectPhotosFilter
{
    return [PHPickerFilter livePhotosFilter];
}

+ (PHPickerFilter *)burstsFilter
{
    return [PHPickerFilter livePhotosFilter];
}

+ (PHPickerFilter *)cinematicVideosFilter
{
    return [PHPickerFilter livePhotosFilter];
}

@end
