#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "RevenantTextFieldAlignment.h"

// iOS 6 starts a UITextField made in code with the top vertical alignment (measured on 6.1.3: contentVerticalAlignment 1 on a 48-point
// field of Telegram's country search, text above the baseline of its placeholder; set to 0 the text sits on it). iOS 7 and later start
// it centered. The initializer gives the later start. A field loaded from a nib keeps what the nib says (-initWithCoder: is not
// touched), and an alignment set after the initializer is the application's.

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
