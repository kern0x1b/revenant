#import "RevenantPhotos.h"
#import <CoreLocation/CoreLocation.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static PHFetchResult *revenant_collections(NSArray *(^query)(void), PHFetchOptions *options)
{
    return [[PHFetchResult alloc] initWithRevenantQuery:query options:options];
}

static NSArray *revenant_no_collections(void)
{
    return @[];
}

@implementation PHCollection

- (BOOL)canContainAssets
{
    return NO;
}

- (BOOL)canContainCollections
{
    return NO;
}

- (NSString *)localizedTitle
{
    return nil;
}

- (BOOL)canPerformEditOperation:(PHCollectionEditOperation)operation
{
    return NO;
}

+ (PHFetchResult<PHCollection *> *)fetchCollectionsInCollectionList:(PHCollectionList *)collectionList options:(PHFetchOptions *)options
{
    return revenant_collections(^{ return revenant_no_collections(); }, options);
}

+ (PHFetchResult<PHCollection *> *)fetchTopLevelUserCollectionsWithOptions:(PHFetchOptions *)options
{
    return revenant_collections(^{
        return [RevenantPhotosStore collectionsOfGroupTypes:ALAssetsGroupAlbum];
    }, options);
}

@end

@implementation PHAssetCollection {
    ALAssetsGroup *_group;
    NSString *_title;
    PHAssetCollectionType _assetCollectionType;
    PHAssetCollectionSubtype _assetCollectionSubtype;
    NSUInteger _estimatedAssetCount;
}

- (instancetype)initWithRevenantGroup:(ALAssetsGroup *)group
{
    NSString *identifier = [[group valueForProperty:ALAssetsGroupPropertyURL] absoluteString];
    self = [self initWithRevenantLocalIdentifier:identifier];
    if (!self)
        return nil;
    _group = group;
    _title = [group valueForProperty:ALAssetsGroupPropertyName];
    _estimatedAssetCount = group.numberOfAssets;
    switch ([[group valueForProperty:ALAssetsGroupPropertyType] unsignedIntegerValue]) {
    case ALAssetsGroupSavedPhotos:
        _assetCollectionType = PHAssetCollectionTypeSmartAlbum;
        _assetCollectionSubtype = PHAssetCollectionSubtypeSmartAlbumUserLibrary;
        break;
    case ALAssetsGroupEvent:
        _assetCollectionType = PHAssetCollectionTypeAlbum;
        _assetCollectionSubtype = PHAssetCollectionSubtypeAlbumSyncedEvent;
        break;
    case ALAssetsGroupFaces:
        _assetCollectionType = PHAssetCollectionTypeAlbum;
        _assetCollectionSubtype = PHAssetCollectionSubtypeAlbumSyncedFaces;
        break;
    case ALAssetsGroupLibrary:
        _assetCollectionType = PHAssetCollectionTypeAlbum;
        _assetCollectionSubtype = PHAssetCollectionSubtypeAlbumSyncedAlbum;
        break;
    case ALAssetsGroupPhotoStream:
        _assetCollectionType = PHAssetCollectionTypeAlbum;
        _assetCollectionSubtype = PHAssetCollectionSubtypeAlbumMyPhotoStream;
        break;
    default:
        _assetCollectionType = PHAssetCollectionTypeAlbum;
        _assetCollectionSubtype = PHAssetCollectionSubtypeAlbumRegular;
    }
    return self;
}

- (instancetype)initWithRevenantSmartSubtype:(PHAssetCollectionSubtype)subtype
{
    if (subtype != PHAssetCollectionSubtypeSmartAlbumVideos)
        return nil;
    self = [self initWithRevenantLocalIdentifier:[NSString stringWithFormat:@"REVENANT/SMART/%ld", (long)subtype]];
    if (!self)
        return nil;
    _assetCollectionType = PHAssetCollectionTypeSmartAlbum;
    _assetCollectionSubtype = subtype;
    _estimatedAssetCount = subtype == PHAssetCollectionSubtypeSmartAlbumVideos ? NSNotFound : 0;
    switch (subtype) {
    case PHAssetCollectionSubtypeSmartAlbumVideos:
        _title = @"Videos";
        break;
    default:
        return nil;
    }
    return self;
}

- (BOOL)canContainAssets
{
    return YES;
}

- (NSString *)localizedTitle
{
    return _title;
}

- (NSUInteger)estimatedAssetCount
{
    return _estimatedAssetCount;
}

- (NSArray<NSString *> *)localizedLocationNames
{
    return @[];
}

- (NSArray<PHAsset *> *)revenant_assets
{
    if (_group)
        return [RevenantPhotosStore assetsInGroupWithURL:[NSURL URLWithString:self.localIdentifier] filter:nil];
    if (_assetCollectionSubtype == PHAssetCollectionSubtypeSmartAlbumVideos)
        return [RevenantPhotosStore assetsOfSourceTypes:0 filter:[ALAssetsFilter allVideos]];
    return @[];
}

