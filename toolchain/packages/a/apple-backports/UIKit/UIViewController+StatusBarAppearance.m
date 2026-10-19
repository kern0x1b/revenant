#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static char charon_captures_key;

static UIViewController *charon_responsible(UIViewController *root, BOOL hidden)
{
    UIViewController *current = root;
    for (;;) {
        UIViewController *presented = current.presentedViewController;
        if (presented && (presented.modalPresentationStyle == UIModalPresentationFullScreen || [presented modalPresentationCapturesStatusBarAppearance])) {
            current = presented;
            continue;
        }
        UIViewController *child = hidden ? [current childViewControllerForStatusBarHidden] : [current childViewControllerForStatusBarStyle];
        if (!child)
            return current;
        current = child;
    }
}

@implementation UIViewController (CharonStatusBarAppearance)

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleDefault;
}

- (BOOL)prefersStatusBarHidden
{
    return NO;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    return UIStatusBarAnimationFade;
}

- (UIViewController *)childViewControllerForStatusBarStyle
{
    return nil;
}

- (UIViewController *)childViewControllerForStatusBarHidden
{
    return nil;
}

- (BOOL)modalPresentationCapturesStatusBarAppearance
{
    return [objc_getAssociatedObject(self, &charon_captures_key) boolValue];
}

- (void)setModalPresentationCapturesStatusBarAppearance:(BOOL)captures
{
    objc_setAssociatedObject(self, &charon_captures_key, @(captures), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setNeedsStatusBarAppearanceUpdate
{
    UIApplication *application = [UIApplication sharedApplication];
    UIViewController *root = application.keyWindow.rootViewController;
    if (!root)
        return;
    UIViewController *styled = charon_responsible(root, NO);
    UIViewController *hiding = charon_responsible(root, YES);
    BOOL animated = [UIView areAnimationsEnabled];
    [application setStatusBarStyle:[styled preferredStatusBarStyle] animated:animated];
    [application setStatusBarHidden:[hiding prefersStatusBarHidden] withAnimation:animated ? [hiding preferredStatusBarUpdateAnimation] : UIStatusBarAnimationNone];
}

@end
