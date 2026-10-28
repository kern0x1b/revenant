#import "RevenantPhotos.h"
#import "RevenantPhotoMoves.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface PHObjectChangeDetails (Revenant)
- (instancetype)initWithRevenantBefore:(PHObject *)before after:(PHObject *)after contentChanged:(BOOL)contentChanged;
@end

@interface PHFetchResultChangeDetails (Revenant)
- (instancetype)initWithRevenantBefore:(PHFetchResult *)before after:(PHFetchResult *)after changed:(NSArray *)changed incremental:(BOOL)incremental;
@end

@implementation PHChange {
    NSSet *_updated;
}

- (instancetype)initWithRevenantUserInfo:(NSDictionary *)userInfo
{
    self = [super init];
    if (self) {
        NSMutableSet *updated = [NSMutableSet set];
        for (NSString *key in @[ALAssetLibraryUpdatedAssetsKey, ALAssetLibraryUpdatedAssetGroupsKey, ALAssetLibraryInsertedAssetGroupsKey, ALAssetLibraryDeletedAssetGroupsKey]) {
            for (NSURL *url in userInfo[key])
                [updated addObject:url.absoluteString];
        }
        _updated = updated;
    }
    return self;
}

- (BOOL)revenant_updated:(PHObject *)object
{
    return [_updated containsObject:[RevenantPhotosStore resolvedIdentifier:object.localIdentifier]];
}

- (PHObjectChangeDetails *)changeDetailsForObject:(PHObject *)object
{
    PHObject *after = [object revenant_refetched];
    BOOL updated = [self revenant_updated:object];
    if (after && !updated && [object revenant_sameStateAs:after])
        return nil;
    return [[PHObjectChangeDetails alloc] initWithRevenantBefore:object after:after contentChanged:updated && [object isKindOfClass:[PHAsset class]]];
}

static NSDictionary *revenant_positions(PHFetchResult *result)
{
    NSMutableDictionary *positions = [NSMutableDictionary dictionaryWithCapacity:result.count];
    for (NSUInteger index = 0; index < result.count; index++)
        positions[[result[index] localIdentifier]] = @(index);
    return positions;
}

- (PHFetchResultChangeDetails *)changeDetailsForFetchResult:(PHFetchResult *)object
{
    PHFetchResult *after = [object revenant_refetched];
    NSDictionary *before = revenant_positions(object);
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
        if ([self revenant_updated:now] || ![object[was] revenant_sameStateAs:now])
            [changed addObject:now];
    }
    if (!differs && changed.count == 0)
        return nil;
    return [[PHFetchResultChangeDetails alloc] initWithRevenantBefore:object after:after changed:changed incremental:[object revenant_wantsIncrementalChangeDetails]];
}

@end

@implementation PHObjectChangeDetails {
    PHObject *_before;
    PHObject *_after;
    BOOL _contentChanged;
}

- (instancetype)initWithRevenantBefore:(PHObject *)before after:(PHObject *)after contentChanged:(BOOL)contentChanged
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
    NSArray *_moves;
}

- (instancetype)initWithRevenantBefore:(PHFetchResult *)before after:(PHFetchResult *)after changed:(NSArray *)changed incremental:(BOOL)incremental
{
    self = [super init];
    if (!self)
        return nil;
    _before = before;
    _after = after;
    NSDictionary *beforePositions = revenant_positions(before), *afterPositions = revenant_positions(after);
    NSMutableSet *changedIdentifiers = [NSMutableSet setWithCapacity:changed.count];
    for (PHObject *object in changed)
        [changedIdentifiers addObject:object.localIdentifier];
    NSMutableIndexSet *removed = [NSMutableIndexSet indexSet];
    for (NSUInteger index = 0; index < before.count; index++) {
        if (!afterPositions[[before[index] localIdentifier]])
            [removed addIndex:index];
    }
    NSMutableIndexSet *inserted = [NSMutableIndexSet indexSet];
    NSMutableIndexSet *changes = [NSMutableIndexSet indexSet];
    size_t *fromIndexes = malloc(sizeof(size_t) * (after.count + 1));
    size_t *toIndexes = malloc(sizeof(size_t) * (after.count + 1));
    unsigned char *stable = malloc(after.count + 1);
    size_t shared = 0;
    for (NSUInteger index = 0; index < after.count; index++) {
        PHObject *object = after[index];
        NSNumber *position = beforePositions[object.localIdentifier];
        if (!position) {
            [inserted addIndex:index];
            continue;
        }
        fromIndexes[shared] = position.unsignedIntegerValue;
        toIndexes[shared] = index;
        shared++;
        if ([changedIdentifiers containsObject:object.localIdentifier])
            [changes addIndex:index];
    }
    RevenantPhotoLongestIncreasingSubsequence(fromIndexes, shared, stable);
    NSMutableArray *moves = [NSMutableArray array];
    for (size_t position = 0; position < shared; position++) {
        if (!stable[position])
            [moves addObject:@[@(fromIndexes[position]), @(toIndexes[position])]];
    }
    free(fromIndexes);
    free(toIndexes);
    free(stable);
    _incremental = incremental;
    if (_incremental) {
        _removed = removed;
        _inserted = inserted;
        _changed = changes;
        _moves = moves;
    }
    return self;
}

+ (instancetype)changeDetailsFromFetchResult:(PHFetchResult *)fromResult toFetchResult:(PHFetchResult *)toResult changedObjects:(NSArray *)changedObjects
{
    return [[self alloc] initWithRevenantBefore:fromResult after:toResult changed:changedObjects incremental:YES];
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
    return _moves.count > 0;
}

- (void)enumerateMovesWithBlock:(void (^)(NSUInteger fromIndex, NSUInteger toIndex))handler
{
    for (NSArray *move in _moves)
        handler([move[0] unsignedIntegerValue], [move[1] unsignedIntegerValue]);
}

@end
