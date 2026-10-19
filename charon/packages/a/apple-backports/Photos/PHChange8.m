#import "CharonPhotos.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// A change is what ALAssetsLibraryChangedNotification said, and a fetch result or an object is read
// again when it is asked about: facts/Photos/Changes.md.

@interface PHObjectChangeDetails (Charon)
- (instancetype)initWithCharonBefore:(PHObject *)before after:(PHObject *)after contentChanged:(BOOL)contentChanged;
@end

@interface PHFetchResultChangeDetails (Charon)
- (instancetype)initWithCharonBefore:(PHFetchResult *)before after:(PHFetchResult *)after changed:(NSArray *)changed incremental:(BOOL)incremental;
@end

@implementation PHChange {
    NSSet *_updated;
}

- (instancetype)initWithCharonUserInfo:(NSDictionary *)userInfo
{
    self = [super init];
    if (self) {
        // With no user info (what 6.1.3 posts for a write of the application itself) nothing is named, and
        // what the change is asked about is read again all the same.
        NSMutableSet *updated = [NSMutableSet set];
        for (NSString *key in @[ALAssetLibraryUpdatedAssetsKey, ALAssetLibraryUpdatedAssetGroupsKey, ALAssetLibraryInsertedAssetGroupsKey, ALAssetLibraryDeletedAssetGroupsKey]) {
            for (NSURL *url in userInfo[key])
                [updated addObject:url.absoluteString];
        }
        _updated = updated;
    }
    return self;
}

- (BOOL)charon_updated:(PHObject *)object
{
    return [_updated containsObject:[CharonPhotosStore resolvedIdentifier:object.localIdentifier]];
}

- (PHObjectChangeDetails *)changeDetailsForObject:(PHObject *)object
{
    PHObject *after = [object charon_refetched];
    BOOL updated = [self charon_updated:object];
    if (after && !updated && [object charon_sameStateAs:after])
        return nil;
    return [[PHObjectChangeDetails alloc] initWithCharonBefore:object after:after contentChanged:updated && [object isKindOfClass:[PHAsset class]]];
}

// Where each object of a fetch is, by identifier: the objects of a fetch are told apart by it (PHObject's
// isEqual:), and a lookup keeps comparing two fetches linear.
static NSDictionary *charon_positions(PHFetchResult *result)
{
    NSMutableDictionary *positions = [NSMutableDictionary dictionaryWithCapacity:result.count];
    for (NSUInteger index = 0; index < result.count; index++)
        positions[[result[index] localIdentifier]] = @(index);
    return positions;
}

- (PHFetchResultChangeDetails *)changeDetailsForFetchResult:(PHFetchResult *)object
{
    PHFetchResult *after = [object charon_refetched];
    NSDictionary *before = charon_positions(object);
    NSMutableArray *changed = [NSMutableArray array];
    BOOL differs = after.count != object.count;
    for (NSUInteger index = 0; index < after.count; index++) {
        PHObject *now = after[index];
        NSNumber *position = before[now.localIdentifier];
        if (!position) {
            differs = YES;
            continue;
        }
        NSUInteger was = position.unsignedIntegerValue;
        differs = differs || was != index;
        if ([self charon_updated:now] || ![object[was] charon_sameStateAs:now])
            [changed addObject:now];
    }
    if (!differs && changed.count == 0)
        return nil;
    return [[PHFetchResultChangeDetails alloc] initWithCharonBefore:object after:after changed:changed incremental:[object charon_wantsIncrementalChangeDetails]];
}

@end

@implementation PHObjectChangeDetails {
    PHObject *_before;
    PHObject *_after;
    BOOL _contentChanged;
}

- (instancetype)initWithCharonBefore:(PHObject *)before after:(PHObject *)after contentChanged:(BOOL)contentChanged
{
    self = [super init];
    if (self) {
        _before = before;
        _after = after;
        _contentChanged = contentChanged;
    }
    return self;
}

