#import "RevenantTextContentType.h"
#import <objc/runtime.h>

static char revenant_text_content_type_key;

static UIKeyboardType revenant_keyboard_type(NSString *type, BOOL *mapped)
{
    *mapped = YES;
    if ([type isEqualToString:@"oneTimeCode"])
        return UIKeyboardTypeNumberPad;
    if ([type isEqualToString:@"emailAddress"])
        return UIKeyboardTypeEmailAddress;
    if ([type isEqualToString:@"URL"])
        return UIKeyboardTypeURL;
    if ([type isEqualToString:@"telephoneNumber"])
        return UIKeyboardTypePhonePad;
    *mapped = NO;
    return UIKeyboardTypeDefault;
}

NSString *revenant_text_content_type(id object)
{
    return objc_getAssociatedObject(object, &revenant_text_content_type_key);
}

void revenant_set_text_content_type(id object, NSString *type)
{
    objc_setAssociatedObject(object, &revenant_text_content_type_key, [type copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    BOOL mapped = NO;
    UIKeyboardType keyboard = revenant_keyboard_type(type, &mapped);
    if (mapped && [object respondsToSelector:@selector(keyboardType)] && [object keyboardType] == UIKeyboardTypeDefault)
        [object setKeyboardType:keyboard];
    static dispatch_once_t once;
    if (type)
        dispatch_once(&once, ^{
            NSLog(@"textContentType sets the keyboard type when the app left it at the default; the AutoFill suggestion is system UI, and iOS 6 has none");
        });
}
