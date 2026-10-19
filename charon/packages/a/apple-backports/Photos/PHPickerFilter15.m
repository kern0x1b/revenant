#import "CharonPhotosPicker.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

static NSString *const charon_image_type = @"public.image";
static NSString *const charon_movie_type = @"public.movie";

static NSMutableSet<NSString *> *charon_every_media_type(void)
{
    return [NSMutableSet setWithObjects:charon_image_type, charon_movie_type, nil];
}

static NSSet<NSString *> *charon_media_types_of(PHPickerFilter *filter)
{
    return [NSSet setWithArray:[filter charon_mediaTypes]];
}

static PHPickerFilter *charon_filter_naming(NSSet<NSString *> *types)
{
    BOOL images = [types containsObject:charon_image_type];
    BOOL movies = [types containsObject:charon_movie_type];
    if (images && movies)
        return [PHPickerFilter anyFilterMatchingSubfilters:@[[PHPickerFilter imagesFilter], [PHPickerFilter videosFilter]]];
    if (images)
        return [PHPickerFilter imagesFilter];
    if (movies)
        return [PHPickerFilter videosFilter];
    return [PHPickerFilter livePhotosFilter];
}

@implementation PHPickerFilter (CharonFilter15)

+ (PHPickerFilter *)panoramasFilter
{
    return [PHPickerFilter livePhotosFilter];
}

+ (PHPickerFilter *)screenshotsFilter
{
    return [PHPickerFilter livePhotosFilter];
}

+ (PHPickerFilter *)screenRecordingsFilter
{
    return [PHPickerFilter livePhotosFilter];
}

+ (PHPickerFilter *)slomoVideosFilter
{
    return [PHPickerFilter livePhotosFilter];
}

+ (PHPickerFilter *)timelapseVideosFilter
{
    return [PHPickerFilter livePhotosFilter];
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
    NSMutableSet<NSString *> *types = charon_every_media_type();
    for (PHPickerFilter *subfilter in subfilters)
        [types intersectSet:charon_media_types_of(subfilter)];
    return charon_filter_naming(types);
}

+ (PHPickerFilter *)notFilterOfSubfilter:(PHPickerFilter *)subfilter
{
    NSMutableSet<NSString *> *types = charon_every_media_type();
    [types minusSet:charon_media_types_of(subfilter)];
    return charon_filter_naming(types);
}

@end
