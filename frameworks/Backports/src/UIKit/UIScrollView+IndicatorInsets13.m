#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char revenant_adjusts_key;

@implementation UIScrollView (RevenantIndicatorInsets13)

+ (void)load
{
    Method original = class_getInstanceMethod(self, @selector(setContentInset:));
    Method replacement = class_getInstanceMethod(self, @selector(revenant_setContentInset:));
    if (original && replacement)
        method_exchangeImplementations(original, replacement);
}

- (void)revenant_setContentInset:(UIEdgeInsets)contentInset
{
    [self revenant_setContentInset:contentInset];
    if (self.automaticallyAdjustsScrollIndicatorInsets)
        self.scrollIndicatorInsets = contentInset;
}

- (BOOL)automaticallyAdjustsScrollIndicatorInsets
{
    NSNumber *held = objc_getAssociatedObject(self, &revenant_adjusts_key);
    return held ? held.boolValue : YES;
}

- (void)setAutomaticallyAdjustsScrollIndicatorInsets:(BOOL)automaticallyAdjustsScrollIndicatorInsets
{
    objc_setAssociatedObject(self, &revenant_adjusts_key, @(automaticallyAdjustsScrollIndicatorInsets), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (automaticallyAdjustsScrollIndicatorInsets)
        self.scrollIndicatorInsets = self.contentInset;
}

@end
