#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char CharonContentAlignmentPointKey;
static const char CharonTransfersHorizontalKey;
static const char CharonTransfersVerticalKey;

@implementation UIScrollView (CharonContentAlignment17)

- (CGPoint)contentAlignmentPoint
{
    NSValue *stored = objc_getAssociatedObject(self, &CharonContentAlignmentPointKey);
    return stored ? stored.CGPointValue : CGPointZero;
}

- (void)setContentAlignmentPoint:(CGPoint)contentAlignmentPoint
{
    objc_setAssociatedObject(self, &CharonContentAlignmentPointKey,
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
    NSNumber *stored = objc_getAssociatedObject(self, &CharonTransfersHorizontalKey);
    return stored ? stored.boolValue : YES;
}

- (void)setTransfersHorizontalScrollingToParent:(BOOL)transfersHorizontalScrollingToParent
{
    objc_setAssociatedObject(self, &CharonTransfersHorizontalKey,
                            @(transfersHorizontalScrollingToParent), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)transfersVerticalScrollingToParent
{
    NSNumber *stored = objc_getAssociatedObject(self, &CharonTransfersVerticalKey);
    return stored ? stored.boolValue : YES;
}

- (void)setTransfersVerticalScrollingToParent:(BOOL)transfersVerticalScrollingToParent
{
    objc_setAssociatedObject(self, &CharonTransfersVerticalKey,
                            @(transfersVerticalScrollingToParent), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)withScrollIndicatorsShownForContentOffsetChanges:(void (NS_NOESCAPE ^)(void))changes
{
    changes();
}

@end
