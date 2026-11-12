#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "RevenantLabelBackground.h"

static IMP revenant_label_init_original;

static id revenant_label_init_with_frame(UILabel *label, SEL selector, CGRect frame)
{
    label = ((id (*)(id, SEL, CGRect))revenant_label_init_original)(label, selector, frame);
    UIColor *background = label.backgroundColor;
    if (!background)
        return label;
    CGColorRef color = background.CGColor;
    if (RevenantLabelBackgroundIsDefaultWhite(CGColorGetComponents(color), CGColorGetNumberOfComponents(color))) {
        label.backgroundColor = nil;
        label.opaque = NO;
    }
    return label;
}

@interface RevenantLabelBackground : NSObject
@end

@implementation RevenantLabelBackground

+ (void)load
{
    if (NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_7_0)
        return;
    Method method = class_getInstanceMethod([UILabel class], @selector(initWithFrame:));
    Method inherited = class_getInstanceMethod([UIView class], @selector(initWithFrame:));
    if (!method || method_getImplementation(method) == method_getImplementation(inherited))
        return;
    revenant_label_init_original = method_getImplementation(method);
    method_setImplementation(method, (IMP)revenant_label_init_with_frame);
}

@end
