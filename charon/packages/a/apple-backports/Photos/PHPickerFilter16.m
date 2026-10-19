#import "CharonPhotosPicker.h"

@implementation PHPickerFilter (CharonFilter16)

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
