#import "CharonPhotosPicker.h"

// The three filters of iOS 16, and the reason all three answer the same way. iOS 6's library answers
// ALAssetPropertyType with one of three values - ALAssetTypePhoto, ALAssetTypeVideo or
// ALAssetTypeUnknown, which is what ALAsset.h of the 16.4 SDK says of its own property - and nothing
// in the release names a fourth (_ALAssetTypePanorama and _ALAssetTypePhotoStream are in no held
// release's symbol table; tools/cache-index/first-rung.lua answers NONE for both). A depth effect
// photo is an image with a depth map beside it, a burst is several exposures the library groups, and
// a cinematic video is a video shot in a particular way: none of the three is a property this
// release keeps, so the filter naming one matches nothing and the picker presents nothing, which is
// the answer facts/Photos/PHPicker.md already gives for a live photo. The filters of iOS 15 sit in
// PHPickerFilter15.m beside the reasoning they share.
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
