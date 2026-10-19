#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@interface RevenantNavigationOrientationInstaller : NSObject
@end

@implementation RevenantNavigationOrientationInstaller

+ (void)load
{
    Class controller = [UINavigationController class];
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
