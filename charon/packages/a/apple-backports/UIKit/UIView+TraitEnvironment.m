#import <UIKit/UIKit.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@interface UITraitCollection (CharonTraitEnvironment)
+ (UITraitCollection *)charon_traitCollectionForScreen:(UIScreen *)screen;
@end

@interface UIView (CharonTraitEnvironment) <UITraitEnvironment>
@end

@implementation UIView (CharonTraitEnvironment)

// A view's trait collection is what its superview answers, or the controller whose view it is answers. A view's own
// override of the style is not in it: the host does not apply a view's override to the view's trait collection, nor to
// the views under it (darkstyle group), so neither does the port.
- (UITraitCollection *)traitCollection
{
    UIResponder *next = self.nextResponder;
    if ([next isKindOfClass:[UIViewController class]] && ((UIViewController *)next).view == self)
        return [(UIViewController *)next traitCollection];
    if (self.superview)
        return [self.superview traitCollection];
    UIWindow *window = [self isKindOfClass:[UIWindow class]] ? (UIWindow *)self : self.window;
    return [UITraitCollection charon_traitCollectionForScreen:window.screen];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
}

@end
