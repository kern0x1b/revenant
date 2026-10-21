#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

void revenant_restoration_extend(NSInteger delta);

@implementation UIScene (RevenantRestoration15)

- (void)extendStateRestoration
{
    revenant_restoration_extend(1);
}

- (void)completeStateRestoration
{
    revenant_restoration_extend(-1);
}

@end
