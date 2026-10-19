#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static BOOL (*charon_original_unwind)(id, SEL, SEL, UIViewController *, id);

@interface CharonUnwindInstaller : NSObject
@end

@implementation CharonUnwindInstaller

+ (void)load
{
    Method old = class_getInstanceMethod([UIViewController class], @selector(canPerformUnwindSegueAction:fromViewController:withSender:));
    if (!old)
        return;
    charon_original_unwind = (void *)method_getImplementation(old);
    method_setImplementation(old, imp_implementationWithBlock(^BOOL(UIViewController *controller, SEL action, UIViewController *fromViewController, id sender) {
        return [controller canPerformUnwindSegueAction:action fromViewController:fromViewController sender:sender];
    }));
}

@end

@implementation UIViewController (CharonUnwind13)

- (BOOL)canPerformUnwindSegueAction:(SEL)action fromViewController:(UIViewController *)fromViewController sender:(id)sender
{
    return charon_original_unwind ? charon_original_unwind(self, @selector(canPerformUnwindSegueAction:fromViewController:withSender:), action, fromViewController, sender) : NO;
}

@end
