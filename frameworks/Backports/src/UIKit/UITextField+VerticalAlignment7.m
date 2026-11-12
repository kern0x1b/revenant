#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "RevenantTextFieldAlignment.h"

static IMP revenant_text_field_init_original;

static id revenant_text_field_init_with_frame(UITextField *field, SEL selector, CGRect frame)
{
    field = ((id (*)(id, SEL, CGRect))revenant_text_field_init_original)(field, selector, frame);
    long initial = RevenantTextFieldInitialAlignment((long)field.contentVerticalAlignment);
    if (initial != (long)field.contentVerticalAlignment)
        field.contentVerticalAlignment = (UIControlContentVerticalAlignment)initial;
    return field;
}

@interface RevenantTextFieldAlignment : NSObject
@end

@implementation RevenantTextFieldAlignment

+ (void)load
{
    if (NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_7_0)
        return;
    Method method = class_getInstanceMethod([UITextField class], @selector(initWithFrame:));
    Method inherited = class_getInstanceMethod([UIView class], @selector(initWithFrame:));
    if (!method || method_getImplementation(method) == method_getImplementation(inherited))
        return;
    revenant_text_field_init_original = method_getImplementation(method);
    method_setImplementation(method, (IMP)revenant_text_field_init_with_frame);
}

@end
