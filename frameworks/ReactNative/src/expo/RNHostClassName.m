#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#undef NSStringFromClass

NSString *RNHostStringFromClass(Class aClass, const char *file, int line)
{
    if (aClass == Nil) {
        NSLog(@"rn-host: NSStringFromClass(Nil) at %s:%d", file, line);
        return nil;
    }
    return NSStringFromClass(aClass);
}
