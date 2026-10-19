#import "CharonCompositionalLayout.h"

@implementation UICollectionViewCompositionalLayoutConfiguration (CharonFourteen)

- (UIContentInsetsReference)contentInsetsReference
{
    return (UIContentInsetsReference)[self charon_contentInsetsReference];
}

- (void)setContentInsetsReference:(UIContentInsetsReference)contentInsetsReference
{
    [self charon_setContentInsetsReference:contentInsetsReference];
}

@end
