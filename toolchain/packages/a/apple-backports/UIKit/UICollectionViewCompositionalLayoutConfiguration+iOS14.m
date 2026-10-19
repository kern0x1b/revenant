#import "RevenantCompositionalLayout.h"

@implementation UICollectionViewCompositionalLayoutConfiguration (RevenantFourteen)

- (UIContentInsetsReference)contentInsetsReference
{
    return (UIContentInsetsReference)[self revenant_contentInsetsReference];
}

- (void)setContentInsetsReference:(UIContentInsetsReference)contentInsetsReference
{
    [self revenant_setContentInsetsReference:contentInsetsReference];
}

@end
