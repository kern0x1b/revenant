#import <Foundation/Foundation.h>

extern CFTypeRef objc_autorelease(CFTypeRef value);

CFTypeRef CFAutorelease(CFTypeRef arg)
{
    if (!arg)
        __builtin_trap();
    return objc_autorelease(arg);
}
