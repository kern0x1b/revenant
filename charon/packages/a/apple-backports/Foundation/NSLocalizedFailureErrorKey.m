#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>

NSErrorUserInfoKey const NSLocalizedFailureErrorKey = @"NSLocalizedFailure";

static NSString *charon_failure_sentence(NSError *error, NSString *failure)
{
    NSString *reason = error.localizedFailureReason;
    return reason.length ? [NSString stringWithFormat:@"%@ %@", failure, reason] : failure;
}

__attribute__((constructor)) static void charon_install_failure_description(void)
{
    void *foundation = dlopen("/System/Library/Frameworks/Foundation.framework/Foundation", RTLD_LAZY | RTLD_NOLOAD);
    BOOL released = foundation && dlsym(foundation, "NSLocalizedFailureErrorKey");
    if (foundation)
        dlclose(foundation);
    if (released)
        return;
    SEL selector = @selector(localizedDescription);
    Method method = class_getInstanceMethod([NSError class], selector);
    NSString *(*original)(id, SEL) = (NSString *(*)(id, SEL))method_getImplementation(method);
    method_setImplementation(method, imp_implementationWithBlock(^NSString *(NSError *self_) {
        NSDictionary *info = self_.userInfo;
        if (info[NSLocalizedDescriptionKey])
            return original(self_, selector);
        if (info[NSLocalizedFailureErrorKey])
            return charon_failure_sentence(self_, info[NSLocalizedFailureErrorKey]);
        id (^provider)(NSError *, NSErrorUserInfoKey) = [NSError respondsToSelector:@selector(userInfoValueProviderForDomain:)] ? [NSError userInfoValueProviderForDomain:self_.domain] : nil;
        if (provider) {
            NSString *described = provider(self_, NSLocalizedDescriptionKey);
            if (described)
                return described;
            NSString *failure = provider(self_, NSLocalizedFailureErrorKey);
            if (failure)
                return charon_failure_sentence(self_, failure);
        }
        return original(self_, selector);
    }));
}
