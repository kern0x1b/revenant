#import <Foundation/Foundation.h>
#import <objc/message.h>

#include "objc_abi.h"

__attribute__((visibility("hidden"))) id objc_alloc(Class cls)
{
    return cls ? [cls alloc] : nil;
}

__attribute__((visibility("hidden"))) id objc_alloc_init(Class cls)
{
    return cls ? [[cls alloc] init] : nil;
}

__attribute__((visibility("hidden"))) id objc_opt_new(Class cls)
{
    return cls ? [cls new] : nil;
}

__attribute__((visibility("hidden"))) Class objc_opt_class(id object)
{
    return object ? [object class] : Nil;
}

__attribute__((visibility("hidden"))) id objc_opt_self(id object)
{
    return object ? [object self] : nil;
}

__attribute__((visibility("hidden"))) BOOL objc_opt_isKindOfClass(id object, Class cls)
{
    return object ? [object isKindOfClass:cls] : NO;
}

__attribute__((visibility("hidden"))) BOOL objc_opt_respondsToSelector(id object, SEL selector)
{
    return object ? [object respondsToSelector:selector] : NO;
}

__attribute__((visibility("hidden"))) id objc_unsafeClaimAutoreleasedReturnValue(id value)
{
    objc_release(objc_retainAutoreleasedReturnValue(value));
    return value;
}
