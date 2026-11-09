#import "RevenantPhotosPicker.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

static NSString *const revenant_image_type = @"public.image";
static NSString *const revenant_movie_type = @"public.movie";

static NSMutableSet<NSString *> *revenant_every_media_type(void)
{
    return [NSMutableSet setWithObjects:revenant_image_type, revenant_movie_type, nil];
}

static NSSet<NSString *> *revenant_media_types_of(PHPickerFilter *filter)
{
    return [NSSet setWithArray:[filter revenant_mediaTypes]];
}

static PHPickerFilter *revenant_filter_naming(NSSet<NSString *> *types)
{
    BOOL images = [types containsObject:revenant_image_type];
    BOOL movies = [types containsObject:revenant_movie_type];
    if (images && movies)
        return [PHPickerFilter anyFilterMatchingSubfilters:@[[PHPickerFilter imagesFilter], [PHPickerFilter videosFilter]]];
    if (images)
        return [PHPickerFilter imagesFilter];
    if (movies)
        return [PHPickerFilter videosFilter];
    return [PHPickerFilter livePhotosFilter];
}

@implementation PHPickerFilter (RevenantFilter15)

+ (PHPickerFilter *)panoramasFilter
{
    return [PHPickerFilter revenant_filterOfSubtype:PHAssetMediaSubtypePhotoPanorama];
}

+ (PHPickerFilter *)screenshotsFilter
{
    return [PHPickerFilter revenant_filterOfSubtype:PHAssetMediaSubtypePhotoScreenshot];
}

+ (PHPickerFilter *)screenRecordingsFilter
{
    return [PHPickerFilter revenant_filterOfSubtype:PHAssetMediaSubtypeVideoScreenRecording];
}

+ (PHPickerFilter *)slomoVideosFilter
{
    return [PHPickerFilter revenant_filterOfSubtype:PHAssetMediaSubtypeVideoHighFrameRate];
}

+ (PHPickerFilter *)timelapseVideosFilter
{
    return [PHPickerFilter revenant_filterOfSubtype:PHAssetMediaSubtypeVideoTimelapse];
}

+ (PHPickerFilter *)playbackStyleFilter:(PHAssetPlaybackStyle)playbackStyle
{
    if (playbackStyle == PHAssetPlaybackStyleImage)
        return [PHPickerFilter imagesFilter];
    if (playbackStyle == PHAssetPlaybackStyleVideo)
        return [PHPickerFilter videosFilter];
    return [PHPickerFilter livePhotosFilter];
}

+ (PHPickerFilter *)allFilterMatchingSubfilters:(NSArray<PHPickerFilter *> *)subfilters
{
    NSMutableSet<NSString *> *types = revenant_every_media_type();
    for (PHPickerFilter *subfilter in subfilters)
        [types intersectSet:revenant_media_types_of(subfilter)];
    return revenant_filter_naming(types);
}

+ (PHPickerFilter *)notFilterOfSubfilter:(PHPickerFilter *)subfilter
{
    NSMutableSet<NSString *> *types = revenant_every_media_type();
    [types minusSet:revenant_media_types_of(subfilter)];
    return revenant_filter_naming(types);
}

@end
