#include "../revenant_impl.h"
#import <Foundation/Foundation.h>

extern CFTypeRef objc_autorelease(CFTypeRef value);

CFTypeRef BACKPORT_IMPL(CFAutorelease)(CFTypeRef arg)
{
    if (!arg)
        __builtin_trap();
    return objc_autorelease(arg);
}
