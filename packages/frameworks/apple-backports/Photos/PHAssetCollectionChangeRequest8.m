#import "RevenantPhotos.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static RevenantPhotosTransaction *revenant_transaction(void)
{
    RevenantPhotosTransaction *transaction = [RevenantPhotosTransaction current];
    if (!transaction)
        [NSException raise:NSInternalInconsistencyException format:@"This method can only be called from inside of -[PHPhotoLibrary performChanges:completionHandler:] or -[PHPhotoLibrary performChangesAndWait:error:]"];
    return transaction;
}

@implementation PHAssetCollectionChangeRequest {
    __weak RevenantPhotosTransaction *_transaction;
    PHAssetCollection *_editing;
    NSString *_title;
    NSString *_token;
    PHObjectPlaceholder *_placeholder;
    NSMutableArray *_addedAssets;
    NSURL *_groupURL;
}

+ (instancetype)creationRequestForAssetCollectionWithTitle:(NSString *)title
{
    RevenantPhotosTransaction *transaction = revenant_transaction();
    PHAssetCollectionChangeRequest *request = [[self alloc] init];
    request->_transaction = transaction;
    request->_title = [title copy];
    request->_token = [[NSUUID UUID].UUIDString stringByAppendingString:@"/L0/ALBUM"];
    request->_placeholder = [[PHObjectPlaceholder alloc] initWithRevenantLocalIdentifier:request->_token];
    [transaction addChange:request];
    return request;
}

+ (void)deleteAssetCollections:(id<NSFastEnumeration>)assetCollections
{
    [revenant_transaction() refuseWithReason:@"iOS 6 has no way to delete an album through AssetsLibrary"];
}

+ (instancetype)changeRequestForAssetCollection:(PHAssetCollection *)assetCollection
{
    RevenantPhotosTransaction *transaction = revenant_transaction();
    if (![assetCollection revenant_group] || assetCollection.assetCollectionSubtype != PHAssetCollectionSubtypeAlbumRegular) {
        [transaction refuseWithReason:@"iOS 6 can only change a regular album, not a smart album or one synced from elsewhere"];
        return nil;
    }
    PHAssetCollectionChangeRequest *request = [[self alloc] init];
    request->_editing = assetCollection;
    [transaction addChange:request];
    return request;
}

+ (instancetype)changeRequestForAssetCollection:(PHAssetCollection *)assetCollection assets:(PHFetchResult<PHAsset *> *)assets
{
    return [self changeRequestForAssetCollection:assetCollection];
}

- (PHObjectPlaceholder *)placeholderForCreatedAssetCollection
{
    return _placeholder;
}

- (NSString *)title
{
    return _editing.localizedTitle ?: _title;
}

- (void)setTitle:(NSString *)title
{
    if (_editing)
        [revenant_transaction() refuseWithReason:@"iOS 6 has no way to rename an existing album through AssetsLibrary"];
    else
        _title = [title copy];
}

- (void)addAssets:(id<NSFastEnumeration>)assets
{
    if (!_editing && !_title)
        [revenant_transaction() refuseWithReason:@"addAssets: needs either a new album or one fetched with changeRequestForAssetCollection:"];
    if (!_addedAssets)
        _addedAssets = [NSMutableArray array];
    for (id asset in assets)
        [_addedAssets addObject:asset];
}

- (void)insertAssets:(id<NSFastEnumeration>)assets atIndexes:(NSIndexSet *)indexes
{
    [revenant_transaction() refuseWithReason:@"iOS 6 can only append assets to an album, not insert them at a position"];
}

- (void)removeAssets:(id<NSFastEnumeration>)assets
{
    [revenant_transaction() refuseWithReason:@"iOS 6 has no way to remove an asset from an album through AssetsLibrary"];
}

- (void)removeAssetsAtIndexes:(NSIndexSet *)indexes
{
    [revenant_transaction() refuseWithReason:@"iOS 6 has no way to remove an asset from an album through AssetsLibrary"];
}

- (void)replaceAssetsAtIndexes:(NSIndexSet *)indexes withAssets:(id<NSFastEnumeration>)assets
{
    [revenant_transaction() refuseWithReason:@"iOS 6 has no way to replace an album's assets through AssetsLibrary"];
}

- (void)moveAssetsAtIndexes:(NSIndexSet *)fromIndexes toIndex:(NSUInteger)toIndex
{
    [revenant_transaction() refuseWithReason:@"iOS 6 albums through AssetsLibrary carry no order to move within"];
}

- (BOOL)revenant_validate:(NSError **)error
{
    if (!_title)
        return YES;
    BOOL taken = NO;
    for (id change in _transaction.changes) {
        if (change == self)
            break;
        if ([change isKindOfClass:[PHAssetCollectionChangeRequest class]] && [((PHAssetCollectionChangeRequest *)change)->_title isEqualToString:_title])
            taken = YES;
    }
    if (!taken && ![RevenantPhotosStore findAlbumWithName:_title found:&taken error:error])
        return NO;
    if (taken) {
        if (error)
            *error = [RevenantPhotosStore errorWithCode:PHPhotosErrorChangeNotSupported
                                               reason:@"iOS 6 cannot make a second album with a name already in use"];
        return NO;
    }
    return YES;
}

- (BOOL)revenant_commit:(NSError **)error
{
    if (_title) {
        ALAssetsGroup *group = [RevenantPhotosStore createAlbumWithName:_title error:error];
        if (!group)
            return NO;
        _groupURL = [group valueForProperty:ALAssetsGroupPropertyURL];
        [RevenantPhotosStore bindPlaceholderIdentifier:_token toIdentifier:_groupURL.absoluteString];
    } else {
        _groupURL = [NSURL URLWithString:[RevenantPhotosStore resolvedIdentifier:_editing.localIdentifier]];
    }
    return YES;
}

- (BOOL)revenant_commitRelations:(NSError **)error
{
    for (id addedAsset in _addedAssets) {
        ALAsset *alAsset = [addedAsset isKindOfClass:[PHObjectPlaceholder class]]
            ? [[RevenantPhotosStore assetWithIdentifier:[addedAsset localIdentifier]] revenant_asset]
            : [addedAsset revenant_asset];
        if (!alAsset) {
            if (error)
                *error = [RevenantPhotosStore errorWithCode:PHPhotosErrorIdentifierNotFound reason:@"an asset added to the album is not in the library: it no longer exists, or no committed change made it"];
            return NO;
        }
        if (![RevenantPhotosStore addAsset:alAsset toGroupWithURL:_groupURL error:error])
            return NO;
    }
    return YES;
}

@end
