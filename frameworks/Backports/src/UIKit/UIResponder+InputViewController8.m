#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static void revenant_wrap_input(Class cls, SEL getter, BOOL accessory)
{
    unsigned count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    Method own = NULL;
    for (unsigned index = 0; index < count && !own; index++) {
        if (method_getName(methods[index]) == getter)
            own = methods[index];
    }
    free(methods);
    if (!own)
        return;
    UIView *(*original)(id, SEL) = (UIView *(*)(id, SEL))method_getImplementation(own);
    method_setImplementation(own, imp_implementationWithBlock(^UIView *(UIResponder *responder) {
        UIView *view = original(responder, getter);
        if (view)
            return view;
        UIViewController *owner = accessory ? responder.inputAccessoryViewController : responder.inputViewController;
        return owner ? owner.view : nil;
    }));
}

@interface RevenantInputViewController8 : NSObject
@end

@implementation RevenantInputViewController8

+ (void)load
{
    if ([UIResponder instancesRespondToSelector:@selector(inputViewController)])
        return;
    for (Class cls in @[[UIResponder class], [UITextField class], [UITextView class]]) {
        revenant_wrap_input(cls, @selector(inputView), NO);
        revenant_wrap_input(cls, @selector(inputAccessoryView), YES);
    }
}

@end

@implementation UIResponder (RevenantInputViewController8)

- (UIInputViewController *)inputViewController
{
    return nil;
}

- (UIInputViewController *)inputAccessoryViewController
{
    return nil;
}

@end
