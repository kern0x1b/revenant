#import "RevenantCompositionalLayout.h"

@implementation NSCollectionLayoutSection (RevenantFourteen)

- (UIContentInsetsReference)contentInsetsReference
{
    return (UIContentInsetsReference)[self revenant_contentInsetsReference];
}

- (void)setContentInsetsReference:(UIContentInsetsReference)contentInsetsReference
{
    [self revenant_setContentInsetsReference:contentInsetsReference];
}

@end
