#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import <string.h>

@implementation UIAccessibilityCustomAction {
    NSString *_name;
    __weak id _target;
    SEL _selector;
}

@dynamic attributedName, image, actionHandler;

- (instancetype)initWithName:(NSString *)name target:(id)target selector:(SEL)selector
{
    self = [super init];
    if (self) {
        _name = [name copy];
        _target = target;
        _selector = selector;
    }
    return self;
}

- (NSString *)name
{
    return _name;
}

- (void)setName:(NSString *)name
{
    _name = [name copy];
}

- (id)target
{
    return _target;
}

- (void)setTarget:(id)target
{
    _target = target;
}

- (SEL)selector
{
    return _selector;
}

- (void)setSelector:(SEL)selector
{
    _selector = selector;
}

- (BOOL)revenantPerform
{
    UIAccessibilityCustomActionHandler handler = self.actionHandler;
    if (handler)
        return handler(self);
    id target = _target;
    if (!target || !_selector || ![target respondsToSelector:_selector])
        return NO;
    IMP method = [target methodForSelector:_selector];
    ((void (*)(id, SEL, id))method)(target, _selector, self);
    return YES;
}

@end

static const void *RevenantCustomActionsKey = &RevenantCustomActionsKey;
static const void *RevenantElementsKey = &RevenantElementsKey;
static const void *RevenantNavigationStyleKey = &RevenantNavigationStyleKey;

static IMP RevenantCustomActionsGetter;
static IMP RevenantCustomActionsSetter;
static BOOL RevenantCustomActionsArmed;

static void RevenantReassertCustomActions(void);

@implementation NSObject (RevenantAccessibilityElements)

- (NSArray<UIAccessibilityCustomAction *> *)accessibilityCustomActions
{
    return objc_getAssociatedObject(self, RevenantCustomActionsKey);
}

- (void)setAccessibilityCustomActions:(NSArray<UIAccessibilityCustomAction *> *)actions
{
    RevenantReassertCustomActions();
    objc_setAssociatedObject(self, RevenantCustomActionsKey, [actions copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray *)accessibilityElements
{
    return objc_getAssociatedObject(self, RevenantElementsKey);
}

- (void)setAccessibilityElements:(NSArray *)elements
{
    objc_setAssociatedObject(self, RevenantElementsKey, [elements copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIAccessibilityNavigationStyle)accessibilityNavigationStyle
{
    return (UIAccessibilityNavigationStyle)[objc_getAssociatedObject(self, RevenantNavigationStyleKey) integerValue];
}

- (void)setAccessibilityNavigationStyle:(UIAccessibilityNavigationStyle)style
{
    objc_setAssociatedObject(self, RevenantNavigationStyleKey, @(style), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

static BOOL RevenantInThisImage(const void *address)
{
    Dl_info here, there;
    if (dladdr(address, &there) == 0 || there.dli_fname == NULL || dladdr((const void *)RevenantInThisImage, &here) == 0
        || here.dli_fname == NULL) {
        return NO;
    }
    return strcmp(here.dli_fname, there.dli_fname) == 0;
}

static void RevenantReassertCustomActions(void)
{
    if (!RevenantCustomActionsArmed) {
        return;
    }
    Method visible = class_getInstanceMethod([NSObject class], @selector(accessibilityCustomActions));
    if (visible != NULL && method_getImplementation(visible) == RevenantCustomActionsGetter) {
        return;
    }
    class_replaceMethod([NSObject class], @selector(accessibilityCustomActions), RevenantCustomActionsGetter, "@@:");
    class_replaceMethod([NSObject class], @selector(setAccessibilityCustomActions:), RevenantCustomActionsSetter, "v@:@");
}

static void RevenantQueueReassertCustomActions(const struct mach_header *header, intptr_t slide)
{
    Dl_info info;
    if (!RevenantCustomActionsArmed || dladdr(header, &info) == 0 || info.dli_fname == NULL
        || strstr(info.dli_fname, "/UIAccessibility.framework/UIAccessibility") == NULL) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        RevenantReassertCustomActions();
    });
}

__attribute__((constructor)) static void RevenantArmCustomActions(void)
{
    RevenantCustomActionsGetter = class_getMethodImplementation([NSObject class], @selector(accessibilityCustomActions));
    RevenantCustomActionsSetter = class_getMethodImplementation([NSObject class], @selector(setAccessibilityCustomActions:));
    RevenantCustomActionsArmed = RevenantInThisImage((const void *)RevenantCustomActionsGetter)
        && RevenantInThisImage((const void *)RevenantCustomActionsSetter);
    _dyld_register_func_for_add_image(RevenantQueueReassertCustomActions);
}