- (PHObject *)objectBeforeChanges
{
    return _before;
}

- (PHObject *)objectAfterChanges
{
    return _after;
}

- (BOOL)assetContentChanged
{
    return _contentChanged;
}

- (BOOL)objectWasDeleted
{
    return _after == nil;
}

@end

@implementation PHFetchResultChangeDetails {
    PHFetchResult *_before;
    PHFetchResult *_after;
    BOOL _incremental;
    NSIndexSet *_removed;
    NSIndexSet *_inserted;
    NSIndexSet *_changed;
}

// Removals are indexes of the fetch before, insertions and changes indexes of the fetch after, as the
// header says. The objects both fetches hold must keep their order among themselves for the change to
// be told incrementally: the release's own order is by date and does not move an asset, so a change
// that reorders is told as not incremental, which the header lets any change be.
- (instancetype)initWithCharonBefore:(PHFetchResult *)before after:(PHFetchResult *)after changed:(NSArray *)changed incremental:(BOOL)incremental
{
    self = [super init];
    if (!self)
        return nil;
    _before = before;
    _after = after;
    NSDictionary *beforePositions = charon_positions(before), *afterPositions = charon_positions(after);
    NSMutableSet *changedIdentifiers = [NSMutableSet setWithCapacity:changed.count];
    for (PHObject *object in changed)
        [changedIdentifiers addObject:object.localIdentifier];
    NSMutableIndexSet *removed = [NSMutableIndexSet indexSet];
    NSMutableArray *kept = [NSMutableArray array];
    for (NSUInteger index = 0; index < before.count; index++) {
        if (afterPositions[[before[index] localIdentifier]])
            [kept addObject:before[index]];
        else
            [removed addIndex:index];
    }
    NSMutableIndexSet *inserted = [NSMutableIndexSet indexSet];
    NSMutableIndexSet *changes = [NSMutableIndexSet indexSet];
    NSUInteger position = 0;
    BOOL ordered = YES;
    for (NSUInteger index = 0; index < after.count; index++) {
        PHObject *object = after[index];
        if (!beforePositions[object.localIdentifier]) {
            [inserted addIndex:index];
            continue;
        }
        ordered = ordered && position < kept.count && [kept[position] isEqual:object];
        position++;
        if ([changedIdentifiers containsObject:object.localIdentifier])
            [changes addIndex:index];
    }
    _incremental = incremental && ordered;
    if (_incremental) {
        _removed = removed;
        _inserted = inserted;
        _changed = changes;
    }
    return self;
}

+ (instancetype)changeDetailsFromFetchResult:(PHFetchResult *)fromResult toFetchResult:(PHFetchResult *)toResult changedObjects:(NSArray *)changedObjects
{
    return [[self alloc] initWithCharonBefore:fromResult after:toResult changed:changedObjects incremental:YES];
}

- (PHFetchResult *)fetchResultBeforeChanges
{
    return _before;
}

- (PHFetchResult *)fetchResultAfterChanges
{
    return _after;
}

- (BOOL)hasIncrementalChanges
{
    return _incremental;
}

- (NSIndexSet *)removedIndexes
{
    return _removed;
}

- (NSArray *)removedObjects
{
    return _removed ? [_before objectsAtIndexes:_removed] : @[];
}

- (NSIndexSet *)insertedIndexes
{
    return _inserted;
}

- (NSArray *)insertedObjects
{
    return _inserted ? [_after objectsAtIndexes:_inserted] : @[];
}

- (NSIndexSet *)changedIndexes
{
    return _changed;
}

- (NSArray *)changedObjects
{
    return _changed ? [_after objectsAtIndexes:_changed] : @[];
}

- (BOOL)hasMoves
{
    return NO;
}

- (void)enumerateMovesWithBlock:(void (^)(NSUInteger fromIndex, NSUInteger toIndex))handler
{
}

@end
