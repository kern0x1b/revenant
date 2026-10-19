#import "CharonTextContentType.h"
#import <objc/runtime.h>

static char charon_text_content_type_key;

NSString *charon_text_content_type(id object)
{
    return objc_getAssociatedObject(object, &charon_text_content_type_key);
}

void charon_set_text_content_type(id object, NSString *type)
{
    static dispatch_once_t once;
    if (type)
        dispatch_once(&once, ^{
            NSLog(@"textContentType is kept and handed back, and not used: iOS 6 has no keyboard that fills a field in from a type");
        });
    objc_setAssociatedObject(object, &charon_text_content_type_key, [type copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
