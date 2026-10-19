#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation UIMenuController (CharonThirteen)

- (void)showMenuFromView:(UIView *)targetView rect:(CGRect)targetRect
{
    [self setTargetRect:targetRect inView:targetView];
    [self setMenuVisible:YES animated:YES];
}

- (void)hideMenuFromView:(UIView *)targetView
{
    [self setMenuVisible:NO animated:YES];
}

- (void)hideMenu
{
    [self setMenuVisible:NO animated:YES];
}

@end
