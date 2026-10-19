#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <stdlib.h>
#import <objc/runtime.h>
#import <stdlib.h>
static void P(NSString *f, ...) NS_FORMAT_FUNCTION(1,2);
static void P(NSString *f, ...) { va_list a; va_start(a,f); NSString *s=[[NSString alloc] initWithFormat:f arguments:a]; va_end(a); printf("%s\n", s.UTF8String); }
int main(void) { @autoreleasepool {
    Class request = NSClassFromString(@"NSBundleResourceRequest");
    P(@"class %s", class_getName(request));
    P(@"  super %s", class_getName(class_getSuperclass(request)));
    P(@"  +alloc -> %s", class_getName([request alloc]));
    P(@"  +supportsSecureCoding answered: %d", (int)[request supportsSecureCoding]);
    P(@"  instancesRespondToSelector:init: %d", (int)[request instancesRespondToSelector:@selector(init)]);
    P(@"  is a stub? -description on the class: %s", [[request description] UTF8String]);
    unsigned count = 0;
    Method *methods = class_copyMethodList(request, &count);
    P(@"  %u methods:", count);
    for (unsigned i = 0; i < count; i++)
        P(@"    -%@", NSStringFromSelector(method_getName(methods[i])));
    free(methods);
    unsigned icount = 0;
    Method *imethods = class_copyMethodList(class_getMetaClass(request), &icount);
    P(@"  %u class methods:", icount);
    for (unsigned i = 0; i < icount; i++)
        P(@"    +%@", NSStringFromSelector(method_getName(imethods[i])));
    free(imethods);
} return 0; }
