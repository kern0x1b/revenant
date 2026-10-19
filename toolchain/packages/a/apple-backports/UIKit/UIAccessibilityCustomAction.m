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

- (BOOL)charonPerform
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

static const void *CharonCustomActionsKey = &CharonCustomActionsKey;
static const void *CharonElementsKey = &CharonElementsKey;
static const void *CharonNavigationStyleKey = &CharonNavigationStyleKey;

static IMP CharonCustomActionsGetter;
static IMP CharonCustomActionsSetter;
static BOOL CharonCustomActionsArmed;

static void CharonReassertCustomActions(void);

@implementation NSObject (CharonAccessibilityElements)

- (NSArray<UIAccessibilityCustomAction *> *)accessibilityCustomActions
{
    return objc_getAssociatedObject(self, CharonCustomActionsKey);
}

- (void)setAccessibilityCustomActions:(NSArray<UIAccessibilityCustomAction *> *)actions
{
    CharonReassertCustomActions();
    objc_setAssociatedObject(self, CharonCustomActionsKey, [actions copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray *)accessibilityElements
{
    return objc_getAssociatedObject(self, CharonElementsKey);
}

- (void)setAccessibilityElements:(NSArray *)elements
{
    objc_setAssociatedObject(self, CharonElementsKey, [elements copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIAccessibilityNavigationStyle)accessibilityNavigationStyle
{
    return (UIAccessibilityNavigationStyle)[objc_getAssociatedObject(self, CharonNavigationStyleKey) integerValue];
}

- (void)setAccessibilityNavigationStyle:(UIAccessibilityNavigationStyle)style
{
    objc_setAssociatedObject(self, CharonNavigationStyleKey, @(style), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

static BOOL CharonInThisImage(const void *address)
{
    Dl_info here, there;
    if (dladdr(address, &there) == 0 || there.dli_fname == NULL || dladdr((const void *)CharonInThisImage, &here) == 0
        || here.dli_fname == NULL) {
        return NO;
    }
    return strcmp(here.dli_fname, there.dli_fname) == 0;
}

static void CharonReassertCustomActions(void)
{
    if (!CharonCustomActionsArmed) {
        return;
    }
    Method visible = class_getInstanceMethod([NSObject class], @selector(accessibilityCustomActions));
    if (visible != NULL && method_getImplementation(visible) == CharonCustomActionsGetter) {
        return;
    }
    class_replaceMethod([NSObject class], @selector(accessibilityCustomActions), CharonCustomActionsGetter, "@@:");
    class_replaceMethod([NSObject class], @selector(setAccessibilityCustomActions:), CharonCustomActionsSetter, "v@:@");
}

static void CharonQueueReassertCustomActions(const struct mach_header *header, intptr_t slide)
{
    Dl_info info;
    if (!CharonCustomActionsArmed || dladdr(header, &info) == 0 || info.dli_fname == NULL
        || strstr(info.dli_fname, "/UIAccessibility.framework/UIAccessibility") == NULL) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        CharonReassertCustomActions();
    });
}

__attribute__((constructor)) static void CharonArmCustomActions(void)
{
    CharonCustomActionsGetter = class_getMethodImplementation([NSObject class], @selector(accessibilityCustomActions));
    CharonCustomActionsSetter = class_getMethodImplementation([NSObject class], @selector(setAccessibilityCustomActions:));
    CharonCustomActionsArmed = CharonInThisImage((const void *)CharonCustomActionsGetter)
        && CharonInThisImage((const void *)CharonCustomActionsSetter);
    _dyld_register_func_for_add_image(CharonQueueReassertCustomActions);
}
