#import <UIKit/UIKit.h>
#import <objc/message.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@interface UICollectionViewLayoutInvalidationContext (RevenantReordering)
- (void)revenant_setInteractivelyMovingPrevious:(NSArray<NSIndexPath *> *)previous
                                       target:(NSArray<NSIndexPath *> *)target
                                     atPoint:(CGPoint)position;
@end

@implementation UICollectionViewLayout (RevenantInteractiveMovement9)

- (NSIndexPath *)targetIndexPathForInteractivelyMovingItem:(NSIndexPath *)previousIndexPath withPosition:(CGPoint)position
{
    return previousIndexPath;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForInteractivelyMovingItemAtIndexPath:(NSIndexPath *)indexPath
                                                                      withTargetPosition:(CGPoint)position
{
    return nil;
}

- (UICollectionViewLayoutInvalidationContext *)invalidationContextForInteractivelyMovingItems:(NSArray<NSIndexPath *> *)targetIndexPaths
                                                                          withTargetPosition:(CGPoint)targetPosition
                                                                            previousIndexPaths:(NSArray<NSIndexPath *> *)previousIndexPaths
                                                                             previousPosition:(CGPoint)previousPosition
{
    Class contextClass = [[self class] invalidationContextClass];
    UICollectionViewLayoutInvalidationContext *context = [[contextClass alloc] init];
    [context revenant_setInteractivelyMovingPrevious:previousIndexPaths target:targetIndexPaths atPoint:targetPosition];
    return context;
}

- (UICollectionViewLayoutInvalidationContext *)invalidationContextForEndingInteractiveMovementOfItemsToFinalIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
                                                                                              previousIndexPaths:(NSArray<NSIndexPath *> *)previousIndexPaths
                                                                                              movementCancelled:(BOOL)movementCancelled
{
    Class contextClass = [[self class] invalidationContextClass];
    UICollectionViewLayoutInvalidationContext *context = [[contextClass alloc] init];
    [context revenant_setInteractivelyMovingPrevious:previousIndexPaths target:indexPaths atPoint:CGPointZero];
    return context;
}

@end

@implementation UICollectionViewFlowLayout (RevenantInteractiveMovement9)

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
