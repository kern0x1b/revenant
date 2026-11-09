#import "RevenantPhotosPicker.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

typedef NS_ENUM(NSInteger, RevenantFilterKind) {
    RevenantFilterImages,
    RevenantFilterVideos,
    RevenantFilterSubtype,
    RevenantFilterAny
};

@implementation PHPickerFilter {
    RevenantFilterKind _kind;
    PHAssetMediaSubtype _subtype;
    NSArray<PHPickerFilter *> *_subfilters;
}

+ (PHPickerFilter *)revenant_filterOfKind:(RevenantFilterKind)kind subfilters:(NSArray *)subfilters
{
    PHPickerFilter *filter = [[self alloc] init];
    filter->_kind = kind;
    filter->_subfilters = [subfilters copy];
    return filter;
}

+ (PHPickerFilter *)revenant_filterOfSubtype:(PHAssetMediaSubtype)subtype
{
    PHPickerFilter *filter = [self revenant_filterOfKind:RevenantFilterSubtype subfilters:nil];
    filter->_subtype = subtype;
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
    return [self revenant_filterOfSubtype:PHAssetMediaSubtypePhotoLive];
}

+ (PHPickerFilter *)anyFilterMatchingSubfilters:(NSArray<PHPickerFilter *> *)subfilters
{
    return [self revenant_filterOfKind:RevenantFilterAny subfilters:subfilters];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (BOOL)isEqual:(id)other
{
    if (other == self)
        return YES;
    if (![other isKindOfClass:[PHPickerFilter class]])
        return NO;
    PHPickerFilter *filter = other;
    return filter->_kind == _kind && filter->_subtype == _subtype && (filter->_subfilters == _subfilters || [filter->_subfilters isEqual:_subfilters]);
}

- (NSUInteger)hash
{
    return (NSUInteger)_kind ^ (NSUInteger)_subtype ^ _subfilters.hash;
}

- (NSArray<NSString *> *)revenant_mediaTypes
{
    switch (_kind) {
    case RevenantFilterImages:
        return @[@"public.image"];
    case RevenantFilterVideos:
        return @[@"public.movie"];
    case RevenantFilterSubtype:
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
