#import "RevenantPhotos.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation PHFetchResult {
    NSArray *_objects;
    NSArray *(^_query)(void);
    PHFetchOptions *_options;
}

- (instancetype)initWithRevenantObjects:(NSArray *)objects
{
    self = [super init];
    if (self)
        _objects = [objects copy] ?: @[];
    return self;
}

- (instancetype)initWithRevenantQuery:(NSArray *(^)(void))query options:(PHFetchOptions *)options
{
    NSArray *objects = query();
    self = [self initWithRevenantObjects:options ? [options revenant_apply:objects] : objects];
    if (self) {
        _query = [query copy];
        _options = [options copy];
    }
    return self;
}

- (PHFetchResult *)revenant_refetched
{
    if (!_query)
        return self;
    return [[PHFetchResult alloc] initWithRevenantQuery:_query options:_options];
}

- (BOOL)revenant_wantsIncrementalChangeDetails
{
    return _options ? _options.wantsIncrementalChangeDetails : YES;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSUInteger)count
{
    return _objects.count;
}

- (id)objectAtIndex:(NSUInteger)index
{
    return _objects[index];
}

- (id)objectAtIndexedSubscript:(NSUInteger)index
{
    return _objects[index];
}

- (BOOL)containsObject:(id)object
{
    return [_objects containsObject:object];
}

- (NSUInteger)indexOfObject:(id)object
{
    return [_objects indexOfObject:object];
}

- (NSUInteger)indexOfObject:(id)object inRange:(NSRange)range
{
    return [_objects indexOfObject:object inRange:range];
}

- (id)firstObject
{
    return _objects.firstObject;
}

- (id)lastObject
{
    return _objects.lastObject;
}

- (NSArray *)objectsAtIndexes:(NSIndexSet *)indexes
{
    return [_objects objectsAtIndexes:indexes];
}

- (void)enumerateObjectsUsingBlock:(void (^)(id obj, NSUInteger idx, BOOL *stop))block
{
    [_objects enumerateObjectsUsingBlock:block];
}

- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)options usingBlock:(void (^)(id obj, NSUInteger idx, BOOL *stop))block
{
    [_objects enumerateObjectsWithOptions:options usingBlock:block];
}

- (void)enumerateObjectsAtIndexes:(NSIndexSet *)indexes options:(NSEnumerationOptions)options usingBlock:(void (^)(id obj, NSUInteger idx, BOOL *stop))block
{
    [_objects enumerateObjectsAtIndexes:indexes options:options usingBlock:block];
}

- (NSUInteger)countOfAssetsWithMediaType:(PHAssetMediaType)mediaType
{
    NSUInteger count = 0;
    for (id object in _objects) {
        if ([object isKindOfClass:[PHAsset class]] && [(PHAsset *)object mediaType] == mediaType)
            count++;
    }
    return count;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)length
{
    return [_objects countByEnumeratingWithState:state objects:buffer count:length];
}

@end
