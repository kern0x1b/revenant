#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@implementation UIScrollView (RevenantContentAlignment17)

- (BOOL)isScrollAnimating
{
    return NO;
}

- (BOOL)isZoomAnimating
{
    return NO;
}

- (void)withScrollIndicatorsShownForContentOffsetChanges:(void (NS_NOESCAPE ^)(void))changes
{
    changes();
}

@end
