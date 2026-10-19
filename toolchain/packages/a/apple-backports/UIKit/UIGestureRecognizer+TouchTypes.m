#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char charon_touch_types_key;
static char charon_exclusive_key;
static char charon_press_types_key;

static NSArray *charon_unique(NSArray *types)
{
    return [[NSOrderedSet orderedSetWithArray:types ?: @[]] array];
}

@implementation UIGestureRecognizer (CharonTouchTypes)

- (NSArray<NSNumber *> *)allowedTouchTypes
{
    NSArray *types = objc_getAssociatedObject(self, &charon_touch_types_key);
    return types ?: @[@(UITouchTypeDirect), @(UITouchTypeIndirect), @(UITouchTypePencil)];
}

- (void)setAllowedTouchTypes:(NSArray<NSNumber *> *)types
{
    objc_setAssociatedObject(self, &charon_touch_types_key, charon_unique(types), OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (BOOL)requiresExclusiveTouchType
{
    NSNumber *value = objc_getAssociatedObject(self, &charon_exclusive_key);
    return value ? value.boolValue : YES;
}

- (void)setRequiresExclusiveTouchType:(BOOL)requires
{
    objc_setAssociatedObject(self, &charon_exclusive_key, @(requires), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray<NSNumber *> *)allowedPressTypes
{
    return objc_getAssociatedObject(self, &charon_press_types_key) ?: @[];
}

- (void)setAllowedPressTypes:(NSArray<NSNumber *> *)types
{
    objc_setAssociatedObject(self, &charon_press_types_key, charon_unique(types), OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end

@implementation UITouch (CharonTouchType)

- (UITouchType)type
{
    return UITouchTypeDirect;
}

@end

@interface CharonTouchTypeInstaller : NSObject
@end

@implementation CharonTouchTypeInstaller

+ (void)load
{
    SEL selector = NSSelectorFromString(@"_delegateShouldReceiveTouch:");
    Method method = class_getInstanceMethod([UIGestureRecognizer class], selector);
    if (!method)
        return;
    BOOL (*original)(id, SEL, id) = (BOOL (*)(id, SEL, id))method_getImplementation(method);
    class_replaceMethod([UIGestureRecognizer class], selector, imp_implementationWithBlock(^BOOL(UIGestureRecognizer *self, UITouch *touch) {
        NSArray *types = objc_getAssociatedObject(self, &charon_touch_types_key);
        if (types && ![types containsObject:@(UITouchTypeDirect)])
            return NO;
        return original(self, selector, touch);
    }), method_getTypeEncoding(method));
}

@end
