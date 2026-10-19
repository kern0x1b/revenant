#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <dlfcn.h>

static BOOL charon_from_backports(IMP implementation)
{
    Dl_info info;
    if (!dladdr((void *)implementation, &info) || !info.dli_fname)
        return NO;
    NSString *image = @(info.dli_fname).lastPathComponent;
    return [image isEqualToString:@"libUIKitBackports.dylib"] || [image isEqualToString:@"libFoundationBackports.dylib"];
}

static void charon_alias(Class cls, Method method, NSString *alias)
{
    SEL selector = NSSelectorFromString(alias);
    class_addMethod(cls, selector, method_getImplementation(method), method_getTypeEncoding(method));
}

static void charon_alias_class(Class cls)
{
    unsigned count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    for (unsigned index = 0; index < count; index++) {
        if (!charon_from_backports(method_getImplementation(methods[index])))
            continue;
        NSString *name = NSStringFromSelector(method_getName(methods[index]));
        charon_alias(cls, methods[index], [@"charonHost_" stringByAppendingString:name]);
        if ([name hasPrefix:@"set"] && name.length > 3)
            charon_alias(cls, methods[index], [@"setCharonHost" stringByAppendingString:[name substringFromIndex:3]]);
        else
            charon_alias(cls, methods[index], [@"charonHost" stringByAppendingFormat:@"%@%@",
                                               [[name substringToIndex:1] uppercaseString], [name substringFromIndex:1]]);
    }
    free(methods);
}

void host_attach_prefixed(const char *prefix)
{
    static BOOL done;
    if (done)
        return;
    done = YES;
    int count = objc_getClassList(NULL, 0);
    Class *classes = (Class *)malloc(sizeof(Class) * count);
    count = objc_getClassList(classes, count);
    for (int index = 0; index < count; index++) {
        charon_alias_class(classes[index]);
        charon_alias_class(object_getClass(classes[index]));
    }
    free(classes);
}
