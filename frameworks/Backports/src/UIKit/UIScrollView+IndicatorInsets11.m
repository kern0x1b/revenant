#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char revenant_vertical_key;
static const char revenant_horizontal_key;
static const char revenant_base_key;

static void (*revenant_set_original)(id, SEL, UIEdgeInsets);
static UIEdgeInsets (*revenant_get_original)(id, SEL);

static UIEdgeInsets revenant_insets_of(id view, const void *key)
{
    NSValue *held = objc_getAssociatedObject(view, key);
    return held ? held.UIEdgeInsetsValue : UIEdgeInsetsZero;
}

static void revenant_apply(UIScrollView *view)
{
    NSValue *vertical = objc_getAssociatedObject(view, &revenant_vertical_key);
    NSValue *horizontal = objc_getAssociatedObject(view, &revenant_horizontal_key);
    UIEdgeInsets base = revenant_insets_of(view, &revenant_base_key);
    UIEdgeInsets merged = base;
    if (vertical) {
        UIEdgeInsets v = vertical.UIEdgeInsetsValue;
        merged.top = v.top;
        merged.bottom = v.bottom;
        merged.right = v.right;
    }
    if (horizontal)
        merged.left = horizontal.UIEdgeInsetsValue.left;
    revenant_set_original(view, @selector(setScrollIndicatorInsets:), merged);
}

static void revenant_install(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Method setter = class_getInstanceMethod([UIScrollView class], @selector(setScrollIndicatorInsets:));
        revenant_set_original = (void (*)(id, SEL, UIEdgeInsets))method_getImplementation(setter);
        class_replaceMethod([UIScrollView class], @selector(setScrollIndicatorInsets:), imp_implementationWithBlock(^(UIScrollView *view, UIEdgeInsets insets) {
            objc_setAssociatedObject(view, &revenant_vertical_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(view, &revenant_horizontal_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(view, &revenant_base_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            revenant_set_original(view, @selector(setScrollIndicatorInsets:), insets);
        }), method_getTypeEncoding(setter));
        Method getter = class_getInstanceMethod([UIScrollView class], @selector(scrollIndicatorInsets));
        revenant_get_original = (UIEdgeInsets (*)(id, SEL))method_getImplementation(getter);
        class_replaceMethod([UIScrollView class], @selector(scrollIndicatorInsets), imp_implementationWithBlock(^UIEdgeInsets(UIScrollView *view) {
            NSValue *base = objc_getAssociatedObject(view, &revenant_base_key);
            return base ? base.UIEdgeInsetsValue : revenant_get_original(view, @selector(scrollIndicatorInsets));
        }), method_getTypeEncoding(getter));
    });
}

static void revenant_hold(UIScrollView *view, const void *key, UIEdgeInsets insets)
{
    revenant_install();
    if (!objc_getAssociatedObject(view, &revenant_base_key))
        objc_setAssociatedObject(view, &revenant_base_key, [NSValue valueWithUIEdgeInsets:revenant_get_original(view, @selector(scrollIndicatorInsets))], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, key, [NSValue valueWithUIEdgeInsets:insets], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    revenant_apply(view);
}

@implementation UIScrollView (RevenantIndicatorInsets11)

- (UIEdgeInsets)verticalScrollIndicatorInsets
{
    NSValue *held = objc_getAssociatedObject(self, &revenant_vertical_key);
    return held ? held.UIEdgeInsetsValue : self.scrollIndicatorInsets;
}

- (void)setVerticalScrollIndicatorInsets:(UIEdgeInsets)insets
{
    revenant_hold(self, &revenant_vertical_key, insets);
}

- (UIEdgeInsets)horizontalScrollIndicatorInsets
{
    NSValue *held = objc_getAssociatedObject(self, &revenant_horizontal_key);
    return held ? held.UIEdgeInsetsValue : self.scrollIndicatorInsets;
}

- (void)setHorizontalScrollIndicatorInsets:(UIEdgeInsets)insets
{
    revenant_hold(self, &revenant_horizontal_key, insets);
}

@end
