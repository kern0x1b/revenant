#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-property-implementation"
#pragma clang diagnostic ignored "-Wincomplete-implementation"

static NSArray *charon_unique_paths(NSArray *existing, NSArray *added)
{
    NSMutableArray *paths = [existing mutableCopy] ?: [NSMutableArray array];
    for (NSIndexPath *path in added)
        if (![paths containsObject:path])
            [paths addObject:path];
    return [paths sortedArrayUsingSelector:@selector(compare:)];
}

static NSDictionary *charon_add_kind(NSDictionary *existing, NSString *kind, NSArray *added)
{
    NSMutableDictionary *kinds = [existing mutableCopy] ?: [NSMutableDictionary dictionary];
    NSArray *paths = charon_unique_paths(kinds[kind], added);
    if (kind)
        kinds[kind] = paths;
    return kinds;
}

@implementation UICollectionViewLayoutInvalidationContext {
@private
    NSArray *_items;
    NSDictionary *_supplementary;
    NSDictionary *_decoration;
    CGPoint _contentOffsetAdjustment;
    CGSize _contentSizeAdjustment;
    // The reordering a context built for an interactive movement carries: where the moving items
    // were, where they are going, and the point the movement is at. The header names no setter for
    // any of the three, so a layout that builds such a context sets them through this one message.
    NSArray *_previousMovingIndexPaths;
    NSArray *_targetMovingIndexPaths;
    CGPoint _interactiveMovementTarget;
}

- (BOOL)invalidateEverything
{
    return NO;
}

- (BOOL)invalidateDataSourceCounts
{
    return NO;
}

- (NSArray<NSIndexPath *> *)invalidatedItemIndexPaths
{
    return _items;
}

- (NSDictionary<NSString *, NSArray<NSIndexPath *> *> *)invalidatedSupplementaryIndexPaths
{
    return _supplementary;
}

- (NSDictionary<NSString *, NSArray<NSIndexPath *> *> *)invalidatedDecorationIndexPaths
{
    return _decoration;
}

- (void)invalidateItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    _items = charon_unique_paths(_items, indexPaths);
}

- (void)invalidateSupplementaryElementsOfKind:(NSString *)elementKind atIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    _supplementary = charon_add_kind(_supplementary, elementKind, indexPaths);
}

- (void)invalidateDecorationElementsOfKind:(NSString *)elementKind atIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
{
    _decoration = charon_add_kind(_decoration, elementKind, indexPaths);
}

- (CGPoint)contentOffsetAdjustment
{
    return _contentOffsetAdjustment;
}

- (void)setContentOffsetAdjustment:(CGPoint)value
{
    _contentOffsetAdjustment = value;
}

- (CGSize)contentSizeAdjustment
{
    return _contentSizeAdjustment;
}

- (void)setContentSizeAdjustment:(CGSize)value
{
    _contentSizeAdjustment = value;
}

// The three reordering answers, each the caller's own index paths and point as they were given,
// measured under Mac Catalyst (macOS 27.0) and held by tests/backports/host/collectionmovement.
- (NSArray<NSIndexPath *> *)previousIndexPathsForInteractivelyMovingItems
{
    return _previousMovingIndexPaths;
}

- (NSArray<NSIndexPath *> *)targetIndexPathsForInteractivelyMovingItems
{
    return _targetMovingIndexPaths;
}

- (CGPoint)interactiveMovementTarget
{
    return _interactiveMovementTarget;
}

- (void)charon_setInteractivelyMovingPrevious:(NSArray<NSIndexPath *> *)previous
                                       target:(NSArray<NSIndexPath *> *)target
                                         atPoint:(CGPoint)position
{
    _previousMovingIndexPaths = previous;
    _targetMovingIndexPaths = target;
    _interactiveMovementTarget = position;
}

@end

@implementation UICollectionViewFlowLayoutInvalidationContext {
@private
    BOOL _invalidateFlowLayoutDelegateMetrics;
    BOOL _invalidateFlowLayoutAttributes;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _invalidateFlowLayoutDelegateMetrics = YES;
        _invalidateFlowLayoutAttributes = YES;
    }
    return self;
}

- (BOOL)invalidateFlowLayoutDelegateMetrics
{
    return _invalidateFlowLayoutDelegateMetrics;
}

- (void)setInvalidateFlowLayoutDelegateMetrics:(BOOL)value
{
    _invalidateFlowLayoutDelegateMetrics = value;
}

- (BOOL)invalidateFlowLayoutAttributes
{
    return _invalidateFlowLayoutAttributes;
}

- (void)setInvalidateFlowLayoutAttributes:(BOOL)value
{
    _invalidateFlowLayoutAttributes = value;
}

@end
