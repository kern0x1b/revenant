#import "RevenantPhotosPicker.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

typedef NS_ENUM(NSInteger, RevenantFilterKind) {
    RevenantFilterImages,
    RevenantFilterVideos,
    RevenantFilterLivePhotos,
    RevenantFilterAny
};

@implementation PHPickerFilter {
    RevenantFilterKind _kind;
    NSArray<PHPickerFilter *> *_subfilters;
}

+ (PHPickerFilter *)revenant_filterOfKind:(RevenantFilterKind)kind subfilters:(NSArray *)subfilters
{
    PHPickerFilter *filter = [[self alloc] init];
    filter->_kind = kind;
    filter->_subfilters = [subfilters copy];
    return filter;
}

+ (PHPickerFilter *)imagesFilter
{
    return [self revenant_filterOfKind:RevenantFilterImages subfilters:nil];
}

+ (PHPickerFilter *)videosFilter
{
    return [self revenant_filterOfKind:RevenantFilterVideos subfilters:nil];
}

+ (PHPickerFilter *)livePhotosFilter
{
    return [self revenant_filterOfKind:RevenantFilterLivePhotos subfilters:nil];
}

+ (PHPickerFilter *)anyFilterMatchingSubfilters:(NSArray<PHPickerFilter *> *)subfilters
{
    return [self revenant_filterOfKind:RevenantFilterAny subfilters:subfilters];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSArray<NSString *> *)revenant_mediaTypes
{
    switch (_kind) {
    case RevenantFilterImages:
        return @[@"public.image"];
    case RevenantFilterVideos:
        return @[@"public.movie"];
    case RevenantFilterLivePhotos:
        return @[];
    case RevenantFilterAny: {
        NSMutableArray *types = [NSMutableArray array];
        for (PHPickerFilter *subfilter in _subfilters)
            for (NSString *type in [subfilter revenant_mediaTypes])
                if (![types containsObject:type])
                    [types addObject:type];
        return types;
    }
    }
    return @[];
}

@end
