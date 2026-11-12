#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "RevenantLabelBackground.h"

// iOS 6 gives a UILabel made in code an opaque white background (measured on 6.1.3: backgroundColor white 1/1, opaque YES; a UIView has
// none). iOS 7 and later give it none and draw it non-opaque. The initializer clears the default the way the later iOS has it. A label
// loaded from a nib keeps what the nib says (-initWithCoder: is not touched), and a background set after the initializer is the app's.

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
