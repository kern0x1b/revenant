#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>

NSErrorUserInfoKey const NSLocalizedFailureErrorKey = @"NSLocalizedFailure";

// The failure followed by the reason, as iOS 11 joins them; the reason is -localizedFailureReason, so
// the user info's, then the provider's, then the one the release generates for the domain and code.
static NSString *charon_failure_sentence(NSError *error, NSString *failure)
{
    NSString *reason = error.localizedFailureReason;
    return reason.length ? [NSString stringWithFormat:@"%@ %@", failure, reason] : failure;
}

// iOS 11 builds -localizedDescription in this order (NSError.h): the description of the user info,
// its failure with the reason, the provider's description, the provider's failure with the reason,
// then what the release did before. The wrapper takes the two failure steps and leaves the others to
// the release, or to the provider's wrapper of NSError+UserInfoValueProvider.m below iOS 9, which it
// has to run outside of: that one answers the provider's description, which the failure of the user
// info comes before. It is installed from a constructor, which runs after every +load of the library.
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
