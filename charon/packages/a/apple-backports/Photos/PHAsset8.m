#import "CharonPhotos.h"
#import <CoreLocation/CoreLocation.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation PHAsset {
    ALAsset *_asset;
    PHAssetMediaType _mediaType;
    NSUInteger _pixelWidth;
    NSUInteger _pixelHeight;
    NSDate *_creationDate;
    CLLocation *_location;
    NSTimeInterval _duration;
    PHAssetSourceType _sourceType;
}

- (instancetype)initWithCharonAsset:(ALAsset *)asset sourceType:(PHAssetSourceType)sourceType
{
    ALAssetRepresentation *representation = asset.defaultRepresentation;
    NSURL *url = representation.url ?: [asset valueForProperty:ALAssetPropertyAssetURL];
    NSString *identifier = url.absoluteString;
    self = [self initWithCharonLocalIdentifier:identifier];
    if (!self)
        return nil;
    _asset = asset;
    _sourceType = sourceType;
    NSString *type = [asset valueForProperty:ALAssetPropertyType];
    _mediaType = [type isEqualToString:ALAssetTypePhoto] ? PHAssetMediaTypeImage : [type isEqualToString:ALAssetTypeVideo] ? PHAssetMediaTypeVideo : PHAssetMediaTypeUnknown;
    CGSize dimensions = representation.dimensions;
    _pixelWidth = (NSUInteger)dimensions.width;
    _pixelHeight = (NSUInteger)dimensions.height;
    id date = [asset valueForProperty:ALAssetPropertyDate];
    _creationDate = [date isKindOfClass:[NSDate class]] ? date : nil;
    id location = [asset valueForProperty:ALAssetPropertyLocation];
    _location = [location isKindOfClass:[CLLocation class]] ? location : nil;
    id duration = [asset valueForProperty:ALAssetPropertyDuration];
    _duration = [duration isKindOfClass:[NSNumber class]] ? [duration doubleValue] : 0;
    return self;
}

- (ALAsset *)charon_asset
{
    return _asset;
}

- (PHAssetPlaybackStyle)playbackStyle
{
    return _mediaType == PHAssetMediaTypeImage ? PHAssetPlaybackStyleImage : _mediaType == PHAssetMediaTypeVideo ? PHAssetPlaybackStyleVideo : PHAssetPlaybackStyleUnsupported;
}

- (BOOL)hasAdjustments
{
    return _asset.originalAsset != nil;
}

- (BOOL)canPerformEditOperation:(PHAssetEditOperation)editOperation
{
    return NO;
}

- (PHObject *)charon_refetched
{
    return [CharonPhotosStore assetWithIdentifier:self.localIdentifier];
}

- (BOOL)charon_sameStateAs:(PHObject *)other
{
    PHAsset *asset = (PHAsset *)other;
    return [asset isKindOfClass:[PHAsset class]] && asset.mediaType == _mediaType && asset.pixelWidth == _pixelWidth &&
           asset.pixelHeight == _pixelHeight && asset.duration == _duration && asset.hasAdjustments == self.hasAdjustments &&
           (asset.creationDate == _creationDate || [asset.creationDate isEqualToDate:_creationDate]) &&
           (asset.location == _location || (asset.location && _location && [asset.location distanceFromLocation:_location] == 0));
}

+ (PHFetchResult *)charon_result:(NSArray *(^)(void))query options:(PHFetchOptions *)options
{
    return [[PHFetchResult alloc] initWithCharonQuery:query options:options];
}

+ (PHFetchResult<PHAsset *> *)fetchAssetsWithOptions:(PHFetchOptions *)options
{
    PHAssetSourceType sourceTypes = options.includeAssetSourceTypes;
    return [self charon_result:^{
        return [CharonPhotosStore assetsOfSourceTypes:sourceTypes filter:nil];
    } options:options];
}

+ (PHFetchResult<PHAsset *> *)fetchAssetsWithMediaType:(PHAssetMediaType)mediaType options:(PHFetchOptions *)options
{
    ALAssetsFilter *filter = mediaType == PHAssetMediaTypeImage ? [ALAssetsFilter allPhotos] : mediaType == PHAssetMediaTypeVideo ? [ALAssetsFilter allVideos] : nil;
    PHAssetSourceType sourceTypes = options.includeAssetSourceTypes;
    return [self charon_result:^{
        NSMutableArray *assets = [NSMutableArray array];
        for (PHAsset *asset in [CharonPhotosStore assetsOfSourceTypes:sourceTypes filter:filter]) {
            if (asset.mediaType == mediaType)
                [assets addObject:asset];
        }
        return (NSArray *)assets;
    } options:options];
}

+ (PHFetchResult<PHAsset *> *)fetchAssetsInAssetCollection:(PHAssetCollection *)assetCollection options:(PHFetchOptions *)options
{
    return [self charon_result:^{
        return [assetCollection charon_assets];
    } options:options];
}

+ (PHFetchResult<PHAsset *> *)fetchAssetsWithLocalIdentifiers:(NSArray<NSString *> *)identifiers options:(PHFetchOptions *)options
{
    NSArray *kept = [identifiers copy];
    return [self charon_result:^{
        NSMutableArray *assets = [NSMutableArray array];
        for (NSString *identifier in kept) {
            PHAsset *asset = [CharonPhotosStore assetWithIdentifier:identifier];
            if (asset)
                [assets addObject:asset];
        }
        return (NSArray *)assets;
    } options:options];
}

@end