- (PHObject *)revenant_refetched
{
    return [RevenantPhotosStore collectionWithIdentifier:self.localIdentifier];
}

- (BOOL)revenant_sameStateAs:(PHObject *)other
{
    PHAssetCollection *collection = (PHAssetCollection *)other;
    return [collection isKindOfClass:[PHAssetCollection class]] && collection.estimatedAssetCount == _estimatedAssetCount &&
           (collection.localizedTitle == _title || [collection.localizedTitle isEqualToString:_title]);
}

- (ALAssetsGroup *)revenant_group
{
    return _group;
}

+ (NSArray *)revenant_smartSubtypes
{
    return @[@(PHAssetCollectionSubtypeSmartAlbumVideos)];
}

+ (PHFetchResult<PHAssetCollection *> *)fetchAssetCollectionsWithType:(PHAssetCollectionType)type subtype:(PHAssetCollectionSubtype)subtype options:(PHFetchOptions *)options
{
    return revenant_collections(^{
        return [self revenant_collectionsWithType:type subtype:subtype];
    }, options);
}

+ (NSArray *)revenant_collectionsWithType:(PHAssetCollectionType)type subtype:(PHAssetCollectionSubtype)subtype
{
    NSMutableArray *found = [NSMutableArray array];
    if (type == PHAssetCollectionTypeAlbum) {
        for (PHAssetCollection *collection in [RevenantPhotosStore collectionsOfGroupTypes:ALAssetsGroupAlbum | ALAssetsGroupEvent | ALAssetsGroupFaces | ALAssetsGroupLibrary | ALAssetsGroupPhotoStream]) {
            if (subtype == PHAssetCollectionSubtypeAny || collection.assetCollectionSubtype == subtype)
                [found addObject:collection];
        }
    } else if (type == PHAssetCollectionTypeSmartAlbum) {
        for (PHAssetCollection *collection in [RevenantPhotosStore collectionsOfGroupTypes:ALAssetsGroupSavedPhotos]) {
            if (subtype == PHAssetCollectionSubtypeAny || collection.assetCollectionSubtype == subtype)
                [found addObject:collection];
        }
        for (NSNumber *smart in [self revenant_smartSubtypes]) {
            if (subtype == PHAssetCollectionSubtypeAny || subtype == smart.integerValue)
                [found addObject:[[PHAssetCollection alloc] initWithRevenantSmartSubtype:(PHAssetCollectionSubtype)smart.integerValue]];
        }
    }
    return found;
}

+ (PHFetchResult<PHAssetCollection *> *)fetchAssetCollectionsWithLocalIdentifiers:(NSArray<NSString *> *)identifiers options:(PHFetchOptions *)options
{
    NSArray *kept = [identifiers copy];
    return revenant_collections(^{
        NSMutableArray *found = [NSMutableArray array];
        for (NSString *identifier in kept) {
            PHAssetCollection *collection = [RevenantPhotosStore collectionWithIdentifier:identifier];
            if (collection)
                [found addObject:collection];
        }
        return (NSArray *)found;
    }, options);
}

+ (PHFetchResult<PHAssetCollection *> *)fetchAssetCollectionsContainingAsset:(PHAsset *)asset withType:(PHAssetCollectionType)type options:(PHFetchOptions *)options
{
    NSString *identifier = asset.localIdentifier;
    return revenant_collections(^{
        NSMutableArray *found = [NSMutableArray array];
        for (PHAssetCollection *collection in [RevenantPhotosStore collectionsContainingAssetWithIdentifier:identifier]) {
            if (collection.assetCollectionType == type)
                [found addObject:collection];
        }
        return (NSArray *)found;
    }, options);
}

+ (PHFetchResult<PHAssetCollection *> *)fetchAssetCollectionsWithALAssetGroupURLs:(NSArray<NSURL *> *)assetGroupURLs options:(PHFetchOptions *)options
{
    NSMutableArray *identifiers = [NSMutableArray array];
    for (NSURL *url in assetGroupURLs)
        [identifiers addObject:url.absoluteString];
    return [self fetchAssetCollectionsWithLocalIdentifiers:identifiers options:options];
}

@end

@implementation PHCollectionList

- (NSArray<NSString *> *)localizedLocationNames
{
    return @[];
}

+ (PHFetchResult<PHCollectionList *> *)fetchCollectionListsContainingCollection:(PHCollection *)collection options:(PHFetchOptions *)options
{
    return revenant_collections(^{ return revenant_no_collections(); }, options);
}

+ (PHFetchResult<PHCollectionList *> *)fetchCollectionListsWithLocalIdentifiers:(NSArray<NSString *> *)identifiers options:(PHFetchOptions *)options
{
    return revenant_collections(^{ return revenant_no_collections(); }, options);
}

+ (PHFetchResult<PHCollectionList *> *)fetchCollectionListsWithType:(PHCollectionListType)collectionListType subtype:(PHCollectionListSubtype)subtype options:(PHFetchOptions *)options
{
    return revenant_collections(^{ return revenant_no_collections(); }, options);
}

@end
