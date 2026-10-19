#import <UIKit/UIKit.h>
#import "collectionmovement-cases.h"

// What a layout answers while a collection view reorders an item under a finger, as the system's
// own UIKit answers it with no collection view and no window, so the host records it and the
// backport is held to the same answers. The reordering inside a live collection view is checked on
// the device, in collectiontransition.m.
@interface MovementPlain : UICollectionViewLayout
@end

@implementation MovementPlain
@end

@interface MovementFlow : UICollectionViewFlowLayout
@end

@implementation MovementFlow
@end

// An index path prints its own address, which is different on every run and on every side, so it is
// recorded by its value instead: which is the only part of it an application can see anyway.
static NSString *MovementPath(id value)
{
    if (![value isKindOfClass:[NSIndexPath class]])
        return value ? [value description] : @"nil";
    NSIndexPath *path = value;
    return [NSString stringWithFormat:@"%ld-%ld", (long)path.section, (long)path.item];
}

// A list of index paths, by their values, or nil for none.
static NSString *MovementPaths(id value)
{
    if (!value)
        return @"nil";
    NSArray *paths = value;
    if (![paths isKindOfClass:[NSArray class]])
        return MovementPath(value);
    NSMutableArray *parts = [NSMutableArray array];
    for (NSIndexPath *path in paths)
        [parts addObject:MovementPath(path)];
    return [parts componentsJoinedByString:@","];
}

static NSString *MovementDescribe(id value)
{
    return value ? [value description] : @"nil";
}

void collectionmovement_run(CollectionMovementRecorder record)
{
    NSIndexPath *previous = [NSIndexPath indexPathForItem:3 inSection:1];
    NSIndexPath *target = [NSIndexPath indexPathForItem:1 inSection:0];
    NSArray *previousPaths = @[previous];
    NSArray *targetPaths = @[target];
    CGPoint position = CGPointMake(37, 91);
    CGPoint wasAt = CGPointMake(4, 5);

    for (NSString *which in @[@"plain", @"flow"]) {
        Class layoutClass = [which isEqualToString:@"flow"] ? [MovementFlow class] : [MovementPlain class];
        id layout = [[layoutClass alloc] init];

        // Where the item would land at this point: the layout's own answer to that question is the
        // index path it was asked about, and both layouts say so.
        record([NSString stringWithFormat:@"%@.targetIndexPath", which],
               MovementPath([layout targetIndexPathForInteractivelyMovingItem:previous withPosition:position]));

        // The moving item's own attributes: a cell at the point, with no size, above everything.
        UICollectionViewLayoutAttributes *attributes = [layout layoutAttributesForInteractivelyMovingItemAtIndexPath:target
                                                                                             withTargetPosition:position];
        record([NSString stringWithFormat:@"%@.movingAttributes.indexPath", which], MovementPath(attributes.indexPath));
        record([NSString stringWithFormat:@"%@.movingAttributes.frame", which], attributes ? NSStringFromCGRect(attributes.frame) : @"nil");
        record([NSString stringWithFormat:@"%@.movingAttributes.center", which], attributes ? NSStringFromCGPoint(attributes.center) : @"nil");
        record([NSString stringWithFormat:@"%@.movingAttributes.size", which], attributes ? NSStringFromCGSize(attributes.size) : @"nil");
        record([NSString stringWithFormat:@"%@.movingAttributes.zIndex", which], attributes ? [NSString stringWithFormat:@"%ld", (long)attributes.zIndex] : @"nil");
        record([NSString stringWithFormat:@"%@.movingAttributes.elementKind", which], attributes ? (attributes.representedElementKind ?: @"nil") : @"nil");

        // The context a movement is invalidated through, and the one that ends it.
        UICollectionViewLayoutInvalidationContext *moving = [layout invalidationContextForInteractivelyMovingItems:targetPaths
                                                                                             withTargetPosition:position
                                                                                               previousIndexPaths:previousPaths
                                                                                                previousPosition:wasAt];
        record([NSString stringWithFormat:@"%@.movingContext.previous", which], MovementPaths(moving.previousIndexPathsForInteractivelyMovingItems));
        record([NSString stringWithFormat:@"%@.movingContext.target", which], MovementPaths(moving.targetIndexPathsForInteractivelyMovingItems));
        record([NSString stringWithFormat:@"%@.movingContext.point", which], NSStringFromCGPoint(moving.interactiveMovementTarget));
        record([NSString stringWithFormat:@"%@.movingContext.invalidatedItems", which], MovementDescribe(moving.invalidatedItemIndexPaths));
        record([NSString stringWithFormat:@"%@.movingContext.invalidateEverything", which],
               [NSString stringWithFormat:@"%d", (int)moving.invalidateEverything]);
        // A flow layout's context class also says the two things only a flow layout can invalidate;
        // the base class's does not carry them at all, which is what "no-such-question" records.
        BOOL flow = [moving isKindOfClass:[UICollectionViewFlowLayoutInvalidationContext class]];
        record([NSString stringWithFormat:@"%@.movingContext.isFlowContext", which], flow ? @"yes" : @"no");
        record([NSString stringWithFormat:@"%@.movingContext.invalidateFlowMetrics", which],
               flow ? [NSString stringWithFormat:@"%d", (int)((UICollectionViewFlowLayoutInvalidationContext *)moving).invalidateFlowLayoutDelegateMetrics]
                    : @"no-such-question");

        UICollectionViewLayoutInvalidationContext *ending = [layout invalidationContextForEndingInteractiveMovementOfItemsToFinalIndexPaths:targetPaths
                                                                                                          previousIndexPaths:previousPaths
                                                                                                          movementCancelled:YES];
        record([NSString stringWithFormat:@"%@.endingContext.previous", which], MovementPaths(ending.previousIndexPathsForInteractivelyMovingItems));
        record([NSString stringWithFormat:@"%@.endingContext.target", which], MovementPaths(ending.targetIndexPathsForInteractivelyMovingItems));
        record([NSString stringWithFormat:@"%@.endingContext.point", which], NSStringFromCGPoint(ending.interactiveMovementTarget));
        record([NSString stringWithFormat:@"%@.endingContext.invalidatedItems", which], MovementDescribe(ending.invalidatedItemIndexPaths));

        // A context built for a bounds change, which is not a movement, carries none of the three.
        UICollectionViewLayoutInvalidationContext *bounds = [layout invalidationContextForBoundsChange:CGRectMake(0, 0, 10, 10)];
        record([NSString stringWithFormat:@"%@.boundsContext.previous", which], MovementDescribe(bounds.previousIndexPathsForInteractivelyMovingItems));
        record([NSString stringWithFormat:@"%@.boundsContext.target", which], MovementDescribe(bounds.targetIndexPathsForInteractivelyMovingItems));
        record([NSString stringWithFormat:@"%@.boundsContext.point", which], NSStringFromCGPoint(bounds.interactiveMovementTarget));
    }
}
