#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation UIScrollView (RevenantGetter17)

- (BOOL)scrollAnimating
{
    return [self isScrollAnimating];
}

- (BOOL)zoomAnimating
{
    return [self isZoomAnimating];
}

@end
