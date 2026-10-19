#import <UIKit/UIKit.h>

@implementation UIViewController (CharonOrientationUpdate)

- (void)setNeedsUpdateOfSupportedInterfaceOrientations
{
    [UIViewController attemptRotationToDeviceOrientation];
}

@end
