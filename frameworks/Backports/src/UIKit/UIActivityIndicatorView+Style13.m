#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char RevenantRequestedActivityStyleKey;

static UIActivityIndicatorViewStyle revenant_style_before_13(UIActivityIndicatorViewStyle style)
{
    if (style == UIActivityIndicatorViewStyleMedium)
        return UIActivityIndicatorViewStyleGray;
    if (style == UIActivityIndicatorViewStyleLarge)
        return UIActivityIndicatorViewStyleWhiteLarge;
    return style;
}

static void revenant_remember_activity_style(id view, UIActivityIndicatorViewStyle style)
{
    objc_setAssociatedObject(view, &RevenantRequestedActivityStyleKey, @(style), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@interface RevenantActivityIndicatorStyle13 : NSObject
@end

@implementation RevenantActivityIndicatorStyle13

+ (void)load
{
    if ([UIView instancesRespondToSelector:@selector(overrideUserInterfaceStyle)])
        return;
    SEL initWithStyle = @selector(initWithActivityIndicatorStyle:);
    Method initMethod = class_getInstanceMethod([UIActivityIndicatorView class], initWithStyle);
    id (*originalInit)(id, SEL, UIActivityIndicatorViewStyle) = (id (*)(id, SEL, UIActivityIndicatorViewStyle))method_getImplementation(initMethod);
    class_replaceMethod([UIActivityIndicatorView class], initWithStyle, imp_implementationWithBlock(^(UIActivityIndicatorView *view, UIActivityIndicatorViewStyle style) {
        UIActivityIndicatorView *initialized = originalInit(view, initWithStyle, revenant_style_before_13(style));
        revenant_remember_activity_style(initialized, style);
        return initialized;
    }), method_getTypeEncoding(initMethod));
    SEL setStyle = @selector(setActivityIndicatorViewStyle:);
    Method setMethod = class_getInstanceMethod([UIActivityIndicatorView class], setStyle);
    void (*originalSet)(id, SEL, UIActivityIndicatorViewStyle) = (void (*)(id, SEL, UIActivityIndicatorViewStyle))method_getImplementation(setMethod);
    class_replaceMethod([UIActivityIndicatorView class], setStyle, imp_implementationWithBlock(^(UIActivityIndicatorView *view, UIActivityIndicatorViewStyle style) {
        revenant_remember_activity_style(view, style);
        originalSet(view, setStyle, revenant_style_before_13(style));
    }), method_getTypeEncoding(setMethod));
    SEL getStyle = @selector(activityIndicatorViewStyle);
    Method getMethod = class_getInstanceMethod([UIActivityIndicatorView class], getStyle);
    UIActivityIndicatorViewStyle (*originalGet)(id, SEL) = (UIActivityIndicatorViewStyle (*)(id, SEL))method_getImplementation(getMethod);
    class_replaceMethod([UIActivityIndicatorView class], getStyle, imp_implementationWithBlock(^UIActivityIndicatorViewStyle(UIActivityIndicatorView *view) {
        NSNumber *requested = objc_getAssociatedObject(view, &RevenantRequestedActivityStyleKey);
        return requested ? (UIActivityIndicatorViewStyle)requested.integerValue : originalGet(view, getStyle);
    }), method_getTypeEncoding(getMethod));
}

@end
