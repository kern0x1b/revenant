#import <UIKit/UIKit.h>

@implementation UIViewController (RevenantOrientationUpdate)

- (void)setNeedsUpdateOfSupportedInterfaceOrientations
{
    [UIViewController attemptRotationToDeviceOrientation];
}

@end
