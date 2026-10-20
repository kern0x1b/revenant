#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char RevenantContentAlignmentPointKey;
static const char RevenantTransfersHorizontalKey;
static const char RevenantTransfersVerticalKey;

@implementation UIScrollView (RevenantContentAlignment17)

- (CGPoint)contentAlignmentPoint
{
    NSValue *stored = objc_getAssociatedObject(self, &RevenantContentAlignmentPointKey);
    return stored ? stored.CGPointValue : CGPointZero;
}

- (void)setContentAlignmentPoint:(CGPoint)contentAlignmentPoint
{
    objc_setAssociatedObject(self, &RevenantContentAlignmentPointKey,
                            [NSValue valueWithCGPoint:contentAlignmentPoint],
                            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isScrollAnimating
{
    return NO;
}

- (BOOL)isZoomAnimating
{
    return NO;
}

- (BOOL)transfersHorizontalScrollingToParent
{
    NSNumber *stored = objc_getAssociatedObject(self, &RevenantTransfersHorizontalKey);
    return stored ? stored.boolValue : YES;
}

- (void)setTransfersHorizontalScrollingToParent:(BOOL)transfersHorizontalScrollingToParent
{
    objc_setAssociatedObject(self, &RevenantTransfersHorizontalKey,
                            @(transfersHorizontalScrollingToParent), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)transfersVerticalScrollingToParent
{
    NSNumber *stored = objc_getAssociatedObject(self, &RevenantTransfersVerticalKey);
    return stored ? stored.boolValue : YES;
}

- (void)setTransfersVerticalScrollingToParent:(BOOL)transfersVerticalScrollingToParent
{
    objc_setAssociatedObject(self, &RevenantTransfersVerticalKey,
                            @(transfersVerticalScrollingToParent), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)withScrollIndicatorsShownForContentOffsetChanges:(void (NS_NOESCAPE ^)(void))changes
{
    changes();
}

@end
