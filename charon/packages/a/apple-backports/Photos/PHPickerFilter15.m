#import "CharonPhotosPicker.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"
// The three class methods below are declared by PHPickerFilter's own @interface, and the primary
// implementation of that class is PHPickerFilter14.m, which is iOS 14.0's object and must not carry a
// 15.0 name. Clang's note that a category is implementing a method its primary class also declares
// is exactly that arrangement, so it is silenced here rather than left to be read as a mistake.
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
// The whole file names PHPickerFilter, which the SDK header marks as introduced in iOS 14, from
// static functions at file scope - and a deployment target of 6.0 is what this library is built for.
// The two helpers below therefore carry the notice on every line, which says nothing about this
// port: the same suppression is the package's own way of building a modern API for a 6.0 target, in
// dozens of its sources - Accelerate's LinearAlgebra8.m, CoreTelephony's
// CTTelephonyNetworkInfo+RadioAccess.m, ARKit's ARConfiguration.m among them - for the same reason.
// Neither a count nor a list of names here: both go stale the day another band adds a file.
#pragma clang diagnostic ignored "-Wunguarded-availability-new"
#pragma clang diagnostic ignored "-Wunguarded-availability"

// The two media types a filter can name, which are the two UIImagePickerController of iOS 6 takes.
// A filter is therefore a set over {image, movie}, and the four sets the port can build are the four
// the SDK's own filters already are: imagesFilter, videosFilter, livePhotosFilter (a live photo is
// neither an image nor a movie to this release, so it names nothing) and anyFilterMatchingSubfilters:
// over the two. Every filter composed below is one of those four, which is why a composition needs
// no state of its own and why two of them are the same object the 14.0 object already returns.
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

// The filter that names exactly this set, built from the SDK's own four. An empty set is the port's
// filter for what the release's picker cannot show: the picker presents nothing and reports no
// results once it has appeared, which is what facts/Photos/PHPicker.md already says of a live photo.
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

// iOS 6's library answers ALAssetPropertyType with one of three values, ALAssetTypePhoto,
// ALAssetTypeVideo or ALAssetTypeUnknown - ALAsset.h of the 16.4 SDK says so of its own property, and
// nothing in the release names a fourth: _ALAssetTypePanorama and _ALAssetTypePhotoStream are in no
// held release's symbol table (tools/cache-index/first-rung.lua, both NONE over the 50 held rungs).
// So a panorama, a screenshot, a screen recording, a slow motion clip and a time lapse are one and
// the same to this release, which keeps no record of any of them, and the filter naming one matches
// nothing. That is not a gap in the filter: it is the whole of what the release can answer, and the
// picker says so by presenting nothing.
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

// The one filter of this release that names something the picker can show. -[PHAsset playbackStyle]
// is the port's own answer for an asset (registry/Photos/ios8.json, PHAsset8.m:49): an image, a
// video, or Unsupported when the library cannot say. The other four cases of the enum - ImageAnimated,
// LivePhoto, VideoLooping, and Unsupported itself - name what the release keeps no record of: a GIF
// animation, a live photo and a looping video are all iOS 9.1's, and none of them is in the library
// this port reads, so the filter built for one matches nothing.
+ (PHPickerFilter *)playbackStyleFilter:(PHAssetPlaybackStyle)playbackStyle
{
    if (playbackStyle == PHAssetPlaybackStyleImage)
        return [PHPickerFilter imagesFilter];
    if (playbackStyle == PHAssetPlaybackStyleVideo)
        return [PHPickerFilter videosFilter];
    return [PHPickerFilter livePhotosFilter];
}

// "AND-ing the filters in a given array": the media types left are the ones every subfilter names.
// An empty array constrains nothing, so the answer is every media type - the reading of the header's
// own word, and the opposite of anyFilterMatchingSubfilters: with the same empty array, which the
// 14.0 object already answers with nothing, as OR-ing over nothing must.
+ (PHPickerFilter *)allFilterMatchingSubfilters:(NSArray<PHPickerFilter *> *)subfilters
{
    NSMutableSet<NSString *> *types = charon_every_media_type();
    for (PHPickerFilter *subfilter in subfilters)
        [types intersectSet:charon_media_types_of(subfilter)];
    return charon_filter_naming(types);
}

// "negating the given filter": what is left of the release's two media types once the subfilter has
// taken its own. Negating a filter that named both leaves nothing, which is the port's empty filter.
+ (PHPickerFilter *)notFilterOfSubfilter:(PHPickerFilter *)subfilter
{
    NSMutableSet<NSString *> *types = charon_every_media_type();
    [types minusSet:charon_media_types_of(subfilter)];
    return charon_filter_naming(types);
}

@end
