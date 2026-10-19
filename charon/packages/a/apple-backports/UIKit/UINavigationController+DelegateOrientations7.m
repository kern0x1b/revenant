#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// A navigation controller asking its delegate which orientations it may be in. Both questions arrived
// with iOS 7 and the release's navigation controller answers neither: it uses its own answers and an
// application that implemented either of these was never asked. The defaults with no delegate are
// measured and are not the ones a guess gives: with no delegate the preferred orientation is neither
// portrait, and the supported mask is not all
// (tests/backports/host/uikitscroll, the nav.delegate*Default cases).
//
// The delegate is asked first and its answer is used; a delegate that answers neither leaves the
// release's own answer, which is what a navigation stack with no delegate has always done.
@interface CharonNavigationOrientationInstaller : NSObject
@end

@implementation CharonNavigationOrientationInstaller

+ (void)load
{
    Class controller = [UINavigationController class];
    // The delegate is asked from the two questions the release already answers for the view: the
    // implementation already in place is captured and called, so the release's own answer is what
    // happens when the delegate has none, and this composes with any other wrap of the same methods.
    Method preferred = class_getInstanceMethod(controller, @selector(preferredInterfaceOrientationForPresentation));
    UIInterfaceOrientation (*previousPreferred)(id, SEL) = (UIInterfaceOrientation (*)(id, SEL))method_getImplementation(preferred);
    class_replaceMethod(controller, @selector(preferredInterfaceOrientationForPresentation),
                        imp_implementationWithBlock(^(UINavigationController *self_) {
        id delegate = self_.delegate;
        SEL ask = @selector(navigationControllerPreferredInterfaceOrientationForPresentation:);
        if ([delegate respondsToSelector:ask])
            return ((UIInterfaceOrientation (*)(id, SEL, id))objc_msgSend)(delegate, ask, self_);
        return previousPreferred(self_, @selector(preferredInterfaceOrientationForPresentation));
    }), method_getTypeEncoding(preferred));
    Method supported = class_getInstanceMethod(controller, @selector(supportedInterfaceOrientations));
    UIInterfaceOrientationMask (*previousSupported)(id, SEL) = (UIInterfaceOrientationMask (*)(id, SEL))method_getImplementation(supported);
    class_replaceMethod(controller, @selector(supportedInterfaceOrientations),
                        imp_implementationWithBlock(^(UINavigationController *self_) {
        id delegate = self_.delegate;
        SEL ask = @selector(navigationControllerSupportedInterfaceOrientations:);
        if ([delegate respondsToSelector:ask])
            return ((UIInterfaceOrientationMask (*)(id, SEL, id))objc_msgSend)(delegate, ask, self_);
        return previousSupported(self_, @selector(supportedInterfaceOrientations));
    }), method_getTypeEncoding(supported));
}

@end
