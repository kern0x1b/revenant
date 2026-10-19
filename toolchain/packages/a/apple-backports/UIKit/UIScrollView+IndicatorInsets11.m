#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char charon_vertical_key;
static const char charon_horizontal_key;
static const char charon_base_key;

static void (*charon_set_original)(id, SEL, UIEdgeInsets);
static UIEdgeInsets (*charon_get_original)(id, SEL);

static UIEdgeInsets charon_insets_of(id view, const void *key)
{
    NSValue *held = objc_getAssociatedObject(view, key);
    return held ? held.UIEdgeInsetsValue : UIEdgeInsetsZero;
}

static void charon_apply(UIScrollView *view)
{
    NSValue *vertical = objc_getAssociatedObject(view, &charon_vertical_key);
    NSValue *horizontal = objc_getAssociatedObject(view, &charon_horizontal_key);
    UIEdgeInsets base = charon_insets_of(view, &charon_base_key);
    UIEdgeInsets merged = base;
    if (vertical) {
        UIEdgeInsets v = vertical.UIEdgeInsetsValue;
        merged.top = v.top;
        merged.bottom = v.bottom;
        merged.right = v.right;
    }
    if (horizontal)
        merged.left = horizontal.UIEdgeInsetsValue.left;
    charon_set_original(view, @selector(setScrollIndicatorInsets:), merged);
}

static void charon_install(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Method setter = class_getInstanceMethod([UIScrollView class], @selector(setScrollIndicatorInsets:));
        charon_set_original = (void (*)(id, SEL, UIEdgeInsets))method_getImplementation(setter);
        class_replaceMethod([UIScrollView class], @selector(setScrollIndicatorInsets:), imp_implementationWithBlock(^(UIScrollView *view, UIEdgeInsets insets) {
            objc_setAssociatedObject(view, &charon_vertical_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(view, &charon_horizontal_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(view, &charon_base_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            charon_set_original(view, @selector(setScrollIndicatorInsets:), insets);
        }), method_getTypeEncoding(setter));
        Method getter = class_getInstanceMethod([UIScrollView class], @selector(scrollIndicatorInsets));
        charon_get_original = (UIEdgeInsets (*)(id, SEL))method_getImplementation(getter);
        class_replaceMethod([UIScrollView class], @selector(scrollIndicatorInsets), imp_implementationWithBlock(^UIEdgeInsets(UIScrollView *view) {
            NSValue *base = objc_getAssociatedObject(view, &charon_base_key);
            return base ? base.UIEdgeInsetsValue : charon_get_original(view, @selector(scrollIndicatorInsets));
        }), method_getTypeEncoding(getter));
    });
}

static void charon_hold(UIScrollView *view, const void *key, UIEdgeInsets insets)
{
    charon_install();
    if (!objc_getAssociatedObject(view, &charon_base_key))
        objc_setAssociatedObject(view, &charon_base_key, [NSValue valueWithUIEdgeInsets:charon_get_original(view, @selector(scrollIndicatorInsets))], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, key, [NSValue valueWithUIEdgeInsets:insets], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    charon_apply(view);
}

@implementation UIScrollView (CharonIndicatorInsets11)

- (UIEdgeInsets)verticalScrollIndicatorInsets
{
    NSValue *held = objc_getAssociatedObject(self, &charon_vertical_key);
    return held ? held.UIEdgeInsetsValue : self.scrollIndicatorInsets;
}

- (void)setVerticalScrollIndicatorInsets:(UIEdgeInsets)insets
{
    charon_hold(self, &charon_vertical_key, insets);
}

- (UIEdgeInsets)horizontalScrollIndicatorInsets
{
    NSValue *held = objc_getAssociatedObject(self, &charon_horizontal_key);
    return held ? held.UIEdgeInsetsValue : self.scrollIndicatorInsets;
}

- (void)setHorizontalScrollIndicatorInsets:(UIEdgeInsets)insets
{
    charon_hold(self, &charon_horizontal_key, insets);
}

@end
