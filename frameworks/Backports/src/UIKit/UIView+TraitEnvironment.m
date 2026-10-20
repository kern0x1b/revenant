#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@interface UITraitCollection (RevenantTraitEnvironment)
+ (UITraitCollection *)revenant_traitCollectionForScreen:(UIScreen *)screen;
@end

@interface UIView (RevenantTraitEnvironment) <UITraitEnvironment>
@end

@implementation UIView (RevenantTraitEnvironment)

- (UITraitCollection *)traitCollection
{
    UIResponder *next = self.nextResponder;
    if ([next isKindOfClass:[UIViewController class]] && ((UIViewController *)next).view == self)
        return [(UIViewController *)next traitCollection];
    if (self.superview)
        return [self.superview traitCollection];
    UIWindow *window = [self isKindOfClass:[UIWindow class]] ? (UIWindow *)self : self.window;
    return [UITraitCollection revenant_traitCollectionForScreen:window.screen];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
}

@end
