#import "CharonPhotos.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

@interface PHAssetResource (Charon)
- (instancetype)initWithCharonAsset:(PHAsset *)asset;
@end

@implementation PHAssetResource {
    PHAssetResourceType _type;
    NSString *_assetLocalIdentifier;
    NSString *_uniformTypeIdentifier;
    NSString *_originalFilename;
}

- (instancetype)initWithCharonAsset:(PHAsset *)asset
{
    self = [super init];
    if (!self)
        return nil;
    ALAssetRepresentation *representation = [asset charon_asset].defaultRepresentation;
    _type = asset.mediaType == PHAssetMediaTypeVideo ? PHAssetResourceTypeVideo : PHAssetResourceTypePhoto;
    _assetLocalIdentifier = asset.localIdentifier;
    _uniformTypeIdentifier = representation.UTI;
    _originalFilename = representation.filename;
    return self;
}

- (PHAssetResourceType)type
{
    return _type;
}

- (NSString *)assetLocalIdentifier
{
    return _assetLocalIdentifier;
}

- (NSString *)uniformTypeIdentifier
{
    return _uniformTypeIdentifier;
}

- (NSString *)originalFilename
{
    return _originalFilename;
}

+ (NSArray<PHAssetResource *> *)assetResourcesForAsset:(PHAsset *)asset
{
    if (![asset charon_asset])
        return @[];
    return @[[[self alloc] initWithCharonAsset:asset]];
}

+ (NSArray<PHAssetResource *> *)assetResourcesForLivePhoto:(PHLivePhoto *)livePhoto
{
    return @[];
}

@end
