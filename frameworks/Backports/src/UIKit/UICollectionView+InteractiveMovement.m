#import "RevenantDiffable.h"
#import "RevenantLists.h"
#import <objc/message.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantMovementKey;

@interface RevenantMovement : NSObject
@property (nonatomic, strong) NSIndexPath *original;
@property (nonatomic, strong) NSIndexPath *current;
@property (nonatomic, strong) UIImageView *proxy;
@property (nonatomic) CGPoint position;
@property (nonatomic, strong) NSTimer *scroller;
@property (nonatomic, weak) UICollectionView *view;
@property (nonatomic) BOOL ending;
@property (nonatomic) BOOL cancelled;
@end

@implementation RevenantMovement
@synthesize original = _original;
@synthesize current = _current;
@synthesize proxy = _proxy;
@synthesize position = _position;
@synthesize scroller = _scroller;
@synthesize view = _view;
@synthesize ending = _ending;
@synthesize cancelled = _cancelled;

- (void)hideCell
{
    [[_view cellForItemAtIndexPath:_current] setAlpha:0];
}

- (void)placeProxy
{
    _proxy.center = _position;
}

- (void)moveTo:(NSIndexPath *)target
{
    UICollectionView *view = _view;
    id source = view.dataSource;
    NSIndexPath *from = _current;
    _current = target;
    [view performBatchUpdates:^{
        ((void (*)(id, SEL, id, id, id))objc_msgSend)(source, @selector(collectionView:moveItemAtIndexPath:toIndexPath:), view, from, target);
        [view moveItemAtIndexPath:from toIndexPath:target];
        UICollectionViewLayout *layout = view.collectionViewLayout;
        [layout invalidateLayoutWithContext:[layout invalidationContextForInteractivelyMovingItems:@[target]
                                                                               withTargetPosition:_position
                                                                                 previousIndexPaths:@[from]
                                                                                  previousPosition:_position]];
    } completion:^(BOOL finished) {
        [self hideCell];
    }];
    [self hideCell];
}

- (NSIndexPath *)proposedTarget
{
    UICollectionView *view = _view;
    NSIndexPath *hit = [view indexPathForItemAtPoint:_position];
    if (!hit)
        return nil;
    NSIndexPath *proposed = [view.collectionViewLayout targetIndexPathForInteractivelyMovingItem:_current withPosition:_position];
    if (proposed && ![proposed isEqual:_current])
        hit = proposed;
    if ([hit isEqual:_current])
        return nil;
    id delegate = view.delegate;
    SEL adjust = @selector(collectionView:targetIndexPathForMoveFromItemAtIndexPath:toProposedIndexPath:);
    if ([delegate respondsToSelector:adjust])
        hit = ((NSIndexPath * (*)(id, SEL, id, id, id))objc_msgSend)(delegate, adjust, view, _current, hit);
    return [hit isEqual:_current] ? nil : hit;
}

- (void)update
{
    [self placeProxy];
    NSIndexPath *target = [self proposedTarget];
    if (target)
        [self moveTo:target];
    [self hideCell];
}

- (void)autoscroll
{
    UICollectionView *view = _view;
    CGRect visible = view.bounds;
    CGFloat edge = 60, speed = 0;
    CGFloat top = visible.origin.y + view.contentInset.top, bottom = CGRectGetMaxY(visible) - view.contentInset.bottom;
    if (_position.y < top + edge)
        speed = -(top + edge - _position.y) / edge * 12;
    else if (_position.y > bottom - edge)
        speed = (_position.y - (bottom - edge)) / edge * 12;
    CGFloat minimum = -view.contentInset.top, maximum = MAX(view.contentSize.height - visible.size.height + view.contentInset.bottom, minimum);
    CGFloat offset = MIN(MAX(view.contentOffset.y + speed, minimum), maximum);
    CGFloat moved = offset - view.contentOffset.y;
    if (fabsf(moved) < 0.01)
        return;
    view.contentOffset = CGPointMake(view.contentOffset.x, offset);
    _position = CGPointMake(_position.x, _position.y + moved);
    [self update];
}

@end

