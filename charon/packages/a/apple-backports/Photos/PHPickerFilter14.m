#import "CharonPhotosPicker.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

typedef NS_ENUM(NSInteger, CharonFilterKind) {
    CharonFilterImages,
    CharonFilterVideos,
    CharonFilterLivePhotos,
    CharonFilterAny
};

@implementation PHPickerFilter {
    CharonFilterKind _kind;
    NSArray<PHPickerFilter *> *_subfilters;
}

+ (PHPickerFilter *)charon_filterOfKind:(CharonFilterKind)kind subfilters:(NSArray *)subfilters
{
    PHPickerFilter *filter = [[self alloc] init];
    filter->_kind = kind;
    filter->_subfilters = [subfilters copy];
    return filter;
}

+ (PHPickerFilter *)imagesFilter
{
    return [self charon_filterOfKind:CharonFilterImages subfilters:nil];
}

+ (PHPickerFilter *)videosFilter
{
    return [self charon_filterOfKind:CharonFilterVideos subfilters:nil];
}

+ (PHPickerFilter *)livePhotosFilter
{
    return [self charon_filterOfKind:CharonFilterLivePhotos subfilters:nil];
}

+ (PHPickerFilter *)anyFilterMatchingSubfilters:(NSArray<PHPickerFilter *> *)subfilters
{
    return [self charon_filterOfKind:CharonFilterAny subfilters:subfilters];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSArray<NSString *> *)charon_mediaTypes
{
    switch (_kind) {
    case CharonFilterImages:
        return @[@"public.image"];
    case CharonFilterVideos:
        return @[@"public.movie"];
    case CharonFilterLivePhotos:
        return @[];
    case CharonFilterAny: {
        NSMutableArray *types = [NSMutableArray array];
        for (PHPickerFilter *subfilter in _subfilters)
            for (NSString *type in [subfilter charon_mediaTypes])
                if (![types containsObject:type])
                    [types addObject:type];
        return types;
    }
    }
    return @[];
}

@end
