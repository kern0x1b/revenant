#import "RevenantPhotos.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

@interface PHAssetResource (Revenant)
- (instancetype)initWithRevenantAsset:(PHAsset *)asset;
@end

@implementation PHAssetResource {
    PHAssetResourceType _type;
    NSString *_assetLocalIdentifier;
    NSString *_uniformTypeIdentifier;
    NSString *_originalFilename;
    BOOL _locallyAvailable;
}

- (instancetype)initWithRevenantAsset:(PHAsset *)asset
{
    self = [super init];
    if (!self)
        return nil;
    ALAssetRepresentation *representation = [asset revenant_asset].defaultRepresentation;
    _type = asset.mediaType == PHAssetMediaTypeVideo ? PHAssetResourceTypeVideo : PHAssetResourceTypePhoto;
    _assetLocalIdentifier = asset.localIdentifier;
    _uniformTypeIdentifier = representation.UTI;
    _originalFilename = representation.filename;
    _locallyAvailable = asset.isLocallyAvailable;
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

- (BOOL)isLocallyAvailable
{
    return _locallyAvailable;
}

+ (NSArray<PHAssetResource *> *)assetResourcesForAsset:(PHAsset *)asset
{
    if (![asset revenant_asset])
        return @[];
    return @[[[self alloc] initWithRevenantAsset:asset]];
}

+ (NSArray<PHAssetResource *> *)assetResourcesForLivePhoto:(PHLivePhoto *)livePhoto
{
    return @[];
}

@end