@implementation UICollectionView (RevenantInteractiveMovement)

- (RevenantMovement *)revenant_movement
{
    return objc_getAssociatedObject(self, &RevenantMovementKey);
}

- (BOOL)beginInteractiveMovementForItemAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self revenant_movement] || !indexPath)
        return NO;
    id source = self.dataSource;
    UICollectionViewCell *cell = [self cellForItemAtIndexPath:indexPath];
    if (!cell || ![source respondsToSelector:@selector(collectionView:moveItemAtIndexPath:toIndexPath:)])
        return NO;
    if ([source respondsToSelector:@selector(collectionView:canMoveItemAtIndexPath:)] && ![source collectionView:self canMoveItemAtIndexPath:indexPath])
        return NO;
    UIGraphicsBeginImageContextWithOptions(cell.bounds.size, NO, 0);
    [cell.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    RevenantMovement *movement = [[RevenantMovement alloc] init];
    movement.view = self;
    movement.original = indexPath;
    movement.current = indexPath;
    movement.position = cell.center;
    movement.proxy = [[UIImageView alloc] initWithImage:image];
    movement.proxy.frame = cell.frame;
    movement.proxy.layer.zPosition = 10000;
    movement.proxy.layer.shadowColor = [UIColor blackColor].CGColor;
    movement.proxy.layer.shadowOpacity = 0.3f;
    movement.proxy.layer.shadowRadius = 4;
    movement.proxy.layer.shadowOffset = CGSizeMake(0, 2);
    [self addSubview:movement.proxy];
    cell.alpha = 0;
    objc_setAssociatedObject(self, &RevenantMovementKey, movement, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if ([source respondsToSelector:@selector(revenant_reorderBegan)])
        [(UICollectionViewDiffableDataSource *)source revenant_reorderBegan];
    movement.scroller = [NSTimer scheduledTimerWithTimeInterval:1.0 / 60 target:movement selector:@selector(autoscroll) userInfo:nil repeats:YES];
    return YES;
}

- (void)updateInteractiveMovementTargetPosition:(CGPoint)targetPosition
{
    RevenantMovement *movement = [self revenant_movement];
    if (!movement || movement.ending)
        return;
    movement.position = targetPosition;
    [movement update];
}

- (void)revenant_finishMovement:(RevenantMovement *)movement
{
    movement.ending = YES;
    [movement.scroller invalidate];
    movement.scroller = nil;
    UICollectionView *view = movement.view;
    UICollectionViewLayout *layout = view.collectionViewLayout;
    [layout invalidateLayoutWithContext:[layout invalidationContextForEndingInteractiveMovementOfItemsToFinalIndexPaths:@[movement.current]
                                                                                       previousIndexPaths:@[movement.original]
                                                                                       movementCancelled:movement.cancelled]];
    objc_setAssociatedObject(view, &RevenantMovementKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UICollectionViewCell *cell = [view cellForItemAtIndexPath:movement.current];
    UIImageView *proxy = movement.proxy;
    [UIView animateWithDuration:0.2 animations:^{
        if (cell)
            proxy.frame = cell.frame;
    } completion:^(BOOL finished) {
        cell.alpha = 1;
        [proxy removeFromSuperview];
    }];
}

- (void)endInteractiveMovement
{
    RevenantMovement *movement = [self revenant_movement];
    if (!movement || movement.ending)
        return;
    [self revenant_finishMovement:movement];
    id source = self.dataSource;
    if ([source respondsToSelector:@selector(revenant_reorderEnded)])
        [(UICollectionViewDiffableDataSource *)source revenant_reorderEnded];
}

- (void)cancelInteractiveMovement
{
    RevenantMovement *movement = [self revenant_movement];
    if (!movement || movement.ending)
        return;
    movement.cancelled = YES;
    if (![movement.current isEqual:movement.original])
        [movement moveTo:movement.original];
    [self revenant_finishMovement:movement];
    id source = self.dataSource;
    if ([source respondsToSelector:@selector(revenant_reorderCancelled)])
        [(UICollectionViewDiffableDataSource *)source revenant_reorderCancelled];
}

@end
