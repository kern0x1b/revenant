#import <UIKit/UIKit.h>
#import <objc/message.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// The one message a layout builds a movement's context with. The three answers on the context are
// readonly and the header names no setter for any of them, so this is how a layout that makes such
// a context fills it in; it is defined beside the three, where the storage is.
@interface UICollectionViewLayoutInvalidationContext (CharonReordering)
- (void)charon_setInteractivelyMovingPrevious:(NSArray<NSIndexPath *> *)previous
                                       target:(NSArray<NSIndexPath *> *)target
                                     atPoint:(CGPoint)position;
@end

// What a layout answers while a collection view reorders an item under a finger. Every answer here
// is the host's own, measured under Mac Catalyst (macOS 27.0) and held against this file by
// tests/backports/host/collectionmovement: the base layout gives the index path it was asked about
// back, and the moving item's attributes are a fresh cell placed at the point it is being dragged
// to, with no size and above every other element. The contexts are the layout's own
// invalidationContextClass, carrying the index paths and the point as they were given and
// invalidating no item of their own, and the one that ends a movement carries the origin as its
// point, because an ended movement is at no point in particular.
@implementation UICollectionViewLayout (CharonInteractiveMovement9)

// The index path an item at this position would move to. The base layout proposes the one it is
// asked about; a layout that arranges its items differently overrides this, and the collection
// view's delegate is asked after it, so a delegate still has the last word.
- (NSIndexPath *)targetIndexPathForInteractivelyMovingItem:(NSIndexPath *)previousIndexPath withPosition:(CGPoint)position
{
    return previousIndexPath;
}

// The attributes of the item being moved, at the point it is being dragged to. The base layout has
// no attributes of its own to move, so it has none to give here either and answers nil; the flow
// layout, which does have them, answers the way Apple's does below.
- (UICollectionViewLayoutAttributes *)layoutAttributesForInteractivelyMovingItemAtIndexPath:(NSIndexPath *)indexPath
                                                                      withTargetPosition:(CGPoint)position
{
    return nil;
}

// The context a layout invalidates through while an item is being moved: its own context class,
// told where the items came from, where they are going and where the movement is now, and
// invalidating no item index path of its own.
- (UICollectionViewLayoutInvalidationContext *)invalidationContextForInteractivelyMovingItems:(NSArray<NSIndexPath *> *)targetIndexPaths
                                                                          withTargetPosition:(CGPoint)targetPosition
                                                                            previousIndexPaths:(NSArray<NSIndexPath *> *)previousIndexPaths
                                                                             previousPosition:(CGPoint)previousPosition
{
    Class contextClass = [[self class] invalidationContextClass];
    UICollectionViewLayoutInvalidationContext *context = [[contextClass alloc] init];
    [context charon_setInteractivelyMovingPrevious:previousIndexPaths target:targetIndexPaths atPoint:targetPosition];
    return context;
}

// The same context for the movement coming to its end, at the index paths it ended at and the ones
// it came from; the point is the origin, which is what the host answers here as well.
- (UICollectionViewLayoutInvalidationContext *)invalidationContextForEndingInteractiveMovementOfItemsToFinalIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
                                                                                              previousIndexPaths:(NSArray<NSIndexPath *> *)previousIndexPaths
                                                                                              movementCancelled:(BOOL)movementCancelled
{
    Class contextClass = [[self class] invalidationContextClass];
    UICollectionViewLayoutInvalidationContext *context = [[contextClass alloc] init];
    [context charon_setInteractivelyMovingPrevious:previousIndexPaths target:indexPaths atPoint:CGPointZero];
    return context;
}

@end

// A flow layout does have attributes for its cells, so it places the item being moved: Apple's
// answer, measured under Mac Catalyst, is a cell with no size whose centre is the point it is being
// dragged to and which draws above every other element, so the item follows the finger and is never
// behind anything. The size is the point's own, not the cell's laid out size, because the cell is
// being carried by the finger rather than placed in the grid.
@implementation UICollectionViewFlowLayout (CharonInteractiveMovement9)

- (UICollectionViewLayoutAttributes *)layoutAttributesForInteractivelyMovingItemAtIndexPath:(NSIndexPath *)indexPath
                                                                      withTargetPosition:(CGPoint)position
{
    if (!indexPath)
        return nil;
    UICollectionViewLayoutAttributes *attributes = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:indexPath];
    attributes.frame = CGRectMake(position.x, position.y, 0, 0);
    attributes.zIndex = NSIntegerMax;
    return attributes;
}

@end
