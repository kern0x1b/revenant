#import <Foundation/Foundation.h>
#import <objc/runtime.h>

__attribute__((constructor)) static void standin(void)
{
    Method ephemeral = class_getClassMethod(NSClassFromString(@"NSURLSessionConfiguration"), @selector(ephemeralSessionConfiguration));
    id (*original)(id, SEL) = (id (*)(id, SEL))method_getImplementation(ephemeral);
    method_setImplementation(ephemeral, imp_implementationWithBlock(^id(id self) {
        [NSHTTPCookieStorage sharedHTTPCookieStorage];
        return original(self, @selector(ephemeralSessionConfiguration));
    }));
}
