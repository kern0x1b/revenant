#import <UIKit/UIKit.h>

@interface UILayoutGuide (RevenantBackingView)
- (UIView *)revenant_view;
@end

@implementation UILayoutGuide (RevenantAmbiguity10)

- (NSArray<NSLayoutConstraint *> *)constraintsAffectingLayoutForAxis:(UILayoutConstraintAxis)axis
{
    return [[self revenant_view] constraintsAffectingLayoutForAxis:axis];
}

- (BOOL)hasAmbiguousLayout
{
    return [[self revenant_view] hasAmbiguousLayout];
}

@end
