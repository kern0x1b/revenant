#import <UIKit/UIKit.h>

@implementation UIViewController (CharonViewLoading)

- (void)loadViewIfNeeded
{
    if (![self isViewLoaded])
        (void)self.view;
}

- (UIView *)viewIfLoaded
{
    return [self isViewLoaded] ? self.view : nil;
}

@end
