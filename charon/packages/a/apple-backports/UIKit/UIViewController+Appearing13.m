#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@interface UIViewController (CharonAppearingDeclaration)
- (void)viewIsAppearing:(BOOL)animated;
@end

static const char charon_depth_key, charon_wrapped_key;

static void (*charon_original_nib)(id, SEL, NSString *, NSBundle *);
static void (*charon_original_coder)(id, SEL, NSCoder *);

static void charon_wrap_class(Class cls)
{
    if (objc_getAssociatedObject(cls, &charon_wrapped_key))
        return;
    objc_setAssociatedObject(cls, &charon_wrapped_key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    for (unsigned int index = 0; index < count; index++) {
        if (method_getName(methods[index]) != @selector(viewWillAppear:))
            continue;
        IMP previous = method_getImplementation(methods[index]);
        method_setImplementation(methods[index], imp_implementationWithBlock(^(UIViewController *controller, BOOL animated) {
            // Keep the controller alive across the whole call, including the callback, whatever the override does.
            UIViewController *held = controller;
            NSInteger depth = [objc_getAssociatedObject(controller, &charon_depth_key) integerValue];
            objc_setAssociatedObject(controller, &charon_depth_key, @(depth + 1), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            ((void (*)(id, SEL, BOOL))previous)(controller, @selector(viewWillAppear:), animated);
            objc_setAssociatedObject(controller, &charon_depth_key, depth ? @(depth) : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (!depth)
                [held viewIsAppearing:animated];
        }));
    }
    free(methods);
}

static void charon_wrap_chain(id controller)
{
    for (Class cls = [controller class]; cls && cls != [NSObject class]; cls = class_getSuperclass(cls)) {
        charon_wrap_class(cls);
        if (cls == [UIViewController class])
            break;
    }
}

@interface CharonAppearingInstaller : NSObject
@end

@implementation CharonAppearingInstaller

+ (void)load
{
    Class cls = [UIViewController class];
    Method nib = class_getInstanceMethod(cls, @selector(initWithNibName:bundle:));
    Method coder = class_getInstanceMethod(cls, @selector(initWithCoder:));
    if (!nib || !coder)
        return;
    charon_original_nib = (void *)method_getImplementation(nib);
    charon_original_coder = (void *)method_getImplementation(coder);
    method_setImplementation(nib, imp_implementationWithBlock(^id(UIViewController *controller, NSString *name, NSBundle *bundle) {
        id result = ((id (*)(id, SEL, NSString *, NSBundle *))charon_original_nib)(controller, @selector(initWithNibName:bundle:), name, bundle);
        if (result)
            charon_wrap_chain(result);
        return result;
    }));
    method_setImplementation(coder, imp_implementationWithBlock(^id(UIViewController *controller, NSCoder *decoder) {
        id result = ((id (*)(id, SEL, NSCoder *))charon_original_coder)(controller, @selector(initWithCoder:), decoder);
        if (result)
            charon_wrap_chain(result);
        return result;
    }));
    charon_wrap_class(cls);
}

@end

@implementation UIViewController (CharonAppearingHooks)

- (void)viewIsAppearing:(BOOL)animated
{
}

@end
