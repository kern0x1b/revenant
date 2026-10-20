#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char revenant_touch_types_key;
static char revenant_exclusive_key;
static char revenant_press_types_key;

static NSArray *revenant_unique(NSArray *types)
{
    return [[NSOrderedSet orderedSetWithArray:types ?: @[]] array];
}

@implementation UIGestureRecognizer (RevenantTouchTypes)

- (NSArray<NSNumber *> *)allowedTouchTypes
{
    NSArray *types = objc_getAssociatedObject(self, &revenant_touch_types_key);
    return types ?: @[@(UITouchTypeDirect), @(UITouchTypeIndirect), @(UITouchTypePencil)];
}

- (void)setAllowedTouchTypes:(NSArray<NSNumber *> *)types
{
    objc_setAssociatedObject(self, &revenant_touch_types_key, revenant_unique(types), OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (BOOL)requiresExclusiveTouchType
{
    NSNumber *value = objc_getAssociatedObject(self, &revenant_exclusive_key);
    return value ? value.boolValue : YES;
}

- (void)setRequiresExclusiveTouchType:(BOOL)requires
{
    objc_setAssociatedObject(self, &revenant_exclusive_key, @(requires), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSArray<NSNumber *> *)allowedPressTypes
{
    return objc_getAssociatedObject(self, &revenant_press_types_key) ?: @[];
}

- (void)setAllowedPressTypes:(NSArray<NSNumber *> *)types
{
    objc_setAssociatedObject(self, &revenant_press_types_key, revenant_unique(types), OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end

@implementation UITouch (RevenantTouchType)

- (UITouchType)type
{
    return UITouchTypeDirect;
}

@end

@interface RevenantTouchTypeInstaller : NSObject
@end

@implementation RevenantTouchTypeInstaller

+ (void)load
{
    SEL selector = NSSelectorFromString(@"_delegateShouldReceiveTouch:");
    Method method = class_getInstanceMethod([UIGestureRecognizer class], selector);
    if (!method)
        return;
    BOOL (*original)(id, SEL, id) = (BOOL (*)(id, SEL, id))method_getImplementation(method);
    class_replaceMethod([UIGestureRecognizer class], selector, imp_implementationWithBlock(^BOOL(UIGestureRecognizer *self, UITouch *touch) {
        NSArray *types = objc_getAssociatedObject(self, &revenant_touch_types_key);
        if (types && ![types containsObject:@(UITouchTypeDirect)])
            return NO;
        return original(self, selector, touch);
    }), method_getTypeEncoding(method));
}

@end
